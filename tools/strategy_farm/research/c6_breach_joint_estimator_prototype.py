#!/usr/bin/env python3
"""Read-only C-6 method prototype on synthetic, flat-boundary day capsules.

This is deliberately not imported by the FTMO decision engine.  It demonstrates
the proposed worst-of moving-block-percentile and exact-binomial confidence
construction; it neither reads farm state nor changes a gate.
"""

from __future__ import annotations

import argparse
import json
import math
import random
from dataclasses import dataclass
from typing import Iterable, Sequence


ALPHA = 0.05
BLOCK_DAYS = 60


@dataclass(frozen=True)
class DayCapsule:
    balance_delta: float
    minimum_equity_delta: float
    trade_count: int = 1
    flat_at_end: bool = True


@dataclass(frozen=True)
class PathOutcome:
    p1_pass: bool
    p2_pass_given_p1: bool
    joint_pass: bool
    official_breach: bool


def percentile(values: Sequence[float], probability: float) -> float:
    if not values:
        raise ValueError("percentile requires values")
    ordered = sorted(values)
    position = (len(ordered) - 1) * probability
    lo = int(math.floor(position))
    hi = int(math.ceil(position))
    if lo == hi:
        return ordered[lo]
    weight = position - lo
    return ordered[lo] * (1.0 - weight) + ordered[hi] * weight


def _binomial_cdf(k: int, n: int, p: float) -> float:
    if k < 0:
        return 0.0
    if k >= n:
        return 1.0
    return sum(
        math.comb(n, i) * p**i * (1.0 - p) ** (n - i)
        for i in range(k + 1)
    )


def clopper_pearson_upper(k: int, n: int, tail_alpha: float) -> float:
    """One-sided exact upper bound: P_p[X <= k] = tail_alpha."""
    if not 0 <= k <= n or n <= 0:
        raise ValueError("invalid binomial count")
    if k == n:
        return 1.0
    lo, hi = 0.0, 1.0
    for _ in range(100):
        mid = (lo + hi) / 2.0
        if _binomial_cdf(k, n, mid) > tail_alpha:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2.0


def clopper_pearson_lower(k: int, n: int, tail_alpha: float) -> float:
    """One-sided exact lower bound: P_p[X >= k] = tail_alpha."""
    if not 0 <= k <= n or n <= 0:
        raise ValueError("invalid binomial count")
    if k == 0:
        return 0.0
    lo, hi = 0.0, 1.0
    for _ in range(100):
        mid = (lo + hi) / 2.0
        survival = 1.0 - _binomial_cdf(k - 1, n, mid)
        if survival < tail_alpha:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2.0


def _phase(
    days: Sequence[DayCapsule],
    start: int,
    horizon: int,
    target: float,
) -> tuple[str, int | None]:
    balance = 1.0
    opened_days = 0
    for offset, day in enumerate(days[start : start + horizon]):
        daily_floor = balance - 0.05
        minimum_equity = balance + day.minimum_equity_delta
        if minimum_equity < 0.90 or minimum_equity < daily_floor:
            return "BREACH", start + offset
        balance += day.balance_delta
        opened_days += day.trade_count > 0
        if balance > 1.0 + target and day.flat_at_end and opened_days >= 4:
            return "PASS", start + offset
    return "TIMEOUT", None


def evaluate_gauntlet(days: Sequence[DayCapsule], start: int) -> PathOutcome:
    if start < 0 or start + 90 > len(days):
        raise ValueError("gauntlet must have a complete 90-day observation horizon")
    p1, p1_end = _phase(days, start, 60, 0.10)
    if p1 == "BREACH":
        return PathOutcome(False, False, False, True)
    if p1 != "PASS":
        return PathOutcome(False, False, False, False)
    assert p1_end is not None
    p2_start = p1_end + 1
    p2, _ = _phase(days, p2_start, min(30, start + 90 - p2_start), 0.05)
    return PathOutcome(True, p2 == "PASS", p2 == "PASS", p2 == "BREACH")


def moving_block_resample(
    days: Sequence[DayCapsule], rng: random.Random, block_days: int = BLOCK_DAYS
) -> list[DayCapsule]:
    if len(days) < block_days:
        raise ValueError("source shorter than block")
    if not all(day.flat_at_end for day in days):
        raise ValueError("prototype requires flat-boundary capsules")
    output: list[DayCapsule] = []
    while len(output) < len(days):
        start = rng.randrange(0, len(days) - block_days + 1)
        output.extend(days[start : start + block_days])
    return output[: len(days)]


def _rates(outcomes: Iterable[PathOutcome]) -> dict[str, float | int]:
    rows = list(outcomes)
    if not rows:
        raise ValueError("no complete gauntlets")
    p1 = sum(row.p1_pass for row in rows)
    joint = sum(row.joint_pass for row in rows)
    breach = sum(row.official_breach for row in rows)
    return {
        "n": len(rows),
        "p1_count": p1,
        "joint_count": joint,
        "breach_count": breach,
        "p1": p1 / len(rows),
        # Empty P1 denominator is fail-closed, never dropped from a replicate.
        "p2_conditional": joint / p1 if p1 else 0.0,
        "joint": joint / len(rows),
        "breach": breach / len(rows),
    }


