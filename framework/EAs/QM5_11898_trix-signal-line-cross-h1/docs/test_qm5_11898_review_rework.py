from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
SOURCE = EA_DIR / "QM5_11898_trix-signal-line-cross-h1.mq5"
SPEC = EA_DIR / "SPEC.md"


def test_timeout_counts_observed_h1_bars_not_wall_clock_seconds() -> None:
    text = SOURCE.read_text(encoding="utf-8")
    assert "iBarShift(_Symbol, PERIOD_H1, open_time, false)" in text
    assert "Strategy_PositionAgeH1Bars(open_time) >= 96" in text
    assert "96 * 3600" not in text
    assert "TimeCurrent() - open_time" not in text


def test_source_preserves_card_mechanics_and_framework_guardrails() -> None:
    text = SOURCE.read_text(encoding="utf-8")
    required = (
        "strategy_trix_ema_period = 14",
        "strategy_trix_signal_period = 9",
        "trix1 > sig1 && trix2 <= sig2",
        "trix1 < sig1 && trix2 >= sig2",
        "bullish_cross && trix1 <= 0.0",
        "bearish_cross && trix1 >= 0.0",
        "QM_StopATR(_Symbol, QM_BUY",
        "QM_TakeRR(_Symbol, QM_BUY",
        "strategy_target_rr = 2.0",
        "QM_TM_OpenPosition(req, out_ticket)",
        "qm_news_stale_max_hours      = 336",
    )
    for token in required:
        assert token in text
    assert "OrderSend(" not in text


def test_backtest_sets_are_fixed_risk_and_match_registered_slots() -> None:
    expected = {
        "EURUSD.DWX": "0",
        "GBPUSD.DWX": "1",
        "USDJPY.DWX": "2",
        "USDCAD.DWX": "3",
        "USDCHF.DWX": "4",
        "AUDUSD.DWX": "5",
        "NZDUSD.DWX": "6",
        "EURJPY.DWX": "7",
        "GBPJPY.DWX": "8",
        "AUDJPY.DWX": "9",
    }
    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(setfiles) == len(expected)
    for path in setfiles:
        text = path.read_text(encoding="utf-8")
        symbol = next(key for key in expected if key in path.name)
        assert "RISK_FIXED=1000" in text
        assert "RISK_PERCENT=0" in text
        assert f"qm_magic_slot_offset={expected[symbol]}" in text
        assert "strategy_timeframe=H1" in text


def test_spec_records_bar_timeout_and_identity() -> None:
    text = SPEC.read_text(encoding="utf-8")
    assert "**EA ID:** QM5_11898" in text
    assert "96 observed `PERIOD_H1` bars" in text
    assert "not 96 wall-clock hours" in text
    for section in range(1, 8):
        assert f"## {section}." in text
