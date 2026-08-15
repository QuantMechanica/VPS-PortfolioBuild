"""Deterministic reference checks for QM5_41016 month-closing momentum."""

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


def classify_clock(
    current_bar: datetime,
    completed_newest_first: list[Bar],
    now: datetime,
    grace_minutes: int = 5,
) -> str:
    """Mirror exact first-bar versus consumed-late broker-month state."""

    current_key = month_key(current_bar)
    current_count = 0
    for bar in completed_newest_first:
        if month_key(bar.opened) != current_key:
            break
        current_count += 1
    if current_count >= len(completed_newest_first):
        return "invalid"
    prior_key = month_key(completed_newest_first[current_count].opened)
    if next_month_key(prior_key) != current_key:
        return "invalid"
    elapsed = now - current_bar
    if (
        current_count == 0
        and timedelta(0) <= elapsed <= timedelta(minutes=grace_minutes)
    ):
        return "exact"
    return "late_consume_flat"


def closing_segment_signal(
    current_bar: datetime, completed_newest_first: list[Bar]
) -> tuple[bool, int, float]:
    """Return validity, direction, and exact prior-month five-interval return."""

    if len(completed_newest_first) < 6:
        return False, 0, 0.0
    sample = completed_newest_first[:6]
    prior_key = month_key(sample[0].opened)
    if next_month_key(prior_key) != month_key(current_bar):
        return False, 0, 0.0
    if any(bar.close <= 0.0 or not math.isfinite(bar.close) for bar in sample):
        return False, 0, 0.0
    if any(month_key(bar.opened) != prior_key for bar in sample):
        return False, 0, 0.0
    if any(sample[i - 1].opened <= sample[i].opened for i in range(1, 6)):
        return False, 0, 0.0

    value = math.log(sample[0].close / sample[5].close)
    direction = 1 if value > 0.0 else -1 if value < 0.0 else 0
    return True, direction, value


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


def july_sample(final_close: float, first_close: float = 80.0) -> tuple[datetime, list[Bar]]:
    current = datetime(2026, 8, 3, tzinfo=UTC)
    bars = [
        Bar(datetime(2026, 7, 31, tzinfo=UTC), final_close),
        Bar(datetime(2026, 7, 30, tzinfo=UTC), 83.0),
        Bar(datetime(2026, 7, 29, tzinfo=UTC), 82.0),
        Bar(datetime(2026, 7, 28, tzinfo=UTC), 81.0),
        Bar(datetime(2026, 7, 27, tzinfo=UTC), 80.5),
        Bar(datetime(2026, 7, 24, tzinfo=UTC), first_close),
    ]
    return current, bars


class MonthClosingMomentumReferenceTest(unittest.TestCase):
    def test_positive_final_five_intervals_buy(self) -> None:
        current, bars = july_sample(84.0)
        valid, direction, value = closing_segment_signal(current, bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertAlmostEqual(value, math.log(84.0 / 80.0), places=14)

    def test_negative_final_five_intervals_sell(self) -> None:
        current, bars = july_sample(76.0)
        valid, direction, value = closing_segment_signal(current, bars)
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertLess(value, 0.0)

    def test_exact_zero_is_valid_but_flat(self) -> None:
        current, bars = july_sample(80.0)
        self.assertEqual(closing_segment_signal(current, bars), (True, 0, 0.0))

    def test_mixed_prior_month_endpoints_rejected(self) -> None:
        current, bars = july_sample(84.0)
        bars[-1] = Bar(datetime(2026, 6, 30, tzinfo=UTC), 80.0)
        self.assertEqual(closing_segment_signal(current, bars), (False, 0, 0.0))

    def test_nonconsecutive_prior_month_rejected(self) -> None:
        current = datetime(2026, 8, 3, tzinfo=UTC)
        _, bars = july_sample(84.0)
        bars = [Bar(bar.opened.replace(month=5), bar.close) for bar in bars]
        self.assertEqual(closing_segment_signal(current, bars), (False, 0, 0.0))

    def test_first_bar_grace_and_late_attachment(self) -> None:
        current, bars = july_sample(84.0)
        self.assertEqual(
            classify_clock(current, bars, current + timedelta(minutes=5)), "exact"
        )
        self.assertEqual(
            classify_clock(current, bars, current + timedelta(minutes=6)),
            "late_consume_flat",
        )
        later_bar = datetime(2026, 8, 4, tzinfo=UTC)
        completed = [Bar(current, 84.5), *bars]
        self.assertEqual(
            classify_clock(later_bar, completed, later_bar),
            "late_consume_flat",
        )

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
