"""Deterministic reference checks for QM5_41376 CMOM4,2 WTI momentum."""

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


def package(anchor: date, count: int, first_open: float, final_close: float) -> list[Bar]:
    rows = [Bar(anchor + timedelta(days=i), first_open + i, first_open + i + 0.25) for i in range(count)]
    rows[-1] = Bar(rows[-1].session, rows[-1].open, final_close)
    return list(reversed(rows))


def cmom42_signal(current: date, newest_first: list[Bar]) -> tuple[int, float, float, float]:
    anchors = [current - timedelta(days=7 * i) for i in range(1, 5)]
    weeks: list[list[Bar]] = []
    for anchor in anchors:
        rows = [bar for bar in newest_first if monday_anchor(bar.session) == anchor]
        if len(rows) < 3 or len(rows) > 5:
            raise ValueError("session count")
        if len({bar.session for bar in rows}) != len(rows):
            raise ValueError("duplicate session")
        if any(rows[i - 1].session <= rows[i].session for i in range(1, len(rows))):
            raise ValueError("order")
        if any(bar.open <= 0 or bar.close <= 0 for bar in rows):
            raise ValueError("price")
        weeks.append(rows)
    first_open_t4 = weeks[3][-1].open
    final_close_t2 = weeks[1][0].close
    value = math.log(final_close_t2 / first_open_t4)
    return (1 if value > 0 else -1 if value < 0 else 0, first_open_t4, final_close_t2, value)


class Cmom42ReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.current = date(2026, 2, 2)

    def rows(self, t4_open: float = 70, t2_close: float = 75, t1_close: float = 500) -> list[Bar]:
        return sum(
            (
                package(self.current - timedelta(days=7), 5, 90, t1_close),
                package(self.current - timedelta(days=14), 5, 80, t2_close),
                package(self.current - timedelta(days=21), 4, 75, 78),
                package(self.current - timedelta(days=28), 3, t4_open, 74),
            ),
            [],
        )

    def test_positive_formation_is_long(self) -> None:
        self.assertEqual(cmom42_signal(self.current, self.rows())[0], 1)

    def test_negative_formation_is_short(self) -> None:
        self.assertEqual(cmom42_signal(self.current, self.rows(80, 70))[0], -1)

    def test_exact_zero_is_flat(self) -> None:
        self.assertEqual(cmom42_signal(self.current, self.rows(70, 70))[0], 0)

    def test_t1_is_completely_excluded(self) -> None:
        positive = cmom42_signal(self.current, self.rows(t1_close=500))
        negative_t1 = cmom42_signal(self.current, self.rows(t1_close=1))
        self.assertEqual(positive, negative_t1)

    def test_exact_endpoints_are_t4_open_and_t2_close(self) -> None:
        self.assertEqual(cmom42_signal(self.current, self.rows())[1:3], (70, 75))

    def test_two_session_week_is_rejected(self) -> None:
        rows = self.rows()
        t3 = self.current - timedelta(days=21)
        rows = [bar for bar in rows if monday_anchor(bar.session) != t3] + package(t3, 2, 75, 78)
        with self.assertRaisesRegex(ValueError, "session count"):
            cmom42_signal(self.current, rows)

    def test_six_session_week_is_rejected(self) -> None:
        rows = self.rows()
        t2 = self.current - timedelta(days=14)
        rows = [bar for bar in rows if monday_anchor(bar.session) != t2] + package(t2, 6, 80, 75)
        with self.assertRaisesRegex(ValueError, "session count"):
            cmom42_signal(self.current, rows)

    def test_year_boundary(self) -> None:
        current = date(2026, 1, 5)
        rows = sum((package(current - timedelta(days=7 * i), 5, 70 + i, 71 + i) for i in range(1, 5)), [])
        self.assertIn(cmom42_signal(current, rows)[0], (-1, 1))

    def test_duplicate_session_is_rejected(self) -> None:
        rows = self.rows()
        rows[1] = Bar(rows[0].session, rows[1].open, rows[1].close)
        with self.assertRaisesRegex(ValueError, "duplicate session"):
            cmom42_signal(self.current, rows)

    def test_current_week_is_ignored(self) -> None:
        baseline = cmom42_signal(self.current, self.rows())
        rows = [Bar(self.current, 1, 999)] + self.rows()
        self.assertEqual(cmom42_signal(self.current, rows), baseline)


if __name__ == "__main__":
    unittest.main()
