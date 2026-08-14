"""Coverage for collect_pattern_fixture_harness_results.py (task 50d5752c-daf2 R2).

Proves the staleness guard is real (a results file predating the fixture
bundle it claims to answer is a hard error, never a silently accepted
pass), that a fresh collection succeeds and is byte-idempotent across two
runs, and that the journal purge only ever touches files under the given
report_root -- never anything outside it.
"""
from __future__ import annotations

import csv
import importlib.util
import sys
import time
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
MODULE_PATH = REPO_ROOT / "framework" / "scripts" / "collect_pattern_fixture_harness_results.py"

_spec = importlib.util.spec_from_file_location("_collect_ppfh_results", MODULE_PATH)
collector = importlib.util.module_from_spec(_spec)
sys.modules["_collect_ppfh_results"] = collector
_spec.loader.exec_module(collector)


def _write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=["fixture_id", "verdict"])
        writer.writeheader()
        writer.writerows(rows)


def test_missing_source_csv_raises(tmp_path: Path) -> None:
    bundle = tmp_path / "bundle.csv"
    _write_csv(bundle, [])
    with pytest.raises(FileNotFoundError):
        collector.collect_results(
            source_csv=tmp_path / "missing_results.csv",
            bundle_csv=bundle,
            dest_csv=tmp_path / "dest.csv",
        )


def test_missing_bundle_csv_raises(tmp_path: Path) -> None:
    source = tmp_path / "results.csv"
    _write_csv(source, [{"fixture_id": "x", "verdict": "PASS"}])
    with pytest.raises(FileNotFoundError):
        collector.collect_results(
            source_csv=source,
            bundle_csv=tmp_path / "missing_bundle.csv",
            dest_csv=tmp_path / "dest.csv",
        )


def test_stale_results_rejected(tmp_path: Path) -> None:
    """A results file older than the bundle it claims to answer must be a
    hard error, never a default pass (R2 acceptance criterion)."""
    bundle = tmp_path / "bundle.csv"
    source = tmp_path / "results.csv"
    _write_csv(source, [{"fixture_id": "x", "verdict": "PASS"}])
    time.sleep(0.02)
    _write_csv(bundle, [])  # bundle regenerated AFTER the results were produced
    with pytest.raises(collector.StaleResultsError):
        collector.collect_results(
            source_csv=source, bundle_csv=bundle, dest_csv=tmp_path / "dest.csv",
        )


def test_fresh_results_accepted_and_counted(tmp_path: Path) -> None:
    bundle = tmp_path / "bundle.csv"
    _write_csv(bundle, [])
    time.sleep(0.02)
    source = tmp_path / "results.csv"
    _write_csv(source, [
        {"fixture_id": "a", "verdict": "PASS"},
        {"fixture_id": "b", "verdict": "PASS"},
        {"fixture_id": "c", "verdict": "FAIL"},
    ])
    dest = tmp_path / "dest" / "pattern_fixture_results.csv"
    result = collector.collect_results(source_csv=source, bundle_csv=bundle, dest_csv=dest)
    assert result["collected"] is True
    assert result["row_count"] == 3
    assert result["verdict_counts"] == {"PASS": 2, "FAIL": 1}
    assert dest.is_file()


def test_two_runs_are_idempotent(tmp_path: Path) -> None:
    bundle = tmp_path / "bundle.csv"
    _write_csv(bundle, [])
    time.sleep(0.02)
    source = tmp_path / "results.csv"
    _write_csv(source, [{"fixture_id": "a", "verdict": "PASS"}])
    dest = tmp_path / "dest.csv"
    r1 = collector.collect_results(source_csv=source, bundle_csv=bundle, dest_csv=dest)
    bytes_1 = dest.read_bytes()
    r2 = collector.collect_results(source_csv=source, bundle_csv=bundle, dest_csv=dest)
    bytes_2 = dest.read_bytes()
    assert bytes_1 == bytes_2
    assert r1["row_count"] == r2["row_count"] == 1


def test_journal_purge_only_touches_report_root(tmp_path: Path) -> None:
    report_root = tmp_path / "work_items" / "wi-1"
    outside_dir = tmp_path / "other_work_item"
    inner_log = report_root / "QM5_0" / "Q02" / "tester.log"
    outside_log = outside_dir / "tester.log"
    inner_log.parent.mkdir(parents=True)
    outside_dir.mkdir(parents=True)
    inner_log.write_text("journal\n", encoding="utf-8")
    outside_log.write_text("journal\n", encoding="utf-8")

    purged = collector.purge_report_root_journal(report_root)

    assert str(inner_log) in purged
    assert not inner_log.exists()
    assert outside_log.exists()  # never touched -- not under report_root


def test_journal_purge_missing_report_root_is_a_noop(tmp_path: Path) -> None:
    assert collector.purge_report_root_journal(tmp_path / "does_not_exist") == []
