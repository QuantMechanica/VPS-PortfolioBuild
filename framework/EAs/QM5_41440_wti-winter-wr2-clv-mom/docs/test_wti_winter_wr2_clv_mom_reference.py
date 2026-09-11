"""Deterministic reference checks for QM5_41440 WTI winter WR2/CLV momentum."""

from __future__ import annotations

import unittest
from dataclasses import dataclass
from datetime import date, timedelta


ELIGIBLE_MONTHS = {11, 12, 1, 2, 3, 4, 5}


@dataclass(frozen=True)
class Bar:
    day: date
    high: float
    low: float
    close: float


def package(anchor: date, count: int, high: float, low: float, close: float) -> list[Bar]:
    if count < 3 or count > 5:
        raise ValueError("session count")
    if not (high > low > 0 and low <= close <= high):
        raise ValueError("geometry")
    return [Bar(anchor + timedelta(days=i), high, low, close) for i in range(count)]


def signal(current_anchor: date, newest: list[Bar], older: list[Bar]) -> tuple[int, float]:
    if current_anchor.month not in ELIGIBLE_MONTHS:
        raise ValueError("ineligible month")
    if min(bar.day for bar in newest) != current_anchor - timedelta(days=7):
        raise ValueError("newest adjacency")
    if min(bar.day for bar in older) != current_anchor - timedelta(days=14):
        raise ValueError("older adjacency")
    if not (3 <= len(newest) <= 5 and 3 <= len(older) <= 5):
        raise ValueError("session count")
    new_range = max(bar.high for bar in newest) - min(bar.low for bar in newest)
    old_range = max(bar.high for bar in older) - min(bar.low for bar in older)
    clv = (newest[-1].close - min(bar.low for bar in newest)) / new_range
    if new_range <= old_range:
        return 0, clv
    if clv > 0.75:
        return 1, clv
    return 0, clv


class WtiWinterWR2CLVReferenceTest(unittest.TestCase):
    current = date(2026, 12, 14)
    new = current - timedelta(days=7)
    old = current - timedelta(days=14)

    def bars(self, close_location: float = 0.8, new_range: float = 20.0,
             old_range: float = 10.0) -> tuple[list[Bar], list[Bar]]:
        low = 90.0
        newest = package(self.new, 5, low + new_range, low, low + new_range * close_location)
        older = package(self.old, 5, low + old_range, low, low + old_range / 2)
        return newest, older

    def test_expansion_upper_quartile_is_long(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(0.8))[0], 1)

    def test_expansion_lower_quartile_is_flat(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(0.2))[0], 0)

    def test_range_equality_is_flat(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(0.8, 10, 10))[0], 0)

    def test_range_contraction_is_flat(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(0.8, 8, 10))[0], 0)

    def test_upper_clv_equality_is_flat(self) -> None:
        direction, clv = signal(self.current, *self.bars(0.75))
        self.assertEqual((direction, clv), (0, 0.75))

    def test_interior_clv_is_flat(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(0.5))[0], 0)

    def test_all_seven_winter_months_are_eligible(self) -> None:
        self.assertEqual(ELIGIBLE_MONTHS, {11, 12, 1, 2, 3, 4, 5})

    def test_summer_month_is_ineligible(self) -> None:
        with self.assertRaisesRegex(ValueError, "ineligible month"):
            signal(date(2026, 7, 13), *self.bars())

    def test_three_to_five_sessions_are_valid(self) -> None:
        for count in (3, 4, 5):
            newest = package(self.new, count, 110, 90, 106)
            older = package(self.old, count, 100, 90, 95)
            self.assertEqual(signal(self.current, newest, older)[0], 1)

    def test_bad_session_count_refuses(self) -> None:
        with self.assertRaisesRegex(ValueError, "session count"):
            package(self.new, 2, 110, 90, 106)

    def test_nonadjacent_week_refuses(self) -> None:
        newest, older = self.bars()
        shifted = [Bar(bar.day - timedelta(days=7), bar.high, bar.low, bar.close) for bar in older]
        with self.assertRaisesRegex(ValueError, "older adjacency"):
            signal(self.current, newest, shifted)


if __name__ == "__main__":
    unittest.main()
