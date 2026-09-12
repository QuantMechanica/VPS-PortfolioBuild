#!/usr/bin/env python3
"""Classify and disposition stale BLOCKED agent tasks.

Dry-run is the default. Apply is intentionally class-scoped and bounded. It
never deletes a task, never changes a prior verdict/artifact, and appends the
transition record to ``payload.blocked_backlog_journal`` in the same SQLite
transaction as the state change.
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path
from typing import Any, Callable

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
import agent_router  # noqa: E402
import farmctl  # noqa: E402

DEFAULT_ROOT = Path("D:/QM/strategy_farm")
DEFAULT_CARDS = DEFAULT_ROOT / "artifacts" / "cards_approved"
SCHEMA = "qm.blocked-agent-task-sweeper/v1"
JOURNAL_SCHEMA = "qm.blocked-agent-task-disposition/v1"

VIDEO_RE = re.compile(r"video_analysis|router_human_lane_hold|OWNER-VID", re.I)
MAGIC_RE = re.compile(
    r"PRECONDITION_HOLD|D6_BUILD_IDENTITY|no magic rows|no active ea_id|MAGIC_ROWS_REQUIRED",
    re.I,
)
RETEST_RE = re.compile(r"RETEST\s+2026-08-21|live-state", re.I)
RECYCLE_CLOSE_RE = re.compile(
    r"approval withdrawn|CLAUDE CORRECTION|BLOCKED statt RECYCLE|re-?issue|rework",
    re.I,
)
FAILED_CLOSE_RE = re.compile(r"CLAUDE CLOSE.*(?:failed|failure|abgelehnt)", re.I | re.S)


def _payload(row: sqlite3.Row) -> dict[str, Any]:
    try:
        value = json.loads(row["payload_json"] or "{}")
    except (TypeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _ea_id(payload: dict[str, Any]) -> str | None:
    raw = payload.get("ea_id") or payload.get("ea_label")
    match = re.search(r"(?:QM5_)?(\d{4,5})", str(raw or ""), re.I)
    if match:
        return f"QM5_{match.group(1)}"
    matches = re.findall(r"QM5_\d{4,5}", json.dumps(payload), re.I)
    return matches[0].upper() if matches else None


def _card_for(ea_id: str | None, cards_dir: Path) -> Path | None:
    if not ea_id:
        return None
    matches = sorted(cards_dir.glob(f"{ea_id}_*.md"))
    return matches[0] if len(matches) == 1 else None


def _precheck(card: Path, repo: Path) -> dict[str, Any]:
    fm = farmctl.parse_card_frontmatter(card)
    return farmctl.magic_allocation_precheck(fm, repo_root=repo)


def _legacy_agy_requeue(payload: dict[str, Any]) -> bool:
    journal = payload.get("backlog_disposition_journal")
    if not isinstance(journal, list):
        return False
    return any(
        isinstance(entry, dict)
        and entry.get("decision") == "OWNER-DEC-BACKLOG-20260912"
        and entry.get("from_state") == "RECYCLE"
        and str(entry.get("previous_assigned_agent") or "").lower() in {"gemini", "agy"}
        for entry in journal
    )


def classify_row(
    row: sqlite3.Row,
    *,
    repo: Path = REPO,
    cards_dir: Path = DEFAULT_CARDS,
    precheck_fn: Callable[[Path, Path], dict[str, Any]] = _precheck,
) -> dict[str, Any]:
    payload = _payload(row)
    verdict = str(row["verdict"] or "")
    blob = json.dumps(payload, sort_keys=True) + " " + verdict
    base = {
        "task_id": row["id"],
        "state": row["state"],
        "assigned_agent": row["assigned_agent"],
        "task_type": row["task_type"],
        "updated_at": row["updated_at"],
        "title": payload.get("title"),
    }
    if VIDEO_RE.search(blob) or "video_analysis" in json.loads(
        row["required_skills_json"] or "[]"
    ):
        return {**base, "class": "VIDEO_HOLD", "disposition": "SKIP", "reason": "owned_by_release_video_analysis_holds"}
    if _legacy_agy_requeue(payload):
        return {**base, "class": "LEGACY_RESEARCH", "disposition": "FAILED", "reason": "legacy_agy_recycle_requeue_corrected_to_archive"}
    if (
        row["task_type"] == "research_strategy"
        and str(row["assigned_agent"] or "").lower() in {"gemini", "agy"}
    ):
        return {**base, "class": "LEGACY_RESEARCH", "disposition": "FAILED", "reason": "agy_backup_only_owner_2026_09_03"}
    if RECYCLE_CLOSE_RE.search(verdict):
        return {**base, "class": "TERMINAL_CLOSE", "disposition": "RECYCLE", "reason": "close_text_requests_rework"}
    if FAILED_CLOSE_RE.search(verdict):
        return {**base, "class": "TERMINAL_CLOSE", "disposition": "FAILED", "reason": "close_text_records_failed_review"}
    if RETEST_RE.search(blob):
        return {**base, "class": "LIVE_RETEST", "disposition": "ASSESS", "reason": "requires_current_live_state_assessment"}
    if MAGIC_RE.search(verdict):
        ea_id = _ea_id(payload)
        card = _card_for(ea_id, cards_dir)
        if card is None:
            return {**base, "class": "MAGIC_PRECONDITION", "disposition": "HOLD", "reason": "exact_approved_card_missing_or_ambiguous", "ea_id": ea_id}
        try:
            check = precheck_fn(card, repo)
        except Exception as exc:
            return {**base, "class": "MAGIC_PRECONDITION", "disposition": "HOLD", "reason": "fresh_precheck_error", "detail": repr(exc), "ea_id": ea_id, "card": str(card)}
        action = str(check.get("action") or "")
        if check.get("ready"):
            disposition, reason = "TODO", "fresh_precheck_ready"
        elif action == "GOVERNED_ALLOCATE":
            disposition, reason = "ALLOCATE", str(check.get("classification"))
        else:
            disposition, reason = "HOLD", str(check.get("classification"))
        return {
            **base,
            "class": "MAGIC_PRECONDITION",
            "disposition": disposition,
            "reason": reason,
            "ea_id": ea_id,
            "card": str(card),
            "precheck": check,
        }
    return {**base, "class": "DEPENDENCY_HOLD", "disposition": "HOLD", "reason": "recorded_dependency_or_owner_hold"}


def build_plan(
    root: Path,
    *,
    repo: Path = REPO,
    cards_dir: Path = DEFAULT_CARDS,
    precheck_fn: Callable[[Path, Path], dict[str, Any]] = _precheck,
    include_requeued_legacy: bool = False,
) -> dict[str, Any]:
    db = root / "state" / "farm_state.sqlite"
    con = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    try:
        rows = con.execute(
            "SELECT * FROM agent_tasks WHERE state IN ('BLOCKED','TODO') ORDER BY updated_at,id"
            if include_requeued_legacy
            else "SELECT * FROM agent_tasks WHERE state='BLOCKED' ORDER BY updated_at,id"
        ).fetchall()
    finally:
        con.close()
    findings = [
        classify_row(row, repo=repo, cards_dir=cards_dir, precheck_fn=precheck_fn)
        for row in rows
    ]
    if include_requeued_legacy:
        findings = [
            finding for finding in findings
            if finding["state"] == "BLOCKED" or finding["class"] == "LEGACY_RESEARCH"
        ]
    counts = collections.Counter((x["class"], x["disposition"]) for x in findings)
    return {
        "schema": SCHEMA,
        "mode": "plan",
        "blocked_count": sum(row["state"] == "BLOCKED" for row in findings),
        "included_requeued_legacy_count": sum(
            row["state"] == "TODO" and row["class"] == "LEGACY_RESEARCH"
            for row in findings
        ),
        "counts": {f"{key[0]}:{key[1]}": value for key, value in sorted(counts.items())},
        "rows": findings,
    }


def build_legacy_restore_plan(root: Path) -> dict[str, Any]:
    """Find only rows moved by this tool's superseded legacy-archive interpretation."""
    db = root / "state" / "farm_state.sqlite"
    con = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    try:
        rows = con.execute(
            "SELECT * FROM agent_tasks WHERE state='FAILED' ORDER BY updated_at,id"
        ).fetchall()
    finally:
        con.close()
    findings: list[dict[str, Any]] = []
    for row in rows:
        payload = _payload(row)
        journal = payload.get("blocked_backlog_journal")
        if not isinstance(journal, list) or not journal:
            continue
        last = journal[-1]
        if not isinstance(last, dict) or last.get("reason") != "legacy_agy_recycle_requeue_corrected_to_archive":
            continue
        findings.append({
            "task_id": row["id"],
            "state": "FAILED",
            "assigned_agent": row["assigned_agent"],
            "task_type": row["task_type"],
            "updated_at": row["updated_at"],
            "title": payload.get("title"),
            "class": "LEGACY_REQUEUE_RESTORE",
            "disposition": "TODO",
            "reason": "restore_concurrent_scope_update_2026_09_12_05_34_48Z",
        })
    return {
        "schema": SCHEMA,
        "mode": "plan",
        "blocked_count": 0,
        "included_requeued_legacy_count": len(findings),
        "counts": {"LEGACY_REQUEUE_RESTORE:TODO": len(findings)} if findings else {},
        "rows": findings,
    }


