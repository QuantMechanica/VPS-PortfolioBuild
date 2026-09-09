from __future__ import annotations

import itertools
import math


WEIGHTS = tuple(range(1, 13))
TOTAL = 78
BOUNDARY = 18
EPSILON = 1.0e-12


def recency_sign_score(returns: tuple[float, ...]) -> tuple[int, int]:
    assert len(returns) == 12
    assert all(math.isfinite(value) and abs(value) > EPSILON for value in returns)
    score = sum(weight * (1 if value > 0.0 else -1)
                for weight, value in zip(WEIGHTS, returns))
    direction = 1 if score >= BOUNDARY else -1 if score <= -BOUNDARY else 0
    return score, direction


def signed_magnitude_rank_score(returns: tuple[float, ...]) -> tuple[int, int]:
    ordered = sorted((abs(value), index) for index, value in enumerate(returns))
    ranks = [0] * 12
    for rank, (_, index) in enumerate(ordered, 1):
        ranks[index] = rank
    score = sum(rank * (1 if value > 0.0 else -1)
                for rank, value in zip(ranks, returns))
    direction = 1 if score >= BOUNDARY else -1 if score <= -BOUNDARY else 0
    return score, direction


def linear_magnitude_score(returns: tuple[float, ...]) -> float:
    return sum(weight * value for weight, value in zip(WEIGHTS, returns)) / TOTAL


def test_weight_contract() -> None:
    assert WEIGHTS == (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
    assert sum(WEIGHTS) == TOTAL


def test_exact_support_contract() -> None:
    counts = {-1: 0, 0: 0, 1: 0}
    for signs in itertools.product((-1.0, 1.0), repeat=12):
        score, direction = recency_sign_score(signs)
        assert -TOTAL <= score <= TOTAL
        assert (score + TOTAL) % 2 == 0
        counts[direction] += 1
    assert counts == {-1: 1062, 0: 1972, 1: 1062}


def test_boundary_is_inclusive() -> None:
    # Positive weights sum to 48, hence S=2*48-78=18.
    positive_weights = {1, 2, 3, 4, 5, 6, 7, 8, 12}
    returns = tuple(0.01 if weight in positive_weights else -0.01
                    for weight in WEIGHTS)
    assert sum(positive_weights) == 48
    assert recency_sign_score(returns) == (18, 1)
    assert recency_sign_score(tuple(-value for value in returns)) == (-18, -1)


def test_chronology_differs_from_magnitude_rank() -> None:
    # Five oldest positive signs have the largest magnitudes. Fixed recency
    # weights sell, while magnitude ranks buy.
    returns = (0.40, 0.39, 0.38, 0.37, 0.36,
               -0.01, -0.02, -0.03, -0.04,
               -0.05, -0.06, -0.07)
    assert recency_sign_score(returns) == (-48, -1)
    assert signed_magnitude_rank_score(returns) == (22, 1)


def test_sign_only_differs_from_linear_magnitude() -> None:
    # Eleven positive signs dominate the fixed sign score, while one large old
    # negative magnitude dominates the magnitude-weighted return rule.
    returns = (-10.0,) + tuple(0.01 for _ in range(11))
    assert recency_sign_score(returns) == (76, 1)
    assert linear_magnitude_score(returns) < 0.0


def test_weak_score_is_flat() -> None:
    positive_weights = {1, 2, 3, 4, 5, 6, 7, 12}  # sum=40 => S=2
    returns = tuple(0.01 if weight in positive_weights else -0.01
                    for weight in WEIGHTS)
    assert sum(positive_weights) == 40
    assert recency_sign_score(returns) == (2, 0)
