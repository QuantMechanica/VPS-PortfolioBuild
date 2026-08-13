"""Independent reference checks for the QM5_20301 locked ES contract."""

from __future__ import annotations

import math
import unittest
from datetime import datetime, timedelta, timezone


RETURNS_PER_BLOCK = 252
TAIL_PROBABILITY = 0.05
TAIL_COUNT = math.ceil(RETURNS_PER_BLOCK * TAIL_PROBABILITY)
PRIOR_OFFSET = 252
CLOSE_COUNT = 505
TOLERANCE = 1.0e-12


def closes_from_simple_returns(returns_newest_first: list[float]) -> list[float]:
    if len(returns_newest_first) != CLOSE_COUNT - 1:
        raise ValueError("exactly 504 simple returns are required")
    closes = [100.0]
    for value in returns_newest_first:
        if not math.isfinite(value) or value <= -1.0:
            raise ValueError("simple returns must be finite and greater than -1")
        closes.append(closes[-1] / (1.0 + value))
    return closes


def expected_shortfall_block(
    closes_newest_first: list[float], block_offset: int
) -> float:
    if len(closes_newest_first) != CLOSE_COUNT:
        raise ValueError("exactly 505 completed closes are required")
    if block_offset not in (0, PRIOR_OFFSET):
        raise ValueError("block offset is not locked")
    if block_offset + RETURNS_PER_BLOCK >= len(closes_newest_first):
        raise ValueError("block support exceeds completed history")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes_newest_first):
        raise ValueError("closes must be positive and finite")

    returns = [
        closes_newest_first[block_offset + index]
        / closes_newest_first[block_offset + index + 1]
        - 1.0
        for index in range(RETURNS_PER_BLOCK)
    ]
    if any(not math.isfinite(value) for value in returns):
        raise ValueError("simple returns must be finite")
    if TAIL_COUNT != 13:
        raise ValueError("the locked five-percent ceiling count must be thirteen")
    return math.fsum(sorted(returns)[:TAIL_COUNT]) / TAIL_COUNT


def locked_direction(recent_es: float, preceding_es: float) -> int:
    difference = recent_es - preceding_es
    if difference > TOLERANCE:
        return 1
    if difference < -TOLERANCE:
        return -1
    return 0


def validate_completed_history(
    closes_newest_first: list[float],
    times_newest_first: list[datetime],
    decision_time: datetime,
) -> None:
    if len(closes_newest_first) != CLOSE_COUNT or len(times_newest_first) != CLOSE_COUNT:
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


def es_state_block(tail_floor: float) -> list[float]:
    background = [0.001 * ((index % 7) - 3) for index in range(239)]
    tail = [tail_floor + 0.001 * index for index in range(TAIL_COUNT)]
    return background + tail


