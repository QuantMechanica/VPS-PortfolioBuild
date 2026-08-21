"""Deterministic reference checks for QM5_41087 weekly WR4 close momentum."""

from __future__ import annotations

import itertools
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


def wr4_signal(
    current_week_key: int,
    completed_newest_first: list[Bar],
    offset: timedelta,
    minimum: int = 3,
    maximum: int = 5,
    upper: float = 0.75,
    lower: float = 0.25,
):
    """Mirror four-week aggregation, strict range rank, body, and CLV gates."""

    empty = (False, 0, (0, 0, 0, 0), tuple(), (0.0,) * 4, 0.0, 0.0, False)
    if current_week_key <= 0 or offset not in (timedelta(0), timedelta(days=1)):
        return empty
    if len(completed_newest_first) < minimum * 4 + 1:
        return empty

    keys: list[int] = []
    buckets: list[list[Bar]] = []
    oldest_boundary_seen = False
    for index, bar in enumerate(completed_newest_first):
        if not ohlc_valid(bar):
            return empty
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return empty
        key = week_key(bar.opened + offset)
        if key <= 0 or key == current_week_key:
            return empty
        if not keys or key != keys[-1]:
            if len(keys) >= 4:
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

    if len(keys) != 4 or not oldest_boundary_seen:
        return empty
    if any(not minimum <= len(bucket) <= maximum for bucket in buckets):
        return empty

    weekly: list[tuple[float, float, float, float]] = []
    for bucket in buckets:
        package = (
            bucket[-1].open,
            max(bar.high for bar in bucket),
            min(bar.low for bar in bucket),
            bucket[0].close,
        )
        if (
            package[1] < max(package[0], package[3])
            or package[2] > min(package[0], package[3])
        ):
            return empty
        weekly.append(package)

    ranges = tuple(high - low for _, high, low, _ in weekly)
    if any(value <= 0.0 or not math.isfinite(value) for value in ranges):
        return empty
    body = math.log(weekly[0][3] / weekly[0][0])
    clv = (weekly[0][3] - weekly[0][2]) / ranges[0]
    if not math.isfinite(body) or not math.isfinite(clv) or not 0.0 <= clv <= 1.0:
        return empty

    widest = ranges[0] > ranges[1] and ranges[0] > ranges[2] and ranges[0] > ranges[3]
    direction = 0
    if widest and body > 0.0 and clv > upper:
        direction = 1
    elif widest and body < 0.0 and clv < lower:
        direction = -1
    return (
        True,
        direction,
        tuple(len(bucket) for bucket in buckets),
        tuple(weekly),
        ranges,
        body,
        clv,
        widest,
    )


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


DEFAULT_WEEKS = (
    (100.0, 130.0, 90.0, 128.0),
    (110.0, 125.0, 100.0, 115.0),
    (105.0, 120.0, 100.0, 110.0),
    (100.0, 118.0, 98.0, 105.0),
)


