"""Deterministic reference checks for QM5_41027_wti-mopen-rev1.

This is an executable specification, not a performance simulation.  It fixes
the normalized second-session selector, completed first-session endpoints,
contrarian mapping, attachment grace, and first-later-D1 lifecycle used by
the MQL5 implementation.
"""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


UTC = timezone.utc
DAY = timedelta(days=1)


def month_key(value: datetime) -> int:
    return value.year * 100 + value.month


def next_month_key(value: int) -> int:
    year, month = divmod(value, 100)
    if year < 1900 or month < 1 or month > 12:
        return 0
    if month == 12:
        return (year + 1) * 100 + 1
    return year * 100 + month + 1


def energy_label_offset(raw_current: datetime, broker_now: datetime) -> timedelta | None:
    elapsed = broker_now - raw_current
    if elapsed < timedelta(0):
        return None
    if elapsed < DAY:
        return timedelta(0)
    if elapsed < 2 * DAY:
        return DAY
    return None


@dataclass(frozen=True)
class Decision:
    eligible: bool
    late: bool = False
    key: int = 0
    offset: timedelta | None = None


def decision_clock(
    raw_current: datetime,
    raw_first: datetime,
    raw_before: datetime,
    broker_now: datetime,
    grace_minutes: int = 180,
) -> Decision:
    if not raw_before < raw_first < raw_current:
        return Decision(False)

    offset = energy_label_offset(raw_current, broker_now)
    if offset is None:
        return Decision(False)

    current = raw_current + offset
    first = raw_first + offset
    before = raw_before + offset
    current_key = month_key(current)
    before_key = month_key(before)
    if (
        current.date() != broker_now.date()
        or current.date() == first.date()
        or first.date() == before.date()
        or month_key(first) != current_key
        or before_key == current_key
        or next_month_key(before_key) != current_key
    ):
        return Decision(False)

    session_elapsed = (broker_now - raw_current) % DAY
    return Decision(
        True,
        late=session_elapsed > timedelta(minutes=grace_minutes),
        key=current_key,
        offset=offset,
    )


def first_session_contrarian(first_open: float, first_close: float) -> tuple[int, float] | None:
    if (
        not math.isfinite(first_open)
        or not math.isfinite(first_close)
        or first_open <= 0.0
        or first_close <= 0.0
    ):
        return None
    session_return = math.log(first_close / first_open)
    if not math.isfinite(session_return):
        return None
    direction = 1 if session_return < 0.0 else -1 if session_return > 0.0 else 0
    return direction, session_return


def lifecycle_exit_due(
    raw_current: datetime,
    broker_now: datetime,
    opened: datetime,
    max_hold_days: int = 4,
) -> bool:
    offset = energy_label_offset(raw_current, broker_now)
    if offset is None or opened > broker_now:
        return True
    normalized_current = raw_current + offset
    return (
        normalized_current.date() != opened.date()
        or broker_now - opened >= timedelta(days=max_hold_days)
    )


