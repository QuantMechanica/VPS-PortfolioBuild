"""Tests: OBSERVE projector manifest + INFRA/strategy separation; research_env guard."""

from __future__ import annotations

import json
import sys
from pathlib import Path

SF = Path(__file__).resolve().parents[1]
if str(SF) not in sys.path:
    sys.path.insert(0, str(SF))

from research import observe_projector, research_env  # noqa: E402
from _research_fixtures import build_fixture_db, build_registry_csv  # noqa: E402


def _dataset(tmp_path):
    db = build_fixture_db(tmp_path / "farm_state.sqlite")
    registry = build_registry_csv(tmp_path / "ea_id_registry.csv")
    out_root = tmp_path / "datasets"
    manifest = observe_projector.project(db, out_root, registry_path=registry)
    return manifest, Path(manifest["dataset_dir"])


def test_manifest_shape_and_content_addressing(tmp_path):
    manifest, dataset_dir = _dataset(tmp_path)

    assert manifest["schema"] == "qm.research-dataset/v1"
    assert manifest["dataset_id"]  # sha256 of the manifest file
    # Every emitted CSV has a sha256 and a row count.
    for name in ("gate_outcomes.csv", "ea_metrics.csv", "holds.csv", "idea_families.csv", "sources.csv"):
        assert name in manifest["sha256"], name
        assert name in manifest["row_counts"], name
        assert (dataset_dir / name).exists()
    # manifest.json on disk parses and its own sha matches dataset_id.
    on_disk = json.loads((dataset_dir / "manifest.json").read_text(encoding="utf-8"))
    assert on_disk["source_db_size_bytes"] == manifest["source_db_size_bytes"]
    assert manifest["source_db_mtime_utc"]  # snapshot note carries the mtime


def test_whitespace_fields_in_gate_outcomes(tmp_path):
    """directive §46: gate_outcomes now carries timeframe/holding/symbol_class/session."""
    import csv

    _, dataset_dir = _dataset(tmp_path)
    rows = list(csv.DictReader((dataset_dir / "gate_outcomes.csv").open(encoding="utf-8")))
    by_wid = {r["work_item_id"]: r for r in rows}
    for col in ("timeframe", "holding_class", "symbol_class", "session"):
        assert col in rows[0], col

    # w1: EURUSD H1 setfile -> intraday / fx_major.
    assert by_wid["w1"]["timeframe"] == "H1"
    assert by_wid["w1"]["holding_class"] == "intraday"
    assert by_wid["w1"]["symbol_class"] == "fx_major"
    # w4: XAUUSD M15 -> intraday / metal.
    assert by_wid["w4"]["timeframe"] == "M15"
    assert by_wid["w4"]["holding_class"] == "intraday"
    assert by_wid["w4"]["symbol_class"] == "metal"
    # w5: GBPUSD D1 -> position / fx_major.
    assert by_wid["w5"]["timeframe"] == "D1"
    assert by_wid["w5"]["holding_class"] == "position"
    assert by_wid["w5"]["symbol_class"] == "fx_major"
    # No fixture EA slug encodes a session -> unspecified.
    assert by_wid["w1"]["session"] == "unspecified"


def test_classify_helpers_are_deterministic():
    op = observe_projector
    assert op.classify_timeframe("QM5_1_x_EURUSD.DWX_M15_q05.set") == "M15"
    assert op.classify_timeframe("QM5_1_x_EURUSD.DWX_M1_q05.set") == "M1"
    assert op.classify_timeframe("no timeframe here") == ""
    assert op.classify_holding("M5") == "scalp"
    assert op.classify_holding("H4") == "swing"
    assert op.classify_holding("") == ""
    assert op.classify_symbol_class("XAUUSD.DWX") == "metal"
    assert op.classify_symbol_class("SP500") == "index"
    assert op.classify_symbol_class("XNGUSD.DWX") == "energy"
    assert op.classify_symbol_class("EURGBP.DWX") == "fx_cross"
    assert op.classify_symbol_class("EURUSD") == "fx_major"
    # Session keyword families (ORB checked before city sessions).
    assert op.classify_session("gh-asian-sweep") == "asian"
    assert op.classify_session("tv-london-session") == "london"
    assert op.classify_session("tv-orb-breakout") == "open"
    assert op.classify_session("chan-overnight-drift") == "overnight"
    assert op.classify_session("ema-trend-cross") == "unspecified"


def test_parameter_sensitivity_only_where_derivable(tmp_path):
    """directive §45: parameter_sensitivity is emitted only from a real census runs list."""
    import csv

    manifest, dataset_dir = _dataset(tmp_path)
    assert "parameter_sensitivity.csv" in manifest["sha256"]
    assert "parameter_sensitivity.csv" in manifest["row_counts"]
    rows = list(csv.DictReader((dataset_dir / "parameter_sensitivity.csv").open(encoding="utf-8")))
    # Only the OPT_CENSUS row (w5) carries a runs list; the empty-detail rows do not.
    by_wid = {r["work_item_id"]: r for r in rows}
    assert set(by_wid) == {"w5"}
    w5 = by_wid["w5"]
    assert w5["n_runs"] == "3"
    assert float(w5["pf_min"]) == 0.95
    assert float(w5["pf_max"]) == 1.30
    assert w5["pf_cv"] != ""  # a spread was computed across >=2 runs
    assert w5["derivation"] == "objective_spread_over_census_runs"

    # A single-run payload is derivable but carries no cv (never invented).
    single = observe_projector.extract_parameter_sensitivity(
        '{"n_runs": 1, "runs": [{"profit_factor": 1.1, "net_profit": 10.0}]}'
    )
    assert single["derivation"] == "single_run" and single["pf_cv"] == ""
    # Empty / structureless payloads yield nothing.
    assert observe_projector.extract_parameter_sensitivity("{}") is None
    assert observe_projector.extract_parameter_sensitivity('{"reason": "x"}') is None


