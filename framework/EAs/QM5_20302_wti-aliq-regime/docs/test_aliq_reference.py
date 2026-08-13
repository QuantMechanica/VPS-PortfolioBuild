"""Independent reference checks for the QM5_20302 locked ALIQ contract."""

from __future__ import annotations

import math
import unittest
from datetime import datetime, timedelta, timezone


RETURNS_PER_BLOCK = 252
PRIOR_OFFSET = 252
RATE_COUNT = 505
ALIQ_SCALE = 1_000_000.0
TOLERANCE = 1.0e-12


def closes_from_log_returns(log_returns_newest_first: list[float]) -> list[float]:
    if len(log_returns_newest_first) != RATE_COUNT - 1:
        raise ValueError("exactly 504 log returns are required")
    closes = [100.0]
    for value in log_returns_newest_first:
        if not math.isfinite(value):
            raise ValueError("log returns must be finite")
        closes.append(closes[-1] / math.exp(value))
    return closes


def aliq_block(
    closes_newest_first: list[float],
    tick_volumes_newest_first: list[int],
    block_offset: int,
) -> float:
    if len(closes_newest_first) != RATE_COUNT:
        raise ValueError("exactly 505 completed closes are required")
    if len(tick_volumes_newest_first) != RATE_COUNT:
        raise ValueError("exactly 505 completed tick volumes are required")
    if block_offset not in (0, PRIOR_OFFSET):
        raise ValueError("block offset is not locked")
    if block_offset + RETURNS_PER_BLOCK >= len(closes_newest_first):
        raise ValueError("block support exceeds completed history")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes_newest_first):
        raise ValueError("closes must be positive and finite")

    terms: list[float] = []
    for index in range(RETURNS_PER_BLOCK):
        rate_index = block_offset + index
        volume = tick_volumes_newest_first[rate_index]
        if volume <= 0:
            raise ValueError("same-bar tick volume must be positive")
        log_return = math.log(
            closes_newest_first[rate_index]
            / closes_newest_first[rate_index + 1]
        )
        term = abs(log_return) / volume * ALIQ_SCALE
        if not math.isfinite(term) or term < 0.0:
            raise ValueError("ALIQ term must be finite and nonnegative")
        terms.append(term)
    if len(terms) != RETURNS_PER_BLOCK:
        raise ValueError("exactly 252 ALIQ terms are required")
    return math.fsum(terms) / RETURNS_PER_BLOCK


def locked_direction(recent_aliq: float, preceding_aliq: float) -> int:
    difference = recent_aliq - preceding_aliq
    if difference > TOLERANCE:
        return 1
    if difference < -TOLERANCE:
        return -1
    return 0


def validate_completed_history(
    closes_newest_first: list[float],
    tick_volumes_newest_first: list[int],
    times_newest_first: list[datetime],
    decision_time: datetime,
) -> None:
    if (
        len(closes_newest_first) != RATE_COUNT
        or len(tick_volumes_newest_first) != RATE_COUNT
        or len(times_newest_first) != RATE_COUNT
    ):
        raise ValueError("exactly 505 completed rates are required")
    if any(
        newer <= older
        for newer, older in zip(times_newest_first, times_newest_first[1:])
    ):
        raise ValueError("timestamps must be strictly older by series index")
    newest = times_newest_first[0]
    if newest >= decision_time or decision_time - newest > timedelta(days=10):
        raise ValueError("completed endpoint is invalid or stale")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes_newest_first):
        raise ValueError("closes must be positive and finite")
    if any(value <= 0 for value in tick_volumes_newest_first[: RATE_COUNT - 1]):
        raise ValueError("used tick volumes must be positive")


def state_block(amplitude: float) -> list[float]:
    return [amplitude * (1.0 if index % 2 == 0 else -1.0) for index in range(252)]


