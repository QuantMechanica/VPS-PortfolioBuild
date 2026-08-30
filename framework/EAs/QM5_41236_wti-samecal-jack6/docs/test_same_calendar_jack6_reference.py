"""Independent deterministic fixtures for QM5_41236.

The suite covers normalized D1 labels, completed WTI month endpoints, exact
Y-6..Y-1 membership, all six delete-one five-observation means, strict
unanimous sign, durable attempts, lifecycle, and static card/build
conformance. It does not invoke MT5.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest
from dataclasses import dataclass
from pathlib import Path


DAY = dt.timedelta(days=1)
EPSILON = 1.0e-12
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]


@dataclass(frozen=True)
class Bar:
    label: dt.datetime
    close: float


@dataclass(frozen=True)
class DeleteOneResult:
    means: tuple[float, float, float, float, float, float]
    minimum_mean: float
    maximum_mean: float
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
) -> list[float] | None:
    sample: list[float] = []
    for year in range(decision_year - 6, decision_year):
        value = observations.get((year, decision_month))
        if value is None or not math.isfinite(value):
            return None
        sample.append(value)
    return sample


def delete_one_signal(observations: list[float]) -> DeleteOneResult | None:
    if len(observations) != 6 or any(
        not math.isfinite(value) for value in observations
    ):
        return None

    means: list[float] = []
    for omitted in range(6):
        subset_sum = 0.0
        subset_members = 0
        for index, value in enumerate(observations):
            if index == omitted:
                continue
            subset_sum += value
            subset_members += 1
            if not math.isfinite(subset_sum):
                return None
        if subset_members != 5:
            return None
        subset_mean = subset_sum / 5.0
        if not math.isfinite(subset_mean):
            return None
        means.append(subset_mean)

    if len(means) != 6:
        return None
    if all(value > EPSILON for value in means):
        direction = 1
    elif all(value < -EPSILON for value in means):
        direction = -1
    else:
        direction = 0
    return DeleteOneResult(
        tuple(means),  # type: ignore[arg-type]
        min(means),
        max(means),
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


class SameCalendarDeleteOneReferenceTests(unittest.TestCase):
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
        self.assertNotEqual(native[0].month, native[1].month)
        self.assertNotEqual(prior_day[0].month, prior_day[1].month)
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

    def test_exact_prior_six_are_mandatory_and_chronological(self) -> None:
        observations = {
            (year, 8): (year - 2019) / 100.0 for year in range(2020, 2026)
        }
        self.assertEqual(
            exact_prior_sample(observations, 2026, 8),
            [0.01, 0.02, 0.03, 0.04, 0.05, 0.06],
        )
        del observations[(2023, 8)]
        observations[(2019, 8)] = 0.0
        self.assertIsNone(exact_prior_sample(observations, 2026, 8))

    def test_every_index_is_omitted_once_with_divisor_five(self) -> None:
        values = [1.0, 2.0, 4.0, 8.0, 16.0, 32.0]
        result = delete_one_signal(values)
        self.assertIsNotNone(result)
        assert result is not None
        total = sum(values)
        expected = tuple((total - value) / 5.0 for value in values)
        self.assertEqual(result.means, expected)
        self.assertEqual(len(set(result.means)), 6)
        self.assertEqual(result.minimum_mean, min(expected))
        self.assertEqual(result.maximum_mean, max(expected))
        self.assertEqual(result.direction, 1)

    def test_stable_buy_and_sign_reflection_sell(self) -> None:
        values = [-0.001, 0.002, 0.003, 0.004, 0.005, 0.006]
        buy = delete_one_signal(values)
        sell = delete_one_signal([-value for value in values])
        self.assertIsNotNone(buy)
        self.assertIsNotNone(sell)
        assert buy is not None and sell is not None
        self.assertTrue(all(value > EPSILON for value in buy.means))
        self.assertTrue(all(value < -EPSILON for value in sell.means))
        self.assertEqual(buy.direction, 1)
        self.assertEqual(sell.direction, -1)
        self.assertEqual(
            sell.means,
            tuple(-value for value in buy.means),
        )

    def test_disagreement_fixture_is_flat_while_neighbors_buy(self) -> None:
        values = [-0.020, -0.010, 0.001, 0.002, 0.003, 0.050]
        result = delete_one_signal(values)
        self.assertIsNotNone(result)
        assert result is not None
        expected = (0.0092, 0.0072, 0.005, 0.0048, 0.0046, -0.0048)
        for observed, wanted in zip(result.means, expected):
            self.assertAlmostEqual(observed, wanted, places=15)
        self.assertEqual(result.direction, 0)
        self.assertLess(result.minimum_mean, -EPSILON)
        self.assertGreater(result.maximum_mean, EPSILON)

        newest_five = values[1:]
        newest_five_mean = sum(newest_five) / 5.0
        newest_five_median = sorted(newest_five)[2]
        two_year_blocks = [
            sum(values[index : index + 2]) / 2.0 for index in (0, 2, 4)
        ]
        block_median = sorted(two_year_blocks)[1]
        self.assertGreater(newest_five_mean, 0.0)
        self.assertGreater(newest_five_median, 0.0)
        self.assertGreater(block_median, 0.0)

    def test_epsilon_is_inclusive_flat_and_invalid_states_fail_closed(self) -> None:
        positive_boundary = delete_one_signal([EPSILON] * 6)
        negative_boundary = delete_one_signal([-EPSILON] * 6)
        self.assertEqual(positive_boundary.direction if positive_boundary else 9, 0)
        self.assertEqual(negative_boundary.direction if negative_boundary else 9, 0)
        self.assertIsNone(delete_one_signal([0.01] * 5))
        self.assertIsNone(delete_one_signal([0.01] * 7))
        self.assertIsNone(
            delete_one_signal([0.01, 0.01, math.nan, 0.01, 0.01, 0.01])
        )
        self.assertIsNone(
            delete_one_signal([1.0e308, 1.0e308, 1.0, 1.0, 1.0, 1.0])
        )

    def test_permutation_changes_mean_order_but_not_conjunction(self) -> None:
        values = [-0.001, 0.002, 0.003, 0.004, 0.005, 0.006]
        forward = delete_one_signal(values)
        reverse = delete_one_signal(values[::-1])
        self.assertIsNotNone(forward)
        self.assertIsNotNone(reverse)
        assert forward is not None and reverse is not None
        for observed, wanted in zip(
            tuple(reversed(forward.means)), reverse.means
        ):
            self.assertAlmostEqual(observed, wanted, places=15)
        self.assertAlmostEqual(forward.minimum_mean, reverse.minimum_mean)
        self.assertAlmostEqual(forward.maximum_mean, reverse.maximum_mean)
        self.assertEqual(forward.direction, reverse.direction)

    def test_attempt_consumes_before_failure_and_survives_restart(self) -> None:
        storage: dict[str, int] = {}
        first = AttemptLedger(storage)
        self.assertFalse(first.consume_before(202608, downstream_gate=False))
        self.assertFalse(first.consume_before(202608, downstream_gate=True))
        restarted = AttemptLedger(storage)
        self.assertFalse(restarted.consume_before(202608, downstream_gate=True))
        self.assertTrue(restarted.consume_before(202609, downstream_gate=True))

    def test_quote_boundaries_and_monthly_stale_lifecycle(self) -> None:
        self.assertTrue(quote_allows(70.0, 70.0, 0.01))
        self.assertTrue(quote_allows(70.0, 85.0, 0.01))
        self.assertFalse(quote_allows(70.0, 85.01, 0.01))
        self.assertFalse(quote_allows(70.01, 70.0, 0.01))
        opened = dt.datetime(2026, 1, 3)
        self.assertFalse(stale_exit_due(opened, opened + 39 * DAY))
        self.assertTrue(stale_exit_due(opened, opened + 40 * DAY))
        self.assertTrue(
            exit_due(dt.datetime(2026, 1, 30), dt.datetime(2026, 2, 2))
        )

    def test_static_build_contract_matches_approved_card(self) -> None:
        source_path = EA_DIR / "QM5_41236_wti-samecal-jack6.mq5"
        source = source_path.read_text(encoding="utf-8")
        set_path = (
            EA_DIR
            / "sets"
            / "QM5_41236_wti-samecal-jack6_XTIUSD.DWX_D1_backtest.set"
        )
        setfile = set_path.read_text(encoding="utf-8")
        for marker in (
            "qm_ea_id                     = 41236;",
            "qm_rng_seed                  = 42;",
            "qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;",
            "qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;",
            "qm_news_mode_legacy      = QM_NEWS_OFF;",
            "qm_friday_close_enabled       = false;",
            "qm_stress_reject_probability  = 0.0;",
            'const string g_symbol = "XTIUSD.DWX";',
            "strategy_history_years       = 6;",
            "strategy_history_bars_d1     = 3000;",
            "strategy_delete_count        = 1;",
            "strategy_subset_size         = 5;",
            "strategy_signal_epsilon      = 1.0e-12;",
            "for(int offset = strategy_history_years; offset >= 1; --offset)",
            "for(int omitted = 0; omitted < sample_count; ++omitted)",
            "if(index == omitted)",
            "subset_sum += observations[index];",
            "!MathIsValidNumber(subset_sum)",
            "subset_members != strategy_subset_size",
            "subset_sum / (double)strategy_subset_size;",
            "if(subset_mean <= strategy_signal_epsilon)",
            "if(subset_mean >= -strategy_signal_epsilon)",
            "mean_count != sample_count",
            "Strategy_LoadDeleteOneSignal",
            "Strategy_DeleteOneSignal",
            "Strategy_CompletedMonthReturn",
            "ArraySetAsSeries(rates, false);",
            "Strategy_NormalizedLabel",
            "Strategy_RecordMonthAttempt(g_decision_month_key)",
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
            "strategy_window",
            "shortest_half",
            "rolling_block",
            "strategy_t_threshold",
            "sample_variance",
            "half_life",
            "entry_grace",
            "strategy_median_index",
            "strategy_lower_hinge_index",
            "strategy_upper_hinge_index",
            "strategy_huber_delta",
            "strategy_bisquare",
            "strategy_hampel",
            "alternate_start",
            "scale_refit",
            "early_stop",
            "majority_vote",
            "confidence_interval",
        ):
            self.assertNotIn(banned, source.lower())
        self.assertNotIn("SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)", source)
        self.assertNotIn("ArraySort(", source)

        prepare = source[
            source.index("void Strategy_PrepareDecisionSignal") :
            source.index("bool Strategy_NoTradeFilter")
        ]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadDeleteOneSignal"),
        )
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("QM_FrameworkTrackOpenPositionMae();"),
            on_tick.index("Strategy_NoTradeFilter()"),
        )

        for marker in (
            "qm_ea_id=41236",
            "qm_magic_slot_offset=0",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "strategy_history_years=6",
            "strategy_history_bars_d1=3000",
            "strategy_delete_count=1",
            "strategy_subset_size=5",
            "strategy_signal_epsilon=0.000000000001",
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
            / "QM5_41236_wti-samecal-jack6_card.md"
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
            "41236,wti-samecal-jack6,0,XTIUSD.DWX,412360000",
            magic_rows,
        )
        resolver = (
            REPO_ROOT
            / "framework"
            / "include"
            / "QM"
            / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("412360000", resolver)


if __name__ == "__main__":
    unittest.main()
