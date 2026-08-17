"""Independent mechanic fixtures for QM5_41046.

The suite covers uniform energy-label normalization, the exact completed
Monday-Tuesday-Wednesday sequence, completed event and pre-event trend
endpoints, strict sign opposition, slow-trend direction, Thursday
grace/attempt identity, and next-D1 exit. It does not invoke MT5 or duplicate
framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest


DAY = dt.timedelta(days=1)
TREND_LOOKBACK_D1 = 252


def session_time(label: dt.datetime, broker_now: dt.datetime) -> dt.datetime:
    elapsed = broker_now - label
    if DAY <= elapsed < 2 * DAY:
        return label + DAY
    return label


def within_entry_grace(
    broker_now: dt.datetime,
    labelled_bar_open: dt.datetime,
    grace_minutes: int = 180,
) -> bool:
    elapsed = int((broker_now - labelled_bar_open).total_seconds())
    if elapsed < 0:
        return False
    return elapsed % 86_400 <= grace_minutes * 60


def valid_wednesday_sequence(
    broker_now: dt.datetime,
    current_label: dt.datetime,
    completed_labels: tuple[dt.datetime, ...],
) -> bool:
    if len(completed_labels) != 3 or broker_now.weekday() != 3:
        return False
    current = session_time(current_label, broker_now)
    offset = current - current_label
    bars = tuple(value + offset for value in completed_labels)
    expected_dates = tuple(
        (broker_now - days * DAY).date() for days in (1, 2, 3)
    )
    gaps = (current - bars[0], bars[0] - bars[1], bars[1] - bars[2])
    return (
        current.date() == broker_now.date()
        and tuple(value.weekday() for value in bars) == (2, 1, 0)
        and tuple(value.date() for value in bars) == expected_dates
        and all(
            dt.timedelta(hours=20) <= gap <= dt.timedelta(hours=28)
            for gap in gaps
        )
    )


def select_direction(event_return: float, slow_trend: float) -> int:
    if not all(math.isfinite(value) for value in (event_return, slow_trend)):
        return 0
    if event_return * slow_trend >= 0:
        return 0
    return (slow_trend > 0) - (slow_trend < 0)


def trend_pullback_direction(
    completed_closes: tuple[float, ...],
    lookback: int = TREND_LOOKBACK_D1,
) -> tuple[int, float, float]:
    flat = (0, 0.0, 0.0)
    required = lookback + 2
    if lookback != TREND_LOOKBACK_D1 or len(completed_closes) != required:
        return flat
    wednesday_close = completed_closes[0]
    tuesday_close = completed_closes[1]
    old_close = completed_closes[lookback + 1]
    endpoints = (wednesday_close, tuesday_close, old_close)
    if not all(math.isfinite(value) and value > 0 for value in endpoints):
        return flat
    event_return = math.log(wednesday_close / tuesday_close)
    slow_trend = math.log(tuesday_close / old_close)
    return select_direction(event_return, slow_trend), event_return, slow_trend


def completed_path(
    wednesday_close: float,
    tuesday_close: float,
    old_close: float,
    off_by_one_close: float = 999.0,
) -> tuple[float, ...]:
    closes = [tuesday_close] * (TREND_LOOKBACK_D1 + 2)
    closes[0] = wednesday_close
    closes[1] = tuesday_close
    closes[TREND_LOOKBACK_D1] = off_by_one_close
    closes[TREND_LOOKBACK_D1 + 1] = old_close
    return tuple(closes)


def later_d1_boundary(
    opened: dt.datetime,
    current_label: dt.datetime,
    broker_now: dt.datetime,
) -> bool:
    return session_time(current_label, broker_now).date() > opened.date()


class WednesdayTrendPullbackReferenceTests(unittest.TestCase):
    def test_native_same_day_labels_are_supported(self) -> None:
        broker_now = dt.datetime(2026, 8, 20, 1, 0)
        completed = tuple(dt.datetime(2026, 8, day) for day in (19, 18, 17))
        self.assertTrue(
            valid_wednesday_sequence(
                broker_now, dt.datetime(2026, 8, 20), completed
            )
        )

    def test_prior_date_energy_labels_normalize_uniformly(self) -> None:
        broker_now = dt.datetime(2026, 8, 20, 1, 0)
        completed = tuple(dt.datetime(2026, 8, day) for day in (18, 17, 16))
        self.assertTrue(
            valid_wednesday_sequence(
                broker_now, dt.datetime(2026, 8, 19), completed
            )
        )

    def test_holiday_or_missing_session_is_not_substituted(self) -> None:
        broker_now = dt.datetime(2026, 8, 20, 1, 0)
        completed = tuple(dt.datetime(2026, 8, day) for day in (19, 17, 16))
        self.assertFalse(
            valid_wednesday_sequence(
                broker_now, dt.datetime(2026, 8, 20), completed
            )
        )

    def test_non_thursday_decision_is_rejected(self) -> None:
        broker_now = dt.datetime(2026, 8, 21, 1, 0)
        completed = tuple(dt.datetime(2026, 8, day) for day in (20, 19, 18))
        self.assertFalse(
            valid_wednesday_sequence(
                broker_now, dt.datetime(2026, 8, 21), completed
            )
        )

    def test_three_hour_grace_uses_executable_session_open(self) -> None:
        labelled = dt.datetime(2026, 8, 19)
        self.assertTrue(
            within_entry_grace(dt.datetime(2026, 8, 20, 2, 59), labelled)
        )
        self.assertFalse(
            within_entry_grace(dt.datetime(2026, 8, 20, 3, 0, 1), labelled)
        )

    def test_negative_event_rejoins_positive_trend_long(self) -> None:
        direction, event_return, slow_trend = trend_pullback_direction(
            completed_path(95.0, 100.0, 80.0)
        )
        self.assertEqual(direction, 1)
        self.assertLess(event_return, 0)
        self.assertGreater(slow_trend, 0)

    def test_positive_event_rejoins_negative_trend_short(self) -> None:
        direction, event_return, slow_trend = trend_pullback_direction(
            completed_path(105.0, 100.0, 120.0)
        )
        self.assertEqual(direction, -1)
        self.assertGreater(event_return, 0)
        self.assertLess(slow_trend, 0)

    def test_agreement_and_zero_are_flat(self) -> None:
        self.assertEqual(
            trend_pullback_direction(completed_path(105.0, 100.0, 80.0))[0],
            0,
        )
        self.assertEqual(
            trend_pullback_direction(completed_path(95.0, 100.0, 120.0))[0],
            0,
        )
        self.assertEqual(
            trend_pullback_direction(completed_path(100.0, 100.0, 80.0))[0],
            0,
        )

    def test_invalid_completed_endpoint_consumes_flat(self) -> None:
        self.assertEqual(
            trend_pullback_direction(completed_path(95.0, 100.0, 0.0)),
            (0, 0.0, 0.0),
        )
        self.assertEqual(
            trend_pullback_direction(
                completed_path(float("nan"), 100.0, 80.0)
            ),
            (0, 0.0, 0.0),
        )

    def test_exact_252_interval_endpoint_ignores_off_by_one_close(self) -> None:
        first = trend_pullback_direction(
            completed_path(95.0, 100.0, 80.0, off_by_one_close=1.0)
        )
        second = trend_pullback_direction(
            completed_path(95.0, 100.0, 80.0, off_by_one_close=10_000.0)
        )
        self.assertEqual(first, second)
        self.assertAlmostEqual(first[2], math.log(100.0 / 80.0))

    def test_wednesday_is_excluded_from_the_slow_state(self) -> None:
        positive_event = trend_pullback_direction(
            completed_path(110.0, 100.0, 80.0)
        )
        negative_event = trend_pullback_direction(
            completed_path(90.0, 100.0, 80.0)
        )
        self.assertAlmostEqual(positive_event[2], negative_event[2])
        self.assertEqual(positive_event[0], 0)
        self.assertEqual(negative_event[0], 1)

    def test_insufficient_or_changed_lookback_is_flat(self) -> None:
        valid = completed_path(95.0, 100.0, 80.0)
        self.assertEqual(trend_pullback_direction(valid[:-1]), (0, 0.0, 0.0))
        self.assertEqual(
            trend_pullback_direction(valid, lookback=251),
            (0, 0.0, 0.0),
        )

    def test_first_later_d1_boundary_is_the_ordinary_exit(self) -> None:
        opened = dt.datetime(2026, 8, 20, 1, 0)
        self.assertFalse(
            later_d1_boundary(
                opened,
                dt.datetime(2026, 8, 20),
                dt.datetime(2026, 8, 20, 12, 0),
            )
        )
        self.assertTrue(
            later_d1_boundary(
                opened,
                dt.datetime(2026, 8, 21),
                dt.datetime(2026, 8, 21, 0, 1),
            )
        )
        self.assertTrue(
            later_d1_boundary(
                opened,
                dt.datetime(2026, 8, 20),
                dt.datetime(2026, 8, 21, 0, 1),
            )
        )

    def test_exact_thursday_attempt_key_is_stable(self) -> None:
        observed = dt.datetime(2026, 8, 20, 2, 0)
        key = observed.year * 10_000 + observed.month * 100 + observed.day
        self.assertEqual(key, 20260820)
        self.assertNotEqual(key, 20260827)


if __name__ == "__main__":
    unittest.main()
