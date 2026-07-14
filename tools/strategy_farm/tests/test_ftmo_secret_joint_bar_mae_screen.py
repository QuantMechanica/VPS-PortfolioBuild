from __future__ import annotations

import pytest

from tools.strategy_farm.portfolio.ftmo_secret_joint_bar_mae_screen import (
    candidate_weights,
    select_development_winner,
    stage_excluded,
)


def test_candidate_weights_carves_control_proportionally() -> None:
    weights = candidate_weights(
        {"a": 0.6, "b": 0.4},
        {"one": 0.25, "two": 0.75},
        0.1,
    )
    assert weights == {
        "a": pytest.approx(0.54),
        "b": pytest.approx(0.36),
        "SECRET:one": pytest.approx(0.025),
        "SECRET:two": pytest.approx(0.075),
    }
    assert sum(weights.values()) == pytest.approx(1.0)


def test_candidate_weights_rejects_non_unit_secret_mix() -> None:
    with pytest.raises(ValueError, match="sum to one"):
        candidate_weights({"a": 1.0}, {"one": 0.7}, 0.1)


def test_development_winner_requires_both_fills_and_ranks_minimum_delta() -> None:
    rows = [
        {
            "representation": "normal_fail_short_circuit",
            "candidate_weight_pct": 0.5,
            "normal_pass_pct": 59.9,
            "adverse_pass_pct": None,
        },
        {
            "representation": "normal_only",
            "candidate_weight_pct": 1.0,
            "normal_pass_pct": 61.0,
            "adverse_pass_pct": 49.0,
        },
        {
            "representation": "balanced",
            "candidate_weight_pct": 2.0,
            "normal_pass_pct": 60.8,
            "adverse_pass_pct": 50.7,
        },
        {
            "representation": "lopsided",
            "candidate_weight_pct": 1.0,
            "normal_pass_pct": 62.0,
            "adverse_pass_pct": 50.2,
        },
    ]
    winner = select_development_winner(
        rows,
        control_normal=60.0,
        control_adverse=50.0,
    )
    assert winner is not None
    assert winner["representation"] == "balanced"


def test_stage_excluded_is_complement_of_included_years() -> None:
    assert stage_excluded([2023]) == {
        2017,
        2018,
        2019,
        2020,
        2021,
        2022,
        2024,
        2025,
    }
