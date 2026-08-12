from __future__ import annotations

import datetime as dt

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_gap_impulse_alignment_screen as screen


def _frame(aligned: bool) -> pd.DataFrame:
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    first = pd.date_range("2024-01-02 09:00", periods=8, freq="15min", tz="UTC")
    second = pd.date_range("2024-01-03 09:00", periods=8, freq="15min", tz="UTC")
    times = first.append(second)
    dates = [dt.date(2024, 1, 2)] * 8 + [dt.date(2024, 1, 3)] * 8
    frame = pd.DataFrame(
        {
            "open": [100.0] * 16,
            "high": [100.5] * 16,
            "low": [99.5] * 16,
            "close": [100.0] * 16,
            "utc": times,
            "local_date": dates,
            "year": [2024] * 16,
            "weekday": [1] * 8 + [2] * 8,
            "minute": [540 + 15 * index for index in range(8)] * 2,
            "atr56": [2.0] * 16,
        }
    )
    frame.loc[7, "close"] = 100.0
    frame.loc[8, ["open", "high", "low", "close"]] = [102.0, 102.5, 101.5, 102.2]
    frame.loc[9, "close"] = 103.0 if aligned else 101.0
    frame.loc[10, "open"] = 103.0 if aligned else 101.0
    frame.loc[10:, "high"] = 107.0
    return frame


def _instrument() -> m15.Instrument:
    return m15.Instrument("TEST", None, "UTC", 540, 660, 0.0)  # type: ignore[arg-type]


def test_aligned_gap_and_impulse_enter_on_next_bar() -> None:
    trades = screen.gap_impulse_trades(
        _frame(True),
        _instrument(),
        range_bars=2,
        gap_atr=0.5,
        impulse_atr=0.25,
        stop_atr=1.0,
        target_r=2.0,
    )
    assert len(trades) == 1
    assert trades[0].side == 1
    assert trades[0].entry_time_utc == "2024-01-03T09:30:00+00:00"


def test_conflicting_gap_and_impulse_are_skipped() -> None:
    trades = screen.gap_impulse_trades(
        _frame(False),
        _instrument(),
        range_bars=2,
        gap_atr=0.5,
        impulse_atr=0.25,
        stop_atr=1.0,
        target_r=2.0,
    )
    assert trades == []


def test_parameter_grid_matches_predeclaration() -> None:
    rows = list(screen.parameter_grid())
    assert len(rows) == 243
    assert {row["range_bars"] for row in rows} == {2, 4, 8}
