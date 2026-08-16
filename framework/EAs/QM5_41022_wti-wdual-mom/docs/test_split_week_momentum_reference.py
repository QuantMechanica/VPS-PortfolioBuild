"""Independent mechanic fixtures for QM5_41022.

The tests cover the locked calendar-label normalization, exact six-bar
sequence, disjoint completed endpoints, agreement direction, grace, attempt,
and later-week repair without invoking MT5 or duplicating framework order
plumbing.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest


DAY = dt.timedelta(days=1)


def session_time(label: dt.datetime, broker_now: dt.datetime) -> dt.datetime:
    elapsed = broker_now - label
    if DAY <= elapsed < 2 * DAY:
        return label + DAY
    return label


def within_entry_grace(
    broker_now: dt.datetime, labelled_bar_open: dt.datetime, grace_minutes: int = 180
) -> bool:
    elapsed = int((broker_now - labelled_bar_open).total_seconds())
    if elapsed < 0:
        return False
    return elapsed % 86_400 <= grace_minutes * 60


def valid_split_sequence(
    broker_now: dt.datetime,
    current_label: dt.datetime,
    completed_labels: tuple[dt.datetime, ...],
) -> bool:
    if len(completed_labels) != 6:
        return False
    current = session_time(current_label, broker_now)
    offset = current - current_label
    bars = tuple(value + offset for value in completed_labels)
    expected_weekdays = (4, 3, 2, 1, 0, 4)  # Python Monday=0
    expected_dates = tuple(
        (broker_now - days * DAY).date() for days in (3, 4, 5, 6, 7, 10)
    )
    return (
        broker_now.weekday() == 0
        and current.date() == broker_now.date()
        and tuple(value.weekday() for value in bars) == expected_weekdays
        and tuple(value.date() for value in bars) == expected_dates
    )


def split_direction(
    preceding_friday_close: float,
    prior_tuesday_close: float,
    prior_friday_close: float,
) -> tuple[int, float, float]:
    values = (
        preceding_friday_close,
        prior_tuesday_close,
        prior_friday_close,
    )
    if not all(math.isfinite(value) and value > 0 for value in values):
        return 0, 0.0, 0.0
    opening = math.log(prior_tuesday_close / preceding_friday_close)
    closing = math.log(prior_friday_close / prior_tuesday_close)
    if opening > 0 and closing > 0:
        return 1, opening, closing
    if opening < 0 and closing < 0:
        return -1, opening, closing
    return 0, opening, closing


def week_start(value: dt.datetime) -> dt.date:
    return (value - value.weekday() * DAY).date()


class SplitWeekMomentumReferenceTests(unittest.TestCase):
    def test_prior_date_energy_labels_normalize_uniformly(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)  # Monday
        current_label = dt.datetime(2026, 8, 16, 0, 0)
        completed = tuple(
            dt.datetime(2026, 8, day, 0, 0) for day in (13, 12, 11, 10, 9, 6)
        )
        self.assertTrue(valid_split_sequence(broker_now, current_label, completed))

    def test_native_same_day_labels_are_supported(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)
        current_label = dt.datetime(2026, 8, 17, 0, 0)
        completed = tuple(
            dt.datetime(2026, 8, day, 0, 0) for day in (14, 13, 12, 11, 10, 7)
        )
        self.assertTrue(valid_split_sequence(broker_now, current_label, completed))

    def test_holiday_broken_sequence_is_not_shifted(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)
        current_label = dt.datetime(2026, 8, 17, 0, 0)
        completed = tuple(
            dt.datetime(2026, 8, day, 0, 0) for day in (14, 12, 11, 10, 7, 6)
        )
        self.assertFalse(valid_split_sequence(broker_now, current_label, completed))

    def test_non_monday_decision_is_rejected(self) -> None:
        broker_now = dt.datetime(2026, 8, 18, 1, 0)
        current_label = dt.datetime(2026, 8, 18, 0, 0)
        completed = tuple(
            dt.datetime(2026, 8, day, 0, 0) for day in (17, 14, 13, 12, 11, 10)
        )
        self.assertFalse(valid_split_sequence(broker_now, current_label, completed))

    def test_three_hour_grace_accepts_normal_energy_open(self) -> None:
        labelled = dt.datetime(2026, 8, 16, 0, 0)
        self.assertTrue(within_entry_grace(dt.datetime(2026, 8, 17, 2, 59), labelled))
        self.assertFalse(within_entry_grace(dt.datetime(2026, 8, 17, 3, 0, 1), labelled))

    def test_both_positive_segments_buy(self) -> None:
        direction, opening, closing = split_direction(70.0, 72.0, 75.0)
        self.assertEqual(direction, 1)
        self.assertGreater(opening, 0)
        self.assertGreater(closing, 0)

    def test_both_negative_segments_sell(self) -> None:
        direction, opening, closing = split_direction(75.0, 72.0, 70.0)
        self.assertEqual(direction, -1)
        self.assertLess(opening, 0)
        self.assertLess(closing, 0)

    def test_disagreement_and_equality_consume_flat(self) -> None:
        self.assertEqual(split_direction(70.0, 75.0, 72.0)[0], 0)
        self.assertEqual(split_direction(75.0, 70.0, 72.0)[0], 0)
        self.assertEqual(split_direction(70.0, 70.0, 72.0)[0], 0)

    def test_invalid_completed_endpoint_consumes_flat(self) -> None:
        self.assertEqual(split_direction(0.0, 70.0, 72.0)[0], 0)
        self.assertEqual(split_direction(70.0, float("nan"), 72.0)[0], 0)

    def test_later_week_is_a_stale_repair_boundary(self) -> None:
        opened = dt.datetime(2026, 8, 17, 1, 0)
        self.assertEqual(week_start(opened), week_start(dt.datetime(2026, 8, 21, 22, 0)))
        self.assertNotEqual(
            week_start(opened), week_start(dt.datetime(2026, 8, 24, 0, 1))
        )

    def test_exact_date_attempt_key_is_stable(self) -> None:
        observed = dt.datetime(2026, 8, 17, 2, 0)
        key = observed.year * 10_000 + observed.month * 100 + observed.day
        self.assertEqual(key, 20260817)
        self.assertNotEqual(key, 20260824)


if __name__ == "__main__":
    unittest.main()
