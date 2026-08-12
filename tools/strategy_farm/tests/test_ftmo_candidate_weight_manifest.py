from __future__ import annotations

import pytest

from tools.strategy_farm.portfolio.ftmo_candidate_weight_manifest import build_manifest


def base_manifest() -> dict:
    return {
        "status": "RESEARCH_ONLY_NO_GO",
        "deployment_allowed": False,
        "candidate_evidence": ["base.json"],
        "sleeves": [
            {"ea_id": 1, "symbol": "A", "base_risk_fixed": 1000.0},
            {"ea_id": 2, "symbol": "B", "base_risk_fixed": 1000.0},
            {"ea_id": 99, "symbol": "UNUSED", "base_risk_fixed": 1000.0},
        ],
        "scenarios": [
            {"name": "locked", "weights": {"1:A": 0.6, "2:B": 0.4}},
            {"name": "unlocked", "weights": {"1:A": 0.5, "2:B": 0.5}},
        ],
    }


def candidate_spec() -> dict:
    return {
        "candidate_evidence": ["candidate.json"],
        "sleeve": {"ea_id": 3, "symbol": "C", "base_risk_fixed": 1000.0},
    }


def test_builds_risk_neutral_scenarios_from_only_locked_incumbent() -> None:
    output = build_manifest(
        base_manifest(),
        candidate_spec(),
        base_scenario="locked",
        candidate_weights_pct=[1.0, 2.5],
        control_name="control",
        scenario_prefix="candidate",
    )

    assert [row["name"] for row in output["scenarios"]] == [
        "control",
        "candidate_01",
        "candidate_02p5",
    ]
    assert [row["ea_id"] for row in output["sleeves"]] == [1, 2, 3]
    weights = output["scenarios"][1]["weights"]
    assert weights == pytest.approx({"1:A": 0.594, "2:B": 0.396, "3:C": 0.01})
    assert sum(weights.values()) == pytest.approx(1.0)
    assert output["candidate_evidence"] == ["base.json", "candidate.json"]


def test_rejects_duplicate_candidate() -> None:
    duplicate = {"sleeve": {"ea_id": 2, "symbol": "B"}}
    with pytest.raises(ValueError, match="already exists"):
        build_manifest(
            base_manifest(),
            duplicate,
            base_scenario="locked",
            candidate_weights_pct=[1.0],
            control_name="control",
            scenario_prefix="candidate",
        )


def test_rejects_invalid_base_weight_sum() -> None:
    base = base_manifest()
    base["scenarios"][0]["weights"]["2:B"] = 0.3
    with pytest.raises(ValueError, match="sum to one"):
        build_manifest(
            base,
            candidate_spec(),
            base_scenario="locked",
            candidate_weights_pct=[1.0],
            control_name="control",
            scenario_prefix="candidate",
        )
