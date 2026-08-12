import datetime as dt

import numpy as np
import pandas as pd

from tools.strategy_farm.portfolio.ftmo_causal_launch_model_screen import (
    FrozenRidge,
    feature_row,
    fit_ridge,
    model_score,
    score_threshold,
)
from tools.strategy_farm.portfolio.ftmo_market_launch_gate_screen import CORE_SYMBOLS


def _bars() -> dict[str, pd.DataFrame]:
    index = pd.date_range("2023-01-01T00:00:00Z", periods=2200, freq="15min", tz="UTC")
    closes = np.linspace(100.0, 120.0, len(index))
    frame = pd.DataFrame(
        {"high": closes + 0.5, "low": closes - 0.5, "close": closes},
        index=index,
    )
    return {symbol: frame.copy() for symbol in CORE_SYMBOLS}


def test_feature_row_ignores_start_day_and_future_data() -> None:
    start_day = dt.date(2023, 1, 22)
    daily_pnl = {
        start_day - dt.timedelta(days=offset): float(offset)
        for offset in range(1, 121)
    }
    bars = _bars()
    before = feature_row(start_day, daily_pnl, bars)

    daily_pnl[start_day] = 1_000_000.0
    daily_pnl[start_day + dt.timedelta(days=1)] = -1_000_000.0
    cutoff = pd.Timestamp("2023-01-21T23:00:00Z")
    for symbol in bars:
        bars[symbol].loc[cutoff:, ["high", "low", "close"]] = [1000.0, 0.0, 1.0]
    after = feature_row(start_day, daily_pnl, bars)

    assert before is not None
    assert after == before


def test_frozen_ridge_json_round_trip_preserves_scores() -> None:
    rows = [
        {"a": 0.0, "b": 1.0},
        {"a": 1.0, "b": 0.0},
        {"a": 2.0, "b": 1.0},
        {"a": 3.0, "b": 0.0},
    ]
    model = fit_ridge(rows, [0.0, 0.0, 1.0, 1.0], penalty=1.0)
    restored = FrozenRidge.from_json(model.to_json())

    assert restored.score(rows[2]) == model.score(rows[2])


def test_model_score_modes_and_top_fraction_threshold() -> None:
    rows = [{"x": float(value)} for value in range(10)]
    threshold_model = fit_ridge(rows, [float(value >= 5) for value in range(10)], 1.0)
    adverse_model = fit_ridge(rows, [float(value >= 7) for value in range(10)], 1.0)
    joint_model = fit_ridge(rows, [float(value >= 7) for value in range(10)], 1.0)
    models = {
        "threshold": threshold_model,
        "adverse": adverse_model,
        "joint": joint_model,
    }

    minimum = model_score(rows[8], models, "minimum")
    mean = model_score(rows[8], models, "mean")
    assert minimum <= mean
    scores = [model_score(row, models, "joint") for row in rows]
    cutoff = score_threshold(scores, 0.2)
    assert sum(score >= cutoff for score in scores) == 2
