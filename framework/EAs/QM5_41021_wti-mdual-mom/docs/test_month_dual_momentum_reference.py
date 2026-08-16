"""Deterministic reference checks for QM5_41021 WTI dual-horizon momentum."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


UTC = timezone.utc


@dataclass(frozen=True)
class Bar:
    opened: datetime
    close: float


def month_key(value: datetime) -> int:
    return value.year * 100 + value.month


def next_month_key(value: int) -> int:
    year, month = divmod(value, 100)
    if month == 12:
        return (year + 1) * 100 + 1
    return year * 100 + month + 1


def label_offset(current_bar: datetime, now: datetime) -> timedelta | None:
    elapsed = now - current_bar
    if elapsed < timedelta(0):
        return None
    if elapsed < timedelta(days=1):
        return timedelta(0)
    if elapsed < timedelta(days=2):
        return timedelta(days=1)
    return None


def within_entry_grace(
    current_bar: datetime, now: datetime, grace_minutes: int = 5
) -> bool:
    elapsed = now - current_bar
    if elapsed < timedelta(0):
        return False
    session_elapsed = elapsed % timedelta(days=1)
    return session_elapsed <= timedelta(minutes=grace_minutes)


def dual_horizon_signal(
    current_bar: datetime,
    completed_newest_first: list[Bar],
    now: datetime,
    closing_intervals: int = 5,
) -> tuple[bool, int, float, float]:
    """Mirror the completed-month and nested final-five sign agreement."""

    offset = label_offset(current_bar, now)
    if offset is None or len(completed_newest_first) < closing_intervals + 2:
        return False, 0, 0.0, 0.0

    current_key = month_key(current_bar + offset)
    bars = completed_newest_first
    prior_key = month_key(bars[0].opened + offset)
    if next_month_key(prior_key) != current_key:
        return False, 0, 0.0, 0.0

    prior_count = 0
    while (
        prior_count < len(bars)
        and month_key(bars[prior_count].opened + offset) == prior_key
    ):
        if bars[prior_count].close <= 0.0 or not math.isfinite(bars[prior_count].close):
            return False, 0, 0.0, 0.0
        if prior_count and bars[prior_count - 1].opened <= bars[prior_count].opened:
            return False, 0, 0.0, 0.0
        prior_count += 1

    if prior_count < closing_intervals + 1 or prior_count >= len(bars):
        return False, 0, 0.0, 0.0
    prior_prior_key = month_key(bars[prior_count].opened + offset)
    if next_month_key(prior_prior_key) != prior_key:
        return False, 0, 0.0, 0.0

    endpoints = (
        bars[0].close,
        bars[closing_intervals].close,
        bars[prior_count].close,
    )
    if any(value <= 0.0 or not math.isfinite(value) for value in endpoints):
        return False, 0, 0.0, 0.0

    month_return = math.log(endpoints[0] / endpoints[2])
    closing_return = math.log(endpoints[0] / endpoints[1])
    direction = 0
    if month_return > 0.0 and closing_return > 0.0:
        direction = 1
    elif month_return < 0.0 and closing_return < 0.0:
        direction = -1
    return True, direction, month_return, closing_return


def should_close(
    opened: datetime | None,
    current_bar: datetime,
    now: datetime,
    completed_since_entry: int,
    hold_bars: int = 5,
    max_days: int = 12,
) -> bool:
    if opened is None or opened > now or completed_since_entry < 0:
        return True
    if month_key(opened) != month_key(current_bar):
        return True
    if completed_since_entry >= hold_bars:
        return True
    return now - opened >= timedelta(days=max_days)


def july_sample(
    month_end: float,
    closing_start: float,
    prior_month_end: float,
    prior_date_labels: bool = False,
) -> tuple[datetime, datetime, list[Bar]]:
    current = datetime(2026, 8, 3, tzinfo=UTC)
    now = current
    bars = [
        Bar(datetime(2026, 7, 31, tzinfo=UTC), month_end),
        Bar(datetime(2026, 7, 30, tzinfo=UTC), 83.0),
        Bar(datetime(2026, 7, 29, tzinfo=UTC), 82.0),
        Bar(datetime(2026, 7, 28, tzinfo=UTC), 81.0),
        Bar(datetime(2026, 7, 27, tzinfo=UTC), 80.5),
        Bar(datetime(2026, 7, 24, tzinfo=UTC), closing_start),
        Bar(datetime(2026, 6, 30, tzinfo=UTC), prior_month_end),
    ]
    if prior_date_labels:
        current -= timedelta(days=1)
        bars = [Bar(bar.opened - timedelta(days=1), bar.close) for bar in bars]
        now = datetime(2026, 8, 3, tzinfo=UTC)
    return current, now, bars


class MonthDualMomentumReferenceTest(unittest.TestCase):
    def test_positive_agreement_is_long(self) -> None:
        current, now, bars = july_sample(84.0, 80.0, 75.0)
        valid, direction, month_value, closing_value = dual_horizon_signal(
            current, bars, now
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertAlmostEqual(month_value, math.log(84.0 / 75.0), places=14)
        self.assertAlmostEqual(closing_value, math.log(84.0 / 80.0), places=14)

    def test_negative_agreement_is_short(self) -> None:
        current, now, bars = july_sample(76.0, 80.0, 85.0)
        valid, direction, month_value, closing_value = dual_horizon_signal(
            current, bars, now
        )
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertLess(month_value, 0.0)
        self.assertLess(closing_value, 0.0)

    def test_disagreement_and_exact_zero_are_flat(self) -> None:
        current, now, bars = july_sample(84.0, 80.0, 90.0)
        self.assertEqual(dual_horizon_signal(current, bars, now)[1], 0)
        current, now, bars = july_sample(80.0, 80.0, 75.0)
        valid, direction, _, closing_value = dual_horizon_signal(current, bars, now)
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertEqual(closing_value, 0.0)

    def test_uniform_prior_date_label_normalization(self) -> None:
        current, now, bars = july_sample(84.0, 80.0, 75.0, True)
        self.assertEqual(label_offset(current, now), timedelta(days=1))
        self.assertTrue(within_entry_grace(current, now + timedelta(minutes=5)))
        self.assertFalse(within_entry_grace(current, now + timedelta(minutes=6)))
        self.assertEqual(dual_horizon_signal(current, bars, now)[1], 1)

    def test_nonconsecutive_or_incomplete_month_rejected(self) -> None:
        current, now, bars = july_sample(84.0, 80.0, 75.0)
        bars[-1] = Bar(datetime(2026, 5, 29, tzinfo=UTC), 75.0)
        self.assertFalse(dual_horizon_signal(current, bars, now)[0])
        self.assertFalse(dual_horizon_signal(current, bars[:6], now)[0])

    def test_bad_endpoint_and_order_rejected(self) -> None:
        current, now, bars = july_sample(84.0, 80.0, 75.0)
        bars[5] = Bar(bars[5].opened, 0.0)
        self.assertFalse(dual_horizon_signal(current, bars, now)[0])
        current, now, bars = july_sample(84.0, 80.0, 75.0)
        bars[2] = Bar(bars[1].opened + timedelta(days=1), bars[2].close)
        self.assertFalse(dual_horizon_signal(current, bars, now)[0])

    def test_exit_occurs_on_sixth_entry_month_bar(self) -> None:
        opened = datetime(2026, 8, 3, 0, 1, tzinfo=UTC)
        sixth_bar = datetime(2026, 8, 10, tzinfo=UTC)
        self.assertFalse(should_close(opened, sixth_bar, sixth_bar, 4))
        self.assertTrue(should_close(opened, sixth_bar, sixth_bar, 5))

    def test_month_change_stale_and_malformed_guards(self) -> None:
        opened = datetime(2026, 8, 3, tzinfo=UTC)
        current = datetime(2026, 8, 14, tzinfo=UTC)
        self.assertFalse(should_close(opened, current, current, 4))
        self.assertTrue(
            should_close(opened, datetime(2026, 9, 1, tzinfo=UTC), current, 4)
        )
        self.assertTrue(should_close(opened, current, opened + timedelta(days=12), 4))
        self.assertTrue(should_close(None, current, current, 0))
        self.assertTrue(should_close(opened, current, current, -1))


if __name__ == "__main__":
    unittest.main()
