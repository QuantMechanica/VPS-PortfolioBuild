"""Independent deterministic fixtures for QM5_41226.

The suite covers normalized D1 labels, synchronized completed-month
endpoints, the exact Y-1..Y-10 scan with a five-pair floor, XAU-minus-XAG
orientation, ordinary odd/even sample-median arithmetic, durable monthly
attempts, quote boundaries, and static card/build conformance. It does not
invoke MT5 or duplicate framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import json
import math
import statistics
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
class MonthObservation:
    value: float
    endpoint: tuple[dt.datetime, dt.datetime, dt.datetime]


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


def completed_month_observation(
    bars: tuple[Bar, ...],
    target_year: int,
    target_month: int,
    label_offset_days: int,
) -> MonthObservation | None:
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
    return MonthObservation(
        math.log(end_close / prior_close),
        (
            normalized[last].label,
            normalized[first - 1].label,
            normalized[last + 1].label,
        ),
    )


def exact_prior_pair_sample(
    xau: dict[tuple[int, int], MonthObservation],
    xag: dict[tuple[int, int], MonthObservation],
    decision_year: int,
    decision_month: int,
    minimum: int = 5,
) -> list[float] | None:
    sample: list[float] = []
    for offset in range(1, 11):
        key = (decision_year - offset, decision_month)
        xau_value = xau.get(key)
        xag_value = xag.get(key)
        if xau_value is None or xag_value is None:
            continue
        if xau_value.endpoint != xag_value.endpoint:
            continue
        relative = xau_value.value - xag_value.value
        if not math.isfinite(relative):
            continue
        sample.append(relative)
    return sample if len(sample) >= minimum else None


def median_signal(
    observations: list[float], epsilon: float = EPSILON
) -> tuple[float, int] | None:
    if not 5 <= len(observations) <= 10:
        return None
    if not all(math.isfinite(value) for value in observations):
        return None
    ordered = sorted(observations)
    middle = len(ordered) // 2
    if len(ordered) % 2:
        median = ordered[middle]
    else:
        median = (ordered[middle - 1] + ordered[middle]) / 2.0
    if not math.isfinite(median):
        return None
    direction = (median > epsilon) - (median < -epsilon)
    return median, direction


def sign_score_direction(observations: list[float]) -> int:
    successes = sum(value >= 0.0 for value in observations)
    score = (2 * successes - len(observations)) / math.sqrt(
        len(observations)
    )
    return (score > 1.0 + 1.0e-10) - (score < -1.0 - 1.0e-10)


def t_score(observations: list[float]) -> float:
    mean = statistics.mean(observations)
    return mean / (statistics.stdev(observations) / math.sqrt(len(observations)))


def quote_allows(
    bid: float, ask: float, point: float, maximum_spread_points: int
) -> bool:
    if not all(
        math.isfinite(value) and value > 0.0 for value in (bid, ask, point)
    ):
        return False
    if ask < bid:
        return False
    spread = (ask - bid) / point
    return (
        math.isfinite(spread)
        and spread >= 0.0
        and spread <= maximum_spread_points
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


class SameCalendarMedianBasketReferenceTests(unittest.TestCase):
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

    def test_completed_month_endpoints_use_uniform_offset(self) -> None:
        bars = (
            Bar(dt.datetime(2025, 12, 30), 90.0),
            Bar(dt.datetime(2026, 1, 1), 92.0),
            Bar(dt.datetime(2026, 1, 29), 99.0),
            Bar(dt.datetime(2026, 2, 1), 101.0),
        )
        observed = completed_month_observation(bars, 2026, 1, 1)
        self.assertIsNotNone(observed)
        assert observed is not None
        self.assertAlmostEqual(observed.value, math.log(99.0 / 90.0))
        self.assertEqual(observed.endpoint[0], dt.datetime(2026, 1, 30))
        self.assertIsNone(completed_month_observation(bars[:-1], 2026, 1, 1))

    def test_exact_year_scan_skips_missing_mismatched_and_year_eleven(self) -> None:
        endpoint = (
            dt.datetime(2025, 1, 31),
            dt.datetime(2024, 12, 31),
            dt.datetime(2025, 2, 3),
        )
        xau = {
            (2026 - offset, 1): MonthObservation(offset / 100.0, endpoint)
            for offset in range(1, 12)
        }
        xag = {
            (2026 - offset, 1): MonthObservation(offset / 200.0, endpoint)
            for offset in range(1, 12)
        }
        del xag[(2023, 1)]
        xag[(2021, 1)] = MonthObservation(
            0.01,
            (
                dt.datetime(2021, 1, 30),
                dt.datetime(2020, 12, 31),
                dt.datetime(2021, 2, 2),
            ),
        )
        sample = exact_prior_pair_sample(xau, xag, 2026, 1)
        self.assertIsNotNone(sample)
        self.assertEqual(len(sample or []), 8)
        self.assertNotIn(11 / 200.0, sample or [])
        self.assertIsNone(exact_prior_pair_sample(xau, {}, 2026, 1))

    def test_ordinary_odd_even_medians_and_orientation(self) -> None:
        odd = median_signal([-0.04, 0.01, 0.03, 0.02, 0.50])
        even = median_signal([-0.04, -0.01, 0.02, 0.04, 0.10, 0.50])
        self.assertEqual(odd, (0.02, 1))
        self.assertEqual(even, (0.03, 1))
        inverse = median_signal([0.04, -0.01, -0.03, -0.02, -0.50])
        self.assertEqual(inverse, (-0.02, -1))

    def test_mean_and_median_take_opposite_sides(self) -> None:
        observations = [0.01, 0.01, 0.01, 0.01, -0.20]
        result = median_signal(observations)
        self.assertIsNotNone(result)
        assert result is not None
        self.assertGreater(result[0], 0.0)
        self.assertEqual(result[1], 1)
        self.assertLess(statistics.mean(observations), 0.0)

    def test_sign_score_and_t_score_abstain_while_median_buys(self) -> None:
        observations = [0.001, -0.20, -0.20, 0.20, 0.20]
        result = median_signal(observations)
        self.assertIsNotNone(result)
        assert result is not None
        self.assertEqual(result, (0.001, 1))
        self.assertEqual(sign_score_direction(observations), 0)
        self.assertLess(abs(t_score(observations)), 1.0)

    def test_bounds_nonfinite_and_epsilon_tie_fail_closed(self) -> None:
        self.assertIsNone(median_signal([0.01] * 4))
        self.assertIsNone(median_signal([0.01] * 11))
        self.assertIsNone(median_signal([0.01] * 4 + [math.nan]))
        self.assertEqual(median_signal([EPSILON] * 5), (EPSILON, 0))
        self.assertEqual(median_signal([-EPSILON] * 5), (-EPSILON, 0))
        self.assertEqual(median_signal([2 * EPSILON] * 5)[1], 1)
        self.assertEqual(median_signal([-2 * EPSILON] * 5)[1], -1)

    def test_quote_boundaries_accept_zero_and_exact_caps(self) -> None:
        self.assertTrue(quote_allows(2000.0, 2000.0, 0.01, 1500))
        self.assertTrue(quote_allows(2000.0, 2015.0, 0.01, 1500))
        self.assertFalse(quote_allows(2000.0, 2015.01, 0.01, 1500))
        self.assertFalse(quote_allows(2000.01, 2000.0, 0.01, 1500))

    def test_attempt_is_consumed_before_failure_and_survives_restart(self) -> None:
        storage: dict[str, int] = {}
        first = AttemptLedger(storage)
        self.assertFalse(first.consume_before(202608, downstream_gate=False))
        self.assertFalse(first.consume_before(202608, downstream_gate=True))
        restarted = AttemptLedger(storage)
        self.assertFalse(restarted.consume_before(202608, downstream_gate=True))
        self.assertTrue(restarted.consume_before(202609, downstream_gate=True))

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41226_xauxag-medcal.mq5").read_text(
            encoding="utf-8"
        )
        set_path = (
            EA_DIR
            / "sets"
            / (
                "QM5_41226_xauxag-medcal_"
                "QM5_41226_XAU_XAG_MEDCAL_D1_D1_backtest.set"
            )
        )
        setfile = set_path.read_text(encoding="utf-8")
        for marker in (
            "input int    qm_ea_id                    = 41226;",
            'input string strategy_xag_symbol            = "XAGUSD.DWX";',
            "input int    strategy_history_years          = 10;",
            "input int    strategy_min_observations      = 5;",
            "input double strategy_signal_epsilon           = 1.0e-12;",
            "if(qm_ea_id != 41226 || qm_magic_slot_offset != 0 || qm_rng_seed != 42)",
            "Strategy_SortAscending(observations, sample_count);",
            "seasonal_median = observations[sample_count / 2];",
            "observations[sample_count / 2 - 1] +",
            "seasonal_median > strategy_signal_epsilon",
            "Strategy_ConsumePeriodAttempt(g_cache_period_key)",
            "Strategy_LoadSignalState(g_cache_decision_month_key",
            "ArraySetAsSeries(xau_rates, false);",
            "ArraySetAsSeries(xag_rates, false);",
            "Strategy_NormalizedHostSessions",
            "xau_month_time != xag_month_time",
            "Strategy_LoadAllowedQuote(symbol, bid, ask)",
            "modeled_spread_points < 0.0",
            "RISK_FIXED / 2.0",
            "req.tp = 0.0;",
            "strategy_atr_period_d1, 1);",
            "strategy_atr_sl_mult * atr;",
            "QM_FrameworkTrackOpenPositionMae();",
        ):
            self.assertIn(marker, source)
        for banned in (
            "irsi(",
            "imacd(",
            "ibands(",
            "webrequest(",
            "fileopen(",
            "strategy_null_probability",
            "strategy_score_threshold",
            "strategy_signal_tolerance",
            "strategy_sign_score",
            "strategy_huber",
            "strategy_sample_mean",
        ):
            self.assertNotIn(banned, source.lower())
        self.assertNotIn("SYMBOL_SPREAD", source)

        entry = source[
            source.index("bool Strategy_EntrySignal") :
            source.index("void Strategy_ManageOpenPosition")
        ]
        self.assertLess(
            entry.index("Strategy_ConsumePeriodAttempt(g_cache_period_key)"),
            entry.index("Strategy_LoadSignalState"),
        )
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("QM_FrameworkTrackOpenPositionMae();"),
            on_tick.index("Strategy_NoTradeFilter()"),
        )
        for marker in (
            "qm_ea_id=41226",
            "qm_magic_slot_offset=0",
            "qm_rng_seed=42",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_news_temporal=0",
            "qm_news_compliance=0",
            "qm_friday_close_enabled=false",
            "strategy_xag_symbol=XAGUSD.DWX",
            "strategy_history_years=10",
            "strategy_min_observations=5",
            "strategy_signal_epsilon=0.000000000001",
            "strategy_history_bars_d1=3000",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
            "strategy_max_hold_days=40",
            "strategy_xau_max_spread_points=1500",
            "strategy_xag_max_spread_points=3000",
            "strategy_deviation_points=20",
        ):
            self.assertIn(marker, setfile)
        self.assertRegex(
            setfile, r"(?m)^; build_hash:\s+(?:pending|[0-9a-f]{64})$"
        )
        set_names = {path.name for path in (EA_DIR / "sets").glob("*.set")}
        self.assertEqual(
            set_names,
            {
                (
                    "QM5_41226_xauxag-medcal_"
                    "QM5_41226_XAU_XAG_MEDCAL_D1_D1_backtest.set"
                ),
                "QM5_41226_xauxag-medcal_XAUUSD.DWX_D1_backtest.set",
                "QM5_41226_xauxag-medcal_XAGUSD.DWX_D1_backtest.set",
            },
        )
        for component_name in set_names - {set_path.name}:
            component = (EA_DIR / "sets" / component_name).read_text(
                encoding="utf-8"
            )
            self.assertIn("RISK_FIXED=1000", component)
            self.assertIn("RISK_PERCENT=0", component)
            self.assertIn("strategy_signal_epsilon=0.000000000001", component)

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41226_xauxag-medcal_card.md"
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
            "41226,xauxag-medcal,0,XAUUSD.DWX,412260000", magic_rows
        )
        self.assertIn(
            "41226,xauxag-medcal,1,XAGUSD.DWX,412260001", magic_rows
        )
        resolver = (
            REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("412260000", resolver)
        self.assertIn("412260001", resolver)

        basket = json.loads(
            (EA_DIR / "basket_manifest.json").read_text(encoding="utf-8")
        )
        self.assertEqual(
            basket["logical_symbol"], "QM5_41226_XAU_XAG_MEDCAL_D1"
        )
        self.assertEqual(basket["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(
            basket["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"]
        )
        self.assertEqual(basket["traded_symbols"], basket["basket_symbols"])


if __name__ == "__main__":
    unittest.main()