def estimate(
    days: Sequence[DayCapsule], *, replicates: int = 250, seed: int = 20260802
) -> dict[str, object]:
    if len(days) < 90 or replicates < 100:
        raise ValueError("prototype requires D>=90 and at least 100 replicates")
    rng = random.Random(seed)
    bootstrap: list[dict[str, float | int]] = []
    for _ in range(replicates):
        sampled = moving_block_resample(days, rng)
        replicate = _rates(
            evaluate_gauntlet(sampled, start) for start in range(len(sampled) - 89)
        )
        if int(replicate["p1_count"]):
            assert math.isclose(
                float(replicate["joint"]),
                float(replicate["p1"]) * float(replicate["p2_conditional"]),
                rel_tol=0.0,
                abs_tol=1e-15,
            )
        bootstrap.append(replicate)

    # Fixed-origin non-overlapping gauntlets are the finite-sample guard.  The
    # origin is sealed; it is not selected after observing outcomes.
    disjoint = [evaluate_gauntlet(days, start) for start in range(0, len(days) - 89, 90)]
    exact = _rates(disjoint)
    tail = ALPHA / 2.0
    mbb = {
        "p1_lower": percentile([float(row["p1"]) for row in bootstrap], tail),
        "breach_upper": percentile(
            [float(row["breach"]) for row in bootstrap], 1.0 - tail
        ),
        "p2_conditional_lower": percentile(
            [float(row["p2_conditional"]) for row in bootstrap], tail
        ),
        "joint_lower": percentile([float(row["joint"]) for row in bootstrap], tail),
    }
    exact_bounds = {
        "p1_lower": clopper_pearson_lower(
            int(exact["p1_count"]), int(exact["n"]), tail
        ),
        "breach_upper": clopper_pearson_upper(
            int(exact["breach_count"]), int(exact["n"]), tail
        ),
        "p2_conditional_lower": (
            clopper_pearson_lower(
                int(exact["joint_count"]), int(exact["p1_count"]), tail
            )
            if int(exact["p1_count"]) else 0.0
        ),
        "joint_lower": clopper_pearson_lower(
            int(exact["joint_count"]), int(exact["n"]), tail
        ),
    }
    credited = {
        "p1_lower": min(mbb["p1_lower"], exact_bounds["p1_lower"]),
        "breach_upper": max(mbb["breach_upper"], exact_bounds["breach_upper"]),
        "p2_conditional_lower": min(
            mbb["p2_conditional_lower"], exact_bounds["p2_conditional_lower"]
        ),
        "joint_lower": min(mbb["joint_lower"], exact_bounds["joint_lower"]),
    }
    return {
        "method": "PROTOTYPE_HYBRID_WORST_OF_MBB_PERCENTILE_AND_FIXED_ORIGIN_CP",
        "decision_eligible": False,
        "days": len(days),
        "block_days": BLOCK_DAYS,
        "replicates": replicates,
        "seed": seed,
        "complete_rolling_gauntlets_per_replicate": len(days) - 89,
        "disjoint": exact,
        "mbb_bounds": mbb,
        "exact_bounds": exact_bounds,
        "credited_bounds": credited,
        "identity_check": "joint == p1 * p2_conditional in every replicate",
    }


def synthetic_days(kind: str, count: int = 540) -> list[DayCapsule]:
    if kind == "safe":
        return [DayCapsule(0.0022, -0.0010) for _ in range(count)]
    if kind == "hazard":
        return [
            DayCapsule(0.0018, -0.055 if index % 23 == 11 else -0.002)
            for index in range(count)
        ]
    if kind == "no_p1":
        return [DayCapsule(0.0, -0.001) for _ in range(count)]
    raise ValueError(f"unknown synthetic fixture: {kind}")


def self_test() -> dict[str, object]:
    # With zero breaches, 36 independent Bernoulli units are the first n whose
    # two-sided-95 upper endpoint can clear 0.10.
    assert clopper_pearson_upper(0, 35, 0.025) > 0.10
    assert clopper_pearson_upper(0, 36, 0.025) <= 0.10
    assert clopper_pearson_lower(23, 23, 0.025) >= 0.85
    assert clopper_pearson_lower(22, 22, 0.025) < 0.85
    assert clopper_pearson_lower(9, 9, 0.025) >= 0.65
    assert clopper_pearson_lower(8, 8, 0.025) < 0.65

    safe = estimate(synthetic_days("safe"), replicates=120)
    hazard = estimate(synthetic_days("hazard"), replicates=120)
    no_p1 = estimate(synthetic_days("no_p1"), replicates=120)
    assert float(safe["credited_bounds"]["breach_upper"]) > 0.10
    assert float(hazard["credited_bounds"]["breach_upper"]) > float(
        safe["credited_bounds"]["breach_upper"]
    )
    assert safe["credited_bounds"]["joint_lower"] > hazard["credited_bounds"]["joint_lower"]
    assert no_p1["credited_bounds"]["p2_conditional_lower"] == 0.0
    return {
        "status": "PASS",
        "fixtures": {"safe_short": safe, "hazard": hazard, "no_p1": no_p1},
        "derived_feasibility_floors": {
            "zero_breach_disjoint_90d_gauntlets": 36,
            "all_success_p2_conditional_denominator": 23,
            "all_success_joint_disjoint_90d_gauntlets": 9,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--fixture", choices=("safe", "hazard", "no_p1"), default="safe")
    parser.add_argument("--days", type=int, default=540)
    parser.add_argument("--replicates", type=int, default=250)
    args = parser.parse_args()
    result = self_test() if args.self_test else estimate(
        synthetic_days(args.fixture, args.days), replicates=args.replicates
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
