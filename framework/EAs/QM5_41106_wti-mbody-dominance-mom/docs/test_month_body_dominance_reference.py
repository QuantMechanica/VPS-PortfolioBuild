"""Deterministic reference checks for QM5_41106 monthly body dominance."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Bar:
    opened: datetime
    open: float
    high: float
    low: float
    close: float


def date_key(value: datetime) -> int:
    return value.year * 10_000 + value.month * 100 + value.day


def month_key(value: datetime) -> int:
    return value.year * 100 + value.month


def next_month_key(value: int) -> int:
    year, month = divmod(value, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    if month == 12:
        return (year + 1) * 100 + 1
    return year * 100 + month + 1


def label_offset(current_bar: datetime, now: datetime) -> timedelta | None:
    if current_bar.timestamp() <= 0 or now < current_bar:
        return None
    if current_bar.date() == now.date():
        return timedelta(0)
    if (current_bar + timedelta(days=1)).date() == now.date():
        return timedelta(days=1)
    return None


def within_entry_grace(
    current_bar: datetime, now: datetime, grace_minutes: int = 180
) -> bool:
    elapsed = now - current_bar
    if elapsed < timedelta(0):
        return False
    return elapsed % timedelta(days=1) <= timedelta(minutes=grace_minutes)


def decision_clock(
    current_bar: datetime,
    now: datetime,
    completed_newest_first: list[Bar],
) -> tuple[bool, bool, int, timedelta | None]:
    offset = label_offset(current_bar, now)
    if offset is None or not completed_newest_first:
        return False, False, 0, offset
    normalized_current = current_bar + offset
    if normalized_current.date() != now.date():
        return False, False, 0, offset
    current_key = month_key(normalized_current)
    if current_key != month_key(now):
        return False, False, 0, offset

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


def ohlc_valid(bar: Bar) -> bool:
    values = (bar.open, bar.high, bar.low, bar.close)
    return (
        bar.opened.timestamp() > 0
        and all(value > 0.0 and math.isfinite(value) for value in values)
        and bar.high >= max(bar.open, bar.low, bar.close)
        and bar.low <= min(bar.open, bar.high, bar.close)
    )


def body_dominance_signal(
    current_month_key: int,
    completed_newest_first: list[Bar],
    offset: timedelta,
    minimum: int = 17,
    maximum: int = 23,
) -> tuple[bool, int, int, tuple[float, ...], bool]:
    """Mirror one completed month and strict 2*body > range arithmetic."""

    empty = (False, 0, 0, (0.0,) * 6, False)
    if current_month_key <= 0 or offset not in (
        timedelta(0),
        timedelta(days=1),
    ):
        return empty
    if len(completed_newest_first) < minimum + 1:
        return empty

    completed_key = 0
    last_session_date: date | None = None
    bucket: list[Bar] = []
    older_boundary_seen = False
    for index, bar in enumerate(completed_newest_first):
        if not ohlc_valid(bar):
            return empty
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return empty
        key = month_key(bar.opened + offset)
        if key == current_month_key:
            return empty
        if completed_key == 0:
            if next_month_key(key) != current_month_key:
                return empty
            completed_key = key
        elif key != completed_key:
            if next_month_key(key) != completed_key:
                return empty
            older_boundary_seen = True
            break

        normalized_date = (bar.opened + offset).date()
        if last_session_date is not None and normalized_date >= last_session_date:
            return empty
        last_session_date = normalized_date
        bucket.append(bar)
        if len(bucket) > maximum:
            return empty

    if not older_boundary_seen or not minimum <= len(bucket) <= maximum:
        return empty

    completed_open = bucket[-1].open
    completed_high = max(bar.high for bar in bucket)
    completed_low = min(bar.low for bar in bucket)
    completed_close = bucket[0].close
    values = (completed_open, completed_high, completed_low, completed_close)
    if (
        completed_high <= completed_low
        or completed_high < max(completed_open, completed_close)
        or completed_low > min(completed_open, completed_close)
        or not all(math.isfinite(value) and value > 0.0 for value in values)
    ):
        return empty

    completed_range = completed_high - completed_low
    completed_body = abs(completed_close - completed_open)
    dominant = 2 * completed_body > completed_range
    direction = 0
    if dominant and completed_close > completed_open:
        direction = 1
    elif dominant and completed_close < completed_open:
        direction = -1
    return (
        True,
        direction,
        len(bucket),
        (*values, completed_range, completed_body),
        dominant,
    )


def trading_days(start: datetime, count: int) -> list[datetime]:
    days: list[datetime] = []
    cursor = start
    while len(days) < count:
        if cursor.weekday() < 5:
            days.append(cursor)
        cursor += timedelta(days=1)
    return days


def make_month(
    start: datetime,
    count: int,
    aggregate: tuple[float, float, float, float],
) -> list[Bar]:
    open_, high, low, close = aggregate
    midpoint = (high + low) / 2.0
    dates = trading_days(start, count)
    bars: list[Bar] = []
    for index, opened in enumerate(dates):
        bar_open = open_ if index == 0 else midpoint
        bar_close = close if index == count - 1 else midpoint
        bar_high = max(bar_open, bar_close, high if index == 1 else midpoint)
        bar_low = min(bar_open, bar_close, low if index == 2 else midpoint)
        bars.append(Bar(opened, bar_open, bar_high, bar_low, bar_close))
    return list(reversed(bars))


def sample(
    completed: tuple[float, float, float, float] = (100.0, 130.0, 90.0, 122.0),
    count: int = 23,
    prior_date_labels: bool = False,
) -> tuple[datetime, datetime, list[Bar]]:
    current = datetime(2026, 8, 3, tzinfo=UTC)
    now = current
    bars = make_month(datetime(2026, 7, 1, tzinfo=UTC), count, completed)
    bars.append(Bar(datetime(2026, 6, 30, tzinfo=UTC), 99.0, 101.0, 98.0, 100.0))
    if prior_date_labels:
        current -= timedelta(days=1)
        bars = [
            Bar(
                bar.opened - timedelta(days=1),
                bar.open,
                bar.high,
                bar.low,
                bar.close,
            )
            for bar in bars
        ]
    return current, now, bars


def consume_attempt(attempts: set[int], current_month_key: int) -> bool:
    if current_month_key in attempts:
        return False
    attempts.add(current_month_key)
    return True


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


class MonthBodyDominanceReferenceTest(unittest.TestCase):
    def signal(self, bars: list[Bar], offset: timedelta = timedelta(0)):
        return body_dominance_signal(202608, bars, offset)

    def test_strict_long_and_short_paths(self) -> None:
        _, _, bars = sample()
        valid, direction, count, values, dominant = self.signal(bars)
        self.assertTrue(valid)
        self.assertTrue(dominant)
        self.assertEqual(direction, 1)
        self.assertEqual(count, 23)
        self.assertEqual(values, (100.0, 130.0, 90.0, 122.0, 40.0, 22.0))

        _, _, bars = sample(completed=(122.0, 130.0, 90.0, 100.0))
        self.assertEqual(self.signal(bars)[0:2], (True, -1))

    def test_seventeen_twenty_and_twenty_three_sessions_are_accepted(self) -> None:
        for count in (17, 20, 23):
            _, _, bars = sample(count=count)
            valid, direction, actual_count, _, dominant = self.signal(bars)
            self.assertTrue(valid)
            self.assertTrue(dominant)
            self.assertEqual(direction, 1)
            self.assertEqual(actual_count, count)

    def test_sixteen_and_twenty_four_sessions_are_rejected(self) -> None:
        for count in (16, 24):
            _, _, bars = sample(count=count)
            self.assertFalse(self.signal(bars)[0])

    def test_threshold_equality_subthreshold_and_body_equality_are_flat(self) -> None:
        cases = (
            ((100.0, 130.0, 90.0, 120.0), 40.0, 20.0),
            ((100.0, 130.0, 90.0, 119.0), 40.0, 19.0),
            ((105.0, 130.0, 90.0, 105.0), 40.0, 0.0),
        )
        for aggregate, expected_range, expected_body in cases:
            _, _, bars = sample(completed=aggregate)
            valid, direction, _, values, dominant = self.signal(bars)
            self.assertTrue(valid)
            self.assertFalse(dominant)
            self.assertEqual(direction, 0)
            self.assertEqual(values[-2:], (expected_range, expected_body))

    def test_malformed_nonconsecutive_and_current_month_history_rejected(self) -> None:
        _, _, bars = sample()
        broken = list(bars)
        newest = broken[0]
        broken[0] = Bar(
            newest.opened, newest.open, newest.close - 1.0, newest.low, newest.close
        )
        self.assertFalse(self.signal(broken)[0])

        _, _, bars = sample(completed=(100.0, 100.0, 100.0, 100.0))
        self.assertFalse(self.signal(bars)[0])

        _, _, bars = sample()
        broken = list(bars)
        parent = broken[-1]
        broken[-1] = Bar(
            parent.opened - timedelta(days=31),
            parent.open,
            parent.high,
            parent.low,
            parent.close,
        )
        self.assertFalse(self.signal(broken)[0])

        _, _, bars = sample()
        bars.insert(
            0,
            Bar(datetime(2026, 8, 3, tzinfo=UTC), 112.0, 113.0, 111.0, 112.5),
        )
        self.assertFalse(self.signal(bars)[0])

    def test_duplicate_normalized_session_date_is_rejected(self) -> None:
        _, _, bars = sample()
        broken = list(bars)
        first = broken[0]
        second = broken[1]
        broken[0] = Bar(
            first.opened + timedelta(hours=12),
            first.open,
            first.high,
            first.low,
            first.close,
        )
        broken[1] = Bar(
            first.opened,
            second.open,
            second.high,
            second.low,
            second.close,
        )
        self.assertFalse(self.signal(broken)[0])

    def test_uniform_prior_date_labels_match_native(self) -> None:
        current, now, bars = sample()
        decision, late, count, offset = decision_clock(current, now, bars)
        self.assertEqual((decision, late, count, offset), (True, False, 0, timedelta(0)))
        native = self.signal(bars, timedelta(0))

        current, now, bars = sample(prior_date_labels=True)
        decision, late, count, offset = decision_clock(current, now, bars)
        self.assertEqual(
            (decision, late, count, offset), (True, False, 0, timedelta(days=1))
        )
        self.assertEqual(self.signal(bars, timedelta(days=1)), native)
        self.assertTrue(within_entry_grace(current, now + timedelta(minutes=180)))
        self.assertFalse(within_entry_grace(current, now + timedelta(minutes=181)))

    def test_invalid_label_gap_fails_closed(self) -> None:
        current, now, bars = sample()
        self.assertIsNone(label_offset(current - timedelta(days=2), now))
        self.assertEqual(
            decision_clock(current - timedelta(days=2), now, bars)[0:2],
            (False, False),
        )

    def test_late_restart_is_detected_and_attempt_is_consumed_once(self) -> None:
        _, _, bars = sample()
        bars.insert(
            0,
            Bar(datetime(2026, 8, 3, tzinfo=UTC), 112.0, 113.0, 111.0, 112.5),
        )
        current = datetime(2026, 8, 4, tzinfo=UTC)
        decision, late, count, _ = decision_clock(current, current, bars)
        self.assertTrue(decision)
        self.assertTrue(late)
        self.assertEqual(count, 1)
        attempts: set[int] = set()
        self.assertTrue(consume_attempt(attempts, 202608))
        self.assertFalse(consume_attempt(attempts, 202608))

    def test_year_boundary_and_lifecycle_guards(self) -> None:
        self.assertEqual(next_month_key(202612), 202701)
        opened = datetime(2026, 8, 3, 0, 1, tzinfo=UTC)
        current = datetime(2026, 8, 31, tzinfo=UTC)
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
            should_close(opened, current, opened + timedelta(days=40), timedelta(0))
        )
        self.assertTrue(should_close(None, current, current, timedelta(0)))
        self.assertTrue(should_close(opened, current, current, None))

    def test_static_build_contract_is_fixed_risk_and_completed_data_only(self) -> None:
        source = (EA_DIR / "QM5_41106_wti-mbody-dominance-mom.mq5").read_text(
            encoding="utf-8"
        )
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41106_wti-mbody-dominance-mom_XTIUSD.DWX_D1_backtest.set"
        ).read_text(encoding="utf-8")
        for marker in (
            "input double RISK_PERCENT                  = 0.0;",
            "input double RISK_FIXED                    = 1000.0;",
            "input double PORTFOLIO_WEIGHT              = 1.0;",
            "input int    strategy_body_numerator       = 2;",
            "input int    strategy_range_multiplier     = 1;",
            "CopyRates(_Symbol, // perf-allowed: bounded completed-month OHLC scan behind the sole QM_IsNewBar branch.",
            "PERIOD_D1,\n                1,",
            "session_date_key >= last_session_date_key",
            "month_range = month_high - month_low;",
            "month_body = MathAbs(month_close - month_open);",
            "qualified = (body_side > range_side);",
            "if(qualified && month_close > month_open)",
            "else if(qualified && month_close < month_open)",
            "QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1)",
            "req.tp = 0.0;",
            "opened_month_key != current_month_key",
        ):
            self.assertIn(marker, source)
        for forbidden in (
            "parent_high",
            "parent_low",
            "strategy_long_clv",
            "strategy_short_clv",
            "moving_average",
        ):
            self.assertNotIn(forbidden, source)
        self.assertLess(
            source.index("if(!Strategy_RecordMonthAttempt(g_decision_month_key))"),
            source.index("Strategy_LoadBodyDominanceSignal(g_decision_month_key,"),
        )
        for marker in (
            "qm_ea_id=41106",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=40",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_body_numerator=2",
            "strategy_range_multiplier=1",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
            "strategy_max_hold_days=40",
        ):
            self.assertIn(marker, setfile)


if __name__ == "__main__":
    unittest.main()
