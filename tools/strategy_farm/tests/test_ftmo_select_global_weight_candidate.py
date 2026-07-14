from __future__ import annotations

import pytest

from tools.strategy_farm.portfolio.ftmo_select_global_weight_candidate import (
    FILL_KEYS,
    select_candidate,
)


def _artifact(control: float, first: float, second: float) -> dict:
    return {
        "results": [
            {"scenario": "locked_control", "historical_rolling": {"pass_pct": control}},
            {"scenario": "candidate_a", "historical_rolling": {"pass_pct": first}},
            {"scenario": "candidate_b", "historical_rolling": {"pass_pct": second}},
        ]
    }


def test_select_candidate_uses_frozen_maximin_rule() -> None:
    manifest = {
        "scenarios": [
            {"name": "locked_control", "weights": {}},
            {
                "name": "candidate_a",
                "weights": {},
                "search_metadata": {"l1_distance_from_control": 0.2},
            },
            {
                "name": "candidate_b",
                "weights": {},
                "search_metadata": {"l1_distance_from_control": 0.1},
            },
        ]
    }
    artifacts = {
        "development_threshold": _artifact(50.0, 52.0, 51.0),
        "development_adverse": _artifact(45.0, 46.0, 46.0),
        "validation_threshold": _artifact(55.0, 55.5, 57.0),
        "validation_adverse": _artifact(48.0, 48.5, 49.0),
    }

    result = select_candidate(
        manifest=manifest,
        artifacts=artifacts,
        control_name="locked_control",
        development_minimum_delta=0.5,
        validation_minimum_delta=0.0,
    )

    assert result["status"] == "SURVIVOR"
    assert result["eligible_count"] == 2
    assert result["winner"]["scenario"] == "candidate_b"
    assert result["winner"]["minimum_delta_pct_points"] == pytest.approx(1.0)
    assert result["sealed_holdout_open_allowed"] is False


def test_select_candidate_closes_family_when_validation_regresses() -> None:
    manifest = {
        "scenarios": [
            {"name": "locked_control", "weights": {}},
            {"name": "candidate_a", "weights": {}},
            {"name": "candidate_b", "weights": {}},
        ]
    }
    artifacts = {key: _artifact(50.0, 51.0, 51.0) for key in FILL_KEYS}
    artifacts["validation_adverse"] = _artifact(50.0, 49.9, 49.5)

    result = select_candidate(
        manifest=manifest,
        artifacts=artifacts,
        control_name="locked_control",
        development_minimum_delta=0.5,
        validation_minimum_delta=0.0,
    )

    assert result["status"] == "NO_SURVIVOR"
    assert result["winner"] is None
    assert result["combined_preholdout_required"] is False


def test_select_candidate_rejects_scenario_set_drift() -> None:
    manifest = {
        "scenarios": [
            {"name": "locked_control", "weights": {}},
            {"name": "candidate_a", "weights": {}},
            {"name": "candidate_b", "weights": {}},
        ]
    }
    artifacts = {key: _artifact(50.0, 51.0, 51.0) for key in FILL_KEYS}
    artifacts["validation_adverse"]["results"].pop()

    with pytest.raises(ValueError, match="scenario sets differ"):
        select_candidate(
            manifest=manifest,
            artifacts=artifacts,
            control_name="locked_control",
            development_minimum_delta=0.5,
            validation_minimum_delta=0.0,
        )
