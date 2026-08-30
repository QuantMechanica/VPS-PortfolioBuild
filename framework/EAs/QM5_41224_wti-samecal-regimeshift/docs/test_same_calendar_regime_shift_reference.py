"""Independent deterministic fixtures for QM5_41224.

The suite covers normalized D1 labels, completed WTI month endpoints, exact
mandatory Y-1..Y-10 sampling, chronological five/five arithmetic, strict
opposite-sign direction, durable monthly attempts, lifecycle, quote/grace
gates, and static card/build conformance. It does not invoke MT5.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest
from dataclasses import dataclass
from pathlib import Path


DAY = dt.timedelta(days=1)
BLOCK_YEARS = 5
HISTORY_YEARS = 10
EPSILON = 1.0e-12
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]


@dataclass(frozen=True)
class Bar:
    label: dt.datetime
    close: float


@dataclass(frozen=True)
class RegimeShiftResult:
    sample_count: int
    recent_sum: float
    older_sum: float
    recent_mean: float
    older_mean: float
    direction: int


def date_key(value: dt.datetime) -> int:
    return value.year * 10000 + value.month * 100 + value.day


def normalized_sessions(
    current_label: dt.datetime,
    previous_label: dt.datetime,
    broker_now: dt.datetime,
) -> tuple[dt.datetime, dt.datetime, int] | None:
    if date_key(current_label) == date_key(broker_now):
        offset = 0
    elif date_key(current_label + DAY) == date_key(broker_now):
        offset = 1
    else:
        return None
    current = current_label + offset * DAY
    previous = previous_label + offset * DAY
    if current <= previous or date_key(current) != date_key(broker_now):
        return None
    return current, previous, offset


def month_ordinal(value: dt.datetime) -> int:
    return value.year * 12 + value.month


def completed_month_return(
    bars: tuple[Bar, ...],
    target_year: int,
    target_month: int,
    label_offset_days: int,
) -> float | None:
    if label_offset_days not in (0, 1) or len(bars) < 3:
        return None
    normalized = tuple(
        Bar(bar.label + label_offset_days * DAY, bar.close) for bar in bars
    )
    if any(
        normalized[index].label <= normalized[index - 1].label
        for index in range(1, len(normalized))
    ):
        return None
    indices = [
        index
        for index, bar in enumerate(normalized)
        if (bar.label.year, bar.label.month) == (target_year, target_month)
    ]
    if not indices:
        return None
    first, last = indices[0], indices[-1]
    if first <= 0 or last + 1 >= len(normalized):
        return None
    if indices != list(range(first, last + 1)):
        return None
    target_ordinal = target_year * 12 + target_month
    if month_ordinal(normalized[first - 1].label) != target_ordinal - 1:
        return None
    if month_ordinal(normalized[last + 1].label) != target_ordinal + 1:
        return None
    prior_close = normalized[first - 1].close
    month_end_close = normalized[last].close
    if not all(
        math.isfinite(value) and value > 0.0
        for value in (prior_close, month_end_close)
    ):
        return None
    return math.log(month_end_close / prior_close)


def exact_prior_sample(
    observations: dict[tuple[int, int], float],
    decision_year: int,
    decision_month: int,
) -> list[float] | None:
    sample: list[float] = []
    for lag in range(1, HISTORY_YEARS + 1):
        value = observations.get((decision_year - lag, decision_month))
        if value is None or not math.isfinite(value):
            return None
        sample.append(value)
    return sample if len(sample) == HISTORY_YEARS else None


def regime_shift_signal(
    observations: list[float],
) -> RegimeShiftResult | None:
    if len(observations) != HISTORY_YEARS:
        return None
    if any(not math.isfinite(value) for value in observations):
        return None
    recent_sum = sum(observations[:BLOCK_YEARS])
    older_sum = sum(observations[BLOCK_YEARS:])
    if not all(math.isfinite(value) for value in (recent_sum, older_sum)):
        return None
    recent_mean = recent_sum / BLOCK_YEARS
    older_mean = older_sum / BLOCK_YEARS
    if not all(math.isfinite(value) for value in (recent_mean, older_mean)):
        return None
    if recent_mean > EPSILON and older_mean < -EPSILON:
        direction = 1
    elif recent_mean < -EPSILON and older_mean > EPSILON:
        direction = -1
    else:
        direction = 0
    return RegimeShiftResult(
        len(observations),
        recent_sum,
        older_sum,
        recent_mean,
        older_mean,
        direction,
    )


def quote_allows(
    bid: float,
    ask: float,
    point: float,
    maximum_spread_points: int = 1500,
) -> bool:
    if not all(
        math.isfinite(value) and value > 0.0 for value in (bid, ask, point)
    ):
        return False
    if ask < bid:
        return False
    modeled_spread = (ask - bid) / point
    return (
        math.isfinite(modeled_spread)
        and 0.0 <= modeled_spread <= maximum_spread_points
    )


def grace_allows(
    normalized_decision: dt.datetime,
    broker_now: dt.datetime,
    minutes: int = 180,
) -> bool:
    elapsed = (broker_now - normalized_decision).total_seconds()
    return 0 <= elapsed <= minutes * 60


class AttemptLedger:
    def __init__(self, storage: dict[str, int], key: str = "attempt") -> None:
        self.storage = storage
        self.key = key

    def consume_before(self, month: int, downstream_gate: bool) -> bool:
        if self.storage.get(self.key, 0) >= month:
            return False
        self.storage[self.key] = month
        return downstream_gate


def stale_exit_due(opened: dt.datetime, current: dt.datetime) -> bool:
    return current >= opened + 40 * DAY


def exit_due(opened: dt.datetime, current: dt.datetime) -> bool:
    crossed_month = (opened.year, opened.month) != (
        current.year,
        current.month,
    )
    return crossed_month or stale_exit_due(opened, current)


class SameCalendarRegimeShiftReferenceTests(unittest.TestCase):
    def test_native_prior_day_and_year_roll_labels(self) -> None:
        native = normalized_sessions(
            dt.datetime(2026, 8, 3),
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 8, 3, 1),
        )
        prior_day_year_roll = normalized_sessions(
            dt.datetime(2025, 12, 31),
            dt.datetime(2025, 12, 30),
            dt.datetime(2026, 1, 1, 1),
        )
        self.assertIsNotNone(native)
        self.assertIsNotNone(prior_day_year_roll)
        assert native is not None and prior_day_year_roll is not None
        self.assertEqual(native[2], 0)
        self.assertEqual(prior_day_year_roll[2], 1)
        self.assertNotEqual(
            (native[0].year, native[0].month),
            (native[1].year, native[1].month),
        )
        self.assertNotEqual(
            (
                prior_day_year_roll[0].year,
                prior_day_year_roll[0].month,
            ),
            (
                prior_day_year_roll[1].year,
                prior_day_year_roll[1].month,
            ),
        )
        self.assertIsNone(
            normalized_sessions(
                dt.datetime(2026, 7, 29),
                dt.datetime(2026, 7, 28),
                dt.datetime(2026, 8, 1, 1),
            )
        )

    def test_completed_month_uses_prior_close_and_confirmation(self) -> None:
        bars = (
            Bar(dt.datetime(2025, 12, 30), 90.0),
            Bar(dt.datetime(2025, 12, 31), 92.0),
            Bar(dt.datetime(2026, 1, 30), 99.0),
            Bar(dt.datetime(2026, 1, 31), 101.0),
        )
        observed = completed_month_return(bars, 2026, 1, 1)
        self.assertIsNotNone(observed)
        self.assertAlmostEqual(observed or 0.0, math.log(99.0 / 90.0))
        self.assertIsNone(completed_month_return(bars[:-1], 2026, 1, 1))
        malformed = (bars[0], bars[2], bars[1], bars[3])
        self.assertIsNone(completed_month_return(malformed, 2026, 1, 1))

    def test_exact_prior_sample_requires_all_ten_in_order(self) -> None:
        observations = {
            (2026 - lag, 1): lag / 100.0
            for lag in range(1, HISTORY_YEARS + 2)
        }
        sample = exact_prior_sample(observations, 2026, 1)
        self.assertEqual(
            sample,
            [lag / 100.0 for lag in range(1, HISTORY_YEARS + 1)],
        )
        missing = observations.copy()
        del missing[(2023, 1)]
        self.assertIsNone(exact_prior_sample(missing, 2026, 1))
        nonfinite = observations.copy()
        nonfinite[(2021, 1)] = math.nan
        self.assertIsNone(exact_prior_sample(nonfinite, 2026, 1))

    def test_buy_and_sell_follow_recent_block(self) -> None:
        buy = regime_shift_signal([0.01] * 5 + [-0.03] * 5)
        sell = regime_shift_signal([-0.02] * 5 + [0.04] * 5)
        self.assertIsNotNone(buy)
        self.assertIsNotNone(sell)
        assert buy is not None and sell is not None
        self.assertEqual(buy.sample_count, 10)
        self.assertAlmostEqual(buy.recent_sum, 0.05)
        self.assertAlmostEqual(buy.older_sum, -0.15)
        self.assertAlmostEqual(buy.recent_mean, 0.01)
        self.assertAlmostEqual(buy.older_mean, -0.03)
        self.assertEqual(buy.direction, 1)
        self.assertEqual(sell.direction, -1)

    def test_stable_sign_zero_and_epsilon_ties_are_flat(self) -> None:
        for values in (
            [0.01] * 10,
            [-0.01] * 10,
            [0.0] * 10,
            [EPSILON] * 5 + [-0.01] * 5,
            [0.01] * 5 + [-EPSILON] * 5,
        ):
            result = regime_shift_signal(values)
            self.assertIsNotNone(result)
            self.assertEqual(result.direction if result else 9, 0)
        beyond = regime_shift_signal(
            [EPSILON + 1.0e-15] * 5 + [-0.01] * 5
        )
        self.assertEqual(beyond.direction if beyond else 0, 1)

    def test_raw_mean_disagreement_is_opposite_side(self) -> None:
        values = [0.01] * 5 + [-0.03] * 5
        result = regime_shift_signal(values)
        self.assertLess(sum(values) / len(values), 0.0)
        self.assertEqual(result.direction if result else 0, 1)

    def test_incomplete_and_nonfinite_samples_fail_closed(self) -> None:
        self.assertIsNone(regime_shift_signal([0.01] * 9))
        self.assertIsNone(regime_shift_signal([0.01] * 11))
        invalid = [0.01] * 10
        invalid[7] = math.inf
        self.assertIsNone(regime_shift_signal(invalid))

    def test_attempt_consumes_before_failure_and_survives_restart(self) -> None:
        storage: dict[str, int] = {}
        first = AttemptLedger(storage)
        self.assertFalse(first.consume_before(202608, downstream_gate=False))
        self.assertFalse(first.consume_before(202608, downstream_gate=True))
        restarted = AttemptLedger(storage)
        self.assertFalse(restarted.consume_before(202608, downstream_gate=True))
        self.assertTrue(restarted.consume_before(202609, downstream_gate=True))

    def test_grace_and_quote_boundaries(self) -> None:
        opened = dt.datetime(2026, 8, 3)
        self.assertTrue(grace_allows(opened, opened))
        self.assertTrue(grace_allows(opened, opened + dt.timedelta(minutes=180)))
        self.assertFalse(
            grace_allows(
                opened,
                opened + dt.timedelta(minutes=180, seconds=1),
            )
        )
        self.assertTrue(quote_allows(70.0, 70.0, 0.01))
        self.assertTrue(quote_allows(70.0, 85.0, 0.01))
        self.assertFalse(quote_allows(70.0, 85.01, 0.01))
        self.assertFalse(quote_allows(70.01, 70.0, 0.01))

    def test_next_month_and_exact_forty_day_stale_exit(self) -> None:
        opened = dt.datetime(2026, 1, 3)
        self.assertFalse(stale_exit_due(opened, opened + 39 * DAY))
        self.assertTrue(stale_exit_due(opened, opened + 40 * DAY))
        month_end_open = dt.datetime(2026, 1, 30)
        self.assertTrue(exit_due(month_end_open, dt.datetime(2026, 2, 2)))

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (
            EA_DIR / "QM5_41224_wti-samecal-regimeshift.mq5"
        ).read_text(encoding="utf-8")
        set_path = (
            EA_DIR
            / "sets"
            / "QM5_41224_wti-samecal-regimeshift_XTIUSD.DWX_D1_backtest.set"
        )
        setfile = set_path.read_text(encoding="utf-8")
        for marker in (
            "qm_ea_id                     = 41224;",
            "qm_rng_seed                  = 42;",
            "qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;",
            "qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;",
            "qm_news_mode_legacy      = QM_NEWS_OFF;",
            "qm_friday_close_enabled       = false;",
            "qm_stress_reject_probability  = 0.0;",
            'const string g_symbol = "XTIUSD.DWX";',
            "strategy_history_years       = 10;",
            "strategy_block_years         = 5;",
            "strategy_signal_epsilon      = 1.0e-12;",
            "const int sample_index = offset - 1;",
            "observations[sample_index] = sample_return;",
            "if(sample_count != strategy_history_years)",
            "recent_sum_value / (double)strategy_block_years;",
            "older_sum_value / (double)strategy_block_years;",
            "recent_mean_value > strategy_signal_epsilon &&",
            "older_mean_value < -strategy_signal_epsilon",
            "recent_mean_value < -strategy_signal_epsilon &&",
            "older_mean_value > strategy_signal_epsilon",
            "Strategy_LoadRegimeShiftSignal",
            "Strategy_CompletedMonthReturn",
            "ArraySetAsSeries(rates, false);",
            "Strategy_NormalizedLabel",
            "Strategy_RecordMonthAttempt(g_decision_month_key)",
            "opening_delay > (long)strategy_entry_grace_minutes * 60L",
            "modeled_spread_points < 0.0",
            "req.tp = 0.0;",
            "strategy_atr_period_d1, 1);",
            "strategy_atr_sl_mult);",
            "strategy_max_hold_days, 40",
            "QM_FrameworkTrackOpenPositionMae();",
        ):
            self.assertIn(marker, source)
        for banned in (
            "irsi(",
            "imacd(",
            "ibands(",
            "webrequest(",
            "fileopen(",
            "bernoulli",
            "signscore",
            "strategy_t_threshold",
            "sample_variance",
            "huber",
            "continuity_correction",
            "strategy_min_observations",
            "strategy_half_life_years",
            "mathpow(",
            "weighted_mean",
        ):
            self.assertNotIn(banned, source.lower())
        self.assertNotIn(
            "SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)",
            source,
        )

        loader = source[
            source.index("bool Strategy_LoadRegimeShiftSignal") :
            source.index("void Strategy_PrepareDecisionSignal")
        ]
        self.assertNotIn("continue;", loader)
        prepare = source[
            source.index("void Strategy_PrepareDecisionSignal") :
            source.index("bool Strategy_NoTradeFilter")
        ]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadRegimeShiftSignal"),
        )
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("QM_FrameworkTrackOpenPositionMae();"),
            on_tick.index("Strategy_NoTradeFilter()"),
        )

        for marker in (
            "qm_ea_id=41224",
            "qm_magic_slot_offset=0",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "strategy_history_years=10",
            "strategy_block_years=5",
            "strategy_signal_epsilon=0.000000000001",
            "strategy_history_bars_d1=3000",
            "strategy_entry_grace_minutes=180",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
            "strategy_max_hold_days=40",
            "strategy_max_spread_points=1500",
        ):
            self.assertIn(marker, setfile)
        self.assertRegex(
            setfile,
            r"(?m)^; build_hash:\s+(?:pending|[0-9a-f]{64})$",
        )
        self.assertEqual(
            {path.name for path in (EA_DIR / "sets").glob("*.set")},
            {set_path.name},
        )

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41224_wti-samecal-regimeshift_card.md"
        )
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(
            local.read_text(encoding="utf-8").rstrip(),
            approved.read_text(encoding="utf-8").rstrip(),
        )
        magic_rows = (
            REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
        ).read_text(encoding="utf-8-sig")
        self.assertIn(
            "41224,wti-samecal-regimeshift,0,XTIUSD.DWX,412240000",
            magic_rows,
        )
        resolver = (
            REPO_ROOT
            / "framework"
            / "include"
            / "QM"
            / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("412240000", resolver)


if __name__ == "__main__":
    unittest.main()
