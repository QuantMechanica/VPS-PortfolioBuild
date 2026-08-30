"""Independent deterministic fixtures for QM5_41223.

The suite covers normalized D1 labels, completed WTI month endpoints, exact
Y-1..Y-10 sampling, uncompressed calendar-year ages, the fixed base-two
four-year half-life, normalized weighted direction, durable monthly attempts,
lifecycle, quote/grace gates, and static card/build conformance. It does not
invoke MT5.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest
from dataclasses import dataclass
from pathlib import Path


DAY = dt.timedelta(days=1)
HALF_LIFE_YEARS = 4.0
EPSILON = 1.0e-12
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]


@dataclass(frozen=True)
class Bar:
    label: dt.datetime
    close: float


@dataclass(frozen=True)
class AgedReturn:
    age: int
    value: float


@dataclass(frozen=True)
class YearWeightResult:
    sample_count: int
    weight_sum: float
    weighted_sum: float
    weighted_mean: float
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
) -> list[AgedReturn] | None:
    sample: list[AgedReturn] = []
    for lag in range(1, 11):
        value = observations.get((decision_year - lag, decision_month))
        if value is None or not math.isfinite(value):
            continue
        sample.append(AgedReturn(age=lag - 1, value=value))
    return sample if len(sample) >= minimum else None


def exponential_year_weight_signal(
    observations: list[AgedReturn],
) -> YearWeightResult | None:
    if not 5 <= len(observations) <= 10:
        return None
    ages = [item.age for item in observations]
    if any(
        not math.isfinite(item.value) or item.age < 0 or item.age > 9
        for item in observations
    ):
        return None
    if any(ages[index] <= ages[index - 1] for index in range(1, len(ages))):
        return None

    weights = [2.0 ** (-item.age / HALF_LIFE_YEARS) for item in observations]
    if any(not math.isfinite(weight) or weight <= 0.0 for weight in weights):
        return None
    weight_sum = sum(weights)
    weighted_sum = sum(
        weight * item.value for weight, item in zip(weights, observations)
    )
    if not all(math.isfinite(value) for value in (weight_sum, weighted_sum)):
        return None
    if weight_sum <= 0.0:
        return None
    weighted_mean = weighted_sum / weight_sum
    if not math.isfinite(weighted_mean):
        return None
    if weighted_mean > EPSILON:
        direction = 1
    elif weighted_mean < -EPSILON:
        direction = -1
    else:
        direction = 0
    return YearWeightResult(
        len(observations), weight_sum, weighted_sum, weighted_mean, direction
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


class SameCalendarExponentialYearWeightReferenceTests(unittest.TestCase):
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

    def test_year_scan_skips_missing_without_compressing_ages(self) -> None:
        observations = {
            (2026 - lag, 1): lag / 100.0 for lag in range(1, 12)
        }
        del observations[(2023, 1)]
        observations[(2021, 1)] = math.nan
        sample = exact_prior_sample(observations, 2026, 1)
        self.assertIsNotNone(sample)
        assert sample is not None
        self.assertEqual(
            [item.age for item in sample],
            [0, 1, 3, 5, 6, 7, 8, 9],
        )
        self.assertNotIn(AgedReturn(age=10, value=0.11), sample)
        sparse = {(2025 - lag, 1): 0.01 for lag in range(4)}
        self.assertIsNone(exact_prior_sample(sparse, 2026, 1))

    def test_exact_decay_weights_normalization_and_side(self) -> None:
        observations = [
            AgedReturn(0, 0.02),
            AgedReturn(1, 0.01),
            AgedReturn(4, -0.01),
            AgedReturn(7, 0.03),
            AgedReturn(8, 0.02),
        ]
        result = exponential_year_weight_signal(observations)
        self.assertIsNotNone(result)
        assert result is not None
        self.assertEqual(result.sample_count, 5)
        self.assertAlmostEqual(2.0 ** (-0 / HALF_LIFE_YEARS), 1.0)
        self.assertAlmostEqual(2.0 ** (-4 / HALF_LIFE_YEARS), 0.5)
        self.assertAlmostEqual(2.0 ** (-8 / HALF_LIFE_YEARS), 0.25)
        expected_weights = [
            2.0 ** (-item.age / 4.0) for item in observations
        ]
        self.assertAlmostEqual(result.weight_sum, sum(expected_weights))
        self.assertAlmostEqual(
            result.weighted_sum,
            sum(
                weight * item.value
                for weight, item in zip(expected_weights, observations)
            ),
        )
        self.assertAlmostEqual(
            result.weighted_mean,
            result.weighted_sum / result.weight_sum,
        )
        self.assertEqual(result.direction, 1)

    def test_strict_epsilon_boundary_consumes_flat(self) -> None:
        base = [AgedReturn(age, 0.0) for age in range(5)]
        flat = exponential_year_weight_signal(base)
        self.assertEqual(flat.direction if flat else 9, 0)
        weight_sum = sum(2.0 ** (-age / 4.0) for age in range(5))
        at_positive = base.copy()
        at_positive[0] = AgedReturn(0, EPSILON * weight_sum)
        positive_result = exponential_year_weight_signal(at_positive)
        self.assertIsNotNone(positive_result)
        self.assertAlmostEqual(
            positive_result.weighted_mean if positive_result else 0.0,
            EPSILON,
        )
        self.assertEqual(positive_result.direction if positive_result else 9, 0)
        beyond = base.copy()
        beyond[0] = AgedReturn(0, (EPSILON + 1.0e-15) * weight_sum)
        beyond_result = exponential_year_weight_signal(beyond)
        self.assertEqual(beyond_result.direction if beyond_result else 0, 1)

    def test_fixed_equal_weight_disagreement_is_opposite_side(self) -> None:
        values = [
            -0.04,
            -0.04,
            -0.04,
            0.03,
            0.03,
            0.03,
            0.03,
            0.03,
            0.03,
            0.03,
        ]
        observations = [
            AgedReturn(age, value) for age, value in enumerate(values)
        ]
        result = exponential_year_weight_signal(observations)
        self.assertGreater(sum(values) / len(values), 0.0)
        self.assertIsNotNone(result)
        self.assertLess(result.weighted_sum if result else 0.0, 0.0)
        self.assertEqual(result.direction if result else 0, -1)

    def test_sample_age_and_nonfinite_states_fail_closed(self) -> None:
        self.assertIsNone(
            exponential_year_weight_signal(
                [AgedReturn(index, 0.01) for index in range(4)]
            )
        )
        self.assertIsNone(
            exponential_year_weight_signal(
                [AgedReturn(index, 0.01) for index in range(10)]
                + [AgedReturn(9, 0.01)]
            )
        )
        self.assertIsNone(
            exponential_year_weight_signal(
                [AgedReturn(index, 0.01) for index in [0, 1, 1, 3, 4]]
            )
        )
        self.assertIsNone(
            exponential_year_weight_signal(
                [AgedReturn(index, 0.01) for index in [0, 1, 2, 3, 10]]
            )
        )
        self.assertIsNone(
            exponential_year_weight_signal(
                [
                    AgedReturn(index, math.nan if index == 4 else 0.01)
                    for index in range(5)
                ]
            )
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
            EA_DIR / "QM5_41223_wti-samecal-expw4.mq5"
        ).read_text(encoding="utf-8")
        set_path = (
            EA_DIR
            / "sets"
            / "QM5_41223_wti-samecal-expw4_XTIUSD.DWX_D1_backtest.set"
        )
        setfile = set_path.read_text(encoding="utf-8")
        for marker in (
            "qm_ea_id                     = 41223;",
            "qm_rng_seed                  = 42;",
            "qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;",
            "qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;",
            "qm_news_mode_legacy      = QM_NEWS_OFF;",
            "qm_friday_close_enabled       = false;",
            "qm_stress_reject_probability  = 0.0;",
            'const string g_symbol = "XTIUSD.DWX";',
            "strategy_history_years       = 10;",
            "strategy_min_observations    = 5;",
            "strategy_half_life_years     = 4.0;",
            "strategy_signal_epsilon      = 1.0e-12;",
            "ages[sample_count] = offset - 1;",
            "const double weight = MathPow(2.0, exponent);",
            "weighted_mean_value = weighted_sum_value / weight_sum_value;",
            "weighted_mean_value > strategy_signal_epsilon",
            "weighted_mean_value < -strategy_signal_epsilon",
            "Strategy_LoadExponentialYearWeightSignal",
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
            "bernoulli",
            "signscore",
            "strategy_t_threshold",
            "sample_variance",
            "huber",
            "continuity_correction",
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
            prepare.index("Strategy_LoadExponentialYearWeightSignal"),
        )
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("QM_FrameworkTrackOpenPositionMae();"),
            on_tick.index("Strategy_NoTradeFilter()"),
        )

        for marker in (
            "qm_ea_id=41223",
            "qm_magic_slot_offset=0",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "strategy_history_years=10",
            "strategy_min_observations=5",
            "strategy_half_life_years=4.0",
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
            / "QM5_41223_wti-samecal-expw4_card.md"
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
            "41223,wti-samecal-expw4,0,XTIUSD.DWX,412230000",
            magic_rows,
        )
        resolver = (
            REPO_ROOT
            / "framework"
            / "include"
            / "QM"
            / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("412230000", resolver)


if __name__ == "__main__":
    unittest.main()
