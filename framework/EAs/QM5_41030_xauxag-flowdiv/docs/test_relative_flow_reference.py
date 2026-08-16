"""Independent mechanic fixtures for QM5_41030.

The tests cover the exact synchronized six-bar calendar, all strict relative-
flow sign outcomes, completed endpoint reconciliation, Monday grace, package
risk/notional rounding, and weekly lifecycle without invoking MT5 or copying
framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest


DAY = dt.timedelta(days=1)


def within_entry_grace(
    broker_now: dt.datetime,
    current_bar_open: dt.datetime,
    grace_minutes: int = 180,
) -> bool:
    elapsed = int((broker_now - current_bar_open).total_seconds())
    return 0 <= elapsed <= grace_minutes * 60


def valid_synchronized_sequence(
    broker_now: dt.datetime,
    xau_current: dt.datetime,
    xag_current: dt.datetime,
    xau_completed: tuple[dt.datetime, ...],
    xag_completed: tuple[dt.datetime, ...],
) -> bool:
    if len(xau_completed) != 6 or len(xag_completed) != 6:
        return False
    expected_weekdays = (4, 3, 2, 1, 0, 4)  # Python Monday=0
    expected_dates = tuple(
        (broker_now - days * DAY).date() for days in (3, 4, 5, 6, 7, 10)
    )
    return (
        broker_now.weekday() == 0
        and xau_current == xag_current
        and xau_current.date() == broker_now.date()
        and xau_completed == xag_completed
        and tuple(value.weekday() for value in xau_completed)
        == expected_weekdays
        and tuple(value.date() for value in xau_completed) == expected_dates
    )


def relative_flow_direction(
    xau_anchor_close: float,
    xag_anchor_close: float,
    xau_bars: tuple[tuple[float, float], ...],
    xag_bars: tuple[tuple[float, float], ...],
) -> tuple[int, float, float, float, float]:
    """Return direction and per-metal components for chronological Mon-Fri."""

    endpoints = (xau_anchor_close, xag_anchor_close)
    if len(xau_bars) != 5 or len(xag_bars) != 5 or not all(
        math.isfinite(value) and value > 0 for value in endpoints
    ):
        return 0, 0.0, 0.0, 0.0, 0.0

    xau_overnight = xag_overnight = 0.0
    xau_session = xag_session = 0.0
    xau_prior = xau_anchor_close
    xag_prior = xag_anchor_close
    for xau_bar, xag_bar in zip(xau_bars, xag_bars):
        values = (*xau_bar, *xag_bar)
        if not all(math.isfinite(value) and value > 0 for value in values):
            return 0, 0.0, 0.0, 0.0, 0.0
        xau_open, xau_close = xau_bar
        xag_open, xag_close = xag_bar
        xau_overnight += math.log(xau_open / xau_prior)
        xag_overnight += math.log(xag_open / xag_prior)
        xau_session += math.log(xau_close / xau_open)
        xag_session += math.log(xag_close / xag_open)
        xau_prior = xau_close
        xag_prior = xag_close

    overnight_relative = xau_overnight - xag_overnight
    session_relative = xau_session - xag_session
    if session_relative > 0 and overnight_relative < 0:
        direction = 1
    elif session_relative < 0 and overnight_relative > 0:
        direction = -1
    else:
        direction = 0
    return (
        direction,
        overnight_relative,
        session_relative,
        xau_overnight + xau_session,
        xag_overnight + xag_session,
    )


def component_bars(
    anchor: float, overnight_factor: float, session_factor: float
) -> tuple[tuple[float, float], ...]:
    bars: list[tuple[float, float]] = []
    prior = anchor
    for _ in range(5):
        day_open = prior * overnight_factor
        day_close = day_open * session_factor
        bars.append((day_open, day_close))
        prior = day_close
    return tuple(bars)


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
    risk_per_xag_lot = lot_ratio / full_xau_lots + 1.0 / full_xag_lots
    raw_xag = 1.0 / risk_per_xag_lot
    raw_xau = lot_ratio * raw_xag
    xau_lots = round_down(raw_xau, xau_step, xau_step)
    xag_lots = round_down(raw_xag, xag_step, xag_step)
    normalized_risk = xau_lots / full_xau_lots + xag_lots / full_xag_lots
    notional_ratio = (
        xau_lots * xau_notional_per_lot
        / (xag_lots * xag_notional_per_lot)
    )
    return xau_lots, xag_lots, normalized_risk, notional_ratio


def week_start(value: dt.datetime) -> dt.date:
    return (value - value.weekday() * DAY).date()


class RelativeFlowReferenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.broker_now = dt.datetime(2026, 8, 17, 1, 0)
        self.current = dt.datetime(2026, 8, 17, 0, 0)
        self.completed = tuple(
            dt.datetime(2026, 8, day, 0, 0)
            for day in (14, 13, 12, 11, 10, 7)
        )

    def test_exact_synchronized_prior_week_is_accepted(self) -> None:
        self.assertTrue(
            valid_synchronized_sequence(
                self.broker_now,
                self.current,
                self.current,
                self.completed,
                self.completed,
            )
        )

    def test_cross_metal_timestamp_mismatch_is_rejected(self) -> None:
        shifted = list(self.completed)
        shifted[2] += dt.timedelta(hours=1)
        self.assertFalse(
            valid_synchronized_sequence(
                self.broker_now,
                self.current,
                self.current,
                self.completed,
                tuple(shifted),
            )
        )

    def test_holiday_broken_week_is_not_substituted(self) -> None:
        broken = tuple(
            dt.datetime(2026, 8, day, 0, 0)
            for day in (14, 12, 11, 10, 7, 6)
        )
        self.assertFalse(
            valid_synchronized_sequence(
                self.broker_now,
                self.current,
                self.current,
                broken,
                broken,
            )
        )

    def test_three_hour_grace_is_inclusive_only_at_boundary(self) -> None:
        self.assertTrue(within_entry_grace(self.current, self.current))
        self.assertTrue(
            within_entry_grace(dt.datetime(2026, 8, 17, 3, 0), self.current)
        )
        self.assertFalse(
            within_entry_grace(dt.datetime(2026, 8, 17, 3, 0, 1), self.current)
        )

    def test_positive_session_negative_overnight_buys_xau(self) -> None:
        xau = component_bars(100.0, 0.99, 1.02)
        xag = component_bars(100.0, 1.01, 0.99)
        direction, overnight, session, _, _ = relative_flow_direction(
            100.0, 100.0, xau, xag
        )
        self.assertEqual(direction, 1)
        self.assertLess(overnight, 0)
        self.assertGreater(session, 0)

    def test_negative_session_positive_overnight_sells_xau(self) -> None:
        xau = component_bars(100.0, 1.01, 0.99)
        xag = component_bars(100.0, 0.99, 1.02)
        direction, overnight, session, _, _ = relative_flow_direction(
            100.0, 100.0, xau, xag
        )
        self.assertEqual(direction, -1)
        self.assertGreater(overnight, 0)
        self.assertLess(session, 0)

    def test_agreement_and_exact_zero_remain_flat(self) -> None:
        rising = component_bars(100.0, 1.01, 1.01)
        unchanged = component_bars(100.0, 1.0, 1.0)
        flat_reference = component_bars(100.0, 1.0, 1.0)
        self.assertEqual(
            relative_flow_direction(100.0, 100.0, rising, flat_reference)[0],
            0,
        )
        self.assertEqual(
            relative_flow_direction(100.0, 100.0, unchanged, unchanged)[0],
            0,
        )

    def test_each_metal_components_reconcile_to_week_return(self) -> None:
        xau = component_bars(100.0, 0.99, 1.02)
        xag = component_bars(80.0, 1.01, 0.99)
        _, _, _, xau_total, xag_total = relative_flow_direction(
            100.0, 80.0, xau, xag
        )
        self.assertAlmostEqual(xau_total, math.log(xau[-1][1] / 100.0))
        self.assertAlmostEqual(xag_total, math.log(xag[-1][1] / 80.0))

    def test_invalid_completed_endpoint_consumes_flat(self) -> None:
        xau = list(component_bars(100.0, 0.99, 1.02))
        xag = component_bars(100.0, 1.01, 0.99)
        xau[2] = (xau[2][0], float("nan"))
        self.assertEqual(
            relative_flow_direction(100.0, 100.0, tuple(xau), xag),
            (0, 0.0, 0.0, 0.0, 0.0),
        )

    def test_joint_sizing_respects_one_risk_budget_and_notional_cap(self) -> None:
        xau_lots, xag_lots, risk, ratio = prepare_equal_notional_package(
            full_xau_lots=1.0,
            full_xag_lots=20.0,
            xau_notional_per_lot=200_000.0,
            xag_notional_per_lot=125_000.0,
        )
        self.assertGreater(xau_lots, 0)
        self.assertGreater(xag_lots, 0)
        self.assertLessEqual(risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_friday_and_later_week_lifecycle_boundaries(self) -> None:
        opened = dt.datetime(2026, 8, 17, 1, 0)
        friday = dt.datetime(2026, 8, 21, 21, 0)
        next_monday = dt.datetime(2026, 8, 24, 0, 1)
        self.assertEqual(friday.weekday(), 4)
        self.assertGreaterEqual(friday.hour, 21)
        self.assertEqual(week_start(opened), week_start(friday))
        self.assertNotEqual(week_start(opened), week_start(next_monday))

    def test_exact_date_attempt_key_is_stable(self) -> None:
        observed = dt.datetime(2026, 8, 17, 2, 0)
        key = observed.year * 10_000 + observed.month * 100 + observed.day
        self.assertEqual(key, 20260817)
        self.assertNotEqual(key, 20260824)


if __name__ == "__main__":
    unittest.main()
