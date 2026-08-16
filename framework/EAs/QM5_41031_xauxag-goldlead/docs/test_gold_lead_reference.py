"""Independent mechanic fixtures for QM5_41031.

These tests cover synchronized completed endpoints, asymmetric gold-only
lead boundaries, entry grace, date attempts, package sizing, and the first
following D1 lifecycle without invoking MT5 order plumbing.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest


def within_entry_grace(
    broker_now: dt.datetime,
    current_bar_open: dt.datetime,
    grace_minutes: int = 180,
) -> bool:
    elapsed = int((broker_now - current_bar_open).total_seconds())
    return 0 <= elapsed <= grace_minutes * 60


def synchronized_two_close_window(
    current_xau: dt.datetime,
    current_xag: dt.datetime,
    completed_xau: tuple[dt.datetime, ...],
    completed_xag: tuple[dt.datetime, ...],
) -> bool:
    if len(completed_xau) != 2 or len(completed_xag) != 2:
        return False
    if current_xau != current_xag or completed_xau != completed_xag:
        return False
    gaps = (
        (current_xau - completed_xau[0]).total_seconds(),
        (completed_xau[0] - completed_xau[1]).total_seconds(),
    )
    return all(20 * 3600 <= gap <= 96 * 3600 for gap in gaps)


def gold_lead_direction(
    xau_new: float,
    xau_old: float,
    xag_new: float,
    xag_old: float,
    shock: float = 0.0075,
    response: float = 0.50,
) -> tuple[int, float, float]:
    values = (xau_new, xau_old, xag_new, xag_old)
    if not all(math.isfinite(value) and value > 0.0 for value in values):
        return 0, 0.0, 0.0
    gold = math.log(xau_new / xau_old)
    silver = math.log(xag_new / xag_old)
    return direction_from_returns(gold, silver, shock, response), gold, silver


def direction_from_returns(
    gold: float,
    silver: float,
    shock: float = 0.0075,
    response: float = 0.50,
) -> int:
    """Apply the exact authorized inequalities to already-computed returns."""

    if not math.isfinite(gold) or not math.isfinite(silver):
        return 0
    if gold >= shock and silver < response * gold and abs(silver) <= abs(gold):
        return -1
    if gold <= -shock and silver > response * gold and abs(silver) <= abs(gold):
        return 1
    return 0


def round_down(value: float, step: float, minimum: float) -> float:
    rounded = math.floor((value + 1e-12) / step) * step
    return rounded if rounded + 1e-12 >= minimum else 0.0


def prepare_equal_notional_package(
    full_xau_lots: float,
    full_xag_lots: float,
    xau_notional_per_lot: float,
    xag_notional_per_lot: float,
    xau_step: float = 0.01,
    xag_step: float = 0.01,
) -> tuple[float, float, float, float]:
    lot_ratio = xag_notional_per_lot / xau_notional_per_lot
    risk_per_xag = lot_ratio / full_xau_lots + 1.0 / full_xag_lots
    xag_lots = round_down(1.0 / risk_per_xag, xag_step, xag_step)
    xau_lots = round_down(lot_ratio / risk_per_xag, xau_step, xau_step)
    risk = xau_lots / full_xau_lots + xag_lots / full_xag_lots
    ratio = (
        xau_lots * xau_notional_per_lot
        / (xag_lots * xag_notional_per_lot)
    )
    return xau_lots, xag_lots, risk, ratio


class GoldLeadReferenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.current = dt.datetime(2026, 8, 17)
        self.completed = (
            dt.datetime(2026, 8, 14),
            dt.datetime(2026, 8, 13),
        )

    def prices(self, gold: float, silver: float) -> tuple[float, ...]:
        return math.exp(gold), 1.0, math.exp(silver), 1.0

    def test_synchronized_two_close_window_accepts_weekend_gap(self) -> None:
        self.assertTrue(
            synchronized_two_close_window(
                self.current, self.current, self.completed, self.completed
            )
        )

    def test_cross_metal_timestamp_mismatch_is_rejected(self) -> None:
        shifted = (self.completed[0], self.completed[1] - dt.timedelta(hours=1))
        self.assertFalse(
            synchronized_two_close_window(
                self.current, self.current, self.completed, shifted
            )
        )

    def test_entry_grace_is_inclusive_only_at_three_hours(self) -> None:
        self.assertTrue(within_entry_grace(self.current, self.current))
        self.assertTrue(within_entry_grace(self.current + dt.timedelta(hours=3), self.current))
        self.assertFalse(
            within_entry_grace(self.current + dt.timedelta(hours=3, seconds=1), self.current)
        )

    def test_positive_gold_lead_sells_xau_and_buys_xag(self) -> None:
        direction, gold, silver = gold_lead_direction(*self.prices(0.0100, 0.0040))
        self.assertEqual(direction, -1)
        self.assertGreater(gold, 0.0)
        self.assertGreater(silver, 0.0)

    def test_negative_gold_lead_buys_xau_and_sells_xag(self) -> None:
        direction, gold, silver = gold_lead_direction(*self.prices(-0.0100, -0.0040))
        self.assertEqual(direction, 1)
        self.assertLess(gold, 0.0)
        self.assertLess(silver, 0.0)

    def test_gold_threshold_is_inclusive(self) -> None:
        self.assertEqual(direction_from_returns(0.0075, 0.0030), -1)
        self.assertEqual(direction_from_returns(-0.0075, -0.0030), 1)

    def test_response_equality_and_gold_subthreshold_are_flat(self) -> None:
        self.assertEqual(direction_from_returns(0.0100, 0.0050), 0)
        self.assertEqual(direction_from_returns(-0.0100, -0.0050), 0)
        self.assertEqual(direction_from_returns(0.0074, 0.0), 0)

    def test_excessive_opposite_silver_move_is_flat(self) -> None:
        self.assertEqual(gold_lead_direction(*self.prices(0.0100, -0.0110))[0], 0)
        self.assertEqual(gold_lead_direction(*self.prices(-0.0100, 0.0110))[0], 0)

    def test_silver_never_leads_gold(self) -> None:
        self.assertEqual(gold_lead_direction(*self.prices(0.0020, 0.0200))[0], 0)

    def test_invalid_completed_endpoint_consumes_flat(self) -> None:
        self.assertEqual(gold_lead_direction(float("nan"), 1.0, 1.0, 1.0), (0, 0.0, 0.0))
        self.assertEqual(gold_lead_direction(1.0, 0.0, 1.0, 1.0), (0, 0.0, 0.0))

    def test_joint_sizing_respects_package_risk_and_notional_cap(self) -> None:
        xau, xag, risk, ratio = prepare_equal_notional_package(
            full_xau_lots=1.0,
            full_xag_lots=20.0,
            xau_notional_per_lot=200_000.0,
            xag_notional_per_lot=125_000.0,
        )
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_first_following_d1_boundary_closes_package(self) -> None:
        entry = dt.datetime(2026, 8, 17, 0, 5)
        same_bar = dt.datetime(2026, 8, 17)
        next_bar = dt.datetime(2026, 8, 18)
        self.assertFalse(same_bar > entry)
        self.assertTrue(next_bar > entry)

    def test_exact_date_attempt_key_is_stable(self) -> None:
        observed = dt.datetime(2026, 8, 17, 2)
        key = observed.year * 10_000 + observed.month * 100 + observed.day
        self.assertEqual(key, 20260817)
        self.assertNotEqual(key, 20260818)


if __name__ == "__main__":
    unittest.main()
