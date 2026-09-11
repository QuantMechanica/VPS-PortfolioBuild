"""Deterministic reference checks for QM5_41435 WTI hurricane WR2/CLV reversion."""

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


def package(anchor: date, count: int, high: float, low: float, final_close: float,
            first_open: float = 100.0) -> list[Bar]:
    rows = [Bar(anchor + timedelta(days=i), first_open, high, low, (high + low) / 2)
            for i in range(count)]
    rows[-1] = Bar(rows[-1].session, rows[-1].open, high, low, final_close)
    return list(reversed(rows))


def signal(current_anchor: date, newest_first: list[Bar]) -> tuple[int, float, tuple[float, float]]:
    if current_anchor.month not in ELIGIBLE_MONTHS:
        raise ValueError("ineligible month")

    expected = [current_anchor - timedelta(days=7), current_anchor - timedelta(days=14)]
    packs: list[list[Bar]] = []
    for anchor in expected:
        rows = [bar for bar in newest_first if monday_anchor(bar.session) == anchor]
        if len(rows) < 3 or len(rows) > 5:
            raise ValueError("session count")
        if len({bar.session for bar in rows}) != len(rows):
            raise ValueError("duplicate session")
        if any(rows[i - 1].session <= rows[i].session for i in range(1, len(rows))):
            raise ValueError("order")
        if any(bar.low <= 0 or bar.high <= bar.low or not bar.low <= bar.close <= bar.high
               for bar in rows):
            raise ValueError("ohlc")
        packs.append(rows)

    ranges = tuple(max(bar.high for bar in rows) - min(bar.low for bar in rows)
                   for rows in packs)
    newest_close = packs[0][0].close
    newest_low = min(bar.low for bar in packs[0])
    clv = (newest_close - newest_low) / ranges[0]
    return (-1 if ranges[0] > ranges[1] and clv > 0.75 else 0), clv, ranges


class WtiHurricaneWR2CLVFadeReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.current = date(2026, 9, 14)
        self.new = self.current - timedelta(days=7)
        self.old = self.current - timedelta(days=14)

    def bars(self, new_range: float = 20, old_range: float = 10,
             close_location: float = 0.8, new_open: float = 100) -> list[Bar]:
        new_low = 90
        newest = package(self.new, 5, new_low + new_range, new_low,
                         new_low + close_location * new_range, new_open)
        older = package(self.old, 5, 90 + old_range, 90, 95)
        return newest + older

    def test_expansion_upper_quartile_is_short(self) -> None:
        self.assertEqual(signal(self.current, self.bars())[0], -1)

    def test_range_tie_is_flat(self) -> None:
        self.assertEqual(signal(self.current, self.bars(new_range=10, old_range=10))[0], 0)

    def test_contraction_is_flat(self) -> None:
        self.assertEqual(signal(self.current, self.bars(new_range=8, old_range=10))[0], 0)

    def test_clv_equality_is_flat(self) -> None:
        direction, clv, _ = signal(self.current, self.bars(close_location=0.75))
        self.assertEqual(direction, 0)
        self.assertEqual(clv, 0.75)

    def test_below_upper_quartile_is_flat(self) -> None:
        self.assertEqual(signal(self.current, self.bars(close_location=0.7))[0], 0)

    def test_negative_body_can_still_enter(self) -> None:
        self.assertEqual(signal(self.current, self.bars(new_open=109))[0], -1)

    def test_all_eligible_anchor_months(self) -> None:
        self.assertTrue(all(value.month in ELIGIBLE_MONTHS for value in
                            (date(2026, 8, 3), date(2026, 9, 7), date(2026, 10, 5))))

    def test_ineligible_month_refuses(self) -> None:
        with self.assertRaisesRegex(ValueError, "ineligible month"):
            signal(date(2026, 11, 2), self.bars())

    def test_three_to_five_sessions_are_accepted(self) -> None:
        for count in (3, 4, 5):
            newest = package(self.new, count, 110, 90, 106)
            older = package(self.old, count, 100, 90, 95)
            self.assertEqual(signal(self.current, newest + older)[0], -1)

    def test_two_sessions_are_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "session count"):
            signal(self.current, package(self.new, 2, 110, 90, 106) +
                   package(self.old, 5, 100, 90, 95))

    def test_missing_preceding_week_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "session count"):
            signal(self.current, package(self.new, 5, 110, 90, 106))

    def test_duplicate_session_is_rejected(self) -> None:
        bars = self.bars()
        bars[1] = Bar(bars[0].session, bars[1].open, bars[1].high, bars[1].low, bars[1].close)
        with self.assertRaisesRegex(ValueError, "duplicate session"):
            signal(self.current, bars)


if __name__ == "__main__":
    unittest.main()
