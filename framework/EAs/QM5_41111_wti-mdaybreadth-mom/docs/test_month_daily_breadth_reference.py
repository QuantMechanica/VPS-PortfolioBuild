"""Deterministic reference checks for QM5_41111 monthly WTI daily-sign breadth."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]


@dataclass(frozen=True)
class Bar:
    opened: datetime
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


def daily_breadth_signal(
    current_month_key: int,
    completed_newest_first: list[Bar],
    offset: timedelta,
    minimum: int = 17,
    maximum: int = 23,
) -> tuple[bool, int, tuple[int, int], tuple[int, int, int], tuple[float, float, float]]:
    """Mirror month reconstruction, sign counts, and strict endpoint agreement."""

    empty = (False, 0, (0, 0), (0, 0, 0), (0.0, 0.0, 0.0))
    if current_month_key <= 0 or offset not in (timedelta(0), timedelta(days=1)):
        return empty
    if len(completed_newest_first) < minimum * 2 + 1:
        return empty

    keys: list[int] = []
    buckets: list[list[Bar]] = []
    last_session_dates: list[datetime.date | None] = []
    parent_boundary_seen = False
    for index, bar in enumerate(completed_newest_first):
        if bar.opened.timestamp() <= 0:
            return empty
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return empty
        if bar.close <= 0.0 or not math.isfinite(bar.close):
            return empty

        normalized = bar.opened + offset
        key = month_key(normalized)
        if key == current_month_key:
            return empty
        if not keys or key != keys[-1]:
            if len(keys) >= 2:
                if next_month_key(key) != keys[1]:
                    return empty
                parent_boundary_seen = True
                break
            if not keys:
                if next_month_key(key) != current_month_key:
                    return empty
            elif next_month_key(key) != keys[-1]:
                return empty
            keys.append(key)
            buckets.append([])
            last_session_dates.append(None)

        normalized_date = normalized.date()
        if (
            last_session_dates[-1] is not None
            and normalized_date >= last_session_dates[-1]
        ):
            return empty
        last_session_dates[-1] = normalized_date
        buckets[-1].append(bar)
        if len(buckets[-1]) > maximum:
            return empty

    if len(keys) != 2 or not parent_boundary_seen:
        return empty
    if any(not minimum <= len(bucket) <= maximum for bucket in buckets):
        return empty

    parent_final = buckets[1][0].close
    newest_chronological = list(reversed(buckets[0]))
    previous = parent_final
    up = down = flat = 0
    for bar in newest_chronological:
        if bar.close > previous:
            up += 1
        elif bar.close < previous:
            down += 1
        else:
            flat += 1
        previous = bar.close
    if up + down + flat != len(newest_chronological):
        return empty

    newest_final = previous
    net_return = newest_final / parent_final - 1.0
    if not math.isfinite(net_return):
        return empty
    direction = 0
    if 2 * up > len(newest_chronological) and net_return > 0.0:
        direction = 1
    elif 2 * down > len(newest_chronological) and net_return < 0.0:
        direction = -1
    return (
        True,
        direction,
        (len(buckets[0]), len(buckets[1])),
        (up, down, flat),
        (parent_final, newest_final, net_return),
    )


def make_month(year: int, month: int, closes: list[float]) -> list[Bar]:
    return list(
        reversed(
            [
                Bar(datetime(year, month, index + 1, tzinfo=UTC), close)
                for index, close in enumerate(closes)
            ]
        )
    )


def closes_from_deltas(anchor: float, deltas: list[float]) -> list[float]:
    closes: list[float] = []
    value = anchor
    for delta in deltas:
        value += delta
        closes.append(value)
    return closes


def majority_deltas(count: int, direction: int = 1) -> list[float]:
    directional = count // 2 + 1
    other = count - directional
    if direction > 0:
        return [1.0] * directional + [-0.2] * other
    return [-1.0] * directional + [0.2] * other


def sample(
    new_deltas: list[float] | None = None,
    parent_count: int = 20,
    parent_month: int = 6,
    prior_date_labels: bool = False,
) -> tuple[datetime, datetime, list[Bar]]:
    deltas = new_deltas if new_deltas is not None else majority_deltas(20)
    parent = [100.0] * parent_count
    newest = closes_from_deltas(parent[-1], deltas)
    current = datetime(2026, 8, 1, tzinfo=UTC)
    now = current
    bars = (
        make_month(2026, 7, newest)
        + make_month(2026, parent_month, parent)
        + make_month(2026, parent_month - 1, [99.0])
    )
    if prior_date_labels:
        current -= timedelta(days=1)
        bars = [Bar(bar.opened - timedelta(days=1), bar.close) for bar in bars]
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


class MonthDailyBreadthReferenceTest(unittest.TestCase):
    def signal(self, bars: list[Bar], offset: timedelta = timedelta(0)):
        return daily_breadth_signal(202608, bars, offset)

    def test_strict_long_and_short_paths(self) -> None:
        _, _, bars = sample(majority_deltas(20, 1))
        valid, direction, counts, signs, values = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertEqual(counts, (20, 20))
        self.assertEqual(signs, (11, 9, 0))
        self.assertEqual(values[0], 100.0)
        self.assertGreater(values[1], values[0])
        self.assertGreater(values[2], 0.0)

        _, _, bars = sample(majority_deltas(20, -1))
        valid, direction, _, signs, values = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertEqual(signs, (9, 11, 0))
        self.assertLess(values[1], values[0])
        self.assertLess(values[2], 0.0)

    def test_seventeen_twenty_and_twenty_three_sessions_are_accepted(self) -> None:
        for new_count in (17, 20, 23):
            for parent_count in (17, 20, 23):
                _, _, bars = sample(
                    majority_deltas(new_count), parent_count=parent_count
                )
                valid, direction, counts, _, _ = self.signal(bars)
                self.assertTrue(valid)
                self.assertEqual(direction, 1)
                self.assertEqual(counts, (new_count, parent_count))

    def test_sixteen_and_twenty_four_sessions_are_rejected(self) -> None:
        for new_count, parent_count in ((16, 20), (20, 16), (24, 20), (20, 24)):
            _, _, bars = sample(
                majority_deltas(new_count), parent_count=parent_count
            )
            self.assertFalse(self.signal(bars)[0])

    def test_tie_and_nonmajority_are_flat_despite_positive_endpoint(self) -> None:
        deltas = [1.0] * 10 + [-0.5] * 10
        _, _, bars = sample(deltas)
        valid, direction, _, signs, values = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertEqual(signs, (10, 10, 0))
        self.assertGreater(values[2], 0.0)

    def test_flat_observation_stays_in_majority_denominator(self) -> None:
        deltas = [1.0] * 10 + [-0.5] * 9 + [0.0]
        _, _, bars = sample(deltas)
        valid, direction, _, signs, values = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertEqual(signs, (10, 9, 1))
        self.assertGreater(values[2], 0.0)

    def test_breadth_endpoint_disagreement_is_flat(self) -> None:
        deltas = [0.1] * 11 + [-1.0] * 9
        _, _, bars = sample(deltas)
        valid, direction, _, signs, values = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertEqual(signs, (11, 9, 0))
        self.assertLess(values[2], 0.0)

    def test_endpoint_equality_is_flat(self) -> None:
        deltas = [1.0] * 11 + [-1.0] * 8 + [-3.0]
        _, _, bars = sample(deltas)
        valid, direction, _, signs, values = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertEqual(signs, (11, 9, 0))
        self.assertAlmostEqual(values[2], 0.0, places=12)

    def test_malformed_nonconsecutive_and_current_month_are_rejected(self) -> None:
        _, _, bars = sample()
        broken = list(bars)
        broken[0] = Bar(broken[0].opened, 0.0)
        self.assertFalse(self.signal(broken)[0])

        _, _, bars = sample(parent_month=5)
        self.assertFalse(self.signal(bars)[0])

        _, _, bars = sample()
        bars.insert(0, Bar(datetime(2026, 8, 1, tzinfo=UTC), 118.5))
        self.assertFalse(self.signal(bars)[0])

    def test_duplicate_normalized_session_date_is_rejected(self) -> None:
        _, _, bars = sample()
        broken = list(bars)
        newest = broken[0]
        second = broken[1]
        broken[0] = Bar(newest.opened + timedelta(hours=12), newest.close)
        broken[1] = Bar(newest.opened, second.close)
        self.assertFalse(self.signal(broken)[0])

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

    def test_late_restart_consumes_month_once(self) -> None:
        _, _, bars = sample()
        bars.insert(0, Bar(datetime(2026, 8, 1, tzinfo=UTC), 118.5))
        current = datetime(2026, 8, 2, tzinfo=UTC)
        decision, late, count, _ = decision_clock(current, current, bars)
        self.assertTrue(decision)
        self.assertTrue(late)
        self.assertEqual(count, 1)
        attempts: set[int] = set()
        self.assertTrue(consume_attempt(attempts, 202608))
        self.assertFalse(consume_attempt(attempts, 202608))

    def test_year_boundary_and_lifecycle_guards(self) -> None:
        self.assertEqual(next_month_key(202612), 202701)
        opened = datetime(2026, 8, 1, 0, 1, tzinfo=UTC)
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
        source = (EA_DIR / "QM5_41111_wti-mdaybreadth-mom.mq5").read_text(
            encoding="utf-8"
        )
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41111_wti-mdaybreadth-mom_XTIUSD.DWX_D1_backtest.set"
        ).read_text(encoding="utf-8")
        for marker in (
            "input double RISK_PERCENT                  = 0.0;",
            "input double RISK_FIXED                    = 1000.0;",
            "input double PORTFOLIO_WEIGHT              = 1.0;",
            "CopyRates(_Symbol, // perf-allowed: bounded completed-month daily-sign scan behind the sole QM_IsNewBar branch.",
            "PERIOD_D1,\n                1,",
            "session_date_key >= month_last_date_keys[bucket]",
            "newest_closes[month_counts[bucket]] = bars[index].close;",
            "parent_final_close = bars[index].close;",
            "if(current_close > previous_close)",
            "else if(current_close < previous_close)",
            "up_count + down_count + flat_count != new_month_bars",
            "2 * up_count > new_month_bars && net_return > 0.0",
            "2 * down_count > new_month_bars && net_return < 0.0",
            "QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1)",
            "req.tp = 0.0;",
            "opened_month_key != current_month_key",
        ):
            self.assertIn(marker, source)
        for banned in ("iRSI(", "iMACD(", "iBands(", "MathLog(", "WebRequest("):
            self.assertNotIn(banned, source)
        self.assertLess(
            source.index("Strategy_RecordMonthAttempt(g_decision_month_key)"),
            source.index("Strategy_LoadDailyBreadthSignal(g_decision_month_key"),
        )
        for marker in (
            "qm_ea_id=41111",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=70",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
        ):
            self.assertIn(marker, setfile)

        approved_card = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41111_wti-mdaybreadth-mom_card.md"
        )
        local_card = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local_card.read_bytes(), approved_card.read_bytes())


if __name__ == "__main__":
    unittest.main()
