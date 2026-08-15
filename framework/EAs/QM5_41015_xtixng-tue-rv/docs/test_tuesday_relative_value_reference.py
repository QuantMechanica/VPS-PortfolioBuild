"""Independent formula fixtures for QM5_41015.

These tests exercise the locked calendar, package-risk, and equal-notional
contracts without invoking MT5 or reproducing framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest


def day_key(value: dt.datetime) -> int:
    return value.year * 10_000 + value.month * 100 + value.day


def monday_week_key(value: dt.datetime) -> int:
    monday = value - dt.timedelta(days=value.weekday())
    return day_key(monday)


def within_entry_grace(
    broker_now: dt.datetime, labelled_bar_open: dt.datetime, grace_minutes: int
) -> bool:
    elapsed = int((broker_now - labelled_bar_open).total_seconds())
    if elapsed < 0:
        return False
    return elapsed % 86_400 <= grace_minutes * 60


def completed_label_maps_to_monday(completed_label: dt.datetime) -> bool:
    # Factory energy D1 labels use the prior calendar date.
    return (completed_label + dt.timedelta(days=1)).weekday() == 0


def normal_exit_due(value: dt.datetime, exit_hour: int = 21) -> bool:
    return value.weekday() == 1 and value.hour >= exit_hour


def solve_joint_lots(
    full_risk_xti_lots: float,
    full_risk_xng_lots: float,
    xti_notional_per_lot: float,
    xng_notional_per_lot: float,
    xti_step: float = 0.01,
    xng_step: float = 0.01,
) -> tuple[float, float, float, float]:
    lot_ratio = xng_notional_per_lot / xti_notional_per_lot
    normalized_risk_per_xng = (
        lot_ratio / full_risk_xti_lots + 1.0 / full_risk_xng_lots
    )
    raw_xng = 1.0 / normalized_risk_per_xng
    raw_xti = lot_ratio * raw_xng
    xti = math.floor((raw_xti + 1e-12) / xti_step) * xti_step
    xng = math.floor((raw_xng + 1e-12) / xng_step) * xng_step
    normalized_risk = xti / full_risk_xti_lots + xng / full_risk_xng_lots
    ratio = xti * xti_notional_per_lot / (xng * xng_notional_per_lot)
    error_pct = 100.0 * abs(ratio - 1.0)
    return xti, xng, normalized_risk, error_pct


class TuesdayRelativeValueReferenceTests(unittest.TestCase):
    def test_week_key_is_monday_anchored_across_full_week(self) -> None:
        monday = dt.datetime(2026, 8, 10, 0, 0)
        expected = 20260810
        for offset in range(7):
            self.assertEqual(monday_week_key(monday + dt.timedelta(days=offset)), expected)
        self.assertEqual(monday_week_key(monday + dt.timedelta(days=7)), 20260817)

    def test_prior_day_energy_label_grace_uses_modulo_one_day(self) -> None:
        labelled = dt.datetime(2026, 8, 10, 0, 0)  # Monday label
        self.assertTrue(
            within_entry_grace(dt.datetime(2026, 8, 11, 0, 5), labelled, 5)
        )
        self.assertFalse(
            within_entry_grace(dt.datetime(2026, 8, 11, 0, 5, 1), labelled, 5)
        )

    def test_native_same_day_label_grace_is_also_supported(self) -> None:
        labelled = dt.datetime(2026, 8, 11, 0, 0)
        self.assertTrue(
            within_entry_grace(dt.datetime(2026, 8, 11, 0, 4, 59), labelled, 5)
        )

    def test_completed_sunday_label_maps_to_monday_session(self) -> None:
        self.assertTrue(
            completed_label_maps_to_monday(dt.datetime(2026, 8, 9, 0, 0))
        )
        self.assertFalse(
            completed_label_maps_to_monday(dt.datetime(2026, 8, 8, 0, 0))
        )

    def test_normal_exit_is_tuesday_21_only(self) -> None:
        self.assertFalse(normal_exit_due(dt.datetime(2026, 8, 11, 20, 59, 59)))
        self.assertTrue(normal_exit_due(dt.datetime(2026, 8, 11, 21, 0, 0)))
        self.assertFalse(normal_exit_due(dt.datetime(2026, 8, 12, 21, 0, 0)))

    def test_joint_solver_caps_one_package_risk_and_notional_error(self) -> None:
        xti, xng, risk, error = solve_joint_lots(
            full_risk_xti_lots=1.2,
            full_risk_xng_lots=0.8,
            xti_notional_per_lot=70_000.0,
            xng_notional_per_lot=30_000.0,
        )
        self.assertGreater(xti, 0.0)
        self.assertGreater(xng, 0.0)
        self.assertLessEqual(risk, 1.0 + 1e-12)
        self.assertLessEqual(error, 15.0)

    def test_source_asymmetric_tuesday_differentials_are_positive(self) -> None:
        wti = [-0.000348, -0.000285, -0.000086, 0.000001]
        xng = [0.001857, 0.001695, 0.001508, 0.001620]
        differentials = [gas - oil for oil, gas in zip(wti, xng)]
        self.assertEqual(
            [round(value, 6) for value in differentials],
            [0.002205, 0.001980, 0.001594, 0.001619],
        )
        self.assertTrue(all(value > 0.0 for value in differentials))

    def test_package_directions_are_not_interchangeable(self) -> None:
        expected = {"XTIUSD.DWX": "SELL", "XNGUSD.DWX": "BUY"}
        self.assertEqual(expected["XTIUSD.DWX"], "SELL")
        self.assertEqual(expected["XNGUSD.DWX"], "BUY")
        self.assertNotEqual(expected["XTIUSD.DWX"], expected["XNGUSD.DWX"])


if __name__ == "__main__":
    unittest.main()