def sample(
    weeks: tuple[tuple[float, float, float, float], ...] = DEFAULT_WEEKS,
    counts: tuple[int, int, int, int] = (5, 5, 5, 5),
    prior_date_labels: bool = False,
) -> tuple[datetime, datetime, list[Bar]]:
    current = datetime(2026, 8, 24, tzinfo=UTC)
    now = current
    anchors = (
        datetime(2026, 8, 17, tzinfo=UTC),
        datetime(2026, 8, 10, tzinfo=UTC),
        datetime(2026, 8, 3, tzinfo=UTC),
        datetime(2026, 7, 27, tzinfo=UTC),
    )
    bars: list[Bar] = []
    for anchor, count, aggregate in zip(anchors, counts, weeks):
        bars.extend(make_week(anchor, count, aggregate))
    bars.extend(
        make_week(
            datetime(2026, 7, 20, tzinfo=UTC),
            3,
            (100.0, 110.0, 95.0, 102.0),
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


class WeekWR4CloseMomentumReferenceTest(unittest.TestCase):
    def signal(self, bars: list[Bar], offset: timedelta = timedelta(0)):
        return wr4_signal(20260824, bars, offset)

    def test_strict_long_and_short_paths_and_ohlc_endpoints(self) -> None:
        _, _, bars = sample()
        valid, direction, counts, weekly, ranges, body, clv, widest = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertEqual(counts, (5, 5, 5, 5))
        self.assertEqual(weekly[0], DEFAULT_WEEKS[0])
        self.assertEqual(ranges, (40.0, 25.0, 20.0, 20.0))
        self.assertAlmostEqual(body, math.log(128.0 / 100.0))
        self.assertGreater(clv, 0.75)
        self.assertTrue(widest)

        short_weeks = ((120.0, 130.0, 90.0, 92.0), *DEFAULT_WEEKS[1:])
        _, _, bars = sample(weeks=short_weeks)
        valid, direction, _, _, _, body, clv, widest = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertLess(body, 0.0)
        self.assertLess(clv, 0.25)
        self.assertTrue(widest)

    def test_three_four_and_five_session_weeks_are_accepted(self) -> None:
        for counts in itertools.product((3, 4, 5), repeat=4):
            _, _, bars = sample(counts=counts)
            valid, direction, actual, *_ = self.signal(bars)
            self.assertTrue(valid)
            self.assertEqual(direction, 1)
            self.assertEqual(actual, counts)

    def test_two_and_six_session_weeks_are_rejected(self) -> None:
        for bad_index in range(4):
            for bad_count in (2, 6):
                counts = [5, 5, 5, 5]
                counts[bad_index] = bad_count
                _, _, bars = sample(counts=tuple(counts))
                self.assertFalse(self.signal(bars)[0])

    def test_range_ties_and_older_wider_states_are_valid_but_flat(self) -> None:
        for older in (
            (110.0, 130.0, 90.0, 115.0),
            (110.0, 135.0, 90.0, 115.0),
        ):
            weeks = (DEFAULT_WEEKS[0], older, *DEFAULT_WEEKS[2:])
            _, _, bars = sample(weeks=weeks)
            valid, direction, *_, widest = self.signal(bars)
            self.assertTrue(valid)
            self.assertEqual(direction, 0)
            self.assertFalse(widest)

    def test_threshold_equalities_zero_body_and_disagreement_are_flat(self) -> None:
        newest_cases = (
            (100.0, 130.0, 90.0, 120.0),
            (120.0, 130.0, 90.0, 100.0),
            (110.0, 150.0, 80.0, 110.0),
            (95.0, 130.0, 90.0, 98.0),
            (125.0, 130.0, 90.0, 122.0),
        )
        for newest in newest_cases:
            _, _, bars = sample(weeks=(newest, *DEFAULT_WEEKS[1:]))
            valid, direction, *_ = self.signal(bars)
            self.assertTrue(valid)
            self.assertEqual(direction, 0)

    def test_malformed_zero_range_nonconsecutive_and_current_week_rejected(self) -> None:
        _, _, bars = sample()
        broken = list(bars)
        bar = broken[0]
        broken[0] = Bar(bar.opened, bar.open, bar.low - 1.0, bar.low, bar.close)
        self.assertFalse(self.signal(broken)[0])

        zero_weeks = ((100.0, 100.0, 100.0, 100.0), *DEFAULT_WEEKS[1:])
        _, _, bars = sample(weeks=zero_weeks)
        self.assertFalse(self.signal(bars)[0])

        _, _, bars = sample()
        nonconsecutive = [
            Bar(
                bar.opened - timedelta(days=7)
                if week_key(bar.opened) == 20260803
                else bar.opened,
                bar.open,
                bar.high,
                bar.low,
                bar.close,
            )
            for bar in bars
        ]
        self.assertFalse(self.signal(nonconsecutive)[0])

        _, _, bars = sample()
        bars.insert(
            0,
            Bar(datetime(2026, 8, 24, tzinfo=UTC), 128.0, 129.0, 127.0, 128.5),
        )
        self.assertFalse(self.signal(bars)[0])

    def test_uniform_prior_date_labels_match_native(self) -> None:
        current, now, bars = sample()
        decision, late, count, offset = decision_clock(current, now, bars)
        self.assertEqual((decision, late, count, offset), (True, False, 0, timedelta(0)))
        native = self.signal(bars)

        current, now, bars = sample(prior_date_labels=True)
        decision, late, count, offset = decision_clock(current, now, bars)
        self.assertEqual(
            (decision, late, count, offset),
            (True, False, 0, timedelta(days=1)),
        )
        self.assertEqual(self.signal(bars, timedelta(days=1)), native)
        self.assertTrue(within_entry_grace(current, now + timedelta(minutes=180)))
        self.assertFalse(within_entry_grace(current, now + timedelta(minutes=181)))

    def test_late_restart_is_detected_and_attempt_is_consumed_once(self) -> None:
        _, _, bars = sample()
        bars.insert(
            0,
            Bar(datetime(2026, 8, 24, tzinfo=UTC), 128.0, 129.0, 127.0, 128.5),
        )
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
        following = datetime(2026, 8, 31, tzinfo=UTC)
        self.assertTrue(should_close(opened, following, following, timedelta(0)))
        self.assertTrue(
            should_close(opened, current, opened + timedelta(days=10), timedelta(0))
        )
        self.assertTrue(should_close(None, current, current, timedelta(0)))
        self.assertTrue(should_close(opened, current, current, None))

    def test_static_build_contract_is_fixed_risk_and_completed_data_only(self) -> None:
        source = (EA_DIR / "QM5_41087_wti-wr4-close-mom.mq5").read_text(
            encoding="utf-8"
        )
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41087_wti-wr4-close-mom_XTIUSD.DWX_D1_backtest.set"
        ).read_text(encoding="utf-8")
        for marker in (
            "input double RISK_PERCENT                  = 0.0;",
            "input double RISK_FIXED                    = 1000.0;",
            "input double PORTFOLIO_WEIGHT              = 1.0;",
            "CopyRates(_Symbol, // perf-allowed: bounded completed-week OHLC scan behind the sole QM_IsNewBar branch.",
            "PERIOD_D1,\n                1,",
            "g_week_ranges[0] > g_week_ranges[1]",
            "g_week_body = MathLog(g_new_close / g_new_open);",
            "g_close_location > strategy_clv_upper",
            "g_close_location < strategy_clv_lower",
            "QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1)",
            "req.tp = 0.0;",
            "opened_week_key != current_week_key",
        ):
            self.assertIn(marker, source)
        self.assertLess(
            source.index("Strategy_RecordWeekAttempt(g_decision_week_key)"),
            source.index("Strategy_LoadWR4Signal(g_decision_week_key"),
        )
        for forbidden in ("iRSI(", "iMACD(", "iStochastic(", "WebRequest("):
            self.assertNotIn(forbidden, source)
        for marker in (
            "qm_ea_id=41087",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "strategy_history_bars=50",
            "strategy_required_weeks=4",
            "strategy_clv_upper=0.75",
            "strategy_clv_lower=0.25",
        ):
            self.assertIn(marker, setfile)


if __name__ == "__main__":
    unittest.main()
