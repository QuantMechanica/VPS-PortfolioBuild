"""Deterministic reference checks for QM5_41392 XNG shoulder reversal."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import date, timedelta


ELIGIBLE_MONTHS = {4, 5, 9, 10}


@dataclass(frozen=True)
class Bar:
    session: date
    open: float
    close: float


def monday_anchor(value: date) -> date:
    return value - timedelta(days=value.weekday())


def shoulder_week(anchor: date) -> bool:
    return anchor.month in ELIGIBLE_MONTHS


def reversal_signal(
    current_anchor: date, newest_first: list[Bar]
) -> tuple[int, int, float, float, float]:
    """Mirror exact prior-week membership and contrarian orientation."""
    if not shoulder_week(current_anchor):
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
    first_open = package[-1].open
    final_close = package[0].close
    value = math.log(final_close / first_open)
    direction = -1 if value > 0.0 else 1 if value < 0.0 else 0
    return direction, len(package), first_open, final_close, value


def package(anchor: date, count: int, first_open: float, final_close: float) -> list[Bar]:
    rows = [
        Bar(anchor + timedelta(days=i), first_open + i, first_open + i + 0.25)
        for i in range(count)
    ]
    rows[-1] = Bar(rows[-1].session, rows[-1].open, final_close)
    return list(reversed(rows))


class XngShoulderWeeklyReversalReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.current = date(2026, 4, 13)
        self.prior = self.current - timedelta(days=7)

    def test_positive_week_is_short(self) -> None:
        self.assertEqual(reversal_signal(self.current, package(self.prior, 5, 3, 4))[0], -1)

    def test_negative_week_is_long(self) -> None:
        self.assertEqual(reversal_signal(self.current, package(self.prior, 5, 4, 3))[0], 1)

    def test_exact_zero_is_flat(self) -> None:
        self.assertEqual(reversal_signal(self.current, package(self.prior, 5, 3, 3))[0], 0)

    def test_reflection_flips_direction(self) -> None:
        up = reversal_signal(self.current, package(self.prior, 5, 3, 4))[0]
        down = reversal_signal(self.current, package(self.prior, 5, 4, 3))[0]
        self.assertEqual(up, -down)

    def test_all_four_anchor_months_are_eligible(self) -> None:
        for value in (date(2026, 4, 6), date(2026, 5, 4), date(2026, 9, 7), date(2026, 10, 5)):
            self.assertTrue(shoulder_week(value))

    def test_demand_peak_months_are_ineligible(self) -> None:
        for value in (date(2026, 1, 5), date(2026, 7, 6), date(2026, 12, 7)):
            self.assertFalse(shoulder_week(value))

    def test_week_crossing_into_april_uses_monday_anchor(self) -> None:
        self.assertFalse(shoulder_week(date(2026, 3, 30)))

    def test_week_crossing_into_june_uses_monday_anchor(self) -> None:
        self.assertTrue(shoulder_week(date(2026, 5, 25)))

    def test_three_to_five_sessions_are_accepted(self) -> None:
        for count in (3, 4, 5):
            self.assertEqual(
                reversal_signal(self.current, package(self.prior, count, 3, 4))[1],
                count,
            )

    def test_two_and_six_sessions_are_rejected(self) -> None:
        for count in (2, 6):
            with self.assertRaisesRegex(ValueError, "session count"):
                reversal_signal(self.current, package(self.prior, count, 3, 4))

    def test_first_open_and_final_close_are_endpoints(self) -> None:
        result = reversal_signal(self.current, package(self.prior, 5, 3, 4))
        self.assertEqual(result[2:4], (3, 4))

    def test_duplicate_session_is_rejected(self) -> None:
        rows = package(self.prior, 5, 3, 4)
        rows[1] = Bar(rows[0].session, rows[1].open, rows[1].close)
        with self.assertRaisesRegex(ValueError, "duplicate session"):
            reversal_signal(self.current, rows)

    def test_ineligible_week_refuses_before_signal(self) -> None:
        with self.assertRaisesRegex(ValueError, "ineligible month"):
            reversal_signal(date(2026, 7, 6), package(date(2026, 6, 29), 5, 3, 4))


if __name__ == "__main__":
    unittest.main()
