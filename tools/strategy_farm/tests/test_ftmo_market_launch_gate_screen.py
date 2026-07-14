import datetime as dt

import numpy as np
import pandas as pd

from tools.strategy_farm.portfolio.ftmo_market_launch_gate_screen import market_features


def test_market_features_use_only_completed_prelaunch_bars() -> None:
    index = pd.date_range("2023-01-01T00:00:00Z", periods=2100, freq="15min", tz="UTC")
    closes = np.linspace(100.0, 120.0, len(index))
    frame = pd.DataFrame(
        {"high": closes + 0.5, "low": closes - 0.5, "close": closes},
        index=index,
    )
    bars = {symbol: frame.copy() for symbol in ("NDX.DWX", "XAUUSD.DWX", "USDJPY.DWX", "XTIUSD.DWX")}
    start_day = dt.date(2023, 1, 22)

    before = market_features(start_day, bars)
    start = pd.Timestamp("2023-01-21T23:00:00Z")
    for symbol in bars:
        bars[symbol].loc[start:, ["high", "low", "close"]] = [1000.0, 0.0, 1.0]
    after = market_features(start_day, bars)

    assert before is not None
    assert after == before
