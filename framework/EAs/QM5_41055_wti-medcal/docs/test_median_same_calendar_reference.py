"""Independent mechanic fixtures for QM5_41055.

The suite covers native and prior-day energy-label normalization, exact
completed calendar-month endpoints, fixed Y-1..Y-10 sampling, the five-sample
floor, odd/even median arithmetic, the load-bearing mean/median divergence,
sign tolerance, monthly renewal, and the 35-day survivor guard. It does not
invoke MT5 or duplicate framework order plumbing.
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


def median_direction(
    observations: list[float],
    minimum: int = 5,
    maximum: int = 10,
    epsilon: float = EPSILON,
) -> tuple[float | None, int]:
    if not minimum <= len(observations) <= maximum:
        return None, 0
    if not all(math.isfinite(value) for value in observations):
        return None, 0
    ordered = sorted(observations)
    middle = len(ordered) // 2
    if len(ordered) % 2:
        median = ordered[middle]
    else:
        median = (ordered[middle - 1] + ordered[middle]) / 2.0
    direction = (median > epsilon) - (median < -epsilon)
    return median, direction


def exact_prior_year_sample(
    returns_by_month: dict[int, float], decision_month: int
) -> list[float]:
    year, month = divmod(decision_month, 100)
    return [
        returns_by_month[(year - offset) * 100 + month]
        for offset in range(1, 11)
        if (year - offset) * 100 + month in returns_by_month
    ]


def monthly_exit_due(opened: dt.datetime, current: dt.datetime) -> bool:
    return month_key(opened) != month_key(current)


def stale_exit_due(
    opened: dt.datetime, current: dt.datetime, maximum_days: int = 35
) -> bool:
    return current - opened >= maximum_days * DAY


class MedianSameCalendarReferenceTests(unittest.TestCase):
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

    def test_december_january_wrap_is_exact(self) -> None:
        self.assertEqual(adjacent_month(202601, -1), 202512)
        self.assertEqual(adjacent_month(202512, 1), 202601)

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
        self.assertIsNone(
            completed_month_return(missing_following, 202601, 0)
        )

    def test_odd_and_even_medians_use_the_center_only(self) -> None:
        odd, odd_direction = median_direction([-0.04, 0.01, 0.03, 0.02, 0.50])
        even, even_direction = median_direction(
            [-0.04, -0.01, 0.02, 0.04, 0.10, 0.50]
        )
        self.assertAlmostEqual(odd or 0.0, 0.02)
        self.assertEqual(odd_direction, 1)
        self.assertAlmostEqual(even or 0.0, 0.03)
        self.assertEqual(even_direction, 1)

    def test_load_bearing_outlier_can_flip_mean_but_not_median(self) -> None:
        observations = [-0.04, -0.03, -0.02, 0.01, 1.00]
        median, direction = median_direction(observations)
        self.assertLess(median or 0.0, 0.0)
        self.assertEqual(direction, -1)
        self.assertGreater(statistics.mean(observations), 0.0)

    def test_five_sample_floor_and_ten_year_cap(self) -> None:
        self.assertEqual(median_direction([0.01] * 4), (None, 0))
        self.assertEqual(median_direction([0.01] * 5)[1], 1)
        self.assertEqual(median_direction([0.01] * 10)[1], 1)
        self.assertEqual(median_direction([0.01] * 11), (None, 0))

    def test_exact_prior_years_skip_without_substitution(self) -> None:
        values = {
            202501: 0.01,
            202401: 0.02,
            202201: -0.03,
            201501: 9.99,
        }
        self.assertEqual(
            exact_prior_year_sample(values, 202601),
            [0.01, 0.02, -0.03],
        )

    def test_inclusive_epsilon_band_is_flat(self) -> None:
        self.assertEqual(median_direction([EPSILON] * 5)[1], 0)
        self.assertEqual(median_direction([-EPSILON] * 5)[1], 0)
        self.assertEqual(median_direction([2 * EPSILON] * 5)[1], 1)
        self.assertEqual(median_direction([-2 * EPSILON] * 5)[1], -1)

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
