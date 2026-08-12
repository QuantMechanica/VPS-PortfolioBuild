from __future__ import annotations

import pytest

from tools.strategy_farm.portfolio.ftmo_incumbent_weight_probe import (
    build_leave_one_out_manifest,
    build_cumulative_manifest,
    build_logistic_normal_manifest,
    build_probe_manifest,
    perturb_weights,
)


def test_leave_one_out_zeroes_each_sleeve_and_renormalizes() -> None:
    base = {
        "scenarios": [
            {"name": "base", "weights": {"1:A.DWX": 0.25, "2:B.DWX": 0.75}}
        ]
    }

    output = build_leave_one_out_manifest(base, base_scenario="base")

    assert len(output["scenarios"]) == 3
    first_drop = output["scenarios"][1]["weights"]
    assert first_drop == {"1:A.DWX": 0.0, "2:B.DWX": 1.0}
    assert sum(output["scenarios"][2]["weights"].values()) == pytest.approx(1.0)


def test_perturb_weights_moves_one_sleeve_and_scales_others() -> None:
    result = perturb_weights({"1:A": 0.6, "2:B": 0.3, "3:C": 0.1}, "2:B", 5.0)

    assert result == pytest.approx({"1:A": 0.5571428571, "2:B": 0.35, "3:C": 0.0928571429})
    assert sum(result.values()) == pytest.approx(1.0)


def test_build_probe_manifest_skips_negative_weight() -> None:
    base = {
        "sleeves": [{"ea_id": 1, "symbol": "A"}, {"ea_id": 2, "symbol": "B"}],
        "scenarios": [{"name": "locked", "weights": {"1:A": 0.99, "2:B": 0.01}}],
    }

    result = build_probe_manifest(base, base_scenario="locked", deltas_pct=[-2.0, 2.0])

    names = [row["name"] for row in result["scenarios"]]
    assert names == ["locked_control", "probe_1_a_down2", "probe_2_b_up2"]
    assert result["generator"]["skipped"] == [
        {
            "key": "1:A",
            "delta_pct": 2.0,
            "reason": "perturbed weight must remain in [0, 1)",
        },
        {
            "key": "2:B",
            "delta_pct": -2.0,
            "reason": "perturbed weight must remain in [0, 1)",
        },
    ]


def test_build_cumulative_manifest_applies_ordered_path() -> None:
    base = {
        "scenarios": [{"name": "locked", "weights": {"1:A": 0.6, "2:B": 0.4}}],
    }

    result = build_cumulative_manifest(
        base,
        base_scenario="locked",
        operations=[("1:A", -10.0), ("2:B", 10.0)],
    )

    assert [row["name"] for row in result["scenarios"]] == [
        "locked_control",
        "path_01_1_a_down10",
        "path_02_2_b_up10",
    ]
    assert result["scenarios"][1]["weights"] == pytest.approx({"1:A": 0.5, "2:B": 0.5})
    assert result["scenarios"][2]["weights"] == pytest.approx({"1:A": 0.4, "2:B": 0.6})


def test_logistic_normal_manifest_is_deterministic_and_regularized() -> None:
    base = {
        "scenarios": [
            {
                "name": "locked",
                "weights": {"1:A": 0.4, "2:B": 0.35, "3:C": 0.25},
            }
        ]
    }

    first = build_logistic_normal_manifest(
        base,
        base_scenario="locked",
        seed=17,
        sigmas=[0.1, 0.2],
        candidates_per_sigma=3,
        max_weight=0.5,
        max_l1_distance=0.3,
    )
    second = build_logistic_normal_manifest(
        base,
        base_scenario="locked",
        seed=17,
        sigmas=[0.1, 0.2],
        candidates_per_sigma=3,
        max_weight=0.5,
        max_l1_distance=0.3,
    )

    assert first == second
    assert len(first["scenarios"]) == 7
    control = first["scenarios"][0]["weights"]
    for scenario in first["scenarios"][1:]:
        weights = scenario["weights"]
        assert sum(weights.values()) == pytest.approx(1.0)
        assert max(weights.values()) <= 0.5
        assert sum(abs(weights[key] - control[key]) for key in control) <= 0.3
    assert base["scenarios"][0]["weights"] == {"1:A": 0.4, "2:B": 0.35, "3:C": 0.25}


def test_logistic_normal_manifest_rejects_zero_base_weight() -> None:
    base = {
        "scenarios": [{"name": "locked", "weights": {"1:A": 1.0, "2:B": 0.0}}]
    }

    with pytest.raises(ValueError, match="positive base weights"):
        build_logistic_normal_manifest(
            base,
            base_scenario="locked",
            seed=1,
            sigmas=[0.2],
            candidates_per_sigma=1,
            max_weight=0.9,
            max_l1_distance=0.5,
        )
