"""Q02 canary ranking tracks terminal_worker's RAM-reservation classes.

2026-09-18 (MNT-0xx): the Q02 first-intake canary was picked by a hand
-maintained liquidity priority list (``Q02_CANARY_SYMBOL_PRIORITY``, retired)
that silently drifted from terminal_worker's admission-lane RAM calibration
table and could rank a 44GB single_index_tick host (SP500) ahead of a cheaper
one. ``_q02_canary_symbol_rank`` now delegates to
``terminal_worker._ram_reservation_detail_for_candidate`` so the two can never
diverge again.
"""
import pytest

from tools.strategy_farm import farmctl


@pytest.fixture(autouse=True)
def _no_measured_ram_ledger(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("QM_TESTER_MEMORY_ADMISSION", "0")


def test_ordinary_fx_and_metal_symbols_all_rank_at_the_flat_8gb_class() -> None:
    for symbol in ("EURUSD.DWX", "USDJPY.DWX", "GBPUSD.DWX", "XAUUSD.DWX"):
        assert farmctl._q02_canary_symbol_rank(symbol) == 8.0, symbol


def test_index_bases_rank_at_their_calibrated_table_value() -> None:
    import terminal_worker as tw  # imported lazily like farmctl does

    for base in ("SP500", "NDX", "GDAXI", "WS30", "UK100"):
        expected = tw.INDEX_TICK_RESERVATION_GB_BY_BASE[base]
        assert farmctl._q02_canary_symbol_rank(f"{base}.DWX") == expected, base


def test_a_cheaper_index_base_ranks_below_a_44gb_exclusive_class_host() -> None:
    assert farmctl._q02_canary_symbol_rank("UK100.DWX") < farmctl._q02_canary_symbol_rank("SP500.DWX")


def test_rank_is_case_insensitive_and_defaults_ea_id() -> None:
    assert farmctl._q02_canary_symbol_rank("ndx.dwx") == farmctl._q02_canary_symbol_rank("NDX.DWX")


def test_ea_id_does_not_change_a_single_symbol_rank() -> None:
    # ea_id only matters for the legacy multisymbol two-leg-FX host lookup;
    # single-symbol Q02 canary candidates are never multisymbol.
    assert farmctl._q02_canary_symbol_rank("EURUSD.DWX", "QM5_1") == farmctl._q02_canary_symbol_rank(
        "EURUSD.DWX", "QM5_99999"
    )
