"""Independent deterministic fixtures for QM5_41214.

The suite covers normalized D1 labels, completed XNG month endpoints, exact
Y-1..Y-10 sampling, the nonnegative binary map, the uncorrected Bernoulli
null-half score, strict abstention, durable monthly attempts, lifecycle, quote
and grace gates, and static card/build conformance. It does not invoke MT5.
"""

from __future__ import annotations

import datetime as dt
import math
import re
import statistics
import unittest
from dataclasses import dataclass
from pathlib import Path


DAY = dt.timedelta(days=1)
NULL_PROBABILITY = 0.5
THRESHOLD = 1.0
TOLERANCE = 1.0e-10
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]


@dataclass(frozen=True)
class Bar:
    label: dt.datetime
    close: float


@dataclass(frozen=True)
class SignScoreResult:
    successes: int
    denominator: float
    score: float
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
    end_close = normalized[last].close
    if not all(
        math.isfinite(value) and value > 0.0
        for value in (prior_close, end_close)
    ):
        return None
    return math.log(end_close / prior_close)


def exact_prior_sample(
    observations: dict[tuple[int, int], float],
    decision_year: int,
    decision_month: int,
    minimum: int = 5,
) -> list[float] | None:
    sample: list[float] = []
    for offset in range(1, 11):
        value = observations.get((decision_year - offset, decision_month))
        if value is None or not math.isfinite(value):
            continue
        sample.append(value)
    return sample if len(sample) >= minimum else None


def score_direction(score: float) -> int:
    if not math.isfinite(score):
        return 0
    if score > THRESHOLD + TOLERANCE:
        return 1
    if score < -THRESHOLD - TOLERANCE:
        return -1
    return 0


def bernoulli_sign_score(
    observations: list[float],
) -> SignScoreResult | None:
    if not 5 <= len(observations) <= 10:
        return None
    if not all(math.isfinite(value) for value in observations):
        return None
    successes = sum(value >= 0.0 for value in observations)
    denominator = math.sqrt(
        len(observations) * NULL_PROBABILITY * (1.0 - NULL_PROBABILITY)
    )
    if not math.isfinite(denominator) or denominator <= 0.0:
        return None
    score = (
        successes - len(observations) * NULL_PROBABILITY
    ) / denominator
    if not math.isfinite(score):
        return None
    return SignScoreResult(
        successes, denominator, score, score_direction(score)
    )


def magnitude_t_score(observations: list[float]) -> float:
    mean = statistics.mean(observations)
    return mean / (
        statistics.stdev(observations) / math.sqrt(len(observations))
    )


