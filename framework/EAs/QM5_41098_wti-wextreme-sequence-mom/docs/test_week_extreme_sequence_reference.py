"""Deterministic reference checks for QM5_41098 weekly extreme sequence."""

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


@dataclass(frozen=True)
class Signal:
    valid: bool = False
    direction: int = 0
    week_bars: int = 0
    week_open: float = 0.0
    week_high: float = 0.0
    week_low: float = 0.0
    week_close: float = 0.0
    high_occurrences: int = 0
    low_occurrences: int = 0
    high_series_index: int = -1
    low_series_index: int = -1
    extreme_sequence: int = 0
    extremes_unique: bool = False
    settlement_agrees: bool = False


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


def extreme_sequence_signal(
    current_week_key: int,
    completed_newest_first: list[Bar],
    offset: timedelta,
    minimum: int = 3,
    maximum: int = 5,
    required_weeks: int = 1,
    require_unique_extremes: bool = True,
) -> Signal:
    """Mirror the bounded completed-week sequence and settlement contract."""

    if (
        current_week_key <= 0
        or offset not in (timedelta(0), timedelta(days=1))
        or required_weeks != 1
        or not require_unique_extremes
        or len(completed_newest_first) < minimum + 1
    ):
        return Signal()

    completed_key = 0
    last_session_date: date | None = None
    bucket: list[Bar] = []
    older_boundary_seen = False
    for index, bar in enumerate(completed_newest_first):
        if not ohlc_valid(bar):
            return Signal()
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return Signal()

        key = week_key(bar.opened + offset)
        if key <= 0 or key == current_week_key:
            return Signal()
        if completed_key == 0:
            if next_week_key(key) != current_week_key:
                return Signal()
            completed_key = key
        elif key != completed_key:
            if next_week_key(key) != completed_key:
                return Signal()
            older_boundary_seen = True
            break

        normalized_date = (bar.opened + offset).date()
        if last_session_date is not None and normalized_date >= last_session_date:
            return Signal()
        last_session_date = normalized_date
        bucket.append(bar)
        if len(bucket) > maximum:
            return Signal()

    if not older_boundary_seen or not minimum <= len(bucket) <= maximum:
        return Signal()

    week_open = bucket[-1].open
    week_high = max(bar.high for bar in bucket)
    week_low = min(bar.low for bar in bucket)
    week_close = bucket[0].close
    values = (week_open, week_high, week_low, week_close)
    if (
        week_high <= week_low
        or week_high < max(week_open, week_close)
        or week_low > min(week_open, week_close)
        or not all(math.isfinite(value) and value > 0.0 for value in values)
    ):
        return Signal()

    high_occurrences = sum(bar.high == week_high for bar in bucket)
    low_occurrences = sum(bar.low == week_low for bar in bucket)
    high_series_index = next(
        index for index, bar in enumerate(bucket) if bar.high == week_high
    )
    low_series_index = next(
        index for index, bar in enumerate(bucket) if bar.low == week_low
    )
    extremes_unique = high_occurrences == 1 and low_occurrences == 1

    extreme_sequence = 0
    if extremes_unique:
        if low_series_index > high_series_index:
            extreme_sequence = 1
        elif high_series_index > low_series_index:
            extreme_sequence = -1

    settlement_agrees = (
        extreme_sequence > 0 and week_close > week_open
    ) or (
        extreme_sequence < 0 and week_close < week_open
    )
    return Signal(
        valid=True,
        direction=extreme_sequence if settlement_agrees else 0,
        week_bars=len(bucket),
        week_open=week_open,
        week_high=week_high,
        week_low=week_low,
        week_close=week_close,
        high_occurrences=high_occurrences,
        low_occurrences=low_occurrences,
        high_series_index=high_series_index,
        low_series_index=low_series_index,
        extreme_sequence=extreme_sequence,
        extremes_unique=extremes_unique,
        settlement_agrees=settlement_agrees,
    )


