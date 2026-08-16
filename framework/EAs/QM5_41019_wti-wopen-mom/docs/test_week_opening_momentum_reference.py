"""Independent mechanic fixtures for QM5_41019.

The tests cover the locked calendar-label normalization, completed endpoint,
direction, grace, attempt, and stale-lifecycle rules without invoking MT5 or
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


def valid_opening_sequence(
    broker_now: dt.datetime,
    current_label: dt.datetime,
    completed_labels: tuple[dt.datetime, dt.datetime, dt.datetime],
) -> bool:
    current = session_time(current_label, broker_now)
    offset = current - current_label
    tuesday, monday, friday = (value + offset for value in completed_labels)
    gaps = (current - tuesday, tuesday - monday, monday - friday)
    return (
        broker_now.weekday() == 2
        and current.date() == broker_now.date()
        and (tuesday.weekday(), monday.weekday(), friday.weekday()) == (1, 0, 4)
        and 20 * 3_600 <= gaps[0].total_seconds() <= 28 * 3_600
        and 20 * 3_600 <= gaps[1].total_seconds() <= 28 * 3_600
        and 68 * 3_600 <= gaps[2].total_seconds() <= 76 * 3_600
    )


def opening_direction(tuesday_close: float, friday_close: float) -> int:
    if not all(math.isfinite(value) and value > 0 for value in (tuesday_close, friday_close)):
        return 0
    value = math.log(tuesday_close / friday_close)
    return 1 if value > 0 else -1 if value < 0 else 0


def stale_weekday(day: dt.datetime, opened: dt.datetime) -> bool:
    return day > opened and day.weekday() in (6, 0, 1)


class WeekOpeningMomentumReferenceTests(unittest.TestCase):
    def test_prior_date_energy_labels_normalize_to_session_dates(self) -> None:
        broker_now = dt.datetime(2026, 8, 12, 1, 0)  # Wednesday
        current_label = dt.datetime(2026, 8, 11, 0, 0)
        completed = (
            dt.datetime(2026, 8, 10, 0, 0),
            dt.datetime(2026, 8, 9, 0, 0),
            dt.datetime(2026, 8, 6, 0, 0),
        )
        self.assertTrue(valid_opening_sequence(broker_now, current_label, completed))

    def test_native_same_day_labels_are_also_supported(self) -> None:
        broker_now = dt.datetime(2026, 8, 12, 1, 0)
        current_label = dt.datetime(2026, 8, 12, 0, 0)
        completed = (
            dt.datetime(2026, 8, 11, 0, 0),
            dt.datetime(2026, 8, 10, 0, 0),
            dt.datetime(2026, 8, 7, 0, 0),
        )
        self.assertTrue(valid_opening_sequence(broker_now, current_label, completed))

    def test_missing_monday_is_not_shifted(self) -> None:
        broker_now = dt.datetime(2026, 8, 12, 1, 0)
        current_label = dt.datetime(2026, 8, 12, 0, 0)
        completed = (
            dt.datetime(2026, 8, 11, 0, 0),
            dt.datetime(2026, 8, 7, 0, 0),
            dt.datetime(2026, 8, 6, 0, 0),
        )
        self.assertFalse(valid_opening_sequence(broker_now, current_label, completed))

    def test_three_hour_grace_accepts_normal_energy_open(self) -> None:
        labelled = dt.datetime(2026, 8, 11, 0, 0)
        self.assertTrue(within_entry_grace(dt.datetime(2026, 8, 12, 2, 59), labelled))
        self.assertFalse(within_entry_grace(dt.datetime(2026, 8, 12, 3, 0, 1), labelled))

    def test_direction_uses_tuesday_and_prior_friday_only(self) -> None:
        self.assertEqual(opening_direction(72.0, 70.0), 1)
        self.assertEqual(opening_direction(68.0, 70.0), -1)
        self.assertEqual(opening_direction(70.0, 70.0), 0)

    def test_invalid_completed_endpoint_consumes_flat(self) -> None:
        self.assertEqual(opening_direction(0.0, 70.0), 0)
        self.assertEqual(opening_direction(float("nan"), 70.0), 0)

    def test_prior_week_carry_is_stale_sunday_through_tuesday(self) -> None:
        opened = dt.datetime(2026, 8, 12, 1, 0)
        self.assertFalse(stale_weekday(dt.datetime(2026, 8, 14, 20, 0), opened))
        self.assertTrue(stale_weekday(dt.datetime(2026, 8, 17, 1, 0), opened))

    def test_exact_date_attempt_key_is_stable(self) -> None:
        observed = dt.datetime(2026, 8, 12, 2, 0)
        key = observed.year * 10_000 + observed.month * 100 + observed.day
        self.assertEqual(key, 20260812)
        self.assertNotEqual(key, 20260819)


if __name__ == "__main__":
    unittest.main()
