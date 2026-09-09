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
import hashlib
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


class InvalidResultsError(RuntimeError):
    """A copied CSV is not proof: every declared fixture must pass exactly once."""


def validate_results(source_csv: Path, bundle_csv: Path) -> list[dict]:
    with Path(bundle_csv).open(encoding="utf-8-sig", newline="") as fh:
        expected = {}
        for row in csv.DictReader(fh):
            identity = tuple(row.get(k) for k in ("predicate", "case", "expected"))
            fid = row.get("fixture_id")
            if not fid or any(v is None for v in identity):
                raise InvalidResultsError("invalid fixture bundle identity")
            if fid in expected and expected[fid] != identity:
                raise InvalidResultsError("inconsistent fixture bundle identity: " + fid)
            expected[fid] = identity
    with Path(source_csv).open(encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    ids = [r.get("fixture_id") for r in rows]
    if not expected or len(ids) != len(set(ids)) or set(ids) != set(expected):
        raise InvalidResultsError("missing, duplicate, extra or empty fixture results")
    for row in rows:
        identity = tuple(row.get(k) for k in ("predicate", "case", "expected"))
        if (identity != expected[row["fixture_id"]] or row.get("verdict") != "PASS"
                or row.get("actual") not in ("0", "1") or row["actual"] != row.get("expected")):
            raise InvalidResultsError("failed or mismatched fixture: " + row["fixture_id"])
        try:
            if not 0 < int(row["bars_required"]) <= int(row["bars_supplied"]):
                raise ValueError("short window")
        except (ValueError, TypeError, KeyError) as exc:
            raise InvalidResultsError("invalid window: " + row["fixture_id"]) from exc
    return rows


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

    # Validate BEFORE replacing a prior green artifact. Rejected native output
    # remains at source_csv for diagnosis; it is never relabelled HARNESS_OK.
    source_sha256 = hashlib.sha256(source_csv.read_bytes()).hexdigest()
    bundle_sha256 = hashlib.sha256(bundle_csv.read_bytes()).hexdigest()
    rows = validate_results(source_csv, bundle_csv)
    if (hashlib.sha256(source_csv.read_bytes()).hexdigest() != source_sha256
            or hashlib.sha256(bundle_csv.read_bytes()).hexdigest() != bundle_sha256):
        raise InvalidResultsError("fixture evidence changed during validation")
    dest_csv.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source_csv, dest_csv)
    if hashlib.sha256(dest_csv.read_bytes()).hexdigest() != source_sha256:
        raise InvalidResultsError("results changed during collection")
    verdict_counts = dict(Counter(r.get("verdict") for r in rows))
    result = {
        "collected": True,
        "dest_csv": str(dest_csv),
        "source_csv": str(source_csv),
        "row_count": len(rows),
        "verdict_counts": verdict_counts,
        "source_mtime": source_mtime,
        "bundle_mtime": bundle_mtime,
        "bundle_sha256": bundle_sha256,
        "results_sha256": source_sha256,
        "all_expected_passed": True,
    }
    # The checked-in CSV alone used to let old outputs certify edited inputs.
    # Preserve a hash-bound collection receipt alongside each accepted result.
    receipt_path = dest_csv.with_suffix(".receipt.json")
    receipt_path.write_text(json.dumps(result, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    return result


def validate_smoke_summary(report_root: Path, payload: dict) -> dict:
    """Do not let a lost process exit code conceal an actual wrapper FAIL."""
    report_root = Path(report_root).resolve()
    paths = list(report_root.glob("QM5_999999/*/summary.json"))
    if len(paths) != 1:
        raise InvalidResultsError("exactly one native fixture smoke summary required")
    path = paths[0]
    raw = path.read_bytes()
    summary = json.loads(raw.decode("utf-8-sig"))
    binary = summary.get("execution_identity", {}).get("expert_binary", {})
    digest = payload["harness_ex5_sha256"]
    if (summary.get("result") != "PASS" or summary.get("reason_classes") != ["OK"]
            or summary.get("min_trades_required") != 0
            # run_smoke stores its numeric pseudo-EA label here. The actual
            # executable is identified by expert + the before/after hashes.
            or summary.get("ea_id") != 999999 or summary.get("ea_label") != "QM5_999999"
            or summary.get("expert") != "QM\\QM_pattern_permission_fixture_runner"
            or summary.get("requested_runs") != 1
            or summary.get("period") != payload["harness_period"]
            or summary.get("from_date") != payload["from_date"]
            or summary.get("to_date") != payload["to_date"]
            or binary.get("stable_during_run") is not True
            or binary.get("required_sha256") != digest
            or binary.get("deployed", {}).get("sha256") != digest
            or binary.get("observed_after", {}).get("sha256") != digest):
        raise InvalidResultsError("fixture smoke failed or execution binding changed")
    runs = summary.get("runs", [])
    if len(runs) != 1 or runs[0].get("status") != "OK" or runs[0].get("total_trades") != 0:
        raise InvalidResultsError("fixture smoke run is incomplete or traded")
    report = Path(runs[0]["report_canonical_path"]).resolve()
    if not report.is_relative_to(report_root) or hashlib.sha256(report.read_bytes()).hexdigest() != runs[0].get("report_sha256"):
        raise InvalidResultsError("native fixture report hash/path mismatch")
    return {"path":str(path), "sha256":hashlib.sha256(raw).hexdigest(), "result":"PASS", "report_sha256":runs[0]["report_sha256"]}


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
    except (FileNotFoundError, StaleResultsError, InvalidResultsError) as exc:
        print(json.dumps({"collected": False, "reason": str(exc)}, sort_keys=True))
        return 2
    if args.report_root:
        result["journal_purged"] = purge_report_root_journal(args.report_root)
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
