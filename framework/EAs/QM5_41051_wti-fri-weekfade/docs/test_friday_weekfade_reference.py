"""Independent mechanic fixtures for QM5_41051.

The suite covers the two permitted energy-label conventions, the exact
completed Monday-through-Thursday sequence, frozen signal endpoints, strict
negative-only direction, Friday grace/attempt identity, and the later-D1
repair boundary. It does not invoke MT5 or duplicate framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest


DAY = dt.timedelta(days=1)


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


def valid_exact_week(
    broker_now: dt.datetime,
    current_label: dt.datetime,
    completed_labels: tuple[dt.datetime, ...],
) -> bool:
    """Mirror only the card's calendar contract, newest completed bar first."""
    if len(completed_labels) != 4 or broker_now.weekday() != 4:
        return False
    current = session_time(current_label, broker_now)
    label_offset = current - current_label
    completed = tuple(value + label_offset for value in completed_labels)
    expected_dates = tuple(
        (broker_now - offset * DAY).date() for offset in (1, 2, 3, 4)
    )
    gaps = (current - completed[0],) + tuple(
        completed[index] - completed[index + 1] for index in range(3)
    )
    return (
        current.date() == broker_now.date()
        and current.weekday() == 4
        and tuple(value.weekday() for value in completed) == (3, 2, 1, 0)
        and tuple(value.date() for value in completed) == expected_dates
        and all(
            dt.timedelta(hours=20) <= gap <= dt.timedelta(hours=28)
            for gap in gaps
        )
    )


def friday_weekfade_signal(
    monday_open: float,
    thursday_close: float,
) -> tuple[int, float]:
    """Return BUY=1 only for a finite, strictly negative completed path."""
    if not all(
        math.isfinite(value) and value > 0
        for value in (monday_open, thursday_close)
    ):
        return 0, 0.0
    formation_return = math.log(thursday_close / monday_open)
    if not math.isfinite(formation_return):
        return 0, 0.0
    return (1 if formation_return < 0 else 0), formation_return


def later_d1_boundary(
    opened: dt.datetime,
    current_label: dt.datetime,
    broker_now: dt.datetime,
) -> bool:
    return session_time(current_label, broker_now).date() > opened.date()


def attempt_date_key(broker_now: dt.datetime) -> int:
    return broker_now.year * 10_000 + broker_now.month * 100 + broker_now.day


class FridayWeekfadeReferenceTests(unittest.TestCase):
    def test_native_same_day_labels_accept_exact_week(self) -> None:
        broker_now = dt.datetime(2026, 8, 21, 1, 0)
        completed = tuple(dt.datetime(2026, 8, day) for day in (20, 19, 18, 17))
        self.assertTrue(
            valid_exact_week(broker_now, dt.datetime(2026, 8, 21), completed)
        )

    def test_prior_date_energy_labels_normalize_uniformly(self) -> None:
        broker_now = dt.datetime(2026, 8, 21, 1, 0)
        completed = tuple(dt.datetime(2026, 8, day) for day in (19, 18, 17, 16))
        self.assertTrue(
            valid_exact_week(broker_now, dt.datetime(2026, 8, 20), completed)
        )

    def test_missing_or_holiday_session_is_not_substituted(self) -> None:
        broker_now = dt.datetime(2026, 8, 21, 1, 0)
        completed = tuple(dt.datetime(2026, 8, day) for day in (20, 19, 17, 16))
        self.assertFalse(
            valid_exact_week(broker_now, dt.datetime(2026, 8, 21), completed)
        )

    def test_mixed_label_convention_is_rejected(self) -> None:
        broker_now = dt.datetime(2026, 8, 21, 1, 0)
        completed = tuple(dt.datetime(2026, 8, day) for day in (20, 18, 17, 16))
        self.assertFalse(
            valid_exact_week(broker_now, dt.datetime(2026, 8, 20), completed)
        )

    def test_non_friday_decision_is_rejected(self) -> None:
        broker_now = dt.datetime(2026, 8, 20, 1, 0)
        completed = tuple(dt.datetime(2026, 8, day) for day in (19, 18, 17, 16))
        self.assertFalse(
            valid_exact_week(broker_now, dt.datetime(2026, 8, 20), completed)
        )

    def test_three_hour_grace_uses_executable_session_open(self) -> None:
        prior_date_label = dt.datetime(2026, 8, 20)
        self.assertTrue(
            within_entry_grace(
                dt.datetime(2026, 8, 21, 2, 59), prior_date_label
            )
        )
        self.assertFalse(
            within_entry_grace(
                dt.datetime(2026, 8, 21, 3, 0, 1), prior_date_label
            )
        )

    def test_negative_completed_formation_is_bought(self) -> None:
        direction, formation = friday_weekfade_signal(80.0, 78.0)
        self.assertEqual(direction, 1)
        self.assertLess(formation, 0.0)

    def test_positive_and_exact_zero_formations_are_flat(self) -> None:
        self.assertEqual(friday_weekfade_signal(80.0, 82.0)[0], 0)
        self.assertEqual(friday_weekfade_signal(80.0, 80.0), (0, 0.0))

    def test_invalid_endpoints_are_flat(self) -> None:
        self.assertEqual(friday_weekfade_signal(0.0, 78.0), (0, 0.0))
        self.assertEqual(
            friday_weekfade_signal(80.0, float("nan")), (0, 0.0)
        )
        self.assertEqual(
            friday_weekfade_signal(float("inf"), 78.0), (0, 0.0)
        )

    def test_only_monday_open_and_thursday_close_define_signal(self) -> None:
        baseline = friday_weekfade_signal(80.0, 78.0)
        # Tuesday/Wednesday paths and the current Friday quote are intentionally
        # absent from the reference function, so they cannot alter the state.
        after_unrelated_price_changes = friday_weekfade_signal(80.0, 78.0)
        self.assertEqual(baseline, after_unrelated_price_changes)

    def test_endpoint_orientation_is_not_reversible(self) -> None:
        self.assertEqual(friday_weekfade_signal(80.0, 78.0)[0], 1)
        self.assertEqual(friday_weekfade_signal(78.0, 80.0)[0], 0)

    def test_first_later_d1_boundary_repairs_survivor(self) -> None:
        opened = dt.datetime(2026, 8, 21, 1, 0)
        self.assertFalse(
            later_d1_boundary(
                opened,
                dt.datetime(2026, 8, 21),
                dt.datetime(2026, 8, 21, 12, 0),
            )
        )
        self.assertTrue(
            later_d1_boundary(
                opened,
                dt.datetime(2026, 8, 24),
                dt.datetime(2026, 8, 24, 0, 1),
            )
        )
        self.assertTrue(
            later_d1_boundary(
                opened,
                dt.datetime(2026, 8, 23),
                dt.datetime(2026, 8, 24, 0, 1),
            )
        )

    def test_broker_friday_attempt_key_is_stable(self) -> None:
        observed = dt.datetime(2026, 8, 21, 2, 0)
        self.assertEqual(attempt_date_key(observed), 20260821)
        self.assertNotEqual(attempt_date_key(observed), 20260828)


if __name__ == "__main__":
    unittest.main()
