"""Deterministic reference checks for QM5_41459 WTI summer WR2 down-week continuation."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import date, timedelta


ELIGIBLE_MONTHS = {6, 7, 8, 9, 10}


@dataclass(frozen=True)
class Bar:
    day: date
    open: float
    high: float
    low: float
    close: float


def package(anchor: date, count: int, open_: float, high: float,
            low: float, close: float) -> list[Bar]:
    if count < 3 or count > 5:
        raise ValueError("session count")
    if not (high >= max(open_, close) and low <= min(open_, close) and low > 0):
        raise ValueError("geometry")
    bars = [Bar(anchor + timedelta(days=i), close, high, low, close) for i in range(count)]
    bars[0] = Bar(anchor, open_, high, low, close)
    return bars


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
    body = math.log(newest[-1].close / newest[0].open)
    return (-1 if new_range > old_range and body < 0 else 0, body)


class WtiSummerWR2DownWeekContinuationReferenceTest(unittest.TestCase):
    current = date(2026, 7, 13)
    new = current - timedelta(days=7)
    old = current - timedelta(days=14)

    def bars(self, close: float = 98.0, new_range: float = 12.0,
             old_range: float = 10.0) -> tuple[list[Bar], list[Bar]]:
        newest = package(self.new, 5, 100, 104, 104 - new_range, close)
        older = package(self.old, 5, 100, 105, 105 - old_range, 100)
        return newest, older

    def test_expansion_negative_week_is_short(self) -> None:
        self.assertEqual(signal(self.current, *self.bars())[0], -1)

    def test_positive_week_is_flat(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(close=102))[0], 0)

    def test_zero_body_is_flat(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(close=100))[0], 0)

    def test_range_equality_is_flat(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(new_range=10, old_range=10))[0], 0)

    def test_range_contraction_is_flat(self) -> None:
        self.assertEqual(signal(self.current, *self.bars(new_range=8, old_range=10))[0], 0)

    def test_all_five_summer_months_are_eligible(self) -> None:
        self.assertEqual(ELIGIBLE_MONTHS, {6, 7, 8, 9, 10})

    def test_winter_month_is_ineligible(self) -> None:
        with self.assertRaisesRegex(ValueError, "ineligible month"):
            signal(date(2026, 12, 14), *self.bars())

    def test_three_to_five_sessions_are_valid(self) -> None:
        for count in (3, 4, 5):
            newest = package(self.new, count, 100, 106, 94, 98)
            older = package(self.old, count, 100, 105, 95, 100)
            self.assertEqual(signal(self.current, newest, older)[0], -1)

    def test_bad_session_count_refuses(self) -> None:
        with self.assertRaisesRegex(ValueError, "session count"):
            package(self.new, 2, 100, 105, 95, 102)

    def test_nonadjacent_week_refuses(self) -> None:
        newest, older = self.bars()
        shifted = [Bar(bar.day - timedelta(days=7), bar.open, bar.high,
                       bar.low, bar.close) for bar in older]
        with self.assertRaisesRegex(ValueError, "older adjacency"):
            signal(self.current, newest, shifted)


if __name__ == "__main__":
    unittest.main()


