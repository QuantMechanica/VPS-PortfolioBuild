"""Independent reference checks for the QM5_20299 locked VoV contract."""

from __future__ import annotations

import math
import statistics
import unittest
from datetime import datetime, timedelta, timezone


RV_WINDOW = 20
VOV_SAMPLES = 252
PRIOR_OFFSET = 271
CLOSE_COUNT = 543
TOLERANCE = 1.0e-12


def closes_from_log_returns(returns_newest_first: list[float]) -> list[float]:
    if len(returns_newest_first) != CLOSE_COUNT - 1:
        raise ValueError("exactly 542 log returns are required")
    closes = [100.0]
    for value in returns_newest_first:
        if not math.isfinite(value):
            raise ValueError("returns must be finite")
        closes.append(closes[-1] / math.exp(value))
    return closes


def realized_vov_block(
    closes_newest_first: list[float], block_offset: int
) -> tuple[float, float, list[float]]:
    if len(closes_newest_first) != CLOSE_COUNT:
        raise ValueError("exactly 543 completed closes are required")
    if block_offset not in (0, PRIOR_OFFSET):
        raise ValueError("block offset is not locked")
    if block_offset + VOV_SAMPLES + RV_WINDOW > len(closes_newest_first):
        raise ValueError("block support exceeds completed history")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes_newest_first):
        raise ValueError("closes must be positive and finite")

    realized_vols: list[float] = []
    for sample in range(VOV_SAMPLES):
        returns = [
            math.log(
                closes_newest_first[block_offset + sample + k]
                / closes_newest_first[block_offset + sample + k + 1]
            )
            for k in range(RV_WINDOW)
        ]
        sample_variance = statistics.variance(returns)
        if not math.isfinite(sample_variance) or sample_variance <= 0.0:
            raise ValueError("inner sample variance must be positive")
        realized_vols.append(math.sqrt(sample_variance) * math.sqrt(252.0))

    mean_rv = math.fsum(realized_vols) / VOV_SAMPLES
    population_variance = math.fsum(
        (value - mean_rv) ** 2 for value in realized_vols
    ) / VOV_SAMPLES
    if mean_rv <= 0.0 or population_variance <= 0.0:
        raise ValueError("outer VoV state must be positive")
    vov = math.sqrt(population_variance) / mean_rv
    if not math.isfinite(vov) or vov <= 0.0:
        raise ValueError("VoV must be positive and finite")
    return vov, mean_rv, realized_vols


def locked_direction(recent_vov: float, preceding_vov: float) -> int:
    difference = recent_vov - preceding_vov
    if difference < -TOLERANCE:
        return 1
    if difference > TOLERANCE:
        return -1
    return 0


def validate_completed_history(
    closes_newest_first: list[float],
    times_newest_first: list[datetime],
    decision_time: datetime,
) -> None:
    if len(closes_newest_first) != CLOSE_COUNT or len(times_newest_first) != CLOSE_COUNT:
        raise ValueError("exactly 543 completed rates are required")
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


def stable_block(scale: float = 1.0) -> list[float]:
    return [
        scale
        * 0.004
        * (1.0 + 0.04 * math.sin(index / 9.0))
        * (1.0 if index % 2 == 0 else -1.0)
        for index in range(PRIOR_OFFSET)
    ]


def unstable_block(scale: float = 1.0) -> list[float]:
    return [
        scale
        * 0.004
        * (0.25 + 1.75 * ((index % 61) / 60.0))
        * (1.0 if index % 2 == 0 else -1.0)
        for index in range(PRIOR_OFFSET)
    ]


