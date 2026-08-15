"""Deterministic reference checks for QM5_41013 month-opening momentum."""

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


def classify_clock(current_bar: datetime, completed_newest_first: list[Bar]) -> str:
    """Mirror the EA's below/exact/late current-month bar-count state."""

    current_key = month_key(current_bar)
    count = 0
    for bar in completed_newest_first:
        if month_key(bar.opened) != current_key:
            break
        count += 1
    if count < 5:
        return "wait"
    if count == 5:
        return "exact"
    return "late_consume_flat"


def opening_segment_signal(
    current_bar: datetime, completed_newest_first: list[Bar]
) -> tuple[bool, int, float]:
    """Return validity, direction, and exact log return for the locked rule."""

    current_key = month_key(current_bar)
    if classify_clock(current_bar, completed_newest_first) != "exact":
        return False, 0, 0.0
    if len(completed_newest_first) < 6:
        return False, 0, 0.0

    sample = completed_newest_first[:6]
    if any(bar.close <= 0.0 or not math.isfinite(bar.close) for bar in sample):
        return False, 0, 0.0
    if any(sample[i - 1].opened <= sample[i].opened for i in range(1, 6)):
        return False, 0, 0.0
    if any(month_key(bar.opened) != current_key for bar in sample[:5]):
        return False, 0, 0.0

    prior_key = month_key(sample[5].opened)
    if next_month_key(prior_key) != current_key:
        return False, 0, 0.0

    value = math.log(sample[0].close / sample[5].close)
    direction = 1 if value > 0.0 else -1 if value < 0.0 else 0
    return True, direction, value


def should_close(opened: datetime | None, now: datetime, max_days: int = 35) -> bool:
    if opened is None or opened > now:
        return True
    if month_key(opened) != month_key(now):
        return True
    return now - opened >= timedelta(days=max_days)


def august_sample(final_close: float, prior_close: float = 80.0) -> tuple[datetime, list[Bar]]:
    current = datetime(2026, 8, 10, tzinfo=UTC)
    bars = [
        Bar(datetime(2026, 8, 7, tzinfo=UTC), final_close),
        Bar(datetime(2026, 8, 6, tzinfo=UTC), 83.0),
        Bar(datetime(2026, 8, 5, tzinfo=UTC), 82.0),
        Bar(datetime(2026, 8, 4, tzinfo=UTC), 81.0),
        Bar(datetime(2026, 8, 3, tzinfo=UTC), 80.5),
        Bar(datetime(2026, 7, 31, tzinfo=UTC), prior_close),
    ]
    return current, bars


class MonthOpeningMomentumReferenceTest(unittest.TestCase):
    def test_positive_segment_buys_on_exact_sixth_bar(self) -> None:
        current, bars = august_sample(84.0)
        valid, direction, value = opening_segment_signal(current, bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertAlmostEqual(value, math.log(84.0 / 80.0), places=14)

    def test_negative_segment_sells(self) -> None:
        current, bars = august_sample(76.0)
        valid, direction, value = opening_segment_signal(current, bars)
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertLess(value, 0.0)

    def test_exact_zero_is_valid_but_flat(self) -> None:
        current, bars = august_sample(80.0)
        valid, direction, value = opening_segment_signal(current, bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertEqual(value, 0.0)

    def test_four_completed_bars_waits(self) -> None:
        current, bars = august_sample(84.0)
        self.assertEqual(classify_clock(current, bars[1:]), "wait")

    def test_restart_after_six_completed_bars_consumes_flat(self) -> None:
        current, bars = august_sample(84.0)
        bars.insert(0, Bar(datetime(2026, 8, 8, tzinfo=UTC), 85.0))
        self.assertEqual(classify_clock(current, bars), "late_consume_flat")
        self.assertEqual(opening_segment_signal(current, bars), (False, 0, 0.0))

    def test_nonconsecutive_prior_month_rejected(self) -> None:
        current = datetime(2026, 1, 12, tzinfo=UTC)
        _, bars = august_sample(84.0)
        january = [
            Bar(datetime(2026, 1, day, tzinfo=UTC), 84.0 - index)
            for index, day in enumerate((9, 8, 7, 6, 5))
        ]
        january.append(Bar(datetime(2025, 11, 28, tzinfo=UTC), 80.0))
        self.assertEqual(opening_segment_signal(current, january), (False, 0, 0.0))

    def test_month_change_and_stale_guards(self) -> None:
        opened = datetime(2026, 8, 10, tzinfo=UTC)
        self.assertFalse(should_close(opened, datetime(2026, 8, 31, tzinfo=UTC)))
        self.assertTrue(should_close(opened, datetime(2026, 9, 1, tzinfo=UTC)))
        self.assertTrue(should_close(opened, opened + timedelta(days=35)))
        self.assertTrue(should_close(None, opened))


if __name__ == "__main__":
    unittest.main()
