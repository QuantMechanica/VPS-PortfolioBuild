"""Tests for the empirical resource-footprint read-model (directive 3 §12)."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import resource_footprint_readmodel as rf  # noqa: E402


def _rec(ts, ram_class, symbol_class, phase, run_kind, peak, dur=100.0, reservation=8.0, symbol="EURUSD.DWX", ea_id="QM5_1"):
    return {
        "schema": "qm.tester_memory_ledger/v1",
        "ts_utc": ts,
        "ea_id": ea_id,
        "symbol": symbol,
        "symbol_class": symbol_class,
        "phase": phase,
        "run_kind": run_kind,
        "ram_class": ram_class,
        "reservation_gb": reservation,
        "run_seconds": dur,
        "peak_subtree_working_set_gb": peak,
    }


def _write_ledger(tmp_path, recs):
    p = tmp_path / "ledger.jsonl"
    with open(p, "w", encoding="utf-8") as h:
        for r in recs:
            h.write(json.dumps(r) + "\n")
    return p


NOW = "2026-09-15T12:00:00+00:00"


def test_percentile_linear_interpolation():
    assert rf._percentile([], 95) == 0.0
    assert rf._percentile([5.0], 95) == 5.0
    assert rf._percentile([0.0, 10.0], 50) == 5.0
    assert rf._percentile([0.0, 10.0], 95) == 9.5


def test_window_filter_drops_old_records(tmp_path):
    recs = [
        _rec("2026-09-14T12:00:00+00:00", "ordinary", "fx_major", "Q04", "backtest", 10.0),
        _rec("2026-08-01T12:00:00+00:00", "ordinary", "fx_major", "Q04", "backtest", 99.0),  # >14d old
    ]
    led = _write_ledger(tmp_path, recs)
    readmodel, _ = rf.build(
        ledger_path=led, window_days=14, proposal_config=dict(rf.DEFAULT_PROPOSAL_CONFIG),
        family_map=None, now=rf._parse_ts(NOW),
    )
    assert readmodel["records"]["in_window"] == 1
    assert readmodel["records"]["seen_total"] == 2
    cls = readmodel["footprints"]["by_ram_class"]["ordinary"]
    assert cls["n"] == 1
    assert cls["peak_ram_gb"]["max"] == 10.0


def test_cpu_and_disk_are_not_evaluated(tmp_path):
    led = _write_ledger(tmp_path, [_rec(NOW, "ordinary", "fx_major", "Q04", "backtest", 10.0)])
    readmodel, _ = rf.build(
        ledger_path=led, window_days=14, proposal_config=dict(rf.DEFAULT_PROPOSAL_CONFIG),
        family_map=None, now=rf._parse_ts(NOW),
    )
    ne = readmodel["not_evaluated"]
    assert ne["cpu_share"].startswith("EVIDENCE_MISSING")
    assert ne["disk_io"].startswith("EVIDENCE_MISSING")


def test_family_evidence_missing_without_map(tmp_path):
    led = _write_ledger(tmp_path, [_rec(NOW, "ordinary", "fx_major", "Q04", "backtest", 10.0)])
    readmodel, _ = rf.build(
        ledger_path=led, window_days=14, proposal_config=dict(rf.DEFAULT_PROPOSAL_CONFIG),
        family_map=None, now=rf._parse_ts(NOW),
    )
    assert readmodel["family"]["family_source"] == "EVIDENCE_MISSING"


def test_family_mapped(tmp_path):
    led = _write_ledger(tmp_path, [
        _rec(NOW, "ordinary", "fx_major", "Q04", "backtest", 10.0, ea_id="QM5_1"),
        _rec(NOW, "ordinary", "fx_major", "Q04", "backtest", 20.0, ea_id="QM5_2"),
    ])
    readmodel, _ = rf.build(
        ledger_path=led, window_days=14, proposal_config=dict(rf.DEFAULT_PROPOSAL_CONFIG),
        family_map={"QM5_1": "trend", "QM5_2": "trend"}, now=rf._parse_ts(NOW),
    )
    fam = readmodel["family"]
    assert fam["family_source"] == "MAPPED"
    assert fam["mapped_records"] == 2
    assert fam["by_family"]["trend"]["n"] == 2


def test_proposal_low_evidence_keeps_live(tmp_path):
    # only 3 samples for single_index_tick -> below min_samples_for_proposal (8)
    recs = [_rec(NOW, "single_index_tick", "index", "Q04", "backtest", 8.0, reservation=44.0, symbol="NDX.DWX") for _ in range(3)]
    led = _write_ledger(tmp_path, recs)
    _, proposal = rf.build(
        ledger_path=led, window_days=14, proposal_config=dict(rf.DEFAULT_PROPOSAL_CONFIG),
        family_map=None, now=rf._parse_ts(NOW),
    )
    entry = proposal["reservation_by_ram_class"]["single_index_tick"]
    assert entry["low_evidence"] is True
    assert entry["proposed_reservation_gb"] == 44.0  # kept live (never lowered)


def test_proposal_calibrates_with_enough_evidence(tmp_path):
    # 10 samples all peaking at 10 GB -> p95 ~10 -> proposed ceil(10*1.5+2)=17
    recs = [_rec(NOW, "single_index_tick", "index", "Q04", "backtest", 10.0, reservation=44.0, symbol="NDX.DWX") for _ in range(10)]
    led = _write_ledger(tmp_path, recs)
    _, proposal = rf.build(
        ledger_path=led, window_days=14, proposal_config=dict(rf.DEFAULT_PROPOSAL_CONFIG),
        family_map=None, now=rf._parse_ts(NOW),
    )
    entry = proposal["reservation_by_ram_class"]["single_index_tick"]
    assert entry["low_evidence"] is False
    assert entry["proposed_reservation_gb"] == 17.0
    assert entry["delta_vs_live_gb"] == -27.0
    # index base recalibrated too
    base = proposal["index_reservation_by_symbol_base"]["NDX"]
    assert base["proposed_reservation_gb"] == 17.0


def test_proposal_never_switches_flag(tmp_path):
    led = _write_ledger(tmp_path, [_rec(NOW, "ordinary", "fx_major", "Q04", "backtest", 10.0)])
    _, proposal = rf.build(
        ledger_path=led, window_days=14, proposal_config=dict(rf.DEFAULT_PROPOSAL_CONFIG),
        family_map=None, now=rf._parse_ts(NOW),
    )
    assert proposal["activation"]["env"] == "QM_RAM_TABLE"
    assert proposal["activation"]["value_to_activate"] == "calibrated"
    assert "NEVER" in proposal["activation"]["note"]


def test_deterministic_output(tmp_path):
    recs = [
        _rec(NOW, "ordinary", "fx_major", "Q04", "backtest", 10.0),
        _rec(NOW, "opt_census_cell", "index", "OPT_CENSUS", "census", 3.0, reservation=4.0),
    ]
    led = _write_ledger(tmp_path, recs)
    a, pa = rf.build(ledger_path=led, window_days=14, proposal_config=dict(rf.DEFAULT_PROPOSAL_CONFIG), family_map=None, now=rf._parse_ts(NOW))
    b, pb = rf.build(ledger_path=led, window_days=14, proposal_config=dict(rf.DEFAULT_PROPOSAL_CONFIG), family_map=None, now=rf._parse_ts(NOW))
    assert json.dumps(a, sort_keys=True) == json.dumps(b, sort_keys=True)
    assert json.dumps(pa, sort_keys=True) == json.dumps(pb, sort_keys=True)


def test_schema_and_generated_at(tmp_path):
    led = _write_ledger(tmp_path, [_rec(NOW, "ordinary", "fx_major", "Q04", "backtest", 10.0)])
    readmodel, proposal = rf.build(
        ledger_path=led, window_days=14, proposal_config=dict(rf.DEFAULT_PROPOSAL_CONFIG),
        family_map=None, now=rf._parse_ts(NOW),
    )
    assert readmodel["schema"] == "qm.resource-footprints/v1"
    assert readmodel["generated_at_utc"].startswith("2026-09-15T12:00:00")
    assert proposal["schema"] == "qm.resource-footprints-proposal/v1"


def test_malformed_lines_skipped(tmp_path):
    p = tmp_path / "ledger.jsonl"
    with open(p, "w", encoding="utf-8") as h:
        h.write("{not json\n")
        h.write(json.dumps(_rec(NOW, "ordinary", "fx_major", "Q04", "backtest", 10.0)) + "\n")
        h.write("\n")
    readmodel, _ = rf.build(
        ledger_path=p, window_days=14, proposal_config=dict(rf.DEFAULT_PROPOSAL_CONFIG),
        family_map=None, now=rf._parse_ts(NOW),
    )
    assert readmodel["records"]["in_window"] == 1
