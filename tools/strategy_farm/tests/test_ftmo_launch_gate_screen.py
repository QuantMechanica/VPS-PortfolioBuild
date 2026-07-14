from __future__ import annotations

import datetime as dt

from tools.strategy_farm.portfolio.ftmo_bar_governor_sim import WindowResult
from tools.strategy_farm.portfolio.ftmo_launch_gate_screen import (
    gate_set,
    has_unsealed_lookback,
    preholdout_pass,
    summarize_subset,
    trailing_pnl_features,
)


def result(outcome: str) -> WindowResult:
    return WindowResult(outcome, 100000.0, 95000.0, 4, 1, 0, 0)


def test_trailing_features_exclude_the_start_day() -> None:
    start = dt.date(2024, 1, 10)
    features = trailing_pnl_features(
        [start],
        {
            start: 999.0,
            start - dt.timedelta(days=1): 3.0,
            start - dt.timedelta(days=5): -1.0,
        },
        lookbacks=(1, 5),
    )

    assert features[start] == {1: 3.0, 5: 2.0}


def test_start_lookback_cannot_cross_a_sealed_year() -> None:
    assert not has_unsealed_lookback(dt.date(2021, 1, 31), {2020}, 60)
    assert has_unsealed_lookback(dt.date(2021, 3, 2), {2020}, 60)


def test_gate_rules_are_fixed_zero_thresholds() -> None:
    row = {5: 1.0, 10: -1.0, 20: 2.0, 40: -2.0, 60: 3.0}
    gates = gate_set()

    assert gates["pnl_05_pos"](row)
    assert gates["pnl_05_20_pos"](row)
    assert gates["pnl_10_recovery"](row) is False
    assert gates["pnl_20_60_pos"](row)


def test_subset_rates_and_eligibility_use_only_selected_starts() -> None:
    days = [dt.date(2024, 1, day) for day in range(1, 5)]
    summary = summarize_subset(
        days,
        [result("passed"), result("not_reached"), result("passed"), result("passed")],
        [result("not_reached"), result("passed"), result("passed"), result("passed")],
        [True, False, True, False],
    )

    assert summary["eligible_starts"] == 2
    assert summary["eligible_pct"] == 50.0
    assert summary["threshold_fill"]["pass_pct"] == 100.0
    assert summary["adverse_bar_fill"]["pass_pct"] == 50.0


def test_preholdout_gate_requires_every_fill_and_split() -> None:
    def metrics(threshold: float, adverse: float, starts: int = 200) -> dict:
        return {
            "eligible_starts": starts,
            "eligible_pct": 20.0,
            "threshold_fill": {"pass_pct": threshold},
            "adverse_bar_fill": {"pass_pct": adverse},
        }

    control = metrics(50.0, 45.0)
    assert preholdout_pass(
        metrics(80.0, 77.0),
        metrics(79.0, 76.0, starts=40),
        control,
        control,
        minimum_floor_pct=75.0,
        minimum_improvement_pct=2.0,
    )
    assert not preholdout_pass(
        metrics(80.0, 74.9),
        metrics(79.0, 76.0, starts=40),
        control,
        control,
        minimum_floor_pct=75.0,
        minimum_improvement_pct=2.0,
    )