def apply_plan(
    root: Path,
    plan: dict[str, Any],
    *,
    apply_classes: set[str],
    limit: int,
    now: str | None = None,
) -> dict[str, Any]:
    allowed = {"MAGIC_PRECONDITION", "TERMINAL_CLOSE", "LEGACY_RESEARCH", "LEGACY_REQUEUE_RESTORE"}
    if not apply_classes or not apply_classes <= allowed:
        raise ValueError(f"apply_classes must be a non-empty subset of {sorted(allowed)}")
    if limit <= 0:
        raise ValueError("apply requires a positive --limit")
    at = now or dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    applied: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    for finding in plan["rows"]:
        if len(applied) >= limit:
            break
        if finding["class"] not in apply_classes:
            continue
        target = finding["disposition"]
        if finding["class"] == "MAGIC_PRECONDITION" and target != "TODO":
            skipped.append({"task_id": finding["task_id"], "reason": f"not_ready:{target}:{finding['reason']}"})
            continue
        if target not in {"TODO", "FAILED", "RECYCLE"}:
            skipped.append({"task_id": finding["task_id"], "reason": f"non_mutating_disposition:{target}"})
            continue
        con = agent_router.connect(root)
        try:
            con.execute("BEGIN IMMEDIATE")
            row = con.execute("SELECT * FROM agent_tasks WHERE id=?", (finding["task_id"],)).fetchone()
            expected_state = str(finding.get("state") or "BLOCKED")
            if row is None or row["state"] != expected_state:
                con.rollback()
                skipped.append({"task_id": finding["task_id"], "reason": "state_changed_since_plan"})
                continue
            payload = _payload(row)
            journal = payload.get("blocked_backlog_journal")
            if not isinstance(journal, list):
                journal = []
            entry = {
                "schema": JOURNAL_SCHEMA,
                "at_utc": at,
                "from_state": expected_state,
                "to_state": target,
                "class": finding["class"],
                "reason": finding["reason"],
                "previous_assigned_agent": row["assigned_agent"],
                "previous_verdict": row["verdict"],
                "previous_verdict_sha256": hashlib.sha256(str(row["verdict"] or "").encode()).hexdigest(),
            }
            journal.append(entry)
            payload["blocked_backlog_journal"] = journal
            payload[agent_router.DECISION_BOUND_PAYLOAD_FIELD] = "codex" if target == "TODO" else payload.get(agent_router.DECISION_BOUND_PAYLOAD_FIELD)
            cursor = con.execute(
                "UPDATE agent_tasks SET state=?, assigned_agent=?, payload_json=?, updated_at=? WHERE id=? AND state=?",
                (target, None if target == "TODO" else row["assigned_agent"], json.dumps(payload, sort_keys=True), at, row["id"], expected_state),
            )
            if cursor.rowcount != 1:
                con.rollback()
                skipped.append({"task_id": finding["task_id"], "reason": "compare_and_swap_failed"})
                continue
            farmctl.event(con, "agent_task", row["id"], "blocked_backlog_disposition", entry)
            if target in agent_router.LEASE_RELEASE_STATES:
                agent_router._release_task_lease(con, row["id"])
            con.commit()
            applied.append({"task_id": row["id"], "to_state": target, "class": finding["class"], "reason": finding["reason"]})
        finally:
            con.close()
    return {
        "schema": SCHEMA,
        "mode": "apply",
        "limit": limit,
        "apply_classes": sorted(apply_classes),
        "applied_count": len(applied),
        "applied": applied,
        "skipped": skipped,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--repo", type=Path, default=REPO)
    parser.add_argument("--cards-dir", type=Path, default=DEFAULT_CARDS)
    parser.add_argument("--apply-class", action="append", choices=("MAGIC_PRECONDITION", "TERMINAL_CLOSE", "LEGACY_RESEARCH", "LEGACY_REQUEUE_RESTORE"))
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--include-requeued-legacy",
        action="store_true",
        help="Also classify TODO rows whose append-only journal proves they were legacy agy RECYCLE rows",
    )
    parser.add_argument(
        "--restore-legacy-requeues",
        action="store_true",
        help="Select only the exact FAILED rows written by the superseded legacy-archive interpretation",
    )
    args = parser.parse_args(argv)
    plan = (
        build_legacy_restore_plan(args.root)
        if args.restore_legacy_requeues
        else build_plan(
            args.root,
            repo=args.repo,
            cards_dir=args.cards_dir,
            include_requeued_legacy=args.include_requeued_legacy,
        )
    )
    result = (
        apply_plan(args.root, plan, apply_classes=set(args.apply_class), limit=args.limit)
        if args.apply_class
        else plan
    )
    text = json.dumps(result, indent=2, sort_keys=True, default=str) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8", newline="\n")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
