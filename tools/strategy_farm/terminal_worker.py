#!/usr/bin/env python
"""Long-running per-terminal worker for QM strategy_farm.

Usage:
    python terminal_worker.py --terminal T1
"""

from __future__ import annotations

import argparse
import json
import os
import signal
import sqlite3
import time
from pathlib import Path
from typing import Any

import farmctl


POLL_SLEEP_SECONDS = 2.0
MAX_WORK_ITEM_RETRIES = 3
SQLITE_WRITE_RETRIES = 5
SQLITE_WRITE_RETRY_SLEEP_SECONDS = 1.0
SMOKE_TERMINAL_EXIT_GRACE_SECONDS = 60.0

_STOP = False


def _handle_stop(_signum: int, _frame: object) -> None:
    global _STOP
    _STOP = True


def _json_loads(text: str | None) -> dict[str, Any]:
    if not text:
        return {}
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        return {}
    return value if isinstance(value, dict) else {}


def _with_sqlite_retry(fn):
    for attempt in range(1, SQLITE_WRITE_RETRIES + 1):
        try:
            return fn()
        except sqlite3.OperationalError as exc:
            if "locked" not in str(exc).lower() or attempt == SQLITE_WRITE_RETRIES:
                raise
            time.sleep(SQLITE_WRITE_RETRY_SLEEP_SECONDS * attempt)
    raise RuntimeError("unreachable sqlite retry state")


def _priority_pending_query() -> str:
    return """
        SELECT w.*,
          CASE w.phase
            WHEN 'P8'   THEN 0
            WHEN 'P7'   THEN 1
            WHEN 'P6'   THEN 2
            WHEN 'P5c'  THEN 3
            WHEN 'P5b'  THEN 4
            WHEN 'P5'   THEN 5
            WHEN 'P4'   THEN 6
            WHEN 'P3.5' THEN 7
            WHEN 'P3'   THEN 8
            WHEN 'P2'   THEN 9
            ELSE 9 END AS _phase_rank,
          CASE WHEN EXISTS (
            SELECT 1 FROM work_items wp
            WHERE wp.ea_id=w.ea_id AND wp.status='done' AND wp.verdict='PASS'
          ) THEN 0 ELSE 1 END AS _winner_rank
        FROM work_items w
        WHERE w.status='pending'
        ORDER BY _phase_rank ASC, _winner_rank ASC, w.updated_at ASC, w.created_at ASC
    """


def _p2_history_claimable(item: sqlite3.Row) -> tuple[bool, dict[str, Any] | None]:
    if str(item["phase"]).upper() != "P2":
        return True, None
    payload = _json_loads(item["payload_json"])
    period = str(payload.get("period") or "").strip().upper()
    if not period:
        try:
            period = farmctl._detect_ea_period(item["ea_id"])
        except Exception:
            period = ""
    if not period:
        return True, None
    is_exploration = any(token in item["setfile_path"] for token in ("_ablation_", "_grid_", "_synth_"))
    default_from_year = 2020 if is_exploration else farmctl.P2_DEFAULT_FROM_YEAR
    from_year = int(payload.get("from_year") or default_from_year)
    to_year = int(payload.get("to_year") or farmctl.P2_DEFAULT_TO_YEAR)
    window = farmctl._p2_history_window_for_symbol(item["symbol"], period, from_year, to_year)
    return not bool(window.get("skip")), window


