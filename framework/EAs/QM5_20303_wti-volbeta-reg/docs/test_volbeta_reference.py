"""Independent reference checks for the QM5_20303 locked beta contract."""

from __future__ import annotations

import math
import unittest
from datetime import datetime, timedelta, timezone


RETURNS_PER_BLOCK = 272
OLS_OBSERVATIONS = 252
RECENT_OFFSET = 272
RATE_COUNT = 545
RV_WINDOW = 20
JUMP_Z = 2.0
MIN_SMOOTH_DAYS = 200
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


def rolling_sample_std(values: list[float], end: int, window: int = RV_WINDOW) -> float:
    first = end - window + 1
    if first < 0 or end >= len(values) or window < 2:
        raise ValueError("rolling window is out of bounds")
    return sample_stats(values[first : end + 1])[1]


def fwl_smooth_beta(y: list[float], market: list[float], smooth: list[float]) -> float:
    """OLS smooth coefficient via independent Frisch-Waugh-Lovell residuals."""
    if not (len(y) == len(market) == len(smooth) == OLS_OBSERVATIONS):
        raise ValueError("exactly 252 OLS rows are required")
    market_mean = math.fsum(market) / len(market)
    y_mean = math.fsum(y) / len(y)
    smooth_mean = math.fsum(smooth) / len(smooth)
    market_ss = math.fsum((value - market_mean) ** 2 for value in market)
    if market_ss <= 1.0e-24:
        raise ValueError("market regressor is singular")
    y_market_slope = math.fsum(
        (m - market_mean) * (value - y_mean) for m, value in zip(market, y)
    ) / market_ss
    smooth_market_slope = math.fsum(
        (m - market_mean) * (value - smooth_mean)
        for m, value in zip(market, smooth)
    ) / market_ss
    y_residual = [
        value - y_mean - y_market_slope * (m - market_mean)
        for value, m in zip(y, market)
    ]
    smooth_residual = [
        value - smooth_mean - smooth_market_slope * (m - market_mean)
        for value, m in zip(smooth, market)
    ]
    denominator = math.fsum(value * value for value in smooth_residual)
    if denominator <= 1.0e-24:
        raise ValueError("smooth regressor is singular")
    beta = math.fsum(
        smooth_value * y_value
        for smooth_value, y_value in zip(smooth_residual, y_residual)
    ) / denominator
    if not math.isfinite(beta):
        raise ValueError("smooth beta is nonfinite")
    return beta


def block_design(
    xti_returns: list[float], xng_returns: list[float], offset: int
) -> tuple[list[float], list[float], list[float], float, float, int]:
    if len(xti_returns) != 2 * RETURNS_PER_BLOCK:
        raise ValueError("exactly 544 WTI returns are required")
    if len(xng_returns) != 2 * RETURNS_PER_BLOCK:
        raise ValueError("exactly 544 gas returns are required")
    if offset not in (0, RECENT_OFFSET):
        raise ValueError("block offset is not locked")
    xti = xti_returns[offset : offset + RETURNS_PER_BLOCK]
    xng = xng_returns[offset : offset + RETURNS_PER_BLOCK]
    _, xti_std = sample_stats(xti[RV_WINDOW:])
    _, xng_std = sample_stats(xng[RV_WINDOW:])
    inverse_sum = 1.0 / xti_std + 1.0 / xng_std
    xti_weight = (1.0 / xti_std) / inverse_sum
    xng_weight = (1.0 / xng_std) / inverse_sum
    market = [
        xti_weight * xti_value + xng_weight * xng_value
        for xti_value, xng_value in zip(xti, xng)
    ]
    market_mean, market_std = sample_stats(market[RV_WINDOW:])
    smooth: list[float] = []
    y: list[float] = []
    market_rows: list[float] = []
    smooth_days = 0
    for index in range(RV_WINDOW, RETURNS_PER_BLOCK):
        current_rv = rolling_sample_std(market, index)
        previous_rv = rolling_sample_std(market, index - 1)
        jump = abs(market[index] - market_mean) >= JUMP_Z * market_std
        smooth.append(0.0 if jump else current_rv - previous_rv)
        smooth_days += int(not jump)
        y.append(xti[index])
        market_rows.append(market[index])
    if len(y) != OLS_OBSERVATIONS:
        raise ValueError("wrong OLS row count")
    return y, market_rows, smooth, xti_weight, xng_weight, smooth_days


def block_beta(
    xti_returns: list[float], xng_returns: list[float], offset: int
) -> tuple[float, float, float, int]:
    y, market, smooth, xti_weight, xng_weight, smooth_days = block_design(
        xti_returns, xng_returns, offset
    )
    if smooth_days < MIN_SMOOTH_DAYS:
        raise ValueError("too few non-jump rows")
    return (
        fwl_smooth_beta(y, market, smooth),
        xti_weight,
        xng_weight,
        smooth_days,
    )


def locked_direction(recent_beta: float, preceding_beta: float) -> int:
    difference = recent_beta - preceding_beta
    if difference > BETA_TOLERANCE:
        return 1
    if difference < -BETA_TOLERANCE:
        return -1
    return 0


