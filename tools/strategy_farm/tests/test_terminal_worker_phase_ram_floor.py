"""Deterministic PHASE RAM FLOOR (2026-09-05, CEO; host-safety patch).

Three Q05 JPY-cross runs reserved the flat 8 GB "ordinary" commit class and then
took 20-27 GB of the 63 GB host shared with T_Live (2026-09-04 08:09Z
QM5_10395/EURJPY 27.0 GB; 23:45Z QM5_11165/EURJPY 20.8 GB; 2026-09-05 01:32Z
QM5_10691/GBPJPY 23.0 GB), each driving free RAM below 4 GB.  The measured path
could not cover them: the class key needs n >= TESTER_MEMORY_MIN_SAMPLES and the
per-EA key needs a COMPLETED run, and a balloon that is killed never writes a
ledger row.

PHASE_RAM_FLOOR_GB is the a-priori floor a workload-scaled phase (Q05-Q07)
reserves before any measurement exists.  These tests pin the table's shape, the
lookup, the max(flat, measured, floor) resolution, the exclusions (OPT_CENSUS,
COMPILE_EA, multisymbol/basket, Q02-Q04, index) and the facts-only source label.
No gate threshold, verdict, budget or cap is touched by any of it.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest  # noqa: E402

import terminal_worker as tw  # noqa: E402

FLOORED_PHASES = ("Q05", "Q06", "Q07")
# Exactly the labels _tester_memory_symbol_class can emit.
SYMBOL_CLASSES = frozenset({
    "index", "metal", "energy", "fx_major", "fx_cross", "fx_exotic",
    "basket2", "basket3_9", "basket10+", "other",
})
UNTOUCHED_CLASSES = frozenset({"index", "basket2", "basket3_9", "basket10+"})


@pytest.fixture(autouse=True)
def _floor_only(monkeypatch):
    """Default state for these tests: floor live, measured path rolled back."""
    monkeypatch.delenv("QM_PHASE_RAM_FLOOR", raising=False)
    monkeypatch.setenv("QM_TESTER_MEMORY_ADMISSION", "0")
    tw._TESTER_MEMORY_EXPECTATIONS_CACHE.update(
        {"path": None, "mtime": None, "data": {}, "at": -1e9}
    )
    yield


def _write_expectations(path, keys):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps({"schema": "qm.tester_memory_expectations/v2", "keys": keys}),
        encoding="utf-8",
    )


# ---- table shape: monotone and bounded ----------------------------------

def test_table_only_names_workload_scaled_phases():
    assert set(tw.PHASE_RAM_FLOOR_GB) == set(FLOORED_PHASES)
    # The phases whose measured peaks are 0.9-8.1 GB (and the non-backtest
    # lanes) must never carry a floor.
    for phase in ("Q02", "Q03", "Q04", "OPT_CENSUS", "COMPILE_EA", "P2"):
        assert phase not in tw.PHASE_RAM_FLOOR_GB


def test_table_keys_are_real_symbol_classes_and_skip_index_and_baskets():
    for phase, table in tw.PHASE_RAM_FLOOR_GB.items():
        assert table, phase
        for symbol_class in table:
            assert symbol_class in SYMBOL_CLASSES, (phase, symbol_class)
            # index keeps its 44 GB single_index_tick class; baskets keep their
            # own multisymbol commit classes.
            assert symbol_class not in UNTOUCHED_CLASSES, (phase, symbol_class)


def test_table_values_are_bounded():
    for phase, table in tw.PHASE_RAM_FLOOR_GB.items():
        for symbol_class, value in table.items():
            gb = float(value)
            assert gb == gb  # not NaN
            # Never below the documented minimum for a workload-scaled phase ...
            assert gb >= tw.PHASE_RAM_FLOOR_MIN_GB, (phase, symbol_class, gb)
            # ... and never above the heaviest existing class, so the floor can
            # never invent a reservation no host arithmetic was built for.
            assert gb <= tw.SINGLE_INDEX_TICK_COMMIT_RESERVATION_GB
            # Derivation rounds up to the next 2 GB.
            assert gb % 2.0 == 0.0, (phase, symbol_class, gb)
            # Every floored row is "heavy" by the census-first / long-run rule.
            assert gb >= tw.HEAVY_RUN_RAM_GB


def test_table_values_are_monotone_across_phases_per_class():
    # Q05 is the first workload-scaled gate and the one the three balloons hit,
    # so no later gate may claim MORE than it for the same class.
    for symbol_class in sorted(tw.PHASE_RAM_FLOOR_GB["Q05"]):
        values = [
            float(tw.PHASE_RAM_FLOOR_GB[phase][symbol_class])
            for phase in FLOORED_PHASES
            if symbol_class in tw.PHASE_RAM_FLOOR_GB[phase]
        ]
        assert values == sorted(values, reverse=True), (symbol_class, values)


def test_table_ranks_the_crosses_above_the_majors():
    # The measured ordering the ledger shows (fx_cross 18.5 GB > fx_major
    # 15.5 GB > metal 12.0 GB) must survive in the floors.
    for phase in FLOORED_PHASES:
        table = tw.PHASE_RAM_FLOOR_GB[phase]
        assert table["fx_cross"] >= table["fx_major"] >= table["metal"]


def test_q05_fx_cross_floor_covers_the_three_incidents():
    # 20.8 / 23.0 / 27.0 GB balloons -> the floor must clear the middle two and
    # is the documented 24 GB.
    assert tw.PHASE_RAM_FLOOR_GB["Q05"]["fx_cross"] >= 24.0


# ---- lookup -------------------------------------------------------------

def test_lookup_returns_the_tabled_floor():
    assert tw._phase_ram_floor_gb("Q05", "fx_cross") == 24.0
    assert tw._phase_ram_floor_gb("Q05", "fx_major") == 16.0
    assert tw._phase_ram_floor_gb("Q07", "metal") == 12.0


def test_lookup_normalizes_case_and_whitespace():
    assert tw._phase_ram_floor_gb(" q05 ", "fx_cross") == 24.0


def test_lookup_none_for_untabled_phase_or_class():
    assert tw._phase_ram_floor_gb("Q04", "fx_cross") is None
    assert tw._phase_ram_floor_gb("OPT_CENSUS", "fx_cross") is None
    assert tw._phase_ram_floor_gb("COMPILE_EA", "fx_major") is None
    assert tw._phase_ram_floor_gb("Q05", "index") is None
    assert tw._phase_ram_floor_gb("Q05", "basket3_9") is None
    assert tw._phase_ram_floor_gb(None, None) is None


def test_lookup_disabled_by_kill_switch(monkeypatch):
    monkeypatch.setenv("QM_PHASE_RAM_FLOOR", "0")
    assert tw._phase_ram_floor_gb("Q05", "fx_cross") is None


def test_lookup_none_when_table_emptied(monkeypatch):
    # Documented rollback: empty the table.
    monkeypatch.setattr(tw, "PHASE_RAM_FLOOR_GB", {})
    assert tw._phase_ram_floor_gb("Q05", "fx_cross") is None


# ---- pure resolver ------------------------------------------------------

def test_resolver_floor_raises_the_flat_class():
    assert tw._resolve_ram_reservation(
        "ordinary", 8.0, None, 24.0, multisymbol=False
    ) == (24.0, tw.RAM_RESERVATION_SOURCE_PHASE_FLOOR)


def test_resolver_measured_larger_than_floor_wins():
    assert tw._resolve_ram_reservation(
        "ordinary", 8.0, 27.0, 24.0, multisymbol=False
    ) == (27.0, tw.RAM_RESERVATION_SOURCE_MEASURED)


def test_resolver_floor_never_lowers_a_heavier_class():
    # index: 44 GB flat, a 12 GB floor may not touch it.
    assert tw._resolve_ram_reservation(
        tw.COMMIT_CLASS_SINGLE_INDEX_TICK, 44.0, None, 12.0, multisymbol=False
    ) == (44.0, tw.RAM_RESERVATION_SOURCE_FLAT)
    # measured below the floor is likewise only ever raised.
    assert tw._resolve_ram_reservation(
        "ordinary", 8.0, 18.5, 24.0, multisymbol=False
    ) == (24.0, tw.RAM_RESERVATION_SOURCE_PHASE_FLOOR)


def test_resolver_ignores_floor_for_multisymbol_and_census():
    assert tw._resolve_ram_reservation(
        "ordinary", 8.0, None, 24.0, multisymbol=True
    ) == (8.0, tw.RAM_RESERVATION_SOURCE_FLAT)
    assert tw._resolve_ram_reservation(
        tw.RAM_CLASS_OPT_CENSUS_CELL, 4.0, None, 24.0, multisymbol=False
    ) == (4.0, tw.RAM_RESERVATION_SOURCE_FLAT)


def test_resolver_without_floor_is_todays_rule_exactly():
    assert tw._resolve_ram_reservation(
        "ordinary", 8.0, None, None, multisymbol=False
    ) == (8.0, tw.RAM_RESERVATION_SOURCE_FLAT)
    # measured <= TESTER_MEMORY_HEAVY_GB keeps the flat class
    assert tw._resolve_ram_reservation(
        "ordinary", 8.0, 9.5, None, multisymbol=False
    ) == (8.0, tw.RAM_RESERVATION_SOURCE_FLAT)
    assert tw._resolve_ram_reservation(
        "ordinary", 8.0, 18.0, None, multisymbol=False
    ) == (18.0, tw.RAM_RESERVATION_SOURCE_MEASURED)


def test_gb_wrapper_keeps_the_float_return_shape():
    assert tw._resolve_ram_reservation_gb(
        "ordinary", 8.0, None, 24.0, multisymbol=False
    ) == 24.0
    # the pre-patch 3-positional call site still resolves unchanged
    assert tw._resolve_ram_reservation_gb(
        "ordinary", 8.0, 18.0, multisymbol=False
    ) == 18.0


# ---- candidate end-to-end ----------------------------------------------

def _q(phase, symbol, ea_id="QM5_10691", timeframe="H4"):
    return (
        {"phase": phase, "symbol": symbol, "ea_id": ea_id},
        {"host_timeframe": timeframe},
    )


def test_q05_fx_cross_candidate_reserves_at_least_24gb():
    item, payload = _q("Q05", "GBPJPY.DWX")
    ram_class, reservation = tw._ram_reservation_for_candidate(item, payload, False)
    assert ram_class == tw.MULTISYMBOL_COMMIT_CLASS_ORDINARY
    assert reservation >= 24.0
    # the incident shape (EURJPY) resolves identically
    item, payload = _q("Q05", "EURJPY.DWX", ea_id="QM5_10395")
    assert tw._ram_reservation_for_candidate(item, payload, False)[1] >= 24.0


def test_q05_fx_major_and_metal_reserve_their_floors():
    item, payload = _q("Q05", "USDJPY.DWX", ea_id="QM5_11179", timeframe="M5")
    assert tw._ram_reservation_for_candidate(item, payload, False)[1] == 16.0
    item, payload = _q("Q05", "XAUUSD.DWX", ea_id="QM5_1634", timeframe="H1")
    assert tw._ram_reservation_for_candidate(item, payload, False)[1] == 14.0


def test_q06_and_q07_are_floored_too():
    item, payload = _q("Q06", "USDJPY.DWX")
    assert tw._ram_reservation_for_candidate(item, payload, False)[1] == 16.0
    item, payload = _q("Q07", "XAUUSD.DWX")
    assert tw._ram_reservation_for_candidate(item, payload, False)[1] == 12.0


def test_q04_and_earlier_are_unchanged():
    for phase in ("Q02", "Q03", "Q04"):
        item, payload = _q(phase, "EURJPY.DWX")
        assert tw._ram_reservation_for_candidate(item, payload, False) == (
            tw.MULTISYMBOL_COMMIT_CLASS_ORDINARY,
            8.0,
        ), phase


def test_opt_census_is_unchanged():
    item, payload = _q("OPT_CENSUS", "EURJPY.DWX")
    assert tw._ram_reservation_for_candidate(item, payload, False) == (
        tw.RAM_CLASS_OPT_CENSUS_CELL,
        tw.OPT_CENSUS_RAM_RESERVATION_GB,
    )


def test_compile_ea_is_unchanged():
    item, payload = _q("COMPILE_EA", "EURJPY.DWX")
    assert tw._ram_reservation_for_candidate(item, payload, False) == (
        tw.MULTISYMBOL_COMMIT_CLASS_ORDINARY,
        8.0,
    )


def test_basket_rows_are_unchanged():
    item = {"phase": "Q05", "symbol": "EURJPY.DWX", "ea_id": "QM5_41192"}
    two_leg = {"basket_symbols": ["EURUSD.DWX", "GBPUSD.DWX"], "basket_symbol_count": 2}
    multi_leg = {
        "basket_symbols": ["EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX"],
        "basket_symbol_count": 3,
    }
    assert tw._ram_reservation_for_candidate(item, two_leg, True) == (
        tw.MULTISYMBOL_COMMIT_CLASS_TWO_LEG_FX,
        8.0,
    )
    assert tw._ram_reservation_for_candidate(item, multi_leg, True) == (
        tw.MULTISYMBOL_COMMIT_CLASS_MULTI_LEG_FX,
        32.0,
    )


def test_index_row_keeps_its_44gb_class():
    item, payload = _q("Q05", "SP500.DWX", ea_id="QM5_B")
    assert tw._ram_reservation_for_candidate(item, payload, False) == (
        tw.COMMIT_CLASS_SINGLE_INDEX_TICK,
        tw.SINGLE_INDEX_TICK_COMMIT_RESERVATION_GB,
    )


def test_kill_switch_restores_the_pre_patch_reservation(monkeypatch):
    monkeypatch.setenv("QM_PHASE_RAM_FLOOR", "0")
    item, payload = _q("Q05", "GBPJPY.DWX")
    assert tw._ram_reservation_for_candidate(item, payload, False) == (
        tw.MULTISYMBOL_COMMIT_CLASS_ORDINARY,
        8.0,
    )


def test_measured_expectation_larger_than_floor_wins_end_to_end(
    tmp_path, monkeypatch
):
    # The 27 GB QM5_10395/EURJPY balloon, once the reaper's synthesized ledger
    # row has been aggregated, must beat the 24 GB floor rather than be capped
    # by it.
    monkeypatch.delenv("QM_TESTER_MEMORY_ADMISSION", raising=False)
    path = tmp_path / "exp.json"
    _write_expectations(path, {"ea:QM5_10395|H4|backtest": {"n": 1, "max_gb": 27.0}})
    monkeypatch.setenv("QM_TESTER_MEMORY_EXPECTATIONS", str(path))
    item, payload = _q("Q05", "EURJPY.DWX", ea_id="QM5_10395")
    ram_class, reservation, source = tw._ram_reservation_detail_for_candidate(
        item, payload, False
    )
    assert (ram_class, reservation) == (tw.MULTISYMBOL_COMMIT_CLASS_ORDINARY, 27.0)
    assert source == tw.RAM_RESERVATION_SOURCE_MEASURED


def test_measured_expectation_below_floor_does_not_lower_it(tmp_path, monkeypatch):
    monkeypatch.delenv("QM_TESTER_MEMORY_ADMISSION", raising=False)
    path = tmp_path / "exp.json"
    _write_expectations(path, {"ea:QM5_10295|D1|backtest": {"n": 1, "max_gb": 18.5}})
    monkeypatch.setenv("QM_TESTER_MEMORY_EXPECTATIONS", str(path))
    item, payload = _q("Q05", "CHFJPY.DWX", ea_id="QM5_10295", timeframe="D1")
    _cls, reservation, source = tw._ram_reservation_detail_for_candidate(
        item, payload, False
    )
    assert reservation == 24.0
    assert source == tw.RAM_RESERVATION_SOURCE_PHASE_FLOOR


# ---- source field recorded ---------------------------------------------

def test_source_label_reports_the_governing_rule():
    item, payload = _q("Q05", "GBPJPY.DWX")
    assert (
        tw._ram_reservation_source_label(item, payload, False)
        == tw.RAM_RESERVATION_SOURCE_PHASE_FLOOR
    )
    item, payload = _q("Q04", "GBPJPY.DWX")
    assert (
        tw._ram_reservation_source_label(item, payload, False)
        == tw.RAM_RESERVATION_SOURCE_FLAT
    )
    item, payload = _q("OPT_CENSUS", "GBPJPY.DWX")
    assert (
        tw._ram_reservation_source_label(item, payload, False)
        == tw.RAM_RESERVATION_SOURCE_FLAT
    )


def test_source_label_fails_open_to_flat(monkeypatch):
    def boom(*args, **kwargs):
        raise RuntimeError("classification unavailable")

    monkeypatch.setattr(tw, "_ram_reservation_detail_for_candidate", boom)
    assert (
        tw._ram_reservation_source_label({}, {}, False)
        == tw.RAM_RESERVATION_SOURCE_FLAT
    )


def test_drain_candidate_facts_carry_the_source():
    # A priority-tracked Q05 fx_cross row now reserves 24 GB, which is exactly
    # DRAIN_WINDOW_MIN_RESERVATION_GB, so it becomes drain-armable; the
    # descriptor must say which rule produced that number.
    item = {"id": "wi-jpy", "ea_id": "QM5_10691", "phase": "Q05", "symbol": "GBPJPY.DWX"}
    payload = {"priority_track": True, "host_timeframe": "H4"}
    candidate = tw._drain_candidate_from_row(
        item, payload, free_ram_gb=10.0, host_total_gb=63.1,
        multisym_ids=frozenset(),
    )
    assert candidate is not None
    assert candidate["reservation_gb"] == 24.0
    assert candidate["ram_reservation_source"] == tw.RAM_RESERVATION_SOURCE_PHASE_FLOOR


# ---- admission consequence ---------------------------------------------

def test_floored_rows_are_heavy_for_census_first_and_the_long_run_cap():
    import longrun_scheduling_policy as lrp

    item, payload = _q("Q05", "GBPJPY.DWX")
    _cls, reservation = tw._ram_reservation_for_candidate(item, payload, False)
    # census-first now sees a heavy row where it saw an 8 GB ordinary one
    assert reservation >= tw.HEAVY_RUN_RAM_GB
    # ... and the post-reservation admission arithmetic moves with it
    assert reservation + tw.RAM_MIN_FREE_GB == 38.0
    assert reservation + tw._census_first_protected_band_gb() == 40.0
    # Two active Q07 long runs now reach the measured long-run RAM cap where
    # three 8 GB reservations previously did not.
    item, payload = _q("Q07", "USDJPY.DWX")
    _cls, q07 = tw._ram_reservation_for_candidate(item, payload, False)
    assert max(q07, tw.DRAIN_LONG_RUN_FLOOR_GB) == 16.0
    assert 2 * 16.0 >= lrp.LONG_RUN_RAM_CAP_GB
    assert 3 * tw.DRAIN_LONG_RUN_FLOOR_GB < lrp.LONG_RUN_RAM_CAP_GB
