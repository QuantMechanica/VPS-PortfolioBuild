from __future__ import annotations

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_breadth_screen as screen
from tools.strategy_farm.portfolio import ftmo_m15_cross_index_screen as cross


def _panel(moves: tuple[float, float, float]) -> pd.DataFrame:
    cross._ARRAY_CACHE.clear()
    cross._SESSION_DAY_CACHE.clear()
    rows = []
    symbols = cross.SYMBOLS
    for index in range(5):
        row = {
            "utc": pd.Timestamp("2023-01-03 14:30", tz="UTC")
            + pd.Timedelta(minutes=15 * index),
            "local_date": "2023-01-03",
            "year": 2023,
            "weekday": 1,
            "minute": cross.SESSION_START_MINUTE + 15 * index,
        }
        for symbol, move in zip(symbols, moves):
            price = 100.0 + move * min(index, 1)
            row[f"{symbol}:open"] = price
            row[f"{symbol}:high"] = price + 0.1
            row[f"{symbol}:low"] = price - 0.1
            row[f"{symbol}:close"] = price
            row[f"{symbol}:atr56"] = 1.0
        rows.append(row)
    return pd.DataFrame(rows)


def test_breadth_signal_uses_completed_bars_and_builds_package() -> None:
    trades = screen.breadth_packages(
        _panel((0.5, 0.4, 0.3)),
        signal_bars=2,
        min_breadth_atr=0.25,
        min_agreement=3,
        stop_atr=1.0,
        target_r=0.0,
        hold_bars=2,
        continuation=True,
    )
    assert len(trades) == 1
    assert trades[0].side == 1
    assert trades[0].entry_time_utc == "2023-01-03T15:00:00+00:00"


def test_breadth_agreement_gate_rejects_split_market() -> None:
    trades = screen.breadth_packages(
        _panel((0.8, -0.1, -0.1)),
        signal_bars=2,
        min_breadth_atr=0.10,
        min_agreement=2,
        stop_atr=1.0,
        target_r=0.0,
        hold_bars=2,
        continuation=True,
    )
    assert trades == []


def test_score_ignores_holdout() -> None:
    row = {
        "metrics": {
            "dev_2018_2022": {"profit_factor": 1.4},
            "validation_2023": {"profit_factor": 1.2},
            "holdout_2024_2025": {"profit_factor": 99.0},
        }
    }
    assert screen.score(row) == 1.2
