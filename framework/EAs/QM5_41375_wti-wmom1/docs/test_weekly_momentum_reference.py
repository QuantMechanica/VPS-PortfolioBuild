"""Deterministic reference checks for QM5_41375 pure weekly WTI momentum."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import date, timedelta


@dataclass(frozen=True)
class Bar:
    session: date
    open: float
    close: float


def monday_anchor(value: date) -> date:
    return value - timedelta(days=value.weekday())


def weekly_signal(current_anchor: date, newest_first: list[Bar]) -> tuple[int, int, float, float, float]:
    """Mirror the EA's exact prior-week package and strict sign contract."""
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
    if any(monday_anchor(bar.session) != expected for bar in package):
        raise ValueError("anchor")
    first_open = package[-1].open
    final_close = package[0].close
    value = math.log(final_close / first_open)
    direction = 1 if value > 0.0 else -1 if value < 0.0 else 0
    return direction, len(package), first_open, final_close, value


def package(anchor: date, count: int, first_open: float, final_close: float) -> list[Bar]:
    rows = [
        Bar(anchor + timedelta(days=i), first_open + i, first_open + i + 0.25)
        for i in range(count)
    ]
    rows[-1] = Bar(rows[-1].session, rows[-1].open, final_close)
    return list(reversed(rows))


class WeeklyMomentumReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.current = date(2026, 1, 12)
        self.prior = self.current - timedelta(days=7)

    def test_positive_week_is_long(self) -> None:
        self.assertEqual(weekly_signal(self.current, package(self.prior, 5, 70, 75))[0], 1)

    def test_negative_week_is_short(self) -> None:
        self.assertEqual(weekly_signal(self.current, package(self.prior, 5, 75, 70))[0], -1)

    def test_exact_zero_is_flat(self) -> None:
        self.assertEqual(weekly_signal(self.current, package(self.prior, 5, 70, 70))[0], 0)

    def test_three_sessions_are_accepted(self) -> None:
        self.assertEqual(weekly_signal(self.current, package(self.prior, 3, 70, 71))[1], 3)

    def test_four_sessions_are_accepted(self) -> None:
        self.assertEqual(weekly_signal(self.current, package(self.prior, 4, 70, 71))[1], 4)

    def test_five_sessions_are_accepted(self) -> None:
        self.assertEqual(weekly_signal(self.current, package(self.prior, 5, 70, 71))[1], 5)

    def test_two_sessions_are_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "session count"):
            weekly_signal(self.current, package(self.prior, 2, 70, 71))

    def test_six_sessions_are_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "session count"):
            weekly_signal(self.current, package(self.prior, 6, 70, 71))

    def test_first_open_and_final_close_are_endpoints(self) -> None:
        result = weekly_signal(self.current, package(self.prior, 5, 70, 75))
        self.assertEqual(result[2:4], (70, 75))

    def test_duplicate_session_is_rejected(self) -> None:
        rows = package(self.prior, 5, 70, 75)
        rows[1] = Bar(rows[0].session, rows[1].open, rows[1].close)
        with self.assertRaisesRegex(ValueError, "duplicate session"):
            weekly_signal(self.current, rows)

    def test_year_boundary_is_adjacent(self) -> None:
        current = date(2026, 1, 5)
        prior = date(2025, 12, 29)
        self.assertEqual(weekly_signal(current, package(prior, 5, 70, 71))[0], 1)

    def test_current_week_data_is_not_part_of_package(self) -> None:
        rows = package(self.prior, 5, 70, 75)
        rows.insert(0, Bar(self.current, 1, 999))
        self.assertEqual(weekly_signal(self.current, rows)[3], 75)


if __name__ == "__main__":
    unittest.main()
