from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
SOURCE = EA_DIR / "QM5_11301_tc-m5-macd1-stoch-ema5-open-close.mq5"
SPEC = EA_DIR / "SPEC.md"


def test_source_preserves_approved_mechanics_and_guardrails() -> None:
    text = SOURCE.read_text(encoding="utf-8")
    required = (
        "QM_Stoch_K(_Symbol, strategy_timeframe",
        "QM_MACD_Main(_Symbol, strategy_timeframe",
        "QM_EMA(_Symbol, strategy_timeframe, 5, 1, PRICE_CLOSE)",
        "QM_EMA(_Symbol, strategy_timeframe, 5, 1, PRICE_OPEN)",
        "QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_stop_pips)",
        "QM_TM_OpenPosition(req, out_ticket)",
        "QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY)",
        "qm_news_stale_max_hours      = 336",
    )
    for token in required:
        assert token in text
    assert "OrderSend(" not in text


def test_backtest_sets_are_fixed_risk_and_match_registered_slots() -> None:
    expected = {"EURUSD.DWX": "0", "GBPUSD.DWX": "1"}
    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(setfiles) == 2
    for path in setfiles:
        text = path.read_text(encoding="utf-8")
        symbol = next(key for key in expected if key in path.name)
        assert "RISK_FIXED=1000" in text
        assert "RISK_PERCENT=0" in text
        assert f"qm_magic_slot_offset={expected[symbol]}" in text
        assert "strategy_timeframe=5" in text


def test_spec_has_canonical_sections_and_identity() -> None:
    text = SPEC.read_text(encoding="utf-8")
    assert "**EA ID:** QM5_11301" in text
    for section in range(1, 8):
        assert f"## {section}." in text

