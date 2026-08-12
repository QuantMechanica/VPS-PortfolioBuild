from __future__ import annotations

import datetime as dt

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_mid_session_displacement as screen


def _frame() -> pd.DataFrame:
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    times = pd.date_range("2024-01-02 09:00", periods=20, freq="15min", tz="UTC")
    frame = pd.DataFrame(
        {
            "open": [100.0] * 20,
            "high": [101.0] * 20,
            "low": [99.0] * 20,
            "close": [100.0] * 20,
            "utc": times,
            "local_date": [dt.date(2024, 1, 2)] * 20,
            "year": [2024] * 20,
            "weekday": [1] * 20,
            "minute": [540 + 15 * index for index in range(20)],
            "atr56": [2.0] * 20,
        }
    )
    frame.loc[7, "close"] = 103.0
    frame.loc[8, "open"] = 103.0
    frame.loc[8:, "high"] = 108.0
    frame.loc[8:, "low"] = 95.0
    return frame


def _instrument() -> m15.Instrument:
    return m15.Instrument("TEST", None, "UTC", 540, 840, 0.0)  # type: ignore[arg-type]


def test_completed_window_enters_on_next_bar() -> None:
    trades = screen.displacement_trades(
        _frame(),
        _instrument(),
        window_bars=8,
        mode="continuation",
        displacement_atr=1.0,
        stop_atr=1.0,
        target_r=1.0,
        end_year=2024,
    )
    assert len(trades) == 1
    assert trades[0].side == 1
    assert trades[0].entry_time_utc == "2024-01-02T11:00:00+00:00"


def test_fade_reverses_side_and_grid_matches_predeclaration() -> None:
    trades = screen.displacement_trades(
        _frame(),
        _instrument(),
        window_bars=8,
        mode="fade",
        displacement_atr=1.0,
        stop_atr=1.0,
        target_r=1.0,
        end_year=2024,
    )
    assert len(trades) == 1
    assert trades[0].side == -1
    assert len(list(screen.parameter_grid())) == 72
