#!/usr/bin/env python3
"""Pure reference checks for QM5_41024 calendar and endpoint mechanics."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timezone


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


def is_first_genuine_wednesday(current: datetime, prior: datetime) -> bool:
    # Python Monday=0, hence Wednesday=2 and Tuesday=1.
    return (
        current.weekday() == 2
        and 1 <= current.day <= 7
        and prior.weekday() == 1
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


def direction(value: float) -> int:
    return 1 if value > 0 else -1 if value < 0 else 0


class ReferenceTests(unittest.TestCase):
    def test_native_and_lagged_energy_labels(self) -> None:
        now = datetime(2026, 8, 5, 1, 30, tzinfo=UTC)
        self.assertEqual(
            label_offset_seconds(datetime(2026, 8, 5, tzinfo=UTC), now), 0
        )
        self.assertEqual(
            label_offset_seconds(datetime(2026, 8, 4, tzinfo=UTC), now), 86_400
        )
        self.assertEqual(
            label_offset_seconds(datetime(2026, 8, 3, tzinfo=UTC), now), -1
        )

    def test_first_wednesday_requires_day_one_to_seven_and_tuesday(self) -> None:
        wed = datetime(2026, 8, 5, tzinfo=UTC)
        tue = datetime(2026, 8, 4, tzinfo=UTC)
        self.assertTrue(is_first_genuine_wednesday(wed, tue))
        self.assertFalse(
            is_first_genuine_wednesday(datetime(2026, 8, 12, tzinfo=UTC), tue)
        )
        self.assertFalse(
            is_first_genuine_wednesday(wed, datetime(2026, 8, 3, tzinfo=UTC))
        )

    def test_previous_month_crosses_year(self) -> None:
        self.assertEqual(previous_month_key(202601), 202512)
        self.assertEqual(previous_month_key(202512), 202511)

    def test_endpoint_scan_skips_current_month_bars(self) -> None:
        bars = [
            Bar(datetime(2026, 8, 4, tzinfo=UTC), 80.0),
            Bar(datetime(2026, 8, 3, tzinfo=UTC), 79.0),
            Bar(datetime(2026, 7, 31, tzinfo=UTC), 75.0),
            Bar(datetime(2026, 7, 30, tzinfo=UTC), 74.0),
            Bar(datetime(2026, 6, 30, tzinfo=UTC), 60.0),
        ]
        value = load_prior_month_return(bars, 202608)
        self.assertAlmostEqual(value, math.log(75.0 / 60.0))
        self.assertEqual(direction(value), 1)

    def test_negative_and_zero_directions(self) -> None:
        self.assertEqual(direction(math.log(50.0 / 60.0)), -1)
        self.assertEqual(direction(math.log(60.0 / 60.0)), 0)

    def test_missing_consecutive_month_fails_closed(self) -> None:
        bars = [
            Bar(datetime(2026, 8, 4, tzinfo=UTC), 80.0),
            Bar(datetime(2026, 6, 30, tzinfo=UTC), 60.0),
        ]
        with self.assertRaises(ValueError):
            load_prior_month_return(bars, 202608)

    def test_next_d1_date_is_exit(self) -> None:
        opened = datetime(2026, 8, 5, 1, 0, tzinfo=UTC)
        same_session = datetime(2026, 8, 5, tzinfo=UTC)
        next_session = datetime(2026, 8, 6, tzinfo=UTC)
        self.assertEqual(same_session.date(), opened.date())
        self.assertNotEqual(next_session.date(), opened.date())


if __name__ == "__main__":
    unittest.main()
