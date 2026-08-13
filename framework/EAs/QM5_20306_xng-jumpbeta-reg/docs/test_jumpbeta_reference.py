"""Independent reference checks for the QM5_20306 locked XNG jump-beta contract."""

from __future__ import annotations

import math
import unittest
from datetime import datetime, timedelta, timezone


RETURNS_PER_BLOCK = 252
RECENT_OFFSET = 252
RATE_COUNT = 505
JUMP_Z = 2.0
MIN_JUMP_DAYS = 6
BETA_TOLERANCE = 1.0e-12


def sample_stats(values: list[float]) -> tuple[float, float]:
    if len(values) < 2 or any(not math.isfinite(value) for value in values):
        raise ValueError("sample requires at least two finite values")
    mean = math.fsum(values) / len(values)
    variance = math.fsum((value - mean) ** 2 for value in values) / (
        len(values) - 1
    )
    stddev = math.sqrt(variance)
    if not math.isfinite(stddev) or stddev <= 1.0e-12:
        raise ValueError("sample standard deviation is degenerate")
    return mean, stddev


def fwl_jump_beta(y: list[float], market: list[float], jump: list[float]) -> float:
    """OLS jump coefficient via independent Frisch-Waugh-Lovell residuals."""
    if not (len(y) == len(market) == len(jump) == RETURNS_PER_BLOCK):
        raise ValueError("exactly 252 OLS rows are required")
    market_mean = math.fsum(market) / len(market)
    y_mean = math.fsum(y) / len(y)
    jump_mean = math.fsum(jump) / len(jump)
    market_ss = math.fsum((value - market_mean) ** 2 for value in market)
    if market_ss <= 1.0e-24:
        raise ValueError("market regressor is singular")
    y_market_slope = math.fsum(
        (m - market_mean) * (value - y_mean) for m, value in zip(market, y)
    ) / market_ss
    jump_market_slope = math.fsum(
        (m - market_mean) * (value - jump_mean)
        for m, value in zip(market, jump)
    ) / market_ss
    y_residual = [
        value - y_mean - y_market_slope * (m - market_mean)
        for value, m in zip(y, market)
    ]
    jump_residual = [
        value - jump_mean - jump_market_slope * (m - market_mean)
        for value, m in zip(jump, market)
    ]
    denominator = math.fsum(value * value for value in jump_residual)
    if denominator <= 1.0e-24:
        raise ValueError("jump regressor is singular")
    beta = math.fsum(
        jump_value * y_value
        for jump_value, y_value in zip(jump_residual, y_residual)
    ) / denominator
    if not math.isfinite(beta):
        raise ValueError("jump beta is nonfinite")
    return beta


def block_design(
    xti_returns: list[float], xng_returns: list[float], offset: int
) -> tuple[list[float], list[float], list[float], float, float, int]:
    if len(xti_returns) != 2 * RETURNS_PER_BLOCK:
        raise ValueError("exactly 504 WTI factor returns are required")
    if len(xng_returns) != 2 * RETURNS_PER_BLOCK:
        raise ValueError("exactly 504 gas returns are required")
    if offset not in (0, RECENT_OFFSET):
        raise ValueError("block offset is not locked")
    xti = xti_returns[offset : offset + RETURNS_PER_BLOCK]
    xng = xng_returns[offset : offset + RETURNS_PER_BLOCK]
    _, xti_std = sample_stats(xti)
    _, xng_std = sample_stats(xng)
    inverse_sum = 1.0 / xti_std + 1.0 / xng_std
    xti_weight = (1.0 / xti_std) / inverse_sum
    xng_weight = (1.0 / xng_std) / inverse_sum
    market = [
        xti_weight * xti_value + xng_weight * xng_value
        for xti_value, xng_value in zip(xti, xng)
    ]
    market_mean, market_std = sample_stats(market)
    jump = [
        value - market_mean
        if abs(value - market_mean) >= JUMP_Z * market_std
        else 0.0
        for value in market
    ]
    jump_days = sum(value != 0.0 for value in jump)
    # QM5_20306 is an XNG carrier. XTI contributes to the locked common-energy
    # factor but is never the dependent return and never receives an order.
    return xng, market, jump, xti_weight, xng_weight, jump_days


