"""Deterministic reference checks for QM5_41461 WTI summer lower-CLV continuation."""

from __future__ import annotations

import unittest
from dataclasses import dataclass
from datetime import date, timedelta


ELIGIBLE_MONTHS = {6, 7, 8, 9, 10}
CLV_CUTOFF = 1.0 / 3.0


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


def signal(current_anchor: date, completed: list[Bar]) -> tuple[int, float]:
    if current_anchor.month not in ELIGIBLE_MONTHS:
        raise ValueError("ineligible month")
    if min(bar.day for bar in completed) != current_anchor - timedelta(days=7):
        raise ValueError("completed-week adjacency")
    if not (3 <= len(completed) <= 5):
        raise ValueError("session count")
    high = max(bar.high for bar in completed)
    low = min(bar.low for bar in completed)
    weekly_range = high - low
    if weekly_range <= 0:
        raise ValueError("weekly range")
    clv = (completed[-1].close - low) / weekly_range
    return (-1 if clv < CLV_CUTOFF else 0, clv)


class WtiSummerLowerClvContinuationReferenceTest(unittest.TestCase):
    current = date(2026, 7, 13)
    prior = current - timedelta(days=7)

    def bars(self, close: float = 95.0, open_: float = 100.0,
             high: float = 110.0, low: float = 90.0,
             count: int = 5) -> list[Bar]:
        return package(self.prior, count, open_, high, low, close)

    def test_lower_tercile_is_short(self) -> None:
        direction, clv = signal(self.current, self.bars())
        self.assertEqual(direction, -1)
        self.assertAlmostEqual(clv, 0.25)

    def test_cutoff_equality_is_flat(self) -> None:
        self.assertEqual(signal(self.current, self.bars(close=96.66666666666667))[0], 0)

    def test_middle_and_upper_closes_are_flat(self) -> None:
        self.assertEqual(signal(self.current, self.bars(close=100.0))[0], 0)
        self.assertEqual(signal(self.current, self.bars(close=108.0))[0], 0)

    def test_positive_body_can_still_signal(self) -> None:
        self.assertEqual(signal(self.current, self.bars(open_=92.0, close=95.0))[0], -1)

    def test_negative_body_can_still_be_flat(self) -> None:
        self.assertEqual(signal(self.current, self.bars(open_=109.0, close=105.0))[0], 0)

    def test_all_five_summer_months_are_eligible(self) -> None:
        self.assertEqual(ELIGIBLE_MONTHS, {6, 7, 8, 9, 10})

    def test_winter_month_is_ineligible(self) -> None:
        with self.assertRaisesRegex(ValueError, "ineligible month"):
            signal(date(2026, 12, 14), self.bars())

    def test_three_to_five_sessions_are_valid(self) -> None:
        for count in (3, 4, 5):
            self.assertEqual(signal(self.current, self.bars(count=count))[0], -1)

    def test_bad_session_count_refuses(self) -> None:
        with self.assertRaisesRegex(ValueError, "session count"):
            package(self.prior, 2, 100, 110, 90, 95)

    def test_nonadjacent_week_refuses(self) -> None:
        shifted = [Bar(bar.day - timedelta(days=7), bar.open, bar.high,
                       bar.low, bar.close) for bar in self.bars()]
        with self.assertRaisesRegex(ValueError, "completed-week adjacency"):
            signal(self.current, shifted)


if __name__ == "__main__":
    unittest.main()
