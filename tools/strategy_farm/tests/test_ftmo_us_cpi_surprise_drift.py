from __future__ import annotations

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_us_cpi_surprise_drift as subject


def test_calendar_timestamp_transform_matches_validated_samples() -> None:
    assert subject.correct_local_calendar_timestamp("2015-01-15 20:30") == pd.Timestamp(
        "2015-01-16 13:30Z"
    )
    assert subject.correct_local_calendar_timestamp("2025-01-14 20:30") == pd.Timestamp(
        "2025-01-15 13:30Z"
    )


def test_grid_matches_predeclaration() -> None:
    rows = subject.parameter_grid()
    assert len(rows) == 108
    assert {row["blackout_minutes"] for row in rows} == {120, 180}
    assert {row["minimum_surprise"] for row in rows} == {0.05, 0.15}


def test_surprise_direction_is_fixed_usd_mapping() -> None:
    assert subject.surprise_sides(0.1) == {
        "EURUSD.DWX": -1,
        "GBPUSD.DWX": -1,
        "USDJPY.DWX": 1,
    }
    assert subject.surprise_sides(-0.1) == {
        "EURUSD.DWX": 1,
        "GBPUSD.DWX": 1,
        "USDJPY.DWX": -1,
    }


def test_preholdout_gate_requires_four_positive_development_years() -> None:
    metrics = {
        "dev_2018_2022": {"trades": 50, "net_r": 5.0, "profit_factor": 1.2},
        "validation_2023": {"trades": 10, "net_r": 1.0, "profit_factor": 1.1},
        "annual": {str(year): {"net_r": 1.0} for year in range(2018, 2023)},
    }
    assert subject.preholdout_pass(metrics)
    metrics["annual"]["2018"]["net_r"] = -1.0
    metrics["annual"]["2019"]["net_r"] = -1.0
    assert not subject.preholdout_pass(metrics)
