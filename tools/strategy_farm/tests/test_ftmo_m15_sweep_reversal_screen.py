from __future__ import annotations

import datetime as dt

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_sweep_reversal_screen as screen


def _frame(signal: str) -> pd.DataFrame:
    times = pd.date_range("2024-01-02 09:00", periods=10, freq="15min", tz="UTC")
    frame = pd.DataFrame(
        {
            "open": [100.0] * 10,
            "high": [101.0] * 10,
            "low": [99.0] * 10,
            "close": [100.0] * 10,
            "utc": times,
            "local_date": [dt.date(2024, 1, 2)] * 10,
            "year": [2024] * 10,
            "weekday": [1] * 10,
            "minute": [540 + 15 * index for index in range(10)],
            "atr56": [2.0] * 10,
        }
    )
    if signal in {"high", "both"}:
        frame.loc[4, ["high", "close"]] = [102.0, 100.5]
    if signal in {"low", "both"}:
        frame.loc[4, ["low", "close"]] = [98.0, 99.5]
    if signal == "high":
        frame.loc[5:, "low"] = 98.0
    elif signal == "low":
        frame.loc[5:, "high"] = 102.0
    return frame


def _instrument() -> m15.Instrument:
    return m15.Instrument("TEST", None, "UTC", 540, 690, 0.0)  # type: ignore[arg-type]


def test_high_sweep_enters_short_on_next_bar() -> None:
    trades = screen.sweep_reversal_trades(
        _frame("high"),
        _instrument(),
        range_bars=4,
        active_bars=4,
        sweep_buffer_atr=0.0,
        stop_buffer_atr=0.05,
        max_range_atr=3.0,
        target_r=1.5,
    )
    assert len(trades) == 1
    assert trades[0].side == -1
    assert trades[0].entry_time_utc == "2024-01-02T10:15:00+00:00"


def test_low_sweep_enters_long_on_next_bar() -> None:
    trades = screen.sweep_reversal_trades(
        _frame("low"),
        _instrument(),
        range_bars=4,
        active_bars=4,
        sweep_buffer_atr=0.0,
        stop_buffer_atr=0.05,
        max_range_atr=3.0,
        target_r=1.5,
    )
    assert len(trades) == 1
    assert trades[0].side == 1


def test_dual_sweep_is_skipped_before_entry() -> None:
    trades = screen.sweep_reversal_trades(
        _frame("both"),
        _instrument(),
        range_bars=4,
        active_bars=1,
        sweep_buffer_atr=0.0,
        stop_buffer_atr=0.05,
        max_range_atr=3.0,
        target_r=1.5,
    )
    assert trades == []


def test_parameter_grid_matches_predeclaration() -> None:
    rows = list(screen.parameter_grid())
    assert len(rows) == 144
    assert {row["range_bars"] for row in rows} == {4, 8}
    assert {row["target_r"] for row in rows} == {1.5, 2.0, 3.0}
