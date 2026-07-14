from __future__ import annotations

import csv
import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
EA_DIR = ROOT / "framework" / "EAs" / "QM5_13207_ws30-fri-t20a"
SOURCE = EA_DIR / "QM5_13207_ws30-fri-t20a.mq5"
CARD = ROOT / "artifacts" / "cards_approved" / "QM5_13207_ws30-fri-t20a.md"
SPEC = EA_DIR / "SPEC.md"
MAGICS = ROOT / "framework" / "registry" / "magic_numbers.csv"
EA_IDS = ROOT / "framework" / "registry" / "ea_id_registry.csv"
RESOLVER = ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"


def _rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def test_card_and_registries_identify_a_separate_approved_strategy() -> None:
    card = CARD.read_text(encoding="utf-8")
    assert "status: APPROVED" in card
    assert "g0_status: APPROVED" in card
    assert "derived_from: QM5_13202" in card
    assert "ea_id: QM5_13207" in card
    assert "slug: ws30-fri-t20a" in card

    ea_rows = [row for row in _rows(EA_IDS) if row["ea_id"] == "13207"]
    magic_rows = [row for row in _rows(MAGICS) if row["ea_id"] == "13207"]
    assert len(ea_rows) == 1
    assert ea_rows[0]["slug"] == "ws30-fri-t20a"
    assert ea_rows[0]["strategy_id"] == "CODEX-FTMO-WS30-FRI-PM-T20A-20260712_S01"
    assert magic_rows == [
        {
            "ea_id": "13207",
            "ea_slug": "ws30-fri-t20a",
            "symbol_slot": "0",
            "symbol": "WS30.DWX",
            "magic": "132070000",
            "reserved_at": "2026-07-13",
            "reserved_by": "Codex",
            "status": "active",
        }
    ]
    assert "132070000" in RESOLVER.read_text(encoding="utf-8")


def test_trend_gate_is_exact_causal_and_entry_only() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    helper = source[
        source.index("bool Strategy_Trend20dAlign()") :
        source.index("bool Strategy_LockedInputsValid()")
    ]
    entry = source[
        source.index("bool Strategy_EntrySignal(") :
        source.index("void Strategy_ManageOpenPosition()")
    ]

    assert "STRATEGY_TREND_NEWEST_SHIFT = 1" in source
    assert "STRATEGY_TREND_OLDEST_SHIFT = 1921" in source
    assert "iTime(_Symbol, PERIOD_M15, STRATEGY_TREND_NEWEST_SHIFT)" in helper
    assert "iTime(_Symbol, PERIOD_M15, STRATEGY_TREND_OLDEST_SHIFT)" in helper
    assert "iClose(_Symbol, PERIOD_M15, STRATEGY_TREND_NEWEST_SHIFT)" in helper
    assert "iClose(_Symbol, PERIOD_M15, STRATEGY_TREND_OLDEST_SHIFT)" in helper
    assert "newest_close / oldest_close - 1.0" in helper
    assert "signed_return > 0.0" in helper
    assert "PERIOD_D1" not in helper
    assert "TimeCurrent" not in helper
    assert source.count("Strategy_Trend20dAlign()") == 2
    assert entry.index("Strategy_IsEntryTime") < entry.index("Strategy_Trend20dAlign")
    assert entry.index("Strategy_Trend20dAlign") < entry.index("Strategy_SimpleATR")


def test_locked_defaults_fail_initialization_and_no_year_veto_exists() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    locked = source[
        source.index("bool Strategy_LockedInputsValid()") :
        source.index("bool Strategy_NoTradeFilter()")
    ]
    for exact in (
        "qm_ea_id == 13207",
        "qm_magic_slot_offset == 0",
        "strategy_atr_bars == 56",
        "MathAbs(strategy_stop_atr - 1.0) <= 1e-12",
        "strategy_entry_hhmm_ny == 1330",
        "strategy_exit_hhmm_ny == 1600",
        "strategy_weekday_ny == 5",
    ):
        assert exact in locked
    assert "!Strategy_LockedInputsValid()" in source
    assert "2020" not in source
    spec = SPEC.read_text(encoding="utf-8")
    assert "There is no runtime year or 2020 exclusion" in spec


def test_only_research_setfiles_exist_and_bind_current_source_hash() -> None:
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    setfiles = sorted((EA_DIR / "sets").glob("*.set"))
    assert {path.name for path in setfiles} == {
        "QM5_13207_ws30-fri-t20a_WS30.DWX_M15_backtest.set",
        "QM5_13207_ws30-fri-t20a_WS30.DWX_M15_entry_parity_risk10.set",
        "QM5_13207_ws30-fri-t20a_WS30.DWX_M15_native_parity.set",
    }
    canonical = [
        path for path in setfiles if "entry_parity_risk10" not in path.name
    ]
    for setfile in canonical:
        text = setfile.read_text(encoding="utf-8")
        assert "; environment:  backtest" in text
        assert "; symbol:       WS30.DWX" in text
        assert "qm_ea_id=13207" in text
        assert "qm_magic_slot_offset=0" in text
        assert f"; build_hash:   {source_hash}" in text
        assert "strategy_atr_bars=56" in text
        assert "strategy_stop_atr=1.0" in text
        assert "strategy_entry_hhmm_ny=1330" in text
        assert "strategy_exit_hhmm_ny=1600" in text
        assert "strategy_weekday_ny=5" in text
        assert "live" not in setfile.name.lower()

    diagnostic = next(
        path for path in setfiles if "entry_parity_risk10" in path.name
    )
    diagnostic_text = diagnostic.read_text(encoding="utf-8")
    assert "Entry-parity diagnostic only" in diagnostic_text
    assert "qm_ea_id=13207" in diagnostic_text
    assert "qm_magic_slot_offset=0" in diagnostic_text
    assert "RISK_FIXED=10" in diagnostic_text
    assert "RISK_PERCENT=0" in diagnostic_text
    assert "strategy_atr_bars=56" in diagnostic_text
    assert "strategy_stop_atr=1.0" in diagnostic_text
    assert "strategy_entry_hhmm_ny=1330" in diagnostic_text
    assert "strategy_exit_hhmm_ny=1600" in diagnostic_text
    assert "strategy_weekday_ny=5" in diagnostic_text
    assert "live" not in diagnostic.name.lower()
