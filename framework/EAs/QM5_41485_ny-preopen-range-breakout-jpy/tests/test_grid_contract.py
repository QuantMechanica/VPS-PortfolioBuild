from __future__ import annotations

import datetime as dt
import re
from pathlib import Path

import pytest

from tools.strategy_farm.session_tools import velocity_family_f1_sweep_0921 as simulator


EA_ROOT = Path(__file__).resolve().parents[1]
SOURCE = EA_ROOT / "QM5_41485_ny-preopen-range-breakout-jpy.mq5"
SETS = EA_ROOT / "sets"


def _server_stamp(day: dt.date, hour: int, minute: int) -> int:
    value = dt.datetime(day.year, day.month, day.day, hour, minute, tzinfo=dt.timezone.utc)
    return int(value.timestamp())


def _synthetic_halves(anchor: int) -> dict[int, list[float]]:
    """Sixteen exact :30-aligned grid bars, each represented by two M30 halves."""
    halves: dict[int, list[float]] = {}
    starts = sorted(anchor - 3600 * k for k in range(1, 17))
    for index, start in enumerate(starts):
        base = 100.0 + index * 0.1
        halves[start] = [base, base + 0.08, base - 0.07, base + 0.02]
        halves[start + 1800] = [base + 0.02, base + 0.12, base - 0.05, base + 0.04]
    return halves


def _pair_like_ea(halves: dict[int, list[float]], grid_end: int) -> list[float]:
    first = halves[grid_end - 3600]
    second = halves[grid_end - 1800]
    return [first[0], max(first[1], second[1]), min(first[2], second[2]), second[3]]


def _atr_like_ea(newest_first: list[list[float]], period: int = 14) -> float:
    total = 0.0
    for index in range(period):
        _, high, low, _ = newest_first[index]
        previous_close = newest_first[index + 1][3]
        total += max(high - low, abs(high - previous_close), abs(low - previous_close))
    return total / period


@pytest.mark.parametrize(
    "day",
    [
        dt.date(2024, 3, 8),   # Friday immediately before the US spring transition.
        dt.date(2024, 3, 11),  # First trading day in the US DST transition week.
        dt.date(2024, 11, 4),  # First trading day after the US autumn transition.
    ],
)
def test_exact_m30_pairing_matches_reference_simulator(day: dt.date) -> None:
    anchor, flat = simulator.anchor_times(simulator.ANCHORS["C"], day)
    assert anchor == _server_stamp(day, 15, 30)
    assert flat == _server_stamp(day, 23, 0)

    halves = _synthetic_halves(anchor)
    sparse_m1 = [(stamp, *ohlc) for stamp, ohlc in sorted(halves.items())]
    reference_grid = simulator.aggregate(sparse_m1, period=3600, offset=1800)
    paired = [_pair_like_ea(halves, anchor - i * 3600) for i in range(15)]

    for arm_bars in (2, 3):
        reference_range = [reference_grid[anchor - 3600 * k] for k in range(1, arm_bars + 1)]
        assert max(bar[1] for bar in reference_range) == max(bar[1] for bar in paired[:arm_bars])
        assert min(bar[2] for bar in reference_range) == min(bar[2] for bar in paired[:arm_bars])

    _, reference_atr = simulator.sma_atr(reference_grid, n=14)
    assert _atr_like_ea(paired) == pytest.approx(reference_atr[anchor - 3600], abs=1e-12)


def test_missing_half_rejects_required_grid_bar() -> None:
    anchor = _server_stamp(dt.date(2024, 3, 11), 15, 30)
    halves = _synthetic_halves(anchor)
    del halves[anchor - 1800]
    with pytest.raises(KeyError):
        _pair_like_ea(halves, anchor)


def test_source_locks_runtime_oco_news_and_current_sl_contracts() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    assert "QM_IsNewBar(_Symbol, PERIOD_M30)" in source
    assert "iBarShift(_Symbol, PERIOD_M30, first_start, true)" in source
    assert "const bool buy_ok = QM_TM_OpenPosition(buy_req, buy_ticket);" in source
    assert "const bool sell_ok = QM_TM_OpenPosition(sell_req, sell_ticket);" in source
    assert "if(buy_ok != sell_ok)" in source
    assert "TRADE_TRANSACTION_DEAL_ADD" in source
    assert "const double current_sl = PositionGetDouble(POSITION_SL);" in source
    assert "MathAbs(open_price - current_sl)" in source
    assert "strategy_news_retry_window_minutes != 60" in source
    assert "qm_news_stale_max_hours > 336" in source
    assert "QM_BrokerToUTC" not in source
    assert not re.search(r"(?:USDJPY|EURUSD)(?:\.DWX)?", source)

    management = source.index("Strategy_ManageOpenPosition();", source.index("void OnTick()"))
    news_gate = source.index("QM_NewsAllowsTrade2", source.index("void OnTick()"))
    assert management < news_gate


def test_three_setfiles_are_fixed_backtest_arms() -> None:
    setfiles = sorted(SETS.glob("*.set"))
    assert len(setfiles) == 3
    observed: set[tuple[str, str, str]] = set()
    for path in setfiles:
        text = path.read_text(encoding="utf-8")
        symbol = re.search(r"^; symbol:\s+(\S+)$", text, re.MULTILINE).group(1)
        slot = re.search(r"^qm_magic_slot_offset=(\d+)$", text, re.MULTILINE).group(1)
        bars = re.search(r"^strategy_range_bars=(\d+)$", text, re.MULTILINE).group(1)
        observed.add((symbol, slot, bars))
        assert "; timeframe:    M30" in text
        assert "; environment:  backtest" in text
        assert "RISK_FIXED=1000" in text
        assert "RISK_PERCENT=0" in text
        assert "qm_news_temporal=3" in text
        assert "qm_news_compliance=1" in text
        assert "qm_news_stale_max_hours=336" in text

    assert observed == {
        ("USDJPY.DWX", "0", "2"),
        ("USDJPY.DWX", "1", "3"),
        ("EURUSD.DWX", "2", "3"),
    }
