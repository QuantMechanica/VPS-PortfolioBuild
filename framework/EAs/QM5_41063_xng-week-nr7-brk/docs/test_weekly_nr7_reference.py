from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass(frozen=True)
class Bar:
    raw_time: datetime
    high: float
    low: float
    close: float


@dataclass(frozen=True)
class State:
    valid: bool
    direction: int = 0
    prior_low: float = 0.0
    prior_high: float = 0.0


def day_key(value: datetime) -> int:
    return value.year * 10_000 + value.month * 100 + value.day


def monday(value: datetime) -> datetime:
    return (value - timedelta(days=value.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0
    )


def label_offset(current_raw: datetime, broker_now: datetime) -> timedelta:
    if current_raw > broker_now:
        raise ValueError("future current bar")
    if day_key(current_raw) == day_key(broker_now):
        return timedelta(0)
    if day_key(current_raw + timedelta(days=1)) == day_key(broker_now):
        return timedelta(days=1)
    raise ValueError("ambiguous energy label")


def weekly_nr7_state(
    current_raw: datetime,
    broker_now: datetime,
    completed_newest_first: list[Bar],
    history_bars: int = 90,
) -> State:
    try:
        offset = label_offset(current_raw, broker_now)
    except ValueError:
        return State(False)
    current = current_raw + offset
    if day_key(current) != day_key(broker_now):
        return State(False)
    if current.weekday() not in (1, 2, 3, 4):
        return State(False)
    if not timedelta(0) <= broker_now - current_raw <= timedelta(minutes=180):
        return State(False)
    if len(completed_newest_first) < history_bars:
        return State(False)

    bars = completed_newest_first[:history_bars]
    latest = bars[0]
    latest_time = latest.raw_time + offset
    if day_key(latest_time) != day_key(current - timedelta(days=1)):
        return State(False)
    current_week = monday(current)
    if monday(latest_time) != current_week:
        return State(False)

    groups: dict[datetime, dict[int, Bar]] = {}
    invalid: set[datetime] = set()
    for bar in bars:
        when = bar.raw_time + offset
        if not all(math.isfinite(v) for v in (bar.high, bar.low, bar.close)):
            return State(False)
        if min(bar.high, bar.low, bar.close) <= 0.0 or bar.high < bar.low:
            return State(False)
        key = monday(when)
        if key == current_week:
            continue
        if when.weekday() not in range(5):
            invalid.add(key)
            continue
        by_day = groups.setdefault(key, {})
        if when.weekday() in by_day:
            invalid.add(key)
            continue
        by_day[when.weekday()] = bar

    prior_week = current_week - timedelta(days=7)
    ordered = sorted(set(groups) | invalid, reverse=True)
    if not ordered or ordered[0] != prior_week:
        return State(False)

    def complete_range(key: datetime) -> tuple[float, float] | None:
        if key in invalid or set(groups.get(key, {})) != set(range(5)):
            return None
        week = list(groups[key].values())
        low = min(bar.low for bar in week)
        high = max(bar.high for bar in week)
        if not math.isfinite(high - low) or high - low <= 0.0:
            return None
        return low, high

    prior = complete_range(prior_week)
    if prior is None:
        return State(False)
    selected = [prior]
    for key in ordered[1:]:
        candidate = complete_range(key)
        if candidate is None:
            continue
        selected.append(candidate)
        if len(selected) == 7:
            break
    if len(selected) != 7:
        return State(False)

    prior_low, prior_high = selected[0]
    prior_range = prior_high - prior_low
    if any(not prior_range < high - low for low, high in selected[1:]):
        return State(False)
    if latest.close > prior_high:
        return State(True, 1, prior_low, prior_high)
    if latest.close < prior_low:
        return State(True, -1, prior_low, prior_high)
    return State(True, 0, prior_low, prior_high)


def make_week(start: datetime, width: float) -> list[Bar]:
    return [
        Bar(
            start + timedelta(days=day),
            70.0 + width * (day + 1) / 5.0,
            70.0,
            70.0 + width * (day + 1) / 6.0,
        )
        for day in range(5)
    ]


def baseline(*, shifted: bool = False, close: float = 71.2) -> tuple[datetime, datetime, list[Bar]]:
    current = datetime(2026, 8, 19)
    broker_now = current + timedelta(minutes=30)
    weeks: list[Bar] = make_week(datetime(2026, 8, 10), 1.0)
    for age in range(2, 8):
        weeks.extend(make_week(datetime(2026, 8, 17) - timedelta(days=7 * age), 1.0 + age / 5.0))
    weeks.extend(
        [
            Bar(datetime(2026, 8, 17), 70.7, 70.1, 70.5),
            Bar(datetime(2026, 8, 18), 71.3, 70.4, close),
        ]
    )
    # Fill the bounded retrieval window with deliberately incomplete older
    # weeks; they cannot become one of the seven valid selected weeks.
    cursor = datetime(2026, 6, 22)
    while len(weeks) < 90:
        weeks.append(Bar(cursor, 73.0, 69.0, 71.0))
        cursor -= timedelta(days=7)
    if shifted:
        # Darwinex energy bars can carry the prior calendar date while the
        # raw opening timestamp is still within the three-hour attach window.
        current -= timedelta(hours=1)
        weeks = [
            Bar(bar.raw_time - timedelta(days=1), bar.high, bar.low, bar.close)
            for bar in weeks
        ]
    weeks.sort(key=lambda bar: bar.raw_time, reverse=True)
    return current, broker_now, weeks


class WeeklyNr7ReferenceTests(unittest.TestCase):
    def test_native_label_upper_break_is_long_xng(self) -> None:
        current, now, bars = baseline(close=71.2)
        self.assertEqual(weekly_nr7_state(current, now, bars).direction, 1)

    def test_uniform_plus_one_label_has_same_identity(self) -> None:
        current, now, bars = baseline(shifted=True, close=71.2)
        state = weekly_nr7_state(current, now, bars)
        self.assertTrue(state.valid)
        self.assertEqual(state.direction, 1)

    def test_lower_break_is_short_xng(self) -> None:
        current, now, bars = baseline(close=69.8)
        self.assertEqual(weekly_nr7_state(current, now, bars).direction, -1)

    def test_boundary_equality_is_flat(self) -> None:
        current, now, bars = baseline(close=71.0)
        self.assertEqual(weekly_nr7_state(current, now, bars).direction, 0)

    def test_current_bar_extreme_cannot_create_signal(self) -> None:
        current, now, bars = baseline(close=70.7)
        # No current-bar OHLC is an input to the reference function.
        self.assertEqual(weekly_nr7_state(current, now, bars).direction, 0)

    def test_mixed_or_two_day_stale_label_fails(self) -> None:
        current, now, bars = baseline(close=71.2)
        stale = current - timedelta(days=2)
        self.assertFalse(weekly_nr7_state(stale, now, bars).valid)

    def test_latest_completed_bar_must_be_exact_prior_day(self) -> None:
        current, now, bars = baseline(close=71.2)
        latest = bars[0]
        bars[0] = Bar(latest.raw_time - timedelta(days=1), latest.high, latest.low, latest.close)
        self.assertFalse(weekly_nr7_state(current, now, bars).valid)

    def test_incomplete_immediate_prior_week_fails(self) -> None:
        current, now, bars = baseline(close=71.2)
        bars = [bar for bar in bars if bar.raw_time != datetime(2026, 8, 14)]
        bars.append(Bar(datetime(2020, 1, 1), 72.0, 70.0, 71.0))
        bars.sort(key=lambda bar: bar.raw_time, reverse=True)
        self.assertFalse(weekly_nr7_state(current, now, bars).valid)

    def test_incomplete_older_holiday_week_is_skipped(self) -> None:
        current, now, bars = baseline(close=71.2)
        holiday_monday = datetime(2026, 8, 3)
        bars = [bar for bar in bars if bar.raw_time != holiday_monday]
        extra_monday = datetime(2026, 6, 22)
        bars = [bar for bar in bars if monday(bar.raw_time) != extra_monday]
        bars.extend(make_week(extra_monday, 3.0))
        bars.sort(key=lambda bar: bar.raw_time, reverse=True)
        self.assertEqual(weekly_nr7_state(current, now, bars).direction, 1)

    def test_equal_older_range_rejects_non_strict_nr7(self) -> None:
        current, now, bars = baseline(close=71.2)
        older = datetime(2026, 8, 3)
        bars = [bar for bar in bars if monday(bar.raw_time) != older]
        bars.extend(make_week(older, 1.0))
        bars.sort(key=lambda bar: bar.raw_time, reverse=True)
        self.assertFalse(weekly_nr7_state(current, now, bars).valid)

    def test_weekend_member_invalidates_immediate_prior_week(self) -> None:
        current, now, bars = baseline(close=71.2)
        bars.append(Bar(datetime(2026, 8, 16), 72.0, 70.0, 71.0))
        bars.sort(key=lambda bar: bar.raw_time, reverse=True)
        self.assertFalse(weekly_nr7_state(current, now, bars).valid)

    def test_outside_tuesday_to_friday_window_fails(self) -> None:
        current, _, bars = baseline(close=71.2)
        monday_raw = datetime(2026, 8, 17)
        monday_now = monday_raw + timedelta(minutes=30)
        self.assertFalse(weekly_nr7_state(monday_raw, monday_now, bars).valid)

    def test_late_attachment_fails(self) -> None:
        current, _, bars = baseline(close=71.2)
        late = current + timedelta(minutes=181)
        self.assertFalse(weekly_nr7_state(current, late, bars).valid)


if __name__ == "__main__":
    unittest.main()
