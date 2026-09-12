from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
SOURCE = EA_DIR / "QM5_10001_ff-static-fib-open.mq5"
CARD = EA_DIR / "docs" / "strategy_card.md"


def test_source_preserves_approved_card_entry_and_risk_contract() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    card = CARD.read_text(encoding="utf-8")
    assert "g0_status: APPROVED" in card
    assert "target_symbols: [GBPUSD.DWX, EURUSD.DWX, USDJPY.DWX, GBPJPY.DWX]" in card
    assert "strategy_entry_offset_pips      = 34" in source
    assert "strategy_tp1_offset_pips        = 89" in source
    assert "strategy_runner_offset_pips     = 144" in source
    assert "strategy_min_entry_atr_mult     = 0.4" in source
    assert "strategy_max_entry_atr_mult     = 2.5" in source
    assert "RISK_FIXED                 = 1000.0" in source
    assert "RISK_PERCENT               = 0.0" in source
    assert "qm_news_stale_max_hours      = 336" in source


def test_unapproved_spread_gate_is_absent_and_single_position_is_enforced() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    assert "strategy_max_spread_points" not in source
    assert "bool HasOurOpenPosition()" in source
    entry = source[source.index("bool Strategy_EntrySignal"):source.index("void Strategy_ManageOpenPosition")]
    assert "HasOurOpenPosition()" in entry
    assert "OPEN_POSITION_EXISTS" in entry


def test_zero_trade_diagnostics_are_default_off_and_session_bounded() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    assert "strategy_debug                  = false" in source
    assert source.index('Strategy_DebugDecision("ENTRY_ATTEMPT"') > source.index(
        "now_dt.hour != strategy_tokyo_open_hour_broker"
    )
    for reason in (
        "PRICE_DATA_UNAVAILABLE",
        "INDICATOR_DATA_UNAVAILABLE",
        "ATR_GEOMETRY",
        "BIAS_FILTER",
    ):
        assert reason in source
