"""Deterministic reference checks for QM5_41093 weekly closing breakout."""

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


def week_key(value: datetime) -> int:
    return date_key(value - timedelta(days=value.weekday()))


def key_to_date(value: int) -> datetime:
    return datetime(value // 10_000, (value // 100) % 100, value % 100, tzinfo=UTC)


def next_week_key(value: int) -> int:
    anchor = key_to_date(value)
    if week_key(anchor) != value:
        return 0
    return week_key(anchor + timedelta(days=7))


def label_offset(
    current_bar: datetime, now: datetime, configured: timedelta
) -> timedelta | None:
    elapsed = now - current_bar
    if elapsed < timedelta(0) or configured not in (timedelta(0), timedelta(days=1)):
        return None
    detected: timedelta | None = None
    if elapsed < timedelta(days=1):
        detected = timedelta(0)
    elif elapsed < timedelta(days=2):
        detected = timedelta(days=1)
    return detected if detected == configured else None


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
    configured_offset: timedelta,
) -> tuple[bool, bool, int, timedelta | None]:
    offset = label_offset(current_bar, now, configured_offset)
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


def ohlc_valid(bar: Bar) -> bool:
    values = (bar.open, bar.high, bar.low, bar.close)
    return (
        bar.opened.timestamp() > 0
        and all(value > 0.0 and math.isfinite(value) for value in values)
        and bar.high >= max(bar.open, bar.low, bar.close)
        and bar.low <= min(bar.open, bar.high, bar.close)
    )


def closing_breakout_signal(
    current_week_key: int,
    completed_newest_first: list[Bar],
    offset: timedelta,
    minimum: int = 3,
    maximum: int = 5,
) -> tuple[bool, int, tuple[int, int], tuple[float, ...], bool]:
    """Mirror bounded weekly OHLC aggregation and final-close breakout signal."""

    empty = (False, 0, (0, 0), (0.0,) * 8, False)
    if current_week_key <= 0 or offset not in (timedelta(0), timedelta(days=1)):
        return empty
    if len(completed_newest_first) < minimum * 2 + 1:
        return empty

    keys: list[int] = []
    buckets: list[list[Bar]] = []
    last_session_dates: list[date | None] = []
    parent_boundary_seen = False
    for index, bar in enumerate(completed_newest_first):
        if not ohlc_valid(bar):
            return empty
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return empty
        key = week_key(bar.opened + offset)
        if key == current_week_key:
            return empty
        if not keys or key != keys[-1]:
            if len(keys) >= 2:
                if next_week_key(key) != keys[1]:
                    return empty
                parent_boundary_seen = True
                break
            if not keys:
                if next_week_key(key) != current_week_key:
                    return empty
            elif next_week_key(key) != keys[-1]:
                return empty
            keys.append(key)
            buckets.append([])
            last_session_dates.append(None)
        normalized_date = (bar.opened + offset).date()
        if last_session_dates[-1] is not None and normalized_date >= last_session_dates[-1]:
            return empty
        last_session_dates[-1] = normalized_date
        buckets[-1].append(bar)
        if len(buckets[-1]) > maximum:
            return empty

    if len(keys) != 2 or not parent_boundary_seen:
        return empty
    if any(not minimum <= len(bucket) <= maximum for bucket in buckets):
        return empty

    weekly: list[tuple[float, float, float, float]] = []
    for bucket in buckets:
        weekly.append(
            (
                bucket[-1].open,
                max(bar.high for bar in bucket),
                min(bar.low for bar in bucket),
                bucket[0].close,
            )
        )
    new_open, new_high, new_low, new_close = weekly[0]
    parent_open, parent_high, parent_low, parent_close = weekly[1]
    for open_, high, low, close in weekly:
        if (
            high <= low
            or high < max(open_, close)
            or low > min(open_, close)
            or not all(math.isfinite(value) and value > 0.0 for value in (open_, high, low, close))
        ):
            return empty

    closing_breakout = False
    direction = 0
    if new_close > parent_high:
        direction = 1
        closing_breakout = True
    elif new_close < parent_low:
        direction = -1
        closing_breakout = True
    values = (
        new_open,
        new_high,
        new_low,
        new_close,
        parent_open,
        parent_high,
        parent_low,
        parent_close,
    )
    return True, direction, (len(buckets[0]), len(buckets[1])), values, closing_breakout


def make_week(
    anchor: datetime,
    count: int,
    aggregate: tuple[float, float, float, float],
) -> list[Bar]:
    open_, high, low, close = aggregate
    midpoint = (high + low) / 2.0
    bars: list[Bar] = []
    for index in range(count):
        bar_open = open_ if index == 0 else midpoint
        bar_close = close if index == count - 1 else midpoint
        bar_high = max(bar_open, bar_close, high if index == 1 else midpoint)
        bar_low = min(bar_open, bar_close, low if index == 2 else midpoint)
        bars.append(
            Bar(anchor + timedelta(days=index), bar_open, bar_high, bar_low, bar_close)
        )
    return list(reversed(bars))


