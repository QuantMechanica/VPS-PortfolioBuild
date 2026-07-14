from __future__ import annotations

import pytest

from tools.strategy_farm.portfolio.ftmo_candidate_donor_transfer_manifest import (
    build_manifest,
)


def base_manifest() -> dict:
    return {
        "candidate_evidence": ["base.json"],
        "sleeves": [
            {"ea_id": 1, "symbol": "A"},
            {"ea_id": 2, "symbol": "B"},
        ],
        "scenarios": [
            {"name": "locked", "weights": {"1:A": 0.6, "2:B": 0.4}},
        ],
    }


def candidate_spec() -> dict:
    return {
        "candidate_evidence": ["candidate.json"],
        "sleeve": {"ea_id": 3, "symbol": "C"},
    }


def test_transfers_only_declared_donor_weight() -> None:
    output = build_manifest(
        base_manifest(),
        candidate_spec(),
        base_scenario="locked",
        donor_keys=["1:A", "2:B"],
        candidate_weights_pct=[1.0],
        control_name="control",
        scenario_prefix="sub",
    )

    assert [row["name"] for row in output["scenarios"]] == [
        "control",
        "sub_1_A_01",
        "sub_2_B_01",
    ]
    assert output["scenarios"][1]["weights"] == pytest.approx(
        {"1:A": 0.59, "2:B": 0.4, "3:C": 0.01}
    )
    assert output["scenarios"][2]["weights"] == pytest.approx(
        {"1:A": 0.6, "2:B": 0.39, "3:C": 0.01}
    )
    assert output["candidate_evidence"] == ["base.json", "candidate.json"]


def test_rejects_unknown_donor() -> None:
    with pytest.raises(ValueError, match="unknown donor"):
        build_manifest(
            base_manifest(),
            candidate_spec(),
            base_scenario="locked",
            donor_keys=["9:Z"],
            candidate_weights_pct=[1.0],
            control_name="control",
            scenario_prefix="sub",
        )


def test_rejects_transfer_above_donor_weight() -> None:
    with pytest.raises(ValueError, match="exceeds donor"):
        build_manifest(
            base_manifest(),
            candidate_spec(),
            base_scenario="locked",
            donor_keys=["2:B"],
            candidate_weights_pct=[50.0],
            control_name="control",
            scenario_prefix="sub",
        )