class ExpectedShortfallReferenceTest(unittest.TestCase):
    def test_exact_ceiling_tail_and_simple_return_mean(self) -> None:
        recent_returns = es_state_block(-0.050)
        closes = closes_from_simple_returns(recent_returns + es_state_block(-0.090))
        expected = math.fsum(sorted(recent_returns)[:13]) / 13
        observed = expected_shortfall_block(closes, 0)
        wrong_floor_count = math.fsum(sorted(recent_returns)[:12]) / 12
        log_tail_mean = math.fsum(
            math.log1p(value) for value in sorted(recent_returns)[:13]
        ) / 13
        self.assertEqual(TAIL_COUNT, 13)
        self.assertAlmostEqual(observed, expected, places=13)
        self.assertNotAlmostEqual(observed, wrong_floor_count, places=6)
        self.assertNotAlmostEqual(observed, log_tail_mean, places=6)

    def test_high_recent_es_maps_long_and_low_recent_maps_short(self) -> None:
        high_recent = closes_from_simple_returns(
            es_state_block(-0.050) + es_state_block(-0.090)
        )
        recent = expected_shortfall_block(high_recent, 0)
        preceding = expected_shortfall_block(high_recent, PRIOR_OFFSET)
        self.assertGreater(recent, preceding)
        self.assertEqual(locked_direction(recent, preceding), 1)

        low_recent = closes_from_simple_returns(
            es_state_block(-0.090) + es_state_block(-0.050)
        )
        recent = expected_shortfall_block(low_recent, 0)
        preceding = expected_shortfall_block(low_recent, PRIOR_OFFSET)
        self.assertLess(recent, preceding)
        self.assertEqual(locked_direction(recent, preceding), -1)

    def test_equal_blocks_and_tolerance_are_flat(self) -> None:
        block = es_state_block(-0.070)
        closes = closes_from_simple_returns(block + block)
        recent = expected_shortfall_block(closes, 0)
        preceding = expected_shortfall_block(closes, PRIOR_OFFSET)
        self.assertAlmostEqual(recent, preceding, places=13)
        self.assertEqual(locked_direction(recent, preceding), 0)
        self.assertEqual(locked_direction(TOLERANCE, 0.0), 0)
        self.assertEqual(locked_direction(-TOLERANCE, 0.0), 0)

    def test_blocks_have_disjoint_return_support_and_one_boundary_close(self) -> None:
        recent_return_indices = set(range(0, RETURNS_PER_BLOCK))
        preceding_return_indices = set(
            range(PRIOR_OFFSET, PRIOR_OFFSET + RETURNS_PER_BLOCK)
        )
        recent_close_indices = set(range(0, RETURNS_PER_BLOCK + 1))
        preceding_close_indices = set(
            range(PRIOR_OFFSET, PRIOR_OFFSET + RETURNS_PER_BLOCK + 1)
        )
        self.assertFalse(recent_return_indices & preceding_return_indices)
        self.assertEqual(recent_close_indices & preceding_close_indices, {252})

        base_returns = es_state_block(-0.050) + es_state_block(-0.090)
        base_closes = closes_from_simple_returns(base_returns)
        recent_0 = expected_shortfall_block(base_closes, 0)
        preceding_0 = expected_shortfall_block(base_closes, PRIOR_OFFSET)

        recent_changed = list(base_returns)
        recent_changed[250] = -0.300
        closes = closes_from_simple_returns(recent_changed)
        self.assertNotAlmostEqual(
            recent_0, expected_shortfall_block(closes, 0), places=10
        )
        self.assertAlmostEqual(
            preceding_0, expected_shortfall_block(closes, PRIOR_OFFSET), places=13
        )

        prior_changed = list(base_returns)
        prior_changed[502] = -0.350
        closes = closes_from_simple_returns(prior_changed)
        self.assertAlmostEqual(
            recent_0, expected_shortfall_block(closes, 0), places=13
        )
        self.assertNotAlmostEqual(
            preceding_0, expected_shortfall_block(closes, PRIOR_OFFSET), places=10
        )

    def test_price_scale_does_not_change_expected_shortfall(self) -> None:
        closes = closes_from_simple_returns(
            es_state_block(-0.050) + es_state_block(-0.090)
        )
        scaled = [value * 17.0 for value in closes]
        for offset in (0, PRIOR_OFFSET):
            self.assertAlmostEqual(
                expected_shortfall_block(closes, offset),
                expected_shortfall_block(scaled, offset),
                places=13,
            )

    def test_count_chronology_and_freshness_fail_closed(self) -> None:
        closes = closes_from_simple_returns(
            es_state_block(-0.050) + es_state_block(-0.090)
        )
        newest = datetime(2026, 1, 30, tzinfo=timezone.utc)
        times = [newest - timedelta(days=index) for index in range(CLOSE_COUNT)]
        validate_completed_history(closes, times, newest + timedelta(days=1))
        with self.assertRaisesRegex(ValueError, "505"):
            expected_shortfall_block(closes[:-1], 0)
        bad_times = list(times)
        bad_times[100] = bad_times[99]
        with self.assertRaisesRegex(ValueError, "strictly older"):
            validate_completed_history(closes, bad_times, newest + timedelta(days=1))
        with self.assertRaisesRegex(ValueError, "stale"):
            validate_completed_history(closes, times, newest + timedelta(days=11))


if __name__ == "__main__":
    unittest.main(verbosity=2)
