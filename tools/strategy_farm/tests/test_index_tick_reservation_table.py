"""Per-symbol index-tick reservation table (2026-09-14, Orchestrator; OWNER "alles freigegeben").

The flat 44 GB single_index_tick class came from ONE SP500 observation and made every
full-window index row structurally unwinnable on the 63 GB host (44 + 14 floor = 58 GB
needed, 54.1 GB max free seen).  SP500 keeps its measured 44 GB; NDX/GDAXI/WS30/UK100 get
a provisional per-symbol reservation.  max(flat, measured, floor) semantics are unchanged:
nothing here can LOWER a measured expectation, and the rollback switch restores 44 GB.
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import terminal_worker as tw  # noqa: E402


def _item(symbol: str, phase: str = "Q04", ea_id: str = "QM5_9999") -> dict:
    return {"symbol": symbol, "ea_id": ea_id, "phase": phase}


def test_sp500_keeps_the_measured_44gb(monkeypatch):
    monkeypatch.delenv(tw.INDEX_TICK_RESERVATION_TABLE_ENV, raising=False)
    assert tw._index_tick_reservation_gb("SP500.DWX") == 44.0
    assert tw._commit_reservation_gb_for_item(
        tw.COMMIT_CLASS_SINGLE_INDEX_TICK, _item("SP500.DWX"), {}
    ) == 44.0


def test_other_index_bases_get_the_provisional_table_value(monkeypatch):
    monkeypatch.delenv(tw.INDEX_TICK_RESERVATION_TABLE_ENV, raising=False)
    for base in ("NDX", "GDAXI", "WS30", "UK100"):
        expected = tw.INDEX_TICK_RESERVATION_GB_BY_BASE[base]
        assert expected < tw.SINGLE_INDEX_TICK_COMMIT_RESERVATION_GB
        assert tw._index_tick_reservation_gb(f"{base}.DWX") == expected, base
        assert tw._commit_reservation_gb_for_item(
            tw.COMMIT_CLASS_SINGLE_INDEX_TICK, _item(f"{base}.DWX"), {}
        ) == expected, base


def test_provisional_rows_are_winnable_on_the_63gb_host():
    """44 + 14 = 58 GB never fit (max free seen 54.1 GB); the provisional value must."""
    for base in ("NDX", "GDAXI", "WS30", "UK100"):
        need = tw.INDEX_TICK_RESERVATION_GB_BY_BASE[base] + tw.COMMIT_RESERVATION_FLOOR_GB \
            if hasattr(tw, "COMMIT_RESERVATION_FLOOR_GB") else tw.INDEX_TICK_RESERVATION_GB_BY_BASE[base] + 14.0
        assert need <= 54.0, base
        drained_need = tw.INDEX_TICK_RESERVATION_GB_BY_BASE[base] + tw.DRAIN_ARMED_ROW_FLOOR_GB
        assert drained_need <= 63.0 - tw.DRAIN_WINDOW_HOST_BASELINE_GB, base


def test_unknown_index_base_and_missing_symbol_fall_back_to_flat(monkeypatch):
    monkeypatch.delenv(tw.INDEX_TICK_RESERVATION_TABLE_ENV, raising=False)
    assert tw._index_tick_reservation_gb("JP225.DWX") == 44.0
    assert tw._index_tick_reservation_gb("") == 44.0
    assert tw._commit_reservation_gb_for_item(tw.COMMIT_CLASS_SINGLE_INDEX_TICK, None, {}) == 44.0
    assert tw._commit_reservation_gb_for_item(tw.COMMIT_CLASS_SINGLE_INDEX_TICK, {"symbol": ""}, {}) == 44.0
    # payload host_symbol is the fallback when the item carries no symbol
    assert tw._commit_reservation_gb_for_item(
        tw.COMMIT_CLASS_SINGLE_INDEX_TICK, {"symbol": ""}, {"host_symbol": "NDX.DWX"}
    ) == tw.INDEX_TICK_RESERVATION_GB_BY_BASE["NDX"]


def test_rollback_switch_restores_the_flat_44gb_everywhere(monkeypatch):
    monkeypatch.setenv(tw.INDEX_TICK_RESERVATION_TABLE_ENV, "0")
    for base in ("SP500", "NDX", "GDAXI", "WS30", "UK100"):
        assert tw._index_tick_reservation_gb(f"{base}.DWX") == 44.0, base
    cls, gb, source = tw._ram_reservation_detail_for_candidate(_item("NDX.DWX"), {}, False)
    assert cls == tw.COMMIT_CLASS_SINGLE_INDEX_TICK
    assert gb == 44.0
    assert source == tw.RAM_RESERVATION_SOURCE_FLAT


def test_other_classes_are_untouched():
    for cls in (
        tw.MULTISYMBOL_COMMIT_CLASS_ORDINARY,
        tw.COMMIT_CLASS_OPT_CENSUS_INDEX_CELL,
        tw.MULTISYMBOL_COMMIT_CLASS_TWO_LEG_FX,
        tw.MULTISYMBOL_COMMIT_CLASS_MULTI_LEG_FX,
        tw.MULTISYMBOL_COMMIT_CLASS_HEAVY,
    ):
        assert tw._commit_reservation_gb_for_item(cls, _item("NDX.DWX"), {}) == tw._commit_reservation_gb(cls)


def test_candidate_detail_labels_the_table_and_measured_can_only_raise(monkeypatch, tmp_path):
    monkeypatch.delenv(tw.INDEX_TICK_RESERVATION_TABLE_ENV, raising=False)
    monkeypatch.setenv("QM_TESTER_MEMORY_ADMISSION", "0")  # no ledger expectation in play
    cls, gb, source = tw._ram_reservation_detail_for_candidate(_item("NDX.DWX", "Q04"), {}, False)
    assert cls == tw.COMMIT_CLASS_SINGLE_INDEX_TICK
    assert gb == tw.INDEX_TICK_RESERVATION_GB_BY_BASE["NDX"]
    assert source == tw.RAM_RESERVATION_SOURCE_INDEX_TABLE
    # SP500 stays labelled flat (the table value equals the flat class)
    cls, gb, source = tw._ram_reservation_detail_for_candidate(_item("SP500.DWX", "Q04"), {}, False)
    assert (gb, source) == (44.0, tw.RAM_RESERVATION_SOURCE_FLAT)
    # pure resolver: a measured 30 GB peak raises the 24 GB table value, a 12 GB peak cannot lower it
    gb, source = tw._resolve_ram_reservation(tw.COMMIT_CLASS_SINGLE_INDEX_TICK, 24.0, 30.0, None, multisymbol=False)
    assert (gb, source) == (30.0, tw.RAM_RESERVATION_SOURCE_MEASURED)
    gb, source = tw._resolve_ram_reservation(tw.COMMIT_CLASS_SINGLE_INDEX_TICK, 24.0, 12.0, None, multisymbol=False)
    assert (gb, source) == (24.0, tw.RAM_RESERVATION_SOURCE_FLAT)


def test_claim_stamp_writes_the_per_symbol_reservation(monkeypatch):
    monkeypatch.delenv(tw.INDEX_TICK_RESERVATION_TABLE_ENV, raising=False)
    payload: dict = {}
    tw._set_commit_reservation(
        payload,
        claimed_at_iso="2026-09-14T14:00:00+00:00",
        multisymbol=False,
        commit_class=tw.COMMIT_CLASS_SINGLE_INDEX_TICK,
        item=_item("NDX.DWX"),
    )
    assert payload["commit_reservation_class"] == tw.COMMIT_CLASS_SINGLE_INDEX_TICK
    assert payload["commit_reservation_gb"] == tw.INDEX_TICK_RESERVATION_GB_BY_BASE["NDX"]
    payload2: dict = {}
    tw._set_commit_reservation(
        payload2,
        claimed_at_iso="2026-09-14T14:00:00+00:00",
        multisymbol=False,
        commit_class=tw.COMMIT_CLASS_SINGLE_INDEX_TICK,
    )
    assert payload2["commit_reservation_gb"] == 44.0  # no item -> flat, byte-for-byte the old stamp
