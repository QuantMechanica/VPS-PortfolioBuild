"""Visible, reversible quarantine for deterministic infrastructure poison pills.

Five consecutive INFRA_FAIL rows with one verdict_reason and no completed merit
run (PASS/FAIL) quarantine an (EA, symbol, phase) triple. Existing work_items are
normally left alone. The one terminal graveyard class,
``summary_missing_retries_exhausted``, is sealed as non-merit ``INVALID`` instead
of remaining pending forever. Release grants a fresh observation window:

  python tools/strategy_farm/poison_pill_quarantine.py release --ea-id QM5_11896 --symbol SP500.DWX --phase Q02
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
from pathlib import Path
from typing import Any

DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_THRESHOLD = 5
MERIT_VERDICTS = frozenset({"PASS", "FAIL"})
QUARANTINE_DDL = """
CREATE TABLE IF NOT EXISTS poison_pill_quarantine (
 ea_id TEXT NOT NULL, symbol TEXT NOT NULL, phase TEXT NOT NULL,
 active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),
 verdict_reason TEXT NOT NULL, consecutive_failures INTEGER NOT NULL,
 successes_ever INTEGER NOT NULL, evidence_path TEXT,
 quarantined_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 released_at TEXT, release_note TEXT,
 PRIMARY KEY(ea_id,symbol,phase))
