"""Prune redundant raw MT5 backtest journals from durable report surfaces.

Each completed backtest produces a ~100 MB .log file (tick-level MT5 output).
The pipeline only reads summary.json for routing decisions; the raw log is
redundant once a work_item reaches a terminal state (done/failed).

Keeps: summary.json, report.htm, tester.ini, *.set, *.json, *.csv, *.md, *.py
Deletes: *.log files inside D:/QM/reports/work_items/<id>/

The same raw journals are also copied into top-level ``reports/pipeline*``
surfaces.  Only logs with the MT5 journal layout ``raw/run_*/*.log`` are pruned
there.  Operational logs elsewhere in those trees and all summary/evidence
formats remain untouched.

Only touches work_items with status in ('done', 'failed') that were last
updated before today (active/pending work items are never touched).

Usage:
    python tools/strategy_farm/prune_workitem_logs.py [--dry-run] \
        [--older-than-days N] [--pipeline-older-than-days N]
"""

from __future__ import annotations

import argparse
import datetime as dt
import sqlite3
from pathlib import Path


FARM_ROOT = Path(r"D:\QM\strategy_farm")
REPORTS_PARENT = Path(r"D:\QM\reports")
REPORTS_ROOT = REPORTS_PARENT / "work_items"
DB_PATH = FARM_ROOT / "state" / "farm_state.sqlite"

TERMINAL_STATES = ("done", "failed")
PIPELINE_MIN_AGE_DAYS = 1
PIPELINE_RETENTION_DAYS = 10


def discover_pipeline_roots(reports_parent: Path = REPORTS_PARENT) -> list[Path]:
    """Return only top-level report directories whose names start with pipeline."""

    try:
        parent_resolved = reports_parent.resolve(strict=True)
        roots: list[Path] = []
        for path in reports_parent.glob("pipeline*"):
            if not path.is_dir():
                continue
            resolved = path.resolve(strict=True)
            # Reject top-level symlinks/junctions that escape reports/.  The
            # pruner must never traverse a similarly named external tree.
            if resolved.parent != parent_resolved:
                continue
            roots.append(path)
        return sorted(roots)
    except OSError:
        return []


def prune_pipeline_logs(
    dry_run: bool,
    older_than_days: int,
    *,
    reports_parent: Path = REPORTS_PARENT,
    now: dt.datetime | None = None,
) -> dict[str, int]:
    """Prune aged MT5 journals below top-level ``pipeline*`` roots."""

    if older_than_days < PIPELINE_MIN_AGE_DAYS:
        raise ValueError(
            f"pipeline older_than_days must be >= {PIPELINE_MIN_AGE_DAYS}"
        )
    current = now or dt.datetime.now(dt.UTC)
    if current.tzinfo is None:
        current = current.replace(tzinfo=dt.UTC)
    cutoff_epoch = (current - dt.timedelta(days=older_than_days)).timestamp()
    roots = discover_pipeline_roots(reports_parent)
    stats = {
        "roots": len(roots),
        "files": 0,
        "bytes": 0,
        "recent": 0,
        "unsafe": 0,
        "errors": 0,
    }

    print(f"\npipeline* roots: {len(roots)}")
    for root in roots:
        try:
            root_resolved = root.resolve(strict=True)
            logs = (
                path
                for path in root.rglob("*.log")
                if path.parent.name.lower().startswith("run_")
                and path.parent.parent.name.lower() == "raw"
            )
            for log_path in logs:
                try:
                    resolved_log = log_path.resolve(strict=True)
                    if not resolved_log.is_relative_to(root_resolved):
                        print(f"  REFUSED path outside pipeline root: {log_path}")
                        stats["unsafe"] += 1
                        continue
                    stat = log_path.stat()
                except OSError as exc:
                    print(f"  ERROR reading {log_path}: {exc}")
                    stats["errors"] += 1
                    continue
                if stat.st_mtime >= cutoff_epoch:
                    stats["recent"] += 1
                    continue

                if dry_run:
                    print(
                        f"  [DRY] would delete {log_path}  "
                        f"({stat.st_size // 1_048_576} MB)"
                    )
                else:
                    try:
                        log_path.unlink()
                    except OSError as exc:
                        print(f"  ERROR deleting {log_path}: {exc}")
                        stats["errors"] += 1
                        continue
                stats["files"] += 1
                stats["bytes"] += int(stat.st_size)
        except OSError as exc:
            print(f"  ERROR scanning {root}: {exc}")
            stats["errors"] += 1

    freed_gb = stats["bytes"] / 1_073_741_824
    action = "Would free" if dry_run else "Freed"
    print(
        f"{action} from pipeline*: {freed_gb:.1f} GB "
        f"({stats['files']} log files); recent kept={stats['recent']}; "
        f"unsafe refused={stats['unsafe']}; errors={stats['errors']}"
    )
    return stats


def prune(
    dry_run: bool,
    older_than_days: int,
    pipeline_older_than_days: int = PIPELINE_RETENTION_DAYS,
) -> None:
    if older_than_days < 0:
        raise ValueError("older_than_days must be non-negative")
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

    prune_pipeline_logs(
        dry_run=dry_run,
        older_than_days=pipeline_older_than_days,
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Prune redundant .log journals from work_items and pipeline* reports."
    )
    parser.add_argument("--dry-run", action="store_true", help="Show what would be deleted without deleting.")
    parser.add_argument("--older-than-days", type=int, default=1, help="Only touch items updated more than N days ago (default: 1).")
    parser.add_argument(
        "--pipeline-older-than-days",
        type=int,
        default=PIPELINE_RETENTION_DAYS,
        help=(
            "Only prune pipeline* raw tester journals older than N days; "
            "minimum: 1, default: 10."
        ),
    )
    args = parser.parse_args()
    prune(
        dry_run=args.dry_run,
        older_than_days=args.older_than_days,
        pipeline_older_than_days=args.pipeline_older_than_days,
    )


if __name__ == "__main__":
    main()
