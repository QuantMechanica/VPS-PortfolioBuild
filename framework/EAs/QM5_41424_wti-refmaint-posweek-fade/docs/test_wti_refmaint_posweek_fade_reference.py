"""Deterministic reference checks for QM5_41424 WTI maintenance positive-week reversion."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import date, timedelta


ELIGIBLE_MONTHS = {2, 3, 9, 10}


@dataclass(frozen=True)
class Bar:
    session: date
    open: float
    close: float


def monday_anchor(value: date) -> date:
    return value - timedelta(days=value.weekday())


def maintenance_week(anchor: date) -> bool:
    return anchor.month in ELIGIBLE_MONTHS


def positive_week_signal(current_anchor: date, newest_first: list[Bar]) -> tuple[int, float]:
    """Mirror the immediately completed positive-week, short-only reversion contract."""
    if not maintenance_week(current_anchor):
        raise ValueError("ineligible month")

    expected = current_anchor - timedelta(days=7)
    package = [bar for bar in newest_first if monday_anchor(bar.session) == expected]
    if len(package) < 3 or len(package) > 5:
        raise ValueError("session count")
    if len({bar.session for bar in package}) != len(package):
        raise ValueError("duplicate session")
    if any(package[i - 1].session <= package[i].session for i in range(1, len(package))):
        raise ValueError("order")
    if any(bar.open <= 0 or bar.close <= 0 for bar in package):
        raise ValueError("price")

    weekly_return = math.log(package[0].close / package[-1].open)
    return (-1 if weekly_return > 0.0 else 0), weekly_return


def package(anchor: date, count: int, first_open: float, final_close: float) -> list[Bar]:
    rows = [
        Bar(anchor + timedelta(days=i), first_open + i, first_open + i + 0.25)
        for i in range(count)
    ]
    rows[-1] = Bar(rows[-1].session, rows[-1].open, final_close)
    return list(reversed(rows))


class WtiRefineryMaintenancePositiveWeekReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.current = date(2026, 10, 19)
        self.prior = self.current - timedelta(days=7)

    def test_positive_week_is_short(self) -> None:
        self.assertEqual(positive_week_signal(self.current, package(self.prior, 5, 76, 80))[0], -1)

    def test_negative_week_is_flat_not_long(self) -> None:
        self.assertEqual(positive_week_signal(self.current, package(self.prior, 5, 80, 76))[0], 0)

    def test_exact_zero_is_flat(self) -> None:
        direction, weekly_return = positive_week_signal(
            self.current, package(self.prior, 5, 78, 78)
        )
        self.assertEqual(direction, 0)
        self.assertEqual(weekly_return, 0.0)

    def test_all_maintenance_anchor_months_are_eligible(self) -> None:
        for value in (
            date(2026, 2, 2),
            date(2026, 3, 2),
            date(2026, 9, 7),
            date(2026, 10, 5),
        ):
            self.assertTrue(maintenance_week(value))

    def test_nonmaintenance_months_are_ineligible(self) -> None:
        for value in (date(2026, 1, 5), date(2026, 6, 1), date(2026, 11, 2)):
            self.assertFalse(maintenance_week(value))

    def test_week_crossing_into_february_uses_monday_anchor(self) -> None:
        self.assertFalse(maintenance_week(date(2026, 1, 26)))

    def test_week_crossing_into_september_uses_monday_anchor(self) -> None:
        self.assertFalse(maintenance_week(date(2026, 8, 31)))

    def test_three_to_five_sessions_are_accepted(self) -> None:
        for count in (3, 4, 5):
            self.assertEqual(
                positive_week_signal(self.current, package(self.prior, count, 76, 80))[0],
                -1,
            )

    def test_two_and_six_sessions_are_rejected(self) -> None:
        for count in (2, 6):
            with self.assertRaisesRegex(ValueError, "session count"):
                positive_week_signal(self.current, package(self.prior, count, 76, 80))

    def test_missing_immediately_prior_week_is_rejected(self) -> None:
        skipped = self.current - timedelta(days=14)
        with self.assertRaisesRegex(ValueError, "session count"):
            positive_week_signal(self.current, package(skipped, 5, 76, 80))

    def test_duplicate_session_is_rejected(self) -> None:
        bars = package(self.prior, 5, 76, 80)
        bars[1] = Bar(bars[0].session, bars[1].open, bars[1].close)
        with self.assertRaisesRegex(ValueError, "duplicate session"):
            positive_week_signal(self.current, bars)

    def test_ineligible_week_refuses_before_signal(self) -> None:
        with self.assertRaisesRegex(ValueError, "ineligible month"):
            positive_week_signal(date(2026, 11, 2), package(self.prior, 5, 76, 80))


if __name__ == "__main__":
    unittest.main()

