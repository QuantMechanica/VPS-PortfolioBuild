"""Unit tests for the ratified partial-year pro-rata activity criterion.

Rule (OWNER 2026-08-21, CEO-MP-#4; docs/ops/ACTIVITY_CRITERION.md §R):

  - Full scored year: >= 10 distinct entry days.
  - Boundary/partial year with >= 3 covered months: threshold
    ceil(10 * covered_months / 12) distinct days.
  - Boundary year with < 3 covered months: skipped (not scored, not failed),
    but the skip must stay visible in the output.
  - Counting basis = entry day.

These tests exercise the pure helpers (covered_months, partial_threshold,
scored_years) and the classify() integration.  They do not touch the
filesystem/DB, so importing the module is safe.
"""
from __future__ import annotations

import datetime as dt
import unittest

from tools.strategy_farm.portfolio import audit_activity_criterion as ac


def D(y, m, d):
    return dt.date(y, m, d)


class PartialThresholdTests(unittest.TestCase):
    def test_scaled_thresholds(self):
        # ceil(10 * m / 12) at the anchor points named in the ratified rule.
        self.assertEqual(ac.partial_threshold(3), 3)   # 3-month -> 3
        self.assertEqual(ac.partial_threshold(6), 5)   # 6-month -> 5
        self.assertEqual(ac.partial_threshold(12), 10)  # full -> 10
        self.assertEqual(ac.partial_threshold(2), 2)   # (only used if >=3 mo)


class CoveredMonthsTests(unittest.TestCase):
    def test_first_boundary_year_runs_to_december(self):
        # data starts 2019-09-10; first year covers Sep..Dec = 4 months.
        self.assertEqual(ac.covered_months(D(2019, 9, 10), D(2022, 3, 5), 2019), 4)

    def test_last_boundary_year_runs_from_january(self):
        # data ends 2022-03-05; last year covers Jan..Mar = 3 months.
        self.assertEqual(ac.covered_months(D(2019, 9, 10), D(2022, 3, 5), 2022), 3)

    def test_single_year_span(self):
        self.assertEqual(ac.covered_months(D(2020, 2, 1), D(2020, 11, 30), 2020), 10)

    def test_two_month_last_year(self):
        self.assertEqual(ac.covered_months(D(2021, 11, 5), D(2023, 2, 20), 2023), 2)


class ScoredYearsTests(unittest.TestCase):
    def test_full_inner_year_9_vs_10(self):
        # 3-year span; boundaries pass comfortably, isolate the inner full year.
        first, last = D(2019, 6, 1), D(2021, 6, 30)
        below = {2019: 9, 2020: 9, 2021: 9}
        res = ac.scored_years(below, first, last)
        # inner year 2020 requires 10; it has 9 -> fail.
        self.assertEqual(res["scored"][2020], 10)
        self.assertIn(2020, res["below"])
        self.assertFalse(res["meets"])
        # bump the inner year to 10 -> the whole pair meets.
        ok = ac.scored_years({2019: 9, 2020: 10, 2021: 9}, first, last)
        self.assertNotIn(2020, ok["below"])
        self.assertTrue(ok["meets"])

    def test_three_month_partial_threshold_is_3(self):
        # first year covers Oct..Dec = 3 months -> threshold 3.
        first, last = D(2020, 10, 1), D(2021, 12, 31)
        res = ac.scored_years({2020: 3, 2021: 15}, first, last)
        self.assertEqual(res["scored"][2020], 3)
        self.assertTrue(res["meets"])
        fail = ac.scored_years({2020: 2, 2021: 15}, first, last)
        self.assertIn(2020, fail["below"])
        self.assertFalse(fail["meets"])

    def test_two_month_partial_is_skipped(self):
        # first year covers Nov..Dec = 2 months (< 3) -> skipped, never fails.
        first, last = D(2020, 11, 1), D(2021, 12, 31)
        res = ac.scored_years({2020: 1, 2021: 15}, first, last)
        self.assertIn(2020, res["skipped"])
        self.assertEqual(res["skipped"][2020], 2)
        self.assertNotIn(2020, res["scored"])
        self.assertNotIn(2020, res["below"])
        self.assertTrue(res["meets"])  # qualifies on 2021 alone

    def test_six_month_partial_threshold_is_5(self):
        # last year covers Jul..Dec = 6 months -> threshold 5.
        first, last = D(2019, 1, 1), D(2020, 12, 31)
        # 2019 is first boundary (full year, 12 months -> thr 10); 2020 last.
        res = ac.scored_years({2019: 12, 2020: 5}, first, last)
        self.assertEqual(res["scored"][2020], 10)  # Jan..Dec = full
        # Now make 2020 a genuine 6-month boundary.
        first2, last2 = D(2019, 1, 1), D(2020, 6, 30)
        res2 = ac.scored_years({2019: 12, 2020: 5}, first2, last2)
        self.assertEqual(res2["scored"][2020], 5)
        self.assertTrue(res2["meets"])
        fail = ac.scored_years({2019: 12, 2020: 4}, first2, last2)
        self.assertIn(2020, fail["below"])
        self.assertFalse(fail["meets"])

    def test_empty(self):
        res = ac.scored_years({}, D(2020, 1, 1), D(2020, 1, 1))
        self.assertFalse(res["meets"])
        self.assertEqual(res["scored"], {})


