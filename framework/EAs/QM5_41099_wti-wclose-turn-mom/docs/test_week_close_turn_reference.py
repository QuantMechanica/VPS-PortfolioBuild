"""Deterministic reference checks for QM5_41099 weekly close-turn recovery."""

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
    close: float


@dataclass(frozen=True)
class Signal:
    valid: bool = False
    direction: int = 0
    week_bars: int = 0
    first_close: float = 0.0
    turn_close: float = 0.0
    final_close: float = 0.0
    turn_index: int = -1
    transition_count: int = 0
    path_kind: int = 0
    has_equality: bool = False
    single_turn: bool = False
    full_recovery: bool = False


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


def close_valid(bar: Bar) -> bool:
    return bar.opened.timestamp() > 0 and bar.close > 0.0 and math.isfinite(bar.close)


def close_turn_signal(
    current_week_key: int,
    completed_newest_first: list[Bar],
    offset: timedelta,
    minimum: int = 3,
    maximum: int = 5,
    required_weeks: int = 1,
    require_single_turn: bool = True,
    require_full_recovery: bool = True,
) -> Signal:
    """Mirror the bounded completed-week close-path contract."""

    if (
        current_week_key <= 0
        or offset not in (timedelta(0), timedelta(days=1))
        or minimum != 3
        or maximum != 5
        or required_weeks != 1
        or not require_single_turn
        or not require_full_recovery
        or len(completed_newest_first) < minimum + 1
    ):
        return Signal()

    completed_key = 0
    last_session_date: date | None = None
    series_closes: list[float] = []
    older_boundary_seen = False
    for index, bar in enumerate(completed_newest_first):
        if not close_valid(bar):
            return Signal()
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return Signal()

        normalized = bar.opened + offset
        key = week_key(normalized)
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

        normalized_date = normalized.date()
        if last_session_date is not None and normalized_date >= last_session_date:
            return Signal()
        last_session_date = normalized_date
        if len(series_closes) >= maximum:
            return Signal()
        series_closes.append(bar.close)

    if not older_boundary_seen or not minimum <= len(series_closes) <= maximum:
        return Signal()

    closes = list(reversed(series_closes))
    first_close, final_close = closes[0], closes[-1]
    first_sign = 0
    previous_sign = 0
    transition_count = 0
    turn_index = -1
    has_equality = False
    for chrono_index, (previous, current) in enumerate(
        zip(closes, closes[1:]), start=1
    ):
        sign = 1 if current > previous else -1 if current < previous else 0
        if sign == 0:
            has_equality = True
            continue
        if first_sign == 0:
            first_sign = sign
        if previous_sign and sign != previous_sign:
            transition_count += 1
            turn_index = chrono_index - 1
        previous_sign = sign

    path_kind = 0
    if (
        not has_equality
        and transition_count == 1
        and 1 <= turn_index <= len(closes) - 2
    ):
        if first_sign < 0 < previous_sign:
            path_kind = 1
        elif first_sign > 0 > previous_sign:
            path_kind = -1
    single_turn = path_kind != 0
    turn_close = closes[turn_index] if single_turn else 0.0
    full_recovery = single_turn and (
        (path_kind > 0 and final_close > first_close)
        or (path_kind < 0 and final_close < first_close)
    )
    return Signal(
        valid=True,
        direction=path_kind if full_recovery else 0,
        week_bars=len(closes),
        first_close=first_close,
        turn_close=turn_close,
        final_close=final_close,
        turn_index=turn_index,
        transition_count=transition_count,
        path_kind=path_kind,
        has_equality=has_equality,
        single_turn=single_turn,
        full_recovery=full_recovery,
    )


def make_week(anchor: datetime, closes: list[float]) -> list[Bar]:
    return list(
        reversed(
            [Bar(anchor + timedelta(days=index), close) for index, close in enumerate(closes)]
        )
    )


def sample(
    closes: list[float],
    *,
    prior_date_labels: bool = False,
    older_anchor: datetime = datetime(2026, 8, 10, tzinfo=UTC),
) -> tuple[datetime, datetime, list[Bar]]:
    current = datetime(2026, 8, 24, tzinfo=UTC)
    now = current
    bars = make_week(datetime(2026, 8, 17, tzinfo=UTC), closes)
    bars += make_week(older_anchor, [98.0, 99.0, 101.0])
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


