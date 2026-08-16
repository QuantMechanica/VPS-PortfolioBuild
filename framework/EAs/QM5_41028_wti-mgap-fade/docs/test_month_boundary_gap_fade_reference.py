"""Deterministic reference checks for QM5_41028_wti-mgap-fade.

This is an executable specification, not a performance simulation. It fixes
the normalized first-session selector, prior-close/current-open endpoints,
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
    raw_before: datetime,
    broker_now: datetime,
    grace_minutes: int = 180,
) -> Decision:
    if not raw_before < raw_current:
        return Decision(False)

    offset = energy_label_offset(raw_current, broker_now)
    if offset is None:
        return Decision(False)

    current = raw_current + offset
    before = raw_before + offset
    current_key = month_key(current)
    before_key = month_key(before)
    if (
        current.date() != broker_now.date()
        or current.date() == before.date()
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


def boundary_gap_contrarian(current_open: float, prior_close: float) -> tuple[int, float] | None:
    if (
        not math.isfinite(current_open)
        or not math.isfinite(prior_close)
        or current_open <= 0.0
        or prior_close <= 0.0
    ):
        return None
    gap_return = math.log(current_open / prior_close)
    if not math.isfinite(gap_return):
        return None
    direction = 1 if gap_return < 0.0 else -1 if gap_return > 0.0 else 0
    return direction, gap_return


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


class MonthBoundaryGapFadeReferenceTests(unittest.TestCase):
    def test_exact_first_genuine_month_session_is_selected(self) -> None:
        decision = decision_clock(
            datetime(2026, 2, 2, tzinfo=UTC),
            datetime(2026, 1, 30, tzinfo=UTC),
            datetime(2026, 2, 2, 1, tzinfo=UTC),
        )
        self.assertTrue(decision.eligible)
        self.assertFalse(decision.late)
        self.assertEqual(decision.key, 202602)
        self.assertEqual(decision.offset, timedelta(0))

    def test_weekend_or_holiday_gap_does_not_shift_month_identity(self) -> None:
        decision = decision_clock(
            datetime(2026, 5, 4, tzinfo=UTC),
            datetime(2026, 4, 30, tzinfo=UTC),
            datetime(2026, 5, 4, 2, tzinfo=UTC),
        )
        self.assertTrue(decision.eligible)

    def test_second_session_and_same_month_pair_are_rejected(self) -> None:
        second_session = decision_clock(
            datetime(2026, 2, 3, tzinfo=UTC),
            datetime(2026, 2, 2, tzinfo=UTC),
            datetime(2026, 2, 3, 1, tzinfo=UTC),
        )
        self.assertFalse(second_session.eligible)

    def test_uniform_plus_one_day_energy_labels_are_supported(self) -> None:
        decision = decision_clock(
            datetime(2026, 1, 31, tzinfo=UTC),
            datetime(2026, 1, 29, tzinfo=UTC),
            datetime(2026, 2, 1, 1, tzinfo=UTC),
        )
        self.assertTrue(decision.eligible)
        self.assertFalse(decision.late)
        self.assertEqual(decision.key, 202602)
        self.assertEqual(decision.offset, DAY)

    def test_nonconsecutive_month_and_late_attachment_fail_closed(self) -> None:
        skipped_month = decision_clock(
            datetime(2026, 3, 2, tzinfo=UTC),
            datetime(2026, 1, 30, tzinfo=UTC),
            datetime(2026, 3, 2, 1, tzinfo=UTC),
        )
        late = decision_clock(
            datetime(2026, 3, 2, tzinfo=UTC),
            datetime(2026, 2, 27, tzinfo=UTC),
            datetime(2026, 3, 2, 3, 1, tzinfo=UTC),
        )
        self.assertFalse(skipped_month.eligible)
        self.assertTrue(late.eligible)
        self.assertTrue(late.late)

    def test_boundary_gap_sign_is_faded_symmetrically(self) -> None:
        long_signal = boundary_gap_contrarian(68.0, 70.0)
        short_signal = boundary_gap_contrarian(72.0, 70.0)
        flat_signal = boundary_gap_contrarian(70.0, 70.0)
        self.assertEqual(long_signal[0], 1)
        self.assertLess(long_signal[1], 0.0)
        self.assertEqual(short_signal[0], -1)
        self.assertGreater(short_signal[1], 0.0)
        self.assertEqual(flat_signal, (0, 0.0))

    def test_invalid_endpoints_fail_and_current_tick_has_no_signal_channel(self) -> None:
        self.assertIsNone(boundary_gap_contrarian(0.0, 70.0))
        self.assertIsNone(boundary_gap_contrarian(70.0, math.nan))
        baseline = boundary_gap_contrarian(68.0, 70.0)
        # The function accepts only fixed D1 open and completed prior close;
        # current bid/ask/high/low/partial-close values have no input channel.
        self.assertEqual(baseline, boundary_gap_contrarian(68.0, 70.0))

    def test_first_later_normalized_d1_boundary_and_stale_guard_exit(self) -> None:
        opened = datetime(2026, 8, 3, 1, tzinfo=UTC)
        self.assertFalse(
            lifecycle_exit_due(
                datetime(2026, 8, 3, tzinfo=UTC),
                datetime(2026, 8, 3, 12, tzinfo=UTC),
                opened,
            )
        )
        self.assertTrue(
            lifecycle_exit_due(
                datetime(2026, 8, 4, tzinfo=UTC),
                datetime(2026, 8, 4, 1, tzinfo=UTC),
                opened,
            )
        )
        self.assertTrue(
            lifecycle_exit_due(
                datetime(2026, 8, 3, tzinfo=UTC),
                opened + timedelta(days=4),
                opened,
            )
        )


if __name__ == "__main__":
    unittest.main()
