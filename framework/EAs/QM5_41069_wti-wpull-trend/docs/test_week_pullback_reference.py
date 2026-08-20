"""Deterministic reference checks for QM5_41069 WTI weekly pullback trend."""

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


def date_key(value: datetime) -> int:
    return value.year * 10_000 + value.month * 100 + value.day


def week_key(value: datetime) -> int:
    return date_key(value - timedelta(days=value.weekday()))


def key_to_date(value: int) -> datetime:
    return datetime(value // 10_000, (value // 100) % 100, value % 100, tzinfo=UTC)


def next_week_key(value: int) -> int:
    anchor = key_to_date(value)
    if week_key(anchor) != value:
        return 0
    return week_key(anchor + timedelta(days=7))


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


def decision_clock(
    current_bar: datetime,
    now: datetime,
    completed_newest_first: list[Bar],
) -> tuple[bool, bool, int, timedelta | None]:
    """Mirror the normalized first-tradable-week-bar and late-restart state."""

    offset = label_offset(current_bar, now)
    if offset is None or not completed_newest_first:
        return False, False, 0, offset
    normalized_current = current_bar + offset
    if normalized_current.date() != now.date():
        return False, False, 0, offset

    current_key = week_key(normalized_current)
    if current_key != week_key(now):
        return False, False, 0, offset
    current_count = 0
    while (
        current_count < len(completed_newest_first)
        and week_key(completed_newest_first[current_count].opened + offset)
        == current_key
    ):
        current_count += 1
    if current_count >= len(completed_newest_first):
        return False, False, current_count, offset

    prior_key = week_key(completed_newest_first[current_count].opened + offset)
    if next_week_key(prior_key) != current_key:
        return False, False, current_count, offset
    late = current_count > 0 or not within_entry_grace(current_bar, now)
    return True, late, current_count, offset


def pullback_signal(
    current_week_key: int,
    completed_newest_first: list[Bar],
    offset: timedelta,
) -> tuple[bool, int, float, float, tuple[float, float, float]]:
    """Mirror three completed week ends and the smaller-countermove rule."""

    week_keys: list[int] = []
    closes: list[float] = []
    for index, bar in enumerate(completed_newest_first):
        if bar.opened.timestamp() <= 0:
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        key = week_key(bar.opened + offset)
        if key == current_week_key:
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        if week_keys and key == week_keys[-1]:
            continue
        if not week_keys:
            if next_week_key(key) != current_week_key:
                return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        elif next_week_key(key) != week_keys[-1]:
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        if bar.close <= 0.0 or not math.isfinite(bar.close):
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        week_keys.append(key)
        closes.append(bar.close)
        if len(closes) == 3:
            break

    if len(closes) != 3:
        return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
    new_return = math.log(closes[0] / closes[1])
    old_return = math.log(closes[1] / closes[2])
    direction = 0
    # Under strict sign opposition, newest-vs-oldest endpoints are
    # algebraically equivalent to the absolute-log-return comparison and make
    # exact equality deterministic under binary floating-point arithmetic.
    if old_return > 0.0 > new_return and closes[0] > closes[2]:
        direction = 1
    elif old_return < 0.0 < new_return and closes[0] < closes[2]:
        direction = -1
    return True, direction, new_return, old_return, tuple(closes)


def consume_attempt(attempts: set[int], current_week_key: int) -> bool:
    if current_week_key in attempts:
        return False
    attempts.add(current_week_key)
    return True


def should_close(
    opened: datetime | None,
    current_bar: datetime,
    now: datetime,
    offset: timedelta | None,
    max_days: int = 10,
) -> bool:
    if opened is None or opened > now or offset is None:
        return True
    if week_key(opened) != week_key(current_bar + offset):
        return True
    return now - opened >= timedelta(days=max_days)


def sample(
    newest: float,
    middle: float,
    oldest: float,
    prior_date_labels: bool = False,
) -> tuple[datetime, datetime, list[Bar]]:
    current = datetime(2026, 8, 24, tzinfo=UTC)
    now = current
    bars = [
        Bar(datetime(2026, 8, 21, tzinfo=UTC), newest),
        Bar(datetime(2026, 8, 20, tzinfo=UTC), newest - 0.5),
        Bar(datetime(2026, 8, 14, tzinfo=UTC), middle),
        Bar(datetime(2026, 8, 13, tzinfo=UTC), middle + 0.5),
        Bar(datetime(2026, 8, 7, tzinfo=UTC), oldest),
    ]
    if prior_date_labels:
        current -= timedelta(days=1)
        bars = [Bar(bar.opened - timedelta(days=1), bar.close) for bar in bars]
    return current, now, bars


class WeekPullbackReferenceTest(unittest.TestCase):
    def test_smaller_negative_pullback_in_positive_trend_is_long(self) -> None:
        current, now, bars = sample(105.0, 110.0, 90.0)
        decision, late, count, offset = decision_clock(current, now, bars)
        self.assertTrue(decision)
        self.assertFalse(late)
        self.assertEqual(count, 0)
        assert offset is not None
        valid, direction, new_value, old_value, endpoints = pullback_signal(
            20260824, bars, offset
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertLess(new_value, 0.0)
        self.assertGreater(old_value, 0.0)
        self.assertLess(abs(new_value), abs(old_value))
        self.assertEqual(endpoints, (105.0, 110.0, 90.0))

    def test_smaller_positive_pullback_in_negative_trend_is_short(self) -> None:
        current, now, bars = sample(95.0, 90.0, 110.0)
        offset = label_offset(current, now)
        assert offset is not None
        valid, direction, new_value, old_value, _ = pullback_signal(
            20260824, bars, offset
        )
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertGreater(new_value, 0.0)
        self.assertLess(old_value, 0.0)
        self.assertLess(abs(new_value), abs(old_value))

    def test_same_sign_and_exact_zero_are_flat(self) -> None:
        current, now, bars = sample(110.0, 100.0, 90.0)
        offset = label_offset(current, now)
        assert offset is not None
        self.assertEqual(pullback_signal(20260824, bars, offset)[1], 0)
        current, now, bars = sample(100.0, 100.0, 105.0)
        offset = label_offset(current, now)
        assert offset is not None
        valid, direction, new_value, _, _ = pullback_signal(
            20260824, bars, offset
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertEqual(new_value, 0.0)

    def test_equal_or_larger_countermove_is_flat(self) -> None:
        current, now, bars = sample(100.0, 110.0, 100.0)
        offset = label_offset(current, now)
        assert offset is not None
        valid, direction, new_value, old_value, _ = pullback_signal(
            20260824, bars, offset
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertAlmostEqual(abs(new_value), abs(old_value))

        current, now, bars = sample(90.0, 110.0, 100.0)
        offset = label_offset(current, now)
        assert offset is not None
        valid, direction, new_value, old_value, _ = pullback_signal(
            20260824, bars, offset
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertGreater(abs(new_value), abs(old_value))

    def test_uniform_prior_date_label_normalization_and_grace(self) -> None:
        current, now, bars = sample(105.0, 110.0, 90.0, True)
        decision, late, count, offset = decision_clock(current, now, bars)
        self.assertTrue(decision)
        self.assertFalse(late)
        self.assertEqual(count, 0)
        self.assertEqual(offset, timedelta(days=1))
        assert offset is not None
        self.assertEqual(pullback_signal(20260824, bars, offset)[1], 1)
        self.assertTrue(within_entry_grace(current, now + timedelta(minutes=180)))
        self.assertFalse(within_entry_grace(current, now + timedelta(minutes=181)))

    def test_late_restart_is_consumed_flat(self) -> None:
        current, now, bars = sample(105.0, 110.0, 90.0)
        bars.insert(0, Bar(datetime(2026, 8, 24, tzinfo=UTC), 111.0))
        current = datetime(2026, 8, 25, tzinfo=UTC)
        now = current
        decision, late, count, _ = decision_clock(current, now, bars)
        self.assertTrue(decision)
        self.assertTrue(late)
        self.assertEqual(count, 1)

    def test_nonconsecutive_or_current_week_endpoint_rejected(self) -> None:
        current, now, bars = sample(105.0, 110.0, 90.0)
        offset = label_offset(current, now)
        assert offset is not None
        bars[-1] = Bar(datetime(2026, 7, 31, tzinfo=UTC), 105.0)
        self.assertFalse(pullback_signal(20260824, bars, offset)[0])
        _, _, bars = sample(105.0, 110.0, 90.0)
        bars.insert(0, Bar(datetime(2026, 8, 24, tzinfo=UTC), 111.0))
        self.assertFalse(pullback_signal(20260824, bars, offset)[0])

    def test_bad_endpoint_and_reverse_order_rejected(self) -> None:
        current, now, bars = sample(105.0, 110.0, 90.0)
        offset = label_offset(current, now)
        assert offset is not None
        bars[2] = Bar(bars[2].opened, 0.0)
        self.assertFalse(pullback_signal(20260824, bars, offset)[0])
        _, _, bars = sample(105.0, 110.0, 90.0)
        bars[1] = Bar(bars[0].opened + timedelta(days=1), bars[1].close)
        self.assertFalse(pullback_signal(20260824, bars, offset)[0])

    def test_week_keys_cross_year_and_attempt_is_single_use(self) -> None:
        self.assertEqual(week_key(datetime(2027, 1, 3, tzinfo=UTC)), 20261228)
        self.assertEqual(next_week_key(20261228), 20270104)
        attempts: set[int] = set()
        self.assertTrue(consume_attempt(attempts, 20270104))
        self.assertFalse(consume_attempt(attempts, 20270104))

    def test_next_week_stale_and_malformed_exit_guards(self) -> None:
        opened = datetime(2026, 8, 24, 0, 1, tzinfo=UTC)
        current = datetime(2026, 8, 28, tzinfo=UTC)
        self.assertFalse(should_close(opened, current, current, timedelta(0)))
        self.assertTrue(
            should_close(
                opened,
                datetime(2026, 8, 31, tzinfo=UTC),
                datetime(2026, 8, 31, tzinfo=UTC),
                timedelta(0),
            )
        )
        self.assertTrue(
            should_close(
                opened,
                current,
                opened + timedelta(days=10),
                timedelta(0),
            )
        )
        self.assertTrue(should_close(None, current, current, timedelta(0)))
        self.assertTrue(should_close(opened, current, current, None))


if __name__ == "__main__":
    unittest.main()
