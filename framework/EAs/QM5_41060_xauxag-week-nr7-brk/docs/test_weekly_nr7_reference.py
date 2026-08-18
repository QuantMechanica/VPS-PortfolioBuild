from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass(frozen=True)
class Bar:
    when: datetime
    xau_close: float
    xag_close: float


@dataclass(frozen=True)
class State:
    valid: bool
    direction: int = 0
    prior_low: float = 0.0
    prior_high: float = 0.0


def monday(value: datetime) -> datetime:
    return (value - timedelta(days=value.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0
    )


def ratio(bar: Bar) -> float:
    if bar.xau_close <= 0.0 or bar.xag_close <= 0.0:
        raise ValueError("nonpositive close")
    value = math.log(bar.xau_close) - math.log(bar.xag_close)
    if not math.isfinite(value):
        raise ValueError("nonfinite ratio")
    return value


def weekly_nr7_state(
    current_bar: datetime,
    bars_newest_first: list[Bar],
    reference_weeks: int = 7,
) -> State:
    if current_bar.weekday() not in (1, 2, 3, 4):
        return State(False)
    if len(bars_newest_first) < 2:
        return State(False)

    latest = bars_newest_first[0]
    previous = bars_newest_first[1]
    current_week = monday(current_bar)
    prior_week = current_week - timedelta(days=7)
    if monday(latest.when) != current_week:
        return State(False)
    if monday(previous.when) not in (current_week, prior_week):
        return State(False)

    groups: dict[datetime, dict[int, float]] = {}
    for bar in bars_newest_first:
        if bar.when.weekday() not in (0, 1, 2, 3, 4):
            continue
        key = monday(bar.when)
        if key == current_week:
            continue
        by_day = groups.setdefault(key, {})
        if bar.when.weekday() in by_day:
            return State(False)
        by_day[bar.when.weekday()] = ratio(bar)

    ordered = sorted(groups, reverse=True)
    if not ordered or ordered[0] != prior_week:
        return State(False)
    if set(groups[prior_week]) != set(range(5)):
        return State(False)

    valid_weeks: list[tuple[float, float]] = []
    for key in ordered:
        values = groups[key]
        if set(values) != set(range(5)):
            continue
        weekly_values = list(values.values())
        valid_weeks.append((min(weekly_values), max(weekly_values)))
        if len(valid_weeks) == reference_weeks:
            break
    if len(valid_weeks) != reference_weeks:
        return State(False)

    prior_low, prior_high = valid_weeks[0]
    prior_range = prior_high - prior_low
    if not math.isfinite(prior_range) or prior_range <= 0.0:
        return State(False)
    for older_low, older_high in valid_weeks[1:]:
        older_range = older_high - older_low
        if not math.isfinite(older_range) or not prior_range < older_range:
            return State(False)

    latest_ratio = ratio(latest)
    previous_ratio = ratio(previous)
    if not prior_low <= previous_ratio <= prior_high:
        return State(True, 0, prior_low, prior_high)
    if latest_ratio > prior_high:
        return State(True, 1, prior_low, prior_high)
    if latest_ratio < prior_low:
        return State(True, -1, prior_low, prior_high)
    return State(True, 0, prior_low, prior_high)


def make_week(start: datetime, values: list[float]) -> list[Bar]:
    if len(values) != 5:
        raise ValueError("complete week requires five values")
    return [
        Bar(start + timedelta(days=offset), math.exp(value), 1.0)
        for offset, value in enumerate(values)
    ]


def baseline(direction: int = 1) -> tuple[datetime, list[Bar]]:
    current_monday = datetime(2026, 8, 17)
    prior = make_week(
        current_monday - timedelta(days=7),
        [0.0, 0.25, 0.50, 0.75, 1.0],
    )
    older: list[Bar] = []
    for age in range(2, 8):
        width = 1.0 + age * 0.2
        older.extend(
            make_week(
                current_monday - timedelta(days=7 * age),
                [-0.1, width * 0.25, width * 0.50, width * 0.75, width],
            )
        )
    latest_value = 1.2 if direction > 0 else -0.2
    current = [
        Bar(current_monday, math.exp(0.5), 1.0),
        Bar(current_monday + timedelta(days=1), math.exp(latest_value), 1.0),
    ]
    bars = sorted(current + prior + older, key=lambda item: item.when, reverse=True)
    return current_monday + timedelta(days=2), bars


class WeeklyNr7ReferenceTests(unittest.TestCase):
    def test_fresh_upper_break_is_long_ratio(self) -> None:
        current, bars = baseline(1)
        state = weekly_nr7_state(current, bars)
        self.assertTrue(state.valid)
        self.assertEqual(state.direction, 1)

    def test_fresh_lower_break_is_short_ratio(self) -> None:
        current, bars = baseline(-1)
        state = weekly_nr7_state(current, bars)
        self.assertTrue(state.valid)
        self.assertEqual(state.direction, -1)

    def test_outer_boundary_equality_is_flat(self) -> None:
        current, bars = baseline(1)
        latest = bars[0]
        bars[0] = Bar(latest.when, math.exp(1.0), 1.0)
        self.assertEqual(weekly_nr7_state(current, bars).direction, 0)

    def test_stale_outside_state_is_flat(self) -> None:
        current, bars = baseline(1)
        previous = bars[1]
        bars[1] = Bar(previous.when, math.exp(1.1), 1.0)
        state = weekly_nr7_state(current, bars)
        self.assertTrue(state.valid)
        self.assertEqual(state.direction, 0)

    def test_equal_older_range_is_not_strict_nr7(self) -> None:
        current, bars = baseline(1)
        older_monday = datetime(2026, 8, 3)
        bars = [bar for bar in bars if monday(bar.when) != older_monday]
        bars.extend(make_week(older_monday, [0.0, 0.25, 0.5, 0.75, 1.0]))
        bars.sort(key=lambda item: item.when, reverse=True)
        self.assertFalse(weekly_nr7_state(current, bars).valid)

    def test_incomplete_older_holiday_week_is_skipped(self) -> None:
        current, bars = baseline(1)
        holiday_week = datetime(2026, 8, 3)
        bars = [
            bar
            for bar in bars
            if not (monday(bar.when) == holiday_week and bar.when.weekday() == 0)
        ]
        extra = make_week(
            datetime(2026, 6, 22),
            [-0.2, 0.3, 0.8, 1.3, 1.8],
        )
        bars.extend(extra)
        bars.sort(key=lambda item: item.when, reverse=True)
        state = weekly_nr7_state(current, bars)
        self.assertTrue(state.valid)
        self.assertEqual(state.direction, 1)

    def test_incomplete_immediate_prior_week_fails(self) -> None:
        current, bars = baseline(1)
        prior_monday = datetime(2026, 8, 10)
        bars = [
            bar
            for bar in bars
            if not (monday(bar.when) == prior_monday and bar.when.weekday() == 4)
        ]
        self.assertFalse(weekly_nr7_state(current, bars).valid)

    def test_fewer_than_seven_complete_weeks_fails(self) -> None:
        current, bars = baseline(1)
        cutoff = datetime(2026, 7, 6)
        bars = [bar for bar in bars if bar.when >= cutoff]
        self.assertFalse(weekly_nr7_state(current, bars).valid)

    def test_latest_completed_ratio_must_belong_to_current_week(self) -> None:
        current, bars = baseline(1)
        bars = [bar for bar in bars if monday(bar.when) != datetime(2026, 8, 17)]
        self.assertFalse(weekly_nr7_state(current, bars).valid)

    def test_nonpositive_price_fails_closed(self) -> None:
        current, bars = baseline(1)
        latest = bars[0]
        bars[0] = Bar(latest.when, 0.0, latest.xag_close)
        with self.assertRaises(ValueError):
            weekly_nr7_state(current, bars)


if __name__ == "__main__":
    unittest.main()
