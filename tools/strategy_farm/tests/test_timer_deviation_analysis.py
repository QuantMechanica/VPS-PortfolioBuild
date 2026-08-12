from __future__ import annotations

import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import timer_deviation_analysis as analysis  # noqa: E402


def _row(entry: int, close: int, net: float, volume: float = 1.0) -> dict:
    return {
        "event": "TRADE_CLOSED",
        "entry_time": entry,
        "time": close,
        "net": net,
        "volume": volume,
    }


def test_pairing_separates_net_only_and_real_exit_shifts() -> None:
    tick = [_row(1, 11, 10), _row(2, 12, 20), _row(3, 13, 30), _row(4, 14, 40)]
    timer = [_row(1, 11, 10), _row(2, 12, 21), _row(3, 14, 30), _row(5, 15, 50)]

    result = analysis.pair_trades(timer, tick)

    assert result["exact"] == 1
    assert result["same_entry_same_close_different_net"] == 1
    assert result["same_entry_shifted_exit"] == 1
    assert result["different_entry"] == 1
    assert result["extra_timer"] == 0
    assert result["missing_timer_tick_only"] == 0
    assert result["exit_shift_seconds"]["max_abs"] == 1


def test_economic_metrics_match_fund_score_definition() -> None:
    rows = [_row(1, 1_600_000_000, 1000), _row(2, 1_600_086_400, -500)]

    result = analysis.economic_metrics(rows)

    assert result["trades"] == 2
    assert result["net"] == 500
    assert result["worst_day_abs_pct"] == 0.5
    assert result["fund_score_denominator"] == 2.0


def test_sixty_calendar_day_window_uses_inclusive_day_59_endpoint() -> None:
    start = 1_600_000_000
    rows = [_row(1, start, 1000)]
    # This row is exactly 60 calendar days after the first close and must not
    # enter the first 60-day window when the starting day is day one.
    rows.append(_row(2, start + 60 * 86_400, 9000))

    result = analysis.economic_metrics(rows)

    assert result["med60_pct"] == 5.0
