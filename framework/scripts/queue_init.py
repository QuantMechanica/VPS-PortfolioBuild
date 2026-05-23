#!/usr/bin/env python3
"""Initialize MT5 worker-pool SQLite schema (jobs + worker_heartbeat)."""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path

DEFAULT_SQLITE = Path(r"D:/QM/reports/pipeline/mt5_queue.db")


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS jobs (
          job_id TEXT PRIMARY KEY,
          ea_id TEXT NOT NULL,
          version TEXT NOT NULL,
          symbol TEXT NOT NULL,
          period TEXT NOT NULL,
          year INTEGER NOT NULL,
          phase TEXT NOT NULL,
          sub_gate_config_hash TEXT NOT NULL,
          setfile_path TEXT NOT NULL,
          status TEXT NOT NULL,
          verdict TEXT,
          invalidation_reason TEXT,
          claimed_by TEXT,
          claimed_at TEXT,
          started_at TEXT,
          finished_at TEXT,
          result_path TEXT,
          retry_count INTEGER NOT NULL DEFAULT 0,
          enqueued_at TEXT NOT NULL,
          enqueued_by TEXT NOT NULL
        )
        """
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_jobs_claimed_by ON jobs(claimed_by) WHERE claimed_by IS NOT NULL")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_jobs_dedup ON jobs(sub_gate_config_hash)")

    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS worker_heartbeat (
          terminal_id TEXT PRIMARY KEY,
          pid INTEGER,
          last_seen_utc TEXT NOT NULL,
          current_job_id TEXT,
          jobs_completed INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        )
        """
    )
    conn.commit()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Initialize mt5_queue.db schema for worker-pool.")
    parser.add_argument("--sqlite", default=str(DEFAULT_SQLITE), help="Path to SQLite DB.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    sqlite_path = Path(args.sqlite)
    sqlite_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(sqlite_path))
    try:
        ensure_schema(conn)
    finally:
        conn.close()
    print(json.dumps({"status": "ok", "sqlite": str(sqlite_path)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
