"""Independent mechanic fixtures for QM5_41199.

The suite covers native and prior-day energy-label normalization, exact
completed calendar-month endpoints, an all-or-nothing Y-1..Y-5 sample,
fixed one-per-tail trimming, the governed neighbor-divergence fixtures,
monthly renewal, and the 35-day survivor guard.  It does not invoke MT5 or
duplicate framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import math
import statistics
import unittest
from dataclasses import dataclass


DAY = dt.timedelta(days=1)
EPSILON = 1.0e-12


@dataclass(frozen=True)
class Bar:
    label: dt.datetime
    close: float


@dataclass(frozen=True)
class TrimmedMeanResult:
    deleted_minimum: float
    deleted_maximum: float
    retained_sum: float
    trimmed_mean: float
    direction: int


def normalized_session(
    label: dt.datetime, broker_now: dt.datetime
) -> dt.datetime | None:
    elapsed = broker_now - label
    if dt.timedelta(0) <= elapsed < DAY:
        return label
    if DAY <= elapsed < 2 * DAY:
        return label + DAY
    return None


def month_key(value: dt.datetime) -> int:
    return value.year * 100 + value.month


def adjacent_month(month: int, step: int) -> int:
    year, number = divmod(month, 100)
    number += step
    if number == 0:
        return (year - 1) * 100 + 12
    if number == 13:
        return (year + 1) * 100 + 1
    return year * 100 + number


def is_month_boundary(
    current_label: dt.datetime,
    previous_label: dt.datetime,
    broker_now: dt.datetime,
) -> tuple[bool, int]:
    current = normalized_session(current_label, broker_now)
    if current is None or current.date() != broker_now.date():
        return False, 0
    offset = current - current_label
    previous = previous_label + offset
    current_month = month_key(current)
    previous_month = month_key(previous)
    return adjacent_month(previous_month, 1) == current_month, offset.days


def completed_month_return(
    bars: tuple[Bar, ...], target_month: int, label_offset_days: int
) -> float | None:
    normalized = tuple(
        Bar(bar.label + label_offset_days * DAY, bar.close) for bar in bars
    )
    indices = [
        index
        for index, bar in enumerate(normalized)
        if month_key(bar.label) == target_month
    ]
    if not indices:
        return None
    first, last = indices[0], indices[-1]
    if first == 0 or last + 1 >= len(normalized):
        return None
    if indices != list(range(first, last + 1)):
        return None
    if any(
        normalized[index - 1].label >= normalized[index].label
        for index in range(1, len(normalized))
    ):
        return None
    if month_key(normalized[first - 1].label) != adjacent_month(
        target_month, -1
    ):
        return None
    if month_key(normalized[last + 1].label) != adjacent_month(
        target_month, 1
    ):
        return None
    prior_close = normalized[first - 1].close
    end_close = normalized[last].close
    if not all(
        math.isfinite(value) and value > 0
        for value in (prior_close, end_close)
    ):
        return None
    return math.log(end_close / prior_close)


def exact_prior_five_sample(
    returns_by_month: dict[int, float], decision_month: int
) -> list[float] | None:
    year, month = divmod(decision_month, 100)
    required = [(year - offset) * 100 + month for offset in range(1, 6)]
    if any(key not in returns_by_month for key in required):
        return None
    return [returns_by_month[key] for key in required]


def trimmed_mean_direction(
    observations: list[float], epsilon: float = EPSILON
) -> TrimmedMeanResult | None:
    if len(observations) != 5:
        return None
    if not all(math.isfinite(value) for value in observations):
        return None
    ordered = sorted(observations)
    retained_sum = sum(ordered[1:4])
    trimmed_mean = retained_sum / 3.0
    direction = (trimmed_mean > epsilon) - (trimmed_mean < -epsilon)
    return TrimmedMeanResult(
        deleted_minimum=ordered[0],
        deleted_maximum=ordered[4],
        retained_sum=retained_sum,
        trimmed_mean=trimmed_mean,
        direction=direction,
    )


def centered_signed_rank_direction(observations: list[float]) -> int:
    absolute_values = [abs(value) for value in observations]
    ranks = [
        1 + sum(other < value for other in absolute_values)
        for value in absolute_values
    ]
    total = len(observations) * (len(observations) + 1) // 2
    positive = sum(
        rank for rank, value in zip(ranks, observations) if value > 0
    )
    score = 2 * positive - total
    return (score > 0) - (score < 0)


def monthly_exit_due(opened: dt.datetime, current: dt.datetime) -> bool:
    return month_key(opened) != month_key(current)


def stale_exit_due(
    opened: dt.datetime, current: dt.datetime, maximum_days: int = 35
) -> bool:
    return current - opened >= maximum_days * DAY


class SameCalendarTrimFiveReferenceTests(unittest.TestCase):
    def test_native_month_boundary(self) -> None:
        boundary, offset = is_month_boundary(
            dt.datetime(2026, 8, 3),
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 8, 3, 1),
        )
        self.assertTrue(boundary)
        self.assertEqual(offset, 0)

    def test_prior_day_energy_labels_normalize_uniformly(self) -> None:
        boundary, offset = is_month_boundary(
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 7, 30),
            dt.datetime(2026, 8, 1, 1),
        )
        self.assertTrue(boundary)
        self.assertEqual(offset, 1)

    def test_mid_month_attach_is_not_a_boundary(self) -> None:
        boundary, _ = is_month_boundary(
            dt.datetime(2026, 8, 18),
            dt.datetime(2026, 8, 17),
            dt.datetime(2026, 8, 18, 1),
        )
        self.assertFalse(boundary)

    def test_exact_completed_month_endpoints(self) -> None:
        bars = (
            Bar(dt.datetime(2025, 12, 31), 90.0),
            Bar(dt.datetime(2026, 1, 2), 92.0),
            Bar(dt.datetime(2026, 1, 30), 99.0),
            Bar(dt.datetime(2026, 2, 2), 101.0),
        )
        observed = completed_month_return(bars, 202601, 0)
        self.assertIsNotNone(observed)
        self.assertAlmostEqual(observed or 0.0, math.log(99.0 / 90.0))

    def test_partial_month_without_adjacent_endpoint_is_rejected(self) -> None:
        missing_prior = (
            Bar(dt.datetime(2026, 1, 2), 92.0),
            Bar(dt.datetime(2026, 1, 30), 99.0),
            Bar(dt.datetime(2026, 2, 2), 101.0),
        )
        missing_following = (
            Bar(dt.datetime(2025, 12, 31), 90.0),
            Bar(dt.datetime(2026, 1, 2), 92.0),
            Bar(dt.datetime(2026, 1, 30), 99.0),
        )
        self.assertIsNone(completed_month_return(missing_prior, 202601, 0))
        self.assertIsNone(completed_month_return(missing_following, 202601, 0))

    def test_december_january_wrap_is_exact(self) -> None:
        self.assertEqual(adjacent_month(202601, -1), 202512)
        self.assertEqual(adjacent_month(202512, 1), 202601)

    def test_exact_five_years_require_every_year_without_substitution(self) -> None:
        values = {
            202501: 0.01,
            202401: 0.02,
            202301: -0.03,
            202201: 0.04,
            202101: 0.05,
            202001: -9.99,
        }
        self.assertEqual(
            exact_prior_five_sample(values, 202601),
            [0.01, 0.02, -0.03, 0.04, 0.05],
        )
        del values[202301]
        self.assertIsNone(exact_prior_five_sample(values, 202601))

    def test_sort_delete_and_middle_three_arithmetic(self) -> None:
        result = trimmed_mean_direction([0.09, -0.30, 0.08, -0.03, -0.04])
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result.deleted_minimum, -0.30)
        self.assertAlmostEqual(result.deleted_maximum, 0.09)
        self.assertAlmostEqual(result.retained_sum, 0.01)
        self.assertAlmostEqual(result.trimmed_mean, 0.01 / 3.0)
        self.assertEqual(result.direction, 1)

    def test_mean_median_and_signed_rank_neighbor_divergence(self) -> None:
        observations = [-0.30, -0.04, -0.03, 0.08, 0.09]
        result = trimmed_mean_direction(observations)
        self.assertIsNotNone(result)
        self.assertEqual(result.direction if result else 0, 1)
        self.assertLess(statistics.mean(observations), 0.0)
        self.assertLess(statistics.median(observations), 0.0)
        self.assertEqual(centered_signed_rank_direction(observations), -1)

    def test_median_and_hit_rate_neighbor_divergence(self) -> None:
        observations = [-0.30, -0.04, 0.01, 0.02, 0.03]
        result = trimmed_mean_direction(observations)
        self.assertIsNotNone(result)
        self.assertEqual(result.direction if result else 0, -1)
        self.assertGreater(statistics.median(observations), 0.0)
        self.assertEqual(sum(value > 0 for value in observations), 3)

    def test_exact_sample_count_nonfinite_and_tie_band_fail_closed(self) -> None:
        self.assertIsNone(trimmed_mean_direction([0.01, 0.02, 0.03, 0.04]))
        self.assertIsNone(
            trimmed_mean_direction([0.01, 0.02, math.nan, 0.04, 0.05])
        )
        tied = trimmed_mean_direction([-0.30, -0.02, 0.0, 0.02, 0.30])
        self.assertIsNotNone(tied)
        self.assertEqual(tied.direction if tied else 1, 0)

    def test_month_boundary_is_ordinary_exit_and_renewal(self) -> None:
        opened = dt.datetime(2026, 8, 3, 1)
        self.assertFalse(monthly_exit_due(opened, dt.datetime(2026, 8, 31)))
        self.assertTrue(monthly_exit_due(opened, dt.datetime(2026, 9, 1)))

    def test_thirty_five_day_guard_repairs_only_survivor(self) -> None:
        opened = dt.datetime(2026, 8, 3, 1)
        self.assertFalse(stale_exit_due(opened, opened + 35 * DAY - DAY / 2))
        self.assertTrue(stale_exit_due(opened, opened + 35 * DAY))


if __name__ == "__main__":
    unittest.main()
