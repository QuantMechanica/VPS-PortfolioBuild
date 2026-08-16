#!/usr/bin/env python3
"""Pure reference checks for QM5_41025 calendar and endpoint mechanics."""

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


def date_key(value: datetime) -> int:
    return value.year * 10_000 + value.month * 100 + value.day


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


def is_exact_decision_date(normalized: datetime, broker_now: datetime) -> bool:
    return normalized.date() == broker_now.date() and normalized.day in (8, 26)


def within_entry_grace(raw_bar: datetime, broker_now: datetime) -> bool:
    elapsed = int((broker_now - raw_bar).total_seconds())
    return elapsed >= 0 and elapsed % 86_400 <= 180 * 60


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


def decision_direction(day: int, prior_month_return: float) -> int:
    if day == 8 and prior_month_return > 0:
        return 1
    if day == 26 and prior_month_return < 0:
        return -1
    return 0


class ReferenceTests(unittest.TestCase):
    def test_native_and_lagged_energy_labels(self) -> None:
        now = datetime(2026, 8, 8, 1, 30, tzinfo=UTC)
        self.assertEqual(label_offset_seconds(datetime(2026, 8, 8, tzinfo=UTC), now), 0)
        self.assertEqual(label_offset_seconds(datetime(2026, 8, 7, tzinfo=UTC), now), 86_400)
        self.assertEqual(label_offset_seconds(datetime(2026, 8, 6, tzinfo=UTC), now), -1)

    def test_exact_dates_do_not_shift(self) -> None:
        for day in (8, 26):
            now = datetime(2026, 9, day, 1, tzinfo=UTC)
            self.assertTrue(is_exact_decision_date(now.replace(hour=0), now))
        weekend_substitute = datetime(2026, 8, 10, tzinfo=UTC)
        self.assertFalse(is_exact_decision_date(weekend_substitute, weekend_substitute))

    def test_entry_grace_boundary(self) -> None:
        raw = datetime(2026, 9, 8, tzinfo=UTC)
        self.assertTrue(within_entry_grace(raw, raw + timedelta(minutes=180)))
        self.assertFalse(within_entry_grace(raw, raw + timedelta(minutes=181)))

    def test_previous_month_crosses_year(self) -> None:
        self.assertEqual(previous_month_key(202601), 202512)
        self.assertEqual(previous_month_key(202512), 202511)

    def test_endpoint_scan_excludes_current_month(self) -> None:
        bars = [
            Bar(datetime(2026, 8, 7, tzinfo=UTC), 80.0),
            Bar(datetime(2026, 8, 6, tzinfo=UTC), 79.0),
            Bar(datetime(2026, 7, 31, tzinfo=UTC), 75.0),
            Bar(datetime(2026, 7, 30, tzinfo=UTC), 74.0),
            Bar(datetime(2026, 6, 30, tzinfo=UTC), 60.0),
        ]
        value = load_prior_month_return(bars, 202608)
        self.assertAlmostEqual(value, math.log(75.0 / 60.0))

    def test_date_specific_agreement_map(self) -> None:
        positive = math.log(75.0 / 60.0)
        negative = math.log(50.0 / 60.0)
        self.assertEqual(decision_direction(8, positive), 1)
        self.assertEqual(decision_direction(8, negative), 0)
        self.assertEqual(decision_direction(26, negative), -1)
        self.assertEqual(decision_direction(26, positive), 0)
        self.assertEqual(decision_direction(8, 0.0), 0)

    def test_missing_consecutive_month_fails_closed(self) -> None:
        bars = [
            Bar(datetime(2026, 8, 7, tzinfo=UTC), 80.0),
            Bar(datetime(2026, 6, 30, tzinfo=UTC), 60.0),
        ]
        with self.assertRaises(ValueError):
            load_prior_month_return(bars, 202608)

    def test_next_d1_date_is_exit(self) -> None:
        opened = datetime(2026, 9, 8, 1, tzinfo=UTC)
        same_session = datetime(2026, 9, 8, tzinfo=UTC)
        next_session = datetime(2026, 9, 9, tzinfo=UTC)
        self.assertEqual(date_key(same_session), date_key(opened))
        self.assertNotEqual(date_key(next_session), date_key(opened))


if __name__ == "__main__":
    unittest.main()
