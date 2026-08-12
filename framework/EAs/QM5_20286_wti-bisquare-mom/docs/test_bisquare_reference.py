#!/usr/bin/env python3
"""Independent reference vectors for QM5_20286's locked bisquare statistic."""

from __future__ import annotations

import json
import math


RETURN_COUNT = 12
BISQUARE_CUTOFF = 4.685
MAD_NORMALIZER = 1.4826
BISQUARE_STEPS = 32


def even_median(values: list[float]) -> float:
    assert len(values) == RETURN_COUNT
    ordered = sorted(values)
    return (ordered[5] + ordered[6]) / 2.0


def bisquare_location(
    values: list[float], steps: int = BISQUARE_STEPS
) -> tuple[float, dict[str, float | int]]:
    assert len(values) == RETURN_COUNT
    median = even_median(values)
    mad = even_median([abs(value - median) for value in values])
    scale = MAD_NORMALIZER * mad
    cutoff = BISQUARE_CUTOFF * scale
    if not math.isfinite(cutoff) or cutoff <= 0.0:
        raise ValueError("nonpositive_or_invalid_bisquare_scale")

    location = median
    rejected = 0
    for _ in range(steps):
        weights = []
        for value in values:
            normalized = (value - location) / cutoff
            weight = (1.0 - normalized * normalized) ** 2 if abs(normalized) < 1.0 else 0.0
            weights.append(weight)
        total_weight = sum(weights)
        if not math.isfinite(total_weight) or total_weight <= 0.0:
            raise ValueError("invalid_bisquare_weight_sum")
        location = sum(
            weight * value for weight, value in zip(weights, values, strict=True)
        ) / total_weight
        assert math.isfinite(location)
        rejected = sum(weight == 0.0 for weight in weights)

    return location, {
        "median": median,
        "mad": mad,
        "scale": scale,
        "cutoff": cutoff,
        "final_zero_weight_count": rejected,
    }


def huber_location(values: list[float], steps: int = BISQUARE_STEPS) -> float:
    median = even_median(values)
    mad = even_median([abs(value - median) for value in values])
    delta = 1.5 * MAD_NORMALIZER * mad
    if delta <= 0.0:
        raise ValueError("bad_huber_scale")
    location = median
    for _ in range(steps):
        weights = [
            1.0 if abs(value - location) <= delta else delta / abs(value - location)
            for value in values
        ]
        location = sum(
            weight * value for weight, value in zip(weights, values, strict=True)
        ) / sum(weights)
    return location


def sign(value: float) -> int:
    if value == 0.0:
        return 0
    return 1 if value > 0.0 else -1


def closes_from_returns(values: list[float], start: float = 70.0) -> list[float]:
    closes = [start]
    for value in values:
        closes.append(closes[-1] * math.exp(value))
    return closes


def consecutive_month_keys(start_year: int, start_month: int, count: int) -> list[int]:
    keys: list[int] = []
    year, month = start_year, start_month
    for _ in range(count):
        keys.append(year * 100 + month)
        month += 1
        if month > 12:
            year += 1
            month = 1
    return keys


def main() -> int:
    results: dict[str, object] = {}

    positive = [0.010 + index * 0.001 for index in range(RETURN_COUNT)]
    negative = [-value for value in positive]
    symmetric = [-6.0, -5.0, -4.0, -3.0, -2.0, -1.0,
                 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
    for name, values, expected_sign in (
        ("positive_cluster", positive, 1),
        ("negative_cluster", negative, -1),
        ("symmetric_zero", symmetric, 0),
    ):
        location, state = bisquare_location(values)
        if expected_sign == 0:
            assert math.isclose(location, 0.0, abs_tol=1.0e-15)
            location = 0.0
        assert sign(location) == expected_sign
        results[name] = {"bisquare": location, "sign": expected_sign, **state}

    # This fixed vector makes the locked bisquare location positive while the
    # closest Huber neighbor is negative. The two remote negative observations
    # have exactly zero final influence, proving the redescending rule matters.
    divergence = [
        -0.005, -0.040, -0.002, -0.010, -0.002, -0.002,
        -0.080, 0.001, 0.010, 0.002, 0.020, -0.060,
    ]
    location, state = bisquare_location(divergence)
    huber = huber_location(divergence)
    assert math.isclose(location, 0.0005493537715735436, abs_tol=1.0e-15)
    assert location > 0.0 > huber
    assert state["final_zero_weight_count"] == 2
    results["huber_sign_and_tail_influence_divergence"] = {
        "bisquare": location,
        "huber": huber,
        **state,
    }

    one_step, _ = bisquare_location(divergence, steps=1)
    thirty_one, _ = bisquare_location(divergence, steps=31)
    assert not math.isclose(one_step, location, abs_tol=1.0e-12)
    assert math.isclose(thirty_one, location, abs_tol=1.0e-15)
    results["fixed_32_step_contract"] = {
        "one_step": one_step,
        "thirty_one_steps": thirty_one,
        "thirty_two_steps": location,
    }

    try:
        bisquare_location([0.01] * RETURN_COUNT)
    except ValueError as exc:
        assert str(exc) == "nonpositive_or_invalid_bisquare_scale"
    else:
        raise AssertionError("zero MAD must fail closed")
    results["zero_mad_fail_closed"] = True

    reconstruction_returns = [
        0.012, -0.004, 0.021, -0.008, 0.014, 0.006,
        -0.003, 0.017, -0.009, 0.011, 0.005, -0.002,
    ]
    closes = closes_from_returns(reconstruction_returns)
    rebuilt = [
        math.log(closes[index + 1] / closes[index]) for index in range(RETURN_COUNT)
    ]
    for expected, observed in zip(reconstruction_returns, rebuilt, strict=True):
        assert math.isclose(expected, observed, abs_tol=1.0e-15)
    assert consecutive_month_keys(2025, 7, 13) == [
        202507, 202508, 202509, 202510, 202511, 202512,
        202601, 202602, 202603, 202604, 202605, 202606, 202607,
    ]
    results["endpoint_orientation_and_cross_year_continuity"] = {
        "closes": closes,
        "rebuilt_returns": rebuilt,
    }

    print(json.dumps({"status": "PASS", "cases": results}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
