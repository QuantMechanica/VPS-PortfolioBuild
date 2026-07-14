from __future__ import annotations

import datetime as dt

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_impulse_pullback_screen as screen


def _frame(*, holds: bool = True) -> pd.DataFrame:
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    times = pd.date_range("2024-01-03 09:30", periods=12, freq="15min", tz="UTC")
    open_ = [100.0] * 12
    close = [100.5, 102.0] + [100.0] * 10
    high = [100.8, 102.2] + [102.0] * 10
    low = [99.8, 100.4] + [100.8] * 10
    close[2] = 101.5 if holds else 99.5
    low[2] = 100.9
    open_[3] = 101.5
    high[3:] = [106.0] * 9
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


def test_pullback_hold_enters_next_bar() -> None:
    trades = screen.impulse_pullback_trades(
        _frame(),
        _instrument(),
        range_bars=2,
        impulse_atr=0.5,
        retracement_fraction=0.5,
        pullback_bars=4,
        stop_atr=1.0,
        target_r=2.0,
    )
    assert len(trades) == 1
    assert trades[0].side == 1
    assert trades[0].entry_time_utc == "2024-01-03T10:15:00+00:00"


def test_pullback_that_loses_session_open_is_rejected() -> None:
    trades = screen.impulse_pullback_trades(
        _frame(holds=False),
        _instrument(),
        range_bars=2,
        impulse_atr=0.5,
        retracement_fraction=0.5,
        pullback_bars=4,
        stop_atr=1.0,
        target_r=2.0,
    )
    assert trades == []


def test_parameter_grid_matches_predeclaration() -> None:
    assert len(list(screen.parameter_grid())) == 64