def make_extreme_week(
    anchor: datetime,
    count: int,
    *,
    high_indices: tuple[int, ...],
    low_indices: tuple[int, ...],
    week_open: float,
    week_close: float,
) -> list[Bar]:
    """Create chronological bars, then return the MT5 series ordering."""

    bars: list[Bar] = []
    for index in range(count):
        bar_open = week_open if index == 0 else 100.0
        bar_close = week_close if index == count - 1 else 100.0
        bar_high = max(bar_open, bar_close, 110.0)
        bar_low = min(bar_open, bar_close, 90.0)
        if index in high_indices:
            bar_high = 130.0
        if index in low_indices:
            bar_low = 70.0
        bars.append(
            Bar(
                opened=anchor + timedelta(days=index),
                open=bar_open,
                high=bar_high,
                low=bar_low,
                close=bar_close,
            )
        )
    return list(reversed(bars))


def sample(
    *,
    count: int = 5,
    high_indices: tuple[int, ...] | None = None,
    low_indices: tuple[int, ...] | None = None,
    week_open: float = 100.0,
    week_close: float = 115.0,
    prior_date_labels: bool = False,
) -> tuple[datetime, datetime, list[Bar]]:
    current = datetime(2026, 8, 24, tzinfo=UTC)
    now = current
    if high_indices is None:
        high_indices = (count - 1,)
    if low_indices is None:
        low_indices = (0,)
    bars = make_extreme_week(
        datetime(2026, 8, 17, tzinfo=UTC),
        count,
        high_indices=high_indices,
        low_indices=low_indices,
        week_open=week_open,
        week_close=week_close,
    )
    bars += make_extreme_week(
        datetime(2026, 8, 10, tzinfo=UTC),
        3,
        high_indices=(2,),
        low_indices=(0,),
        week_open=100.0,
        week_close=101.0,
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


class WeekExtremeSequenceReferenceTest(unittest.TestCase):
    def signal(self, bars: list[Bar], offset: timedelta = timedelta(0)) -> Signal:
        return extreme_sequence_signal(20260824, bars, offset)

    def test_unique_low_before_high_long_and_inverse_short(self) -> None:
        _, _, bars = sample()
        signal = self.signal(bars)
        self.assertTrue(signal.valid)
        self.assertEqual(signal.direction, 1)
        self.assertEqual(signal.extreme_sequence, 1)
        self.assertEqual((signal.low_series_index, signal.high_series_index), (4, 0))
        self.assertEqual((signal.high_occurrences, signal.low_occurrences), (1, 1))
        self.assertTrue(signal.extremes_unique)
        self.assertTrue(signal.settlement_agrees)

        _, _, bars = sample(
            high_indices=(0,), low_indices=(4,), week_close=85.0
        )
        signal = self.signal(bars)
        self.assertEqual(signal.direction, -1)
        self.assertEqual(signal.extreme_sequence, -1)
        self.assertEqual((signal.high_series_index, signal.low_series_index), (4, 0))

    def test_three_four_and_five_session_packages_are_accepted(self) -> None:
        for count in (3, 4, 5):
            with self.subTest(count=count):
                _, _, bars = sample(count=count)
                signal = self.signal(bars)
                self.assertTrue(signal.valid)
                self.assertEqual(signal.direction, 1)
                self.assertEqual(signal.week_bars, count)

    def test_two_and_six_session_packages_are_rejected(self) -> None:
        for count in (2, 6):
            with self.subTest(count=count):
                _, _, bars = sample(count=count)
                self.assertFalse(self.signal(bars).valid)

    def test_repeated_high_or_low_is_valid_but_flat(self) -> None:
        cases = (
            ((3, 4), (0,), 2, 1),
            ((4,), (0, 1), 1, 2),
        )
        for highs, lows, high_count, low_count in cases:
            with self.subTest(highs=highs, lows=lows):
                _, _, bars = sample(high_indices=highs, low_indices=lows)
                signal = self.signal(bars)
                self.assertTrue(signal.valid)
                self.assertEqual(signal.direction, 0)
                self.assertEqual(signal.extreme_sequence, 0)
                self.assertFalse(signal.extremes_unique)
                self.assertEqual(signal.high_occurrences, high_count)
                self.assertEqual(signal.low_occurrences, low_count)

    def test_same_session_extremes_and_close_equality_are_flat(self) -> None:
        _, _, bars = sample(high_indices=(2,), low_indices=(2,))
        signal = self.signal(bars)
        self.assertTrue(signal.valid)
        self.assertTrue(signal.extremes_unique)
        self.assertEqual(signal.extreme_sequence, 0)
        self.assertEqual(signal.direction, 0)

        _, _, bars = sample(week_close=100.0)
        signal = self.signal(bars)
        self.assertTrue(signal.valid)
        self.assertEqual(signal.extreme_sequence, 1)
        self.assertFalse(signal.settlement_agrees)
        self.assertEqual(signal.direction, 0)

    def test_both_order_settlement_disagreements_are_flat(self) -> None:
        cases = (
            ((4,), (0,), 85.0, 1),
            ((0,), (4,), 115.0, -1),
        )
        for highs, lows, close, expected_sequence in cases:
            with self.subTest(expected_sequence=expected_sequence):
                _, _, bars = sample(
                    high_indices=highs,
                    low_indices=lows,
                    week_close=close,
                )
                signal = self.signal(bars)
                self.assertTrue(signal.valid)
                self.assertEqual(signal.extreme_sequence, expected_sequence)
                self.assertFalse(signal.settlement_agrees)
                self.assertEqual(signal.direction, 0)

    def test_malformed_nonadjacent_and_current_week_history_are_rejected(self) -> None:
        _, _, bars = sample()
        broken = list(bars)
        newest = broken[0]
        broken[0] = Bar(
            newest.opened, newest.open, newest.close - 1.0, newest.low, newest.close
        )
        self.assertFalse(self.signal(broken).valid)

        broken = list(bars)
        broken[1] = Bar(
            broken[1].opened,
            broken[1].open,
            math.nan,
            broken[1].low,
            broken[1].close,
        )
        self.assertFalse(self.signal(broken).valid)

        broken = [
            Bar(
                bar.opened - timedelta(days=7) if index >= 5 else bar.opened,
                bar.open,
                bar.high,
                bar.low,
                bar.close,
            )
            for index, bar in enumerate(bars)
        ]
        self.assertFalse(self.signal(broken).valid)

        with_current = list(bars)
        with_current.insert(
            0,
            Bar(datetime(2026, 8, 24, tzinfo=UTC), 100.0, 110.0, 90.0, 101.0),
        )
        self.assertFalse(self.signal(with_current).valid)
        self.assertFalse(self.signal(bars[:5]).valid)

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
        self.assertFalse(self.signal(broken).valid)

    def test_native_and_prior_date_labels_produce_identical_signal(self) -> None:
        current, now, bars = sample()
        decision = decision_clock(current, now, bars, timedelta(0))
        self.assertEqual(decision, (True, False, 0, timedelta(0)))
        native = self.signal(bars)

        current, now, bars = sample(prior_date_labels=True)
        decision = decision_clock(current, now, bars, timedelta(days=1))
        self.assertEqual(decision, (True, False, 0, timedelta(days=1)))
        self.assertEqual(self.signal(bars, timedelta(days=1)), native)
        self.assertTrue(within_entry_grace(current, now + timedelta(minutes=180)))
        self.assertFalse(within_entry_grace(current, now + timedelta(minutes=181)))

    def test_wrong_label_and_unlocked_package_settings_fail_closed(self) -> None:
        current, now, bars = sample()
        self.assertEqual(
            decision_clock(current, now, bars, timedelta(days=1))[0:2],
            (False, False),
        )
        current, now, prior_bars = sample(prior_date_labels=True)
        self.assertEqual(
            decision_clock(current, now, prior_bars, timedelta(0))[0:2],
            (False, False),
        )
        self.assertFalse(
            extreme_sequence_signal(20260824, bars, timedelta(0), required_weeks=2).valid
        )
        self.assertFalse(
            extreme_sequence_signal(
                20260824,
                bars,
                timedelta(0),
                require_unique_extremes=False,
            ).valid
        )

    def test_late_restart_is_detected_and_attempt_is_consumed_once(self) -> None:
        _, _, bars = sample()
        bars.insert(
            0,
            Bar(datetime(2026, 8, 24, tzinfo=UTC), 100.0, 110.0, 90.0, 101.0),
        )
        current = datetime(2026, 8, 25, tzinfo=UTC)
        decision, late, count, _ = decision_clock(current, current, bars, timedelta(0))
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
        self.assertTrue(
            should_close(opened, current, opened + timedelta(days=10), timedelta(0))
        )
        self.assertTrue(should_close(None, current, current, timedelta(0)))
        self.assertTrue(should_close(opened, current, current, None))

    def test_static_build_contract_is_fixed_risk_and_completed_data_only(self) -> None:
        source = (EA_DIR / "QM5_41098_wti-wextreme-sequence-mom.mq5").read_text(
            encoding="utf-8"
        )
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41098_wti-wextreme-sequence-mom_XTIUSD.DWX_D1_backtest.set"
        ).read_text(encoding="utf-8")
        card = (EA_DIR / "docs" / "strategy_card.md").read_text(encoding="utf-8")
        for marker in (
            "input int    qm_ea_id                      = 41098;",
            "input double RISK_PERCENT                  = 0.0;",
            "input double RISK_FIXED                    = 1000.0;",
            "input double PORTFOLIO_WEIGHT              = 1.0;",
            "input int    strategy_label_offset_seconds = 86400;",
            "input int    strategy_required_weeks        = 1;",
            "input bool   strategy_require_unique_extremes = true;",
            "PERIOD_D1,\n                1,",
            "high_occurrences == 1 && low_occurrences == 1",
            "if(low_series_index > high_series_index)",
            "else if(high_series_index > low_series_index)",
            "extreme_sequence > 0 && week_close > week_open",
            "extreme_sequence < 0 && week_close < week_open",
            "QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1)",
            "req.tp = 0.0;",
            "opened_week_key != current_week_key",
        ):
            self.assertIn(marker, source)
        for forbidden in (
            "parent_high",
            "parent_low",
            "strict_inside",
            "excursion_multiplier",
            "strategy_clv_",
            "strategy_body_numerator",
            "iRSI(",
            "iMA(",
        ):
            self.assertNotIn(forbidden, source)
        self.assertEqual(source.count("QM_IsNewBar()"), 1)
        self.assertLess(
            source.index("Strategy_RecordWeekAttempt(g_decision_week_key)"),
            source.index(
                "Strategy_LoadExtremeSequenceSignal(g_decision_week_key"
            ),
        )
        for marker in (
            "environment:  backtest",
            "qm_ea_id=41098",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_label_offset_seconds=86400",
            "strategy_entry_grace_minutes=180",
            "strategy_required_weeks=1",
            "strategy_require_unique_extremes=true",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
            "strategy_max_hold_days=10",
        ):
            self.assertIn(marker, setfile)
        self.assertNotIn("T_Live", setfile)
        for marker in (
            "g0_status: APPROVED",
            "| `strategy_label_offset_seconds` | 86400 |",
            "| `strategy_required_weeks` | 1 |",
            "| `strategy_require_unique_extremes` | true |",
        ):
            self.assertIn(marker, card)


if __name__ == "__main__":
    unittest.main()
