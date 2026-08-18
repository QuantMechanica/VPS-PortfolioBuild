"""Independent mechanic fixtures for QM5_41058.

The tests cover the locked calendar-label normalization, exact completed
six-bar sequence, five close-to-open and open-to-close endpoints, strict sign
agreement, Monday grace, one-attempt identity, and later-week repair without
invoking MT5 or duplicating framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest


DAY = dt.timedelta(days=1)
RECONCILE_TOLERANCE = 1.0e-10


def session_time(label: dt.datetime, broker_now: dt.datetime) -> dt.datetime:
    elapsed = broker_now - label
    if DAY <= elapsed < 2 * DAY:
        return label + DAY
    return label


def within_entry_grace(
    broker_now: dt.datetime, labelled_bar_open: dt.datetime, grace_minutes: int = 180
) -> bool:
    elapsed = int((broker_now - labelled_bar_open).total_seconds())
    if elapsed < 0:
        return False
    return elapsed % 86_400 <= grace_minutes * 60


def valid_flow_sequence(
    broker_now: dt.datetime,
    current_label: dt.datetime,
    completed_labels: tuple[dt.datetime, ...],
) -> bool:
    if len(completed_labels) != 6:
        return False
    current = session_time(current_label, broker_now)
    offset = current - current_label
    bars = tuple(value + offset for value in completed_labels)
    expected_weekdays = (4, 3, 2, 1, 0, 4)  # newest first; Python Monday=0
    expected_dates = tuple(
        (broker_now - days * DAY).date() for days in (3, 4, 5, 6, 7, 10)
    )
    return (
        broker_now.weekday() == 0
        and current.date() == broker_now.date()
        and tuple(value.weekday() for value in bars) == expected_weekdays
        and tuple(value.date() for value in bars) == expected_dates
    )


def flow_direction(
    preceding_friday_close: float,
    prior_week_bars: tuple[tuple[float, float], ...],
) -> tuple[int, float, float]:
    """Return direction and component sums for chronological Mon-Fri bars."""

    if len(prior_week_bars) != 5:
        return 0, 0.0, 0.0
    if not math.isfinite(preceding_friday_close) or preceding_friday_close <= 0:
        return 0, 0.0, 0.0

    overnight_flow = 0.0
    session_flow = 0.0
    prior_close = preceding_friday_close
    for day_open, day_close in prior_week_bars:
        if not all(
            math.isfinite(value) and value > 0
            for value in (day_open, day_close)
        ):
            return 0, 0.0, 0.0
        overnight_flow += math.log(day_open / prior_close)
        session_flow += math.log(day_close / day_open)
        prior_close = day_close

    weekly_return = math.log(prior_week_bars[-1][1] / preceding_friday_close)
    if not flows_reconcile(
        overnight_flow,
        session_flow,
        weekly_return,
    ):
        return 0, overnight_flow, session_flow

    if overnight_flow > 0 and session_flow > 0:
        direction = 1
    elif overnight_flow < 0 and session_flow < 0:
        direction = -1
    else:
        direction = 0
    return direction, overnight_flow, session_flow


def flows_reconcile(
    overnight_flow: float,
    session_flow: float,
    weekly_return: float,
    tolerance: float = RECONCILE_TOLERANCE,
) -> bool:
    values = (overnight_flow, session_flow, weekly_return, tolerance)
    return (
        all(math.isfinite(value) for value in values)
        and tolerance == RECONCILE_TOLERANCE
        and abs((overnight_flow + session_flow) - weekly_return) <= tolerance
    )


def week_start(value: dt.datetime) -> dt.date:
    return (value - value.weekday() * DAY).date()


class FlowAgreementReferenceTests(unittest.TestCase):
    def test_prior_date_energy_labels_normalize_uniformly(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)  # Monday
        current_label = dt.datetime(2026, 8, 16, 0, 0)
        completed = tuple(
            dt.datetime(2026, 8, day, 0, 0) for day in (13, 12, 11, 10, 9, 6)
        )
        self.assertTrue(valid_flow_sequence(broker_now, current_label, completed))

    def test_native_same_day_labels_are_supported(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)
        current_label = dt.datetime(2026, 8, 17, 0, 0)
        completed = tuple(
            dt.datetime(2026, 8, day, 0, 0) for day in (14, 13, 12, 11, 10, 7)
        )
        self.assertTrue(valid_flow_sequence(broker_now, current_label, completed))

    def test_holiday_broken_sequence_is_not_shifted(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)
        current_label = dt.datetime(2026, 8, 17, 0, 0)
        completed = tuple(
            dt.datetime(2026, 8, day, 0, 0) for day in (14, 12, 11, 10, 7, 6)
        )
        self.assertFalse(valid_flow_sequence(broker_now, current_label, completed))

    def test_non_monday_decision_is_rejected(self) -> None:
        broker_now = dt.datetime(2026, 8, 18, 1, 0)
        current_label = dt.datetime(2026, 8, 18, 0, 0)
        completed = tuple(
            dt.datetime(2026, 8, day, 0, 0) for day in (17, 14, 13, 12, 11, 10)
        )
        self.assertFalse(valid_flow_sequence(broker_now, current_label, completed))

    def test_three_hour_grace_accepts_normal_energy_open(self) -> None:
        labelled = dt.datetime(2026, 8, 16, 0, 0)
        self.assertTrue(within_entry_grace(dt.datetime(2026, 8, 17, 2, 59), labelled))
        self.assertFalse(within_entry_grace(dt.datetime(2026, 8, 17, 3, 0, 1), labelled))

    def test_both_positive_flows_buy(self) -> None:
        days = ((71.0, 72.0), (73.0, 74.0), (75.0, 76.0), (77.0, 78.0), (79.0, 80.0))
        direction, overnight, session = flow_direction(70.0, days)
        self.assertEqual(direction, 1)
        self.assertGreater(overnight, 0)
        self.assertGreater(session, 0)

    def test_both_negative_flows_sell(self) -> None:
        days = ((79.0, 78.0), (77.0, 76.0), (75.0, 74.0), (73.0, 72.0), (71.0, 70.0))
        direction, overnight, session = flow_direction(80.0, days)
        self.assertEqual(direction, -1)
        self.assertLess(overnight, 0)
        self.assertLess(session, 0)

    def test_opposed_flows_and_exact_zero_remain_flat(self) -> None:
        opposed = ((101.0, 100.0),) * 5
        self.assertEqual(flow_direction(100.0, opposed)[0], 0)
        unchanged = ((100.0, 100.0),) * 5
        self.assertEqual(flow_direction(100.0, unchanged)[0], 0)

    def test_component_sums_reconcile_to_total_week_return(self) -> None:
        days = ((101.0, 102.0), (100.0, 103.0), (104.0, 102.0), (105.0, 106.0), (104.0, 108.0))
        _, overnight, session = flow_direction(100.0, days)
        self.assertAlmostEqual(overnight + session, math.log(108.0 / 100.0))

    def test_failed_or_unlocked_reconciliation_is_rejected(self) -> None:
        self.assertFalse(flows_reconcile(0.02, 0.03, 0.06))
        self.assertFalse(flows_reconcile(0.02, 0.03, 0.05, 1.0e-6))

    def test_invalid_completed_endpoint_consumes_flat(self) -> None:
        valid = ((101.0, 102.0),) * 5
        self.assertEqual(flow_direction(0.0, valid), (0, 0.0, 0.0))
        invalid = ((101.0, 102.0), (103.0, float("nan"))) + valid[2:]
        self.assertEqual(flow_direction(100.0, invalid), (0, 0.0, 0.0))

    def test_later_week_is_a_stale_repair_boundary(self) -> None:
        opened = dt.datetime(2026, 8, 17, 1, 0)
        self.assertEqual(week_start(opened), week_start(dt.datetime(2026, 8, 21, 22, 0)))
        self.assertNotEqual(
            week_start(opened), week_start(dt.datetime(2026, 8, 24, 0, 1))
        )

    def test_exact_date_attempt_key_is_stable(self) -> None:
        observed = dt.datetime(2026, 8, 17, 2, 0)
        key = observed.year * 10_000 + observed.month * 100 + observed.day
        self.assertEqual(key, 20260817)
        self.assertNotEqual(key, 20260824)


if __name__ == "__main__":
    unittest.main()