def quote_allows(
    bid: float,
    ask: float,
    point: float,
    maximum_spread_points: int = 3000,
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


class SameCalendarSignScoreReferenceTests(unittest.TestCase):
    def test_native_and_prior_day_labels_detect_month_roll(self) -> None:
        native = normalized_sessions(
            dt.datetime(2026, 8, 3),
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 8, 3, 1),
        )
        prior_day = normalized_sessions(
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 7, 30),
            dt.datetime(2026, 8, 1, 1),
        )
        self.assertIsNotNone(native)
        self.assertIsNotNone(prior_day)
        assert native is not None and prior_day is not None
        self.assertEqual(native[2], 0)
        self.assertEqual(prior_day[2], 1)
        self.assertNotEqual(
            (native[0].year, native[0].month),
            (native[1].year, native[1].month),
        )
        self.assertNotEqual(
            (prior_day[0].year, prior_day[0].month),
            (prior_day[1].year, prior_day[1].month),
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
            Bar(dt.datetime(2026, 1, 1), 92.0),
            Bar(dt.datetime(2026, 1, 29), 99.0),
            Bar(dt.datetime(2026, 2, 1), 101.0),
        )
        observed = completed_month_return(bars, 2026, 1, 1)
        self.assertIsNotNone(observed)
        self.assertAlmostEqual(observed or 0.0, math.log(99.0 / 90.0))
        self.assertIsNone(completed_month_return(bars[:-1], 2026, 1, 1))

    def test_year_scan_skips_missing_without_substitution(self) -> None:
        observations = {
            (2026 - offset, 1): offset / 100.0 for offset in range(1, 12)
        }
        del observations[(2023, 1)]
        observations[(2021, 1)] = math.nan
        sample = exact_prior_sample(observations, 2026, 1)
        self.assertIsNotNone(sample)
        self.assertEqual(len(sample or []), 8)
        self.assertNotIn(0.11, sample or [])
        sparse = dict(list(observations.items())[:4])
        self.assertIsNone(exact_prior_sample(sparse, 2026, 1))

    def test_nonnegative_map_null_denominator_score_and_side(self) -> None:
        long_result = bernoulli_sign_score([0.0, 0.01, 0.02, 0.03, -0.01])
        self.assertIsNotNone(long_result)
        assert long_result is not None
        self.assertEqual(long_result.successes, 4)
        self.assertAlmostEqual(long_result.denominator, 0.5 * math.sqrt(5))
        self.assertAlmostEqual(long_result.score, 3.0 / math.sqrt(5))
        self.assertEqual(long_result.direction, 1)

        short_result = bernoulli_sign_score(
            [0.01, -0.01, -0.02, -0.03, -0.04]
        )
        self.assertIsNotNone(short_result)
        assert short_result is not None
        self.assertEqual(short_result.successes, 1)
        self.assertAlmostEqual(short_result.score, -3.0 / math.sqrt(5))
        self.assertEqual(short_result.direction, -1)

    def test_strict_threshold_and_tolerance_abstain(self) -> None:
        self.assertEqual(score_direction(THRESHOLD), 0)
        self.assertEqual(score_direction(THRESHOLD + TOLERANCE), 0)
        self.assertEqual(score_direction(-THRESHOLD - TOLERANCE), 0)
        self.assertEqual(score_direction(THRESHOLD + TOLERANCE + 1e-12), 1)
        self.assertEqual(score_direction(-THRESHOLD - TOLERANCE - 1e-12), -1)
        exact_positive = bernoulli_sign_score(
            [1.0] * 6 + [-1.0] * 3
        )
        exact_negative = bernoulli_sign_score(
            [1.0] * 3 + [-1.0] * 6
        )
        self.assertAlmostEqual(exact_positive.score if exact_positive else 0, 1)
        self.assertAlmostEqual(exact_negative.score if exact_negative else 0, -1)
        self.assertEqual(exact_positive.direction if exact_positive else 9, 0)
        self.assertEqual(exact_negative.direction if exact_negative else 9, 0)

    def test_fixed_nonduplicate_disagreement_vectors(self) -> None:
        raw_mean_vector = [0.09, -0.01, -0.01, -0.01, -0.01]
        raw_result = bernoulli_sign_score(raw_mean_vector)
        self.assertGreater(statistics.mean(raw_mean_vector), 0.0)
        self.assertEqual(raw_result.direction if raw_result else 0, -1)

        hit_vector = [0.01, 0.02, 0.03, -0.01, -0.02, -0.03]
        hit_result = bernoulli_sign_score(hit_vector)
        self.assertGreaterEqual(
            sum(value >= 0 for value in hit_vector) / len(hit_vector),
            0.40,
        )
        self.assertEqual(hit_result.direction if hit_result else 9, 0)

        t_vector = [0.001, 0.001, 0.001, 0.001, -0.100]
        t_result = bernoulli_sign_score(t_vector)
        self.assertLess(abs(magnitude_t_score(t_vector)), 1.0)
        self.assertEqual(t_result.direction if t_result else 0, 1)

    def test_sample_bounds_and_nonfinite_fail_closed(self) -> None:
        self.assertIsNone(bernoulli_sign_score([0.01] * 4))
        self.assertIsNone(bernoulli_sign_score([0.01] * 11))
        self.assertIsNone(
            bernoulli_sign_score([0.01] * 4 + [math.nan])
        )

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
            grace_allows(opened, opened + dt.timedelta(minutes=180, seconds=1))
        )
        self.assertTrue(quote_allows(70.0, 70.0, 0.01))
        self.assertTrue(quote_allows(70.0, 100.0, 0.01))
        self.assertFalse(quote_allows(70.0, 100.01, 0.01))
        self.assertFalse(quote_allows(70.01, 70.0, 0.01))

    def test_next_month_and_exact_forty_day_stale_exit(self) -> None:
        opened = dt.datetime(2026, 1, 3)
        self.assertFalse(stale_exit_due(opened, opened + 39 * DAY))
        self.assertTrue(stale_exit_due(opened, opened + 40 * DAY))
        month_end_open = dt.datetime(2026, 1, 30)
        self.assertTrue(exit_due(month_end_open, dt.datetime(2026, 2, 2)))

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (
            EA_DIR / "QM5_41214_xng-samecal-signscore.mq5"
        ).read_text(encoding="utf-8")
        set_path = (
            EA_DIR
            / "sets"
            / "QM5_41214_xng-samecal-signscore_XNGUSD.DWX_D1_backtest.set"
        )
        setfile = set_path.read_text(encoding="utf-8")
        for marker in (
            "qm_ea_id                     = 41214;",
            "qm_rng_seed                  = 42;",
            "qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;",
            "qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;",
            "qm_news_mode_legacy      = QM_NEWS_OFF;",
            "qm_friday_close_enabled       = false;",
            "qm_stress_reject_probability  = 0.0;",
            'const string g_symbol = "XNGUSD.DWX";',
            "strategy_history_years       = 10;",
            "strategy_min_observations    = 5;",
            "strategy_null_probability   = 0.5;",
            "strategy_score_threshold     = 1.0;",
            "strategy_signal_tolerance    = 1.0e-10;",
            "strategy_entry_grace_minutes = 180;",
            "if(observations[index] >= 0.0)",
            "(double)sample_count * strategy_null_probability;",
            "MathSqrt(null_variance);",
            "strategy_score_threshold + strategy_signal_tolerance;",
            "-strategy_score_threshold - strategy_signal_tolerance;",
            "Strategy_LoadBernoulliSignScoreSignal",
            "if(sample_count < strategy_min_observations)",
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
            "strategy_t_threshold",
            "strategy_loadtstatisticsignal",
            "sample_variance",
            "standard_error",
            "continuity_correction",
            "exact_binomial",
        ):
            self.assertNotIn(banned, source.lower())
        self.assertNotIn(
            "SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)",
            source,
        )

        prepare = source[
            source.index("void Strategy_PrepareDecisionSignal") :
            source.index("bool Strategy_NoTradeFilter")
        ]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadBernoulliSignScoreSignal"),
        )
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("QM_FrameworkTrackOpenPositionMae();"),
            on_tick.index("Strategy_NoTradeFilter()"),
        )

        for marker in (
            "qm_ea_id=41214",
            "qm_magic_slot_offset=0",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "strategy_history_years=10",
            "strategy_min_observations=5",
            "strategy_null_probability=0.5",
            "strategy_score_threshold=1.0",
            "strategy_signal_tolerance=0.0000000001",
            "strategy_history_bars_d1=3000",
            "strategy_entry_grace_minutes=180",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
            "strategy_max_hold_days=40",
            "strategy_max_spread_points=3000",
        ):
            self.assertIn(marker, setfile)
        self.assertRegex(
            setfile, r"(?m)^; build_hash:\s+(?:pending|[0-9a-f]{64})$"
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
            / "QM5_41214_xng-samecal-signscore_card.md"
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
            "41214,xng-samecal-signscore,0,XNGUSD.DWX,412140000",
            magic_rows,
        )
        resolver = (
            REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("412140000", resolver)


if __name__ == "__main__":
    unittest.main()


