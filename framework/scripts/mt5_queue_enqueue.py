#!/usr/bin/env python3
"""Deterministically enqueue rows into mt5_job_queue for saturation scheduler runs."""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

if __package__ is None or __package__ == "":
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts.mt5_saturation_scheduler import ensure_schema
from framework.scripts.pipeline_dispatcher import validate_job


def _insert_row(conn: sqlite3.Connection, job: dict[str, Any]) -> int:
    cursor = conn.execute(
        """
        INSERT INTO mt5_job_queue
        (ea_id,version,phase,symbol,sub_gate_config_hash,setfile_path,target_terminal,priority,status)
        VALUES (?,?,?,?,?,?,?,?,?)
        """,
        (
            str(job["ea_id"]),
            str(job.get("version", "v1")),
            str(job["phase"]),
            str(job["symbol"]),
            str(job["sub_gate_config_hash"]),
            str(job["setfile_path"]),
            str(job.get("target_terminal", "any")),
            int(job.get("priority", 0)),
            "queued",
        ),
    )
    return int(cursor.lastrowid)


def enqueue_jobs(sqlite_path: Path, jobs: list[dict[str, Any]]) -> dict[str, Any]:
    conn = sqlite3.connect(str(sqlite_path))
    inserted_ids: list[int] = []
    try:
        ensure_schema(conn)
        for job in jobs:
            validate_job(
                {
                    "ea_id": job["ea_id"],
                    "version": job.get("version", "v1"),
                    "phase": job["phase"],
                    "symbol": job["symbol"],
                    "sub_gate_config_hash": job["sub_gate_config_hash"],
                    "setfile_path": job["setfile_path"],
                    "target_terminal": job.get("target_terminal", "any"),
                }
            )
            inserted_ids.append(_insert_row(conn, job))
        conn.commit()
    finally:
        conn.close()
    return {
        "status": "ok",
        "sqlite": str(sqlite_path),
        "inserted": len(inserted_ids),
        "inserted_ids": inserted_ids,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Enqueue jobs into mt5_job_queue.")
    parser.add_argument("--sqlite", required=True, help="Path to SQLite queue DB.")
    parser.add_argument("--job-json", help="Single job JSON file.")
    parser.add_argument("--jobs-json", help="Array of jobs JSON file.")
    parser.add_argument(
        "--job-inline",
        help="Single job JSON payload as inline string.",
    )
    return parser.parse_args()


def _load_jobs(args: argparse.Namespace) -> list[dict[str, Any]]:
    sources = [bool(args.job_json), bool(args.jobs_json), bool(args.job_inline)]
    if sum(1 for item in sources if item) != 1:
        raise ValueError("Provide exactly one of --job-json, --jobs-json, or --job-inline.")

    if args.job_json:
        payload = json.loads(Path(args.job_json).read_text(encoding="utf-8"))
        if not isinstance(payload, dict):
            raise ValueError("--job-json must contain a single JSON object.")
        return [payload]

    if args.jobs_json:
        payload = json.loads(Path(args.jobs_json).read_text(encoding="utf-8"))
        if not isinstance(payload, list):
            raise ValueError("--jobs-json must contain a JSON array.")
        return [dict(item) for item in payload]

    payload = json.loads(str(args.job_inline))
    if not isinstance(payload, dict):
        raise ValueError("--job-inline must contain a single JSON object.")
    return [payload]


def main() -> int:
    args = parse_args()
    jobs = _load_jobs(args)
    summary = enqueue_jobs(Path(args.sqlite), jobs)
    print(json.dumps(summary, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
