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
        writer = csv.DictWriter(fh, fieldnames=["fixture_id", "predicate", "case", "expected", "actual", "verdict", "bars_supplied", "bars_required"])
        writer.writeheader()
        writer.writerows({"predicate":"QM_PP_DOJI", "case":"positive", "expected":"1", "actual":"1", "bars_supplied":"3", "bars_required":"3", **row} for row in rows)


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
    _write_csv(bundle, [{"fixture_id": x, "verdict":"PASS"} for x in "abc"])
    time.sleep(0.02)
    source = tmp_path / "results.csv"
    _write_csv(source, [
        {"fixture_id": "a", "verdict": "PASS"},
        {"fixture_id": "b", "verdict": "PASS"},
        {"fixture_id": "c", "verdict": "PASS"},
    ])
    dest = tmp_path / "dest" / "pattern_fixture_results.csv"
    result = collector.collect_results(source_csv=source, bundle_csv=bundle, dest_csv=dest)
    assert result["collected"] is True
    assert result["row_count"] == 3
    assert result["verdict_counts"] == {"PASS": 3}
    assert result["all_expected_passed"] is True
    assert len(result["bundle_sha256"]) == len(result["results_sha256"]) == 64
    assert dest.is_file()


def test_two_runs_are_idempotent(tmp_path: Path) -> None:
    bundle = tmp_path / "bundle.csv"
    _write_csv(bundle, [{"fixture_id":"a", "verdict":"PASS"}])
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


@pytest.mark.parametrize("rows", [
    [],
    [{"fixture_id":"a", "verdict":"FAIL"}],
    [{"fixture_id":"a", "verdict":"PASS", "actual":"0"}],
    [{"fixture_id":"a", "verdict":"PASS", "bars_supplied":"1"}],
    [{"fixture_id":"a", "verdict":"PASS", "predicate":"QM_PP_HAMMER"}],
    [{"fixture_id":"a", "verdict":"PASS"}] * 2,
    [{"fixture_id":"other", "verdict":"PASS"}],
])
def test_invalid_native_output_never_replaces_green_artifact(tmp_path, rows):
    bundle, source, dest = (tmp_path / n for n in ("bundle.csv", "source.csv", "dest.csv"))
    _write_csv(bundle, [{"fixture_id":"a", "verdict":"PASS"}])
    _write_csv(source, rows)
    dest.write_bytes(b"historic evidence")
    with pytest.raises(collector.InvalidResultsError):
        collector.collect_results(source_csv=source, bundle_csv=bundle, dest_csv=dest)
    assert dest.read_bytes() == b"historic evidence"


@pytest.mark.parametrize("mutation", ["none", "wrapper_fail", "wrong_binary", "traded", "report_tamper"])
def test_native_summary_must_independently_confirm_success(tmp_path, mutation):
    import hashlib
    import json
    run = tmp_path / "QM5_999999" / "run"
    run.mkdir(parents=True)
    report = run / "report.htm"
    report.write_bytes(b"real native fixture report stand-in")
    digest = "a"*64
    payload = {"harness_ex5_sha256":digest, "harness_period":"D1", "from_date":"2024.01.02", "to_date":"2024.01.10"}
    summary = {"result":"PASS", "reason_classes":["OK"], "min_trades_required":0,
               "ea_id":999999, "ea_label":"QM5_999999", "expert":"QM\\QM_pattern_permission_fixture_runner", "requested_runs":1,
               "period":"D1", "from_date":payload["from_date"], "to_date":payload["to_date"],
               "execution_identity":{"expert_binary":{"stable_during_run":True, "required_sha256":digest,
                   "deployed":{"sha256":digest}, "observed_after":{"sha256":digest}}},
               "runs":[{"status":"OK", "total_trades":0, "report_canonical_path":str(report),
                        "report_sha256":hashlib.sha256(report.read_bytes()).hexdigest()}]}
    if mutation == "wrapper_fail":
        summary.update(result="FAIL", reason_classes=["MIN_TRADES_NOT_MET"])
    if mutation == "wrong_binary":
        summary["execution_identity"]["expert_binary"]["observed_after"]["sha256"] = "b"*64
    if mutation == "traded":
        summary["runs"][0]["total_trades"] = 1
    if mutation == "report_tamper":
        report.write_bytes(b"tampered")
    (run / "summary.json").write_text(json.dumps(summary))
    if mutation == "none":
        assert collector.validate_smoke_summary(tmp_path,payload)["result"] == "PASS"
    else:
        with pytest.raises(collector.InvalidResultsError):
            collector.validate_smoke_summary(tmp_path,payload)
