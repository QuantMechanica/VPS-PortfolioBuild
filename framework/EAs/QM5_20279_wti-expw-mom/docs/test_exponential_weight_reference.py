#!/usr/bin/env python3
"""Independent reference vectors for QM5_20279's fixed exponential weights."""

from __future__ import annotations

import math


RETURN_MONTHS = 12
HALF_LIFE_MONTHS = 3.0


def weights() -> tuple[float, ...]:
    """Return oldest-to-newest weights with newest age zero."""
    return tuple(
        math.pow(2.0, -(RETURN_MONTHS - 1 - index) / HALF_LIFE_MONTHS)
        for index in range(RETURN_MONTHS)
    )


def exponential_weighted_mean(returns: list[float]) -> float:
    if len(returns) != RETURN_MONTHS:
        raise ValueError("exactly twelve chronological returns are required")
    if not all(math.isfinite(value) for value in returns):
        raise ValueError("returns must be finite")
    fixed_weights = weights()
    total = sum(fixed_weights)
    if not math.isfinite(total) or total <= 0.0:
        raise AssertionError("weight total must be finite and positive")
    return sum(weight * value for weight, value in zip(fixed_weights, returns)) / total


def linear_weighted_mean(returns: list[float]) -> float:
    return sum((index + 1) * value for index, value in enumerate(returns)) / 78.0


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
    fixed_weights = weights()
    assert len(fixed_weights) == RETURN_MONTHS
    assert all(math.isfinite(value) and 0.0 < value <= 1.0 for value in fixed_weights)
    assert all(fixed_weights[index] < fixed_weights[index + 1] for index in range(11))
    assert_close(fixed_weights[11], 1.0)
    assert_close(fixed_weights[8], 0.5)
    assert_close(fixed_weights[5], 0.25)
    assert_close(fixed_weights[2], 0.125)

    positive = [0.01] * RETURN_MONTHS
    negative = [-0.01] * RETURN_MONTHS
    flat = [0.0] * RETURN_MONTHS
    assert_close(exponential_weighted_mean(positive), 0.01)
    assert_close(exponential_weighted_mean(negative), -0.01)
    assert_close(exponential_weighted_mean(flat), 0.0)
    assert signal(exponential_weighted_mean(positive)) == 1
    assert signal(exponential_weighted_mean(negative)) == -1
    assert signal(exponential_weighted_mean(flat)) == 0

    # Chronology is load-bearing. Both vectors have the same observations and
    # positive cumulative return, but reversing their age orientation flips
    # the exponential-recency signal.
    recent_reversal = [0.08] + [0.0] * 10 + [-0.02]
    old_reversal = list(reversed(recent_reversal))
    assert sum(recent_reversal) > 0.0
    assert sum(old_reversal) > 0.0
    assert signal(exponential_weighted_mean(recent_reversal)) == -1
    assert signal(exponential_weighted_mean(old_reversal)) == 1

    # The fixed exponential kernel can reverse on a recent shock while the
    # existing linear, median, trimmed, and Winsorized estimators remain long.
    neighbor_divergence = [0.01] * 11 + [-0.05]
    ordered = sorted(neighbor_divergence)
    raw_median = 0.5 * (ordered[5] + ordered[6])
    trimmed_mean = sum(ordered[2:10]) / 8.0
    winsorized = [ordered[2], ordered[2], *ordered[2:10], ordered[9], ordered[9]]
    winsorized_mean = sum(winsorized) / 12.0
    assert linear_weighted_mean(neighbor_divergence) > 0.0
    assert raw_median > 0.0
    assert trimmed_mean > 0.0
    assert winsorized_mean > 0.0
    assert signal(exponential_weighted_mean(neighbor_divergence)) == -1

    # A direct hand calculation protects newest-age-zero orientation.
    ramp = [float(index) / 1000.0 for index in range(1, 13)]
    expected = sum(weight * value for weight, value in zip(fixed_weights, ramp)) / sum(fixed_weights)
    assert_close(exponential_weighted_mean(ramp), expected)

    print("PASS QM5_20279 exponential-weight reference vectors")


if __name__ == "__main__":
    main()
