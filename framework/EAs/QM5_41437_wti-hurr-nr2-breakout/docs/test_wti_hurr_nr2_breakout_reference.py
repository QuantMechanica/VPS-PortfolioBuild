"""Deterministic reference checks for QM5_41437 WTI hurricane NR2 close breakout."""

from __future__ import annotations

import unittest
from dataclasses import dataclass
from datetime import date, timedelta


ELIGIBLE_MONTHS = {8, 9, 10}


@dataclass(frozen=True)
class Bar:
    session: date
    open: float
    high: float
    low: float
    close: float


def monday_anchor(value: date) -> date:
    return value - timedelta(days=value.weekday())


def package(anchor: date, count: int, high: float, low: float) -> list[Bar]:
    return [Bar(anchor + timedelta(days=i), (high + low) / 2, high, low,
                (high + low) / 2) for i in reversed(range(count))]


def signal(current_anchor: date, current_week: list[Bar],
           completed_weeks: list[Bar]) -> tuple[int, tuple[float, float]]:
    if current_anchor.month not in ELIGIBLE_MONTHS:
        raise ValueError("ineligible month")
    if not current_week:
        raise ValueError("no completed current-week close")
    if any(monday_anchor(bar.session) != current_anchor for bar in current_week):
        raise ValueError("current-week leakage")

    expected = [current_anchor - timedelta(days=7), current_anchor - timedelta(days=14)]
    packs: list[list[Bar]] = []
    for anchor in expected:
        rows = [bar for bar in completed_weeks if monday_anchor(bar.session) == anchor]
        if len(rows) < 3 or len(rows) > 5:
            raise ValueError("session count")
        if len({bar.session for bar in rows}) != len(rows):
            raise ValueError("duplicate session")
        if any(rows[i - 1].session <= rows[i].session for i in range(1, len(rows))):
            raise ValueError("order")
        if any(bar.open <= 0 or bar.low <= 0 or bar.high <= bar.low or
               not bar.low <= bar.open <= bar.high or
               not bar.low <= bar.close <= bar.high for bar in rows):
            raise ValueError("ohlc")
        packs.append(rows)

    ranges = tuple(max(bar.high for bar in rows) - min(bar.low for bar in rows)
                   for rows in packs)
    newest_high = max(bar.high for bar in packs[0])
    newest_low = min(bar.low for bar in packs[0])
    breakout_close = current_week[0].close
    direction = 0
    if ranges[0] < ranges[1]:
        direction = 1 if breakout_close > newest_high else -1 if breakout_close < newest_low else 0
    return direction, ranges


class WtiHurricaneNR2CloseBreakoutReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.current = date(2026, 9, 14)
        self.new = self.current - timedelta(days=7)
        self.old = self.current - timedelta(days=14)

    def history(self, new_range: float = 10, old_range: float = 20) -> list[Bar]:
        return package(self.new, 5, 100, 100 - new_range) + package(
            self.old, 5, 100, 100 - old_range)

    def current_close(self, value: float) -> list[Bar]:
        return [Bar(self.current, 95, max(101, value), min(89, value), value)]

    def test_contraction_upper_close_breakout_is_long(self) -> None:
        self.assertEqual(signal(self.current, self.current_close(101), self.history())[0], 1)

    def test_contraction_lower_close_breakout_is_short(self) -> None:
        self.assertEqual(signal(self.current, self.current_close(89), self.history())[0], -1)

    def test_box_high_equality_is_flat(self) -> None:
        self.assertEqual(signal(self.current, self.current_close(100), self.history())[0], 0)

    def test_box_low_equality_is_flat(self) -> None:
        self.assertEqual(signal(self.current, self.current_close(90), self.history())[0], 0)

    def test_range_tie_is_flat(self) -> None:
        self.assertEqual(signal(self.current, self.current_close(101),
                                self.history(new_range=20, old_range=20))[0], 0)

    def test_expansion_is_flat(self) -> None:
        self.assertEqual(signal(self.current, self.current_close(101),
                                self.history(new_range=20, old_range=10))[0], 0)

    def test_noncontained_contraction_is_allowed(self) -> None:
        newest = package(self.new, 5, 105, 95)
        older = package(self.old, 5, 100, 80)
        self.assertEqual(signal(self.current, self.current_close(106), newest + older)[0], 1)

    def test_ineligible_month_refuses(self) -> None:
        with self.assertRaisesRegex(ValueError, "ineligible month"):
            signal(date(2026, 11, 2), self.current_close(101), self.history())

    def test_no_completed_current_week_close_refuses(self) -> None:
        with self.assertRaisesRegex(ValueError, "no completed"):
            signal(self.current, [], self.history())

    def test_three_to_five_sessions_are_accepted(self) -> None:
        for count in (3, 4, 5):
            history = package(self.new, count, 100, 90) + package(self.old, count, 100, 80)
            self.assertEqual(signal(self.current, self.current_close(101), history)[0], 1)

    def test_missing_preceding_week_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "session count"):
            signal(self.current, self.current_close(101), package(self.new, 5, 100, 90))

    def test_current_week_never_enters_box(self) -> None:
        current = [Bar(self.current + timedelta(days=1), 95, 200, 1, 101)]
        self.assertEqual(signal(self.current, current, self.history())[0], 1)


if __name__ == "__main__":
    unittest.main()
