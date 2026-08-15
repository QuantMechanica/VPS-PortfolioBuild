"""Deterministic reference checks for QM5_41017 WTI counter-regime dates."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


UTC = timezone.utc
LONG_DAY = 8
SHORT_DAY = 26


@dataclass
class AttemptLedger:
    last_date_key: int = 0

    def consume(self, bar: datetime) -> bool:
        key = bar.year * 10_000 + bar.month * 100 + bar.day
        if key == self.last_date_key:
            return False
        self.last_date_key = key
        return True


def completed_state(close_1: float, close_253: float) -> tuple[int, float]:
    if (
        close_1 <= 0.0
        or close_253 <= 0.0
        or not math.isfinite(close_1)
        or not math.isfinite(close_253)
    ):
        raise ValueError("completed endpoints must be positive and finite")
    value = math.log(close_1 / close_253)
    direction = 1 if value > 0.0 else -1 if value < 0.0 else 0
    return direction, value


def entry_side(
    bar: datetime,
    now: datetime,
    direction: int,
    grace_minutes: int = 5,
) -> str | None:
    elapsed = now - bar
    if not timedelta(0) <= elapsed <= timedelta(minutes=grace_minutes):
        return None
    if bar.day == LONG_DAY and direction == -1:
        return "BUY"
    if bar.day == SHORT_DAY and direction == 1:
        return "SELL"
    return None


def should_close(
    opened: datetime | None,
    side: str,
    current_bar: datetime,
    now: datetime,
) -> bool:
    if opened is None or opened > now:
        return True
    expected = "BUY" if opened.day == LONG_DAY else "SELL" if opened.day == SHORT_DAY else None
    if side != expected:
        return True
    if current_bar > opened:
        return True
    return now - opened >= timedelta(days=1)


class DomCounterRegimeReferenceTest(unittest.TestCase):
    def test_day_8_buys_only_in_negative_completed_state(self) -> None:
        bar = datetime(2026, 9, 8, tzinfo=UTC)
        negative, value = completed_state(72.0, 80.0)
        self.assertLess(value, 0.0)
        self.assertEqual(entry_side(bar, bar, negative), "BUY")
        self.assertIsNone(entry_side(bar, bar, 1))
        self.assertIsNone(entry_side(bar, bar, 0))

    def test_day_26_sells_only_in_positive_completed_state(self) -> None:
        bar = datetime(2026, 8, 26, tzinfo=UTC)
        positive, value = completed_state(88.0, 80.0)
        self.assertGreater(value, 0.0)
        self.assertEqual(entry_side(bar, bar, positive), "SELL")
        self.assertIsNone(entry_side(bar, bar, -1))
        self.assertIsNone(entry_side(bar, bar, 0))

    def test_missing_exact_date_is_never_shifted(self) -> None:
        negative, _ = completed_state(72.0, 80.0)
        self.assertIsNone(
            entry_side(
                datetime(2026, 11, 9, tzinfo=UTC),
                datetime(2026, 11, 9, tzinfo=UTC),
                negative,
            )
        )

    def test_five_minute_grace_is_inclusive_and_late_is_flat(self) -> None:
        bar = datetime(2026, 9, 8, tzinfo=UTC)
        self.assertEqual(entry_side(bar, bar + timedelta(minutes=5), -1), "BUY")
        self.assertIsNone(entry_side(bar, bar + timedelta(minutes=5, seconds=1), -1))
        self.assertIsNone(entry_side(bar, bar - timedelta(seconds=1), -1))

    def test_exact_date_is_consumed_before_downstream_failure(self) -> None:
        ledger = AttemptLedger()
        bar = datetime(2026, 9, 8, tzinfo=UTC)
        self.assertTrue(ledger.consume(bar))
        # A hypothetical failed spread/ATR/order gate cannot retry the date.
        self.assertFalse(ledger.consume(bar))
        self.assertTrue(ledger.consume(datetime(2026, 9, 26, tzinfo=UTC)))

    def test_invalid_completed_endpoints_fail_closed(self) -> None:
        for endpoints in ((0.0, 80.0), (80.0, 0.0), (math.nan, 80.0)):
            with self.assertRaises(ValueError):
                completed_state(*endpoints)

    def test_next_d1_and_stale_exit_guards(self) -> None:
        opened = datetime(2026, 9, 8, 0, 1, tzinfo=UTC)
        same_bar = datetime(2026, 9, 8, tzinfo=UTC)
        next_bar = datetime(2026, 9, 9, tzinfo=UTC)
        self.assertFalse(should_close(opened, "BUY", same_bar, opened + timedelta(hours=12)))
        self.assertTrue(should_close(opened, "BUY", next_bar, next_bar))
        self.assertTrue(should_close(opened, "BUY", same_bar, opened + timedelta(days=1)))

    def test_malformed_side_or_entry_date_closes(self) -> None:
        opened = datetime(2026, 9, 8, 0, 1, tzinfo=UTC)
        same_bar = datetime(2026, 9, 8, tzinfo=UTC)
        self.assertTrue(should_close(opened, "SELL", same_bar, opened))
        malformed = datetime(2026, 9, 10, 0, 1, tzinfo=UTC)
        self.assertTrue(should_close(malformed, "BUY", same_bar, malformed))
        self.assertTrue(should_close(None, "BUY", same_bar, opened))


if __name__ == "__main__":
    unittest.main()
