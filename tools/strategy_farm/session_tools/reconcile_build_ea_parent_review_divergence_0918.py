#!/usr/bin/env python3
"""Reconcile build_ea parent bookkeeping states with FAILED/BLOCKED gating cross-reviews.

Evidence-integrity follow-up of the 2026-09-18 review triage
(D:/QM/reports/ai_exchange/20260918_review_triage/REVIEW_TRIAGE.md section 1a):
three review_ea rows carry a BLOCKED card-defect verdict while their parent
build_ea row already sits in a positive terminal agent_tasks state (PASSED /
PIPELINE). This never overwrites the parent's state, verdict or artifact_path
(that history is exactly the "bereits durch ... Q03 PASS" provenance the
factory relies on to avoid duplicate build dispatch). It only appends a
compare-and-swapped, read-verifiable ledger entry to
payload.parent_review_divergence_ledger, cross-referencing the child
review_ea row and the live work_items disposition for the same ea_id, so a
future reader of the build_ea row is not misled by its bare state.

Dry-run is the default. --apply commits.
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

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
import agent_router  # noqa: E402
import farmctl  # noqa: E402

DEFAULT_ROOT = Path("D:/QM/strategy_farm")
SCHEMA = "qm.build-ea-parent-review-divergence-reconciliation/v1"
JOURNAL_SCHEMA = "qm.build-ea-parent-review-divergence-ledger/v1"

# The exact §1a mapping, taken verbatim from the triage doc (build_ea -> its
# gating review_ea) so this tool cannot silently drift onto unrelated rows.
DIVERGENCES: list[dict[str, str]] = [
    {
        "build_ea_id": "4b97cf9e-7a3c-452d-bc44-964a5a85555b",
        "review_ea_id": "da921b20-b31f-4530-aa87-15a05d4c818a",
        "ea_id": "QM5_33008",
        "expected_build_state": "PASSED",
    },
    {
        "build_ea_id": "e48c6a6c-1935-4945-9e47-e420f9fb15df",
        "review_ea_id": "33203a5c-13c9-4db5-b553-2cc23519125f",
        "ea_id": "QM5_34004",
        "expected_build_state": "PASSED",
    },
    {
        "build_ea_id": "2d3a6323-d804-427f-8387-ca78687a78b1",
        "review_ea_id": "c734242f-6787-4bda-a735-05758753a9f0",
        "ea_id": "QM5_33002",
        "expected_build_state": "PIPELINE",
    },
]


def _payload(row: sqlite3.Row) -> dict[str, Any]:
    try:
        value = json.loads(row["payload_json"] or "{}")
    except (TypeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _latest_q04_disposition(con: sqlite3.Connection, ea_id: str) -> dict[str, Any] | None:
    row = con.execute(
        """
        SELECT id, status, verdict, updated_at FROM work_items
        WHERE ea_id=? AND phase='Q04'
        ORDER BY updated_at DESC LIMIT 1
        """,
        (ea_id,),
    ).fetchone()
    if row is None:
        return None
    return {"id": row["id"], "status": row["status"], "verdict": row["verdict"], "updated_at": row["updated_at"]}


def build_plan(root: Path) -> dict[str, Any]:
    db = root / "state" / "farm_state.sqlite"
    con = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    rows = []
    try:
        for entry in DIVERGENCES:
            build_row = con.execute(
                "SELECT id, state, verdict, updated_at, payload_json FROM agent_tasks WHERE id=?",
                (entry["build_ea_id"],),
            ).fetchone()
            review_row = con.execute(
                "SELECT id, state, verdict, updated_at FROM agent_tasks WHERE id=?",
                (entry["review_ea_id"],),
            ).fetchone()
            if build_row is None or review_row is None:
                rows.append({**entry, "skip_reason": "row_not_found"})
                continue
            q04 = _latest_q04_disposition(con, entry["ea_id"])
            payload = _payload(build_row)
            already = any(
                isinstance(item, dict) and item.get("review_ea_id") == entry["review_ea_id"]
                for item in payload.get("parent_review_divergence_ledger", [])
                if isinstance(payload.get("parent_review_divergence_ledger"), list)
            )
            rows.append(
                {
                    **entry,
                    "build_state": build_row["state"],
                    "build_updated_at": build_row["updated_at"],
                    "review_state": review_row["state"],
                    "review_verdict": review_row["verdict"],
                    "review_verdict_sha256": hashlib.sha256(str(review_row["verdict"] or "").encode()).hexdigest(),
                    "review_updated_at": review_row["updated_at"],
                    "q04_disposition": q04,
                    "already_journaled": already,
                    "divergence_confirmed": build_row["state"] not in {"FAILED", "BLOCKED", "RECYCLE"}
                    and review_row["state"] in {"FAILED", "BLOCKED"},
                }
            )
    finally:
        con.close()
    return {"schema": SCHEMA, "root": str(root), "rows": rows}


def apply_plan(root: Path, plan: dict[str, Any], *, now: str | None = None) -> dict[str, Any]:
    at = now or dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    applied: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    for row in plan["rows"]:
        if row.get("skip_reason"):
            skipped.append({"build_ea_id": row["build_ea_id"], "reason": row["skip_reason"]})
            continue
        if row.get("already_journaled"):
            skipped.append({"build_ea_id": row["build_ea_id"], "reason": "already_journaled"})
            continue
        con = agent_router.connect(root)
        try:
            con.execute("BEGIN IMMEDIATE")
            current = con.execute(
                "SELECT * FROM agent_tasks WHERE id=?", (row["build_ea_id"],)
            ).fetchone()
            if current is None or current["updated_at"] != row["build_updated_at"] or current["state"] != row["build_state"]:
                con.rollback()
                skipped.append({"build_ea_id": row["build_ea_id"], "reason": "state_changed_since_plan"})
                continue
            payload = _payload(current)
            journal = payload.get("parent_review_divergence_ledger")
            if not isinstance(journal, list):
                journal = []
            q04 = row.get("q04_disposition") or {}
            journal.append(
                {
                    "schema": JOURNAL_SCHEMA,
                    "at_utc": at,
                    "source": "task_a4e82d86_review_triage_1a_reconciliation",
                    "review_ea_id": row["review_ea_id"],
                    "review_ea_state": row["review_state"],
                    "review_ea_verdict_sha256": row["review_verdict_sha256"],
                    "ea_id": row["ea_id"],
                    "finding": (
                        "review_ea gating cross-review found a card defect (state="
                        f"{row['review_state']}) after this build_ea row already reached a "
                        "positive agent_tasks bookkeeping state. Not corrected in place: "
                        "state/verdict/artifact_path are untouched, this is an additive "
                        "cross-reference only."
                    ),
                    "pipeline_authority_note": (
                        "agent_tasks.state on build_ea/review_ea is task-lifecycle bookkeeping, "
                        "not EA admission. Per CLAUDE.md 'pipeline verdicts come only from "
                        "pipeline evidence': the real judge is work_items. Latest Q04 disposition "
                        f"for {row['ea_id']}: {q04.get('verdict')!r} ({q04.get('status')!r}) at "
                        f"{q04.get('updated_at')!r}, work_item {q04.get('id')!r}."
                    ),
                    "divergence_disposition": "LEGITIMATE_NON_HAZARDOUS",
                }
            )
            payload["parent_review_divergence_ledger"] = journal
            cursor = con.execute(
                "UPDATE agent_tasks SET payload_json=?, updated_at=? WHERE id=? AND state=? AND updated_at=?",
                (json.dumps(payload, sort_keys=True), at, current["id"], current["state"], current["updated_at"]),
            )
            if cursor.rowcount != 1:
                con.rollback()
                skipped.append({"build_ea_id": row["build_ea_id"], "reason": "compare_and_swap_failed"})
                continue
            farmctl.event(
                con,
                "agent_task",
                current["id"],
                "parent_review_divergence_reconciled",
                {"review_ea_id": row["review_ea_id"], "ea_id": row["ea_id"], "disposition": "LEGITIMATE_NON_HAZARDOUS"},
            )
            con.commit()
            applied.append({"build_ea_id": row["build_ea_id"], "review_ea_id": row["review_ea_id"]})
        finally:
            con.close()
    return {"schema": SCHEMA, "mode": "apply", "applied": applied, "skipped": skipped}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    plan = build_plan(args.root)
    result = apply_plan(args.root, plan) if args.apply else {**plan, "mode": "plan"}
    text = json.dumps(result, indent=2, sort_keys=True, default=str) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8", newline="\n")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
