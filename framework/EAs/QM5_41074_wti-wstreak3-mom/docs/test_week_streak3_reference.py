"""Deterministic reference checks for QM5_41074 WTI three-week streak."""

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


def fresh_streak_signal(
    current_week_key: int,
    completed_newest_first: list[Bar],
    offset: timedelta,
    required_weeks: int = 5,
    minimum: int = 3,
    maximum: int = 5,
) -> tuple[bool, int, tuple[int, ...], tuple[float, ...], tuple[float, ...]]:
    """Mirror the bounded five-week endpoint scan and strict sign path."""

    empty = (False, 0, (), (), ())
    if current_week_key <= 0 or offset not in (timedelta(0), timedelta(days=1)):
        return empty
    if len(completed_newest_first) < minimum * required_weeks + 1:
        return empty

    keys: list[int] = []
    buckets: list[list[Bar]] = []
    oldest_boundary_seen = False
    for index, bar in enumerate(completed_newest_first):
        if bar.opened.timestamp() <= 0:
            return empty
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return empty
        key = week_key(bar.opened + offset)
        if key == current_week_key:
            return empty
        if not keys or key != keys[-1]:
            if len(keys) >= required_weeks:
                if next_week_key(key) != keys[-1]:
                    return empty
                oldest_boundary_seen = True
                break
            if not keys:
                if next_week_key(key) != current_week_key:
                    return empty
            elif next_week_key(key) != keys[-1]:
                return empty
            keys.append(key)
            buckets.append([])
        buckets[-1].append(bar)
        if len(buckets[-1]) > maximum:
            return empty

    if len(keys) != required_weeks or not oldest_boundary_seen:
        return empty
    if any(not minimum <= len(bucket) <= maximum for bucket in buckets):
        return empty

    closes = tuple(bucket[0].close for bucket in buckets)
    if any(close <= 0.0 or not math.isfinite(close) for close in closes):
        return empty
    returns = tuple(math.log(closes[index] / closes[index + 1]) for index in range(4))
    if any(not math.isfinite(value) for value in returns):
        return empty

    r0, r1, r2, r3 = returns
    direction = 0
    if r0 > 0.0 and r1 > 0.0 and r2 > 0.0 and r3 < 0.0:
        direction = 1
    elif r0 < 0.0 and r1 < 0.0 and r2 < 0.0 and r3 > 0.0:
        direction = -1
    return True, direction, tuple(map(len, buckets)), returns, closes


def make_week(anchor: datetime, count: int, endpoint: float) -> list[Bar]:
    chronological = [
        Bar(anchor + timedelta(days=index), endpoint - (count - index - 1) * 0.1)
        for index in range(count)
    ]
    return list(reversed(chronological))


def sample(
    endpoints: tuple[float, float, float, float, float] = (120.0, 110.0, 100.0, 90.0, 100.0),
    counts: tuple[int, int, int, int, int] = (5, 5, 5, 5, 5),
    prior_date_labels: bool = False,
) -> tuple[datetime, datetime, list[Bar]]:
    current = datetime(2026, 8, 24, tzinfo=UTC)
    now = current
    anchors = [
        datetime(2026, 8, 17, tzinfo=UTC),
        datetime(2026, 8, 10, tzinfo=UTC),
        datetime(2026, 8, 3, tzinfo=UTC),
        datetime(2026, 7, 27, tzinfo=UTC),
        datetime(2026, 7, 20, tzinfo=UTC),
    ]
    bars: list[Bar] = []
    for anchor, count, endpoint in zip(anchors, counts, endpoints, strict=True):
        bars.extend(make_week(anchor, count, endpoint))
    bars.extend(make_week(datetime(2026, 7, 13, tzinfo=UTC), 3, 95.0))
    if prior_date_labels:
        current -= timedelta(days=1)
        bars = [Bar(bar.opened - timedelta(days=1), bar.close) for bar in bars]
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