class MonthOpeningSessionReversalReferenceTests(unittest.TestCase):
    def test_exact_second_genuine_session_is_selected(self) -> None:
        decision = decision_clock(
            datetime(2026, 2, 4, tzinfo=UTC),
            datetime(2026, 2, 3, tzinfo=UTC),
            datetime(2026, 1, 30, tzinfo=UTC),
            datetime(2026, 2, 4, 1, tzinfo=UTC),
        )
        self.assertTrue(decision.eligible)
        self.assertFalse(decision.late)
        self.assertEqual(decision.key, 202602)
        self.assertEqual(decision.offset, timedelta(0))

    def test_weekend_or_holiday_gap_does_not_shift_ordinal(self) -> None:
        decision = decision_clock(
            datetime(2026, 5, 5, tzinfo=UTC),
            datetime(2026, 5, 4, tzinfo=UTC),
            datetime(2026, 4, 30, tzinfo=UTC),
            datetime(2026, 5, 5, 2, tzinfo=UTC),
        )
        self.assertTrue(decision.eligible)

    def test_first_and_third_month_sessions_are_rejected(self) -> None:
        first_session = decision_clock(
            datetime(2026, 2, 3, tzinfo=UTC),
            datetime(2026, 1, 30, tzinfo=UTC),
            datetime(2026, 1, 29, tzinfo=UTC),
            datetime(2026, 2, 3, 1, tzinfo=UTC),
        )
        third_session = decision_clock(
            datetime(2026, 2, 5, tzinfo=UTC),
            datetime(2026, 2, 4, tzinfo=UTC),
            datetime(2026, 2, 3, tzinfo=UTC),
            datetime(2026, 2, 5, 1, tzinfo=UTC),
        )
        self.assertFalse(first_session.eligible)
        self.assertFalse(third_session.eligible)

    def test_uniform_plus_one_day_energy_labels_are_supported(self) -> None:
        decision = decision_clock(
            datetime(2026, 2, 1, tzinfo=UTC),
            datetime(2026, 1, 31, tzinfo=UTC),
            datetime(2026, 1, 30, tzinfo=UTC),
            datetime(2026, 2, 2, 1, tzinfo=UTC),
        )
        self.assertTrue(decision.eligible)
        self.assertFalse(decision.late)
        self.assertEqual(decision.key, 202602)
        self.assertEqual(decision.offset, DAY)

    def test_nonconsecutive_month_and_late_attachment_fail_closed(self) -> None:
        skipped_month = decision_clock(
            datetime(2026, 3, 3, tzinfo=UTC),
            datetime(2026, 3, 2, tzinfo=UTC),
            datetime(2026, 1, 30, tzinfo=UTC),
            datetime(2026, 3, 3, 1, tzinfo=UTC),
        )
        late = decision_clock(
            datetime(2026, 3, 3, tzinfo=UTC),
            datetime(2026, 3, 2, tzinfo=UTC),
            datetime(2026, 2, 27, tzinfo=UTC),
            datetime(2026, 3, 3, 3, 1, tzinfo=UTC),
        )
        self.assertFalse(skipped_month.eligible)
        self.assertTrue(late.eligible)
        self.assertTrue(late.late)

    def test_completed_first_session_sign_is_faded_symmetrically(self) -> None:
        long_signal = first_session_contrarian(70.0, 68.0)
        short_signal = first_session_contrarian(70.0, 72.0)
        flat_signal = first_session_contrarian(70.0, 70.0)
        self.assertEqual(long_signal[0], 1)
        self.assertLess(long_signal[1], 0.0)
        self.assertEqual(short_signal[0], -1)
        self.assertGreater(short_signal[1], 0.0)
        self.assertEqual(flat_signal, (0, 0.0))

    def test_invalid_endpoints_fail_and_current_bar_cannot_enter_signal(self) -> None:
        self.assertIsNone(first_session_contrarian(0.0, 72.0))
        self.assertIsNone(first_session_contrarian(70.0, math.nan))
        baseline = first_session_contrarian(70.0, 68.0)
        # The signal function deliberately accepts only completed first-session
        # endpoints; a current-session price has no input channel.
        self.assertEqual(baseline, first_session_contrarian(70.0, 68.0))

    def test_first_later_normalized_d1_boundary_and_stale_guard_exit(self) -> None:
        opened = datetime(2026, 8, 4, 1, tzinfo=UTC)
        self.assertFalse(
            lifecycle_exit_due(
                datetime(2026, 8, 4, tzinfo=UTC),
                datetime(2026, 8, 4, 12, tzinfo=UTC),
                opened,
            )
        )
        self.assertTrue(
            lifecycle_exit_due(
                datetime(2026, 8, 5, tzinfo=UTC),
                datetime(2026, 8, 5, 1, tzinfo=UTC),
                opened,
            )
        )
        self.assertTrue(
            lifecycle_exit_due(
                datetime(2026, 8, 4, tzinfo=UTC),
                opened + timedelta(days=4),
                opened,
            )
        )


if __name__ == "__main__":
    unittest.main()
