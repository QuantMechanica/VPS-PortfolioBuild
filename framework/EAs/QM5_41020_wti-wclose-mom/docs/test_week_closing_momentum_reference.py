"""Independent mechanic fixtures for QM5_41020.

The tests cover the locked calendar-label normalization, completed endpoints,
direction, grace, attempt, and Wednesday lifecycle without invoking MT5 or
duplicating framework order plumbing.
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


def valid_closing_sequence(
    broker_now: dt.datetime,
    current_label: dt.datetime,
    completed_labels: tuple[
        dt.datetime, dt.datetime, dt.datetime, dt.datetime
    ],
) -> bool:
    current = session_time(current_label, broker_now)
    offset = current - current_label
    friday, thursday, wednesday, tuesday = (
        value + offset for value in completed_labels
    )
    gaps = (
        current - friday,
        friday - thursday,
        thursday - wednesday,
        wednesday - tuesday,
    )
    return (
        broker_now.weekday() == 0
        and current.date() == broker_now.date()
        and (
            friday.weekday(),
            thursday.weekday(),
            wednesday.weekday(),
            tuesday.weekday(),
        )
        == (4, 3, 2, 1)
        and 68 * 3_600 <= gaps[0].total_seconds() <= 76 * 3_600
        and all(20 * 3_600 <= gap.total_seconds() <= 28 * 3_600 for gap in gaps[1:])
    )


def closing_direction(friday_close: float, tuesday_close: float) -> int:
    if not all(
        math.isfinite(value) and value > 0
        for value in (friday_close, tuesday_close)
    ):
        return 0
    value = math.log(friday_close / tuesday_close)
    return 1 if value > 0 else -1 if value < 0 else 0


def stale_weekday(day: dt.datetime, opened: dt.datetime) -> bool:
    return day > opened and day.weekday() in (2, 3, 4)


def stale_age(day: dt.datetime, opened: dt.datetime, max_days: int = 5) -> bool:
    return day >= opened and day - opened >= max_days * DAY


class WeekClosingMomentumReferenceTests(unittest.TestCase):
    def test_prior_date_energy_labels_normalize_to_session_dates(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)  # Monday
        current_label = dt.datetime(2026, 8, 16, 0, 0)
        completed = (
            dt.datetime(2026, 8, 13, 0, 0),
            dt.datetime(2026, 8, 12, 0, 0),
            dt.datetime(2026, 8, 11, 0, 0),
            dt.datetime(2026, 8, 10, 0, 0),
        )
        self.assertTrue(valid_closing_sequence(broker_now, current_label, completed))

    def test_native_same_day_labels_are_also_supported(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)
        current_label = dt.datetime(2026, 8, 17, 0, 0)
        completed = (
            dt.datetime(2026, 8, 14, 0, 0),
            dt.datetime(2026, 8, 13, 0, 0),
            dt.datetime(2026, 8, 12, 0, 0),
            dt.datetime(2026, 8, 11, 0, 0),
        )
        self.assertTrue(valid_closing_sequence(broker_now, current_label, completed))

    def test_missing_thursday_is_not_shifted(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)
        current_label = dt.datetime(2026, 8, 17, 0, 0)
        completed = (
            dt.datetime(2026, 8, 14, 0, 0),
            dt.datetime(2026, 8, 12, 0, 0),
            dt.datetime(2026, 8, 11, 0, 0),
            dt.datetime(2026, 8, 10, 0, 0),
        )
        self.assertFalse(valid_closing_sequence(broker_now, current_label, completed))

    def test_three_hour_grace_accepts_normal_energy_open(self) -> None:
        labelled = dt.datetime(2026, 8, 16, 0, 0)
        self.assertTrue(within_entry_grace(dt.datetime(2026, 8, 17, 2, 59), labelled))
        self.assertFalse(within_entry_grace(dt.datetime(2026, 8, 17, 3, 0, 1), labelled))

    def test_direction_uses_prior_friday_and_prior_tuesday_only(self) -> None:
        self.assertEqual(closing_direction(72.0, 70.0), 1)
        self.assertEqual(closing_direction(68.0, 70.0), -1)
        self.assertEqual(closing_direction(70.0, 70.0), 0)

    def test_invalid_completed_endpoint_consumes_flat(self) -> None:
        self.assertEqual(closing_direction(0.0, 70.0), 0)
        self.assertEqual(closing_direction(float("nan"), 70.0), 0)

    def test_first_wednesday_and_later_weekdays_are_stale(self) -> None:
        opened = dt.datetime(2026, 8, 17, 1, 0)
        self.assertFalse(stale_weekday(dt.datetime(2026, 8, 18, 20, 0), opened))
        self.assertTrue(stale_weekday(dt.datetime(2026, 8, 19, 0, 1), opened))
        self.assertTrue(stale_weekday(dt.datetime(2026, 8, 21, 20, 0), opened))

    def test_five_day_guard_repairs_weekend_carry(self) -> None:
        opened = dt.datetime(2026, 8, 17, 1, 0)
        self.assertFalse(stale_age(dt.datetime(2026, 8, 22, 0, 59), opened))
        self.assertTrue(stale_age(dt.datetime(2026, 8, 22, 1, 0), opened))

    def test_exact_date_attempt_key_is_stable(self) -> None:
        observed = dt.datetime(2026, 8, 17, 2, 0)
        key = observed.year * 10_000 + observed.month * 100 + observed.day
        self.assertEqual(key, 20260817)
        self.assertNotEqual(key, 20260824)


if __name__ == "__main__":
    unittest.main()
