"""Independent mechanic fixtures for QM5_41033.

The suite covers uniform energy-label normalization, the exact completed
six-bar sequence, all ten price endpoints, strict component opposition,
Friday-to-Friday reconciliation, dominant-component direction, Monday grace,
one-attempt identity, and later-week stale repair.  It does not invoke MT5 or
duplicate framework order plumbing.
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
    broker_now: dt.datetime,
    labelled_bar_open: dt.datetime,
    grace_minutes: int = 180,
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
    expected_weekdays = (4, 3, 2, 1, 0, 4)  # newest first; Monday=0
    expected_dates = tuple(
        (broker_now - days * DAY).date() for days in (3, 4, 5, 6, 7, 10)
    )
    return (
        broker_now.weekday() == 0
        and current.date() == broker_now.date()
        and tuple(value.weekday() for value in bars) == expected_weekdays
        and tuple(value.date() for value in bars) == expected_dates
    )


def select_direction(
    overnight_flow: float,
    session_flow: float,
    week_return: float,
    tolerance: float = RECONCILE_TOLERANCE,
) -> int:
    total_flow = overnight_flow + session_flow
    if not all(
        math.isfinite(value)
        for value in (overnight_flow, session_flow, week_return, total_flow)
    ):
        return 0
    if abs(total_flow - week_return) > tolerance:
        return 0
    signs_oppose = (overnight_flow > 0 > session_flow) or (
        overnight_flow < 0 < session_flow
    )
    if not signs_oppose:
        return 0
    return (total_flow > 0) - (total_flow < 0)


def flow_direction(
    preceding_friday_close: float,
    prior_week_bars: tuple[tuple[float, float], ...],
) -> tuple[int, float, float, float, float]:
    """Return direction, components, weekly return, and reconciled total."""

    flat = (0, 0.0, 0.0, 0.0, 0.0)
    if len(prior_week_bars) != 5:
        return flat
    if not math.isfinite(preceding_friday_close) or preceding_friday_close <= 0:
        return flat

    overnight_flow = 0.0
    session_flow = 0.0
    prior_close = preceding_friday_close
    for day_open, day_close in prior_week_bars:
        if not all(
            math.isfinite(value) and value > 0
            for value in (day_open, day_close, prior_close)
        ):
            return flat
        overnight_flow += math.log(day_open / prior_close)
        session_flow += math.log(day_close / day_open)
        prior_close = day_close

    week_return = math.log(prior_close / preceding_friday_close)
    total_flow = overnight_flow + session_flow
    direction = select_direction(overnight_flow, session_flow, week_return)
    return direction, overnight_flow, session_flow, week_return, total_flow


def week_start(value: dt.datetime) -> dt.date:
    return (value - value.weekday() * DAY).date()


class FlowDominanceReferenceTests(unittest.TestCase):
    def test_prior_date_energy_labels_normalize_uniformly(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)
        current_label = dt.datetime(2026, 8, 16, 0, 0)
        completed = tuple(
            dt.datetime(2026, 8, day, 0, 0)
            for day in (13, 12, 11, 10, 9, 6)
        )
        self.assertTrue(valid_flow_sequence(broker_now, current_label, completed))

    def test_native_same_day_labels_are_supported(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)
        current_label = dt.datetime(2026, 8, 17, 0, 0)
        completed = tuple(
            dt.datetime(2026, 8, day, 0, 0)
            for day in (14, 13, 12, 11, 10, 7)
        )
        self.assertTrue(valid_flow_sequence(broker_now, current_label, completed))

    def test_holiday_broken_sequence_is_not_shifted(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)
        current_label = dt.datetime(2026, 8, 17, 0, 0)
        completed = tuple(
            dt.datetime(2026, 8, day, 0, 0)
            for day in (14, 12, 11, 10, 7, 6)
        )
        self.assertFalse(valid_flow_sequence(broker_now, current_label, completed))

    def test_non_monday_decision_is_rejected(self) -> None:
        broker_now = dt.datetime(2026, 8, 18, 1, 0)
        current_label = dt.datetime(2026, 8, 18, 0, 0)
        completed = tuple(
            dt.datetime(2026, 8, day, 0, 0)
            for day in (17, 14, 13, 12, 11, 10)
        )
        self.assertFalse(valid_flow_sequence(broker_now, current_label, completed))

    def test_three_hour_grace_uses_executable_session_open(self) -> None:
        labelled = dt.datetime(2026, 8, 16, 0, 0)
        before_cutoff = dt.datetime(2026, 8, 17, 2, 59)
        after_cutoff = dt.datetime(2026, 8, 17, 3, 0, 1)
        self.assertTrue(within_entry_grace(before_cutoff, labelled))
        self.assertFalse(within_entry_grace(after_cutoff, labelled))

    def test_session_dominant_positive_total_buys(self) -> None:
        days = ((99.0, 102.0), (101.0, 104.0), (103.0, 106.0),
                (105.0, 108.0), (107.0, 110.0))
        direction, overnight, session, week_return, total = flow_direction(100.0, days)
        self.assertEqual(direction, 1)
        self.assertLess(overnight, 0)
        self.assertGreater(session, 0)
        self.assertGreater(total, 0)
        self.assertAlmostEqual(total, week_return)

    def test_session_dominant_negative_total_sells(self) -> None:
        days = ((101.0, 98.0), (99.0, 96.0), (97.0, 94.0),
                (95.0, 92.0), (93.0, 90.0))
        direction, overnight, session, _, total = flow_direction(100.0, days)
        self.assertEqual(direction, -1)
        self.assertGreater(overnight, 0)
        self.assertLess(session, 0)
        self.assertLess(total, 0)

    def test_overnight_dominant_positive_total_buys_against_session(self) -> None:
        days = ((103.0, 102.0), (105.0, 104.0), (107.0, 106.0),
                (109.0, 108.0), (111.0, 110.0))
        direction, overnight, session, _, total = flow_direction(100.0, days)
        self.assertEqual(direction, 1)
        self.assertGreater(overnight, 0)
        self.assertLess(session, 0)
        self.assertGreater(total, 0)

    def test_overnight_dominant_negative_total_sells_against_session(self) -> None:
        days = ((97.0, 98.0), (95.0, 96.0), (93.0, 94.0),
                (91.0, 92.0), (89.0, 90.0))
        direction, overnight, session, _, total = flow_direction(100.0, days)
        self.assertEqual(direction, -1)
        self.assertLess(overnight, 0)
        self.assertGreater(session, 0)
        self.assertLess(total, 0)

    def test_agreement_zero_and_equal_opposition_are_flat(self) -> None:
        self.assertEqual(select_direction(0.2, 0.1, 0.3), 0)
        self.assertEqual(select_direction(-0.2, -0.1, -0.3), 0)
        self.assertEqual(select_direction(0.0, 0.0, 0.0), 0)
        self.assertEqual(select_direction(-0.1, 0.1, 0.0), 0)

    def test_failed_reconciliation_is_flat(self) -> None:
        self.assertEqual(select_direction(-0.1, 0.2, 0.2), 0)
        self.assertEqual(
            select_direction(-0.1, 0.2, 0.1 + 2 * RECONCILE_TOLERANCE),
            0,
        )

    def test_all_endpoints_telescope_to_friday_return(self) -> None:
        days = ((101.0, 102.0), (100.0, 103.0), (104.0, 102.0),
                (105.0, 106.0), (104.0, 108.0))
        _, overnight, session, week_return, total = flow_direction(100.0, days)
        self.assertAlmostEqual(total, week_return)
        self.assertAlmostEqual(total, math.log(108.0 / 100.0))
        self.assertAlmostEqual(overnight + session, total)

    def test_invalid_completed_endpoint_consumes_flat(self) -> None:
        valid = ((101.0, 102.0),) * 5
        self.assertEqual(flow_direction(0.0, valid), (0, 0.0, 0.0, 0.0, 0.0))
        invalid = ((101.0, 102.0), (103.0, float("nan"))) + valid[2:]
        self.assertEqual(
            flow_direction(100.0, invalid),
            (0, 0.0, 0.0, 0.0, 0.0),
        )

    def test_later_week_is_a_stale_repair_boundary(self) -> None:
        opened = dt.datetime(2026, 8, 17, 1, 0)
        friday = dt.datetime(2026, 8, 21, 22, 0)
        next_monday = dt.datetime(2026, 8, 24, 0, 1)
        self.assertEqual(week_start(opened), week_start(friday))
        self.assertNotEqual(week_start(opened), week_start(next_monday))

    def test_exact_date_attempt_key_is_stable(self) -> None:
        observed = dt.datetime(2026, 8, 17, 2, 0)
        key = observed.year * 10_000 + observed.month * 100 + observed.day
        self.assertEqual(key, 20260817)
        self.assertNotEqual(key, 20260824)


if __name__ == "__main__":
    unittest.main()
