from __future__ import annotations

import datetime as dt
import unittest


ENTRY_WEEKDAY = 4  # Python Monday=0; Friday=4.
ENTRY_HOUR = 21
EXIT_HOUR = 21
MAX_HOLD_HOURS = 96


def entry_boundary(bar_time: dt.datetime, now: dt.datetime) -> bool:
    delay = (now - bar_time).total_seconds()
    return (
        bar_time.weekday() == ENTRY_WEEKDAY
        and bar_time.hour == ENTRY_HOUR
        and bar_time.minute == 0
        and bar_time.second == 0
        and 0 <= delay <= 5 * 60
    )


def calendar_exit(opened: dt.datetime, now: dt.datetime) -> bool:
    if now <= opened:
        return False
    if now - opened >= dt.timedelta(hours=MAX_HOLD_HOURS):
        return True
    if now.weekday() == 0 and now.hour >= EXIT_HOUR:
        return True
    if now.weekday() in (1, 2, 3):
        return True
    return False


class WeekendScheduleReferenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.friday = dt.datetime(2026, 8, 14, 21, 0, 0)

    def test_exact_friday_boundary_is_eligible(self) -> None:
        self.assertTrue(entry_boundary(self.friday, self.friday))

    def test_five_minute_grace_is_inclusive(self) -> None:
        self.assertTrue(
            entry_boundary(self.friday, self.friday + dt.timedelta(minutes=5))
        )
        self.assertFalse(
            entry_boundary(
                self.friday, self.friday + dt.timedelta(minutes=5, seconds=1)
            )
        )

    def test_other_weekday_or_hour_is_ineligible(self) -> None:
        self.assertFalse(
            entry_boundary(self.friday - dt.timedelta(hours=1), self.friday)
        )
        monday = dt.datetime(2026, 8, 17, 21, 0, 0)
        self.assertFalse(entry_boundary(monday, monday))

    def test_hold_survives_monday_before_cutoff(self) -> None:
        self.assertFalse(
            calendar_exit(self.friday, dt.datetime(2026, 8, 17, 20, 59, 59))
        )

    def test_matching_monday_cutoff_exits(self) -> None:
        self.assertTrue(
            calendar_exit(self.friday, dt.datetime(2026, 8, 17, 21, 0, 0))
        )

    def test_first_tuesday_tick_repairs_missed_cutoff(self) -> None:
        self.assertTrue(
            calendar_exit(self.friday, dt.datetime(2026, 8, 18, 0, 0, 1))
        )

    def test_absolute_stale_guard_exits(self) -> None:
        self.assertTrue(
            calendar_exit(
                self.friday, self.friday + dt.timedelta(hours=MAX_HOLD_HOURS)
            )
        )


if __name__ == "__main__":
    unittest.main()
