from __future__ import annotations

import datetime as dt

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_vwap_reversion_screen as screen


def _frame(direction: str) -> pd.DataFrame:
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    times = pd.date_range("2024-01-02 09:00", periods=12, freq="15min", tz="UTC")
    frame = pd.DataFrame(
        {
            "open": [100.0] * 12,
            "high": [100.5] * 12,
            "low": [99.5] * 12,
            "close": [100.0] * 12,
            "tickvol": [100.0] * 12,
            "utc": times,
            "local_date": [dt.date(2024, 1, 2)] * 12,
            "year": [2024] * 12,
            "weekday": [1] * 12,
            "minute": [540 + 15 * index for index in range(12)],
            "atr56": [1.0] * 12,
        }
    )
    if direction == "high":
        frame.loc[3, ["open", "high", "low", "close"]] = [101.0, 102.0, 100.8, 101.5]
        frame.loc[4, "open"] = 101.4
        frame.loc[4:, "low"] = 99.0
    elif direction == "low":
        frame.loc[3, ["open", "high", "low", "close"]] = [99.0, 99.2, 98.0, 98.5]
        frame.loc[4, "open"] = 98.6
        frame.loc[4:, "high"] = 101.0
    return frame


def _instrument() -> m15.Instrument:
    return m15.Instrument("TEST", None, "UTC", 540, 720, 0.0)  # type: ignore[arg-type]


def test_positive_deviation_enters_short_on_next_bar() -> None:
    trades = screen.vwap_reversion_trades(
        _frame("high"),
        _instrument(),
        warmup_bars=4,
        active_bars=4,
        deviation_atr=0.5,
        stop_to_target_ratio=1.0,
    )
    assert len(trades) == 1
    assert trades[0].side == -1
    assert trades[0].entry_time_utc == "2024-01-02T10:00:00+00:00"


def test_negative_deviation_enters_long_on_next_bar() -> None:
    trades = screen.vwap_reversion_trades(
        _frame("low"),
        _instrument(),
        warmup_bars=4,
        active_bars=4,
        deviation_atr=0.5,
        stop_to_target_ratio=1.0,
    )
    assert len(trades) == 1
    assert trades[0].side == 1


def test_next_open_beyond_frozen_target_is_skipped() -> None:
    frame = _frame("high")
    frame.loc[4, "open"] = 99.0
    trades = screen.vwap_reversion_trades(
        frame,
        _instrument(),
        warmup_bars=4,
        active_bars=1,
        deviation_atr=0.5,
        stop_to_target_ratio=1.0,
    )
    assert trades == []


def test_parameter_grid_matches_predeclaration() -> None:
    rows = list(screen.parameter_grid())
    assert len(rows) == 81
    assert {row["warmup_bars"] for row in rows} == {4, 8, 12}
