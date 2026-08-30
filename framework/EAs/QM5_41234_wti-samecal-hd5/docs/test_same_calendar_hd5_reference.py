"""Independent deterministic fixtures for QM5_41234.

Covers normalized D1 labels, completed WTI month endpoints, exact Y-5..Y-1
membership, fixed Harrell-Davis beta(3,3) interval weights, the independent
rational/decimal invariant, semantic disagreement, sign boundaries, durable
attempts, lifecycle, quotes, and static card/build conformance. It does not
invoke MT5.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path


DAY = dt.timedelta(days=1)
EPSILON = 1.0e-12
WEIGHT_NUMERATORS = (181, 811, 1141, 811, 181)
WEIGHT_DENOMINATOR = 3125
DECIMAL_WEIGHTS = (0.05792, 0.25952, 0.36512, 0.25952, 0.05792)
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]


@dataclass(frozen=True)
class Bar:
    label: dt.datetime
    close: float


@dataclass(frozen=True)
class HarrellDavisResult:
    sorted_values: tuple[float, float, float, float, float]
    rational_location: float
    decimal_location: float
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
    for year in range(decision_year - 5, decision_year):
        value = observations.get((year, decision_month))
        if value is None or not math.isfinite(value):
            return None
        sample.append(value)
    return sample


def beta33_cdf(value: Fraction) -> Fraction:
    """Closed-form regularized beta(3,3) CDF."""
    return 10 * value**3 - 15 * value**4 + 6 * value**5


def beta33_interval_weights() -> tuple[Fraction, ...]:
    boundaries = tuple(Fraction(index, 5) for index in range(6))
    return tuple(
        beta33_cdf(boundaries[index + 1]) - beta33_cdf(boundaries[index])
        for index in range(5)
    )


def harrell_davis_signal(observations: list[float]) -> HarrellDavisResult | None:
    if len(observations) != 5 or any(
        not math.isfinite(value) for value in observations
    ):
        return None
    sorted_values = tuple(sorted(observations))
    rational_location = sum(
        numerator * value
        for numerator, value in zip(WEIGHT_NUMERATORS, sorted_values)
    ) / WEIGHT_DENOMINATOR
    decimal_location = sum(
        weight * value
        for weight, value in zip(DECIMAL_WEIGHTS, sorted_values)
    )
    if not all(
        math.isfinite(value) for value in (rational_location, decimal_location)
    ):
        return None
    if abs(rational_location - decimal_location) > EPSILON:
        return None
    if rational_location > EPSILON:
        direction = 1
    elif rational_location < -EPSILON:
        direction = -1
    else:
        direction = 0
    return HarrellDavisResult(
        sorted_values, rational_location, decimal_location, direction
    )


def peer_locations(values: list[float]) -> dict[str, float]:
    ordered = sorted(values)
    return {
        "mean": sum(ordered) / 5.0,
        "median": ordered[2],
        "trim": sum(ordered[1:4]) / 3.0,
        "winsor": sum(
            [ordered[1], ordered[1], ordered[2], ordered[3], ordered[3]]
        )
        / 5.0,
        "trimean": (ordered[1] + 2.0 * ordered[2] + ordered[3]) / 4.0,
        "midhinge": (ordered[1] + ordered[3]) / 2.0,
        "gastwirth": 0.2 * ordered[1] + 0.6 * ordered[2] + 0.2 * ordered[3],
    }


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


class SameCalendarHarrellDavisReferenceTests(unittest.TestCase):
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

    def test_exact_prior_five_are_mandatory(self) -> None:
        observations = {
            (year, 8): (year - 2020) / 100.0 for year in range(2021, 2026)
        }
        self.assertEqual(
            exact_prior_sample(observations, 2026, 8),
            [0.01, 0.02, 0.03, 0.04, 0.05],
        )
        del observations[(2023, 8)]
        observations[(2020, 8)] = 0.0
        self.assertIsNone(exact_prior_sample(observations, 2026, 8))

    def test_beta33_interval_masses_equal_locked_exact_weights(self) -> None:
        expected = tuple(
            Fraction(value, WEIGHT_DENOMINATOR) for value in WEIGHT_NUMERATORS
        )
        observed = beta33_interval_weights()
        self.assertEqual(observed, expected)
        self.assertEqual(sum(observed), Fraction(1, 1))
        self.assertEqual(tuple(float(value) for value in observed), DECIMAL_WEIGHTS)

    def test_rational_and_decimal_forms_are_invariant(self) -> None:
        result = harrell_davis_signal([-0.30, -0.30, 0.05, 0.25, 0.25])
        self.assertIsNotNone(result)
        assert result is not None
        self.assertAlmostEqual(result.rational_location, 0.002384, places=15)
        self.assertAlmostEqual(
            result.rational_location, result.decimal_location, places=15
        )
        self.assertEqual(result.direction, 1)

    def test_first_fixture_disagrees_with_mean_trim_winsor_midhinge(self) -> None:
        values = [-0.30, -0.30, 0.05, 0.25, 0.25]
        result = harrell_davis_signal(values)
        peers = peer_locations(values)
        self.assertEqual(result.direction if result else 0, 1)
        self.assertLess(peers["mean"], -EPSILON)
        self.assertLess(peers["winsor"], -EPSILON)
        self.assertAlmostEqual(peers["trim"], 0.0)
        self.assertLess(peers["midhinge"], -EPSILON)

    def test_second_fixture_disagrees_with_median_gastwirth_trimean(self) -> None:
        values = [-0.30, -0.20, -0.05, 0.30, 0.30]
        result = harrell_davis_signal(values)
        peers = peer_locations(values)
        self.assertIsNotNone(result)
        assert result is not None
        self.assertAlmostEqual(result.rational_location, 0.007696, places=15)
        self.assertEqual(result.direction, 1)
        self.assertLess(peers["median"], -EPSILON)
        self.assertLess(peers["gastwirth"], -EPSILON)
        self.assertAlmostEqual(peers["trimean"], 0.0)

    def test_third_fixture_sells_while_median_and_gastwirth_buy(self) -> None:
        values = [-0.30, -0.30, 0.05, 0.20, 0.20]
        result = harrell_davis_signal(values)
        peers = peer_locations(values)
        self.assertIsNotNone(result)
        assert result is not None
        self.assertAlmostEqual(result.rational_location, -0.013488, places=15)
        self.assertEqual(result.direction, -1)
        self.assertGreater(peers["median"], EPSILON)
        self.assertGreater(peers["gastwirth"], EPSILON)

    def test_sign_reflection_is_exactly_symmetric(self) -> None:
        for values in (
            [-0.30, -0.30, 0.05, 0.25, 0.25],
            [-0.30, -0.20, -0.05, 0.30, 0.30],
            [-0.30, -0.30, 0.05, 0.20, 0.20],
        ):
            original = harrell_davis_signal(values)
            reflected = harrell_davis_signal([-value for value in values])
            self.assertIsNotNone(original)
            self.assertIsNotNone(reflected)
            assert original is not None and reflected is not None
            self.assertAlmostEqual(
                reflected.rational_location,
                -original.rational_location,
                places=15,
            )
            self.assertEqual(reflected.direction, -original.direction)

    def test_sort_makes_year_order_irrelevant_after_membership(self) -> None:
        values = [-0.30, -0.20, -0.05, 0.30, 0.30]
        forward = harrell_davis_signal(values)
        reverse = harrell_davis_signal(values[::-1])
        self.assertIsNotNone(forward)
        self.assertIsNotNone(reverse)
        assert forward is not None and reverse is not None
        self.assertEqual(forward.sorted_values, reverse.sorted_values)
        self.assertAlmostEqual(
            forward.rational_location, reverse.rational_location, places=15
        )
        self.assertEqual(forward.direction, reverse.direction)

    def test_strict_epsilon_and_invalid_states_fail_closed(self) -> None:
        centered = harrell_davis_signal([-2.0, -1.0, 0.0, 1.0, 2.0])
        positive = harrell_davis_signal(
            [-2.0 + 1.0e-9, -1.0 + 1.0e-9, 1.0e-9, 1.0 + 1.0e-9, 2.0 + 1.0e-9]
        )
        self.assertEqual(centered.direction if centered else 9, 0)
        self.assertEqual(positive.direction if positive else 0, 1)
        self.assertIsNone(harrell_davis_signal([0.01] * 4))
        self.assertIsNone(
            harrell_davis_signal([0.01, 0.01, math.nan, 0.01, 0.01])
        )

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
        source_path = EA_DIR / "QM5_41234_wti-samecal-hd5.mq5"
        source = source_path.read_text(encoding="utf-8")
        set_path = (
            EA_DIR
            / "sets"
            / "QM5_41234_wti-samecal-hd5_XTIUSD.DWX_D1_backtest.set"
        )
        setfile = set_path.read_text(encoding="utf-8")
        for marker in (
            "qm_ea_id                     = 41234;",
            "qm_rng_seed                  = 42;",
            "qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;",
            "qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;",
            "qm_news_mode_legacy      = QM_NEWS_OFF;",
            "qm_friday_close_enabled       = false;",
            "qm_stress_reject_probability  = 0.0;",
            'const string g_symbol = "XTIUSD.DWX";',
            "strategy_history_years       = 5;",
            "strategy_signal_epsilon      = 1.0e-12;",
            "strategy_invariant_tolerance = 1.0e-12;",
            "strategy_deviation_points    = 20;",
            "for(int offset = strategy_history_years; offset >= 1; --offset)",
            "double sorted_values[5];",
            "ArraySort(sorted_values);",
            "181.0 * sorted_values[0] +",
            "811.0 * sorted_values[1] +",
            "1141.0 * sorted_values[2] +",
            "const double rational_location = rational_numerator / 3125.0;",
            "0.05792 * sorted_values[0] +",
            "0.25952 * sorted_values[1] +",
            "0.36512 * sorted_values[2] +",
            "MathAbs(rational_location - decimal_location) >",
            "strategy_invariant_tolerance",
            "Strategy_LoadHarrellDavisSignal",
            "Strategy_HarrellDavisSignal",
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
            "strategy_mad_cap_mult",
            "strategy_bisquare_cutoff",
            "strategy_huber_delta",
            "early_stop",
        ):
            self.assertNotIn(banned, source.lower())
        self.assertNotIn("SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)", source)

        prepare = source[
            source.index("void Strategy_PrepareDecisionSignal") :
            source.index("bool Strategy_NoTradeFilter")
        ]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadHarrellDavisSignal"),
        )
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("QM_FrameworkTrackOpenPositionMae();"),
            on_tick.index("Strategy_NoTradeFilter()"),
        )

        for marker in (
            "qm_ea_id=41234",
            "qm_magic_slot_offset=0",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "strategy_history_years=5",
            "strategy_signal_epsilon=0.000000000001",
            "strategy_invariant_tolerance=0.000000000001",
            "strategy_history_bars_d1=3000",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
            "strategy_max_hold_days=40",
            "strategy_max_spread_points=1500",
            "strategy_deviation_points=20",
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
            / "QM5_41234_wti-samecal-hd5_card.md"
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
            "41234,wti-samecal-hd5,0,XTIUSD.DWX,412340000",
            magic_rows,
        )
        resolver = (
            REPO_ROOT
            / "framework"
            / "include"
            / "QM"
            / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("412340000", resolver)


if __name__ == "__main__":
    unittest.main()

