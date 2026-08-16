"""Deterministic reference checks for QM5_41023 boundary-segment momentum."""

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
    current_bar: datetime, now: datetime, grace_minutes: int = 180
) -> bool:
    elapsed = now - current_bar
    if elapsed < timedelta(0):
        return False
    session_elapsed = elapsed % timedelta(days=1)
    return session_elapsed <= timedelta(minutes=grace_minutes)


def boundary_segment_signal(
    current_bar: datetime,
    completed_newest_first: list[Bar],
    now: datetime,
    opening_sessions: int = 5,
    closing_intervals: int = 5,
    min_prior_month_bars: int = 15,
) -> tuple[bool, int, float, float]:
    """Mirror the two non-overlapping completed prior-month segments."""

    offset = label_offset(current_bar, now)
    if offset is None or len(completed_newest_first) < min_prior_month_bars + 1:
        return False, 0, 0.0, 0.0

    current_key = month_key(current_bar + offset)
    bars = completed_newest_first
    prior_key = month_key(bars[0].opened + offset)
    if next_month_key(prior_key) != current_key:
        return False, 0, 0.0, 0.0

    prior_count = 0
    while prior_count < len(bars) and month_key(bars[prior_count].opened + offset) == prior_key:
        close = bars[prior_count].close
        if close <= 0.0 or not math.isfinite(close):
            return False, 0, 0.0, 0.0
        if prior_count and bars[prior_count - 1].opened <= bars[prior_count].opened:
            return False, 0, 0.0, 0.0
        prior_count += 1

    if prior_count < min_prior_month_bars or prior_count >= len(bars):
        return False, 0, 0.0, 0.0

    opening_index = prior_count - opening_sessions
    closing_index = closing_intervals
    if opening_index <= closing_index or opening_index < 0 or closing_index >= prior_count:
        return False, 0, 0.0, 0.0

    anchor = bars[prior_count]
    if next_month_key(month_key(anchor.opened + offset)) != prior_key:
        return False, 0, 0.0, 0.0
    if anchor.close <= 0.0 or not math.isfinite(anchor.close):
        return False, 0, 0.0, 0.0

    opening_return = math.log(bars[opening_index].close / anchor.close)
    closing_return = math.log(bars[0].close / bars[closing_index].close)
    if not math.isfinite(opening_return) or not math.isfinite(closing_return):
        return False, 0, 0.0, 0.0

    direction = 0
    if opening_return > 0.0 and closing_return > 0.0:
        direction = 1
    elif opening_return < 0.0 and closing_return < 0.0:
        direction = -1
    return True, direction, opening_return, closing_return


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
    opening_fifth: float,
    closing_start: float,
    month_end: float,
    anchor: float,
    prior_date_labels: bool = False,
) -> tuple[datetime, datetime, list[Bar]]:
    dates: list[datetime] = []
    cursor = datetime(2026, 7, 1, tzinfo=UTC)
    while cursor.month == 7:
        if cursor.weekday() < 5:
            dates.append(cursor)
        cursor += timedelta(days=1)

    closes = [77.0 + index * 0.1 for index in range(len(dates))]
    closes[4] = opening_fifth
    closes[-6] = closing_start
    closes[-1] = month_end
    chronological = [Bar(opened, close) for opened, close in zip(dates, closes)]
    bars = list(reversed(chronological))
    bars.append(Bar(datetime(2026, 6, 30, tzinfo=UTC), anchor))

    current = datetime(2026, 8, 3, tzinfo=UTC)
    now = current
    if prior_date_labels:
        current -= timedelta(days=1)
        bars = [Bar(bar.opened - timedelta(days=1), bar.close) for bar in bars]
    return current, now, bars


