"""Advance an EA's evidence chain one gate at a time, in cascade order.

WHY THIS EXISTS
---------------
Qualification (`ftmo_qualification.py`) requires every strict phase to hold an
evidence file that exists and is NOT older than the deployed `.ex5`. When an EA
loses several phases at once — report directories deleted, or a rebuild that
post-dates all of them — the naive fix is to requeue every missing gate. That is
wrong and was tried on 2026-07-26: the pipeline is a cascade (Q04 consumes Q03's
summary, Q05 consumes Q04's), so workers claimed the deep gates first and they
died with SOURCE_SUMMARY_MISSING against evidence the requeue had just
invalidated.

`dispatch_tick` auto-enqueues the next phase on a PASS, but only when that phase
has no completed row yet; a stale `done PASS` row is not re-run. So a chain with
several stale-but-passing gates needs to be walked deliberately.

WHAT IT DOES
------------
For each requested EA it finds the SHALLOWEST phase whose evidence is missing or
older than the binary, verifies that every earlier phase is already fresh, and
requeues exactly that one gate. Idempotent: a phase already pending or active is
left alone, so the command can be run repeatedly to advance the chain.

Nothing is destroyed — the pre-flip row state is appended to the snapshot before
any write, and `--revert` restores every recorded row.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
EAS = Path(r"C:\QM\repo\framework\EAs")
SNAPSHOT = Path(r"D:\QM\reports\state\evidence_cascade_driver.json")
PHASES = ("Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q10")
RUNTIME_KEYS = (
    "pid", "started_at_iso", "log_path", "claimed_at_iso", "claimed_by_worker_pid",
    "commit_reservation_gb", "commit_reservation_until_utc", "terminal",
)


def ex5_mtime(ea_id: str) -> float | None:
    for directory in EAS.glob(f"{ea_id}_*"):
        for binary in directory.glob("*.ex5"):
            return binary.stat().st_mtime
    return None


def evidence_state(row: sqlite3.Row, binary_mtime: float) -> str:
    """fresh | stale | absent | norow"""
    if row is None:
        return "norow"
    path = row["evidence_path"]
    if not path:
        return "absent"
    p = Path(path)
    if not p.exists():
        return "absent"
    return "fresh" if p.stat().st_mtime >= binary_mtime else "stale"


def latest_row(conn: sqlite3.Connection, ea_id: str, phase: str, symbol: str):
    return conn.execute(
        "SELECT id, phase, symbol, status, verdict, evidence_path, payload_json "
        "FROM work_items WHERE ea_id=? AND phase=? AND symbol LIKE ? "
        "ORDER BY updated_at DESC LIMIT 1",
        (ea_id, phase, f"{symbol}%"),
    ).fetchone()


def plan_for(conn: sqlite3.Connection, ea_id: str, symbol: str) -> dict[str, Any]:
    binary_mtime = ex5_mtime(ea_id)
    if binary_mtime is None:
        return {"ea_id": ea_id, "symbol": symbol, "action": "no_ex5"}

    states: list[tuple[str, str, sqlite3.Row]] = []
    for phase in PHASES:
        row = latest_row(conn, ea_id, phase, symbol)
        states.append((phase, evidence_state(row, binary_mtime), row))

    # Anything already in flight means the chain is advancing; do not stack work.
    for phase, _state, row in states:
        if row is not None and row["status"] in ("pending", "active"):
            return {"ea_id": ea_id, "symbol": symbol, "action": "in_flight",
                    "phase": phase, "status": row["status"]}

    for phase, state, row in states:
        if state == "fresh":
            continue
        if state == "norow":
            return {"ea_id": ea_id, "symbol": symbol, "action": "needs_enqueue",
                    "phase": phase, "detail": "no work item exists for this phase"}
        return {"ea_id": ea_id, "symbol": symbol, "action": "requeue",
                "phase": phase, "row": row, "detail": state}

    return {"ea_id": ea_id, "symbol": symbol, "action": "complete"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ea", action="append", required=True,
                        help="EA_ID:SYMBOL, repeatable (e.g. QM5_11421:EURUSD)")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--revert", action="store_true")
    args = parser.parse_args()

    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    now = datetime.now(timezone.utc).isoformat()

    if args.revert:
        if not SNAPSHOT.exists():
            print("no snapshot to revert")
            return 1
        snap = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
        for row in snap.get("rows", []):
            conn.execute(
                "UPDATE work_items SET status=?, verdict=?, payload_json=?, updated_at=? "
                "WHERE id=?",
                (row["status"], row["verdict"], row["payload_json"], now, row["id"]),
            )
        conn.commit()
        print(f"reverted {len(snap.get('rows', []))} rows")
        return 0

    targets = []
    for spec in args.ea:
        ea_id, _, symbol = spec.partition(":")
        targets.append((ea_id.strip(), symbol.strip()))

    plans = [plan_for(conn, ea, sym) for ea, sym in targets]
    to_write = []
    for plan in plans:
        head = f"{plan['ea_id']:11} {plan['symbol']:8}"
        if plan["action"] == "requeue":
            print(f"{head} -> requeue {plan['phase']} (evidence {plan['detail']})")
            to_write.append(plan)
        elif plan["action"] == "in_flight":
            print(f"{head} -- {plan['phase']} already {plan['status']}, leaving alone")
        elif plan["action"] == "complete":
            print(f"{head} == every phase has evidence newer than the binary")
        elif plan["action"] == "needs_enqueue":
            print(f"{head} !! {plan['phase']}: {plan['detail']} — needs a real enqueue, "
                  f"not a requeue")
        else:
            print(f"{head} !! {plan['action']}")

    if not args.apply:
        print("\n(dry run — pass --apply)")
        return 0

    if not to_write:
        print("\nnothing to do")
        return 0

    existing = {"rows": []}
    if SNAPSHOT.exists():
        try:
            existing = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            pass
    for plan in to_write:
        existing["rows"].append({k: plan["row"][k] for k in
                                 ("id", "status", "verdict", "payload_json")})
    existing["updated_at_utc"] = now
    SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
    SNAPSHOT.write_text(json.dumps(existing, indent=2), encoding="utf-8")

    for plan in to_write:
        row = plan["row"]
        payload = json.loads(row["payload_json"] or "{}")
        for key in RUNTIME_KEYS:
            payload.pop(key, None)
        payload["requeue_reason"] = f"evidence_{plan['detail']}_cascade_step"
        payload["requeued_by"] = "evidence_cascade_driver"
        payload["priority_track"] = True
        payload["priority_reason"] = "ftmo_demo_book_evidence_chain"
        conn.execute(
            "UPDATE work_items SET status='pending', verdict=NULL, claimed_by=NULL, "
            "payload_json=?, updated_at=? WHERE id=? AND status NOT IN ('pending','active')",
            (json.dumps(payload, sort_keys=True), now, row["id"]),
        )
    conn.commit()
    print(f"\nrequeued {len(to_write)} gate(s); snapshot -> {SNAPSHOT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
