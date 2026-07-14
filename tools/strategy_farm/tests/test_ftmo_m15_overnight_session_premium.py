from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_overnight_session_premium as subject


def _two_session_frame(start_day: str = "2023-01-03") -> pd.DataFrame:
    start = pd.Timestamp(start_day, tz="UTC")
    utc = pd.date_range(start + pd.Timedelta(hours=14), start + pd.Timedelta(days=1, hours=21), freq="15min", tz="UTC")
    local = utc.tz_convert("America/New_York")
    open_values = np.full(len(utc), 100.0)
    next_open_time = start + pd.Timedelta(days=1, hours=14, minutes=30)
    next_open = np.where(utc == next_open_time)[0][0]
    open_values[next_open] = 102.0
    frame = pd.DataFrame(
        {
            "utc": utc,
            "local": local,
            "local_date": local.date,
            "year": local.year,
            "weekday": local.weekday,
            "minute": local.hour * 60 + local.minute,
            "open": open_values,
            "high": np.full(len(utc), 100.1),
            "low": np.full(len(utc), 99.9),
            "close": np.full(len(utc), 100.0),
            "atr56": np.ones(len(utc)),
        }
    )
    # Extremes in the scheduled exit bar occur after its open and must not affect the trade.
    frame.loc[next_open, "high"] = 200.0
    frame.loc[next_open, "low"] = 0.0
    return frame


def test_scheduled_exit_occurs_at_next_session_open_before_bar_extremes() -> None:
    frame = _two_session_frame()
    instrument = m15.Instrument(
        "NDX.DWX", Path("unused"), "America/New_York", 9 * 60 + 30, 16 * 60, 0.0
    )
    spec = subject.OvernightInstrument(instrument, 0.0, 0.0, 2)
    trades = subject.overnight_trades(
        frame,
        spec,
        entry_bars_before_close=1,
        exit_bars_after_next_open=0,
        stop_atr=2.0,
        target_r=0.0,
        direction=1,
        entry_weekday=-1,
        end_year=2023,
    )
    assert len(trades) == 1
    assert trades[0].r_multiple == 1.0
    assert trades[0].exit_reason == "overnight:next_open"


def test_wednesday_negative_swap_is_tripled_and_positive_swap_not_credited() -> None:
    frame = _two_session_frame("2023-01-04")
    instrument = m15.Instrument(
        "NDX.DWX", Path("unused"), "America/New_York", 9 * 60 + 30, 16 * 60, 0.0
    )
    negative = subject.OvernightInstrument(instrument, -100.0, 100.0, 2)
    long_trade = subject.overnight_trades(
        frame,
        negative,
        entry_bars_before_close=1,
        exit_bars_after_next_open=0,
        stop_atr=2.0,
        target_r=0.0,
        direction=1,
        entry_weekday=2,
        end_year=2023,
    )[0]
    short_trade = subject.overnight_trades(
        frame,
        negative,
        entry_bars_before_close=1,
        exit_bars_after_next_open=0,
        stop_atr=2.0,
        target_r=0.0,
        direction=-1,
        entry_weekday=2,
        end_year=2023,
    )[0]
    assert long_trade.r_multiple == -0.5
    assert short_trade.r_multiple == -1.0