class MonthBoundarySegmentReferenceTest(unittest.TestCase):
    def test_positive_agreement_is_long(self) -> None:
        current, now, bars = july_sample(80.0, 81.0, 84.0, 75.0)
        valid, direction, opening_value, closing_value = boundary_segment_signal(
            current, bars, now
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertAlmostEqual(opening_value, math.log(80.0 / 75.0), places=14)
        self.assertAlmostEqual(closing_value, math.log(84.0 / 81.0), places=14)

    def test_negative_agreement_is_short(self) -> None:
        current, now, bars = july_sample(80.0, 81.0, 76.0, 85.0)
        valid, direction, opening_value, closing_value = boundary_segment_signal(
            current, bars, now
        )
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertLess(opening_value, 0.0)
        self.assertLess(closing_value, 0.0)

    def test_disagreement_and_exact_zero_are_flat(self) -> None:
        current, now, bars = july_sample(80.0, 81.0, 84.0, 85.0)
        self.assertEqual(boundary_segment_signal(current, bars, now)[1], 0)
        current, now, bars = july_sample(75.0, 81.0, 84.0, 75.0)
        valid, direction, opening_value, _ = boundary_segment_signal(current, bars, now)
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertEqual(opening_value, 0.0)

    def test_middle_path_does_not_change_signal(self) -> None:
        current, now, bars = july_sample(80.0, 81.0, 84.0, 75.0)
        baseline = boundary_segment_signal(current, bars, now)
        prior_count = len(bars) - 1
        opening_index = prior_count - 5
        for index in range(6, opening_index):
            bars[index] = Bar(bars[index].opened, 1_000.0 + index)
        changed = boundary_segment_signal(current, bars, now)
        self.assertEqual(baseline, changed)

    def test_uniform_prior_date_label_normalization(self) -> None:
        current, now, bars = july_sample(80.0, 81.0, 84.0, 75.0, True)
        self.assertEqual(label_offset(current, now), timedelta(days=1))
        self.assertTrue(within_entry_grace(current, now + timedelta(minutes=180)))
        self.assertFalse(within_entry_grace(current, now + timedelta(minutes=181)))
        self.assertEqual(boundary_segment_signal(current, bars, now)[1], 1)

    def test_short_or_overlapping_month_is_rejected(self) -> None:
        current, now, bars = july_sample(80.0, 81.0, 84.0, 75.0)
        shortened = bars[:14] + [bars[-1]]
        self.assertFalse(boundary_segment_signal(current, shortened, now)[0])
        self.assertFalse(
            boundary_segment_signal(
                current,
                bars,
                now,
                opening_sessions=12,
                closing_intervals=12,
            )[0]
        )

    def test_nonconsecutive_anchor_month_is_rejected(self) -> None:
        current, now, bars = july_sample(80.0, 81.0, 84.0, 75.0)
        bars[-1] = Bar(datetime(2026, 5, 29, tzinfo=UTC), 75.0)
        self.assertFalse(boundary_segment_signal(current, bars, now)[0])

    def test_bad_middle_price_and_order_are_rejected(self) -> None:
        current, now, bars = july_sample(80.0, 81.0, 84.0, 75.0)
        bars[10] = Bar(bars[10].opened, math.nan)
        self.assertFalse(boundary_segment_signal(current, bars, now)[0])
        current, now, bars = july_sample(80.0, 81.0, 84.0, 75.0)
        bars[2] = Bar(bars[1].opened + timedelta(days=1), bars[2].close)
        self.assertFalse(boundary_segment_signal(current, bars, now)[0])

    def test_exit_occurs_on_sixth_entry_month_bar(self) -> None:
        opened = datetime(2026, 8, 3, 0, 1, tzinfo=UTC)
        sixth_bar = datetime(2026, 8, 10, tzinfo=UTC)
        self.assertFalse(should_close(opened, sixth_bar, sixth_bar, 4))
        self.assertTrue(should_close(opened, sixth_bar, sixth_bar, 5))

    def test_month_change_stale_and_malformed_guards(self) -> None:
        opened = datetime(2026, 8, 3, tzinfo=UTC)
        current = datetime(2026, 8, 14, tzinfo=UTC)
        self.assertFalse(should_close(opened, current, current, 4))
        self.assertTrue(should_close(opened, datetime(2026, 9, 1, tzinfo=UTC), current, 4))
        self.assertTrue(should_close(opened, current, opened + timedelta(days=12), 4))
        self.assertTrue(should_close(None, current, current, 0))
        self.assertTrue(should_close(opened, current, current, -1))


if __name__ == "__main__":
    unittest.main()
