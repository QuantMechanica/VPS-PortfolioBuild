"""Deterministic checks for QM5_41428 refinery-ramp weekly reversion."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import date, timedelta


ELIGIBLE_MONTHS = {4, 5, 6, 7}
CLV_LOWER = 1.0 / 3.0


@dataclass(frozen=True)
class Bar:
    session: date
    open: float
    high: float
    low: float
    close: float


def monday_anchor(value: date) -> date:
    return value - timedelta(days=value.weekday())


def ramp_week(anchor: date) -> bool:
    return anchor.month in ELIGIBLE_MONTHS


def signal(current_anchor: date, newest_first: list[Bar]) -> tuple[int, float, float]:
    if not ramp_week(current_anchor):
        raise ValueError("ineligible month")

    expected_new = current_anchor - timedelta(days=7)
    expected_parent = current_anchor - timedelta(days=14)
    new = [bar for bar in newest_first if monday_anchor(bar.session) == expected_new]
    parent = [bar for bar in newest_first if monday_anchor(bar.session) == expected_parent]
    for package in (new, parent):
        if len(package) < 3 or len(package) > 5:
            raise ValueError("session count")
        if len({bar.session for bar in package}) != len(package):
            raise ValueError("duplicate session")
        if any(package[i - 1].session <= package[i].session for i in range(1, len(package))):
            raise ValueError("order")
        if any(
            bar.low <= 0
            or bar.high < bar.low
            or bar.open < bar.low
            or bar.open > bar.high
            or bar.close < bar.low
            or bar.close > bar.high
            for bar in package
        ):
            raise ValueError("price")

    newest_close = new[0].close
    parent_close = parent[0].close
    newest_high = max(bar.high for bar in new)
    newest_low = min(bar.low for bar in new)
    if newest_high <= newest_low:
        raise ValueError("range")
    weekly_return = math.log(newest_close / parent_close)
    close_location = (newest_close - newest_low) / (newest_high - newest_low)
    direction = int(weekly_return < 0.0 and close_location < CLV_LOWER)
    return direction, weekly_return, close_location


def package(anchor: date, closes: list[float], low: float, high: float) -> list[Bar]:
    rows = [
        Bar(anchor + timedelta(days=i), close, high, low, close)
        for i, close in enumerate(closes)
    ]
    return list(reversed(rows))


class WtiRefineryRampCloseLocationReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.current = date(2026, 6, 15)
        self.new_anchor = self.current - timedelta(days=7)
        self.parent_anchor = self.current - timedelta(days=14)

    def bars(self, newest_close: float = 78.0, parent_close: float = 80.0) -> list[Bar]:
        newest = package(self.new_anchor, [81.0, 80.0, 79.5, 79.0, newest_close], 76.0, 84.0)
        parent = package(self.parent_anchor, [78.0, 78.5, 79.0, 79.5, parent_close], 75.0, 82.0)
        return newest + parent

    def test_negative_return_and_lower_tercile_is_long(self) -> None:
        direction, weekly_return, close_location = signal(self.current, self.bars())
        self.assertEqual(direction, 1)
        self.assertLess(weekly_return, 0.0)
        self.assertLess(close_location, CLV_LOWER)

    def test_negative_return_above_lower_tercile_is_flat(self) -> None:
        self.assertEqual(signal(self.current, self.bars(newest_close=80.0, parent_close=81.0))[0], 0)

    def test_positive_return_is_flat(self) -> None:
        self.assertEqual(signal(self.current, self.bars(newest_close=82.0, parent_close=80.0))[0], 0)

    def test_exact_return_zero_is_flat(self) -> None:
        direction, weekly_return, _ = signal(self.current, self.bars(newest_close=80.0, parent_close=80.0))
        self.assertEqual(direction, 0)
        self.assertEqual(weekly_return, 0.0)

    def test_exact_close_location_boundary_is_flat(self) -> None:
        boundary = 76.0 + (84.0 - 76.0) * CLV_LOWER
        direction, _, close_location = signal(
            self.current, self.bars(newest_close=boundary, parent_close=80.0)
        )
        self.assertAlmostEqual(close_location, CLV_LOWER)
        self.assertEqual(direction, 0)

    def test_all_ramp_anchor_months_are_eligible(self) -> None:
        for month in ELIGIBLE_MONTHS:
            self.assertTrue(ramp_week(date(2026, month, 6)))

    def test_nonramp_months_are_ineligible(self) -> None:
        for month in (3, 8, 10):
            self.assertFalse(ramp_week(date(2026, month, 2)))

    def test_monday_anchor_controls_cross_month_week(self) -> None:
        self.assertFalse(ramp_week(date(2026, 3, 30)))
        self.assertTrue(ramp_week(date(2026, 7, 27)))

    def test_three_to_five_sessions_are_accepted(self) -> None:
        for count in (3, 4, 5):
            newest = package(self.new_anchor, [79.0] * (count - 1) + [78.0], 76.0, 84.0)
            parent = package(self.parent_anchor, [77.0] * (count - 1) + [80.0], 75.0, 82.0)
            self.assertEqual(signal(self.current, newest + parent)[0], 1)

    def test_missing_adjacent_parent_week_is_rejected(self) -> None:
        newest = package(self.new_anchor, [78.0, 79.0, 80.0, 81.0, 82.0], 76.0, 84.0)
        stale_parent = package(self.parent_anchor - timedelta(days=7), [76.0, 77.0, 78.0, 79.0, 80.0], 75.0, 82.0)
        with self.assertRaisesRegex(ValueError, "session count"):
            signal(self.current, newest + stale_parent)

    def test_duplicate_session_is_rejected(self) -> None:
        bars = self.bars()
        bars[1] = Bar(bars[0].session, bars[1].open, bars[1].high, bars[1].low, bars[1].close)
        with self.assertRaisesRegex(ValueError, "duplicate session"):
            signal(self.current, bars)

    def test_ineligible_week_refuses_before_signal(self) -> None:
        with self.assertRaisesRegex(ValueError, "ineligible month"):
            signal(date(2026, 11, 2), self.bars())


if __name__ == "__main__":
    unittest.main()
