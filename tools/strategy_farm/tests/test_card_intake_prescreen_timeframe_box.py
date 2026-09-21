"""Timeframe box of the card-intake prescreen (M5..M30, H1..H24, D1) — box amendment 2026-09-21 adds M30."""
from tools.strategy_farm import card_intake_prescreen as cip


def test_timeframe_box_accepts_m30_after_amendment():
    assert cip._timeframe_allowed("M30")
    assert cip._timeframe_allowed("M5") and cip._timeframe_allowed("M15")
    assert cip._timeframe_allowed("H1") and cip._timeframe_allowed("H24") and cip._timeframe_allowed("D1")


def test_timeframe_box_still_rejects_outside():
    assert not cip._timeframe_allowed("M1")
    assert not cip._timeframe_allowed("M45")
    assert not cip._timeframe_allowed("W1")
    assert not cip._timeframe_allowed(None)
