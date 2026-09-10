"""Deterministic reference checks for QM5_41409 XNG summer two-week fade."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import date, timedelta


ELIGIBLE_MONTHS = {6, 7, 8}


@dataclass(frozen=True)
class Bar:
    session: date
    open: float
    close: float


def monday_anchor(value: date) -> date:
    return value - timedelta(days=value.weekday())


def summer_week(anchor: date) -> bool:
    return anchor.month in ELIGIBLE_MONTHS


def fade_signal(
    current_anchor: date, newest_first: list[Bar]
) -> tuple[int, tuple[float, float]]:
    """Mirror two adjacent completed weeks and inverse strict-sign agreement."""
    if not summer_week(current_anchor):
        raise ValueError("ineligible month")

    expected = (current_anchor - timedelta(days=7), current_anchor - timedelta(days=14))
    returns: list[float] = []
    for anchor in expected:
        package = [bar for bar in newest_first if monday_anchor(bar.session) == anchor]
        if len(package) < 3 or len(package) > 5:
            raise ValueError("session count")
        if len({bar.session for bar in package}) != len(package):
            raise ValueError("duplicate session")
        if any(package[i - 1].session <= package[i].session for i in range(1, len(package))):
            raise ValueError("order")
        if any(bar.open <= 0 or bar.close <= 0 for bar in package):
            raise ValueError("price")
        returns.append(math.log(package[0].close / package[-1].open))

    if returns[0] > 0.0 and returns[1] > 0.0:
        direction = -1
    elif returns[0] < 0.0 and returns[1] < 0.0:
        direction = 1
    else:
        direction = 0
    return direction, (returns[0], returns[1])


def package(anchor: date, count: int, first_open: float, final_close: float) -> list[Bar]:
    rows = [
        Bar(anchor + timedelta(days=i), first_open + i, first_open + i + 0.25)
        for i in range(count)
    ]
    rows[-1] = Bar(rows[-1].session, rows[-1].open, final_close)
    return list(reversed(rows))


class XngSummerTwoWeekFadeReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.current = date(2026, 7, 20)
        self.newer = self.current - timedelta(days=7)
        self.older = self.current - timedelta(days=14)

    def bars(
        self,
        newer_open: float,
        newer_close: float,
        older_open: float,
        older_close: float,
    ) -> list[Bar]:
        return package(self.newer, 5, newer_open, newer_close) + package(
            self.older, 5, older_open, older_close
        )

    def test_two_positive_weeks_are_short(self) -> None:
        self.assertEqual(fade_signal(self.current, self.bars(3, 4, 2, 3))[0], -1)

    def test_two_negative_weeks_are_long(self) -> None:
        self.assertEqual(fade_signal(self.current, self.bars(4, 3, 3, 2))[0], 1)

    def test_mixed_signs_are_flat(self) -> None:
        self.assertEqual(fade_signal(self.current, self.bars(3, 4, 3, 2))[0], 0)

    def test_either_exact_zero_is_flat(self) -> None:
        self.assertEqual(fade_signal(self.current, self.bars(3, 3, 2, 3))[0], 0)
        self.assertEqual(fade_signal(self.current, self.bars(3, 4, 2, 2))[0], 0)

    def test_reflection_flips_direction(self) -> None:
        up = fade_signal(self.current, self.bars(3, 4, 2, 3))[0]
        down = fade_signal(self.current, self.bars(4, 3, 3, 2))[0]
        self.assertEqual(up, -down)

    def test_all_summer_anchor_months_are_eligible(self) -> None:
        for value in (date(2026, 6, 1), date(2026, 7, 6), date(2026, 8, 3)):
            self.assertTrue(summer_week(value))

    def test_nonsummer_months_are_ineligible(self) -> None:
        for value in (date(2026, 1, 5), date(2026, 5, 25), date(2026, 9, 7)):
            self.assertFalse(summer_week(value))

    def test_week_crossing_into_july_uses_monday_anchor(self) -> None:
        self.assertTrue(summer_week(date(2026, 6, 29)))

    def test_week_crossing_into_june_uses_monday_anchor(self) -> None:
        self.assertFalse(summer_week(date(2026, 5, 25)))

    def test_week_crossing_into_september_uses_monday_anchor(self) -> None:
        self.assertTrue(summer_week(date(2026, 8, 31)))

    def test_three_to_five_sessions_per_week_are_accepted(self) -> None:
        for newer_count in (3, 4, 5):
            for older_count in (3, 4, 5):
                bars = package(self.newer, newer_count, 3, 4) + package(
                    self.older, older_count, 2, 3
                )
                self.assertEqual(fade_signal(self.current, bars)[0], -1)

    def test_two_and_six_sessions_are_rejected(self) -> None:
        for count in (2, 6):
            bars = package(self.newer, count, 3, 4) + package(self.older, 5, 2, 3)
            with self.assertRaisesRegex(ValueError, "session count"):
                fade_signal(self.current, bars)

    def test_missing_adjacent_week_is_rejected(self) -> None:
        skipped = self.current - timedelta(days=21)
        bars = package(self.newer, 5, 3, 4) + package(skipped, 5, 2, 3)
        with self.assertRaisesRegex(ValueError, "session count"):
            fade_signal(self.current, bars)

    def test_duplicate_session_is_rejected(self) -> None:
        bars = self.bars(3, 4, 2, 3)
        bars[1] = Bar(bars[0].session, bars[1].open, bars[1].close)
        with self.assertRaisesRegex(ValueError, "duplicate session"):
            fade_signal(self.current, bars)

    def test_ineligible_week_refuses_before_signal(self) -> None:
        with self.assertRaisesRegex(ValueError, "ineligible month"):
            fade_signal(date(2026, 9, 7), self.bars(3, 4, 2, 3))


if __name__ == "__main__":
    unittest.main()
