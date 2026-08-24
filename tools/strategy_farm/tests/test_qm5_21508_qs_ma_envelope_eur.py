import csv
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_21508_qs-ma-envelope-eur"
EA_DIR = REPO / "framework" / "EAs" / EA_LABEL
SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
SETFILE = EA_DIR / "sets" / f"{EA_LABEL}_EURUSD.DWX_D1_backtest.set"


def _source() -> str:
    return SOURCE.read_text(encoding="utf-8")


def test_card_mechanism_is_wired_exactly() -> None:
    source = _source()

    assert "const double upper_1 = sma_1 * (1.0 + strategy_envelope_pct);" in source
    assert "const double lower_1 = sma_1 * (1.0 - strategy_envelope_pct);" in source
    assert "close_1 < lower_1 && close_2 >= lower_2" in source
    assert "close_1 > upper_1 && close_2 <= upper_2" in source
    assert "position_type == POSITION_TYPE_BUY && close_1 >= sma_1" in source
    assert "position_type == POSITION_TYPE_SELL && close_1 <= sma_1" in source
    assert "completed_since_entry >= strategy_max_hold_bars" in source
    assert "QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr_1, strategy_atr_sl_mult)" in source
    assert "QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr_1, strategy_atr_sl_mult)" in source
    assert "req.tp = 0.0;" in source
    assert "if(ask > bid && (ask - bid) / point > strategy_max_spread_points)" in source
    assert source.index("Strategy_EntrySignal") < source.index("if(ask > bid")


def test_framework_corset_and_all_card_inputs_are_present() -> None:
    source = _source()
    for group in (
        "QuantMechanica V5 Framework",
        "Risk",
        "News",
        "Friday Close",
        "Strategy",
    ):
        assert f'input group "{group}"' in source

    for hook in (
        "Strategy_NoTradeFilter",
        "Strategy_EntrySignal",
        "Strategy_ManageOpenPosition",
        "Strategy_ExitSignal",
        "Strategy_NewsFilterHook",
    ):
        assert source.count(hook) >= 2

    for parameter in (
        "strategy_ma_period",
        "strategy_envelope_pct",
        "strategy_atr_period",
        "strategy_atr_sl_mult",
        "strategy_max_hold_bars",
        "strategy_max_spread_points",
    ):
        assert source.count(parameter) >= 2

    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkInit(qm_ea_id" in source
    assert "QM_NewsAllowsTrade2" in source
    assert "RISK_PERCENT                 = 0.0;" in source
    assert "RISK_FIXED                   = 1000.0;" in source
    assert "CopyBuffer(" not in source
    assert "iATR(" not in source
    assert "iMA(" not in source


def test_registry_identity_and_magic_are_deterministic() -> None:
    with (REPO / "framework" / "registry" / "ea_id_registry.csv").open(
        encoding="utf-8", newline=""
    ) as handle:
        ids = [row for row in csv.DictReader(handle) if row["ea_id"] == "21508"]
    assert len(ids) == 1
    assert ids[0]["slug"] == "qs-ma-envelope-eur"
    assert ids[0]["status"] == "active"

    with (REPO / "framework" / "registry" / "magic_numbers.csv").open(
        encoding="utf-8", newline=""
    ) as handle:
        magics = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "21508" and row["status"] == "active"
        ]
    assert magics == [
        {
            "ea_id": "21508",
            "ea_slug": "qs-ma-envelope-eur",
            "symbol_slot": "0",
            "symbol": "EURUSD.DWX",
            "magic": "215080000",
            "reserved_at": "2026-08-24",
            "reserved_by": "Codex burn-window build",
            "status": "active",
        }
    ]


def test_docs_and_governed_backtest_setfile_are_complete() -> None:
    spec = (EA_DIR / "SPEC.md").read_text(encoding="utf-8")
    card = (EA_DIR / "docs" / "strategy_card.md").read_text(encoding="utf-8")
    setfile = SETFILE.read_text(encoding="utf-8")

    for section in range(1, 8):
        assert f"## {section}." in spec
    assert "g0_status: APPROVED" in card
    assert "target_symbols: [EURUSD.DWX]" in card
    assert "RISK_FIXED=1000" in setfile
    assert "RISK_PERCENT=0" in setfile
    assert "strategy_ma_period=20" in setfile
    assert "strategy_envelope_pct=0.015" in setfile
    assert "strategy_atr_period=14" in setfile
    assert "strategy_atr_sl_mult=2.0" in setfile
    assert "strategy_max_hold_bars=20" in setfile
    assert "strategy_max_spread_points=20" in setfile
