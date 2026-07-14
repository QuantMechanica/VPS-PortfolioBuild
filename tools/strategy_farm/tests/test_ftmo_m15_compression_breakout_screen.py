from __future__ import annotations

import datetime as dt

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_compression_breakout_screen as screen


def _frame(*, wide: bool = False) -> pd.DataFrame:
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    times = pd.date_range("2024-01-03 09:30", periods=12, freq="15min", tz="UTC")
    high = [100.2] * 12
    low = [99.8] * 12
    if wide:
        high[0] = 102.0
        low[0] = 98.0
    close = [100.0] * 12
    close[4] = 101.0
    open_ = [100.0] * 12
    open_[5] = 101.0
    high[5:] = [108.0] * 7
    return pd.DataFrame(
        {
            "open": open_,
            "high": high,
            "low": low,
            "close": close,
            "utc": times,
            "local_date": [dt.date(2024, 1, 3)] * 12,
            "year": [2024] * 12,
            "weekday": [2] * 12,
            "minute": [570 + 15 * index for index in range(12)],
            "atr56": [2.0] * 12,
        }
    )


def _instrument() -> m15.Instrument:
    return m15.Instrument("TEST", None, "UTC", 570, 750, 0.0)  # type: ignore[arg-type]


def test_confirmed_breakout_enters_next_bar() -> None:
    trades = screen.compression_breakout_trades(
        _frame(),
        _instrument(),
        range_bars=4,
        active_bars=4,
        max_range_atr=0.75,
        breakout_buffer_atr=0.05,
        stop_atr=1.0,
        target_r=2.0,
    )
    assert len(trades) == 1
    assert trades[0].side == 1
    assert trades[0].entry_time_utc == "2024-01-03T10:45:00+00:00"


def test_wide_opening_range_is_rejected() -> None:
    trades = screen.compression_breakout_trades(
        _frame(wide=True),
        _instrument(),
        range_bars=4,
        active_bars=4,
        max_range_atr=0.75,
        breakout_buffer_atr=0.05,
        stop_atr=1.0,
        target_r=2.0,
    )
    assert trades == []


def test_parameter_grid_matches_predeclaration() -> None:
    rows = list(screen.parameter_grid())
    assert len(rows) == 64
    assert {row["range_bars"] for row in rows} == {4, 8}
    assert {row["target_r"] for row in rows} == {2.0, 3.0}
