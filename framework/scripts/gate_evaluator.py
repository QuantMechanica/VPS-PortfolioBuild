#!/usr/bin/env python3
"""Evaluate completed MT5 worker-pool jobs and drive next actions.

Scope (QUA-1579):
- PASS path: mark processed and enqueue next-phase job(s)
- FAIL/INVALID infra path: bounded retry + terminal failure state
- FAIL strategy path (MIN_TRADES_NOT_MET): block + dispatch zero-trades escalation
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PHASE_SEQUENCE = ["P1", "P2", "P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8"]
INFRA_RETRY_TOKENS = ("no_summary_json:rc=1", "REPORT_MISSING")
ZERO_TRADES_TOKEN = "MIN_TRADES_NOT_MET"
ZERO_TRADES_AGENT_ID = "8ba981d2"


@dataclass
class EvalResult:
    processed: int = 0
    pass_count: int = 0
    requeued_count: int = 0
    failed_terminal_count: int = 0
    blocked_strategy_count: int = 0
    escalations_created: int = 0


def utc_now_iso() -> str:
    return datetime.now(tz=timezone.utc).isoformat()


def _column_exists(conn: sqlite3.Connection, table: str, column: str) -> bool:
    rows = conn.execute(f"PRAGMA table_info({table})").fetchall()
    return any(str(row[1]) == column for row in rows)


def ensure_columns(conn: sqlite3.Connection) -> None:
    if not _column_exists(conn, "jobs", "verdict_processed_at"):
        conn.execute("ALTER TABLE jobs ADD COLUMN verdict_processed_at TEXT")
    if not _column_exists(conn, "jobs", "escalation_issue_id"):
        conn.execute("ALTER TABLE jobs ADD COLUMN escalation_issue_id TEXT")
    conn.commit()


def next_phase(phase: str) -> str | None:
    normalized = str(phase or "").strip()
    try:
        idx = PHASE_SEQUENCE.index(normalized)
    except ValueError:
        return None
    if idx >= len(PHASE_SEQUENCE) - 1:
        return None
    return PHASE_SEQUENCE[idx + 1]


def is_infra_retry_reason(text: str) -> bool:
    blob = str(text or "")
    return any(token in blob for token in INFRA_RETRY_TOKENS)


def is_zero_trades_reason(text: str) -> bool:
    return ZERO_TRADES_TOKEN in str(text or "")


def create_zero_trades_issue(
    *,
    base_url: str,
    company_id: str,
    project_id: str,
    parent_issue_id: str | None,
    job: dict[str, Any],
    dry_run: bool,
) -> str | None:
    title = f"Zero-Trades recovery: {job['ea_id']} {job['phase']} {job['symbol']}"
    body = (
        "Auto-created by gate_evaluator.py after strategy-level FAIL.\n\n"
        f"- ea_id: {job['ea_id']}\n"
        f"- phase: {job['phase']}\n"
        f"- symbol: {job['symbol']}\n"
        f"- reason: {job.get('invalidation_reason') or job.get('verdict')}\n"
        f"- result_path: {job.get('result_path') or ''}\n"
        f"- source_job_id: {job['job_id']}\n"
    )
    if dry_run:
        return "DRY_RUN"
    payload: dict[str, Any] = {
        "companyId": company_id,
        "projectId": project_id,
        "parentId": parent_issue_id,
        "title": title,
        "description": body,
        "priority": "high",
        "assigneeAgentId": ZERO_TRADES_AGENT_ID,
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}/api/issues",
        data=data,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            response = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError):
        return None
    return str(response.get("id") or response.get("identifier") or "")


def _fetch_ready_rows(conn: sqlite3.Connection, limit: int) -> list[dict[str, Any]]:
    rows = conn.execute(
        """
        SELECT
          job_id, ea_id, version, symbol, period, year, phase, sub_gate_config_hash,
          setfile_path, status, verdict, invalidation_reason, retry_count, result_path
        FROM jobs
        WHERE status='done' AND verdict_processed_at IS NULL
        ORDER BY finished_at ASC, enqueued_at ASC
        LIMIT ?
        """,
        (max(1, int(limit)),),
    ).fetchall()
    payload: list[dict[str, Any]] = []
    for row in rows:
        payload.append(
            {
                "job_id": str(row[0]),
                "ea_id": str(row[1]),
                "version": str(row[2]),
                "symbol": str(row[3]),
                "period": str(row[4]),
                "year": int(row[5]),
                "phase": str(row[6]),
                "sub_gate_config_hash": str(row[7]),
                "setfile_path": str(row[8]),
                "status": str(row[9]),
                "verdict": str(row[10] or ""),
                "invalidation_reason": str(row[11] or ""),
                "retry_count": int(row[12] or 0),
                "result_path": str(row[13] or ""),
            }
        )
    return payload


def _enqueue_next_job(conn: sqlite3.Connection, row: dict[str, Any], next_p: str, ts: str) -> None:
    next_hash = f"{row['ea_id']}|{row['version']}|{row['symbol']}|{next_p}|{row['year']}"
    new_job_id = f"{row['job_id']}::{next_p}"
    conn.execute(
        """
        INSERT OR IGNORE INTO jobs
        (job_id, ea_id, version, symbol, period, year, phase, sub_gate_config_hash, setfile_path,
         status, retry_count, enqueued_at, enqueued_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'queued', 0, ?, 'gate_evaluator')
        """,
        (
            new_job_id,
            row["ea_id"],
            row["version"],
            row["symbol"],
            row["period"],
            row["year"],
            next_p,
            next_hash,
            row["setfile_path"],
            ts,
        ),
    )


def evaluate(
    *,
    sqlite_path: Path,
    max_retries: int,
    limit: int,
    paperclip_base: str,
    company_id: str,
    project_id: str,
    parent_issue_id: str | None,
    dry_run: bool,
) -> EvalResult:
    result = EvalResult()
    conn = sqlite3.connect(str(sqlite_path))
    try:
        ensure_columns(conn)
        rows = _fetch_ready_rows(conn, limit)
        now = utc_now_iso()
        for row in rows:
            verdict = row["verdict"].upper()
            reason = row["invalidation_reason"]
            if verdict == "PASS":
                nxt = next_phase(row["phase"])
                if nxt is not None and not dry_run:
                    _enqueue_next_job(conn, row, nxt, now)
                if not dry_run:
                    conn.execute(
                        "UPDATE jobs SET verdict_processed_at=? WHERE job_id=?",
                        (now, row["job_id"]),
                    )
                result.pass_count += 1
                result.processed += 1
                continue

            if verdict in {"FAIL", "INVALID"} and is_infra_retry_reason(reason):
                retries = int(row["retry_count"]) + 1
                if retries < max_retries:
                    if not dry_run:
                        conn.execute(
                            """
                            UPDATE jobs
                            SET status='queued', retry_count=?, claimed_by=NULL, claimed_at=NULL,
                                started_at=NULL, finished_at=NULL, verdict=NULL, invalidation_reason=NULL,
                                result_path=NULL, verdict_processed_at=?
                            WHERE job_id=?
                            """,
                            (retries, now, row["job_id"]),
                        )
                    result.requeued_count += 1
                else:
                    if not dry_run:
                        conn.execute(
                            "UPDATE jobs SET status='failed_terminal', retry_count=?, verdict_processed_at=? WHERE job_id=?",
                            (retries, now, row["job_id"]),
                        )
                    result.failed_terminal_count += 1
                result.processed += 1
                continue

            if verdict == "FAIL" and is_zero_trades_reason(reason):
                issue_id = create_zero_trades_issue(
                    base_url=paperclip_base,
                    company_id=company_id,
                    project_id=project_id,
                    parent_issue_id=parent_issue_id,
                    job=row,
                    dry_run=dry_run,
                )
                if not dry_run:
                    conn.execute(
                        "UPDATE jobs SET status='blocked_strategy', escalation_issue_id=?, verdict_processed_at=? WHERE job_id=?",
                        (issue_id or "", now, row["job_id"]),
                    )
                result.blocked_strategy_count += 1
                if issue_id:
                    result.escalations_created += 1
                result.processed += 1
                continue

            if not dry_run:
                conn.execute("UPDATE jobs SET verdict_processed_at=? WHERE job_id=?", (now, row["job_id"]))
            result.processed += 1

        if not dry_run:
            conn.commit()
    finally:
        conn.close()
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Process completed MT5 queue jobs and roll gate decisions forward.")
    parser.add_argument("--sqlite", required=True, help="Path to mt5_queue.db")
    parser.add_argument("--max-retries", type=int, default=3, help="Infra retry cap")
    parser.add_argument("--limit", type=int, default=200, help="Max completed rows per tick")
    parser.add_argument("--paperclip-base", default="http://127.0.0.1:3100", help="Paperclip API base URL")
    parser.add_argument("--company-id", default="03d4dcc8-4cea-4133-9f68-90c0d99628fb")
    parser.add_argument("--project-id", default="71b6d994-70ba-4a28-bd62-732b42a9ea58")
    parser.add_argument("--parent-issue-id", default="", help="Optional parent issue for escalation issues")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    summary = evaluate(
        sqlite_path=Path(args.sqlite),
        max_retries=max(1, int(args.max_retries)),
        limit=max(1, int(args.limit)),
        paperclip_base=str(args.paperclip_base),
        company_id=str(args.company_id),
        project_id=str(args.project_id),
        parent_issue_id=str(args.parent_issue_id or "") or None,
        dry_run=bool(args.dry_run),
    )
    print(json.dumps(summary.__dict__, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