def claim_atomic(root: Path, terminal: str) -> dict[str, Any]:
    """Atomically claim one pending work_item for a terminal.

    The transaction serializes competing worker daemons. A symbol already active
    anywhere in the farm blocks another item with the same symbol.
    """
    farmctl.init_db(root)
    now = farmctl.utc_now()
    db_path = root / farmctl.DB_REL
    with sqlite3.connect(db_path, timeout=30) as conn:
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA busy_timeout=30000")
        conn.execute("BEGIN IMMEDIATE")
        try:
            active_terminal = conn.execute(
                "SELECT * FROM work_items WHERE status='active' AND claimed_by=? LIMIT 1",
                (terminal,),
            ).fetchone()
            if active_terminal:
                payload = _json_loads(active_terminal["payload_json"])
                pid = payload.get("pid")
                if pid and farmctl._pid_exists(pid):
                    conn.commit()
                    return {"claimed": False, "reason": "terminal_busy", "item_id": active_terminal["id"]}
                payload["prior_failure"] = payload.get("prior_failure") or "worker_loop_released_stale_claim"
                terminal_stopped = _stop_terminal_slot_for_release(root, terminal)
                if terminal_stopped is not None:
                    payload["terminal_stopped_on_release"] = terminal_stopped
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='pending', claimed_by=NULL, payload_json=?, updated_at=?
                    WHERE id=? AND status='active' AND claimed_by=?
                    """,
                    (json.dumps(payload, sort_keys=True), now, active_terminal["id"], terminal),
                )

            if root.resolve() == farmctl.DEFAULT_ROOT.resolve() and terminal in farmctl._running_mt5_terminals():
                conn.commit()
                return {"claimed": False, "reason": "terminal_process_busy", "terminal": terminal}

            active_symbols = farmctl._active_work_item_symbols(conn)
            skipped_history: list[dict[str, Any]] = []
            for item in conn.execute(_priority_pending_query()).fetchall():
                symbol_key = str(item["symbol"] or "").upper()
                if symbol_key and symbol_key in active_symbols:
                    continue
                history_ok, history = _p2_history_claimable(item)
                if not history_ok:
                    skipped_history.append({"item_id": item["id"], **(history or {})})
                    continue
                payload = _json_loads(item["payload_json"])
                payload.update({
                    "claimed_at_iso": now,
                    "claimed_by_worker_pid": os.getpid(),
                    "terminal": terminal,
                })
                cur = conn.execute(
                    """
                    UPDATE work_items
                    SET status='active', claimed_by=?, payload_json=?, updated_at=?
                    WHERE id=? AND status='pending'
                    """,
                    (terminal, json.dumps(payload, sort_keys=True), now, item["id"]),
                )
                if cur.rowcount == 1:
                    conn.commit()
                    row = conn.execute("SELECT * FROM work_items WHERE id=?", (item["id"],)).fetchone()
                    return {"claimed": True, "item": dict(row)}
            conn.commit()
            return {"claimed": False, "reason": "no_pending_claimable", "history_skipped": skipped_history}
        except Exception:
            conn.rollback()
            raise


def release_stale_claims_for_terminal(root: Path, terminal: str) -> list[str]:
    """Release this terminal's active rows if the recorded smoke process is gone."""
    def _release() -> list[str]:
        farmctl.init_db(root)
        released: list[str] = []
        now = farmctl.utc_now()
        with farmctl.connect(root) as conn:
            rows = conn.execute(
                "SELECT * FROM work_items WHERE status='active' AND claimed_by=?",
                (terminal,),
            ).fetchall()
            for row in rows:
                payload = _json_loads(row["payload_json"])
                pid = payload.get("pid")
                if pid and farmctl._pid_exists(pid):
                    continue
                payload["prior_failure"] = payload.get("prior_failure") or "worker_restart_released_stale_claim"
                terminal_stopped = _stop_terminal_slot_for_release(root, terminal)
                if terminal_stopped is not None:
                    payload["terminal_stopped_on_release"] = terminal_stopped
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='pending', claimed_by=NULL, payload_json=?, updated_at=?
                    WHERE id=? AND status='active' AND claimed_by=?
                    """,
                    (json.dumps(payload, sort_keys=True), now, row["id"], terminal),
                )
                released.append(row["id"])
            if released:
                conn.commit()
        return released

    return _with_sqlite_retry(_release)


def _find_summary(report_root: str | None) -> Path | None:
    if not report_root:
        return None
    root = Path(report_root)
    if not root.is_dir():
        return None
    candidates = sorted(root.rglob("summary.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    return candidates[0] if candidates else None


def _smoke_terminal_exit_stalled(item: dict[str, Any], payload: dict[str, Any]) -> bool:
    """Detect run_smoke wrappers stuck after MT5 already exited.

    P2/P3 use a single run_smoke.ps1 child. If its log has reached
    terminal_exit but no summary appears and the log is quiet, waiting for the
    full worker timeout only blocks the symbol dedupe queue.
    """
    if str(item.get("phase") or "").upper() not in {"P2", "P3"}:
        return False
    if _find_summary(payload.get("report_root")):
        return False
    log_path = payload.get("log_path")
    if not log_path:
        return False
    path = Path(str(log_path))
    try:
        stat = path.stat()
        if time.time() - stat.st_mtime < SMOKE_TERMINAL_EXIT_GRACE_SECONDS:
            return False
        text = path.read_text(encoding="utf-8-sig", errors="ignore")
    except OSError:
        return False
    return "run_smoke.stage=terminal_exit" in text


def _stop_terminal_slot_for_release(root: Path, terminal: str | None) -> bool | None:
    """Stop the factory MT5 process before a released work_item can orphan it."""
    if root.resolve() != farmctl.DEFAULT_ROOT.resolve():
        return None
    if not terminal:
        return None
    return farmctl._stop_terminal_slot(str(terminal))


def _work_item_ownership(root: Path, item_id: str, terminal: str) -> dict[str, Any]:
    """Return whether a worker still owns the active work_item claim."""
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT status, claimed_by FROM work_items WHERE id=?",
            (item_id,),
        ).fetchone()
    if not row:
        return {"owned": False, "reason": "missing_item"}
    status = row["status"]
    claimed_by = row["claimed_by"]
    if status != "active":
        return {"owned": False, "reason": "status_changed", "status": status, "claimed_by": claimed_by}
    if claimed_by != terminal:
        return {"owned": False, "reason": "claim_transferred", "status": status, "claimed_by": claimed_by}
    return {"owned": True, "status": status, "claimed_by": claimed_by}


def _finish_work_item(root: Path, item_id: str, exit_code: int | None) -> dict[str, Any]:
    def _finish() -> dict[str, Any]:
        now = farmctl.utc_now()
        with farmctl.connect(root) as conn:
            item = conn.execute("SELECT * FROM work_items WHERE id=?", (item_id,)).fetchone()
            if not item:
                return {"finished": False, "reason": "missing_item"}
            payload = _json_loads(item["payload_json"])
            summary_path = _find_summary(payload.get("report_root"))
            if summary_path:
                try:
                    summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
                except (OSError, json.JSONDecodeError):
                    summary = None
                if summary:
                    effective_min_trades = int(
                        payload.get("effective_min_trades")
                        or summary.get("min_trades_required")
                        or 5
                    )
                    verdict, reason = farmctl._derive_verdict_from_summary(
                        summary,
                        min_trades=effective_min_trades,
                        phase=item["phase"],
                    )
                    payload["verdict_reason"] = reason
                    payload["run_smoke_exit_code"] = exit_code
                    conn.execute(
                        """
                        UPDATE work_items
                        SET status='done', verdict=?, evidence_path=?, claimed_by=NULL,
                            payload_json=?, updated_at=?
                        WHERE id=?
                        """,
                        (verdict, str(summary_path), json.dumps(payload, sort_keys=True), now, item_id),
                    )
                    conn.commit()
                    aggregate = _aggregate_finished_parent(root, item["parent_task_id"])
                    return {"finished": True, "status": "done", "verdict": verdict, "reason": reason, "aggregate": aggregate}

            attempt = int(item["attempt_count"] or 0) + 1
            payload["run_smoke_exit_code"] = exit_code
            payload["prior_failure"] = payload.get("prior_failure") or "summary_missing"
            terminal_stopped = _stop_terminal_slot_for_release(root, item["claimed_by"])
            if terminal_stopped is not None:
                payload["terminal_stopped_on_release"] = terminal_stopped
            if attempt < MAX_WORK_ITEM_RETRIES:
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='pending', attempt_count=?, claimed_by=NULL,
                        payload_json=?, updated_at=?
                    WHERE id=?
                    """,
                    (attempt, json.dumps(payload, sort_keys=True), now, item_id),
                )
                status = "pending"
                verdict = None
            else:
                payload["final_failure"] = "summary_missing_retries_exhausted"
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='failed', verdict='INVALID', claimed_by=NULL,
                        payload_json=?, updated_at=?
                    WHERE id=?
                    """,
                    (json.dumps(payload, sort_keys=True), now, item_id),
                )
                status = "failed"
                verdict = "INVALID"
            conn.commit()
            aggregate = _aggregate_finished_parent(root, item["parent_task_id"]) if status == "failed" else None
            return {"finished": True, "status": status, "verdict": verdict, "attempt": attempt, "aggregate": aggregate}

    return _with_sqlite_retry(_finish)


def _phase_from_task_kind(kind: str) -> str:
    raw = kind.replace("backtest_", "").upper()
    return {"P35": "P3.5"}.get(raw, raw)


def _aggregate_finished_parent(root: Path, parent_task_id: str | None) -> dict[str, Any] | None:
    if not parent_task_id:
        return None
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        summary = conn.execute(
            """
            SELECT COUNT(*) AS total,
                   SUM(CASE WHEN status='done' OR status='failed' THEN 1 ELSE 0 END) AS finished
            FROM work_items
            WHERE parent_task_id=?
            """,
            (parent_task_id,),
        ).fetchone()
        if not summary or int(summary["total"] or 0) == 0 or summary["total"] != summary["finished"]:
            return None
        parent = conn.execute("SELECT * FROM tasks WHERE id=?", (parent_task_id,)).fetchone()
        if not parent or parent["status"] == "done":
            return None
        wis = conn.execute("SELECT * FROM work_items WHERE parent_task_id=?", (parent_task_id,)).fetchall()
        phase = _phase_from_task_kind(parent["kind"])
        pass_symbols = [w["symbol"] for w in wis if w["verdict"] == "PASS"]
        p2_profit_skipped: list[dict[str, Any]] = []
        if phase == "P2":
            surviving, p2_profit_skipped = farmctl._filter_p2_profitable_symbols(conn, parent_task_id, pass_symbols)
        else:
            surviving = pass_symbols
        verdict = "PASS" if surviving else "STRATEGY_FAIL"
        classification: dict[str, Any] = {
            "verdict": verdict,
            "surviving_symbols": surviving,
            "counts_by_verdict": {
                v: sum(1 for w in wis if w["verdict"] == v)
                for v in ("PASS", "FAIL", "INVALID")
            },
            "source": "terminal_worker_aggregate",
        }
        if p2_profit_skipped:
            classification["p2_p3_profit_filter_skipped"] = p2_profit_skipped
        parent_payload = _json_loads(parent["payload_json"])
        parent_payload["classification"] = classification
        parent_payload["completed_at_iso"] = now
        conn.execute(
            "UPDATE tasks SET status='done', payload_json=?, updated_at=? WHERE id=?",
            (json.dumps(parent_payload, sort_keys=True), now, parent_task_id),
        )
        conn.commit()

    auto_next = None
    if verdict == "PASS":
        next_map = {"P2": "P3", "P3": "P3.5", "P3.5": "P4"}
        next_phase = next_map.get(phase)
        if next_phase and next_phase in farmctl.SUPPORTED_BACKTEST_PHASES:
            npp_kind = next_phase.lower().replace(".", "")
            with farmctl.connect(root) as conn:
                existing = conn.execute(
                    "SELECT id FROM tasks WHERE kind=? AND payload_json LIKE ?",
                    (f"backtest_{npp_kind}", f"%\"ea_id\": \"{parent_payload.get('ea_id')}\"%"),
                ).fetchone()
            if not existing:
                enq = farmctl.enqueue_backtest(root, parent_task_id, next_phase)
                if enq.get("enqueued"):
                    auto_next = {
                        "phase": next_phase,
                        "task_id": enq.get("task_id"),
                        "work_items_created": len(enq.get("work_items_created", [])),
                    }
    return {
        "parent_task_id": parent_task_id,
        "phase": phase,
        "verdict": verdict,
        "surviving_symbols": surviving,
        "auto_next": auto_next,
    }


def _run_claimed_item(root: Path, item: dict[str, Any], terminal: str, timeout_seconds: int) -> dict[str, Any]:
    with farmctl.connect(root) as conn:
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (item["id"],)).fetchone()
    if not row:
        return {"action": "missing_item", "item_id": item["id"]}
    spawn = farmctl._spawn_work_item_runner(root, row, terminal)
    now = farmctl.utc_now()
    if not spawn.get("spawned"):
        if spawn.get("pending_runner"):
            payload = _json_loads(row["payload_json"])
            payload.update({
                "verdict_reason": spawn.get("reason"),
                "log_path": spawn.get("log_path"),
                "report_root": spawn.get("report_root"),
            })
            with farmctl.connect(root) as conn:
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='done', verdict='PENDING_RUNNER', claimed_by=NULL,
                        payload_json=?, updated_at=?
                    WHERE id=?
                    """,
                    (json.dumps(payload, sort_keys=True), now, item["id"]),
                )
                conn.commit()
            return {
                "action": "pending_runner",
                "item_id": item["id"],
                "reason": spawn.get("reason"),
                "aggregate": _aggregate_finished_parent(root, row["parent_task_id"]),
            }
        with farmctl.connect(root) as conn:
            conn.execute(
                "UPDATE work_items SET status='failed', verdict='INVALID', claimed_by=NULL, updated_at=? WHERE id=?",
                (now, item["id"]),
            )
            conn.commit()
        return {"action": "spawn_failed", "item_id": item["id"], "reason": spawn.get("reason")}

    payload = _json_loads(row["payload_json"])
    payload.update({
        "started_at_iso": now,
        "pid": spawn["pid"],
        "log_path": spawn["log_path"],
        "report_root": spawn["report_root"],
        "ea_dir_name": spawn["ea_dir_name"],
        "terminal": terminal,
        "expected_trades_per_year_per_symbol": spawn.get("expected_trades_per_year_per_symbol"),
        "smoke_year_count": spawn.get("smoke_year_count"),
        "effective_min_trades": spawn.get("effective_min_trades"),
        "phase_runner": spawn.get("phase_runner"),
    })
    def _record_spawn() -> None:
        with farmctl.connect(root) as conn:
            conn.execute(
                "UPDATE work_items SET payload_json=?, updated_at=? WHERE id=? AND status='active'",
                (json.dumps(payload, sort_keys=True), now, item["id"]),
            )
            conn.commit()

    _with_sqlite_retry(_record_spawn)

    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline and farmctl._pid_exists(spawn["pid"]):
        if _STOP:
            return {"action": "shutdown_waiting_for_child", "item_id": item["id"], "pid": spawn["pid"]}
        ownership = _work_item_ownership(root, item["id"], terminal)
        if not ownership.get("owned"):
            child_stopped = farmctl._stop_pid(spawn["pid"])
            terminal_stopped = _stop_terminal_slot_for_release(root, terminal)
            return {
                "action": "external_release_observed",
                "item_id": item["id"],
                "pid": spawn["pid"],
                "child_stopped": child_stopped,
                "terminal_stopped": terminal_stopped,
                **ownership,
            }
        if _smoke_terminal_exit_stalled(item, payload):
            farmctl._stop_pid(spawn["pid"])
            break
        time.sleep(2.0)
    if farmctl._pid_exists(spawn["pid"]):
        farmctl._stop_pid(spawn["pid"])
        exit_code = None
    else:
        exit_code = 0
    return {"action": "finished", "item_id": item["id"], **_finish_work_item(root, item["id"], exit_code)}


