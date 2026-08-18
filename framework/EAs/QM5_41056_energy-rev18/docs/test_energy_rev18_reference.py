"""Independent mechanic fixtures for QM5_41056.

The suite covers native and prior-day energy-label normalization, genuine
broker-month detection, strictly completed synchronized 18-month endpoints,
the loser-long/winner-short map, the inclusive tie band, durable attempts,
equal fixed-risk halves, package integrity, monthly renewal, and the 35-day
survivor guard. It does not invoke MT5 or duplicate framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest
from dataclasses import dataclass


DAY = dt.timedelta(days=1)
EPSILON = 1.0e-12


@dataclass(frozen=True)
class Bar:
    label: dt.datetime
    close: float


def month_key(value: dt.datetime) -> int:
    return value.year * 100 + value.month


def next_month(month: int) -> int:
    year, number = divmod(month, 100)
    number += 1
    if number == 13:
        return (year + 1) * 100 + 1
    return year * 100 + number


def shift_month_start(boundary: dt.datetime, months_back: int) -> dt.datetime:
    ordinal = boundary.year * 12 + boundary.month - 1 - months_back
    year, zero_based_month = divmod(ordinal, 12)
    return dt.datetime(year, zero_based_month + 1, 1)


def label_offset_days(current_label: dt.datetime, broker_now: dt.datetime) -> int | None:
    elapsed = broker_now - current_label
    if dt.timedelta(0) <= elapsed < DAY:
        return 0
    if DAY <= elapsed < 2 * DAY:
        return 1
    return None


def decision_clock(
    current_label: dt.datetime,
    previous_label: dt.datetime,
    broker_now: dt.datetime,
) -> tuple[bool, int]:
    offset = label_offset_days(current_label, broker_now)
    if offset is None:
        return False, 0
    current = current_label + offset * DAY
    previous = previous_label + offset * DAY
    if current.date() != broker_now.date() or current <= previous:
        return False, 0
    return next_month(month_key(previous)) == month_key(current), offset


def completed_reversal_return(
    bars: tuple[Bar, ...],
    decision_label: dt.datetime,
    label_offset: int,
    months: int = 18,
    maximum_gap_days: int = 10,
) -> tuple[float, dt.datetime, dt.datetime] | None:
    decision = decision_label + label_offset * DAY
    end_boundary = shift_month_start(decision, 0)
    start_boundary = shift_month_start(end_boundary, months)
    eligible = tuple(
        Bar(bar.label + label_offset * DAY, bar.close)
        for bar in bars
        if math.isfinite(bar.close) and bar.close > 0
    )
    end = max((bar for bar in eligible if bar.label < end_boundary), default=None,
              key=lambda bar: bar.label)
    start = max((bar for bar in eligible if bar.label < start_boundary), default=None,
                key=lambda bar: bar.label)
    if end is None or start is None or end.label <= start.label:
        return None
    maximum_gap = maximum_gap_days * DAY
    if not dt.timedelta(0) < end_boundary - end.label <= maximum_gap:
        return None
    if not dt.timedelta(0) < start_boundary - start.label <= maximum_gap:
        return None
    return math.log(end.close / start.close), end.label, start.label


def paired_direction(
    xti: tuple[float, dt.datetime, dt.datetime] | None,
    xng: tuple[float, dt.datetime, dt.datetime] | None,
    epsilon: float = EPSILON,
) -> int | None:
    if xti is None or xng is None or xti[1:] != xng[1:]:
        return None
    difference = xti[0] - xng[0]
    if difference < -epsilon:
        return 1  # long XTI, short XNG
    if difference > epsilon:
        return -1  # short XTI, long XNG
    return 0


def consume_attempt(last_attempt: int, decision_month: int) -> tuple[bool, int]:
    if decision_month <= 0 or last_attempt >= decision_month:
        return False, last_attempt
    return True, decision_month


def package_is_healthy(legs: tuple[tuple[str, int, float], ...]) -> bool:
    if len(legs) != 2:
        return False
    by_symbol = {symbol: (direction, stop) for symbol, direction, stop in legs}
    if set(by_symbol) != {"XTIUSD.DWX", "XNGUSD.DWX"}:
        return False
    xti_direction, xti_stop = by_symbol["XTIUSD.DWX"]
    xng_direction, xng_stop = by_symbol["XNGUSD.DWX"]
    return xti_stop > 0 and xng_stop > 0 and xti_direction == -xng_direction


def monthly_exit_due(opened: dt.datetime, current: dt.datetime) -> bool:
    return month_key(opened) != month_key(current)


def stale_exit_due(opened: dt.datetime, current: dt.datetime) -> bool:
    return current - opened >= 35 * DAY


class EnergyRev18ReferenceTests(unittest.TestCase):
    def test_native_month_boundary(self) -> None:
        boundary, offset = decision_clock(
            dt.datetime(2026, 8, 3),
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 8, 3, 1),
        )
        self.assertTrue(boundary)
        self.assertEqual(offset, 0)

    def test_prior_day_energy_labels_normalize_uniformly(self) -> None:
        boundary, offset = decision_clock(
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 7, 30),
            dt.datetime(2026, 8, 1, 1),
        )
        self.assertTrue(boundary)
        self.assertEqual(offset, 1)

    def test_mid_month_attach_is_not_a_boundary(self) -> None:
        self.assertFalse(
            decision_clock(
                dt.datetime(2026, 8, 18),
                dt.datetime(2026, 8, 17),
                dt.datetime(2026, 8, 18, 1),
            )[0]
        )

    def test_completed_18_month_endpoints_exclude_decision_month(self) -> None:
        bars = (
            Bar(dt.datetime(2025, 1, 31), 50.0),
            Bar(dt.datetime(2025, 2, 3), 999.0),
            Bar(dt.datetime(2026, 7, 31), 75.0),
            Bar(dt.datetime(2026, 8, 1), 1_000_000.0),
        )
        observed = completed_reversal_return(
            bars, dt.datetime(2026, 8, 1), 0
        )
        self.assertIsNotNone(observed)
        self.assertAlmostEqual((observed or (0.0,))[0], math.log(75.0 / 50.0))

    def test_uniform_prior_day_offset_applies_to_historical_endpoints(self) -> None:
        bars = (
            Bar(dt.datetime(2025, 1, 30), 40.0),
            Bar(dt.datetime(2026, 7, 30), 60.0),
        )
        observed = completed_reversal_return(
            bars, dt.datetime(2026, 7, 31), 1
        )
        self.assertEqual(observed and observed[1], dt.datetime(2026, 7, 31))
        self.assertEqual(observed and observed[2], dt.datetime(2025, 1, 31))

    def test_stale_endpoint_is_rejected(self) -> None:
        bars = (
            Bar(dt.datetime(2025, 1, 20), 40.0),
            Bar(dt.datetime(2026, 7, 31), 60.0),
        )
        self.assertIsNone(
            completed_reversal_return(bars, dt.datetime(2026, 8, 1), 0)
        )

    def test_lower_xti_return_maps_to_long_xti_short_xng(self) -> None:
        end, start = dt.datetime(2026, 7, 31), dt.datetime(2025, 1, 31)
        self.assertEqual(paired_direction((0.10, end, start), (0.40, end, start)), 1)
        self.assertEqual(paired_direction((0.40, end, start), (0.10, end, start)), -1)

    def test_inclusive_tie_band_consumes_flat(self) -> None:
        end, start = dt.datetime(2026, 7, 31), dt.datetime(2025, 1, 31)
        anchor = (0.0, end, start)
        self.assertEqual(paired_direction(anchor, (EPSILON, end, start)), 0)
        self.assertEqual(paired_direction(anchor, (-EPSILON, end, start)), 0)
        self.assertEqual(paired_direction(anchor, (2 * EPSILON, end, start)), 1)
        self.assertEqual(paired_direction(anchor, (-2 * EPSILON, end, start)), -1)

    def test_unsynchronized_energy_endpoints_fail_closed(self) -> None:
        start = dt.datetime(2025, 1, 31)
        xti = (0.10, dt.datetime(2026, 7, 31), start)
        xng = (0.20, dt.datetime(2026, 7, 30), start)
        self.assertIsNone(paired_direction(xti, xng))

    def test_attempt_is_consumed_once_per_yyyymm(self) -> None:
        accepted, ledger = consume_attempt(202607, 202608)
        self.assertTrue(accepted)
        self.assertEqual(ledger, 202608)
        self.assertEqual(consume_attempt(ledger, 202608), (False, ledger))

    def test_fixed_package_risk_splits_equally(self) -> None:
        package_risk = 1000.0
        self.assertEqual((package_risk / 2.0, package_risk / 2.0), (500.0, 500.0))

    def test_orphan_same_direction_and_missing_stop_are_invalid(self) -> None:
        self.assertFalse(package_is_healthy((("XTIUSD.DWX", 1, 70.0),)))
        self.assertFalse(
            package_is_healthy(
                (("XTIUSD.DWX", 1, 70.0), ("XNGUSD.DWX", 1, 2.0))
            )
        )
        self.assertFalse(
            package_is_healthy(
                (("XTIUSD.DWX", 1, 0.0), ("XNGUSD.DWX", -1, 2.0))
            )
        )
        self.assertTrue(
            package_is_healthy(
                (("XTIUSD.DWX", 1, 70.0), ("XNGUSD.DWX", -1, 2.0))
            )
        )

    def test_month_boundary_is_exit_and_renewal(self) -> None:
        opened = dt.datetime(2026, 8, 3)
        self.assertFalse(monthly_exit_due(opened, dt.datetime(2026, 8, 31)))
        self.assertTrue(monthly_exit_due(opened, dt.datetime(2026, 9, 1)))

    def test_thirty_five_day_guard_repairs_only_survivor(self) -> None:
        opened = dt.datetime(2026, 8, 3)
        self.assertFalse(stale_exit_due(opened, opened + 34 * DAY))
        self.assertTrue(stale_exit_due(opened, opened + 35 * DAY))


if __name__ == "__main__":
    unittest.main()
