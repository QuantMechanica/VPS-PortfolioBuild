#!/usr/bin/env python3
"""Read-only status snapshot for MT5 queue DB.

Prefers canonical worker-pool schema (`jobs` + `worker_heartbeat`) and
falls back to legacy saturation schema (`mt5_job_queue`) when needed.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path
from typing import Any


def queue_status(sqlite_path: Path, limit: int = 5) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "sqlite": str(sqlite_path),
        "db_exists": sqlite_path.exists(),
        "schema": "unknown",
        "counts": {},
        "queued_top": [],
        "dispatched_top": [],
        "worker_heartbeat_top": [],
    }
    if not sqlite_path.exists():
        return payload

    conn = sqlite3.connect(str(sqlite_path))
    try:
        table_rows = conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        tables = {str(row[0]) for row in table_rows}

        if "jobs" in tables:
            payload["schema"] = "worker_pool"
            rows = conn.execute("SELECT status, COUNT(*) FROM jobs GROUP BY status").fetchall()
            payload["counts"] = {str(status): int(count) for status, count in rows}
            payload["queued_top"] = [
                {
                    "job_id": str(row[0]),
                    "ea_id": str(row[1]),
                    "phase": str(row[2]),
                    "symbol": str(row[3]),
                    "status": str(row[4]),
                    "enqueued_at": str(row[5] or ""),
                }
                for row in conn.execute(
                    """
                    SELECT job_id,ea_id,phase,symbol,status,enqueued_at
                    FROM jobs
                    WHERE status='queued'
                    ORDER BY enqueued_at ASC, job_id ASC
                    LIMIT ?
                    """,
                    (max(1, int(limit)),),
                ).fetchall()
            ]
            payload["dispatched_top"] = [
                {
                    "job_id": str(row[0]),
                    "ea_id": str(row[1]),
                    "phase": str(row[2]),
                    "symbol": str(row[3]),
                    "claimed_by": str(row[4] or ""),
                    "status": str(row[5]),
                    "claimed_at": str(row[6] or ""),
                }
                for row in conn.execute(
                    """
                    SELECT job_id,ea_id,phase,symbol,claimed_by,status,claimed_at
                    FROM jobs
                    WHERE status IN ('claimed','running')
                    ORDER BY claimed_at DESC, job_id DESC
                    LIMIT ?
                    """,
                    (max(1, int(limit)),),
                ).fetchall()
            ]
            payload["worker_heartbeat_top"] = [
                {
                    "terminal_id": str(row[0]),
                    "pid": int(row[1] or 0),
                    "last_seen_utc": str(row[2]),
                    "current_job_id": str(row[3] or ""),
                    "jobs_completed": int(row[4] or 0),
                    "last_error": str(row[5] or ""),
                }
                for row in conn.execute(
                    """
                    SELECT terminal_id,pid,last_seen_utc,current_job_id,jobs_completed,last_error
                    FROM worker_heartbeat
                    ORDER BY last_seen_utc DESC, terminal_id ASC
                    LIMIT ?
                    """,
                    (max(1, int(limit)),),
                ).fetchall()
            ]
        elif "mt5_job_queue" in tables:
            payload["schema"] = "legacy_saturation"
            rows = conn.execute("SELECT status, COUNT(*) FROM mt5_job_queue GROUP BY status").fetchall()
            payload["counts"] = {str(status): int(count) for status, count in rows}
            payload["queued_top"] = [
                {
                    "id": int(row[0]),
                    "ea_id": str(row[1]),
                    "phase": str(row[2]),
                    "symbol": str(row[3]),
                    "priority": int(row[4] or 0),
                    "status": str(row[5]),
                }
                for row in conn.execute(
                    """
                    SELECT id,ea_id,phase,symbol,priority,status
                    FROM mt5_job_queue
                    WHERE status='queued'
                    ORDER BY priority DESC, created_at ASC, id ASC
                    LIMIT ?
                    """,
                    (max(1, int(limit)),),
                ).fetchall()
            ]
            payload["dispatched_top"] = [
                {
                    "id": int(row[0]),
                    "ea_id": str(row[1]),
                    "phase": str(row[2]),
                    "symbol": str(row[3]),
                    "assigned_terminal": str(row[4] or ""),
                    "dispatch_decision": str(row[5] or ""),
                    "status": str(row[6]),
                }
                for row in conn.execute(
                    """
                    SELECT id,ea_id,phase,symbol,assigned_terminal,dispatch_decision,status
                    FROM mt5_job_queue
                    WHERE status='dispatched'
                    ORDER BY dispatched_at DESC, id DESC
                    LIMIT ?
                    """,
                    (max(1, int(limit)),),
                ).fetchall()
            ]
    finally:
        conn.close()
    return payload


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Read queue counts and top queued/dispatched rows.")
    parser.add_argument("--sqlite", required=True, help="Path to SQLite queue DB.")
    parser.add_argument("--limit", type=int, default=5, help="Max rows for queued/dispatched previews.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    print(json.dumps(queue_status(Path(args.sqlite), limit=args.limit), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
