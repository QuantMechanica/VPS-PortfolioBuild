#!/usr/bin/env python3
"""Deterministic cross-EA scheduler that keeps installed T1-T10 saturated from SQLite queue state."""

from __future__ import annotations

import argparse
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from framework.scripts.pipeline_dispatcher import (
    DEFAULT_STATE_PATH,
    active_terminals,
    dedup_key,
    load_dispatch_state,
    resolve_target_terminal,
    save_dispatch_state,
    validate_job,
)


def _utc_now_iso() -> str:
    return datetime.now(tz=timezone.utc).isoformat()


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS mt5_job_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ea_id TEXT NOT NULL,
            version TEXT NOT NULL,
            phase TEXT NOT NULL,
            symbol TEXT NOT NULL,
            sub_gate_config_hash TEXT NOT NULL,
            setfile_path TEXT NOT NULL,
            target_terminal TEXT NOT NULL DEFAULT 'any',
            priority INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'queued',
            created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
            dispatched_at TEXT,
            assigned_terminal TEXT,
            dispatch_decision TEXT,
            dedup_key TEXT,
            last_error TEXT
        )
        """
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_mt5_queue_status_priority ON mt5_job_queue(status, priority DESC, created_at ASC, id ASC)"
    )
    conn.commit()


def _slots_available(state: dict[str, Any], max_per_terminal: int) -> int:
    terminals = active_terminals()
    running = state.setdefault("running", {})
    for terminal in terminals:
        running.setdefault(terminal, 0)
    available = 0
    for terminal in terminals:
        current = int(running.get(terminal, 0))
        available += max(0, max_per_terminal - current)
    return available


def fetch_queued_jobs(conn: sqlite3.Connection, limit: int) -> list[dict[str, Any]]:
    rows = conn.execute(
        """
        SELECT
            id, ea_id, version, phase, symbol, sub_gate_config_hash, setfile_path, target_terminal, priority
        FROM mt5_job_queue
        WHERE status = 'queued'
        ORDER BY priority DESC, created_at ASC, id ASC
        LIMIT ?
        """,
        (max(0, int(limit)),),
    ).fetchall()
    jobs: list[dict[str, Any]] = []
    for row in rows:
        job = {
            "id": int(row[0]),
            "ea_id": str(row[1]),
            "version": str(row[2]),
            "phase": str(row[3]),
            "symbol": str(row[4]),
            "sub_gate_config_hash": str(row[5]),
            "setfile_path": str(row[6]),
            "target_terminal": str(row[7] or "any"),
            "priority": int(row[8] or 0),
        }
        jobs.append(job)
    return jobs


def _mark_dispatched(
    conn: sqlite3.Connection,
    *,
    row_id: int,
    terminal: str,
    decision_status: str,
    key: str,
) -> None:
    conn.execute(
        """
        UPDATE mt5_job_queue
        SET
            status = 'dispatched',
            dispatched_at = ?,
            assigned_terminal = ?,
            dispatch_decision = ?,
            dedup_key = ?,
            last_error = NULL
        WHERE id = ?
        """,
        (_utc_now_iso(), terminal, decision_status, key, row_id),
    )


def _mark_invalid(conn: sqlite3.Connection, *, row_id: int, error_text: str) -> None:
    conn.execute(
        """
        UPDATE mt5_job_queue
        SET
            status = 'invalid',
            dispatch_decision = 'invalid',
            last_error = ?
        WHERE id = ?
        """,
        (error_text, row_id),
    )


def run_tick(
    *,
    sqlite_path: Path,
    dispatch_state_path: Path,
    max_per_terminal: int,
    scan_limit: int,
    dry_run: bool = False,
) -> dict[str, Any]:
    state = load_dispatch_state(dispatch_state_path)
    available_before = _slots_available(state, max_per_terminal)
    if available_before <= 0:
        return {
            "status": "ok",
            "available_slots_before": 0,
            "queued_scanned": 0,
            "scheduled": 0,
            "duplicate": 0,
            "invalid": 0,
            "no_capacity": 0,
            "available_slots_after": 0,
            "dry_run": dry_run,
        }

    conn = sqlite3.connect(str(sqlite_path))
    try:
        ensure_schema(conn)
        jobs = fetch_queued_jobs(conn, limit=max(scan_limit, available_before))
        summary = {
            "status": "ok",
            "available_slots_before": available_before,
            "queued_scanned": len(jobs),
            "scheduled": 0,
            "duplicate": 0,
            "invalid": 0,
            "no_capacity": 0,
            "available_slots_after": 0,
            "dry_run": dry_run,
        }
        for row in jobs:
            job_payload = {
                "ea_id": row["ea_id"],
                "version": row["version"],
                "phase": row["phase"],
                "symbol": row["symbol"],
                "sub_gate_config_hash": row["sub_gate_config_hash"],
                "setfile_path": row["setfile_path"],
                "target_terminal": row["target_terminal"] or "any",
            }
            try:
                validate_job(job_payload)
            except Exception as exc:
                summary["invalid"] += 1
                if not dry_run:
                    _mark_invalid(conn, row_id=row["id"], error_text=str(exc))
                continue

            decision = resolve_target_terminal(job_payload, state, max_per_terminal=max_per_terminal)
            status = str(decision.get("status", ""))
            if status in {"scheduled", "duplicate", "pinned"}:
                terminal = str(decision.get("terminal") or "")
                key = dedup_key(job_payload)
                summary["scheduled" if status in {"scheduled", "pinned"} else "duplicate"] += 1
                if not dry_run:
                    _mark_dispatched(
                        conn,
                        row_id=row["id"],
                        terminal=terminal,
                        decision_status=status,
                        key=key,
                    )
            elif status == "no_capacity":
                summary["no_capacity"] += 1
                break
            else:
                summary["invalid"] += 1
                if not dry_run:
                    _mark_invalid(conn, row_id=row["id"], error_text=f"unsupported status: {status}")

        summary["available_slots_after"] = _slots_available(state, max_per_terminal)
        if not dry_run:
            save_dispatch_state(state, dispatch_state_path)
            conn.commit()
        return summary
    finally:
        conn.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="MT5 T1-T10 saturation scheduler (cross-EA, deterministic).")
    parser.add_argument("--sqlite", required=True, help="Path to SQLite queue DB.")
    parser.add_argument("--dispatch-state", default=str(DEFAULT_STATE_PATH), help="dispatch_state.json path.")
    parser.add_argument("--max-per-terminal", type=int, default=3, help="Max active runs per terminal.")
    parser.add_argument("--scan-limit", type=int, default=500, help="Max queued rows scanned per tick.")
    parser.add_argument("--dry-run", action="store_true", help="Compute decisions without writing DB/state.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    summary = run_tick(
        sqlite_path=Path(args.sqlite),
        dispatch_state_path=Path(args.dispatch_state),
        max_per_terminal=max(1, int(args.max_per_terminal)),
        scan_limit=max(1, int(args.scan_limit)),
        dry_run=bool(args.dry_run),
    )
    print(json.dumps(summary, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
