"""Pure reference fixtures for QM5_41280 card arithmetic and sequencing."""

from __future__ import annotations

from itertools import combinations
from pathlib import Path

import pytest


ENDPOINTS = 12
BLOCK = 6
U_LOWER = 12
U_UPPER = 24


def mann_whitney_signal(closes: list[float]) -> tuple[int, int, int, int]:
    if len(closes) != ENDPOINTS:
        raise ValueError("endpoint_count")
    if any(value <= 0 for value in closes):
        raise ValueError("nonpositive")
    if len(set(closes)) != ENDPOINTS:
        raise ValueError("tie")

    older = closes[:BLOCK]
    newer = closes[BLOCK:]
    u_new = sum(new > old for new in newer for old in older)
    u_old = sum(old > new for new in newer for old in older)
    newer_rank_sum = sum(
        1 + sum(other < new for other in closes) for new in newer
    )
    assert u_new + u_old == BLOCK * BLOCK
    assert newer_rank_sum - BLOCK * (BLOCK + 1) // 2 == u_new
    direction = 1 if u_new >= U_UPPER else -1 if u_new <= U_LOWER else 0
    return u_new, u_old, newer_rank_sum, direction


def fixture_from_newer_ranks(newer_ranks: list[int]) -> list[float]:
    assert len(newer_ranks) == BLOCK
    older_ranks = [rank for rank in range(1, ENDPOINTS + 1) if rank not in newer_ranks]
    return [float(rank) for rank in older_ranks + newer_ranks]


def test_extremes_and_inclusive_boundaries() -> None:
    assert mann_whitney_signal([*map(float, range(1, 7)), *map(float, range(7, 13))])[
        :2
    ] == (36, 0)
    assert mann_whitney_signal([*map(float, range(7, 13)), *map(float, range(1, 7))])[
        :2
    ] == (0, 36)

    upper = mann_whitney_signal(fixture_from_newer_ranks([2, 5, 8, 9, 10, 11]))
    lower = mann_whitney_signal(fixture_from_newer_ranks([1, 2, 3, 8, 9, 10]))
    assert upper == (24, 12, 45, 1)
    assert lower == (12, 24, 33, -1)


def test_central_state_is_flat() -> None:
    observed = mann_whitney_signal(
        fixture_from_newer_ranks([1, 4, 7, 8, 9, 10])
    )
    assert observed == (18, 18, 39, 0)


def test_ties_fail_closed() -> None:
    with pytest.raises(ValueError, match="tie"):
        mann_whitney_signal([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 6.0, 8.0, 9.0, 10.0, 11.0, 12.0])


def test_within_block_permutations_do_not_change_u() -> None:
    closes = fixture_from_newer_ranks([2, 5, 8, 9, 10, 11])
    permuted = [*reversed(closes[:BLOCK]), *reversed(closes[BLOCK:])]
    assert mann_whitney_signal(closes) == mann_whitney_signal(permuted)


def test_reflection_complements_u_and_direction() -> None:
    closes = fixture_from_newer_ranks([2, 5, 8, 9, 10, 11])
    reflected = [14.0 - value for value in closes]
    original = mann_whitney_signal(closes)
    mirror = mann_whitney_signal(reflected)
    assert mirror[0] == original[1]
    assert mirror[1] == original[0]
    assert mirror[3] == -original[3]


def test_exact_assignment_density_is_924_with_182_per_tail() -> None:
    u_values = [
        sum(newer_ranks) - BLOCK * (BLOCK + 1) // 2
        for newer_ranks in combinations(range(1, ENDPOINTS + 1), BLOCK)
    ]
    assert len(u_values) == 924
    assert sum(value >= U_UPPER for value in u_values) == 182
    assert sum(value <= U_LOWER for value in u_values) == 182
    assert sum(value >= U_UPPER or value <= U_LOWER for value in u_values) == 364


def test_mq5_binds_completed_bars_and_consumes_before_fallible_gates() -> None:
    source = Path(__file__).parents[1] / "QM5_41280_usdchf-ww-shift-tr.mq5"
    text = source.read_text(encoding="utf-8")

    assert "const int shift = strategy_endpoint_count - index;" in text
    assert "!QM_ReadBar(g_symbol, PERIOD_D1, shift, bar)" in text
    assert "closes[left] == closes[right]" in text
    assert "metrics.u_new + metrics.u_old != pair_count" in text
    assert "metrics.newer_rank_sum - minimum_rank_sum != metrics.u_new" in text

    consumed = text.index("if(!Strategy_RecordWeekAttempt(current_week_key))")
    history = text.index("if(Strategy_WeekAlreadyEntered(current_week_key))")
    endpoints = text.index("Strategy_LoadCompletedCloses(closes, endpoint_times)")
    assert consumed < history < endpoints

