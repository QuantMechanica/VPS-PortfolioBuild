"""Independent reference checks for the QM5_20295 locked statistic contract."""

from __future__ import annotations

import math
import unittest
from datetime import datetime, timedelta, timezone


LOOKBACK = 252
VARIANCE_FLOOR = 1.0e-12
BENCHMARK = 3.0
TOLERANCE = 1.0e-12


def pearson_historical_kurtosis(returns: list[float]) -> tuple[float, float, float]:
    """Return (kurtosis, sample variance, fourth central moment)."""
    if len(returns) != LOOKBACK or any(not math.isfinite(value) for value in returns):
        raise ValueError("exactly 252 finite returns are required")
    mean = math.fsum(returns) / LOOKBACK
    centered = [value - mean for value in returns]
    squared_sum = math.fsum(value * value for value in centered)
    fourth_sum = math.fsum(value**4 for value in centered)
    sample_variance = squared_sum / (LOOKBACK - 1)
    fourth_moment = fourth_sum / LOOKBACK
    if sample_variance <= VARIANCE_FLOOR or fourth_moment <= 0.0:
        raise ValueError("degenerate source moments")
    kurtosis = fourth_moment / (sample_variance * sample_variance)
    if not math.isfinite(kurtosis) or kurtosis <= 0.0:
        raise ValueError("invalid Pearson kurtosis")
    return kurtosis, sample_variance, fourth_moment


def locked_direction(kurtosis: float) -> int:
    if kurtosis > BENCHMARK + TOLERANCE:
        return 1
    if kurtosis < BENCHMARK - TOLERANCE:
        return -1
    return 0


def completed_simple_returns(
    closes_oldest_first: list[float],
    times_oldest_first: list[datetime],
    decision_time: datetime,
) -> list[float]:
    if len(closes_oldest_first) != LOOKBACK + 1 or len(times_oldest_first) != LOOKBACK + 1:
        raise ValueError("exactly 253 completed closes are required")
    if any(
        not math.isfinite(close) or close <= 0.0 for close in closes_oldest_first
    ):
        raise ValueError("closes must be positive and finite")
    if any(
        newer <= older
        for older, newer in zip(times_oldest_first, times_oldest_first[1:])
    ):
        raise ValueError("timestamps must be strictly increasing")
    newest = times_oldest_first[-1]
    if newest >= decision_time or decision_time - newest > timedelta(days=10):
        raise ValueError("completed endpoint is invalid or stale")
    return [
        newer / older - 1.0
        for older, newer in zip(closes_oldest_first, closes_oldest_first[1:])
    ]


class KurtosisReferenceTest(unittest.TestCase):
    def test_source_denominators_have_known_two_point_value(self) -> None:
        returns = [-0.01, 0.01] * (LOOKBACK // 2)
        kurtosis, sample_variance, fourth_moment = pearson_historical_kurtosis(returns)
        self.assertAlmostEqual(sample_variance, LOOKBACK * 0.01**2 / (LOOKBACK - 1), places=16)
        self.assertAlmostEqual(fourth_moment, 0.01**4, places=20)
        self.assertAlmostEqual(kurtosis, ((LOOKBACK - 1) / LOOKBACK) ** 2, places=14)
        self.assertEqual(locked_direction(kurtosis), -1)

    def test_sparse_large_tails_map_to_locked_long_direction(self) -> None:
        returns = [-0.001, 0.001] * 125 + [-0.10, 0.10]
        kurtosis, _, _ = pearson_historical_kurtosis(returns)
        self.assertGreater(kurtosis, BENCHMARK + TOLERANCE)
        self.assertEqual(locked_direction(kurtosis), 1)

    def test_statistic_is_scale_invariant_and_pivot_tie_is_flat(self) -> None:
        returns = [-0.001, 0.001] * 125 + [-0.10, 0.10]
        original, _, _ = pearson_historical_kurtosis(returns)
        scaled, _, _ = pearson_historical_kurtosis([2.0 * value for value in returns])
        self.assertAlmostEqual(original, scaled, places=13)
        self.assertEqual(locked_direction(BENCHMARK), 0)
        self.assertEqual(locked_direction(BENCHMARK + TOLERANCE), 0)
        self.assertEqual(locked_direction(BENCHMARK - TOLERANCE), 0)

    def test_completed_close_chronology_forms_simple_returns(self) -> None:
        source_returns = [-0.002, 0.003] * (LOOKBACK // 2)
        closes = [80.0]
        for value in source_returns:
            closes.append(closes[-1] * (1.0 + value))
        start = datetime(2025, 1, 1, tzinfo=timezone.utc)
        times = [start + timedelta(days=index) for index in range(LOOKBACK + 1)]
        decision = times[-1] + timedelta(days=1)
        reconstructed = completed_simple_returns(closes, times, decision)
        for actual, expected in zip(reconstructed, source_returns):
            self.assertAlmostEqual(actual, expected, places=14)

    def test_count_order_and_freshness_fail_closed(self) -> None:
        start = datetime(2025, 1, 1, tzinfo=timezone.utc)
        times = [start + timedelta(days=index) for index in range(LOOKBACK + 1)]
        closes = [80.0 + index * 0.01 for index in range(LOOKBACK + 1)]
        with self.assertRaisesRegex(ValueError, "253"):
            completed_simple_returns(closes[:-1], times[:-1], times[-1] + timedelta(days=1))
        bad_times = list(times)
        bad_times[100] = bad_times[99]
        with self.assertRaisesRegex(ValueError, "strictly increasing"):
            completed_simple_returns(closes, bad_times, times[-1] + timedelta(days=1))
        with self.assertRaisesRegex(ValueError, "stale"):
            completed_simple_returns(closes, times, times[-1] + timedelta(days=11))


if __name__ == "__main__":
    unittest.main(verbosity=2)
