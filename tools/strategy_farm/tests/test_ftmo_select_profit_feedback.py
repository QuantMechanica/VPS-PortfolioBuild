from __future__ import annotations

import pytest

from tools.strategy_farm.portfolio.ftmo_select_profit_feedback import select_policies


def _row(risk: float, steps: list[tuple[float, float]], passed: float, daily: float, maximum: float) -> dict:
    return {
        "scenario": "selected",
        "risk_multiplier": risk,
        "profit_risk_steps": [
            {"profit_threshold": threshold, "risk_multiplier": multiplier}
            for threshold, multiplier in steps
        ],
        "historical_rolling": {
            "pass_pct": passed,
            "daily_breach_pct": daily,
            "max_breach_pct": maximum,
            "not_reached_pct": 100.0 - passed - daily,
        },
    }


def _artifact(fill: str, candidate_pass: float = 51.0, candidate_daily: float = 1.0) -> dict:
    return {
        "fill_contract": fill,
        "manifest": "manifest.json",
        "excluded_years": [2017, 2020, 2023, 2024, 2025],
        "start_windows": 100,
        "trade_paths": 200,
        "results": [
            _row(25.0, [], 50.0, 2.0, 3.0),
            _row(20.0, [(2000.0, 25.0)], candidate_pass, candidate_daily, 2.5),
        ],
    }


def _predeclaration() -> dict:
    return {
        "manifest": "manifest.json",
        "scenario": "selected",
        "selection_split": {
            "development_years": [2018, 2019, 2021, 2022],
            "development_excluded_years": [2017, 2020, 2023, 2024, 2025],
        },
        "control": {
            "name": "fixed_25",
            "base_risk_multiplier": 25.0,
            "profit_risk_steps": [],
        },
        "candidates": [
            {
                "name": "candidate",
                "base_risk_multiplier": 20.0,
                "profit_risk_steps": [[2000.0, 25.0]],
            }
        ],
    }


def test_selects_policy_only_when_both_fills_improve_without_more_breaches() -> None:
    result = select_policies(
        _predeclaration(), _artifact("ideal_threshold_inside_m15_bar"), _artifact("adverse_bar")
    )
    assert result["status"] == "DEVELOPMENT_SURVIVOR_FOUND"
    assert result["survivors"][0]["name"] == "candidate"


def test_rejects_policy_when_one_fill_does_not_improve() -> None:
    result = select_policies(
        _predeclaration(),
        _artifact("ideal_threshold_inside_m15_bar"),
        _artifact("adverse_bar", candidate_pass=49.0),
    )
    assert result["status"] == "NO_DEVELOPMENT_SURVIVOR"


def test_rejects_policy_when_breach_rate_increases() -> None:
    result = select_policies(
        _predeclaration(),
        _artifact("ideal_threshold_inside_m15_bar", candidate_daily=2.1),
        _artifact("adverse_bar"),
    )
    assert result["status"] == "NO_DEVELOPMENT_SURVIVOR"


def test_rejects_metadata_drift() -> None:
    adverse = _artifact("adverse_bar")
    adverse["start_windows"] = 99
    with pytest.raises(ValueError, match="start_windows"):
        select_policies(_predeclaration(), _artifact("ideal_threshold_inside_m15_bar"), adverse)


def test_rejects_missing_predeclared_candidate() -> None:
    adverse = _artifact("adverse_bar")
    adverse["results"] = adverse["results"][:1]
    with pytest.raises(ValueError, match="candidate policy is missing"):
        select_policies(_predeclaration(), _artifact("ideal_threshold_inside_m15_bar"), adverse)


def test_rejects_development_year_contamination() -> None:
    threshold = _artifact("ideal_threshold_inside_m15_bar")
    threshold["excluded_years"] = [2017, 2020, 2023, 2024]
    adverse = _artifact("adverse_bar")
    adverse["excluded_years"] = [2017, 2020, 2023, 2024]
    with pytest.raises(ValueError, match="excluded years"):
        select_policies(_predeclaration(), threshold, adverse)
