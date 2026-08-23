"""Deterministic reference checks for QM5_41122 WTI extreme sequence."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass, replace
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]


@dataclass(frozen=True)
class Bar:
    opened: datetime
    open: float
    high: float
    low: float
    close: float


def month_key(value: datetime) -> int:
    return value.year * 100 + value.month


def next_month_key(value: int) -> int:
    year, month = divmod(value, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    if month == 12:
        return (year + 1) * 100 + 1
    return year * 100 + month + 1


def within_entry_grace(
    current_bar: datetime, now: datetime, grace_minutes: int = 180
) -> bool:
    if current_bar.timestamp() <= 0 or now < current_bar:
        return False
    return now - current_bar <= timedelta(minutes=grace_minutes)


def decision_clock(
    current_bar: datetime,
    now: datetime,
    completed_newest_first: list[Bar],
) -> tuple[bool, bool, int]:
    if (
        current_bar.timestamp() <= 0
        or now < current_bar
        or current_bar.date() != now.date()
        or month_key(current_bar) != month_key(now)
    ):
        return False, False, 0
    current_key = month_key(current_bar)
    current_count = 0
    while (
        current_count < len(completed_newest_first)
        and month_key(completed_newest_first[current_count].opened) == current_key
    ):
        current_count += 1
    if current_count >= len(completed_newest_first):
        return False, False, current_count
    prior_key = month_key(completed_newest_first[current_count].opened)
    if next_month_key(prior_key) != current_key:
        return False, False, current_count
    late = current_count > 0 or not within_entry_grace(current_bar, now)
    return True, late, current_count


def bar_valid(bar: Bar) -> bool:
    values = (bar.open, bar.high, bar.low, bar.close)
    return (
        bar.opened.timestamp() > 0
        and all(value > 0.0 and math.isfinite(value) for value in values)
        and bar.high >= max(bar.open, bar.low, bar.close)
        and bar.low <= min(bar.open, bar.high, bar.close)
    )


def extreme_sequence_signal(
    current_month_key: int,
    completed_newest_first: list[Bar],
    minimum: int = 17,
    maximum: int = 23,
) -> tuple[bool, int, int, int, int, int, tuple[float, float, float, float]]:
    """Mirror the bounded month reconstruction and exact signal contract."""

    empty = (False, 0, 0, -1, -1, 0, (0.0, 0.0, 0.0, 0.0))
    if current_month_key <= 0 or len(completed_newest_first) < minimum + 1:
        return empty

    completed: list[Bar] = []
    prior_month_key = 0
    last_date = None
    older_boundary_seen = False
    for index, bar in enumerate(completed_newest_first):
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return empty
        key = month_key(bar.opened)
        if key <= 0 or key == current_month_key:
            return empty
        if prior_month_key == 0:
            if next_month_key(key) != current_month_key:
                return empty
            prior_month_key = key
        if key != prior_month_key:
            if next_month_key(key) != prior_month_key:
                return empty
            older_boundary_seen = True
            break
        if last_date is not None and bar.opened.date() >= last_date:
            return empty
        last_date = bar.opened.date()
        if len(completed) >= maximum or not bar_valid(bar):
            return empty
        completed.append(bar)

    count = len(completed)
    if not older_boundary_seen or not minimum <= count <= maximum:
        return empty

    chronological = list(reversed(completed))
    month_open = chronological[0].open
    month_close = chronological[-1].close
    month_high = max(bar.high for bar in chronological)
    month_low = min(bar.low for bar in chronological)
    values = (month_open, month_high, month_low, month_close)
    if (
        not all(math.isfinite(value) for value in values)
        or month_high <= month_low
        or not month_low <= month_open <= month_high
        or not month_low <= month_close <= month_high
    ):
        return empty

    high_indices = [
        index for index, bar in enumerate(chronological) if bar.high == month_high
    ]
    low_indices = [
        index for index, bar in enumerate(chronological) if bar.low == month_low
    ]
    high_index = high_indices[-1]
    low_index = low_indices[-1]
    direction = 0
    if len(high_indices) == len(low_indices) == 1 and high_index != low_index:
        if low_index < high_index and month_close > month_open:
            direction = 1
        elif high_index < low_index and month_close < month_open:
            direction = -1
    return (
        True,
        direction,
        count,
        high_index,
        low_index,
        len(high_indices) * 10 + len(low_indices),
        values,
    )


def make_month(
    count: int = 20,
    high_index: int | None = None,
    low_index: int | None = None,
    body: int = 1,
) -> list[Bar]:
    high_at = count - 1 if high_index is None else high_index
    low_at = 0 if low_index is None else low_index
    bars: list[Bar] = []
    for index in range(count):
        opened = 100.0
        closed = 100.0
        if index == 0:
            opened = 100.0 if body >= 0 else 101.0
        if index == count - 1:
            closed = 101.0 if body > 0 else (100.0 if body < 0 else 100.0)
        bars.append(
            Bar(
                datetime(2026, 7, index + 1, tzinfo=UTC),
                opened,
                110.0 if index == high_at else 104.0,
                90.0 if index == low_at else 96.0,
                closed,
            )
        )
    if body == 0:
        bars[-1] = replace(bars[-1], close=bars[0].open)
    return list(reversed(bars))


def with_boundary(bars: list[Bar]) -> list[Bar]:
    return bars + [Bar(datetime(2026, 6, 30, tzinfo=UTC), 99, 100, 98, 99)]


def consume_attempt(attempts: set[int], current_month_key: int) -> bool:
    if current_month_key in attempts:
        return False
    attempts.add(current_month_key)
    return True


def should_close(opened: datetime | None, now: datetime, max_days: int = 40) -> bool:
    if opened is None or opened > now:
        return True
    return month_key(opened) != month_key(now) or now - opened >= timedelta(days=max_days)


class MonthlyExtremeSequenceReferenceTest(unittest.TestCase):
    def signal(self, bars: list[Bar]):
        return extreme_sequence_signal(202608, bars)

    def test_unique_low_before_high_and_positive_body_buys(self) -> None:
        valid, direction, count, high_index, low_index, occurrences, values = self.signal(
            with_boundary(make_month())
        )
        self.assertTrue(valid)
        self.assertEqual((direction, count, high_index, low_index), (1, 20, 19, 0))
        self.assertEqual(occurrences, 11)
        self.assertGreater(values[3], values[0])

    def test_unique_high_before_low_and_negative_body_sells(self) -> None:
        result = self.signal(
            with_boundary(make_month(high_index=0, low_index=19, body=-1))
        )
        self.assertEqual(result[:6], (True, -1, 20, 0, 19, 11))
        self.assertLess(result[6][3], result[6][0])

    def test_seventeen_twenty_and_twenty_three_sessions_are_accepted(self) -> None:
        for count in (17, 20, 23):
            result = self.signal(with_boundary(make_month(count=count)))
            self.assertEqual(result[:3], (True, 1, count))

    def test_sixteen_and_twenty_four_sessions_are_rejected(self) -> None:
        for count in (16, 24):
            self.assertFalse(self.signal(with_boundary(make_month(count=count)))[0])

    def test_repeated_high_and_repeated_low_are_valid_flat_states(self) -> None:
        bars = make_month()
        bars[1] = replace(bars[1], high=110.0)
        result = self.signal(with_boundary(bars))
        self.assertTrue(result[0])
        self.assertEqual((result[1], result[5]), (0, 21))

        bars = make_month()
        bars[-2] = replace(bars[-2], low=90.0)
        result = self.signal(with_boundary(bars))
        self.assertTrue(result[0])
        self.assertEqual((result[1], result[5]), (0, 12))

    def test_same_session_equality_and_disagreement_are_flat(self) -> None:
        result = self.signal(
            with_boundary(make_month(high_index=5, low_index=5, body=1))
        )
        self.assertEqual((result[0], result[1], result[3], result[4]), (True, 0, 5, 5))

        result = self.signal(with_boundary(make_month(body=0)))
        self.assertEqual(result[:2], (True, 0))
        self.assertEqual(result[6][0], result[6][3])

        result = self.signal(
            with_boundary(make_month(high_index=0, low_index=19, body=1))
        )
        self.assertEqual(result[:2], (True, 0))
        result = self.signal(
            with_boundary(make_month(high_index=19, low_index=0, body=-1))
        )
        self.assertEqual(result[:2], (True, 0))

    def test_malformed_current_month_unsorted_and_truncated_are_rejected(self) -> None:
        bars = with_boundary(make_month())
        bars[0] = replace(bars[0], high=99.0, low=101.0)
        self.assertFalse(self.signal(bars)[0])

        bars = with_boundary(make_month())
        bars.insert(0, Bar(datetime(2026, 8, 1, tzinfo=UTC), 100, 101, 99, 100))
        self.assertFalse(self.signal(bars)[0])

        bars = with_boundary(make_month())
        bars[1] = replace(bars[1], opened=bars[0].opened)
        self.assertFalse(self.signal(bars)[0])

        self.assertFalse(self.signal(make_month())[0])

    def test_month_clock_attempt_and_lifecycle_boundaries(self) -> None:
        self.assertEqual(next_month_key(202612), 202701)
        current = datetime(2026, 8, 1, tzinfo=UTC)
        prior = with_boundary(make_month())
        self.assertEqual(
            decision_clock(current, current + timedelta(minutes=180), prior),
            (True, False, 0),
        )
        self.assertEqual(
            decision_clock(current, current + timedelta(minutes=181), prior),
            (True, True, 0),
        )
        later_bar = datetime(2026, 8, 2, tzinfo=UTC)
        current_month_history = [
            Bar(datetime(2026, 8, 1, tzinfo=UTC), 100, 101, 99, 100)
        ] + prior
        self.assertEqual(
            decision_clock(later_bar, later_bar, current_month_history),
            (True, True, 1),
        )

        attempts: set[int] = set()
        self.assertTrue(consume_attempt(attempts, 202608))
        self.assertFalse(consume_attempt(attempts, 202608))

        opened = datetime(2026, 8, 1, tzinfo=UTC)
        self.assertFalse(should_close(opened, datetime(2026, 8, 31, tzinfo=UTC)))
        self.assertTrue(should_close(opened, datetime(2026, 9, 1, tzinfo=UTC)))
        self.assertTrue(should_close(opened, opened + timedelta(days=40)))
        self.assertTrue(should_close(None, opened))

    def test_static_source_contract_matches_the_card(self) -> None:
        source = (EA_DIR / "QM5_41122_wti-mextreme-sequence-mom.mq5").read_text(
            encoding="utf-8"
        )
        for marker in (
            "input double RISK_PERCENT                  = 0.0;",
            "input double RISK_FIXED                    = 1000.0;",
            "CopyRates(_Symbol, // perf-allowed: bounded completed-month extreme-sequence scan behind the sole QM_IsNewBar branch.",
            "strategy_require_unique_extremes",
            "month_open = completed[completed_month_bars - 1].open;",
            "month_close = completed[0].close;",
            "if(low_index < high_index && month_close > month_open)",
            "else if(high_index < low_index && month_close < month_open)",
            "Strategy_RecordMonthAttempt(g_decision_month_key)",
            "QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1)",
            "req.tp = 0.0;",
            "opened_month_key != current_month_key",
        ):
            self.assertIn(marker, source)
        for banned in ("iRSI(", "iMACD(", "iBands(", "WebRequest("):
            self.assertNotIn(banned, source)
        self.assertLess(
            source.index("Strategy_RecordMonthAttempt(g_decision_month_key)"),
            source.index("Strategy_LoadExtremeSequenceSignal(g_decision_month_key"),
        )

    def test_setfile_and_card_copy_contract(self) -> None:
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41122_wti-mextreme-sequence-mom_XTIUSD.DWX_D1_backtest.set"
        ).read_text(encoding="utf-8")
        for marker in (
            "qm_ea_id=41122",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=45",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_require_unique_extremes=true",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
        ):
            self.assertIn(marker, setfile)

        approved_card = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41122_wti-mextreme-sequence-mom_card.md"
        )
        local_card = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local_card.read_bytes(), approved_card.read_bytes())


if __name__ == "__main__":
    unittest.main()
