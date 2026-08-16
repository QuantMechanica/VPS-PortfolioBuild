#!/usr/bin/env python3
"""Pure reference checks for QM5_41026 calendar and reversal mechanics."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


UTC = timezone.utc


@dataclass(frozen=True)
class Bar:
    timestamp: datetime
    close: float


def month_key(value: datetime) -> int:
    return value.year * 100 + value.month


def previous_month_key(key: int) -> int:
    year, month = divmod(key, 100)
    month -= 1
    if month < 1:
        year -= 1
        month = 12
    return year * 100 + month


def label_offset_seconds(raw_bar: datetime, broker_now: datetime) -> int:
    elapsed = int((broker_now - raw_bar).total_seconds())
    if elapsed < 0:
        return -1
    if elapsed < 86_400:
        return 0
    if elapsed < 172_800:
        return 86_400
    return -1


def within_entry_grace(raw_bar: datetime, broker_now: datetime) -> bool:
    elapsed = int((broker_now - raw_bar).total_seconds())
    if elapsed < 0:
        return False
    return elapsed % 86_400 <= 180 * 60


def is_first_genuine_friday(current: datetime, prior: datetime) -> bool:
    # Python Monday=0, hence Friday=4 and Thursday=3.
    return (
        current.weekday() == 4
        and 1 <= current.day <= 7
        and prior.weekday() == 3
        and prior < current
    )


def load_prior_month_return(bars: list[Bar], current_month: int) -> float:
    prior_month = previous_month_key(current_month)
    prior_prior_month = previous_month_key(prior_month)
    prior_end: Bar | None = None
    prior_prior_end: Bar | None = None

    for index, bar in enumerate(bars):
        if index and bars[index - 1].timestamp <= bar.timestamp:
            raise ValueError("bars must be newest first")
        key = month_key(bar.timestamp)
        if key == current_month:
            if prior_end or prior_prior_end:
                raise ValueError("non-contiguous current month")
            continue
        if key == prior_month:
            if prior_prior_end:
                raise ValueError("non-contiguous prior month")
            if prior_end is None:
                prior_end = bar
            continue
        if key == prior_prior_month:
            if prior_end is None:
                raise ValueError("missing prior month")
            prior_prior_end = bar
            break
        raise ValueError("unexpected month before endpoints")

    if prior_end is None or prior_prior_end is None:
        raise ValueError("endpoint missing")
    if prior_end.close <= 0 or prior_prior_end.close <= 0:
        raise ValueError("invalid price")
    return math.log(prior_end.close / prior_prior_end.close)


def should_buy(prior_month_return: float) -> bool:
    return math.isfinite(prior_month_return) and prior_month_return < 0.0


class ReferenceTests(unittest.TestCase):
    def test_native_and_lagged_energy_labels(self) -> None:
        now = datetime(2026, 8, 7, 1, 30, tzinfo=UTC)
        self.assertEqual(
            label_offset_seconds(datetime(2026, 8, 7, tzinfo=UTC), now), 0
        )
        self.assertEqual(
            label_offset_seconds(datetime(2026, 8, 6, tzinfo=UTC), now), 86_400
        )
        self.assertEqual(
            label_offset_seconds(datetime(2026, 8, 5, tzinfo=UTC), now), -1
        )

    def test_first_friday_requires_day_one_to_seven_and_thursday(self) -> None:
        fri = datetime(2026, 8, 7, tzinfo=UTC)
        thu = datetime(2026, 8, 6, tzinfo=UTC)
        self.assertTrue(is_first_genuine_friday(fri, thu))
        self.assertFalse(
            is_first_genuine_friday(datetime(2026, 8, 14, tzinfo=UTC), thu)
        )
        self.assertFalse(
            is_first_genuine_friday(fri, datetime(2026, 8, 5, tzinfo=UTC))
        )

    def test_entry_grace_works_for_both_label_offsets(self) -> None:
        native = datetime(2026, 8, 7, tzinfo=UTC)
        lagged = datetime(2026, 8, 6, tzinfo=UTC)
        self.assertTrue(
            within_entry_grace(native, native + timedelta(minutes=180))
        )
        self.assertTrue(
            within_entry_grace(lagged, lagged + timedelta(days=1, minutes=180))
        )
        self.assertFalse(
            within_entry_grace(native, native + timedelta(minutes=181))
        )

    def test_previous_month_crosses_year(self) -> None:
        self.assertEqual(previous_month_key(202601), 202512)
        self.assertEqual(previous_month_key(202512), 202511)

    def test_endpoint_scan_skips_current_month_bars(self) -> None:
        bars = [
            Bar(datetime(2026, 8, 6, tzinfo=UTC), 62.0),
            Bar(datetime(2026, 8, 5, tzinfo=UTC), 61.0),
            Bar(datetime(2026, 7, 31, tzinfo=UTC), 55.0),
            Bar(datetime(2026, 7, 30, tzinfo=UTC), 56.0),
            Bar(datetime(2026, 6, 30, tzinfo=UTC), 60.0),
        ]
        value = load_prior_month_return(bars, 202608)
        self.assertAlmostEqual(value, math.log(55.0 / 60.0))
        self.assertTrue(should_buy(value))

    def test_only_strictly_negative_return_buys(self) -> None:
        self.assertTrue(should_buy(math.log(50.0 / 60.0)))
        self.assertFalse(should_buy(0.0))
        self.assertFalse(should_buy(math.log(70.0 / 60.0)))
        self.assertFalse(should_buy(math.nan))

    def test_missing_consecutive_month_fails_closed(self) -> None:
        bars = [
            Bar(datetime(2026, 8, 6, tzinfo=UTC), 62.0),
            Bar(datetime(2026, 6, 30, tzinfo=UTC), 60.0),
        ]
        with self.assertRaises(ValueError):
            load_prior_month_return(bars, 202608)

    def test_later_d1_and_four_day_stale_guards(self) -> None:
        opened = datetime(2026, 8, 7, 1, 0, tzinfo=UTC)
        same_session = datetime(2026, 8, 7, tzinfo=UTC)
        later_session = datetime(2026, 8, 10, tzinfo=UTC)
        self.assertEqual(same_session.date(), opened.date())
        self.assertNotEqual(later_session.date(), opened.date())
        self.assertEqual(opened + timedelta(days=4), datetime(2026, 8, 11, 1, tzinfo=UTC))


if __name__ == "__main__":
    unittest.main()
