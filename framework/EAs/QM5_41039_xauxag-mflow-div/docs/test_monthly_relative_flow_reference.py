"""Independent mechanic fixtures for QM5_41039.

These tests reproduce the approved synchronized broker-month selector,
gold-minus-silver flow arithmetic, strict opposition rule, attempt ledger,
joint package sizing, rollback, and month lifecycle without invoking MT5 or
copying framework order plumbing.
"""

from __future__ import annotations

import calendar
import datetime as dt
import math
import unittest
from dataclasses import dataclass


@dataclass(frozen=True)
class Bar:
    time: dt.datetime
    open: float
    close: float


def month_key(value: dt.datetime) -> int:
    return value.year * 100 + value.month


def next_month_key(value: int) -> int:
    year, month = divmod(value, 100)
    if not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def within_entry_grace(
    broker_now: dt.datetime,
    current_bar: dt.datetime,
    grace_minutes: int = 180,
) -> bool:
    elapsed = int((broker_now - current_bar).total_seconds())
    return 0 <= elapsed <= grace_minutes * 60


def synchronized_month_boundary(
    broker_now: dt.datetime,
    xau_current: dt.datetime,
    xag_current: dt.datetime,
    newest_completed: dt.datetime,
) -> tuple[bool, bool, int]:
    """Return accepted clock, late flag, and exact broker yyyymm."""

    key = month_key(broker_now)
    current_is_exact = (
        xau_current == xag_current
        and xau_current.date() == broker_now.date()
        and month_key(xau_current) == key
    )
    if not current_is_exact:
        return False, False, key
    prior_key = month_key(newest_completed)
    if prior_key == key:
        return True, True, key
    if next_month_key(prior_key) != key:
        return False, False, key
    return True, not within_entry_grace(broker_now, xau_current), key


def business_sessions(year: int, month: int) -> tuple[dt.datetime, ...]:
    _, final_day = calendar.monthrange(year, month)
    return tuple(
        dt.datetime(year, month, day)
        for day in range(1, final_day + 1)
        if dt.datetime(year, month, day).weekday() < 5
    )


def component_bars(
    anchor_close: float,
    sessions: tuple[dt.datetime, ...],
    overnight_factor: float,
    session_factor: float,
) -> tuple[Bar, ...]:
    chronological: list[Bar] = []
    prior_close = anchor_close
    for timestamp in sessions:
        day_open = prior_close * overnight_factor
        day_close = day_open * session_factor
        chronological.append(Bar(timestamp, day_open, day_close))
        prior_close = day_close
    return tuple(reversed(chronological))


def reconciliation_valid(
    xau_overnight: float,
    xau_session: float,
    xag_overnight: float,
    xag_session: float,
    xau_month: float,
    xag_month: float,
    tolerance: float = 1e-10,
    relative_total_override: float | None = None,
) -> bool:
    relative_components = relative_total_override
    if relative_components is None:
        relative_components = (
            xau_overnight - xag_overnight + xau_session - xag_session
        )
    relative_month = xau_month - xag_month
    return (
        abs(xau_overnight + xau_session - xau_month) <= tolerance
        and abs(xag_overnight + xag_session - xag_month) <= tolerance
        and abs(relative_components - relative_month) <= tolerance
    )