def test_infra_vs_strategy_kept_apart(tmp_path):
    manifest, dataset_dir = _dataset(tmp_path)
    rows = list(__import__("csv").DictReader((dataset_dir / "gate_outcomes.csv").open(encoding="utf-8")))
    by_wid = {r["work_item_id"]: r for r in rows}

    # w3 is INFRA_FAIL -> infra taxonomy, reason_class an INFRA token, never strategy.
    assert by_wid["w3"]["verdict_taxonomy"] == "infra"
    assert by_wid["w3"]["reason_class"] == "ACTIVE_TIMEOUT"
    # w1 is a gate PASS -> strategy taxonomy.
    assert by_wid["w1"]["verdict_taxonomy"] == "strategy"
    assert by_wid["w1"]["reason_class"] == "PASS"
    # w5 MEASURED -> measurement, DISJOINT from strategy.
    assert by_wid["w5"]["verdict_taxonomy"] == "measurement"

    # The manifest's split enumerates every taxonomy -> a single disposition.
    split = manifest["verdict_taxonomy_split"]
    assert split["infra"]["disposition"] == "infra"
    assert split["strategy"]["disposition"] == "economic"
    assert split["measurement"]["disposition"] == "measurement"
    # No taxonomy is dropped silently: rows sum to the gate_outcomes row count.
    assert sum(v["rows"] for v in split.values()) == manifest["row_counts"]["gate_outcomes.csv"]


def test_idea_families_derived_from_slug(tmp_path):
    _, dataset_dir = _dataset(tmp_path)
    rows = list(__import__("csv").DictReader((dataset_dir / "idea_families.csv").open(encoding="utf-8")))
    fam = {r["ea_id"]: r["family"] for r in rows}
    assert fam["QM5_1001"] == "trend"
    assert fam["QM5_1002"] == "mean_reversion"
    assert fam["QM5_1003"] == "breakout"


def test_limit_bounds_rows(tmp_path):
    db = build_fixture_db(tmp_path / "farm_state.sqlite")
    registry = build_registry_csv(tmp_path / "ea_id_registry.csv")
    manifest = observe_projector.project(db, tmp_path / "ds", registry_path=registry, limit=2)
    assert manifest["row_counts"]["gate_outcomes.csv"] == 2
    assert manifest["limit"] == 2


def test_projector_is_read_only(tmp_path):
    """The DB file bytes are unchanged after projection (mode=ro + query_only)."""
    import hashlib

    db = build_fixture_db(tmp_path / "farm_state.sqlite")
    registry = build_registry_csv(tmp_path / "ea_id_registry.csv")
    before = hashlib.sha256(db.read_bytes()).hexdigest()
    observe_projector.project(db, tmp_path / "ds", registry_path=registry)
    after = hashlib.sha256(db.read_bytes()).hexdigest()
    assert before == after


# --- research_env guard ------------------------------------------------------


def test_guard_allows_when_clear(tmp_path):
    result = research_env.research_guard(
        cpu_percent=10.0, disk_free_gb=200.0, free_ram_gb=40.0, lock_status="absent"
    )
    assert result.allowed
    assert result.reasons == []
    assert result.max_worker_processes == 2


def test_guard_refuses_high_cpu():
    result = research_env.research_guard(
        cpu_percent=99.0, disk_free_gb=200.0, free_ram_gb=40.0, lock_status="absent"
    )
    assert not result.allowed
    assert any(r.startswith("CPU_HIGH") for r in result.reasons)
    # The CPU line is READ from the worker constant, never redefined.
    assert result.measurements["cpu_high_pause_percent"] == research_env.CPU_HIGH_PAUSE_PERCENT


def test_guard_refuses_low_disk():
    result = research_env.research_guard(
        cpu_percent=10.0, disk_free_gb=10.0, free_ram_gb=40.0, lock_status="absent"
    )
    assert not result.allowed
    assert any(r.startswith("DISK_LOW") for r in result.reasons)


def test_guard_refuses_live_mutation_lock():
    result = research_env.research_guard(
        cpu_percent=10.0, disk_free_gb=200.0, free_ram_gb=40.0, lock_status="live"
    )
    assert not result.allowed
    assert any(r.startswith("MUTATION_LOCK_LIVE") for r in result.reasons)


def test_guard_scratch_floor_is_20gb():
    # Recalibrated from the flat 80 GB D: floor to a measured 20 GB scratch-volume
    # floor (OWNER directive 2026-09-15 §34; audit research_disk_guard.md R1).
    assert research_env.RESEARCH_DISK_MIN_FREE_GB == 20.0
