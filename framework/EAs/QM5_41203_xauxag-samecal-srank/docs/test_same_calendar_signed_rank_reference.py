#!/usr/bin/env python3
"""Deterministic reference vectors for QM5_41203 (not a backtest)."""

from __future__ import annotations

import math
import pathlib
import unittest


EPSILON = 1.0e-12


def signed_rank_score(values: list[float], minimum: int = 5) -> int:
    if not minimum <= len(values) <= 10:
        raise ValueError("sample_count")
    if any(not math.isfinite(value) or abs(value) <= EPSILON for value in values):
        raise ValueError("zero_or_invalid")
    magnitudes = [abs(value) for value in values]
    for left in range(len(magnitudes)):
        for right in range(left + 1, len(magnitudes)):
            if abs(magnitudes[left] - magnitudes[right]) <= EPSILON:
                raise ValueError("absolute_tie")

    ranks = [1 + sum(other < value for other in magnitudes) for value in magnitudes]
    total = len(values) * (len(values) + 1) // 2
    if sum(ranks) != total:
        raise AssertionError("rank_total")
    positive = sum(rank for rank, value in zip(ranks, values) if value > 0.0)
    score = 2 * positive - total
    if not -total <= score <= total:
        raise AssertionError("score_bounds")
    return score


def paired_relative_returns(xau: list[float], xag: list[float]) -> list[float]:
    if len(xau) != len(xag):
        raise ValueError("unsynchronized_sample_count")
    result = [gold - silver for gold, silver in zip(xau, xag)]
    if any(not math.isfinite(value) for value in result):
        raise ValueError("invalid_difference")
    return result


def pair_side(score: int) -> tuple[str, str] | None:
    if score > 0:
        return ("BUY_XAU", "SELL_XAG")
    if score < 0:
        return ("SELL_XAU", "BUY_XAG")
    return None


class SignedRankReferenceTests(unittest.TestCase):
    def test_disagrees_with_arithmetic_mean_neighbor(self) -> None:
        values = [0.01, 0.02, 0.03, 0.04, -0.20]
        self.assertEqual(signed_rank_score(values), 5)
        self.assertLess(sum(values) / len(values), 0.0)
        self.assertEqual(pair_side(signed_rank_score(values)), ("BUY_XAU", "SELL_XAG"))

    def test_mirror_vector_reverses_both_legs(self) -> None:
        values = [-0.01, -0.02, -0.03, -0.04, 0.20]
        self.assertEqual(signed_rank_score(values), -5)
        self.assertEqual(pair_side(signed_rank_score(values)), ("SELL_XAU", "BUY_XAG"))

    def test_larger_positive_rank_mass_can_overrule_sign_majority(self) -> None:
        values = [-0.01, -0.02, -0.03, -0.04, -0.05, -0.06, 0.07, 0.08, 0.09, 0.10]
        self.assertEqual(signed_rank_score(values), 13)
        self.assertEqual(sum(value > 0.0 for value in values), 4)

    def test_paired_difference_orientation(self) -> None:
        xau = [0.03, -0.01, 0.08, -0.02, 0.01]
        xag = [0.02, -0.03, 0.05, -0.06, 0.21]
        differences = paired_relative_returns(xau, xag)
        expected = [0.01, 0.02, 0.03, 0.04, -0.20]
        for actual, wanted in zip(differences, expected):
            self.assertAlmostEqual(actual, wanted, places=14)
        self.assertEqual(signed_rank_score(differences), 5)

    def test_epsilon_zero_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "zero_or_invalid"):
            signed_rank_score([0.01, 0.02, 0.03, 0.04, EPSILON])

    def test_absolute_tie_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "absolute_tie"):
            signed_rank_score([0.01, -0.01, 0.03, 0.04, 0.05])

    def test_sample_floor_and_cap(self) -> None:
        with self.assertRaisesRegex(ValueError, "sample_count"):
            signed_rank_score([0.01, 0.02, 0.03, 0.04])
        with self.assertRaisesRegex(ValueError, "sample_count"):
            signed_rank_score([float(index) / 100 for index in range(1, 12)])

    def test_centered_zero_stands_down(self) -> None:
        values = [0.01, -0.02, -0.03, -0.04, -0.05, 0.06, 0.07]
        self.assertEqual(signed_rank_score(values), 0)
        self.assertIsNone(pair_side(0))

    def test_source_contains_locked_contract(self) -> None:
        source = pathlib.Path(__file__).resolve().parents[1] / "QM5_41203_xauxag-samecal-srank.mq5"
        text = source.read_text(encoding="utf-8-sig")
        required = (
            "input int    qm_ea_id                    = 41203;",
            "strategy_min_observations       = 5;",
            "strategy_signal_epsilon         = 1.0e-12;",
            "score = 2 * positive_rank_sum - total_rank_sum;",
            "RISK_FIXED / 2.0",
            "QM5_41203_XAUXAG_SAMECAL_SR_ATTEMPT",
            'string g_leg_xau = "XAUUSD.DWX";',
            'input string strategy_xag_symbol            = "XAGUSD.DWX";',
        )
        for token in required:
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
