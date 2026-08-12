from __future__ import annotations

import datetime as dt

import pandas as pd
import pytest

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_us_index_relative_strength as screen


def _frame(second_close: float) -> pd.DataFrame:
    first = pd.date_range("2024-01-02 09:30", periods=8, freq="15min", tz="UTC")
    second = pd.date_range("2024-01-03 09:30", periods=8, freq="15min", tz="UTC")
    times = first.append(second)
    frame = pd.DataFrame(
        {
            "open": [100.0] * 16,
            "high": [101.0] * 16,
            "low": [99.0] * 16,
            "close": [100.0] * 16,
            "utc": times,
            "local_date": [dt.date(2024, 1, 2)] * 8 + [dt.date(2024, 1, 3)] * 8,
            "year": [2024] * 16,
            "weekday": [1] * 8 + [2] * 8,
            "minute": [570 + 15 * index for index in range(8)] * 2,
            "atr56": [2.0] * 16,
        }
    )
    frame.loc[9, "close"] = second_close
    frame.loc[10, "open"] = second_close
    frame.loc[10:, "high"] = 108.0
    frame.loc[10:, "low"] = 95.0
    return frame


def _inputs():
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    frames = {
        "NDX.DWX": _frame(104.0),
        "SP500.DWX": _frame(101.0),
        "WS30.DWX": _frame(101.0),
    }
    instruments = {
        symbol: m15.Instrument(symbol, None, "UTC", 570, 690, cost)  # type: ignore[arg-type]
        for symbol, cost in (("NDX.DWX", 0.0), ("SP500.DWX", 0.0), ("WS30.DWX", 0.0))
    }
    return frames, instruments


def test_relative_value_and_next_bar_entry() -> None:
    frames, instruments = _inputs()
    trades = screen.relative_strength_trades(
        frames,
        instruments,
        target_symbol="NDX.DWX",
        window_bars=2,
        mode="continuation",
        relative_atr=1.0,
        stop_atr=1.0,
        target_r=1.0,
        end_year=2024,
    )
    assert len(trades) == 1
    assert trades[0].side == 1
    assert trades[0].entry_time_utc == "2024-01-03T10:00:00+00:00"


def test_convergence_reverses_relative_side_and_grid_is_frozen() -> None:
    frames, instruments = _inputs()
    trades = screen.relative_strength_trades(
        frames,
        instruments,
        target_symbol="NDX.DWX",
        window_bars=2,
        mode="convergence",
        relative_atr=1.0,
        stop_atr=1.0,
        target_r=1.0,
        end_year=2024,
    )
    assert len(trades) == 1
    assert trades[0].side == -1
    assert len(list(screen.parameter_grid())) == 216


def test_relative_value_uses_mean_of_two_peers() -> None:
    row = {"NDX.DWX": 2.0, "SP500.DWX": 0.5, "WS30.DWX": 1.5}
    assert screen.relative_value(row, "NDX.DWX") == pytest.approx(1.0)