"""
SUMMARY_MISSING_EXHAUSTED = "summary_missing_retries_exhausted"
SINGLE_OBSERVATION_KEY = "poison_pill_single_observation"
PRIORITY_OVERRIDE_KEY = "poison_pill_priority_override"


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.execute(QUARANTINE_DDL)


def _reason(row: sqlite3.Row) -> str:
    try:
        payload = json.loads(row["payload_json"] or "{}")
    except (TypeError, ValueError):
        payload = {}
    if not isinstance(payload, dict):
        payload = {}
    return str(payload.get("verdict_reason") or payload.get("final_failure") or "").strip()


def _evidence(row: sqlite3.Row) -> str | None:
    if row["evidence_path"]:
        return str(row["evidence_path"])
    try:
        payload = json.loads(row["payload_json"] or "{}")
    except (TypeError, ValueError):
        payload = {}
    if not isinstance(payload, dict):
        return None
    value = payload.get("summary_path") or payload.get("log_path") or payload.get("report_root")
    return str(value) if value else None


def diagnose_triple(
    conn: sqlite3.Connection, ea_id: str, symbol: str, phase: str,
    *, threshold: int = DEFAULT_THRESHOLD,
) -> dict[str, Any]:
    existing = conn.execute(
        "SELECT released_at FROM poison_pill_quarantine WHERE ea_id=? AND symbol=? AND phase=?",
        (ea_id, symbol, phase),
    ).fetchone()
    released_at = str(existing["released_at"]) if existing and existing["released_at"] else None
    rows = conn.execute(
        """SELECT id,status,verdict,evidence_path,payload_json,updated_at FROM work_items
           WHERE ea_id=? AND symbol=? AND phase=? AND verdict IS NOT NULL
           ORDER BY updated_at DESC,id DESC""",
        (ea_id, symbol, phase),
    ).fetchall()
    successes = sum(1 for row in rows if str(row["verdict"] or "").upper() in MERIT_VERDICTS)
    streak_reason, streak, evidence_path = "", 0, None
    for row in rows:
        if released_at and str(row["updated_at"]) <= released_at:
            break
        if str(row["verdict"] or "").upper() != "INFRA_FAIL":
            break
        reason = _reason(row)
        if not reason:
            break
        if not streak_reason:
            streak_reason, evidence_path = reason, _evidence(row)
        if reason != streak_reason:
            break
        streak += 1
    return {
        "ea_id": ea_id, "symbol": symbol, "phase": phase,
        "eligible": successes == 0 and streak >= threshold and bool(streak_reason),
        "verdict_reason": streak_reason, "consecutive_failures": streak,
        "successes_ever": successes, "evidence_path": evidence_path,
        "released_at": released_at,
    }


def scan(conn: sqlite3.Connection, *, threshold: int = DEFAULT_THRESHOLD) -> list[dict[str, Any]]:
    ensure_schema(conn)
    triples = conn.execute(
        "SELECT DISTINCT ea_id,symbol,phase FROM work_items WHERE status='pending'"
    ).fetchall()
    results = [
        diagnose_triple(conn, row["ea_id"], row["symbol"], row["phase"], threshold=threshold)
        for row in triples
    ]
    return [
        result for result in results
        if result["eligible"] and not _single_observation_pending(
            conn, result["ea_id"], result["symbol"], result["phase"]
        )
    ]


def _single_observation_pending(
    conn: sqlite3.Connection, ea_id: str, symbol: str, phase: str,
) -> bool:
    """Keep one explicitly protected pending row out of quarantine.

    Protection expires as soon as a worker stamps ``started_at_iso`` later than
    ``protected_at``. The separate priority override keeps the protected poison
    row behind healthy work without deleting an OWNER-set priority flag.
    """
    rows = conn.execute(
        """SELECT payload_json FROM work_items
           WHERE ea_id=? AND symbol=? AND phase=? AND status='pending'""",
        (ea_id, symbol, phase),
    ).fetchall()
    for row in rows:
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except (TypeError, ValueError):
            continue
        marker = payload.get(SINGLE_OBSERVATION_KEY) if isinstance(payload, dict) else None
        if not isinstance(marker, dict):
            continue
        protected_at = str(marker.get("protected_at") or "")
        started_at = str(payload.get("started_at_iso") or "")
        if protected_at and (not started_at or started_at <= protected_at):
            return True
    return False


def _seal_summary_missing_pending(
    conn: sqlite3.Connection, item: dict[str, Any], now: str,
) -> int:
    """Seal dead no-summary successors with a non-merit verdict."""
    if item["verdict_reason"] != SUMMARY_MISSING_EXHAUSTED:
        return 0
    changed = 0
    rows = conn.execute(
        """SELECT id,payload_json FROM work_items
           WHERE ea_id=? AND symbol=? AND phase=? AND status='pending'""",
        (item["ea_id"], item["symbol"], item["phase"]),
    ).fetchall()
    for row in rows:
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except (TypeError, ValueError):
            payload = {}
        if not isinstance(payload, dict):
            payload = {}
        payload["final_failure"] = SUMMARY_MISSING_EXHAUSTED
        payload["verdict_reason"] = "poison_pill:summary_missing_retries_exhausted"
        payload["verdict_taxonomy"] = "invalid"
        payload["poison_pill_disposition"] = {
            "sealed_at": now,
            "reason": "five_identical_infra_failures_no_merit_verdict",
            "verdict": "INVALID",
        }
        cur = conn.execute(
            """UPDATE work_items
               SET status='failed',verdict='INVALID',payload_json=?,updated_at=?
               WHERE id=? AND status='pending'""",
            (json.dumps(payload, sort_keys=True), now, row["id"]),
        )
        changed += cur.rowcount
    return changed


def refresh_pending(
    conn: sqlite3.Connection, *, threshold: int = DEFAULT_THRESHOLD
) -> list[dict[str, Any]]:
    """Upsert poison state only; never mutate work_items."""
    found = scan(conn, threshold=threshold)
    now = utc_now()
    for item in found:
        conn.execute(
            """INSERT INTO poison_pill_quarantine
               (ea_id,symbol,phase,active,verdict_reason,consecutive_failures,
                successes_ever,evidence_path,quarantined_at,updated_at,released_at,release_note)
               VALUES(?,?,?,1,?,?,?,?,?,?,NULL,NULL)
               ON CONFLICT(ea_id,symbol,phase) DO UPDATE SET
                active=1,verdict_reason=excluded.verdict_reason,
                consecutive_failures=excluded.consecutive_failures,
                successes_ever=excluded.successes_ever,evidence_path=excluded.evidence_path,
                quarantined_at=excluded.quarantined_at,updated_at=excluded.updated_at,
                released_at=NULL,release_note=NULL""",
            (item["ea_id"], item["symbol"], item["phase"], item["verdict_reason"],
             item["consecutive_failures"], item["successes_ever"], item["evidence_path"], now, now),
        )
        item["sealed_pending_rows"] = _seal_summary_missing_pending(conn, item, now)
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    sub = parser.add_subparsers(dest="command", required=True)
    scan_cmd = sub.add_parser("scan")
    scan_cmd.add_argument("--apply", action="store_true")
    scan_cmd.add_argument("--threshold", type=int, default=DEFAULT_THRESHOLD)
    scan_cmd.add_argument("--output", type=Path)
    release = sub.add_parser("release")
    release.add_argument("--ea-id", required=True)
    release.add_argument("--symbol", required=True)
    release.add_argument("--phase", required=True)
    release.add_argument("--note", default="fixed; released for retry")
    protect = sub.add_parser("protect-observation")
    protect.add_argument("--work-item-id", action="append", required=True)
    protect.add_argument("--note", required=True)
    args = parser.parse_args()
    with sqlite3.connect(args.db, timeout=30) as conn:
        conn.row_factory = sqlite3.Row
        ensure_schema(conn)
        if args.command == "scan":
            rows = refresh_pending(conn, threshold=args.threshold) if args.apply else scan(
                conn, threshold=args.threshold)
            if args.apply:
                conn.commit()
            document = json.dumps(
                {"threshold": args.threshold, "count": len(rows), "items": rows}, indent=2
            ) + "\n"
            if args.output:
                args.output.parent.mkdir(parents=True, exist_ok=True)
                args.output.write_text(document, encoding="utf-8")
                print(f"wrote {len(rows)} items to {args.output}")
            else:
                print(document, end="")
            return 0
        if args.command == "protect-observation":
            now = utc_now()
            changed = []
            for work_item_id in args.work_item_id:
                row = conn.execute(
                    "SELECT status,payload_json FROM work_items WHERE id=?", (work_item_id,)
                ).fetchone()
                if not row or row["status"] != "pending":
                    raise SystemExit(f"pending work item not found: {work_item_id}")
                payload = json.loads(row["payload_json"] or "{}")
                if not isinstance(payload, dict):
                    raise SystemExit(f"payload is not an object: {work_item_id}")
                payload[SINGLE_OBSERVATION_KEY] = {
                    "protected_at": now,
                    "note": args.note,
                }
                payload[PRIORITY_OVERRIDE_KEY] = True
                cur = conn.execute(
                    """UPDATE work_items SET payload_json=?,updated_at=?
                       WHERE id=? AND status='pending'""",
                    (json.dumps(payload, sort_keys=True), now, work_item_id),
                )
                if cur.rowcount != 1:
                    raise SystemExit(f"concurrent work-item change: {work_item_id}")
                changed.append(work_item_id)
            conn.commit()
            print(json.dumps({"protected_at": now, "work_item_ids": changed}, indent=2))
            return 0
        now = utc_now()
        cur = conn.execute(
            """UPDATE poison_pill_quarantine SET active=0,released_at=?,release_note=?,updated_at=?
               WHERE ea_id=? AND symbol=? AND phase=? AND active=1""",
            (now, args.note, now, args.ea_id, args.symbol, args.phase),
        )
        conn.commit()
        if cur.rowcount != 1:
            raise SystemExit("no active quarantine matched the requested triple")
        print(f"released {args.ea_id} {args.symbol} {args.phase} at {now}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
