from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
SOURCE = EA_DIR / "QM5_11363_robo-vol-channel-breakout.mq5"
SPEC = EA_DIR / "SPEC.md"


def test_source_preserves_card_mechanics_and_framework_guardrails() -> None:
    text = SOURCE.read_text(encoding="utf-8")
    for token in (
        "bar1.close > (ema5 + atr30)",
        "bar1.close > (ema4 + atr14)",
        "bar1.close < (ema5 - atr30)",
        "bar1.close < (ema4 - atr14)",
        "tp_price = entry + strategy_tp_multiplier * atr14",
        "tp_price = entry - strategy_tp_multiplier * atr14",
        "QM_TM_OpenPosition(req, out_ticket)",
        "qm_news_stale_max_hours      = 336",
    ):
        assert token in text
    assert "OrderSend(" not in text


def test_backtest_sets_are_fixed_risk_and_slots_are_unique() -> None:
    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(setfiles) == 3
    slots = set()
    for path in setfiles:
        text = path.read_text(encoding="utf-8")
        assert "RISK_FIXED=1000" in text
        assert "RISK_PERCENT=0" in text
        slots.add(next(line.split("=", 1)[1] for line in text.splitlines() if line.startswith("qm_magic_slot_offset=")))
    assert slots == {"0", "1", "2"}


def test_spec_has_canonical_sections_and_identity() -> None:
    text = SPEC.read_text(encoding="utf-8")
    assert "**EA ID:** QM5_11363" in text
    for section in range(1, 8):
        assert f"## {section}." in text
