#!/usr/bin/env python3
"""Collect the pattern-permission fixture runner's verdict CSV.

The MQL5 runner (framework/tests/QM_pattern_permission_fixture_runner.mq5)
writes its verdict CSV to the shared MT5 Common\\Files folder (FILE_COMMON),
not into the repo. This script copies it into
framework/tests/fixtures/pattern_permission/_bundle/pattern_fixture_results.csv
-- the path test_pattern_fixture_coverage.py reads -- with a staleness guard:
a results file older than the fixture bundle CSV it claims to answer is a
hard error, never a silently accepted pass (a stale results.csv sitting next
to an edited fixture bundle would otherwise let a changed fixture "pass" on
a verdict computed against the OLD bundle).

It also purges the .log tester-journal copies left under a harness work
item's own report_root (D:\\QM\\reports\\work_items\\<id>\\). That directory
is created fresh per work item and never shared with any other concurrent
dispatch, so removing it cannot affect another in-flight run -- unlike the
terminal's shared per-day tester journal under <Tn>\\Tester\\logs\\, which
this script never touches.

Usage:
    python framework/scripts/collect_pattern_fixture_harness_results.py \
        --source-csv "C:\\Users\\Administrator\\AppData\\Roaming\\MetaQuotes\\Terminal\\Common\\Files\\QM\\pattern_fixture_results.csv" \
        [--bundle-csv ...] [--dest-csv ...] [--report-root D:\\QM\\reports\\work_items\\<id>]
"""
from __future__ import annotations

import argparse
import csv
import json
import shutil
from collections import Counter
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_DIR = REPO_ROOT / "framework" / "tests" / "fixtures" / "pattern_permission"
DEFAULT_BUNDLE_CSV = FIXTURE_DIR / "_bundle" / "pattern_fixtures.csv"
DEFAULT_DEST_CSV = FIXTURE_DIR / "_bundle" / "pattern_fixture_results.csv"


class StaleResultsError(RuntimeError):
    """The results CSV predates the fixture bundle it claims to answer."""


def collect_results(*, source_csv: Path, bundle_csv: Path = DEFAULT_BUNDLE_CSV,
                     dest_csv: Path = DEFAULT_DEST_CSV) -> dict[str, Any]:
    source_csv = Path(source_csv)
    bundle_csv = Path(bundle_csv)
    dest_csv = Path(dest_csv)
    if not source_csv.is_file():
        raise FileNotFoundError(f"results CSV not found: {source_csv}")
    if not bundle_csv.is_file():
        raise FileNotFoundError(f"fixture bundle CSV not found: {bundle_csv}")

    source_mtime = source_csv.stat().st_mtime
    bundle_mtime = bundle_csv.stat().st_mtime
    if source_mtime < bundle_mtime:
        raise StaleResultsError(
            f"results CSV {source_csv} (mtime={source_mtime}) predates the "
            f"fixture bundle it claims to answer {bundle_csv} "
            f"(mtime={bundle_mtime}) -- refusing a stale pass; re-run the "
            f"harness against the current bundle before collecting"
        )

    dest_csv.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source_csv, dest_csv)

    with dest_csv.open(encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    verdict_counts = dict(Counter(r.get("verdict") for r in rows))
    return {
        "collected": True,
        "dest_csv": str(dest_csv),
        "source_csv": str(source_csv),
        "row_count": len(rows),
        "verdict_counts": verdict_counts,
        "source_mtime": source_mtime,
        "bundle_mtime": bundle_mtime,
    }


def purge_report_root_journal(report_root: Path) -> list[str]:
    """Delete .log files under a harness work item's own report_root.

    Safe because report_root (D:\\QM\\reports\\work_items\\<item_id>\\) is
    created fresh per work item and read by nothing else once this
    function's caller has already extracted the verdict CSV from
    Common\\Files -- it is never the terminal's shared per-day tester
    journal other concurrent work items still need.
    """
    report_root = Path(report_root)
    purged: list[str] = []
    if not report_root.is_dir():
        return purged
    for log_path in sorted(report_root.rglob("*.log")):
        try:
            log_path.unlink()
            purged.append(str(log_path))
        except OSError:
            continue
    return purged


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-csv", type=Path, required=True)
    parser.add_argument("--bundle-csv", type=Path, default=DEFAULT_BUNDLE_CSV)
    parser.add_argument("--dest-csv", type=Path, default=DEFAULT_DEST_CSV)
    parser.add_argument(
        "--report-root", type=Path,
        help="if given, purge .log journal copies under this dir after a successful collection",
    )
    args = parser.parse_args(argv)
    try:
        result = collect_results(
            source_csv=args.source_csv,
            bundle_csv=args.bundle_csv,
            dest_csv=args.dest_csv,
        )
    except (FileNotFoundError, StaleResultsError) as exc:
        print(json.dumps({"collected": False, "reason": str(exc)}, sort_keys=True))
        return 2
    if args.report_root:
        result["journal_purged"] = purge_report_root_journal(args.report_root)
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
