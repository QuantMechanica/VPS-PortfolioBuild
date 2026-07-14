from __future__ import annotations

from datetime import date
from pathlib import Path

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_tod_signal_screen as screen


def _frame(*, collision: bool = False) -> pd.DataFrame:
    utc = pd.date_range("2024-01-02 13:00", periods=80, freq="15min", tz="UTC")
    close = [100.0 + index * 0.1 for index in range(80)]
    frame = pd.DataFrame(
        {
            "open": close,
            "high": [value + 0.05 for value in close],
            "low": [value - 0.05 for value in close],
            "close": close,
            "atr56": [1.0] * 80,
            "utc": utc,
            "local_date": [date(2024, 1, 2)] * 32 + [date(2024, 1, 3)] * 32 + [date(2024, 1, 4)] * 16,
            "year": [2024] * 80,
            "weekday": [1] * 32 + [2] * 32 + [3] * 16,
            "minute": list(range(9 * 60, 17 * 60, 15)) * 2 + list(range(9 * 60, 13 * 60, 15)),
        }
    )
    if collision:
        frame.loc[32, "open"] = 104.0
        frame.loc[32, "high"] = 106.5
        frame.loc[32, "low"] = 102.5
        frame.loc[32, "close"] = 104.0
    return frame


def _instrument() -> m15.Instrument:
    return m15.Instrument("TEST", Path("unused.csv"), "UTC", 9 * 60, 17 * 60, 0.0)


def test_signal_uses_completed_bars_and_sets_direction() -> None:
    frame = _frame()
    continuation = screen.time_of_day_signal_trades(
        frame,
        _instrument(),
        entry_offset_bars=0,
        signal_lookback_bars=4,
        signal_atr=0.1,
        continuation=True,
        stop_atr=1.0,
        target_r=0.0,
        hold_bars=4,
    )
    fade = screen.time_of_day_signal_trades(
        frame,
        _instrument(),
        entry_offset_bars=0,
        signal_lookback_bars=4,
        signal_atr=0.1,
        continuation=False,
        stop_atr=1.0,
        target_r=0.0,
        hold_bars=4,
    )
    assert continuation and fade
    assert continuation[0].side == 1
    assert fade[0].side == -1


def test_dual_touch_is_charged_as_stop() -> None:
    trades = screen.time_of_day_signal_trades(
        _frame(collision=True),
        _instrument(),
        entry_offset_bars=0,
        signal_lookback_bars=4,
        signal_atr=0.1,
        continuation=True,
        stop_atr=1.0,
        target_r=2.0,
        hold_bars=4,
    )
    assert trades
    assert trades[0].r_multiple == -1.0
    assert trades[0].exit_reason.endswith("stop_pessimistic")


def test_preholdout_gate_requires_four_positive_dev_years() -> None:
    metrics = {
        "dev_2018_2022": {"trades": 200, "net_r": 10.0, "profit_factor": 1.2},
        "validation_2023": {"trades": 30, "net_r": 2.0, "profit_factor": 1.1},
        "annual": {str(year): {"net_r": 1.0} for year in range(2018, 2023)},
    }
    assert screen.preholdout_pass(metrics)
    metrics["annual"]["2018"]["net_r"] = -1.0
    metrics["annual"]["2019"]["net_r"] = -1.0
    assert not screen.preholdout_pass(metrics)
