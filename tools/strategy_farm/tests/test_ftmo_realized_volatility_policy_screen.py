from __future__ import annotations

from tools.strategy_farm.portfolio.ftmo_realized_volatility_policy_screen import (
    select_development_winner,
)


def test_selects_largest_minimum_dual_fill_improvement() -> None:
    rows = [
        {
            "name": "control",
            "normal_delta_pct_points": 0.0,
            "adverse_delta_pct_points": 0.0,
            "maximum_effective_risk_multiplier": 25.0,
        },
        {
            "name": "normal_heavy",
            "normal_delta_pct_points": 2.0,
            "adverse_delta_pct_points": 0.1,
            "maximum_effective_risk_multiplier": 31.25,
        },
        {
            "name": "balanced",
            "normal_delta_pct_points": 0.5,
            "adverse_delta_pct_points": 0.4,
            "maximum_effective_risk_multiplier": 31.25,
        },
    ]
    assert select_development_winner(rows)["name"] == "balanced"


def test_requires_strict_improvement_in_both_fills() -> None:
    rows = [
        {
            "name": "control",
            "normal_delta_pct_points": 0.0,
            "adverse_delta_pct_points": 0.0,
            "maximum_effective_risk_multiplier": 25.0,
        },
        {
            "name": "tie",
            "normal_delta_pct_points": 0.5,
            "adverse_delta_pct_points": 0.0,
            "maximum_effective_risk_multiplier": 31.25,
        },
    ]
    assert select_development_winner(rows) is None
