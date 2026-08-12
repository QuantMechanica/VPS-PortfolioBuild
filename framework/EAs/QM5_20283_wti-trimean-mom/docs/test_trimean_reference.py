#!/usr/bin/env python3
"""Independent reference vectors for QM5_20283's locked trimean statistic."""

from __future__ import annotations

import json
import math


def quartile_trimean(values: list[float]) -> tuple[float, dict[str, float]]:
    assert len(values) == 12
    ordered = sorted(values)
    q1 = (ordered[2] + ordered[3]) / 2.0
    median = (ordered[5] + ordered[6]) / 2.0
    q3 = (ordered[8] + ordered[9]) / 2.0
    value = (q1 + 2.0 * median + q3) / 4.0
    return value, {"q1": q1, "median": median, "q3": q3}


def middle_eight_trimmed_mean(values: list[float]) -> float:
    ordered = sorted(values)
    return sum(ordered[2:10]) / 8.0


def fixed_tail_winsor_mean(values: list[float]) -> float:
    ordered = sorted(values)
    low = ordered[2]
    high = ordered[9]
    capped = [low if value < low else high if value > high else value for value in ordered]
    return sum(capped) / 12.0


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
    cases = {
        "positive_cluster": ([0.010 + i * 0.001 for i in range(12)], 1),
        "negative_cluster": ([-0.021 + i * 0.001 for i in range(12)], -1),
        "symmetric_zero": ([-6.0, -5.0, -4.0, -3.0, -2.0, -1.0,
                             1.0, 2.0, 3.0, 4.0, 5.0, 6.0], 0),
    }
    results: dict[str, object] = {}
    for name, (values, expected_sign) in cases.items():
        value, state = quartile_trimean(values)
        observed_sign = sign(value)
        assert observed_sign == expected_sign, (name, value, state)
        results[name] = {"trimean": value, "sign": observed_sign, **state}

    # Five values at -1 and seven at +0.55 produce a positive trimean because
    # the center receives half the weight. The middle-eight trim and fixed-tail
    # Winsor neighbors remain negative, proving the exact mechanic matters.
    distinct = [-9.0, -8.0, -1.0, -1.0, -1.0,
                0.55, 0.55, 0.55, 0.55, 0.55, 0.55, 0.55]
    value, state = quartile_trimean(distinct)
    trim_mean = middle_eight_trimmed_mean(distinct)
    winsor_mean = fixed_tail_winsor_mean(distinct)
    assert math.isclose(state["q1"], -1.0, abs_tol=1.0e-15)
    assert math.isclose(state["median"], 0.55, abs_tol=1.0e-15)
    assert math.isclose(state["q3"], 0.55, abs_tol=1.0e-15)
    assert math.isclose(value, 0.1625, abs_tol=1.0e-15)
    assert trim_mean < 0.0 and winsor_mean < 0.0
    results["trim_and_winsor_sign_divergence"] = {
        "trimean": value,
        "trimmed_mean": trim_mean,
        "winsor_mean": winsor_mean,
        **state,
    }

    # A positive raw median does not force a positive trimean when the lower
    # quartile is materially negative.
    median_divergence = [-10.0, -9.0, -8.0, -7.0, 0.01, 0.02,
                         0.03, 0.04, 0.05, 0.06, 0.07, 0.08]
    value, state = quartile_trimean(median_divergence)
    assert state["median"] > 0.0 and value < 0.0
    results["median_sign_divergence"] = {"trimean": value, **state}

    # Close reconstruction proves the EA's oldest-to-newest log orientation.
    reconstruction_returns = [0.012, -0.004, 0.021, -0.008, 0.014, 0.006,
                              -0.003, 0.017, -0.009, 0.011, 0.005, -0.002]
    closes = closes_from_returns(reconstruction_returns)
    rebuilt = [math.log(closes[i + 1] / closes[i]) for i in range(12)]
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
