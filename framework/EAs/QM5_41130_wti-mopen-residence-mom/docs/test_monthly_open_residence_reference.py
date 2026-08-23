"""Deterministic reference checks for QM5_41130 monthly WTI open residence."""

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


def identity_holds(log_sum: float, endpoint: float, tolerance: float = 1e-10) -> bool:
    return (
        math.isfinite(log_sum)
        and math.isfinite(endpoint)
        and abs(log_sum - endpoint) <= tolerance
    )


def open_residence_signal(
    current_month_key: int,
    completed_newest_first: list[Bar],
    offset: timedelta,
    minimum: int = 17,
    maximum: int = 23,
    numerator: int = 3,
    denominator: int = 4,
    tolerance: float = 1e-10,
    history_bars: int = 45,
) -> tuple[bool, int, int, tuple[int, int, int], int, tuple[float, float, float]]:
    """Mirror fixed-anchor counts, ceiling gate, and endpoint identity."""

    empty = (False, 0, 0, (0, 0, 0), 0, (0.0, 0.0, 0.0))
    if (
        current_month_key <= 0
        or offset not in (timedelta(0), timedelta(days=1))
        or len(completed_newest_first) != history_bars
        or numerator <= 0
        or denominator <= 0
    ):
        return empty

    completed_key = 0
    last_date = None
    month_closes: list[float] = []
    boundary = 0.0
    boundary_seen = False
    for index, bar in enumerate(completed_newest_first):
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return empty
        if bar.opened.timestamp() <= 0 or bar.close <= 0.0 or not math.isfinite(bar.close):
            return empty

        normalized = bar.opened + offset
        key = month_key(normalized)
        date = normalized.date()
        if key == current_month_key:
            return empty
        if index == 0:
            completed_key = key
            if next_month_key(completed_key) != current_month_key:
                return empty

        if key == completed_key:
            if len(month_closes) >= maximum or (last_date is not None and date >= last_date):
                return empty
            month_closes.append(bar.close)
            last_date = date
            continue

        if (
            not minimum <= len(month_closes) <= maximum
            or next_month_key(key) != completed_key
        ):
            return empty
        boundary = bar.close
        boundary_seen = True
        break

    if not boundary_seen or boundary <= 0.0 or not math.isfinite(boundary):
        return empty

    sessions = len(month_closes)
    required = (numerator * sessions + denominator - 1) // denominator
    if not 0 < required <= sessions:
        return empty

    above = below = ties = 0
    previous = boundary
    log_sum = 0.0
    for current in reversed(month_closes):
        if current > boundary:
            above += 1
        elif current < boundary:
            below += 1
        else:
            ties += 1
        ratio = current / previous
        if ratio <= 0.0 or not math.isfinite(ratio):
            return empty
        log_sum += math.log(ratio)
        previous = current

    if above + below + ties != sessions:
        return empty
    final = previous
    endpoint = math.log(final / boundary)
    if not identity_holds(log_sum, endpoint, tolerance):
        return empty

    direction = 0
    if above >= required and endpoint > 0.0:
        direction = 1
    elif below >= required and endpoint < 0.0:
        direction = -1
    return (
        True,
        direction,
        sessions,
        (above, below, ties),
        required,
        (boundary, final, endpoint),
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


def qualifying_levels(count: int, direction: int) -> list[float]:
    required = (3 * count + 3) // 4
    other = count - required
    if direction > 0:
        return [99.0] * other + [101.0] * required
    return [101.0] * other + [99.0] * required


def sample(
    levels: list[float] | None = None,
    completed_month: int = 7,
    prior_date_labels: bool = False,
) -> tuple[datetime, datetime, list[Bar]]:
    month_levels = levels if levels is not None else qualifying_levels(20, 1)
    current = datetime(2026, 8, 1, tzinfo=UTC)
    now = current
    filler_count = 45 - len(month_levels)
    older_month = completed_month - 1
    bars = make_month(2026, completed_month, month_levels) + make_month(
        2026, older_month, [100.0] * filler_count
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


class MonthOpenResidenceReferenceTest(unittest.TestCase):
    def signal(self, bars: list[Bar], offset: timedelta = timedelta(0)):
        return open_residence_signal(202608, bars, offset)

    def test_exact_three_quarter_long_and_short(self) -> None:
        for direction in (1, -1):
            _, _, bars = sample(qualifying_levels(20, direction))
            valid, actual, sessions, counts, required, values = self.signal(bars)
            self.assertTrue(valid)
            self.assertEqual(actual, direction)
            self.assertEqual(sessions, 20)
            self.assertEqual(required, 15)
            self.assertEqual(counts, (15, 5, 0) if direction > 0 else (5, 15, 0))
            self.assertEqual(values[0], 100.0)
            self.assertEqual(math.copysign(1.0, values[2]), float(direction))

    def test_integer_ceiling_for_all_accepted_session_counts(self) -> None:
        for sessions, required in ((17, 13), (20, 15), (23, 18)):
            _, _, bars = sample(qualifying_levels(sessions, 1))
            result = self.signal(bars)
            self.assertTrue(result[0])
            self.assertEqual(result[1], 1)
            self.assertEqual(result[2], sessions)
            self.assertEqual(result[4], required)

    def test_one_below_required_is_flat(self) -> None:
        levels = [99.0] * 6 + [101.0] * 14
        _, _, bars = sample(levels)
        valid, direction, _, counts, required, _ = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual((direction, counts, required), (0, (14, 6, 0), 15))

    def test_ties_stay_in_denominator_and_count_to_neither_side(self) -> None:
        levels = [99.0] * 5 + [100.0] + [101.0] * 14
        _, _, bars = sample(levels)
        valid, direction, sessions, counts, required, values = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual((direction, sessions, counts, required), (0, 20, (14, 5, 1), 15))
        self.assertGreater(values[2], 0.0)

    def test_residence_endpoint_disagreement_is_flat(self) -> None:
        levels = [101.0] * 15 + [99.0] * 5
        _, _, bars = sample(levels)
        valid, direction, _, counts, required, values = self.signal(bars)
        self.assertTrue(valid)
        self.assertEqual((direction, counts, required), (0, (15, 5, 0), 15))
        self.assertLess(values[2], 0.0)

    def test_sixteen_and_twenty_four_sessions_are_rejected(self) -> None:
        for sessions in (16, 24):
            _, _, bars = sample(qualifying_levels(sessions, 1))
            self.assertFalse(self.signal(bars)[0])

    def test_malformed_nonconsecutive_and_current_month_are_rejected(self) -> None:
        _, _, bars = sample()
        broken = list(bars)
        broken[0] = Bar(broken[0].opened, 0.0)
        self.assertFalse(self.signal(broken)[0])

        _, _, bars = sample(completed_month=6)
        self.assertFalse(self.signal(bars)[0])

        _, _, bars = sample()
        broken = [Bar(datetime(2026, 8, 1, tzinfo=UTC), 101.0)] + bars[:-1]
        self.assertFalse(self.signal(broken)[0])

    def test_duplicate_normalized_session_date_is_rejected(self) -> None:
        _, _, bars = sample()
        broken = list(bars)
        broken[1] = Bar(broken[0].opened, broken[1].close)
        self.assertFalse(self.signal(broken)[0])

    def test_endpoint_identity_uses_absolute_tolerance(self) -> None:
        self.assertTrue(identity_holds(0.1, 0.1 + 1e-10))
        self.assertFalse(identity_holds(0.1, 0.1 + 1.01e-10))

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
        bars = [Bar(datetime(2026, 8, 1, tzinfo=UTC), 101.0)] + bars[:-1]
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
        self.assertTrue(should_close(opened, current, opened + timedelta(days=40), timedelta(0)))
        self.assertTrue(should_close(None, current, current, timedelta(0)))

    def test_static_build_contract_is_fixed_risk_and_completed_data_only(self) -> None:
        source = (EA_DIR / "QM5_41130_wti-mopen-residence-mom.mq5").read_text(
            encoding="utf-8"
        )
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41130_wti-mopen-residence-mom_XTIUSD.DWX_D1_backtest.set"
        ).read_text(encoding="utf-8")
        for marker in (
            "input double RISK_PERCENT                  = 0.0;",
            "input double RISK_FIXED                    = 1000.0;",
            "input double PORTFOLIO_WEIGHT              = 1.0;",
            "CopyRates(_Symbol, // perf-allowed: one bounded completed-month fixed-open scan behind a consumed monthly attempt.",
            "PERIOD_D1,\n                1,",
            "month_closes[month_sessions] = bars[index].close;",
            "boundary_close = bars[index].close;",
            "if(current_close > boundary_close)",
            "else if(current_close < boundary_close)",
            "above_count + below_count + tie_count != month_sessions",
            "strategy_residence_numerator * month_sessions +",
            "strategy_residence_denominator - 1",
            "MathLog(close_ratio)",
            "MathAbs(net_return - endpoint_return) > strategy_numerical_tolerance",
            "above_count >= required_residence && endpoint_return > 0.0",
            "below_count >= required_residence && endpoint_return < 0.0",
            "QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1)",
            "req.tp = 0.0;",
            "opened_month_key != current_month_key",
        ):
            self.assertIn(marker, source)
        for banned in ("iRSI(", "iMACD(", "iBands(", "WebRequest("):
            self.assertNotIn(banned, source)
        self.assertLess(
            source.index("Strategy_RecordMonthAttempt(g_decision_month_key)"),
            source.index("Strategy_LoadOpenResidenceSignal(g_decision_month_key"),
        )
        for marker in (
            "qm_ea_id=41130",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_news_temporal=0",
            "qm_news_compliance=0",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=45",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_residence_numerator=3",
            "strategy_residence_denominator=4",
            "strategy_numerical_tolerance=0.0000000001",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
            "strategy_deviation_points=20",
        ):
            self.assertIn(marker, setfile)

        approved_card = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41130_wti-mopen-residence-mom_card.md"
        )
        local_card = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local_card.read_bytes(), approved_card.read_bytes())


if __name__ == "__main__":
    unittest.main()