class WeekCloseTurnReferenceTest(unittest.TestCase):
    def signal(self, closes: list[float]) -> Signal:
        _, _, bars = sample(closes)
        return close_turn_signal(20260824, bars, timedelta(0))

    def test_strict_trough_recovery_long_and_peak_recovery_short(self) -> None:
        long_signal = self.signal([100.0, 94.0, 88.0, 102.0, 111.0])
        self.assertEqual(long_signal.direction, 1)
        self.assertEqual(long_signal.turn_index, 2)
        self.assertEqual(long_signal.turn_close, 88.0)
        self.assertEqual(long_signal.transition_count, 1)
        self.assertTrue(long_signal.single_turn)
        self.assertTrue(long_signal.full_recovery)

        short_signal = self.signal([100.0, 108.0, 114.0, 97.0, 89.0])
        self.assertEqual(short_signal.direction, -1)
        self.assertEqual(short_signal.turn_index, 2)
        self.assertEqual(short_signal.turn_close, 114.0)
        self.assertTrue(short_signal.full_recovery)

    def test_three_four_and_five_session_packages_are_accepted(self) -> None:
        paths = (
            [100.0, 90.0, 110.0],
            [100.0, 95.0, 90.0, 110.0],
            [100.0, 95.0, 90.0, 105.0, 110.0],
        )
        for expected_count, closes in zip((3, 4, 5), paths):
            with self.subTest(expected_count=expected_count):
                signal = self.signal(closes)
                self.assertTrue(signal.valid)
                self.assertEqual(signal.week_bars, expected_count)
                self.assertEqual(signal.direction, 1)

    def test_two_and_six_session_packages_are_rejected(self) -> None:
        for closes in (
            [100.0, 110.0],
            [100.0, 95.0, 90.0, 92.0, 100.0, 110.0],
        ):
            with self.subTest(count=len(closes)):
                _, _, bars = sample(closes)
                self.assertFalse(close_turn_signal(20260824, bars, timedelta(0)).valid)

    def test_equality_no_turn_and_endpoint_only_extrema_are_flat(self) -> None:
        equal = self.signal([100.0, 90.0, 90.0, 110.0])
        self.assertTrue(equal.valid)
        self.assertTrue(equal.has_equality)
        self.assertEqual(equal.direction, 0)

        for closes in (
            [100.0, 105.0, 110.0],
            [110.0, 105.0, 100.0],
        ):
            with self.subTest(closes=closes):
                signal = self.signal(closes)
                self.assertTrue(signal.valid)
                self.assertEqual(signal.transition_count, 0)
                self.assertEqual(signal.direction, 0)

    def test_multiple_turns_and_incomplete_recovery_are_flat(self) -> None:
        multiple = self.signal([100.0, 90.0, 105.0, 95.0, 110.0])
        self.assertTrue(multiple.valid)
        self.assertEqual(multiple.transition_count, 3)
        self.assertEqual(multiple.direction, 0)

        for closes in (
            [100.0, 90.0, 95.0],
            [100.0, 90.0, 100.0],
            [100.0, 110.0, 105.0],
            [100.0, 110.0, 100.0],
        ):
            with self.subTest(closes=closes):
                signal = self.signal(closes)
                self.assertTrue(signal.valid)
                self.assertTrue(signal.single_turn)
                self.assertFalse(signal.full_recovery)
                self.assertEqual(signal.direction, 0)

    def test_malformed_nonadjacent_and_current_week_history_are_rejected(self) -> None:
        _, _, bars = sample([100.0, 90.0, 110.0])
        broken = list(bars)
        broken[1] = Bar(broken[1].opened, math.nan)
        self.assertFalse(close_turn_signal(20260824, broken, timedelta(0)).valid)

        _, _, nonadjacent = sample(
            [100.0, 90.0, 110.0],
            older_anchor=datetime(2026, 8, 3, tzinfo=UTC),
        )
        self.assertFalse(close_turn_signal(20260824, nonadjacent, timedelta(0)).valid)

        with_current = list(bars)
        with_current.insert(0, Bar(datetime(2026, 8, 24, tzinfo=UTC), 111.0))
        self.assertFalse(close_turn_signal(20260824, with_current, timedelta(0)).valid)
        self.assertFalse(close_turn_signal(20260824, bars[:3], timedelta(0)).valid)

    def test_duplicate_normalized_session_date_is_rejected(self) -> None:
        _, _, bars = sample([100.0, 95.0, 90.0, 105.0, 110.0])
        broken = list(bars)
        broken[0] = Bar(datetime(2026, 8, 20, 12, tzinfo=UTC), broken[0].close)
        broken[1] = Bar(datetime(2026, 8, 20, tzinfo=UTC), broken[1].close)
        self.assertFalse(close_turn_signal(20260824, broken, timedelta(0)).valid)

    def test_native_and_prior_date_labels_produce_identical_signal(self) -> None:
        closes = [100.0, 94.0, 88.0, 102.0, 111.0]
        current, now, bars = sample(closes)
        self.assertEqual(
            decision_clock(current, now, bars, timedelta(0)),
            (True, False, 0, timedelta(0)),
        )
        native = close_turn_signal(20260824, bars, timedelta(0))

        current, now, bars = sample(closes, prior_date_labels=True)
        self.assertEqual(
            decision_clock(current, now, bars, timedelta(days=1)),
            (True, False, 0, timedelta(days=1)),
        )
        self.assertEqual(close_turn_signal(20260824, bars, timedelta(days=1)), native)
        self.assertTrue(within_entry_grace(current, now + timedelta(minutes=180)))
        self.assertFalse(within_entry_grace(current, now + timedelta(minutes=181)))

    def test_wrong_label_and_unlocked_settings_fail_closed(self) -> None:
        current, now, bars = sample([100.0, 90.0, 110.0])
        self.assertEqual(
            decision_clock(current, now, bars, timedelta(days=1))[0:2],
            (False, False),
        )
        self.assertFalse(
            close_turn_signal(
                20260824, bars, timedelta(0), require_single_turn=False
            ).valid
        )
        self.assertFalse(
            close_turn_signal(
                20260824, bars, timedelta(0), require_full_recovery=False
            ).valid
        )

    def test_late_restart_attempt_and_lifecycle_guards(self) -> None:
        _, _, bars = sample([100.0, 90.0, 110.0])
        bars.insert(0, Bar(datetime(2026, 8, 24, tzinfo=UTC), 111.0))
        current = datetime(2026, 8, 25, tzinfo=UTC)
        decision, late, count, _ = decision_clock(current, current, bars, timedelta(0))
        self.assertTrue(decision)
        self.assertTrue(late)
        self.assertEqual(count, 1)
        attempts: set[int] = set()
        self.assertTrue(consume_attempt(attempts, 20260824))
        self.assertFalse(consume_attempt(attempts, 20260824))

        self.assertEqual(week_key(datetime(2027, 1, 3, tzinfo=UTC)), 20261228)
        self.assertEqual(next_week_key(20261228), 20270104)
        opened = datetime(2026, 8, 24, 0, 1, tzinfo=UTC)
        current_bar = datetime(2026, 8, 28, tzinfo=UTC)
        self.assertFalse(should_close(opened, current_bar, current_bar, timedelta(0)))
        self.assertTrue(
            should_close(
                opened,
                datetime(2026, 8, 31, tzinfo=UTC),
                datetime(2026, 8, 31, tzinfo=UTC),
                timedelta(0),
            )
        )
        self.assertTrue(
            should_close(opened, current_bar, opened + timedelta(days=10), timedelta(0))
        )
        self.assertTrue(should_close(None, current_bar, current_bar, timedelta(0)))

    def test_static_build_contract_is_fixed_risk_and_close_only(self) -> None:
        source = (EA_DIR / "QM5_41099_wti-wclose-turn-mom.mq5").read_text(
            encoding="utf-8"
        )
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41099_wti-wclose-turn-mom_XTIUSD.DWX_D1_backtest.set"
        ).read_text(encoding="utf-8")
        card = (EA_DIR / "docs" / "strategy_card.md").read_text(encoding="utf-8")
        for marker in (
            "input int    qm_ea_id                      = 41099;",
            "input double RISK_PERCENT                  = 0.0;",
            "input double RISK_FIXED                    = 1000.0;",
            "input bool   strategy_require_single_turn    = true;",
            "input bool   strategy_require_full_recovery  = true;",
            "Strategy_LoadCloseTurnSignal",
            "if(current_close > previous_close)",
            "else if(current_close < previous_close)",
            "transition_count == 1",
            "path_kind > 0 && final_close > first_close",
            "path_kind < 0 && final_close < first_close",
            "QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1)",
            "req.tp = 0.0;",
            "opened_week_key != current_week_key",
        ):
            self.assertIn(marker, source)
        for forbidden in (
            "bars[index].open",
            "bars[index].high",
            "bars[index].low",
            "strategy_clv_",
            "excursion_multiplier",
            "iRSI(",
            "iMA(",
        ):
            self.assertNotIn(forbidden, source)
        self.assertEqual(source.count("QM_IsNewBar()"), 1)
        self.assertLess(
            source.index("Strategy_RecordWeekAttempt(g_decision_week_key)"),
            source.index("Strategy_LoadCloseTurnSignal(g_decision_week_key"),
        )
        for marker in (
            "environment:  backtest",
            "qm_ea_id=41099",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_label_offset_seconds=86400",
            "strategy_entry_grace_minutes=180",
            "strategy_required_weeks=1",
            "strategy_require_single_turn=true",
            "strategy_require_full_recovery=true",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
            "strategy_max_hold_days=10",
        ):
            self.assertIn(marker, setfile)
        self.assertNotIn("T_Live", setfile)
        for marker in (
            "g0_status: APPROVED",
            "| `strategy_label_offset_seconds` | 86400 |",
            "| `strategy_require_single_turn` | true |",
            "| `strategy_require_full_recovery` | true |",
        ):
            self.assertIn(marker, card)


if __name__ == "__main__":
    unittest.main()