def run_loop(root: Path, terminal: str, timeout_seconds: int) -> int:
    signal.signal(signal.SIGINT, _handle_stop)
    signal.signal(signal.SIGTERM, _handle_stop)
    released = release_stale_claims_for_terminal(root, terminal)
    if released:
        print(json.dumps({"event": "released_stale_claims", "terminal": terminal, "item_ids": released}), flush=True)
    while not _STOP:
        claim = claim_atomic(root, terminal)
        if not claim.get("claimed"):
            time.sleep(POLL_SLEEP_SECONDS)
            continue
        item = claim["item"]
        print(json.dumps({"event": "claimed", "terminal": terminal, "item_id": item["id"]}), flush=True)
        result = _run_claimed_item(root, item, terminal, timeout_seconds)
        print(json.dumps({"event": "run_result", "terminal": terminal, **result}, sort_keys=True), flush=True)
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--terminal", required=True, choices=farmctl.MT5_TERMINALS)
    parser.add_argument("--root", type=Path, default=farmctl.DEFAULT_ROOT)
    parser.add_argument("--timeout-minutes", type=float, default=30.0)
    args = parser.parse_args(argv)
    return run_loop(args.root, args.terminal, int(args.timeout_minutes * 60))


if __name__ == "__main__":
    raise SystemExit(main())
