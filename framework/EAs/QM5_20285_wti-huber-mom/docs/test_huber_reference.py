#!/usr/bin/env python3
"""Independent reference vectors for QM5_20285's locked Huber statistic."""

from __future__ import annotations

import json
import math


RETURN_COUNT = 12
HUBER_TUNING = 1.5
MAD_NORMALIZER = 1.4826
HUBER_STEPS = 32


def even_median(values: list[float]) -> float:
    assert len(values) == RETURN_COUNT
    ordered = sorted(values)
    return (ordered[5] + ordered[6]) / 2.0


def huber_location(values: list[float], steps: int = HUBER_STEPS) -> tuple[float, dict[str, float]]:
    assert len(values) == RETURN_COUNT
    median = even_median(values)
    mad = even_median([abs(value - median) for value in values])
    scale = MAD_NORMALIZER * mad
    delta = HUBER_TUNING * scale
    if not math.isfinite(delta) or delta <= 0.0:
        raise ValueError("nonpositive_or_invalid_huber_scale")

    location = median
    for _ in range(steps):
        weights = []
        for value in values:
            residual = abs(value - location)
            weights.append(1.0 if residual <= delta else delta / residual)
        total_weight = sum(weights)
        location = sum(weight * value for weight, value in zip(weights, values, strict=True)) / total_weight
        assert math.isfinite(location)

    return location, {"median": median, "mad": mad, "scale": scale, "delta": delta}


def three_raw_mad_cap_mean(values: list[float]) -> float:
    median = even_median(values)
    mad = even_median([abs(value - median) for value in values])
    low, high = median - 3.0 * mad, median + 3.0 * mad
    return sum(max(low, min(high, value)) for value in values) / RETURN_COUNT


def two_tail_winsor_mean(values: list[float]) -> float:
    ordered = sorted(values)
    low, high = ordered[2], ordered[9]
    return sum(max(low, min(high, value)) for value in ordered) / RETURN_COUNT


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
        location, state = huber_location(values)
        if expected_sign == 0:
            assert math.isclose(location, 0.0, abs_tol=1.0e-15)
            location = 0.0
        assert sign(location) == expected_sign
        results[name] = {"huber": location, "sign": expected_sign, **state}

    # This fixed vector makes the 32-step Huber location negative while both
    # closest repository neighbors (one-shot MAD cap and fixed-tail Winsor)
    # are positive. It proves the re-centering rule is load-bearing.
    divergence = [-1.0, -2.0, 0.1, 3.0, 5.0, 5.0,
                  0.6, -1.0, -0.2, -0.5, -2.0, -3.0]
    location, state = huber_location(divergence)
    madcap = three_raw_mad_cap_mean(divergence)
    winsor = two_tail_winsor_mean(divergence)
    assert math.isclose(location, -0.027232500000000173, abs_tol=1.0e-14)
    assert location < 0.0 < madcap and 0.0 < winsor
    results["madcap_and_winsor_sign_divergence"] = {
        "huber": location,
        "madcap": madcap,
        "winsor": winsor,
        **state,
    }

    # The fixed update sequence must not collapse to a one-step cap.
    one_step, _ = huber_location(divergence, steps=1)
    thirty_one, _ = huber_location(divergence, steps=31)
    assert not math.isclose(one_step, location, abs_tol=1.0e-12)
    results["fixed_32_step_contract"] = {
        "one_step": one_step,
        "thirty_one_steps": thirty_one,
        "thirty_two_steps": location,
    }

    try:
        huber_location([0.01] * RETURN_COUNT)
    except ValueError as exc:
        assert str(exc) == "nonpositive_or_invalid_huber_scale"
    else:
        raise AssertionError("zero MAD must fail closed")
    results["zero_mad_fail_closed"] = True

    reconstruction_returns = [0.012, -0.004, 0.021, -0.008, 0.014, 0.006,
                              -0.003, 0.017, -0.009, 0.011, 0.005, -0.002]
    closes = closes_from_returns(reconstruction_returns)
    rebuilt = [math.log(closes[index + 1] / closes[index]) for index in range(RETURN_COUNT)]
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
