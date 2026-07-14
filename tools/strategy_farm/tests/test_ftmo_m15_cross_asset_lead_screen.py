from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_cross_asset_lead_screen as subject


def _frame(start: str, periods: int, *, rising: bool) -> pd.DataFrame:
    utc = pd.date_range(start, periods=periods, freq="15min", tz="UTC")
    local = utc.tz_convert("America/New_York")
    step = np.arange(periods, dtype=float)
    close = 100.0 + (0.2 * step if rising else 0.0)
    frame = pd.DataFrame(
        {
            "utc": utc,
            "local": local,
            "local_date": local.date,
            "year": local.year,
            "weekday": local.weekday,
            "minute": local.hour * 60 + local.minute,
            "open": close,
            "high": close + 0.25,
            "low": close - 0.25,
            "close": close,
            "atr56": np.ones(periods),
        }
    )
    return frame


def test_latest_completed_source_index_rejects_current_unclosed_bar() -> None:
    source = pd.date_range("2023-01-03 13:00", periods=8, freq="15min", tz="UTC")
    source_ns = source.as_unit("ns").astype("int64").to_numpy()
    entry_ns = int(pd.Timestamp("2023-01-03 14:30", tz="UTC").value)
    index = subject.latest_completed_source_index(source_ns, entry_ns)
    assert index is not None
    assert source[index] == pd.Timestamp("2023-01-03 14:15", tz="UTC")


def test_cross_asset_signal_uses_only_completed_source_bars() -> None:
    source = _frame("2023-01-03 12:00", 32, rising=True)
    target = _frame("2023-01-03 14:00", 28, rising=True)
    # The 09:30 New York source bar opens at the target entry and is not known yet.
    future_index = source.index[source["utc"] == pd.Timestamp("2023-01-03 14:30", tz="UTC")][0]
    source.loc[future_index:, "close"] = 1.0
    instrument = m15.Instrument(
        "NDX.DWX", Path("unused"), "America/New_York", 9 * 60 + 30, 16 * 60, 0.0
    )
    trades = subject.cross_asset_trades(
        source,
        target,
        instrument,
        source_lookback_bars=8,
        target_entry_offset_bars=0,
        source_move_atr_threshold=0.5,
        continuation=True,
        target_stop_atr=1.25,
        target_r_multiple=1.5,
        maximum_hold_bars=8,
        end_year=2023,
    )
    assert len(trades) == 1
    assert trades[0].side == 1


def test_preholdout_gate_requires_four_positive_development_years() -> None:
    annual = {str(year): {"net_r": 1.0} for year in range(2018, 2023)}
    metrics = {
        "dev_2018_2022": {"trades": 300, "net_r": 20.0, "profit_factor": 1.25},
        "validation_2023": {"trades": 50, "net_r": 3.0, "profit_factor": 1.15},
        "annual": annual,
    }
    assert subject.preholdout_pass(metrics)
    metrics["annual"]["2019"]["net_r"] = -1.0
    metrics["annual"]["2020"]["net_r"] = -1.0
    assert not subject.preholdout_pass(metrics)
