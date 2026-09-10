"""Deterministic reference checks for QM5_41411 WTI weekly alternation continuation."""

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


def alternation_signal(
    current_anchor: date, newest_first: list[Bar]
) -> tuple[int, tuple[float, float, float]]:
    """Mirror three adjacent weeks and follow the newest sign on alternation."""
    expected = tuple(current_anchor - timedelta(days=7 * i) for i in (1, 2, 3))
    returns: list[float] = []
    for anchor in expected:
        package = [bar for bar in newest_first if monday_anchor(bar.session) == anchor]
        if len(package) < 3 or len(package) > 5:
            raise ValueError("session count")
        if len({bar.session for bar in package}) != len(package):
            raise ValueError("duplicate session")
        if any(package[i - 1].session <= package[i].session for i in range(1, len(package))):
            raise ValueError("order")
        if any(
            bar.open <= 0
            or bar.close <= 0
            or not math.isfinite(bar.open)
            or not math.isfinite(bar.close)
            for bar in package
        ):
            raise ValueError("price")
        returns.append(math.log(package[0].close / package[-1].open))

    if returns[0] > 0.0 and returns[1] < 0.0 and returns[2] > 0.0:
        direction = 1
    elif returns[0] < 0.0 and returns[1] > 0.0 and returns[2] < 0.0:
        direction = -1
    else:
        direction = 0
    return direction, (returns[0], returns[1], returns[2])


def package(anchor: date, count: int, first_open: float, final_close: float) -> list[Bar]:
    rows = [
        Bar(anchor + timedelta(days=i), first_open + i, first_open + i + 0.25)
        for i in range(count)
    ]
    rows[-1] = Bar(rows[-1].session, rows[-1].open, final_close)
    return list(reversed(rows))


class WtiWeeklyAlternationContinuationReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.current = date(2026, 7, 20)
        self.newest = self.current - timedelta(days=7)
        self.middle = self.current - timedelta(days=14)
        self.oldest = self.current - timedelta(days=21)

    def bars(self, newest: tuple[float, float], middle: tuple[float, float], oldest: tuple[float, float]) -> list[Bar]:
        return (
            package(self.newest, 5, *newest)
            + package(self.middle, 5, *middle)
            + package(self.oldest, 5, *oldest)
        )

    def test_positive_negative_positive_buys(self) -> None:
        self.assertEqual(
            alternation_signal(self.current, self.bars((3, 4), (4, 3), (2, 3)))[0],
            1,
        )

    def test_negative_positive_negative_sells(self) -> None:
        self.assertEqual(
            alternation_signal(self.current, self.bars((4, 3), (3, 4), (3, 2)))[0],
            -1,
        )

    def test_newest_sign_is_followed_not_faded(self) -> None:
        up = alternation_signal(self.current, self.bars((3, 4), (4, 3), (2, 3)))[0]
        down = alternation_signal(self.current, self.bars((4, 3), (3, 4), (3, 2)))[0]
        self.assertEqual((up, down), (1, -1))

    def test_nonalternating_paths_are_flat(self) -> None:
        for values in (
            ((3, 4), (2, 3), (4, 3)),
            ((4, 3), (3, 2), (2, 3)),
            ((3, 4), (2, 3), (1, 2)),
        ):
            self.assertEqual(alternation_signal(self.current, self.bars(*values))[0], 0)

    def test_any_exact_zero_is_flat(self) -> None:
        for values in (
            ((3, 3), (4, 3), (2, 3)),
            ((3, 4), (4, 4), (2, 3)),
            ((3, 4), (4, 3), (2, 2)),
        ):
            self.assertEqual(alternation_signal(self.current, self.bars(*values))[0], 0)

    def test_three_to_five_sessions_are_accepted(self) -> None:
        for count in (3, 4, 5):
            bars = (
                package(self.newest, count, 3, 4)
                + package(self.middle, count, 4, 3)
                + package(self.oldest, count, 2, 3)
            )
            self.assertEqual(alternation_signal(self.current, bars)[0], 1)

    def test_two_and_six_sessions_are_rejected(self) -> None:
        for count in (2, 6):
            bars = (
                package(self.newest, count, 3, 4)
                + package(self.middle, 5, 4, 3)
                + package(self.oldest, 5, 2, 3)
            )
            with self.assertRaisesRegex(ValueError, "session count"):
                alternation_signal(self.current, bars)

    def test_missing_middle_week_is_rejected(self) -> None:
        bars = package(self.newest, 5, 3, 4) + package(self.oldest, 5, 2, 3)
        with self.assertRaisesRegex(ValueError, "session count"):
            alternation_signal(self.current, bars)

    def test_duplicate_session_is_rejected(self) -> None:
        bars = self.bars((3, 4), (4, 3), (2, 3))
        bars[1] = Bar(bars[0].session, bars[1].open, bars[1].close)
        with self.assertRaisesRegex(ValueError, "duplicate session"):
            alternation_signal(self.current, bars)

    def test_year_boundary_adjacency(self) -> None:
        current = date(2027, 1, 4)
        bars = (
            package(date(2026, 12, 28), 5, 3, 4)
            + package(date(2026, 12, 21), 5, 4, 3)
            + package(date(2026, 12, 14), 5, 2, 3)
        )
        self.assertEqual(alternation_signal(current, bars)[0], 1)


if __name__ == "__main__":
    unittest.main()