def block_beta(
    xti_returns: list[float], xng_returns: list[float], offset: int
) -> tuple[float, float, float, int]:
    y, market, jump, xti_weight, xng_weight, jump_days = block_design(
        xti_returns, xng_returns, offset
    )
    if jump_days < MIN_JUMP_DAYS:
        raise ValueError("too few realized-jump rows")
    return (
        fwl_jump_beta(y, market, jump),
        xti_weight,
        xng_weight,
        jump_days,
    )


def locked_direction(recent_beta: float, preceding_beta: float) -> int:
    difference = recent_beta - preceding_beta
    if difference < -BETA_TOLERANCE:
        return 1
    if difference > BETA_TOLERANCE:
        return -1
    return 0


def simple_returns_from_series_closes(closes_newest_first: list[float]) -> list[float]:
    if len(closes_newest_first) != RATE_COUNT:
        raise ValueError("exactly 505 completed closes are required")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes_newest_first):
        raise ValueError("closes must be positive and finite")
    total_returns = RATE_COUNT - 1
    return [
        closes_newest_first[total_returns - sample - 1]
        / closes_newest_first[total_returns - sample]
        - 1.0
        for sample in range(total_returns)
    ]


def validate_synchronized_history(
    xti_closes: list[float],
    xng_closes: list[float],
    xti_times: list[datetime],
    xng_times: list[datetime],
    decision_time: datetime,
) -> None:
    if not (
        len(xti_closes)
        == len(xng_closes)
        == len(xti_times)
        == len(xng_times)
        == RATE_COUNT
    ):
        raise ValueError("exactly 505 synchronized closes are required")
    if xti_times != xng_times:
        raise ValueError("timestamps are not synchronized")
    if any(newer <= older for newer, older in zip(xti_times, xti_times[1:])):
        raise ValueError("timestamps must be strictly older by series index")
    if xti_times[0] >= decision_time or decision_time - xti_times[0] > timedelta(days=10):
        raise ValueError("completed endpoint is invalid or stale")
    for values in (xti_closes, xng_closes):
        if any(not math.isfinite(value) or value <= 0.0 for value in values):
            raise ValueError("closes must be positive and finite")


