"""Transfer the two idle Claude build tasks under OWNER's 2026-09-22 handover.

Dry-run by default. Writes only through the canonical router connection, in one
transaction, with an exact task/state/pin check and an append-only payload journal.
Never changes task scope, priority, verdict, artifact, gates or active work.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

REPO = Path("C:/QM/repo")
ROOT = Path("D:/QM/strategy_farm")
AUTHORITY = "decisions/2026-09-22_owner_codex_orchestration_takeover.md"
TASKS = (
    "67c45a2f-2b42-4813-a5c8-13704534cace",
    "6ae8518a-975b-4c0f-bb92-09e4cd36713b",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if not (REPO / AUTHORITY).is_file():
        raise RuntimeError("Durable OWNER handover record missing")
    sys.path.insert(0, str(REPO / "tools/strategy_farm"))
    import agent_router

    conn = agent_router.connect(ROOT)
    receipt = {"authority": AUTHORITY, "apply": args.apply, "rows": []}
    try:
        conn.execute("BEGIN IMMEDIATE" if args.apply else "BEGIN")
        for task_id in TASKS:
            row = conn.execute("SELECT * FROM agent_tasks WHERE id=?", (task_id,)).fetchone()
            if row is None:
                raise RuntimeError(f"Task missing: {task_id}")
            payload = json.loads(row["payload_json"])
            journal = payload.get("orchestration_handoff_journal", [])
            if any(item.get("authority") == AUTHORITY for item in journal):
                receipt["rows"].append({"task_id": task_id, "action": "already_transferred", "state": row["state"]})
                continue
            if (row["state"], row["task_type"], row["assigned_agent"], agent_router.decision_bound_agent(payload)) != (
                "TODO", "build_ea", "claude", "claude"
            ):
                raise RuntimeError(f"Task ownership/state changed: {task_id}")
            before = dict(row)
            now = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
            journal.append({"authority": AUTHORITY, "at_utc": now, "from_agent": "claude", "to_agent": "codex",
                            "previous_updated_at": row["updated_at"],
                            "previous_router_hold": payload.pop("router_decision_bound_hold", None)})
            payload["orchestration_handoff_journal"] = journal
            payload[agent_router.DECISION_BOUND_PAYLOAD_FIELD] = "codex"
            payload["orchestrator_handoff_note"] = (
                "Codex now orchestrates. Resume the existing source and the exact returned-build defect in the verdict; "
                "do not repeat finished work. Worktree/pathspec publication and governed COMPILE_EA remain required. "
                "Independent review remains required; Claude autonomous work is paused by OWNER."
            )
            if args.apply:
                cursor = conn.execute(
                    "UPDATE agent_tasks SET assigned_agent=NULL, payload_json=?, updated_at=? "
                    "WHERE id=? AND state='TODO' AND assigned_agent='claude' AND updated_at=?",
                    (json.dumps(payload, sort_keys=True), now, task_id, row["updated_at"]),
                )
                if cursor.rowcount != 1:
                    raise RuntimeError(f"Concurrent task change: {task_id}")
            receipt["rows"].append({"task_id": task_id, "action": "transferred" if args.apply else "would_transfer", "before": before})
        conn.commit() if args.apply else conn.rollback()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
    target = REPO / "docs/ops/evidence/2026-09-22_codex_orchestration_takeover" / (
        "build_task_transfer_applied.json" if args.apply else "build_task_transfer_dry_run.json"
    )
    target.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"receipt": str(target), "rows": [{k: v for k, v in r.items() if k != "before"} for r in receipt["rows"]]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
