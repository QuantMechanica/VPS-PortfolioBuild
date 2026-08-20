from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass(frozen=True)
class PairBar:
    when: datetime
    xau_open: float
    xau_close: float
    xag_open: float
    xag_close: float


@dataclass(frozen=True)
class GapState:
    valid: bool
    direction: int = 0
    xau_gap: float = 0.0
    xag_gap: float = 0.0


def opposed_weekend_gap(current: PairBar, prior: PairBar) -> GapState:
    if current.when.weekday() != 0 or prior.when.weekday() != 4:
        return GapState(False)
    if current.when.date() - prior.when.date() != timedelta(days=3):
        return GapState(False)

    prices = (
        current.xau_open,
        current.xag_open,
        prior.xau_close,
        prior.xag_close,
    )
    if any(price <= 0.0 or not math.isfinite(price) for price in prices):
        return GapState(False)

    xau_gap = math.log(current.xau_open / prior.xau_close)
    xag_gap = math.log(current.xag_open / prior.xag_close)
    if not math.isfinite(xau_gap) or not math.isfinite(xag_gap):
        return GapState(False)
    if xau_gap > 0.0 and xag_gap < 0.0:
        return GapState(True, -1, xau_gap, xag_gap)
    if xau_gap < 0.0 and xag_gap > 0.0:
        return GapState(True, 1, xau_gap, xag_gap)
    return GapState(True, 0, xau_gap, xag_gap)


def rounded_package(
    full_xau_lots: float,
    full_xag_lots: float,
    xau_notional_per_lot: float,
    xag_notional_per_lot: float,
    xau_step: float,
    xag_step: float,
) -> tuple[float, float, float, float]:
    lot_ratio = xag_notional_per_lot / xau_notional_per_lot
    risk_per_xag_lot = lot_ratio / full_xau_lots + 1.0 / full_xag_lots
    raw_xag = 1.0 / risk_per_xag_lot
    raw_xau = lot_ratio * raw_xag
    xau = math.floor((raw_xau + 1.0e-12) / xau_step) * xau_step
    xag = math.floor((raw_xag + 1.0e-12) / xag_step) * xag_step
    normalized_risk = xau / full_xau_lots + xag / full_xag_lots
    actual_ratio = xau * xau_notional_per_lot / (
        xag * xag_notional_per_lot
    )
    mismatch_pct = 100.0 * abs(actual_ratio - 1.0)
    return xau, xag, normalized_risk, mismatch_pct


def baseline() -> tuple[PairBar, PairBar]:
    friday = PairBar(
        datetime(2026, 8, 14),
        xau_open=1980.0,
        xau_close=2000.0,
        xag_open=24.8,
        xag_close=25.0,
    )
    monday = PairBar(
        datetime(2026, 8, 17),
        xau_open=2020.0,
        xau_close=9999.0,
        xag_open=24.5,
        xag_close=0.01,
    )
    return monday, friday


class OpposedWeekendGapReferenceTests(unittest.TestCase):
    def test_xau_up_xag_down_fades_short_ratio(self) -> None:
        monday, friday = baseline()
        state = opposed_weekend_gap(monday, friday)
        self.assertTrue(state.valid)
        self.assertEqual(state.direction, -1)

    def test_xau_down_xag_up_fades_long_ratio(self) -> None:
        monday, friday = baseline()
        reverse = PairBar(
            monday.when,
            xau_open=1980.0,
            xau_close=monday.xau_close,
            xag_open=25.5,
            xag_close=monday.xag_close,
        )
        self.assertEqual(opposed_weekend_gap(reverse, friday).direction, 1)

    def test_same_sign_gaps_are_flat(self) -> None:
        monday, friday = baseline()
        same_sign = PairBar(
            monday.when,
            xau_open=2020.0,
            xau_close=monday.xau_close,
            xag_open=25.5,
            xag_close=monday.xag_close,
        )
        state = opposed_weekend_gap(same_sign, friday)
        self.assertTrue(state.valid)
        self.assertEqual(state.direction, 0)

    def test_zero_component_gap_is_flat(self) -> None:
        monday, friday = baseline()
        zero = PairBar(
            monday.when,
            xau_open=friday.xau_close,
            xau_close=monday.xau_close,
            xag_open=monday.xag_open,
            xag_close=monday.xag_close,
        )
        self.assertEqual(opposed_weekend_gap(zero, friday).direction, 0)

    def test_non_monday_decision_fails(self) -> None:
        monday, friday = baseline()
        tuesday = PairBar(
            monday.when + timedelta(days=1),
            monday.xau_open,
            monday.xau_close,
            monday.xag_open,
            monday.xag_close,
        )
        self.assertFalse(opposed_weekend_gap(tuesday, friday).valid)

    def test_non_immediate_friday_fails(self) -> None:
        monday, friday = baseline()
        stale = PairBar(
            friday.when - timedelta(days=7),
            friday.xau_open,
            friday.xau_close,
            friday.xag_open,
            friday.xag_close,
        )
        self.assertFalse(opposed_weekend_gap(monday, stale).valid)

    def test_current_closes_do_not_affect_signal(self) -> None:
        monday, friday = baseline()
        changed = PairBar(
            monday.when,
            monday.xau_open,
            xau_close=1.0,
            xag_open=monday.xag_open,
            xag_close=1_000_000.0,
        )
        self.assertEqual(
            opposed_weekend_gap(monday, friday).direction,
            opposed_weekend_gap(changed, friday).direction,
        )

    def test_nonpositive_price_fails_closed(self) -> None:
        monday, friday = baseline()
        invalid = PairBar(
            monday.when,
            xau_open=0.0,
            xau_close=monday.xau_close,
            xag_open=monday.xag_open,
            xag_close=monday.xag_close,
        )
        self.assertFalse(opposed_weekend_gap(invalid, friday).valid)

    def test_equal_notional_package_stays_inside_risk_budget(self) -> None:
        xau, xag, normalized_risk, mismatch = rounded_package(
            full_xau_lots=1.2,
            full_xag_lots=4.5,
            xau_notional_per_lot=200_000.0,
            xag_notional_per_lot=5_000.0,
            xau_step=0.01,
            xag_step=0.01,
        )
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(normalized_risk, 1.0 + 1.0e-12)
        self.assertLessEqual(mismatch, 20.0)


if __name__ == "__main__":
    unittest.main()
