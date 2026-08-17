"""Independent mechanic fixtures for QM5_41049.

The suite covers uniform energy-label normalization, the exact completed
Monday-Tuesday-Wednesday sequence, completed Wednesday endpoints, strict
component opposition, strict overnight dominance, return reconciliation,
continuation direction, Thursday grace/attempt identity, and next-D1 exit.
It does not invoke MT5 or duplicate framework order plumbing.
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


def valid_wednesday_sequence(
    broker_now: dt.datetime,
    current_label: dt.datetime,
    completed_labels: tuple[dt.datetime, ...],
) -> bool:
    if len(completed_labels) != 3 or broker_now.weekday() != 3:
        return False
    current = session_time(current_label, broker_now)
    offset = current - current_label
    bars = tuple(value + offset for value in completed_labels)
    expected_dates = tuple(
        (broker_now - days * DAY).date() for days in (1, 2, 3)
    )
    gaps = (current - bars[0], bars[0] - bars[1], bars[1] - bars[2])
    return (
        current.date() == broker_now.date()
        and tuple(value.weekday() for value in bars) == (2, 1, 0)
        and tuple(value.date() for value in bars) == expected_dates
        and all(dt.timedelta(hours=20) <= gap <= dt.timedelta(hours=28)
                for gap in gaps)
    )


def select_direction(
    overnight_flow: float,
    session_flow: float,
    day_return: float,
    tolerance: float = RECONCILE_TOLERANCE,
) -> int:
    total_flow = overnight_flow + session_flow
    if not all(
        math.isfinite(value)
        for value in (overnight_flow, session_flow, day_return, total_flow)
    ):
        return 0
    if abs(total_flow - day_return) > tolerance:
        return 0
    signs_oppose = (overnight_flow > 0 > session_flow) or (
        overnight_flow < 0 < session_flow
    )
    if not signs_oppose or abs(overnight_flow) <= abs(session_flow):
        return 0
    # Follow the overnight-dominant completed Wednesday total.
    return (total_flow > 0) - (total_flow < 0)


def wednesday_direction(
    tuesday_close: float,
    wednesday_open: float,
    wednesday_close: float,
) -> tuple[int, float, float, float, float]:
    flat = (0, 0.0, 0.0, 0.0, 0.0)
    endpoints = (tuesday_close, wednesday_open, wednesday_close)
    if not all(math.isfinite(value) and value > 0 for value in endpoints):
        return flat
    overnight = math.log(wednesday_open / tuesday_close)
    session = math.log(wednesday_close / wednesday_open)
    day_return = math.log(wednesday_close / tuesday_close)
    total = overnight + session
    return (
        select_direction(overnight, session, day_return),
        overnight,
        session,
        day_return,
        total,
    )


def later_d1_boundary(
    opened: dt.datetime,
    current_label: dt.datetime,
    broker_now: dt.datetime,
) -> bool:
    return session_time(current_label, broker_now).date() > opened.date()


class WednesdayOvernightDominanceReferenceTests(unittest.TestCase):
    def test_native_same_day_labels_are_supported(self) -> None:
        broker_now = dt.datetime(2026, 8, 20, 1, 0)
        completed = tuple(
            dt.datetime(2026, 8, day) for day in (19, 18, 17)
        )
        self.assertTrue(
            valid_wednesday_sequence(
                broker_now, dt.datetime(2026, 8, 20), completed
            )
        )

    def test_prior_date_energy_labels_normalize_uniformly(self) -> None:
        broker_now = dt.datetime(2026, 8, 20, 1, 0)
        completed = tuple(
            dt.datetime(2026, 8, day) for day in (18, 17, 16)
        )
        self.assertTrue(
            valid_wednesday_sequence(
                broker_now, dt.datetime(2026, 8, 19), completed
            )
        )

    def test_holiday_or_missing_session_is_not_substituted(self) -> None:
        broker_now = dt.datetime(2026, 8, 20, 1, 0)
        completed = tuple(
            dt.datetime(2026, 8, day) for day in (19, 17, 16)
        )
        self.assertFalse(
            valid_wednesday_sequence(
                broker_now, dt.datetime(2026, 8, 20), completed
            )
        )

    def test_non_thursday_decision_is_rejected(self) -> None:
        broker_now = dt.datetime(2026, 8, 21, 1, 0)
        completed = tuple(
            dt.datetime(2026, 8, day) for day in (20, 19, 18)
        )
        self.assertFalse(
            valid_wednesday_sequence(
                broker_now, dt.datetime(2026, 8, 21), completed
            )
        )

    def test_three_hour_grace_uses_executable_session_open(self) -> None:
        labelled = dt.datetime(2026, 8, 19)
        self.assertTrue(
            within_entry_grace(dt.datetime(2026, 8, 20, 2, 59), labelled)
        )
        self.assertFalse(
            within_entry_grace(
                dt.datetime(2026, 8, 20, 3, 0, 1), labelled
            )
        )

    def test_overnight_dominant_positive_day_is_bought(self) -> None:
        direction, overnight, session, day_return, total = (
            wednesday_direction(100.0, 103.0, 101.0)
        )
        self.assertEqual(direction, 1)
        self.assertGreater(overnight, 0)
        self.assertLess(session, 0)
        self.assertGreater(total, 0)
        self.assertGreater(abs(overnight), abs(session))
        self.assertAlmostEqual(total, day_return)

    def test_overnight_dominant_negative_day_is_sold(self) -> None:
        direction, overnight, session, _, total = wednesday_direction(
            100.0, 97.0, 99.0
        )
        self.assertEqual(direction, -1)
        self.assertLess(overnight, 0)
        self.assertGreater(session, 0)
        self.assertLess(total, 0)
        self.assertGreater(abs(overnight), abs(session))

    def test_session_dominance_is_flat(self) -> None:
        self.assertEqual(select_direction(0.1, -0.2, -0.1), 0)
        self.assertEqual(select_direction(-0.1, 0.2, 0.1), 0)

    def test_agreement_zero_and_equal_opposition_are_flat(self) -> None:
        self.assertEqual(select_direction(0.2, 0.1, 0.3), 0)
        self.assertEqual(select_direction(-0.2, -0.1, -0.3), 0)
        self.assertEqual(select_direction(0.0, 0.0, 0.0), 0)
        self.assertEqual(select_direction(-0.1, 0.1, 0.0), 0)

    def test_failed_reconciliation_and_invalid_arithmetic_are_flat(self) -> None:
        self.assertEqual(select_direction(-0.2, 0.1, -0.05), 0)
        self.assertEqual(
            select_direction(-0.2, 0.1, -0.1 + 2 * RECONCILE_TOLERANCE),
            0,
        )
        self.assertEqual(select_direction(float("nan"), 0.1, -0.1), 0)

    def test_completed_endpoints_telescope_to_day_return(self) -> None:
        _, overnight, session, day_return, total = wednesday_direction(
            100.0, 97.0, 102.0
        )
        self.assertAlmostEqual(total, day_return)
        self.assertAlmostEqual(total, math.log(102.0 / 100.0))
        self.assertAlmostEqual(overnight + session, total)

    def test_invalid_completed_endpoint_consumes_flat(self) -> None:
        self.assertEqual(
            wednesday_direction(100.0, 0.0, 102.0),
            (0, 0.0, 0.0, 0.0, 0.0),
        )
        self.assertEqual(
            wednesday_direction(100.0, 99.0, float("nan")),
            (0, 0.0, 0.0, 0.0, 0.0),
        )

    def test_first_later_d1_boundary_is_the_ordinary_exit(self) -> None:
        opened = dt.datetime(2026, 8, 20, 1, 0)
        self.assertFalse(
            later_d1_boundary(
                opened,
                dt.datetime(2026, 8, 20),
                dt.datetime(2026, 8, 20, 12, 0),
            )
        )
        self.assertTrue(
            later_d1_boundary(
                opened,
                dt.datetime(2026, 8, 21),
                dt.datetime(2026, 8, 21, 0, 1),
            )
        )
        self.assertTrue(
            later_d1_boundary(
                opened,
                dt.datetime(2026, 8, 20),
                dt.datetime(2026, 8, 21, 0, 1),
            )
        )

    def test_exact_thursday_attempt_key_is_stable(self) -> None:
        observed = dt.datetime(2026, 8, 20, 2, 0)
        key = observed.year * 10_000 + observed.month * 100 + observed.day
        self.assertEqual(key, 20260820)
        self.assertNotEqual(key, 20260827)


if __name__ == "__main__":
    unittest.main()


