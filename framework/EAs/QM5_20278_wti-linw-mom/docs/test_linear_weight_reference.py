#!/usr/bin/env python3
"""Independent reference vectors for QM5_20278's fixed linear weights."""

from __future__ import annotations

import math


WEIGHTS = tuple(range(1, 13))
WEIGHT_TOTAL = 78


def linear_weighted_mean(returns: list[float]) -> float:
    if len(returns) != 12:
        raise ValueError("exactly twelve chronological returns are required")
    if sum(WEIGHTS) != WEIGHT_TOTAL:
        raise AssertionError("weight contract changed")
    if not all(math.isfinite(value) for value in returns):
        raise ValueError("returns must be finite")
    return sum(weight * value for weight, value in zip(WEIGHTS, returns)) / WEIGHT_TOTAL


def signal(value: float) -> int:
    if value > 0.0:
        return 1
    if value < 0.0:
        return -1
    return 0


def assert_close(actual: float, expected: float, tolerance: float = 1.0e-14) -> None:
    if not math.isclose(actual, expected, rel_tol=0.0, abs_tol=tolerance):
        raise AssertionError(f"actual={actual!r} expected={expected!r}")


def main() -> None:
    assert WEIGHTS == (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
    assert sum(WEIGHTS) == WEIGHT_TOTAL

    positive = [0.01] * 12
    negative = [-0.01] * 12
    flat = [0.0] * 12
    assert_close(linear_weighted_mean(positive), 0.01)
    assert_close(linear_weighted_mean(negative), -0.01)
    assert_close(linear_weighted_mean(flat), 0.0)
    assert signal(linear_weighted_mean(positive)) == 1
    assert signal(linear_weighted_mean(negative)) == -1
    assert signal(linear_weighted_mean(flat)) == 0

    # Chronology is load-bearing. Both vectors have the same observations and
    # the same positive cumulative return, but opposite linear-weight signals.
    recent_reversal = [0.12] + [0.0] * 10 + [-0.02]
    old_reversal = list(reversed(recent_reversal))
    assert sum(recent_reversal) > 0.0
    assert sum(old_reversal) > 0.0
    assert signal(linear_weighted_mean(recent_reversal)) == -1
    assert signal(linear_weighted_mean(old_reversal)) == 1

    # A recent shock can reverse this estimator while the raw median, trimmed
    # mean, and fixed-tail Winsorized mean all remain positive.
    robust_divergence = [0.01] * 11 + [-0.12]
    ordered = sorted(robust_divergence)
    raw_median = 0.5 * (ordered[5] + ordered[6])
    trimmed_mean = sum(ordered[2:10]) / 8.0
    winsorized = [ordered[2], ordered[2], *ordered[2:10], ordered[9], ordered[9]]
    winsorized_mean = sum(winsorized) / 12.0
    assert raw_median > 0.0
    assert trimmed_mean > 0.0
    assert winsorized_mean > 0.0
    assert signal(linear_weighted_mean(robust_divergence)) == -1

    # A direct hand calculation protects the oldest/newest orientation.
    ramp = [float(index) / 1000.0 for index in range(1, 13)]
    expected = sum((index + 1) ** 2 for index in range(12)) / 1000.0 / WEIGHT_TOTAL
    assert_close(linear_weighted_mean(ramp), expected)

    print("PASS QM5_20278 linear-weight reference vectors")


if __name__ == "__main__":
    main()