class AliqReferenceTest(unittest.TestCase):
    def test_exact_log_return_same_bar_volume_mean(self) -> None:
        returns = state_block(0.010) + state_block(0.004)
        closes = closes_from_log_returns(returns)
        volumes = [100 + index % 17 for index in range(RATE_COUNT)]
        expected = math.fsum(
            abs(returns[index]) / volumes[index] * ALIQ_SCALE
            for index in range(RETURNS_PER_BLOCK)
        ) / RETURNS_PER_BLOCK
        observed = aliq_block(closes, volumes, 0)
        wrong_previous_volume = math.fsum(
            abs(returns[index]) / volumes[index + 1] * ALIQ_SCALE
            for index in range(RETURNS_PER_BLOCK)
        ) / RETURNS_PER_BLOCK
        simple_return_proxy = math.fsum(
            abs(math.expm1(returns[index])) / volumes[index] * ALIQ_SCALE
            for index in range(RETURNS_PER_BLOCK)
        ) / RETURNS_PER_BLOCK
        self.assertAlmostEqual(observed, expected, places=10)
        self.assertNotAlmostEqual(observed, wrong_previous_volume, places=6)
        self.assertNotAlmostEqual(observed, simple_return_proxy, places=6)

    def test_high_recent_aliq_maps_long_and_low_recent_maps_short(self) -> None:
        volumes = [100] * RATE_COUNT
        high_recent = closes_from_log_returns(state_block(0.012) + state_block(0.004))
        recent = aliq_block(high_recent, volumes, 0)
        preceding = aliq_block(high_recent, volumes, PRIOR_OFFSET)
        self.assertGreater(recent, preceding)
        self.assertEqual(locked_direction(recent, preceding), 1)

        low_recent = closes_from_log_returns(state_block(0.004) + state_block(0.012))
        recent = aliq_block(low_recent, volumes, 0)
        preceding = aliq_block(low_recent, volumes, PRIOR_OFFSET)
        self.assertLess(recent, preceding)
        self.assertEqual(locked_direction(recent, preceding), -1)

    def test_equal_blocks_and_tolerance_are_flat(self) -> None:
        block = state_block(0.007)
        closes = closes_from_log_returns(block + block)
        volumes = [125] * RATE_COUNT
        recent = aliq_block(closes, volumes, 0)
        preceding = aliq_block(closes, volumes, PRIOR_OFFSET)
        self.assertAlmostEqual(recent, preceding, places=12)
        self.assertEqual(locked_direction(recent, preceding), 0)
        self.assertEqual(locked_direction(TOLERANCE, 0.0), 0)
        self.assertEqual(locked_direction(-TOLERANCE, 0.0), 0)

    def test_blocks_have_disjoint_return_and_volume_support(self) -> None:
        recent_indices = set(range(0, RETURNS_PER_BLOCK))
        preceding_indices = set(range(PRIOR_OFFSET, PRIOR_OFFSET + RETURNS_PER_BLOCK))
        recent_closes = set(range(0, RETURNS_PER_BLOCK + 1))
        preceding_closes = set(range(PRIOR_OFFSET, PRIOR_OFFSET + RETURNS_PER_BLOCK + 1))
        self.assertFalse(recent_indices & preceding_indices)
        self.assertEqual(recent_closes & preceding_closes, {252})

        returns = state_block(0.010) + state_block(0.004)
        closes = closes_from_log_returns(returns)
        volumes = [100] * RATE_COUNT
        recent_0 = aliq_block(closes, volumes, 0)
        preceding_0 = aliq_block(closes, volumes, PRIOR_OFFSET)

        recent_volumes = list(volumes)
        recent_volumes[250] = 1_000
        self.assertNotAlmostEqual(recent_0, aliq_block(closes, recent_volumes, 0), places=10)
        self.assertAlmostEqual(preceding_0, aliq_block(closes, recent_volumes, PRIOR_OFFSET), places=12)

        prior_volumes = list(volumes)
        prior_volumes[502] = 1_000
        self.assertAlmostEqual(recent_0, aliq_block(closes, prior_volumes, 0), places=12)
        self.assertNotAlmostEqual(preceding_0, aliq_block(closes, prior_volumes, PRIOR_OFFSET), places=10)

    def test_price_scale_invariant_and_volume_scale_inverse(self) -> None:
        closes = closes_from_log_returns(state_block(0.010) + state_block(0.004))
        volumes = [100 + index % 9 for index in range(RATE_COUNT)]
        scaled_prices = [value * 17.0 for value in closes]
        scaled_volumes = [value * 2 for value in volumes]
        for offset in (0, PRIOR_OFFSET):
            base = aliq_block(closes, volumes, offset)
            self.assertAlmostEqual(base, aliq_block(scaled_prices, volumes, offset), places=10)
            self.assertAlmostEqual(base / 2.0, aliq_block(closes, scaled_volumes, offset), places=10)

    def test_count_volume_chronology_and_freshness_fail_closed(self) -> None:
        closes = closes_from_log_returns(state_block(0.010) + state_block(0.004))
        volumes = [100] * RATE_COUNT
        newest = datetime(2026, 1, 30, tzinfo=timezone.utc)
        times = [newest - timedelta(days=index) for index in range(RATE_COUNT)]
        validate_completed_history(closes, volumes, times, newest + timedelta(days=1))
        with self.assertRaisesRegex(ValueError, "505"):
            aliq_block(closes[:-1], volumes, 0)
        bad_volumes = list(volumes)
        bad_volumes[17] = 0
        with self.assertRaisesRegex(ValueError, "positive"):
            aliq_block(closes, bad_volumes, 0)
        bad_times = list(times)
        bad_times[100] = bad_times[99]
        with self.assertRaisesRegex(ValueError, "strictly older"):
            validate_completed_history(closes, volumes, bad_times, newest + timedelta(days=1))
        with self.assertRaisesRegex(ValueError, "stale"):
            validate_completed_history(closes, volumes, times, newest + timedelta(days=11))


if __name__ == "__main__":
    unittest.main(verbosity=2)
