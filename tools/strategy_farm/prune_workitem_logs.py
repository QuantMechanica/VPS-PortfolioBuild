"""Prune raw MT5 backtest .log files from completed work_item report directories.

Each completed backtest produces a ~100 MB .log file (tick-level MT5 output).
The pipeline only reads summary.json for routing decisions; the raw log is
redundant once a work_item reaches a terminal state (done/failed).

Keeps: summary.json, report.htm, tester.ini, *.set, *.json, *.csv, *.md, *.py
Deletes: *.log files inside D:/QM/reports/work_items/<id>/

Only touches work_items with status in ('done', 'failed') that were last
updated before today (active/pending work items are never touched).

Usage:
    python tools/strategy_farm/prune_workitem_logs.py [--dry-run] [--older-than-days N]
"""

from __future__ import annotations

import argparse
import datetime as dt
import sqlite3
from pathlib import Path


FARM_ROOT = Path(r"D:\QM\strategy_farm")
REPORTS_ROOT = Path(r"D:\QM\reports\work_items")
DB_PATH = FARM_ROOT / "state" / "farm_state.sqlite"

TERMINAL_STATES = ("done", "failed")


def prune(dry_run: bool, older_than_days: int) -> None:
    cutoff = (dt.datetime.now(dt.UTC) - dt.timedelta(days=older_than_days)).isoformat()

    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    rows = con.execute(
        """
        SELECT id, ea_id, symbol, phase, status, verdict, updated_at
        FROM work_items
        WHERE status IN ('done','failed')
          AND updated_at < ?
        ORDER BY updated_at ASC
        """,
        (cutoff,),
    ).fetchall()
    con.close()

    print(f"work_items in terminal state, older than {older_than_days}d: {len(rows)}")
    print(f"Dry-run: {dry_run}\n")

    total_bytes = 0
    total_files = 0
    missing_dirs = 0
    errors = 0

    for row in rows:
        report_dir = REPORTS_ROOT / row["id"]
        if not report_dir.is_dir():
            missing_dirs += 1
            continue

        logs = list(report_dir.rglob("*.log"))
        if not logs:
            continue

        for log_path in logs:
            size = log_path.stat().st_size
            total_bytes += size
            total_files += 1
            if dry_run:
                print(f"  [DRY] would delete {log_path.name}  ({size // 1_048_576} MB)  [{row['ea_id']} {row['symbol']} {row['phase']} {row['status']}]")
            else:
                try:
                    log_path.unlink()
                except OSError as exc:
                    print(f"  ERROR deleting {log_path}: {exc}")
                    errors += 1
                    total_bytes -= size
                    total_files -= 1

    freed_gb = total_bytes / 1_073_741_824
    action = "Would free" if dry_run else "Freed"
    print(f"\n{'='*60}")
    print(f"{action}: {freed_gb:.1f} GB  ({total_files} log files)")
    print(f"Dirs not found (already cleaned or no report): {missing_dirs}")
    if errors:
        print(f"Errors: {errors}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Prune .log files from completed work_item report directories.")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be deleted without deleting.")
    parser.add_argument("--older-than-days", type=int, default=1, help="Only touch items updated more than N days ago (default: 1).")
    args = parser.parse_args()
    prune(dry_run=args.dry_run, older_than_days=args.older_than_days)


if __name__ == "__main__":
    main()