def sample(
    new: tuple[float, float, float, float] = (100.0, 126.0, 90.0, 122.0),
    parent: tuple[float, float, float, float] = (95.0, 120.0, 80.0, 100.0),
    new_count: int = 5,
    parent_count: int = 5,
    prior_date_labels: bool = False,
) -> tuple[datetime, datetime, list[Bar]]:
    current = datetime(2026, 8, 24, tzinfo=UTC)
    now = current
    bars = (
        make_week(datetime(2026, 8, 17, tzinfo=UTC), new_count, new)
        + make_week(datetime(2026, 8, 10, tzinfo=UTC), parent_count, parent)
        + make_week(
            datetime(2026, 8, 3, tzinfo=UTC),
            3,
            (100.0, 105.0, 95.0, 101.0),
        )
    )
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


class WeekClosingBreakoutReferenceTest(unittest.TestCase):
    def signal(self, bars: list[Bar], offset: timedelta = timedelta(0)):
        return closing_breakout_signal(20260824, bars, offset)

    def test_strict_final_close_long_and_short_paths(self) -> None:
        _, _, bars = sample()
        valid, direction, counts, values, breakout = self.signal(bars)
        self.assertTrue(valid)
        self.assertTrue(breakout)
        self.assertEqual(direction, 1)
        self.assertEqual(counts, (5, 5))
        self.assertEqual(values, (100.0, 126.0, 90.0, 122.0, 95.0, 120.0, 80.0, 100.0))

        _, _, bars = sample(new=(100.0, 110.0, 70.0, 78.0))
        self.assertEqual(self.signal(bars)[0:2], (True, -1))

    def test_three_four_and_five_session_weeks_are_accepted(self) -> None:
        for new_count in (3, 4, 5):
            for parent_count in (3, 4, 5):
                _, _, bars = sample(new_count=new_count, parent_count=parent_count)
                valid, direction, counts, _, breakout = self.signal(bars)
                self.assertTrue(valid)
                self.assertTrue(breakout)
                self.assertEqual(direction, 1)
                self.assertEqual(counts, (new_count, parent_count))

    def test_two_and_six_session_weeks_are_rejected(self) -> None:
        for new_count, parent_count in ((2, 5), (5, 2), (6, 5), (5, 6)):
            _, _, bars = sample(new_count=new_count, parent_count=parent_count)
            self.assertFalse(self.signal(bars)[0])

    def test_equal_endpoints_and_inside_close_are_flat(self) -> None:
        cases = [
            (100.0, 126.0, 90.0, 120.0),
            (100.0, 110.0, 70.0, 80.0),
            (100.0, 130.0, 70.0, 100.0),
        ]
        for new in cases:
            _, _, bars = sample(new=new)
            valid, direction, _, _, breakout = self.signal(bars)
            self.assertTrue(valid)
            self.assertFalse(breakout)
            self.assertEqual(direction, 0)

    def test_newest_body_and_opposite_endpoint_do_not_choose_side(self) -> None:
        # Bearish newest body and both-sided range expansion still buy because
        # only the final close is above the parent high.
        _, _, bars = sample(new=(125.0, 130.0, 70.0, 122.0))
        self.assertEqual(self.signal(bars)[0:2], (True, 1))

        # Bullish newest body and both-sided range expansion still sell because
        # only the final close is below the parent low.
        _, _, bars = sample(new=(75.0, 130.0, 70.0, 78.0))
        self.assertEqual(self.signal(bars)[0:2], (True, -1))

    def test_parent_open_close_do_not_choose_side(self) -> None:
        _, _, bars = sample(parent=(82.0, 120.0, 80.0, 118.0))
        self.assertEqual(self.signal(bars)[0:2], (True, 1))
        _, _, bars = sample(parent=(118.0, 120.0, 80.0, 82.0))
        self.assertEqual(self.signal(bars)[0:2], (True, 1))

    def test_malformed_zero_range_nonconsecutive_and_current_week_rejected(self) -> None:
        _, _, bars = sample()
        broken = list(bars)
        bad = broken[0]
        broken[0] = Bar(bad.opened, bad.open, bad.close - 1.0, bad.low, bad.close)
        self.assertFalse(self.signal(broken)[0])

        _, _, bars = sample(new=(100.0, 100.0, 100.0, 100.0))
        self.assertFalse(self.signal(bars)[0])

        _, _, bars = sample()
        shifted_parent = [
            Bar(
                bar.opened - timedelta(days=7) if index >= 5 else bar.opened,
                bar.open,
                bar.high,
                bar.low,
                bar.close,
            )
            for index, bar in enumerate(bars)
        ]
        self.assertFalse(self.signal(shifted_parent)[0])

        _, _, bars = sample()
        bars.insert(0, Bar(datetime(2026, 8, 24, tzinfo=UTC), 112.0, 113.0, 111.0, 112.5))
        self.assertFalse(self.signal(bars)[0])

    def test_duplicate_normalized_session_date_is_rejected(self) -> None:
        _, _, bars = sample()
        broken = list(bars)
        newest = broken[0]
        second = broken[1]
        broken[0] = Bar(newest.opened + timedelta(hours=12), newest.open, newest.high, newest.low, newest.close)
        broken[1] = Bar(newest.opened, second.open, second.high, second.low, second.close)
        self.assertFalse(self.signal(broken)[0])

    def test_uniform_prior_date_labels_match_native(self) -> None:
        current, now, bars = sample()
        decision, late, count, offset = decision_clock(current, now, bars, timedelta(0))
        self.assertEqual((decision, late, count, offset), (True, False, 0, timedelta(0)))
        native = self.signal(bars, timedelta(0))

        current, now, bars = sample(prior_date_labels=True)
        decision, late, count, offset = decision_clock(current, now, bars, timedelta(days=1))
        self.assertEqual((decision, late, count, offset), (True, False, 0, timedelta(days=1)))
        self.assertEqual(self.signal(bars, timedelta(days=1)), native)
        self.assertTrue(within_entry_grace(current, now + timedelta(minutes=180)))
        self.assertFalse(within_entry_grace(current, now + timedelta(minutes=181)))

    def test_wrong_configured_label_offset_fails_closed(self) -> None:
        current, now, bars = sample()
        self.assertEqual(decision_clock(current, now, bars, timedelta(days=1))[0:2], (False, False))
        current, now, bars = sample(prior_date_labels=True)
        self.assertEqual(decision_clock(current, now, bars, timedelta(0))[0:2], (False, False))

    def test_late_restart_is_detected_and_week_is_consumed_once(self) -> None:
        current, _, bars = sample()
        bars.insert(0, Bar(datetime(2026, 8, 24, tzinfo=UTC), 112.0, 113.0, 111.0, 112.5))
        now = datetime(2026, 8, 25, tzinfo=UTC)
        current = now
        decision, late, count, _ = decision_clock(current, now, bars, timedelta(0))
        self.assertTrue(decision)
        self.assertTrue(late)
        self.assertEqual(count, 1)
        attempts: set[int] = set()
        self.assertTrue(consume_attempt(attempts, 20260824))
        self.assertFalse(consume_attempt(attempts, 20260824))

    def test_year_boundary_and_lifecycle_guards(self) -> None:
        self.assertEqual(week_key(datetime(2027, 1, 3, tzinfo=UTC)), 20261228)
        self.assertEqual(next_week_key(20261228), 20270104)
        opened = datetime(2026, 8, 24, 0, 1, tzinfo=UTC)
        current = datetime(2026, 8, 28, tzinfo=UTC)
        self.assertFalse(should_close(opened, current, current, timedelta(0)))
        self.assertTrue(should_close(opened, datetime(2026, 8, 31, tzinfo=UTC), datetime(2026, 8, 31, tzinfo=UTC), timedelta(0)))
        self.assertTrue(should_close(opened, current, opened + timedelta(days=10), timedelta(0)))
        self.assertTrue(should_close(None, current, current, timedelta(0)))
        self.assertTrue(should_close(opened, current, current, None))

    def test_static_build_contract_is_fixed_risk_and_completed_data_only(self) -> None:
        source = (EA_DIR / "QM5_41093_wti-wclose-breakout-mom.mq5").read_text(encoding="utf-8")
        setfile = (EA_DIR / "sets" / "QM5_41093_wti-wclose-breakout-mom_XTIUSD.DWX_D1_backtest.set").read_text(encoding="utf-8")
        for marker in (
            "input double RISK_PERCENT                  = 0.0;",
            "input double RISK_FIXED                    = 1000.0;",
            "input double PORTFOLIO_WEIGHT              = 1.0;",
            "input int    strategy_label_offset_seconds = 86400;",
            "CopyRates(_Symbol, // perf-allowed: bounded completed-week OHLC scan behind the sole QM_IsNewBar branch.",
            "PERIOD_D1,\n                1,",
            "session_date_key >= week_last_date_keys[bucket]",
            "if(new_close > parent_high)",
            "else if(new_close < parent_low)",
            "QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1)",
            "req.tp = 0.0;",
            "opened_week_key != current_week_key",
        ):
            self.assertIn(marker, source)
        self.assertNotIn("strict_inside", source)
        self.assertNotIn("new_body", source)
        self.assertNotIn("strategy_clv_", source)
        self.assertLess(
            source.index("Strategy_RecordWeekAttempt(g_decision_week_key)"),
            source.index("Strategy_LoadClosingBreakoutSignal(g_decision_week_key"),
        )
        for marker in (
            "qm_ea_id=41093",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_label_offset_seconds=86400",
            "strategy_required_weeks=2",
            "strategy_entry_grace_minutes=180",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
            "strategy_max_hold_days=10",
        ):
            self.assertIn(marker, setfile)


if __name__ == "__main__":
    unittest.main()
