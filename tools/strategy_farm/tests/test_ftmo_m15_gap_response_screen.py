from __future__ import annotations

import datetime as dt

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_gap_response_screen as screen


def _frame(response: float) -> pd.DataFrame:
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    first = pd.date_range("2024-01-02 09:00", periods=8, freq="15min", tz="UTC")
    second = pd.date_range("2024-01-03 09:00", periods=8, freq="15min", tz="UTC")
    times = first.append(second)
    frame = pd.DataFrame(
        {
            "open": [100.0] * 16,
            "high": [100.5] * 16,
            "low": [99.5] * 16,
            "close": [100.0] * 16,
            "utc": times,
            "local_date": [dt.date(2024, 1, 2)] * 8 + [dt.date(2024, 1, 3)] * 8,
            "year": [2024] * 16,
            "weekday": [1] * 8 + [2] * 8,
            "minute": [540 + 15 * index for index in range(8)] * 2,
            "atr56": [2.0] * 16,
        }
    )
    frame.loc[8, ["open", "high", "low", "close"]] = [102.0, 103.5, 100.5, response]
    frame.loc[9, "open"] = response
    frame.loc[9:, "low"] = 95.0
    frame.loc[9:, "high"] = 108.0
    return frame


def _instrument() -> m15.Instrument:
    return m15.Instrument("TEST", None, "UTC", 540, 660, 0.0)  # type: ignore[arg-type]


def test_gap_fade_uses_prior_atr_and_enters_next_bar() -> None:
    trades = screen.gap_response_trades(
        _frame(101.0),
        _instrument(),
        mode="fade",
        gap_atr=0.5,
        response_atr=0.25,
        stop_atr=1.0,
        target_r=1.0,
        end_year=2024,
    )
    assert len(trades) == 1
    assert trades[0].side == -1
    assert trades[0].entry_time_utc == "2024-01-03T09:15:00+00:00"


def test_gap_continuation_requires_first_bar_alignment() -> None:
    aligned = screen.gap_response_trades(
        _frame(103.0),
        _instrument(),
        mode="continuation",
        gap_atr=0.5,
        response_atr=0.25,
        stop_atr=1.0,
        target_r=1.0,
        end_year=2024,
    )
    conflicting = screen.gap_response_trades(
        _frame(101.0),
        _instrument(),
        mode="continuation",
        gap_atr=0.5,
        response_atr=0.25,
        stop_atr=1.0,
        target_r=1.0,
        end_year=2024,
    )
    assert len(aligned) == 1
    assert aligned[0].side == 1
    assert conflicting == []


def test_parameter_grid_matches_predeclaration() -> None:
    rows = list(screen.parameter_grid())
    assert len(rows) == 162
    assert {row["mode"] for row in rows} == {"fade", "continuation"}
