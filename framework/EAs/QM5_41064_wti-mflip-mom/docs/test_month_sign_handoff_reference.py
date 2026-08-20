"""Deterministic reference checks for QM5_41064 WTI sign handoff."""

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


def decision_clock(
    current_bar: datetime,
    now: datetime,
    completed_newest_first: list[Bar],
) -> tuple[bool, bool, int, timedelta | None]:
    """Mirror the normalized new-month clock and late restart state."""

    offset = label_offset(current_bar, now)
    if offset is None or not completed_newest_first:
        return False, False, 0, offset
    normalized_current = current_bar + offset
    if normalized_current.date() != now.date():
        return False, False, 0, offset

    current_key = month_key(normalized_current)
    current_count = 0
    while (
        current_count < len(completed_newest_first)
        and month_key(completed_newest_first[current_count].opened + offset)
        == current_key
    ):
        current_count += 1
    if current_count >= len(completed_newest_first):
        return False, False, current_count, offset

    prior_key = month_key(completed_newest_first[current_count].opened + offset)
    if next_month_key(prior_key) != current_key:
        return False, False, current_count, offset
    late = current_count > 0 or not within_entry_grace(current_bar, now)
    return True, late, current_count, offset


def sign_handoff_signal(
    current_month_key: int,
    completed_newest_first: list[Bar],
    offset: timedelta,
) -> tuple[bool, int, float, float, tuple[float, float, float]]:
    """Mirror three completed month ends and the strict sign handoff."""

    month_keys: list[int] = []
    closes: list[float] = []
    for index, bar in enumerate(completed_newest_first):
        if bar.opened.timestamp() <= 0:
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        key = month_key(bar.opened + offset)
        if key == current_month_key:
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        if month_keys and key == month_keys[-1]:
            continue
        if not month_keys:
            if next_month_key(key) != current_month_key:
                return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        elif next_month_key(key) != month_keys[-1]:
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        if bar.close <= 0.0 or not math.isfinite(bar.close):
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        month_keys.append(key)
        closes.append(bar.close)
        if len(closes) == 3:
            break

    if len(closes) != 3:
        return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
    new_return = math.log(closes[0] / closes[1])
    old_return = math.log(closes[1] / closes[2])
    direction = 0
    if old_return < 0.0 < new_return:
        direction = 1
    elif old_return > 0.0 > new_return:
        direction = -1
    return True, direction, new_return, old_return, tuple(closes)


def should_close(
    opened: datetime | None,
    current_bar: datetime,
    now: datetime,
    offset: timedelta | None,
    max_days: int = 40,
) -> bool:
    if opened is None or opened > now or offset is None:
        return True
    if month_key(opened) != month_key(current_bar + offset):
        return True
    return now - opened >= timedelta(days=max_days)


def sample(
    newest: float,
    middle: float,
    oldest: float,
    prior_date_labels: bool = False,
) -> tuple[datetime, datetime, list[Bar]]:
    current = datetime(2026, 8, 3, tzinfo=UTC)
    now = current
    bars = [
        Bar(datetime(2026, 7, 31, tzinfo=UTC), newest),
        Bar(datetime(2026, 7, 30, tzinfo=UTC), newest - 0.5),
        Bar(datetime(2026, 6, 30, tzinfo=UTC), middle),
        Bar(datetime(2026, 6, 29, tzinfo=UTC), middle + 0.5),
        Bar(datetime(2026, 5, 29, tzinfo=UTC), oldest),
    ]
    if prior_date_labels:
        current -= timedelta(days=1)
        bars = [Bar(bar.opened - timedelta(days=1), bar.close) for bar in bars]
    return current, now, bars


