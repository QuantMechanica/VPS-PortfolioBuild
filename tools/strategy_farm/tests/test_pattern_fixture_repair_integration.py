"""Native harness gate must not certify failed CSVs or a different binary."""
import hashlib
import json
from pathlib import Path
import sqlite3

import pytest

from tools.strategy_farm import farmctl, terminal_worker as worker


@pytest.mark.parametrize("exit_code,collection,expected", [
    (0, {"all_expected_passed":True, "bundle_sha256":"a"*64}, "HARNESS_OK"),
    (None, {"all_expected_passed":True, "bundle_sha256":"a"*64}, "HARNESS_FAIL"),
    (1, {"all_expected_passed":True, "bundle_sha256":"a"*64}, "HARNESS_FAIL"),
    (0, {"verdict_counts":{"PASS":1,"FAIL":1}}, "HARNESS_FAIL"),
    (0, {"all_expected_passed":True, "bundle_sha256":"b"*64}, "HARNESS_FAIL"),
])
def test_worker_requires_confirmed_complete_bound_success(tmp_path, monkeypatch, exit_code, collection, expected):
    from framework.scripts import collect_pattern_fixture_harness_results as collector
    monkeypatch.setattr(collector, "collect_results", lambda **kw:collection)
    db = sqlite3.connect(":memory:")
    db.execute("CREATE TABLE work_items(id,status,verdict,evidence_path,claimed_by,payload_json,updated_at)")
    db.execute("INSERT INTO work_items VALUES('x','active',NULL,NULL,'T1','{}','old')")
    payload = {"harness_type":"pattern_permission_fixture", "bundle_csv_sha256":"a"*64}
    result = worker._finish_harness_work_item(db, {}, payload, exit_code, "now", "x")
    assert result["verdict"] == expected
    assert db.execute("SELECT verdict FROM work_items").fetchone()[0] == expected


def test_probe_binary_binding_has_priority_over_old_canonical_binary(tmp_path):
    path = tmp_path / "fixture.ex5"
    path.write_bytes(b"new fixture binary")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    payload = {"harness_source_dir":str(tmp_path), "staged_ex5_path":str(path),
               "staged_ex5_sha256":digest, "expected_ex5_sha256":digest}
    item = {"kind":"harness", "payload_json":json.dumps(payload)}
    result = worker._dispatch_ex5_requirement(item)
    assert result["source"] == path and result["expected_sha256"] == digest
    path.write_bytes(b"mutated")
    with pytest.raises(ValueError, match="source_sha256_mismatch"):
        worker._dispatch_ex5_requirement(item)


def test_integrity_harness_precedes_sibling_baseline_and_census():
    db = sqlite3.connect(":memory:")
    db.execute("CREATE TABLE work_items(id,phase,payload_json)")
    for wid, phase, payload in [("h", "HARNESS_PP_FIXTURE", {}),
                               ("c", "OPT_CENSUS", {}),
                               ("q", "Q02", {"schema":farmctl.DL089_Q02_PREREQUISITE_SCHEMA})]:
        db.execute("INSERT INTO work_items VALUES(?,?,?)", (wid,phase,json.dumps(payload)))
    rank = farmctl._topdown_gate_rank_sql()
    assert db.execute("SELECT id FROM work_items w ORDER BY " + rank).fetchall() == [("h",),("q",),("c",)]


def test_only_short_identified_fixture_has_separate_memory_cohort(monkeypatch):
    item = {"kind":"harness", "phase":"HARNESS_PP_FIXTURE", "symbol":"EURUSD.DWX", "ea_id":"QM_PP_FIXTURE_HARNESS"}
    payload = {"harness_type":"pattern_permission_fixture", "host_timeframe":"D1",
               "from_date":"2024.01.02", "to_date":"2024.01.10"}
    assert worker._tester_memory_run_kind(item,payload) == "fixture"
    assert worker._tester_memory_run_kind({**item, "kind":"backtest"},payload) == "backtest"
    assert worker._tester_memory_run_kind(item,{**payload,"to_date":"2025.01.10"}) == "backtest"
    assert worker._tester_memory_run_kind(item,{**payload,"from_date":"invalid"}) == "backtest"
    monkeypatch.setattr(worker, "_tester_memory_admission_active", lambda:True)
    def peak(symbol_class, timeframe, kind, **kwargs):
        assert timeframe == "D1" and kind == "fixture"
        return 20.0
    monkeypatch.setattr(worker, "_measured_ram_expectation_gb", peak)
    cls, reservation, source = worker._ram_reservation_detail_for_candidate(item,payload,False)
    assert reservation >= 20.0 and source == "measured"
    assert worker._ram_floor_for_class(cls) == worker.RAM_MIN_FREE_GB


def test_census_rejects_db_green_without_native_runner_proof(tmp_path):
    from tools.strategy_farm import opt_census
    from tools.strategy_farm.tests.test_opt_census import _db
    db = sqlite3.connect(_db(tmp_path / "farm.sqlite"))
    payload = {"harness_ex5_sha256":"a"*64, "report_root":str(tmp_path)}
    db.execute("UPDATE work_items SET payload_json=? WHERE id=?", (json.dumps(payload),opt_census.HARNESS_WORK_ITEM_ID))
    with pytest.raises(opt_census.CensusError, match="native proof invalid"):
        opt_census._harness_pass(db,opt_census.HARNESS_WORK_ITEM_ID)
