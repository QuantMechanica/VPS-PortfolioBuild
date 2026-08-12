from __future__ import annotations

import copy
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "portfolio"))

import dxz_next_book_trigger as trigger  # noqa: E402


def packet(*, sharpe: float = 0.66, dd: float = 10.05) -> dict:
    basis = {
        "window": ["2018-07-02", "2025-12-31"],
        "cost_model_sha256": "a" * 64,
        "stream_contract": "sealed-dxz-v1",
    }
    basis_sha = trigger.canonical_sha256(basis)
    return {
        "schema_version": 1,
        "comparison_basis": basis,
        "comparison_basis_sha256": basis_sha,
        "incumbent": {
            "book_id": "FINAL24",
            "comparison_basis_sha256": basis_sha,
            "evidence_sha256": "b" * 64,
            "oos_metrics": {"sharpe": 0.60, "max_drawdown_pct": 10.00},
            "robustness_status": "PASS",
        },
        "challenger": {
            "book_id": "NEXT",
            "comparison_basis_sha256": basis_sha,
            "evidence_sha256": "c" * 64,
            "oos_metrics": {"sharpe": sharpe, "max_drawdown_pct": dd},
            "robustness_status": "PASS",
            "correlation_contribution": "NEUTRAL",
            "operational_complexity": "SAME_OR_LOWER",
        },
        "live_probation": {"status": "SEPARATE_AXIS", "sessions": 7},
    }


def test_exact_owner_thresholds_are_better_and_never_auto_deploy() -> None:
    result = trigger.classify(packet(sharpe=0.66, dd=10.05))
    assert result["trigger_class"] == "BETTER"
    assert result["owner_review_unlocked"] is True
    assert result["deployment_action"] == "NONE"


@pytest.mark.parametrize(
    ("sharpe", "dd", "expected"),
    [
        (0.659999, 10.05, "NO_MATERIAL_GAIN"),
        (0.66, 10.050001, "MATERIAL_BUT_REVIEW"),
        (0.61, 9.94, "MATERIAL_BUT_REVIEW"),
        (0.59, 10.00, "NO_MATERIAL_GAIN"),
    ],
)
def test_boundary_classes(sharpe: float, dd: float, expected: str) -> None:
    assert trigger.classify(packet(sharpe=sharpe, dd=dd))["trigger_class"] == expected


def test_non_pass_robustness_demotes_numeric_better_to_review() -> None:
    payload = packet()
    payload["challenger"]["robustness_status"] = "REVIEW"
    result = trigger.classify(payload)
    assert result["trigger_class"] == "MATERIAL_BUT_REVIEW"
    assert "CHALLENGER_ROBUSTNESS_NOT_PASS" in result["review_flags"]


def test_comparison_basis_mismatch_fails_closed() -> None:
    payload = packet()
    payload["challenger"]["comparison_basis_sha256"] = "d" * 64
    with pytest.raises(trigger.ContractError, match="comparison_basis_sha256 mismatch"):
        trigger.classify(payload)


def test_live_metrics_cannot_be_mixed_into_oos_book_axis() -> None:
    payload = packet()
    payload["challenger"]["live_metrics"] = {"sharpe": 99}
    with pytest.raises(trigger.ContractError, match="mixes live"):
        trigger.classify(payload)


def test_same_inputs_are_deterministic() -> None:
    payload = packet()
    assert trigger.classify(payload) == trigger.classify(copy.deepcopy(payload))
