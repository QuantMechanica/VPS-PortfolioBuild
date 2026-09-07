"""Deterministic reference checks for QM5_41378 CMOM26,5 translation."""

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
    rows = [
        Bar(anchor + timedelta(days=i), first_open + i * 0.01, first_open + i * 0.01)
        for i in range(count)
    ]
    rows[-1] = Bar(rows[-1].session, rows[-1].open, final_close)
    return list(reversed(rows))


def cmom265_signal(current: date, newest_first: list[Bar]) -> tuple[int, float, float, float]:
    weeks: list[list[Bar]] = []
    for lag in range(1, 27):
        anchor = current - timedelta(days=7 * lag)
        rows = [bar for bar in newest_first if monday_anchor(bar.session) == anchor]
        if len(rows) < 2 or len(rows) > 5:
            raise ValueError("session count")
        if len({bar.session for bar in rows}) != len(rows):
            raise ValueError("duplicate session")
        if any(rows[i - 1].session <= rows[i].session for i in range(1, len(rows))):
            raise ValueError("order")
        if any(bar.open <= 0 or bar.close <= 0 for bar in rows):
            raise ValueError("price")
        weeks.append(rows)

    formation_open = weeks[25][-1].open
    formation_close = weeks[4][0].close
    value = math.log(formation_close / formation_open)
    direction = 1 if value > 0 else (-1 if value < 0 else 0)
    return direction, value, formation_open, formation_close


class HalfYearWeeklyMomentumReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.current = date(2026, 7, 6)

    def rows(self, *, old_open: float = 70.0, t5_close: float = 80.0) -> list[Bar]:
        result: list[Bar] = []
        for lag in range(1, 27):
            first_open = old_open if lag == 26 else 74.0 + lag * 0.1
            final_close = t5_close if lag == 5 else first_open + 0.5
            result.extend(package(self.current - timedelta(days=7 * lag), 4, first_open, final_close))
        return result

    def test_positive_is_long(self) -> None:
        self.assertEqual(cmom265_signal(self.current, self.rows())[0], 1)

    def test_negative_is_short(self) -> None:
        self.assertEqual(cmom265_signal(self.current, self.rows(old_open=90, t5_close=75))[0], -1)

    def test_equal_is_flat(self) -> None:
        self.assertEqual(cmom265_signal(self.current, self.rows(old_open=80, t5_close=80))[0], 0)

    def test_exact_endpoints(self) -> None:
        self.assertEqual(cmom265_signal(self.current, self.rows())[2:], (70.0, 80.0))

    def test_recent_four_weeks_are_signal_inert(self) -> None:
        baseline = cmom265_signal(self.current, self.rows())
        rows = [bar for bar in self.rows() if monday_anchor(bar.session) < self.current - timedelta(days=28)]
        for lag in range(1, 5):
            rows.extend(package(self.current - timedelta(days=7 * lag), 3, 1000 * lag, 0.5 + lag))
        self.assertEqual(cmom265_signal(self.current, rows), baseline)

    def test_two_session_week_is_accepted(self) -> None:
        rows = [bar for bar in self.rows() if monday_anchor(bar.session) != self.current - timedelta(days=70)]
        rows.extend(package(self.current - timedelta(days=70), 2, 76, 77))
        self.assertIn(cmom265_signal(self.current, rows)[0], (-1, 0, 1))

    def test_five_session_week_is_accepted(self) -> None:
        rows = [bar for bar in self.rows() if monday_anchor(bar.session) != self.current - timedelta(days=70)]
        rows.extend(package(self.current - timedelta(days=70), 5, 76, 77))
        self.assertIn(cmom265_signal(self.current, rows)[0], (-1, 0, 1))

    def test_one_session_week_is_rejected(self) -> None:
        rows = [bar for bar in self.rows() if monday_anchor(bar.session) != self.current - timedelta(days=70)]
        rows.extend(package(self.current - timedelta(days=70), 1, 76, 77))
        with self.assertRaisesRegex(ValueError, "session count"):
            cmom265_signal(self.current, rows)

    def test_six_session_week_is_rejected(self) -> None:
        rows = [bar for bar in self.rows() if monday_anchor(bar.session) != self.current - timedelta(days=70)]
        rows.extend(package(self.current - timedelta(days=70), 6, 76, 77))
        with self.assertRaisesRegex(ValueError, "session count"):
            cmom265_signal(self.current, rows)

    def test_missing_week_is_rejected(self) -> None:
        rows = [bar for bar in self.rows() if monday_anchor(bar.session) != self.current - timedelta(days=98)]
        with self.assertRaisesRegex(ValueError, "session count"):
            cmom265_signal(self.current, rows)

    def test_duplicate_session_is_rejected(self) -> None:
        rows = self.rows()
        rows[1] = Bar(rows[0].session, rows[1].open, rows[1].close)
        with self.assertRaisesRegex(ValueError, "duplicate session"):
            cmom265_signal(self.current, rows)

    def test_year_boundary(self) -> None:
        current = date(2026, 1, 5)
        rows = []
        for lag in range(1, 27):
            rows.extend(package(current - timedelta(days=7 * lag), 4, 70 + lag, 71 + lag))
        self.assertIn(cmom265_signal(current, rows)[0], (-1, 0, 1))

    def test_current_week_is_ignored(self) -> None:
        baseline = cmom265_signal(self.current, self.rows())
        rows = [Bar(self.current, 1, 999)] + self.rows()
        self.assertEqual(cmom265_signal(self.current, rows), baseline)

    def test_nonpositive_endpoint_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "price"):
            cmom265_signal(self.current, self.rows(old_open=0))


if __name__ == "__main__":
    unittest.main()
