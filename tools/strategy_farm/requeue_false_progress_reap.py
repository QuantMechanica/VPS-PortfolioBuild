#!/usr/bin/env python3
"""Requeue work items that a NO_FORWARD_PROGRESS reap killed while they were demonstrably running.

Why this needs its own operator
-------------------------------
The reaper records a harness kill as INFRA_FAIL rather than a strategy FAIL, and its comment says
why: "so the stranded-INFRA sweep can requeue the pair instead of freezing it at a terminal strategy
FAIL" (farmctl.py, WP-4). That sweep has no caller. `requeue_stranded_infra.py` is not attached to
any scheduled task, and `QM_StrategyFarm_Repair_Hourly` is Disabled. So the row stays failed forever
and the reaper's stated contract is unfulfilled -- the third mechanism found this month whose design
assumes an operator that does not exist.

Eligibility is deliberately narrow
----------------------------------
A row qualifies only if ALL of the following hold. This is not a general INFRA requeue.

  1. status='failed' and verdict='INFRA_FAIL'
  2. payload reap_reason == 'NO_FORWARD_PROGRESS'  (never the absolute ceiling: that one really did
     run out of budget)
  3. the row was killed BEFORE its absolute ceiling -- age_min < absolute_ceiling_min
  4. an artifact under the row's own contract roots was written INSIDE the reaper's blind window --
     strictly after the progress timestamp it acted on, at least PROOF_MARGIN_SEC later, and at or
     before the kill. That is the proof the run was alive: the detector said "nothing since T", and
     a file written between T and the kill says otherwise.

Condition 4 is the whole point. Without it this would be a blind retry loop, which is exactly what
the recovery-cap rules forbid.

The upper bound in condition 4 is not decoration. A first draft accepted any artifact newer than the
progress timestamp, and on a dry run that admitted two rows it should not have: QM5_12855 was reaped
on 2026-08-14 and "proved alive" by a file from 2026-08-18 -- a later run of the same EA, four days
after the kill -- and QM5_21514's proof was the very artifact the reaper had already seen, one whose
sub-second part alone put it past a truncated timestamp. Both would have been requeued on evidence
about something else. Hence: after the blind window opens, before the kill, and by a margin.

Discipline is the same as expedite_batch_rows.py: mutation lock, BEGIN IMMEDIATE, every row re-read
and revalidated inside the transaction, guarded UPDATE, exact rowcount assertion, journal.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
MARKER = "false_progress_reap_requeue"
REASON = "no-forward-progress-reap-with-live-tester-session"
JOURNAL_SCHEMA = "qm.false-progress-requeue-journal/v1"


class RequeueError(RuntimeError):
    pass


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def payload_sha256(payload_json: str | None) -> str:
    return hashlib.sha256((payload_json or "").encode("utf-8")).hexdigest()


def _lock(path: Path):
    from factory_mutation_lock import FactoryMutationLock

    return FactoryMutationLock(path, owner="requeue_false_progress_reap")


PROOF_MARGIN_SEC = 30


def _as_utc(value: str | None) -> dt.datetime | None:
    try:
        parsed = dt.datetime.fromisoformat(str(value))
    except (TypeError, ValueError):
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=dt.UTC)


def artifact_inside_blind_window(payload: dict[str, Any], after_iso: str) -> dict[str, Any] | None:
    """An artifact written between the reaper's last-seen progress and its kill.

    Bounded on BOTH sides on purpose -- see the module docstring. Anything after the kill belongs to
    a different run, and anything inside PROOF_MARGIN_SEC of the progress timestamp may be the same
    artifact the reaper already counted, seen through a truncated timestamp.
    """
    pe = payload.get("progress_evidence") or {}
    ext = pe.get("external_report_progress") or {}
    roots = [Path(r) for r in (ext.get("contract_roots") or []) if r]
    after = _as_utc(after_iso)
    killed = _as_utc(payload.get("killed_at"))
    if after is None or killed is None:
        return None
    lower = after + dt.timedelta(seconds=PROOF_MARGIN_SEC)
    if lower >= killed:
        return None
    best: tuple[dt.datetime, Path] | None = None
    for root in roots:
        if not root.is_dir():
            continue
        for path in root.rglob("*"):
            try:
                if not path.is_file():
                    continue
                mtime = dt.datetime.fromtimestamp(path.stat().st_mtime, dt.UTC)
            except OSError:
                continue
            if lower <= mtime <= killed and (best is None or mtime > best[0]):
                best = (mtime, path)
    if best is None:
        return None
    return {"at_utc": best[0].replace(microsecond=0).isoformat(), "path": str(best[1]),
            "window_start_utc": lower.replace(microsecond=0).isoformat(),
            "window_end_utc": killed.replace(microsecond=0).isoformat()}


def candidates(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    conn.row_factory = sqlite3.Row
    out: list[dict[str, Any]] = []
    for row in conn.execute(
            "SELECT id, ea_id, symbol, phase, status, verdict, attempt_count, payload_json "
            "FROM work_items WHERE status='failed' AND verdict='INFRA_FAIL'"):
        payload = json.loads(row["payload_json"] or "{}")
        if payload.get("reap_reason") != "NO_FORWARD_PROGRESS":
            continue
        if payload.get(MARKER):
            continue
        pe = payload.get("progress_evidence") or {}
        progress_at = pe.get("progress_at")
        blockers: list[str] = []
        try:
            age = float(payload.get("active_age_min") or 0.0)
            ceiling = float(payload.get("absolute_ceiling_min") or 0.0)
        except (TypeError, ValueError):
            age, ceiling = 0.0, 0.0
        if ceiling and age >= ceiling:
            blockers.append(f"killed at its absolute ceiling ({age:.1f} >= {ceiling:.0f} min)")
        proof = artifact_inside_blind_window(payload, progress_at) if progress_at else None
        if proof is None:
            blockers.append("no artifact inside the reaper blind window: not provably alive")
        out.append({
            "work_item_id": row["id"], "ea_id": row["ea_id"], "symbol": row["symbol"],
            "phase": row["phase"], "attempt_count": row["attempt_count"],
            "reaper_progress_at": progress_at,
            "reaper_stalled_min": pe.get("stalled_min"),
            "active_age_min": age, "absolute_ceiling_min": ceiling,
            "liveness_proof": proof,
            "payload_sha256": payload_sha256(row["payload_json"]),
            "blockers": blockers,
        })
    return out


def plan(db: Path) -> dict[str, Any]:
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=30)
    try:
        rows = candidates(conn)
    finally:
        conn.close()
    eligible = [r for r in rows if not r["blockers"]]
    return {"mode": "DRY_RUN", "at_utc": utc_now(), "examined": len(rows),
            "eligible": len(eligible), "rows": rows,
            "status": "READY_FOR_APPLY" if eligible else "NOTHING_TO_DO"}


def apply(db: Path, lock_path: Path, journal_out: Path) -> dict[str, Any]:
    pre = plan(db)
    if pre["status"] != "READY_FOR_APPLY":
        raise RequeueError(f"dry run is {pre['status']}; refusing to apply")
    expected = {r["work_item_id"]: r for r in pre["rows"] if not r["blockers"]}
    with _lock(lock_path):
        conn = sqlite3.connect(str(db), timeout=60)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("BEGIN IMMEDIATE")
            entries: list[dict[str, Any]] = []
            changed = 0
            for wid, exp in expected.items():
                row = conn.execute(
                    "SELECT status, verdict, payload_json FROM work_items WHERE id=?",
                    (wid,)).fetchone()
                if row is None:
                    raise RequeueError(f"{wid}: row vanished between plan and apply")
                if row["status"] != "failed" or row["verdict"] != "INFRA_FAIL":
                    raise RequeueError(
                        f"{wid}: moved to {row['status']!r}/{row['verdict']!r} since planning")
                before = payload_sha256(row["payload_json"])
                if before != exp["payload_sha256"]:
                    raise RequeueError(f"{wid}: payload changed since planning")
                payload = json.loads(row["payload_json"] or "{}")
                payload[MARKER] = {
                    "reason": REASON, "applied_at_utc": utc_now(),
                    "pre_image_payload_sha256": before,
                    "reaper_progress_at": exp["reaper_progress_at"],
                    "liveness_proof": exp["liveness_proof"],
                }
                # Clear the kill bookkeeping so the next claim starts clean; keep the evidence
                # of what happened inside the marker above.
                for key in ("reap_reason", "killed_at", "verdict_reason", "progress_evidence",
                            "reason_classes", "terminal_stopped", "worker_stopped",
                            "claimed_at_iso", "claimed_by_worker_pid", "pid", "worker_pid",
                            "started_at_iso", "active_age_min"):
                    payload.pop(key, None)
                new_json = json.dumps(payload, sort_keys=True)
                cur = conn.execute(
                    "UPDATE work_items SET status='pending', verdict=NULL, claimed_by=NULL, "
                    "payload_json=?, updated_at=? "
                    "WHERE id=? AND status='failed' AND verdict='INFRA_FAIL'",
                    (new_json, utc_now(), wid))
                changed += cur.rowcount
                entries.append({"work_item_id": wid, "ea_id": exp["ea_id"],
                                "symbol": exp["symbol"], "phase": exp["phase"],
                                "before_payload_sha256": before,
                                "after_payload_sha256": payload_sha256(new_json),
                                "liveness_proof": exp["liveness_proof"]})
            if changed != len(expected):
                raise RequeueError(f"rowcount assertion failed: {changed} != {len(expected)}")
            journal = {"schema_version": JOURNAL_SCHEMA, "applied_at_utc": utc_now(),
                       "reason": REASON, "db": str(db), "entries": entries,
                       "changed_rows": changed}
            journal_out.parent.mkdir(parents=True, exist_ok=True)
            journal_out.write_text(json.dumps(journal, indent=1, sort_keys=True) + "\n",
                                   encoding="utf-8")
            conn.commit()
            return {"mode": "APPLY", "status": "APPLIED", "changed_rows": changed,
                    "journal": str(journal_out)}
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()


def verify(db: Path, journal_path: Path) -> dict[str, Any]:
    journal = json.loads(journal_path.read_text(encoding="utf-8"))
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    try:
        states = []
        for e in journal.get("entries") or []:
            row = conn.execute(
                "SELECT status, claimed_by, verdict, attempt_count FROM work_items WHERE id=?",
                (e["work_item_id"],)).fetchone()
            states.append({"work_item_id": e["work_item_id"], "symbol": e["symbol"],
                           "status": row["status"] if row else "missing",
                           "terminal": row["claimed_by"] if row else None,
                           "verdict": row["verdict"] if row else None})
        return {"mode": "VERIFY", "rows": len(states), "states": states,
                "accepted": all(s["status"] in {"pending", "active", "done"} for s in states)}
    finally:
        conn.close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--mutation-lock", type=Path, default=DEFAULT_LOCK)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--journal-out", type=Path)
    ap.add_argument("--verify", type=Path)
    args = ap.parse_args()
    if args.verify:
        print(json.dumps(verify(args.db, args.verify), indent=1))
        return 0
    if args.apply:
        if not args.journal_out:
            raise RequeueError("--apply requires --journal-out")
        print(json.dumps(apply(args.db, args.mutation_lock, args.journal_out), indent=1))
        return 0
    print(json.dumps(plan(args.db), indent=1, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