def simple_returns_from_series_closes(closes_newest_first: list[float]) -> list[float]:
    if len(closes_newest_first) != RATE_COUNT:
        raise ValueError("exactly 545 completed closes are required")
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
        raise ValueError("exactly 545 synchronized closes are required")
    if xti_times != xng_times:
        raise ValueError("timestamps are not synchronized")
    if any(newer <= older for newer, older in zip(xti_times, xti_times[1:])):
        raise ValueError("timestamps must be strictly older by series index")
    if xti_times[0] >= decision_time or decision_time - xti_times[0] > timedelta(days=10):
        raise ValueError("completed endpoint is invalid or stale")
    for values in (xti_closes, xng_closes):
        if any(not math.isfinite(value) or value <= 0.0 for value in values):
            raise ValueError("closes must be positive and finite")


def synthetic_block(phase: float, modulation: float) -> tuple[list[float], list[float]]:
    xti: list[float] = []
    xng: list[float] = []
    for index in range(RETURNS_PER_BLOCK):
        carrier = 0.0040 * math.sin(0.19 * index + phase)
        carrier += 0.0021 * math.cos(0.071 * index - 0.5 * phase)
        amplitude = 1.0 + modulation * math.sin(0.037 * index + phase)
        xti.append(amplitude * carrier + 0.0008 * math.sin(0.43 * index + phase))
        xng.append(0.82 * amplitude * carrier + 0.0011 * math.cos(0.31 * index - phase))
    return xti, xng


class VolBetaReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.block_a = synthetic_block(0.2, 0.18)
        self.block_b = synthetic_block(1.1, 0.52)
        self.xti = self.block_a[0] + self.block_b[0]
        self.xng = self.block_a[1] + self.block_b[1]

    def test_sample_standard_deviation_uses_n_minus_one(self) -> None:
        mean, observed = sample_stats([1.0, 2.0, 4.0, 8.0])
        population = math.sqrt(math.fsum((value - mean) ** 2 for value in [1, 2, 4, 8]) / 4)
        expected = math.sqrt(math.fsum((value - mean) ** 2 for value in [1, 2, 4, 8]) / 3)
        self.assertAlmostEqual(observed, expected, places=14)
        self.assertNotAlmostEqual(observed, population, places=10)

    def test_each_block_has_252_rows_and_independent_inverse_vol_weights(self) -> None:
        prior = block_beta(self.xti, self.xng, 0)
        recent = block_beta(self.xti, self.xng, RECENT_OFFSET)
        for result in (prior, recent):
            self.assertAlmostEqual(result[1] + result[2], 1.0, places=14)
            self.assertGreaterEqual(result[3], MIN_SMOOTH_DAYS)
        self.assertNotAlmostEqual(prior[1], recent[1], places=8)

    def test_blocks_are_return_disjoint_and_direction_reverses_when_swapped(self) -> None:
        prior_beta = block_beta(self.xti, self.xng, 0)[0]
        recent_beta = block_beta(self.xti, self.xng, RECENT_OFFSET)[0]
        self.assertGreater(abs(recent_beta - prior_beta), BETA_TOLERANCE)
        original_direction = locked_direction(recent_beta, prior_beta)
        swapped_xti = self.block_b[0] + self.block_a[0]
        swapped_xng = self.block_b[1] + self.block_a[1]
        swapped_prior = block_beta(swapped_xti, swapped_xng, 0)[0]
        swapped_recent = block_beta(swapped_xti, swapped_xng, RECENT_OFFSET)[0]
        self.assertAlmostEqual(swapped_prior, recent_beta, places=11)
        self.assertAlmostEqual(swapped_recent, prior_beta, places=11)
        self.assertEqual(locked_direction(swapped_recent, swapped_prior), -original_direction)

    def test_jump_rows_are_retained_with_zero_smooth_innovation(self) -> None:
        xti = list(self.xti)
        xng = list(self.xng)
        jump_index = RECENT_OFFSET + 170
        xti[jump_index] = 0.25
        xng[jump_index] = 0.25
        _, _, smooth, _, _, smooth_days = block_design(xti, xng, RECENT_OFFSET)
        self.assertEqual(len(smooth), OLS_OBSERVATIONS)
        self.assertEqual(smooth[jump_index - RECENT_OFFSET - RV_WINDOW], 0.0)
        self.assertLess(smooth_days, OLS_OBSERVATIONS)
        self.assertGreaterEqual(smooth_days, MIN_SMOOTH_DAYS)

    def test_tolerance_band_is_symmetric_and_flat(self) -> None:
        self.assertEqual(locked_direction(BETA_TOLERANCE, 0.0), 0)
        self.assertEqual(locked_direction(-BETA_TOLERANCE, 0.0), 0)
        self.assertEqual(locked_direction(2.0 * BETA_TOLERANCE, 0.0), 1)
        self.assertEqual(locked_direction(-2.0 * BETA_TOLERANCE, 0.0), -1)

    def test_chronological_simple_return_mapping_and_history_guards(self) -> None:
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