def monthly_relative_flow(
    current_month: int,
    xau_bars: tuple[Bar, ...],
    xag_bars: tuple[Bar, ...],
    minimum: int = 15,
    maximum: int = 25,
    tolerance: float = 1e-10,
) -> tuple[bool, int, dict[str, float]]:
    """Consume newest-first completed bars, including one older anchor."""

    empty = {
        "xau_overnight": 0.0,
        "xau_session": 0.0,
        "xag_overnight": 0.0,
        "xag_session": 0.0,
        "overnight_relative": 0.0,
        "session_relative": 0.0,
        "xau_month": 0.0,
        "xag_month": 0.0,
        "count": 0.0,
    }
    if len(xau_bars) != len(xag_bars) or len(xau_bars) < minimum + 1:
        return False, 0, empty
    if xau_bars[0].time != xag_bars[0].time:
        return False, 0, empty

    prior_month = month_key(xau_bars[0].time)
    if (
        month_key(xag_bars[0].time) != prior_month
        or next_month_key(prior_month) != current_month
    ):
        return False, 0, empty

    count = 0
    while count < len(xau_bars) and month_key(xau_bars[count].time) == prior_month:
        xau = xau_bars[count]
        xag = xag_bars[count]
        values = (xau.open, xau.close, xag.open, xag.close)
        if (
            xau.time != xag.time
            or month_key(xag.time) != prior_month
            or not all(math.isfinite(value) and value > 0 for value in values)
        ):
            return False, 0, empty
        if count and (
            xau_bars[count - 1].time <= xau.time
            or xag_bars[count - 1].time <= xag.time
        ):
            return False, 0, empty
        count += 1

    if not minimum <= count <= maximum or count >= len(xau_bars):
        return False, 0, empty
    xau_anchor = xau_bars[count]
    xag_anchor = xag_bars[count]
    anchor_month = month_key(xau_anchor.time)
    if (
        xau_anchor.time != xag_anchor.time
        or xau_bars[count - 1].time <= xau_anchor.time
        or xag_bars[count - 1].time <= xag_anchor.time
        or next_month_key(anchor_month) != prior_month
        or month_key(xag_anchor.time) != anchor_month
        or not all(
            math.isfinite(value) and value > 0
            for value in (xau_anchor.close, xag_anchor.close)
        )
    ):
        return False, 0, empty

    xau_overnight = xau_session = 0.0
    xag_overnight = xag_session = 0.0
    for index in range(count - 1, -1, -1):
        xau_prior_close = xau_bars[index + 1].close
        xag_prior_close = xag_bars[index + 1].close
        xau = xau_bars[index]
        xag = xag_bars[index]
        endpoints = (
            xau_prior_close,
            xag_prior_close,
            xau.open,
            xau.close,
            xag.open,
            xag.close,
        )
        if not all(math.isfinite(value) and value > 0 for value in endpoints):
            return False, 0, empty
        xau_overnight += math.log(xau.open / xau_prior_close)
        xau_session += math.log(xau.close / xau.open)
        xag_overnight += math.log(xag.open / xag_prior_close)
        xag_session += math.log(xag.close / xag.open)

    xau_month = math.log(xau_bars[0].close / xau_anchor.close)
    xag_month = math.log(xag_bars[0].close / xag_anchor.close)
    overnight_relative = xau_overnight - xag_overnight
    session_relative = xau_session - xag_session
    metrics = {
        "xau_overnight": xau_overnight,
        "xau_session": xau_session,
        "xag_overnight": xag_overnight,
        "xag_session": xag_session,
        "overnight_relative": overnight_relative,
        "session_relative": session_relative,
        "xau_month": xau_month,
        "xag_month": xag_month,
        "count": float(count),
    }
    if not reconciliation_valid(
        xau_overnight,
        xau_session,
        xag_overnight,
        xag_session,
        xau_month,
        xag_month,
        tolerance,
    ):
        return False, 0, metrics
    if session_relative > 0 and overnight_relative < 0:
        return True, 1, metrics
    if session_relative < 0 and overnight_relative > 0:
        return True, -1, metrics
    return True, 0, metrics


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


def open_pair(first_leg_ok: bool, second_leg_ok: bool) -> tuple[bool, int]:
    survivors = 0
    if not first_leg_ok:
        return False, survivors
    survivors = 1
    if not second_leg_ok:
        return False, 0
    return True, 2


def lifecycle_exit(
    entry_time: dt.datetime,
    synchronized_current_bar: dt.datetime,
    broker_now: dt.datetime,
    package_valid: bool = True,
    max_days: int = 40,
) -> str:
    if not package_valid:
        return "malformed"
    if month_key(synchronized_current_bar) != month_key(entry_time):
        return "next_month"
    if broker_now - entry_time >= dt.timedelta(days=max_days):
        return "stale"
    return "hold"


class AttemptLedger:
    def __init__(self) -> None:
        self.last_month = 0

    def consume(self, value: int) -> bool:
        if value <= 0 or value == self.last_month:
            return False
        self.last_month = value
        return True


class MonthlyRelativeFlowReferenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.sessions = business_sessions(2026, 7)
        self.anchor_time = dt.datetime(2026, 6, 30)
        self.current = dt.datetime(2026, 8, 3)
        self.broker_now = dt.datetime(2026, 8, 3, 2)

    def fixture(
        self,
        xau_overnight: float = 0.99,
        xau_session: float = 1.02,
        xag_overnight: float = 1.01,
        xag_session: float = 0.99,
        sessions: tuple[dt.datetime, ...] | None = None,
    ) -> tuple[tuple[Bar, ...], tuple[Bar, ...]]:
        selected = sessions if sessions is not None else self.sessions
        xau = component_bars(2000.0, selected, xau_overnight, xau_session)
        xag = component_bars(25.0, selected, xag_overnight, xag_session)
        return (
            xau + (Bar(self.anchor_time, 2000.0, 2000.0),),
            xag + (Bar(self.anchor_time, 25.0, 25.0),),
        )

    def test_exact_synchronized_new_month_clock_is_accepted(self) -> None:
        accepted, late, key = synchronized_month_boundary(
            self.broker_now, self.current, self.current, self.sessions[-1]
        )
        self.assertTrue(accepted)
        self.assertFalse(late)
        self.assertEqual(key, 202608)

    def test_current_cross_symbol_timestamp_mismatch_is_rejected(self) -> None:
        accepted, _, _ = synchronized_month_boundary(
            self.broker_now,
            self.current,
            self.current + dt.timedelta(hours=1),
            self.sessions[-1],
        )
        self.assertFalse(accepted)

    def test_completed_current_month_bar_marks_attachment_late(self) -> None:
        accepted, late, _ = synchronized_month_boundary(
            dt.datetime(2026, 8, 4, 1),
            dt.datetime(2026, 8, 4),
            dt.datetime(2026, 8, 4),
            dt.datetime(2026, 8, 3),
        )
        self.assertTrue(accepted)
        self.assertTrue(late)

    def test_three_hour_grace_is_inclusive_only_at_boundary(self) -> None:
        self.assertTrue(within_entry_grace(self.current, self.current))
        self.assertTrue(
            within_entry_grace(dt.datetime(2026, 8, 3, 3), self.current)
        )
        self.assertFalse(
            within_entry_grace(
                dt.datetime(2026, 8, 3, 3, 0, 1), self.current
            )
        )

    def test_full_prior_month_and_consecutive_anchor_are_accepted(self) -> None:
        xau, xag = self.fixture()
        valid, direction, metrics = monthly_relative_flow(202608, xau, xag)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertEqual(int(metrics["count"]), len(self.sessions))

    def test_cross_metal_consumed_timestamp_mismatch_is_rejected(self) -> None:
        xau, xag = self.fixture()
        changed = list(xag)
        changed[7] = Bar(
            changed[7].time + dt.timedelta(hours=1),
            changed[7].open,
            changed[7].close,
        )
        self.assertFalse(monthly_relative_flow(202608, xau, tuple(changed))[0])

    def test_nonconsecutive_anchor_month_is_rejected(self) -> None:
        xau, xag = self.fixture()
        bad_xau = xau[:-1] + (Bar(dt.datetime(2026, 5, 29), 2000, 2000),)
        bad_xag = xag[:-1] + (Bar(dt.datetime(2026, 5, 29), 25, 25),)
        self.assertFalse(monthly_relative_flow(202608, bad_xau, bad_xag)[0])

    def test_strict_newest_to_oldest_order_is_required(self) -> None:
        xau, xag = self.fixture()
        repeated = list(xau)
        repeated[4] = Bar(repeated[3].time, repeated[4].open, repeated[4].close)
        self.assertFalse(monthly_relative_flow(202608, tuple(repeated), xag)[0])

    def test_session_count_boundaries_accept_15_and_25(self) -> None:
        for count in (15, 25):
            start = dt.datetime(2026, 7, 1)
            sessions = tuple(start + dt.timedelta(days=i) for i in range(count))
            xau, xag = self.fixture(sessions=sessions)
            self.assertTrue(monthly_relative_flow(202608, xau, xag)[0])

    def test_session_count_outside_15_to_25_is_rejected(self) -> None:
        for count in (14, 26):
            start = dt.datetime(2026, 7, 1)
            sessions = tuple(start + dt.timedelta(days=i) for i in range(count))
            xau, xag = self.fixture(sessions=sessions)
            self.assertFalse(monthly_relative_flow(202608, xau, xag)[0])

    def test_invalid_completed_endpoint_is_rejected(self) -> None:
        xau, xag = self.fixture()
        changed = list(xau)
        changed[2] = Bar(changed[2].time, changed[2].open, float("nan"))
        self.assertFalse(monthly_relative_flow(202608, tuple(changed), xag)[0])

    def test_positive_session_negative_overnight_buys_xau(self) -> None:
        xau, xag = self.fixture()
        valid, direction, metrics = monthly_relative_flow(202608, xau, xag)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertLess(metrics["overnight_relative"], 0)
        self.assertGreater(metrics["session_relative"], 0)

    def test_negative_session_positive_overnight_sells_xau(self) -> None:
        xau, xag = self.fixture(1.01, 0.99, 0.99, 1.02)
        valid, direction, metrics = monthly_relative_flow(202608, xau, xag)
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertGreater(metrics["overnight_relative"], 0)
        self.assertLess(metrics["session_relative"], 0)

    def test_agreement_and_exact_zero_remain_flat(self) -> None:
        agreeing = self.fixture(1.01, 1.01, 1.0, 1.0)
        unchanged = self.fixture(1.0, 1.0, 1.0, 1.0)
        self.assertEqual(monthly_relative_flow(202608, *agreeing)[1], 0)
        self.assertEqual(monthly_relative_flow(202608, *unchanged)[1], 0)

    def test_per_metal_and_relative_components_reconcile(self) -> None:
        xau, xag = self.fixture()
        valid, _, values = monthly_relative_flow(202608, xau, xag)
        self.assertTrue(valid)
        self.assertTrue(
            reconciliation_valid(
                values["xau_overnight"],
                values["xau_session"],
                values["xag_overnight"],
                values["xag_session"],
                values["xau_month"],
                values["xag_month"],
            )
        )

    def test_any_independent_reconciliation_failure_is_rejected(self) -> None:
        self.assertFalse(reconciliation_valid(0.01, 0.02, 0.01, 0.02, 0.031, 0.03))
        self.assertFalse(reconciliation_valid(0.01, 0.02, 0.01, 0.02, 0.03, 0.031))
        self.assertFalse(
            reconciliation_valid(
                0.01,
                0.02,
                0.02,
                0.01,
                0.03,
                0.03,
                relative_total_override=2e-10,
            )
        )

    def test_month_attempt_is_consumed_before_downstream_failure(self) -> None:
        ledger = AttemptLedger()
        self.assertTrue(ledger.consume(202608))
        downstream_history_valid = False
        self.assertFalse(downstream_history_valid)
        self.assertFalse(ledger.consume(202608))
        self.assertTrue(ledger.consume(202609))

    def test_joint_sizing_respects_one_budget_and_notional_cap(self) -> None:
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

    def test_second_leg_failure_rolls_back_first_leg(self) -> None:
        self.assertEqual(open_pair(True, False), (False, 0))
        self.assertEqual(open_pair(True, True), (True, 2))

    def test_month_rollover_or_malformed_package_exits_both(self) -> None:
        opened = dt.datetime(2026, 8, 3, 1)
        self.assertEqual(
            lifecycle_exit(opened, dt.datetime(2026, 9, 1), dt.datetime(2026, 9, 1)),
            "next_month",
        )
        self.assertEqual(
            lifecycle_exit(opened, dt.datetime(2026, 8, 10), dt.datetime(2026, 8, 10), False),
            "malformed",
        )

    def test_forty_day_stale_guard_and_friday_hold(self) -> None:
        opened = dt.datetime(2026, 8, 3)
        friday = dt.datetime(2026, 8, 7, 21)
        self.assertEqual(lifecycle_exit(opened, friday, friday), "hold")
        stale = opened + dt.timedelta(days=40)
        stale_synchronized_bar = dt.datetime(2026, 8, 31)
        self.assertEqual(
            lifecycle_exit(opened, stale_synchronized_bar, stale), "stale"
        )


if __name__ == "__main__":
    unittest.main()
