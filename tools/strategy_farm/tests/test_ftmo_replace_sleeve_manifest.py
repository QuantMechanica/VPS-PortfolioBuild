from __future__ import annotations

import pytest

from tools.strategy_farm.portfolio.ftmo_replace_sleeve_manifest import (
    build_replacement_manifest,
)


def base_manifest() -> dict:
    return {
        "candidate_evidence": ["base.json"],
        "sleeves": [
            {"ea_id": 1, "symbol": "A", "base_risk_fixed": 1000.0, "stream_path": "old"},
            {"ea_id": 2, "symbol": "B", "base_risk_fixed": 1000.0, "stream_path": "keep"},
        ],
        "scenarios": [
            {"name": "locked", "weights": {"1:A": 0.6, "2:B": 0.4}},
            {"name": "other", "weights": {"1:A": 0.5, "2:B": 0.5}},
        ],
    }


def test_replaces_only_evidence_and_preserves_weights() -> None:
    replacement = {
        "candidate_evidence": ["fresh.json"],
        "sleeve": {
            "ea_id": 1,
            "symbol": "a",
            "base_risk_fixed": 1000.0,
            "stream_path": "fresh",
        },
    }
    output = build_replacement_manifest(
        base_manifest(),
        replacement,
        base_scenario="locked",
        scenario_name="candidate",
    )

    assert output["scenarios"] == [
        {"name": "candidate", "weights": {"1:A": 0.6, "2:B": 0.4}}
    ]
    assert output["sleeves"][0]["stream_path"] == "fresh"
    assert output["sleeves"][1]["stream_path"] == "keep"
    assert output["candidate_evidence"] == ["base.json", "fresh.json"]
    assert output["deployment_allowed"] is False


def test_rejects_new_key_and_weight_change() -> None:
    missing = {"sleeve": {"ea_id": 3, "symbol": "C", "base_risk_fixed": 1000.0}}
    with pytest.raises(ValueError, match="not in the locked scenario"):
        build_replacement_manifest(
            base_manifest(), missing, base_scenario="locked", scenario_name="candidate"
        )

    changed = {"sleeve": {"ea_id": 1, "symbol": "A", "base_risk_fixed": 900.0}}
    with pytest.raises(ValueError, match="preserve base_risk_fixed"):
        build_replacement_manifest(
            base_manifest(), changed, base_scenario="locked", scenario_name="candidate"
        )