def synthetic_block(
    xng_jump_loading: float, phase: float
) -> tuple[list[float], list[float]]:
    xti: list[float] = []
    xng: list[float] = []
    jump_indices = {18, 49, 81, 112, 144, 176, 207, 239}
    for index in range(RETURNS_PER_BLOCK):
        common = 0.0032 * math.sin(0.19 * index + phase)
        common += 0.0017 * math.cos(0.071 * index - phase)
        shock = 0.0
        if index in jump_indices:
            shock = 0.032 if (index // 30) % 2 == 0 else -0.032
        xti.append(
            0.95 * common
            + 0.62 * shock
            + 0.0007 * math.sin(0.43 * index + phase)
        )
        xng.append(
            0.78 * common
            + xng_jump_loading * shock
            + 0.0009 * math.cos(0.31 * index - phase)
        )
    return xti, xng


class JumpBetaReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.preceding = synthetic_block(0.35, 0.2)
        self.recent = synthetic_block(1.15, 1.1)
        self.xti = self.preceding[0] + self.recent[0]
        self.xng = self.preceding[1] + self.recent[1]

    def test_sample_standard_deviation_uses_n_minus_one(self) -> None:
        values = [1.0, 2.0, 4.0, 8.0]
        mean, observed = sample_stats(values)
        population = math.sqrt(math.fsum((v - mean) ** 2 for v in values) / 4)
        expected = math.sqrt(math.fsum((v - mean) ** 2 for v in values) / 3)
        self.assertAlmostEqual(observed, expected, places=14)
        self.assertNotAlmostEqual(observed, population, places=10)

    def test_each_block_has_252_rows_and_independent_weights(self) -> None:
        prior = block_beta(self.xti, self.xng, 0)
        recent = block_beta(self.xti, self.xng, RECENT_OFFSET)
        for result in (prior, recent):
            self.assertAlmostEqual(result[1] + result[2], 1.0, places=14)
            self.assertGreaterEqual(result[3], MIN_JUMP_DAYS)
        self.assertNotAlmostEqual(prior[1], recent[1], places=8)

    def test_all_rows_are_retained_and_nonjump_rows_are_zero(self) -> None:
        y, market, jump, _, _, jump_days = block_design(
            self.xti, self.xng, RECENT_OFFSET
        )
        self.assertEqual(len(y), RETURNS_PER_BLOCK)
        self.assertEqual(len(market), RETURNS_PER_BLOCK)
        self.assertEqual(len(jump), RETURNS_PER_BLOCK)
        self.assertEqual(sum(value != 0.0 for value in jump), jump_days)
        self.assertEqual(sum(value == 0.0 for value in jump), RETURNS_PER_BLOCK - jump_days)

    def test_xng_is_dependent_return_and_xti_is_factor_only(self) -> None:
        y, _, _, _, _, _ = block_design(self.xti, self.xng, RECENT_OFFSET)
        self.assertEqual(y, self.xng[RECENT_OFFSET:])
        self.assertNotEqual(y, self.xti[RECENT_OFFSET:])

    def test_low_jump_beta_is_long_and_high_jump_beta_is_short(self) -> None:
        self.assertEqual(locked_direction(-0.5, 0.1), 1)
        self.assertEqual(locked_direction(0.5, 0.1), -1)
        self.assertEqual(locked_direction(BETA_TOLERANCE, 0.0), 0)
        self.assertEqual(locked_direction(-BETA_TOLERANCE, 0.0), 0)

    def test_disjoint_blocks_reverse_direction_when_swapped(self) -> None:
        prior_beta = block_beta(self.xti, self.xng, 0)[0]
        recent_beta = block_beta(self.xti, self.xng, RECENT_OFFSET)[0]
        original = locked_direction(recent_beta, prior_beta)
        self.assertNotEqual(original, 0)
        swapped_xti = self.recent[0] + self.preceding[0]
        swapped_xng = self.recent[1] + self.preceding[1]
        swapped_prior = block_beta(swapped_xti, swapped_xng, 0)[0]
        swapped_recent = block_beta(swapped_xti, swapped_xng, RECENT_OFFSET)[0]
        self.assertAlmostEqual(swapped_prior, recent_beta, places=11)
        self.assertAlmostEqual(swapped_recent, prior_beta, places=11)
        self.assertEqual(locked_direction(swapped_recent, swapped_prior), -original)

    def test_minimum_jump_guard_rejects_smooth_blocks(self) -> None:
        smooth_xti = [0.001 * math.sin(index * 0.17) for index in range(504)]
        smooth_xng = [0.001 * math.cos(index * 0.13) for index in range(504)]
        _, _, _, _, _, jump_days = block_design(smooth_xti, smooth_xng, 0)
        if jump_days < MIN_JUMP_DAYS:
            with self.assertRaisesRegex(ValueError, "too few"):
                block_beta(smooth_xti, smooth_xng, 0)
        else:
            self.assertGreaterEqual(jump_days, MIN_JUMP_DAYS)

    def test_chronological_mapping_and_history_guards(self) -> None:
        chronological = [0.0001 * math.sin(index) for index in range(RATE_COUNT - 1)]
        chronological_closes = [100.0]
        for value in chronological:
            chronological_closes.append(chronological_closes[-1] * (1.0 + value))
        newest_first = list(reversed(chronological_closes))
        observed = simple_returns_from_series_closes(newest_first)
        for left, right in zip(observed, chronological):
            self.assertAlmostEqual(left, right, places=14)

        newest = datetime(2026, 7, 31, tzinfo=timezone.utc)
        times = [newest - timedelta(days=index) for index in range(RATE_COUNT)]
        xng_closes = [value * 0.04 for value in newest_first]
        validate_synchronized_history(
            newest_first, xng_closes, times, list(times), newest + timedelta(days=3)
        )
        misaligned = list(times)
        misaligned[200] -= timedelta(hours=1)
        with self.assertRaisesRegex(ValueError, "not synchronized"):
            validate_synchronized_history(
                newest_first, xng_closes, times, misaligned, newest + timedelta(days=3)
            )
        with self.assertRaisesRegex(ValueError, "stale"):
            validate_synchronized_history(
                newest_first, xng_closes, times, list(times), newest + timedelta(days=11)
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