class VoVReferenceTest(unittest.TestCase):
    def test_nested_denominators_match_statistics_reference(self) -> None:
        closes = closes_from_log_returns(stable_block() + unstable_block())
        recent, recent_mean, recent_rvs = realized_vov_block(closes, 0)
        expected_mean = statistics.fmean(recent_rvs)
        expected_vov = statistics.pstdev(recent_rvs) / expected_mean
        self.assertAlmostEqual(recent_mean, expected_mean, places=14)
        self.assertAlmostEqual(recent, expected_vov, places=14)

    def test_low_recent_vov_maps_long_and_high_recent_maps_short(self) -> None:
        low_recent = closes_from_log_returns(stable_block() + unstable_block())
        recent, _, _ = realized_vov_block(low_recent, 0)
        preceding, _, _ = realized_vov_block(low_recent, PRIOR_OFFSET)
        self.assertLess(recent, preceding)
        self.assertEqual(locked_direction(recent, preceding), 1)

        high_recent = closes_from_log_returns(unstable_block() + stable_block())
        recent, _, _ = realized_vov_block(high_recent, 0)
        preceding, _, _ = realized_vov_block(high_recent, PRIOR_OFFSET)
        self.assertGreater(recent, preceding)
        self.assertEqual(locked_direction(recent, preceding), -1)

    def test_equal_blocks_and_tolerance_are_flat(self) -> None:
        block = stable_block()
        closes = closes_from_log_returns(block + block)
        recent, _, _ = realized_vov_block(closes, 0)
        preceding, _, _ = realized_vov_block(closes, PRIOR_OFFSET)
        self.assertAlmostEqual(recent, preceding, places=14)
        self.assertEqual(locked_direction(recent, preceding), 0)
        self.assertEqual(locked_direction(preceding + TOLERANCE, preceding), 0)
        self.assertEqual(locked_direction(preceding - TOLERANCE, preceding), 0)

    def test_blocks_have_disjoint_return_support(self) -> None:
        base_returns = stable_block() + unstable_block()
        base_closes = closes_from_log_returns(base_returns)
        recent_0, _, _ = realized_vov_block(base_closes, 0)
        preceding_0, _, _ = realized_vov_block(base_closes, PRIOR_OFFSET)

        recent_changed = list(base_returns)
        recent_changed[100] *= 8.0
        closes = closes_from_log_returns(recent_changed)
        recent_1, _, _ = realized_vov_block(closes, 0)
        preceding_1, _, _ = realized_vov_block(closes, PRIOR_OFFSET)
        self.assertNotAlmostEqual(recent_0, recent_1, places=10)
        self.assertAlmostEqual(preceding_0, preceding_1, places=14)

        prior_changed = list(base_returns)
        prior_changed[400] *= 8.0
        closes = closes_from_log_returns(prior_changed)
        recent_2, _, _ = realized_vov_block(closes, 0)
        preceding_2, _, _ = realized_vov_block(closes, PRIOR_OFFSET)
        self.assertAlmostEqual(recent_0, recent_2, places=14)
        self.assertNotAlmostEqual(preceding_0, preceding_2, places=10)

    def test_price_scale_does_not_change_vov(self) -> None:
        closes = closes_from_log_returns(stable_block() + unstable_block())
        scaled = [value * 17.0 for value in closes]
        for offset in (0, PRIOR_OFFSET):
            original, _, _ = realized_vov_block(closes, offset)
            rescaled, _, _ = realized_vov_block(scaled, offset)
            self.assertAlmostEqual(original, rescaled, places=14)

    def test_count_chronology_and_freshness_fail_closed(self) -> None:
        closes = closes_from_log_returns(stable_block() + unstable_block())
        newest = datetime(2026, 1, 31, tzinfo=timezone.utc)
        times = [newest - timedelta(days=index) for index in range(CLOSE_COUNT)]
        validate_completed_history(closes, times, newest + timedelta(days=1))
        with self.assertRaisesRegex(ValueError, "543"):
            realized_vov_block(closes[:-1], 0)
        bad_times = list(times)
        bad_times[100] = bad_times[99]
        with self.assertRaisesRegex(ValueError, "strictly older"):
            validate_completed_history(closes, bad_times, newest + timedelta(days=1))
        with self.assertRaisesRegex(ValueError, "stale"):
            validate_completed_history(closes, times, newest + timedelta(days=11))


if __name__ == "__main__":
    unittest.main(verbosity=2)
