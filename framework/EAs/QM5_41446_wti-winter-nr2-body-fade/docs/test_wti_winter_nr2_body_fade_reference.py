"""Deterministic reference checks for QM5_41446 WTI winter NR2 body reversion."""

from __future__ import annotations

import unittest
from dataclasses import dataclass
from datetime import date, timedelta


ELIGIBLE_MONTHS = {11, 12, 1, 2, 3, 4, 5}


@dataclass(frozen=True)
class Bar:
    day: date
    open: float
    high: float
    low: float
    close: float


def package(anchor: date, count: int, open_: float, high: float, low: float,
            close: float) -> list[Bar]:
    if count < 3 or count > 5:
        raise ValueError("session count")
    if not (high > low > 0 and low <= open_ <= high and low <= close <= high):
        raise ValueError("geometry")
    return [Bar(anchor + timedelta(days=i), open_, high, low, close) for i in range(count)]


def signal(current_anchor: date, newest: list[Bar], older: list[Bar]) -> int:
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
    body = newest[-1].close - newest[0].open
    if new_range >= old_range:
        return 0
    if body > 0:
        return -1
    if body < 0:
        return 1
    return 0


class WtiWinterNR2BodyReversionReferenceTest(unittest.TestCase):
    current = date(2026, 12, 14)
    new = current - timedelta(days=7)
    old = current - timedelta(days=14)

    def bars(self, open_: float = 100.0, close: float = 106.0,
             new_range: float = 20.0, old_range: float = 30.0) -> tuple[list[Bar], list[Bar]]:
        low = 90.0
        newest = package(self.new, 5, open_, low + new_range, low, close)
        older = package(self.old, 5, 95.0, low + old_range, low, 95.0)
        return newest, older

    def test_contraction_positive_body_is_short(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(100.0, 106.0)), -1)

    def test_contraction_negative_body_is_long(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(106.0, 94.0)), 1)

    def test_zero_body_is_flat(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(100.0, 100.0)), 0)

    def test_range_equality_is_flat(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(100.0, 100.0, 10.0, 10.0)), 0)

    def test_range_expansion_is_flat(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(96.0, 94.0, 20.0, 10.0)), 0)

    def test_close_location_is_irrelevant(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(91.0, 92.0)), -1)
        self.assertEqual(signal(self.current, *self.bars(99.0, 98.0)), 1)

    def test_all_seven_winter_months_are_eligible(self) -> None:
        self.assertEqual(ELIGIBLE_MONTHS, {11, 12, 1, 2, 3, 4, 5})

    def test_summer_month_is_ineligible(self) -> None:
        with self.assertRaisesRegex(ValueError, "ineligible month"):
            signal(date(2026, 7, 13), *self.bars())

    def test_three_to_five_sessions_are_valid(self) -> None:
        for count in (3, 4, 5):
            newest = package(self.new, count, 100, 110, 90, 106)
            older = package(self.old, count, 95, 120, 90, 95)
            self.assertEqual(signal(self.current, newest, older), -1)

    def test_bad_session_count_refuses(self) -> None:
        with self.assertRaisesRegex(ValueError, "session count"):
            package(self.new, 2, 100, 110, 90, 106)

    def test_nonadjacent_week_refuses(self) -> None:
        newest, older = self.bars()
        shifted = [Bar(bar.day - timedelta(days=7), bar.open, bar.high, bar.low, bar.close)
                   for bar in older]
        with self.assertRaisesRegex(ValueError, "older adjacency"):
            signal(self.current, newest, shifted)


if __name__ == "__main__":
    unittest.main()