class YearBoundaryAndLeapTests(unittest.TestCase):
    def test_per_year_days_splits_on_calendar_year(self):
        # entry-day index (0): 2020-02-29 (leap), 2020-12-31, 2021-01-01.
        ev = [
            (D(2020, 2, 29), D(2020, 3, 2), 1.0),
            (D(2020, 12, 31), D(2021, 1, 2), 1.0),
            (D(2021, 1, 1), D(2021, 1, 3), 1.0),
        ]
        by_entry = ac.per_year_days(ev, 0)
        self.assertEqual(by_entry[2020], 2)  # Feb 29 + Dec 31
        self.assertEqual(by_entry[2021], 1)

    def test_leap_day_counts_as_distinct_entry_day(self):
        ev = [(D(2020, 2, 29), D(2020, 2, 29), 1.0)]
        by_entry = ac.per_year_days(ev, 0)
        self.assertEqual(by_entry[2020], 1)


class ClassifyIntegrationTests(unittest.TestCase):
    def _entries(self, year, n, start_month=1):
        # n distinct entry days in `year`, one trade each (entry==close day).
        out = []
        d = dt.date(year, start_month, 1)
        for _ in range(n):
            out.append((d, d, 1.0))
            d += dt.timedelta(days=1)
        return out

    def test_qualifying_multi_year_pair_entry_basis(self):
        ev = (
            self._entries(2019, 12, start_month=9)   # boundary: Sep.. -> 4 mo, thr 4
            + self._entries(2020, 12)                # full inner year, thr 10
            + self._entries(2021, 12)                # last boundary: Jan only -> <3mo, skipped
        )
        rec = ac.classify(ev, coverage=1.0)
        self.assertTrue(rec["meets_10_per_year_entry"])
        self.assertEqual(rec["years_below_criterion_entry"], [])

    def test_full_inner_year_shortfall_fails(self):
        ev = (
            self._entries(2019, 12, start_month=9)
            + self._entries(2020, 9)                 # inner year, only 9 -> fail
            + self._entries(2021, 12)
        )
        rec = ac.classify(ev, coverage=1.0)
        self.assertFalse(rec["meets_10_per_year_entry"])
        self.assertIn(2020, rec["years_below_criterion_entry"])

    def test_short_partial_boundary_is_visible_and_not_fatal(self):
        # 2019 boundary covers only Dec = 1 month -> skipped, must not fail.
        ev = (
            self._entries(2019, 1, start_month=12)
            + self._entries(2020, 12)
            + self._entries(2021, 12)
        )
        rec = ac.classify(ev, coverage=1.0)
        self.assertIn(2019, rec["skipped_partial_years_entry"])
        self.assertNotIn(2019, rec["years_below_criterion_entry"])
        self.assertTrue(rec["meets_10_per_year_entry"])


if __name__ == "__main__":
    unittest.main()
