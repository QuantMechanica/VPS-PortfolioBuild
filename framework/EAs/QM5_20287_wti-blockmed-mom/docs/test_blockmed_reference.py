#!/usr/bin/env python3
"""Independent reference vectors for QM5_20287's locked block statistic."""

from __future__ import annotations

import json
import math


RETURN_COUNT = 12
BLOCK_MONTHS = 3
BLOCK_COUNT = 4


def block_median_location(values: list[float]) -> tuple[float, list[float]]:
    assert len(values) == RETURN_COUNT
    assert BLOCK_MONTHS * BLOCK_COUNT == RETURN_COUNT
    blocks = [
        sum(values[index : index + BLOCK_MONTHS]) / BLOCK_MONTHS
        for index in range(0, RETURN_COUNT, BLOCK_MONTHS)
    ]
    assert len(blocks) == BLOCK_COUNT
    ordered = sorted(blocks)
    return (ordered[1] + ordered[2]) / 2.0, blocks


def raw_return_median(values: list[float]) -> float:
    ordered = sorted(values)
    return (ordered[5] + ordered[6]) / 2.0


def middle_eight_trimmed_mean(values: list[float]) -> float:
    ordered = sorted(values)
    return sum(ordered[2:10]) / 8.0


def quarterly_sign_consensus(blocks: list[float]) -> int:
    positive = sum(value > 0.0 for value in blocks)
    negative = sum(value < 0.0 for value in blocks)
    if positive >= 3:
        return 1
    if negative >= 3:
        return -1
    return 0


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
    symmetric_blocks = [-0.04] * 3 + [-0.01] * 3 + [0.01] * 3 + [0.04] * 3
    for name, values, expected_sign in (
        ("positive_blocks", positive, 1),
        ("negative_blocks", negative, -1),
        ("symmetric_exact_zero", symmetric_blocks, 0),
    ):
        location, blocks = block_median_location(values)
        if expected_sign == 0:
            assert math.isclose(location, 0.0, abs_tol=1.0e-15)
            location = 0.0
        assert sign(location) == expected_sign
        results[name] = {
            "block_means": blocks,
            "block_median": location,
            "sign": expected_sign,
        }

    # Two negative and two positive blocks are flat under QM5_20272's
    # three-of-four sign vote. Retained magnitude makes this locked statistic
    # positive, proving that the tie-resolution rule is mechanically distinct.
    tie_divergence = [-0.03] * 3 + [-0.01] * 3 + [0.02] * 3 + [0.03] * 3
    location, blocks = block_median_location(tie_divergence)
    assert math.isclose(location, 0.005, abs_tol=1.0e-15)
    assert quarterly_sign_consensus(blocks) == 0
    assert sign(location) == 1
    results["quarterly_vote_tie_divergence"] = {
        "block_means": blocks,
        "block_median": location,
        "quarterly_sign_consensus": 0,
    }

    # Nine of twelve individual returns are negative, so both the raw-return
    # median and the fixed middle-eight trimmed mean are negative. Three
    # positive block means make the block median positive. This freezes the
    # requirement to aggregate chronologically before sorting.
    aggregation_divergence = [
        -0.12, -0.10, -0.08,
        -0.01, -0.01, 0.05,
        -0.01, -0.01, 0.08,
        -0.01, -0.01, 0.13,
    ]
    location, blocks = block_median_location(aggregation_divergence)
    raw_median = raw_return_median(aggregation_divergence)
    trimmed_mean = middle_eight_trimmed_mean(aggregation_divergence)
    assert math.isclose(location, 0.015, abs_tol=1.0e-15)
    assert location > 0.0 > raw_median
    assert location > 0.0 > trimmed_mean
    results["aggregate_before_sort_divergence"] = {
        "block_means": blocks,
        "block_median": location,
        "raw_return_median": raw_median,
        "middle_eight_trimmed_mean": trimmed_mean,
    }

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
        "block_means": block_median_location(rebuilt)[1],
    }

    print(json.dumps({"status": "PASS", "cases": results}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
