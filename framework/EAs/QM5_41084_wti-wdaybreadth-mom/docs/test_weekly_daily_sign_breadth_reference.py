"""Deterministic reference checks for QM5_41084 weekly daily-sign breadth."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
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
        and bar.high >= bar.low
        and bar.high >= max(bar.open, bar.close)
        and bar.low <= min(bar.open, bar.close)
    )


def daily_breadth_signal(
    current_week_key: int,
    completed_newest_first: list[Bar],
    offset: timedelta,
    required_sessions: int = 5,
    minimum_same_sign: int = 4,
    minimum_parent_sessions: int = 3,
    maximum_parent_sessions: int = 5,
) -> tuple[bool, int, tuple[int, int], tuple[float, ...], int, int, float]:
    """Mirror the bounded parent-plus-five-session breadth calculation."""

    empty = (False, 0, (0, 0), (0.0,) * 6, 0, 0, 0.0)
    if (
        current_week_key <= 0
        or required_sessions != 5
        or minimum_same_sign != 4
        or offset not in (timedelta(0), timedelta(days=1))
    ):
        return empty
    if len(completed_newest_first) < required_sessions + minimum_parent_sessions + 1:
        return empty

    keys: list[int] = []
    buckets: list[list[Bar]] = []
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
        buckets[-1].append(bar)
        if len(buckets) == 1 and len(buckets[0]) > required_sessions:
            return empty
        if len(buckets) == 2 and len(buckets[1]) > maximum_parent_sessions:
            return empty

    if len(keys) != 2 or not parent_boundary_seen:
        return empty
    newest, parent = buckets
    if len(newest) != required_sessions:
        return empty
    if not minimum_parent_sessions <= len(parent) <= maximum_parent_sessions:
        return empty

    parent_close = parent[0].close
    newest_chronological = [bar.close for bar in reversed(newest)]
    closes = [parent_close, *newest_chronological]
    if any(value <= 0.0 or not math.isfinite(value) for value in closes):
        return empty
    returns = tuple(math.log(closes[index + 1] / closes[index]) for index in range(5))
    if any(not math.isfinite(value) for value in returns):
        return empty
    positive_count = sum(value > 0.0 for value in returns)
    negative_count = sum(value < 0.0 for value in returns)
    weekly_net = math.log(closes[-1] / closes[0])

    direction = 0
    if positive_count >= minimum_same_sign and weekly_net > 0.0:
        direction = 1
    elif negative_count >= minimum_same_sign and weekly_net < 0.0:
        direction = -1
    return (
        True,
        direction,
        (len(newest), len(parent)),
        tuple(closes),
        positive_count,
        negative_count,
        weekly_net,
    )


def make_week(anchor: datetime, closes: list[float]) -> list[Bar]:
    bars: list[Bar] = []
    prior = closes[0]
    for index, close in enumerate(closes):
        opened = prior
        high = max(opened, close) + 1.0
        low = min(opened, close) - 1.0
        bars.append(Bar(anchor + timedelta(days=index), opened, high, low, close))
        prior = close
    return list(reversed(bars))


def sample(
    newest_closes: list[float] | None = None,
    parent_closes: list[float] | None = None,
    prior_date_labels: bool = False,
) -> tuple[datetime, datetime, list[Bar]]:
    if newest_closes is None:
        newest_closes = [102.0, 104.0, 103.0, 105.0, 107.0]
    if parent_closes is None:
        parent_closes = [96.0, 97.0, 98.0, 99.0, 100.0]
    current = datetime(2026, 8, 24, tzinfo=UTC)
    now = current
    bars = (
        make_week(datetime(2026, 8, 17, tzinfo=UTC), newest_closes)
        + make_week(datetime(2026, 8, 10, tzinfo=UTC), parent_closes)
        + make_week(datetime(2026, 8, 3, tzinfo=UTC), [95.0, 96.0, 97.0])
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


class WeekDailySignBreadthReferenceTest(unittest.TestCase):
    def signal(self, bars: list[Bar], offset: timedelta = timedelta(0)):
        return daily_breadth_signal(20260824, bars, offset)

    def test_four_of_five_long_and_short(self) -> None:
        _, _, bars = sample()
        valid, direction, counts, closes, positive, negative, weekly_net = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertEqual(counts, (5, 5))
        self.assertEqual(closes, (100.0, 102.0, 104.0, 103.0, 105.0, 107.0))
        self.assertEqual((positive, negative), (4, 1))
        self.assertGreater(weekly_net, 0.0)

        _, _, bars = sample(newest_closes=[98.0, 96.0, 97.0, 95.0, 93.0])
        valid, direction, _, _, positive, negative, weekly_net = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertEqual((positive, negative), (1, 4))
        self.assertLess(weekly_net, 0.0)

    def test_five_of_five_and_one_zero_are_eligible(self) -> None:
        for closes in (
            [101.0, 102.0, 103.0, 104.0, 105.0],
            [102.0, 104.0, 104.0, 106.0, 108.0],
        ):
            _, _, bars = sample(newest_closes=closes)
            valid, direction, _, _, positive, negative, _ = self.signal(bars)
            self.assertTrue(valid)
            self.assertEqual(direction, 1)
            self.assertGreaterEqual(positive, 4)
            self.assertEqual(negative, 0)

    def test_three_of_five_and_breadth_net_disagreement_are_flat(self) -> None:
        cases = (
            [102.0, 101.0, 103.0, 102.0, 104.0],
            [101.0, 102.0, 103.0, 104.0, 90.0],
            [99.0, 98.0, 97.0, 96.0, 110.0],
        )
        for closes in cases:
            _, _, bars = sample(newest_closes=list(closes))
            valid, direction, *_ = self.signal(bars)
            self.assertTrue(valid)
            self.assertEqual(direction, 0)

    def test_exactly_five_newest_sessions_are_required(self) -> None:
        for closes in ([101.0, 102.0, 103.0, 104.0], [101.0, 102.0, 103.0, 104.0, 105.0, 106.0]):
            _, _, bars = sample(newest_closes=list(closes))
            self.assertFalse(self.signal(bars)[0])

    def test_parent_three_to_five_sessions_only(self) -> None:
        for count in (3, 4, 5):
            _, _, bars = sample(parent_closes=[100.0] * count)
            valid, direction, counts, *_ = self.signal(bars)
            self.assertTrue(valid)
            self.assertEqual(direction, 1)
            self.assertEqual(counts, (5, count))
        for count in (2, 6):
            _, _, bars = sample(parent_closes=[100.0] * count)
            self.assertFalse(self.signal(bars)[0])

    def test_malformed_nonconsecutive_and_current_week_rejected(self) -> None:
        _, _, bars = sample()
        broken = list(bars)
        bad = broken[0]
        broken[0] = Bar(bad.opened, bad.open, bad.low - 1.0, bad.low, bad.close)
        self.assertFalse(self.signal(broken)[0])

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
        bars.insert(0, Bar(datetime(2026, 8, 24, tzinfo=UTC), 107.0, 108.0, 106.0, 107.5))
        self.assertFalse(self.signal(bars)[0])

    def test_uniform_prior_date_labels_match_native(self) -> None:
        current, now, bars = sample()
        decision, late, count, offset = decision_clock(current, now, bars)
        self.assertEqual((decision, late, count, offset), (True, False, 0, timedelta(0)))
        native = self.signal(bars, timedelta(0))

        current, now, bars = sample(prior_date_labels=True)
        decision, late, count, offset = decision_clock(current, now, bars)
        self.assertEqual((decision, late, count, offset), (True, False, 0, timedelta(days=1)))
        self.assertEqual(self.signal(bars, timedelta(days=1)), native)
        self.assertTrue(within_entry_grace(current, now + timedelta(minutes=180)))
        self.assertFalse(within_entry_grace(current, now + timedelta(minutes=181)))

    def test_late_restart_is_detected_and_week_is_consumed_once(self) -> None:
        current, _, bars = sample()
        bars.insert(0, Bar(datetime(2026, 8, 24, tzinfo=UTC), 107.0, 108.0, 106.0, 107.5))
        now = datetime(2026, 8, 25, tzinfo=UTC)
        current = now
        decision, late, count, _ = decision_clock(current, now, bars)
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
        self.assertTrue(
            should_close(
                opened,
                datetime(2026, 8, 31, tzinfo=UTC),
                datetime(2026, 8, 31, tzinfo=UTC),
                timedelta(0),
            )
        )
        self.assertTrue(should_close(opened, current, opened + timedelta(days=10), timedelta(0)))
        self.assertTrue(should_close(None, current, current, timedelta(0)))
        self.assertTrue(should_close(opened, current, current, None))

    def test_static_build_contract_is_fixed_risk_and_completed_data_only(self) -> None:
        source = (EA_DIR / "QM5_41084_wti-wdaybreadth-mom.mq5").read_text(encoding="utf-8")
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41084_wti-wdaybreadth-mom_XTIUSD.DWX_D1_backtest.set"
        ).read_text(encoding="utf-8")
        for marker in (
            "input double RISK_PERCENT                  = 0.0;",
            "input double RISK_FIXED                    = 1000.0;",
            "input double PORTFOLIO_WEIGHT              = 1.0;",
            "CopyRates(_Symbol, // perf-allowed: bounded completed-week daily-sign scan behind the sole QM_IsNewBar branch.",
            "PERIOD_D1,\n                1,",
            "const double component_return = MathLog(newer_close / older_close);",
            "weekly_net = MathLog(newest_close / parent_close);",
            "positive_count >= strategy_min_same_sign && weekly_net > 0.0",
            "negative_count >= strategy_min_same_sign && weekly_net < 0.0",
            "QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1)",
            "req.tp = 0.0;",
            "opened_week_key != current_week_key",
        ):
            self.assertIn(marker, source)
        self.assertLess(
            source.index("Strategy_RecordWeekAttempt(g_decision_week_key)"),
            source.index("Strategy_LoadDailyBreadthSignal(g_decision_week_key"),
        )
        for marker in (
            "qm_ea_id=41084",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_required_sessions=5",
            "strategy_min_same_sign=4",
        ):
            self.assertIn(marker, setfile)


if __name__ == "__main__":
    unittest.main()