class WeekStreak3ReferenceTest(unittest.TestCase):
    def signal(self, bars: list[Bar], offset: timedelta = timedelta(0)):
        return fresh_streak_signal(20260824, bars, offset)

    def test_fresh_positive_streak_is_long(self) -> None:
        _, _, bars = sample()
        valid, direction, counts, returns, closes = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertEqual(counts, (5, 5, 5, 5, 5))
        self.assertEqual(closes, (120.0, 110.0, 100.0, 90.0, 100.0))
        self.assertTrue(all(value > 0.0 for value in returns[:3]))
        self.assertLess(returns[3], 0.0)

    def test_fresh_negative_streak_is_short(self) -> None:
        _, _, bars = sample((80.0, 90.0, 100.0, 110.0, 100.0))
        valid, direction, _, returns, _ = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertTrue(all(value < 0.0 for value in returns[:3]))
        self.assertGreater(returns[3], 0.0)

    def test_rolling_fourth_week_and_nearby_paths_are_flat(self) -> None:
        cases = (
            (140.0, 130.0, 120.0, 110.0, 100.0),
            (120.0, 110.0, 100.0, 105.0, 95.0),
            (120.0, 110.0, 100.0, 90.0, 80.0),
            (120.0, 110.0, 105.0, 105.0, 100.0),
            (100.0, 110.0, 100.0, 90.0, 100.0),
        )
        for endpoints in cases:
            _, _, bars = sample(endpoints)
            valid, direction, _, _, _ = self.signal(bars)
            self.assertTrue(valid)
            self.assertEqual(direction, 0)

    def test_three_four_and_five_session_weeks_are_accepted(self) -> None:
        for count in (3, 4, 5):
            counts = (count, 5, 4, 3, 5)
            _, _, bars = sample(counts=counts)
            valid, direction, observed, _, _ = self.signal(bars)
            self.assertTrue(valid)
            self.assertEqual(direction, 1)
            self.assertEqual(observed, counts)

    def test_two_and_six_session_weeks_are_rejected(self) -> None:
        for counts in ((2, 5, 5, 5, 5), (5, 6, 5, 5, 5), (5, 5, 5, 2, 5)):
            _, _, bars = sample(counts=counts)
            self.assertFalse(self.signal(bars)[0])

    def test_bad_endpoint_reverse_order_and_missing_boundary_are_rejected(self) -> None:
        _, _, bars = sample()
        broken = list(bars)
        first = broken[0]
        broken[0] = Bar(first.opened, 0.0)
        self.assertFalse(self.signal(broken)[0])

        _, _, bars = sample()
        broken = list(bars)
        broken[1] = Bar(broken[0].opened + timedelta(days=1), broken[1].close)
        self.assertFalse(self.signal(broken)[0])

        _, _, bars = sample()
        self.assertFalse(self.signal(bars[:-3])[0])

    def test_nonconsecutive_and_current_week_history_are_rejected(self) -> None:
        _, _, bars = sample()
        broken = [
            Bar(bar.opened - timedelta(days=7) if index >= 5 else bar.opened, bar.close)
            for index, bar in enumerate(bars)
        ]
        self.assertFalse(self.signal(broken)[0])

        _, _, bars = sample()
        bars.insert(0, Bar(datetime(2026, 8, 24, tzinfo=UTC), 121.0))
        self.assertFalse(self.signal(bars)[0])

    def test_uniform_prior_date_labels_match_native_and_grace_is_strict(self) -> None:
        current, now, bars = sample()
        decision, late, count, offset = decision_clock(current, now, bars)
        self.assertEqual((decision, late, count, offset), (True, False, 0, timedelta(0)))
        native = self.signal(bars)

        current, now, bars = sample(prior_date_labels=True)
        decision, late, count, offset = decision_clock(current, now, bars)
        self.assertEqual((decision, late, count, offset), (True, False, 0, timedelta(days=1)))
        self.assertEqual(self.signal(bars, timedelta(days=1)), native)
        self.assertTrue(within_entry_grace(current, now + timedelta(minutes=180)))
        self.assertFalse(within_entry_grace(current, now + timedelta(minutes=181)))

    def test_late_restart_is_detected_and_attempt_is_single_use(self) -> None:
        _, _, bars = sample()
        bars.insert(0, Bar(datetime(2026, 8, 24, tzinfo=UTC), 121.0))
        now = datetime(2026, 8, 25, tzinfo=UTC)
        decision, late, count, _ = decision_clock(now, now, bars)
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
        source = (EA_DIR / "QM5_41074_wti-wstreak3-mom.mq5").read_text(encoding="utf-8")
        setfile = (EA_DIR / "sets" / "QM5_41074_wti-wstreak3-mom_XTIUSD.DWX_D1_backtest.set").read_text(encoding="utf-8")
        for marker in (
            "input double RISK_PERCENT                  = 0.0;",
            "input double RISK_FIXED                    = 1000.0;",
            "input double PORTFOLIO_WEIGHT              = 1.0;",
            "CopyRates(_Symbol, // perf-allowed: bounded completed-week endpoint scan behind the sole QM_IsNewBar branch.",
            "PERIOD_D1,\n                1,",
            "strategy_required_weeks != 5",
            "QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1)",
            "req.tp = 0.0;",
            "opened_week_key != current_week_key",
        ):
            self.assertIn(marker, source)
        self.assertLess(source.index("Strategy_RecordWeekAttempt(g_decision_week_key)"), source.index("Strategy_LoadFreshStreakSignal(g_decision_week_key"))
        for marker in (
            "qm_ea_id=41074",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_required_weeks=5",
        ):
            self.assertIn(marker, setfile)


if __name__ == "__main__":
    unittest.main()
