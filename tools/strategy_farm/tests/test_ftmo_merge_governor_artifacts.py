from __future__ import annotations

import pytest

from tools.strategy_farm.portfolio.ftmo_merge_governor_artifacts import (
    merge_artifacts,
)


def _artifact(scenario: str, *, excluded_years: list[int] | None = None) -> dict:
    return {
        "schema_version": 1,
        "status": "RESEARCH_ONLY",
        "basis": "governor",
        "timestamp_basis": "broker_wall",
        "fill_contract": "adverse_bar",
        "manifest": "manifest.json",
        "horizon_calendar_days": 30,
        "excluded_years": excluded_years or [2020],
        "trade_paths": 100,
        "start_windows": 50,
        "results": [
            {
                "scenario": scenario,
                "risk_multiplier": 25.0,
                "daily_stop": 4500.0,
                "full_risk_room": 4000.0,
                "room_retention": 0.2,
                "open_risk_limit_ratio": 0.0,
                "profit_risk_steps": [],
                "elapsed_risk_steps": [],
            }
        ],
    }


def test_merge_artifacts_combines_and_sorts_disjoint_results() -> None:
    result = merge_artifacts([_artifact("b"), _artifact("a")])

    assert [row["scenario"] for row in result["results"]] == ["a", "b"]
    assert result["merged_chunk_count"] == 2
    assert result["merged_result_count"] == 2


def test_merge_artifacts_rejects_metadata_drift() -> None:
    with pytest.raises(ValueError, match="excluded_years"):
        merge_artifacts([_artifact("a"), _artifact("b", excluded_years=[2021])])


def test_merge_artifacts_rejects_duplicate_result() -> None:
    with pytest.raises(ValueError, match="duplicate result identity"):
        merge_artifacts([_artifact("a"), _artifact("a")])
