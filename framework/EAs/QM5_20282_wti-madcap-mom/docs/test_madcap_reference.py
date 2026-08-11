#!/usr/bin/env python3
"""Independent reference vectors for QM5_20282's locked robust statistic."""

from __future__ import annotations

import json
import math


def even_median(values: list[float]) -> float:
    assert len(values) == 12
    ordered = sorted(values)
    return (ordered[5] + ordered[6]) / 2.0


def mad_capped_mean(values: list[float]) -> tuple[float | None, dict[str, object]]:
    assert len(values) == 12
    median = even_median(values)
    deviations = [abs(value - median) for value in values]
    raw_mad = even_median(deviations)
    if raw_mad <= 0.0:
        return None, {"median": median, "raw_mad": raw_mad, "capped": []}
    low = median - 3.0 * raw_mad
    high = median + 3.0 * raw_mad
    capped = [min(high, max(low, value)) for value in values]
    return sum(capped) / 12.0, {
        "median": median,
        "raw_mad": raw_mad,
        "low": low,
        "high": high,
        "capped": capped,
    }


def fixed_tail_winsor_mean(values: list[float]) -> float:
    ordered = sorted(values)
    low = ordered[2]
    high = ordered[9]
    capped = [low if value < low else high if value > high else value for value in ordered]
    return sum(capped) / 12.0


def middle_eight_trimmed_mean(values: list[float]) -> float:
    ordered = sorted(values)
    return sum(ordered[2:10]) / 8.0


def sign(value: float | None) -> int:
    if value is None or value == 0.0:
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
        "zero_mad_flat": ([0.01] * 12, 0),
    }
    results: dict[str, object] = {}
    for name, (values, expected_sign) in cases.items():
        mean, state = mad_capped_mean(values)
        observed_sign = sign(mean)
        assert observed_sign == expected_sign, (name, mean, state)
        if name == "zero_mad_flat":
            assert mean is None and state["raw_mad"] == 0.0
        else:
            assert state["raw_mad"] > 0.0
        results[name] = {"mean": mean, "sign": observed_sign, **state}

    # Three extreme negative months are adaptively capped above zero because
    # the robust center/dispersion of the nine positive months is tight. The
    # fixed-tail neighbors retain the third negative order statistic and flip.
    distinct = [-10.0, -9.0, -8.0, 0.08, 0.09, 0.10,
                0.11, 0.12, 0.13, 0.14, 0.15, 0.16]
    madcap_mean, state = mad_capped_mean(distinct)
    winsor_mean = fixed_tail_winsor_mean(distinct)
    trim_mean = middle_eight_trimmed_mean(distinct)
    assert math.isclose(state["median"], 0.105, abs_tol=1.0e-15)
    assert math.isclose(state["raw_mad"], 0.03, abs_tol=1.0e-15)
    assert math.isclose(state["low"], 0.015, abs_tol=1.0e-15)
    assert math.isclose(state["high"], 0.195, abs_tol=1.0e-15)
    assert math.isclose(madcap_mean or 0.0, 0.09375, abs_tol=1.0e-15)
    assert madcap_mean is not None and madcap_mean > 0.0
    assert winsor_mean < 0.0 and trim_mean < 0.0
    results["adaptive_cap_sign_divergence"] = {
        "madcap_mean": madcap_mean,
        "winsor_mean": winsor_mean,
        "trimmed_mean": trim_mean,
        **state,
    }

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
