#!/usr/bin/env python3
"""Independent reference vectors for QM5_20277's locked return statistic."""

from __future__ import annotations

import json
import math


def winsorized_mean(values: list[float]) -> tuple[float, list[float]]:
    assert len(values) == 12
    ordered = sorted(values)
    low = ordered[2]
    high = ordered[9]
    capped = [low if i < 2 else high if i > 9 else value for i, value in enumerate(ordered)]
    return sum(capped) / 12.0, capped


def trimmed_mean(values: list[float]) -> float:
    ordered = sorted(values)
    return sum(ordered[2:10]) / 8.0


def main() -> int:
    cases = {
        "constant_positive": ([0.01] * 12, 1),
        "constant_negative": ([-0.01] * 12, -1),
        "symmetric_zero": ([-6.0, -5.0, -4.0, -3.0, -2.0, -1.0,
                             1.0, 2.0, 3.0, 4.0, 5.0, 6.0], 0),
        "two_outliers_each_tail": ([-5.0, -4.0] + [0.01] * 8 + [4.0, 5.0], 1),
    }
    results: dict[str, object] = {}
    for name, (values, expected_sign) in cases.items():
        mean, capped = winsorized_mean(values)
        observed_sign = 1 if mean > 0.0 else -1 if mean < 0.0 else 0
        assert observed_sign == expected_sign, (name, mean)
        assert len(capped) == 12
        assert capped[0] == capped[1] == capped[2]
        assert capped[9] == capped[10] == capped[11]
        results[name] = {"mean": mean, "sign": observed_sign}

    # Proves the new functional is not the existing middle-eight trimmed mean:
    # fixed boundary weights make the signs diverge on this ordered sample.
    distinct = [-0.20, -0.15, -0.10, 0.02, 0.02, 0.02,
                0.02, 0.02, 0.02, 0.03, 0.10, 0.20]
    winsor_mean, capped = winsorized_mean(distinct)
    trim_mean = trimmed_mean(distinct)
    assert winsor_mean < 0.0
    assert trim_mean > 0.0
    assert math.isclose(winsor_mean, -0.0075, abs_tol=1.0e-15)
    assert math.isclose(trim_mean, 0.00625, abs_tol=1.0e-15)
    assert capped == ([-0.10] * 3 + [0.02] * 6 + [0.03] * 3)
    results["boundary_weight_sign_divergence"] = {
        "winsor_mean": winsor_mean,
        "trimmed_mean": trim_mean,
        "winsor_sign": -1,
        "trimmed_sign": 1,
    }

    print(json.dumps({"status": "PASS", "cases": results}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