class MonthSignHandoffReferenceTest(unittest.TestCase):
    def test_negative_to_positive_is_long(self) -> None:
        current, now, bars = sample(110.0, 100.0, 105.0)
        decision, late, count, offset = decision_clock(current, now, bars)
        self.assertTrue(decision)
        self.assertFalse(late)
        self.assertEqual(count, 0)
        assert offset is not None
        valid, direction, new_value, old_value, endpoints = sign_handoff_signal(
            202608, bars, offset
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertGreater(new_value, 0.0)
        self.assertLess(old_value, 0.0)
        self.assertEqual(endpoints, (110.0, 100.0, 105.0))

    def test_positive_to_negative_is_short(self) -> None:
        current, now, bars = sample(90.0, 100.0, 95.0)
        offset = label_offset(current, now)
        assert offset is not None
        valid, direction, new_value, old_value, _ = sign_handoff_signal(
            202608, bars, offset
        )
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertLess(new_value, 0.0)
        self.assertGreater(old_value, 0.0)

    def test_same_sign_and_exact_zero_are_flat(self) -> None:
        current, now, bars = sample(110.0, 100.0, 90.0)
        offset = label_offset(current, now)
        assert offset is not None
        self.assertEqual(sign_handoff_signal(202608, bars, offset)[1], 0)
        current, now, bars = sample(100.0, 100.0, 105.0)
        offset = label_offset(current, now)
        assert offset is not None
        valid, direction, new_value, _, _ = sign_handoff_signal(
            202608, bars, offset
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertEqual(new_value, 0.0)

    def test_uniform_prior_date_label_normalization(self) -> None:
        current, now, bars = sample(110.0, 100.0, 105.0, True)
        decision, late, count, offset = decision_clock(current, now, bars)
        self.assertTrue(decision)
        self.assertFalse(late)
        self.assertEqual(count, 0)
        self.assertEqual(offset, timedelta(days=1))
        assert offset is not None
        self.assertEqual(sign_handoff_signal(202608, bars, offset)[1], 1)
        self.assertTrue(within_entry_grace(current, now + timedelta(minutes=5)))
        self.assertFalse(within_entry_grace(current, now + timedelta(minutes=6)))

    def test_late_restart_is_consumed_flat(self) -> None:
        current, now, bars = sample(110.0, 100.0, 105.0)
        bars.insert(0, Bar(datetime(2026, 8, 3, tzinfo=UTC), 111.0))
        current = datetime(2026, 8, 4, tzinfo=UTC)
        now = current
        decision, late, count, _ = decision_clock(current, now, bars)
        self.assertTrue(decision)
        self.assertTrue(late)
        self.assertEqual(count, 1)

    def test_nonconsecutive_or_current_month_endpoint_rejected(self) -> None:
        current, now, bars = sample(110.0, 100.0, 105.0)
        offset = label_offset(current, now)
        assert offset is not None
        bars[-1] = Bar(datetime(2026, 4, 30, tzinfo=UTC), 105.0)
        self.assertFalse(sign_handoff_signal(202608, bars, offset)[0])
        _, _, bars = sample(110.0, 100.0, 105.0)
        bars.insert(0, Bar(datetime(2026, 8, 3, tzinfo=UTC), 111.0))
        self.assertFalse(sign_handoff_signal(202608, bars, offset)[0])

    def test_bad_endpoint_and_reverse_order_rejected(self) -> None:
        current, now, bars = sample(110.0, 100.0, 105.0)
        offset = label_offset(current, now)
        assert offset is not None
        bars[2] = Bar(bars[2].opened, 0.0)
        self.assertFalse(sign_handoff_signal(202608, bars, offset)[0])
        _, _, bars = sample(110.0, 100.0, 105.0)
        bars[1] = Bar(bars[0].opened + timedelta(days=1), bars[1].close)
        self.assertFalse(sign_handoff_signal(202608, bars, offset)[0])

    def test_next_month_stale_and_malformed_exit_guards(self) -> None:
        opened = datetime(2026, 8, 3, 0, 1, tzinfo=UTC)
        current = datetime(2026, 8, 14, tzinfo=UTC)
        self.assertFalse(should_close(opened, current, current, timedelta(0)))
        self.assertTrue(
            should_close(
                opened,
                datetime(2026, 9, 1, tzinfo=UTC),
                datetime(2026, 9, 1, tzinfo=UTC),
                timedelta(0),
            )
        )
        self.assertTrue(
            should_close(
                opened,
                current,
                opened + timedelta(days=40),
                timedelta(0),
            )
        )
        self.assertTrue(should_close(None, current, current, timedelta(0)))
        self.assertTrue(should_close(opened, current, current, None))


if __name__ == "__main__":
    unittest.main()
