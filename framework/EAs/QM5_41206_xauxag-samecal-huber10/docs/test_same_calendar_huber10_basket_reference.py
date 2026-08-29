"""Independent deterministic fixtures for QM5_41206.

The suite covers strict synchronized D1 month endpoints, the all-or-nothing
Y-1..Y-10 paired sample, XAU-minus-XAG orientation, even median/MAD,
frozen-scale Huber weights, exactly 32 updates, direction separation from
nearby estimators, durable monthly attempts, atomic basket lifecycle, and
static card/build conformance.
It does not invoke MT5 or duplicate framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import json
import math
import re
import statistics
import unittest
from dataclasses import dataclass
from pathlib import Path


DAY = dt.timedelta(days=1)
EPSILON = 1.0e-12
MAD_NORMALIZER = 1.4826
HUBER_TUNING = 1.5
HUBER_STEPS = 32
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]


@dataclass(frozen=True)
class Bar:
    label: dt.datetime
    close: float


@dataclass(frozen=True)
class HuberResult:
    observations: tuple[float, ...]
    median: float
    mad: float
    scale: float
    delta: float
    location: float
    direction: int


def normalized_session(
    label: dt.datetime, broker_now: dt.datetime
) -> dt.datetime | None:
    elapsed = broker_now - label
    if dt.timedelta(0) <= elapsed < DAY:
        return label
    if DAY <= elapsed < 2 * DAY:
        return label + DAY
    return None


def month_key(value: dt.datetime) -> int:
    return value.year * 100 + value.month


def adjacent_month(month: int, step: int) -> int:
    year, number = divmod(month, 100)
    number += step
    if number == 0:
        return (year - 1) * 100 + 12
    if number == 13:
        return (year + 1) * 100 + 1
    return year * 100 + number


def is_month_boundary(
    current_label: dt.datetime,
    previous_label: dt.datetime,
    broker_now: dt.datetime,
) -> tuple[bool, int]:
    current = normalized_session(current_label, broker_now)
    if current is None or current.date() != broker_now.date():
        return False, 0
    offset = current - current_label
    previous = previous_label + offset
    return (
        adjacent_month(month_key(previous), 1) == month_key(current),
        offset.days,
    )


def completed_month_return(
    bars: tuple[Bar, ...], target_month: int, label_offset_days: int
) -> float | None:
    normalized = tuple(
        Bar(bar.label + label_offset_days * DAY, bar.close) for bar in bars
    )
    indices = [
        index
        for index, bar in enumerate(normalized)
        if month_key(bar.label) == target_month
    ]
    if not indices:
        return None
    first, last = indices[0], indices[-1]
    if first == 0 or last + 1 >= len(normalized):
        return None
    if indices != list(range(first, last + 1)):
        return None
    if any(
        normalized[index - 1].label >= normalized[index].label
        for index in range(1, len(normalized))
    ):
        return None
    if month_key(normalized[first - 1].label) != adjacent_month(
        target_month, -1
    ):
        return None
    if month_key(normalized[last + 1].label) != adjacent_month(
        target_month, 1
    ):
        return None
    prior_close = normalized[first - 1].close
    end_close = normalized[last].close
    if not all(
        math.isfinite(value) and value > 0.0
        for value in (prior_close, end_close)
    ):
        return None
    return math.log(end_close / prior_close)


def exact_prior_ten_sample(
    returns_by_month: dict[int, float], decision_month: int
) -> list[float] | None:
    year, month = divmod(decision_month, 100)
    required = [(year - offset) * 100 + month for offset in range(1, 11)]
    if any(key not in returns_by_month for key in required):
        return None
    sample = [returns_by_month[key] for key in required]
    if not all(math.isfinite(value) for value in sample):
        return None
    return sample


def paired_relative_returns(
    xau_returns: list[float], xag_returns: list[float]
) -> list[float] | None:
    if len(xau_returns) != 10 or len(xag_returns) != 10:
        return None
    observations = [
        xau - xag for xau, xag in zip(xau_returns, xag_returns)
    ]
    if not all(math.isfinite(value) for value in observations):
        return None
    return observations


def huber_direction(
    observations: list[float],
    *,
    steps: int = HUBER_STEPS,
    epsilon: float = EPSILON,
) -> HuberResult | None:
    if len(observations) != 10:
        return None
    if not all(math.isfinite(value) for value in observations):
        return None
    ordered = sorted(observations)
    median = (ordered[4] + ordered[5]) / 2.0
    deviations = sorted(abs(value - median) for value in observations)
    mad = (deviations[4] + deviations[5]) / 2.0
    scale = MAD_NORMALIZER * mad
    delta = HUBER_TUNING * scale
    if not all(math.isfinite(value) and value > 0.0 for value in (mad, scale, delta)):
        return None

    location = median
    for _ in range(steps):
        weights = [
            1.0
            if abs(value - location) <= delta
            else delta / abs(value - location)
            for value in observations
        ]
        weight_sum = sum(weights)
        weighted_sum = sum(
            weight * value for weight, value in zip(weights, observations)
        )
        if (
            not math.isfinite(weight_sum)
            or weight_sum <= 0.0
            or not math.isfinite(weighted_sum)
        ):
            return None
        location = weighted_sum / weight_sum
        if not math.isfinite(location):
            return None

    direction = (location > epsilon) - (location < -epsilon)
    return HuberResult(
        observations=tuple(observations),
        median=median,
        mad=mad,
        scale=scale,
        delta=delta,
        location=location,
        direction=direction,
    )


def signed_rank_direction(observations: list[float]) -> int:
    magnitudes = [abs(value) for value in observations]
    if len(observations) != 10 or len(set(magnitudes)) != 10:
        raise ValueError("fixture requires ten unique nonzero magnitudes")
    ranks = [1 + sum(other < value for other in magnitudes) for value in magnitudes]
    score = sum(
        rank if value > 0.0 else -rank
        for rank, value in zip(ranks, observations)
    )
    return (score > 0) - (score < 0)


def monthly_exit_due(opened: dt.datetime, current: dt.datetime) -> bool:
    return month_key(opened) != month_key(current)


def stale_exit_due(
    opened: dt.datetime, current: dt.datetime, maximum_days: int = 40
) -> bool:
    return current - opened >= maximum_days * DAY


class AttemptLedger:
    def __init__(self, storage: dict[str, int], key: str = "attempt") -> None:
        self.storage = storage
        self.key = key
        self.month = storage.get(key)

    def consume_before(self, month: int, downstream_gate: bool) -> bool:
        if self.month == month:
            return False
        self.month = month
        self.storage[self.key] = month
        return downstream_gate


class SameCalendarHuberTenReferenceTests(unittest.TestCase):
    def test_native_and_prior_day_month_boundaries(self) -> None:
        native = is_month_boundary(
            dt.datetime(2026, 8, 3),
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 8, 3, 1),
        )
        prior_day = is_month_boundary(
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 7, 30),
            dt.datetime(2026, 8, 1, 1),
        )
        self.assertEqual(native, (True, 0))
        self.assertEqual(prior_day, (True, 1))
        self.assertFalse(
            is_month_boundary(
                dt.datetime(2026, 8, 18),
                dt.datetime(2026, 8, 17),
                dt.datetime(2026, 8, 18, 1),
            )[0]
        )

    def test_exact_completed_month_endpoints_and_year_wrap(self) -> None:
        bars = (
            Bar(dt.datetime(2025, 12, 31), 90.0),
            Bar(dt.datetime(2026, 1, 2), 92.0),
            Bar(dt.datetime(2026, 1, 30), 99.0),
            Bar(dt.datetime(2026, 2, 2), 101.0),
        )
        observed = completed_month_return(bars, 202601, 0)
        self.assertIsNotNone(observed)
        self.assertAlmostEqual(observed or 0.0, math.log(99.0 / 90.0))
        self.assertEqual(adjacent_month(202601, -1), 202512)
        self.assertEqual(adjacent_month(202512, 1), 202601)

    def test_partial_or_nonmonotone_endpoints_fail_closed(self) -> None:
        missing_prior = (
            Bar(dt.datetime(2026, 1, 2), 92.0),
            Bar(dt.datetime(2026, 1, 30), 99.0),
            Bar(dt.datetime(2026, 2, 2), 101.0),
        )
        nonmonotone = (
            Bar(dt.datetime(2025, 12, 31), 90.0),
            Bar(dt.datetime(2026, 1, 30), 99.0),
            Bar(dt.datetime(2026, 1, 2), 92.0),
            Bar(dt.datetime(2026, 2, 2), 101.0),
        )
        self.assertIsNone(completed_month_return(missing_prior, 202601, 0))
        self.assertIsNone(completed_month_return(nonmonotone, 202601, 0))

    def test_exact_prior_ten_years_allow_no_skip_or_substitution(self) -> None:
        values = {
            (2026 - offset) * 100 + 1: offset / 1000.0
            for offset in range(1, 12)
        }
        self.assertEqual(
            exact_prior_ten_sample(values, 202601),
            [offset / 1000.0 for offset in range(1, 11)],
        )
        del values[202301]
        self.assertIsNone(exact_prior_ten_sample(values, 202601))

    def test_paired_difference_orientation_and_synchronization(self) -> None:
        wanted = [
            0.0188,
            -0.0148,
            0.0122,
            0.0021,
            -0.0084,
            -0.0013,
            0.0012,
            0.0006,
            0.0058,
            -0.0160,
        ]
        xag = [0.01] * 10
        xau = [silver + relative for silver, relative in zip(xag, wanted)]
        observed = paired_relative_returns(xau, xag)
        self.assertIsNotNone(observed)
        assert observed is not None
        for actual, expected in zip(observed, wanted):
            self.assertAlmostEqual(actual, expected, places=14)
        self.assertIsNone(paired_relative_returns(xau[:-1], xag))

    def test_even_median_mad_frozen_scale_and_exact_updates(self) -> None:
        observations = [
            0.0188,
            -0.0148,
            0.0122,
            0.0021,
            -0.0084,
            -0.0013,
            0.0012,
            0.0006,
            0.0058,
            -0.0160,
        ]
        result = huber_direction(observations)
        one_step = huber_direction(observations, steps=1)
        self.assertIsNotNone(result)
        self.assertIsNotNone(one_step)
        assert result is not None and one_step is not None
        self.assertAlmostEqual(result.median, 0.0009)
        self.assertAlmostEqual(result.mad, 0.0071)
        self.assertAlmostEqual(result.scale, 0.01052646)
        self.assertAlmostEqual(result.delta, 0.01578969)
        self.assertAlmostEqual(result.location, -0.00031225666666666747)
        self.assertNotAlmostEqual(one_step.location, result.location, places=8)

    def test_locked_disagreement_vector_is_not_neighbor_logic(self) -> None:
        observations = [
            0.0188,
            -0.0148,
            0.0122,
            0.0021,
            -0.0084,
            -0.0013,
            0.0012,
            0.0006,
            0.0058,
            -0.0160,
        ]
        result = huber_direction(observations)
        assert result is not None
        self.assertEqual(result.direction, -1)
        self.assertGreater(statistics.mean(observations), 0.0)
        self.assertGreater(statistics.median(observations), 0.0)
        self.assertEqual(signed_rank_direction(observations), 1)

    def test_count_nonfinite_zero_mad_and_epsilon_fail_closed(self) -> None:
        self.assertIsNone(huber_direction([0.01] * 9))
        self.assertIsNone(huber_direction([0.01] * 9 + [math.nan]))
        self.assertIsNone(huber_direction([0.01] * 10))
        symmetric = [
            -5e-13,
            -4e-13,
            -3e-13,
            -2e-13,
            -1e-13,
            1e-13,
            2e-13,
            3e-13,
            4e-13,
            5e-13,
        ]
        tied = huber_direction(symmetric)
        self.assertIsNotNone(tied)
        self.assertEqual(tied.direction if tied else 1, 0)

    def test_attempt_is_consumed_before_failure_and_survives_restart(self) -> None:
        storage: dict[str, int] = {}
        first_process = AttemptLedger(storage)
        self.assertFalse(first_process.consume_before(202608, downstream_gate=False))
        self.assertFalse(first_process.consume_before(202608, downstream_gate=True))
        restarted = AttemptLedger(storage)
        self.assertFalse(restarted.consume_before(202608, downstream_gate=True))
        self.assertTrue(restarted.consume_before(202609, downstream_gate=True))

    def test_monthly_renewal_and_forty_day_survivor_guard(self) -> None:
        opened = dt.datetime(2026, 8, 3, 1)
        self.assertFalse(monthly_exit_due(opened, dt.datetime(2026, 8, 31)))
        self.assertTrue(monthly_exit_due(opened, dt.datetime(2026, 9, 1)))
        self.assertFalse(stale_exit_due(opened, opened + 40 * DAY - DAY / 2))
        self.assertTrue(stale_exit_due(opened, opened + 40 * DAY))

    def test_static_build_contract_matches_approved_card(self) -> None:
        source_path = EA_DIR / "QM5_41206_xauxag-samecal-huber10.mq5"
        source = source_path.read_text(encoding="utf-8")
        setfile = (
            EA_DIR
            / "sets"
            / (
                "QM5_41206_xauxag-samecal-huber10_"
                "QM5_41206_XAU_XAG_SAMECAL_HUBER10_D1_D1_backtest.set"
            )
        ).read_text(encoding="utf-8")
        for marker in (
            "input int    qm_ea_id                    = 41206;",
            'input string strategy_xag_symbol            = "XAGUSD.DWX";',
            "input int    strategy_history_years          = 10;",
            "input int    strategy_required_observations = 10;",
            "input double strategy_mad_normalizer         = 1.4826;",
            "input double strategy_huber_tuning           = 1.5;",
            "input int    strategy_huber_steps            = 32;",
            "(sorted_values[4] + sorted_values[5]) / 2.0;",
            "(absolute_deviations[4] + absolute_deviations[5]) / 2.0;",
            "scale_value = strategy_mad_normalizer * mad_value;",
            "delta_value = strategy_huber_tuning * scale_value;",
            "for(int step = 0; step < strategy_huber_steps; ++step)",
            "(residual <= delta_value) ? 1.0 : delta_value / residual;",
            "Strategy_ConsumePeriodAttempt(g_cache_period_key)",
            "Strategy_LoadSignalState(g_cache_decision_month_key",
            "ArraySetAsSeries(xau_rates, false);",
            "ArraySetAsSeries(xag_rates, false);",
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
            "matrix",
            "machine learning",
            "winsorizedsignal",
        ):
            self.assertNotIn(banned, source.lower())

        entry = source[
            source.index("bool Strategy_EntrySignal") :
            source.index("void Strategy_ManageOpenPosition")
        ]
        self.assertLess(
            entry.index("Strategy_ConsumePeriodAttempt(g_cache_period_key)"),
            entry.index("Strategy_LoadSignalState"),
        )
        loader = source[
            source.index("bool Strategy_LoadSignalState") :
            source.index("bool Strategy_IsPairMagic")
        ].lower()
        for forbidden_current_month_input in (
            "symbolinfo",
            "tickvolume",
            "real_volume",
            "current_month_return",
        ):
            self.assertNotIn(forbidden_current_month_input, loader)

        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("QM_FrameworkTrackOpenPositionMae();"),
            on_tick.index("Strategy_NoTradeFilter()"),
        )
        for marker in (
            "qm_ea_id=41206",
            "qm_magic_slot_offset=0",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "strategy_xag_symbol=XAGUSD.DWX",
            "strategy_history_years=10",
            "strategy_required_observations=10",
            "strategy_mad_normalizer=1.4826",
            "strategy_huber_tuning=1.5",
            "strategy_huber_steps=32",
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
            setfile,
            r"(?m)^; build_hash:\s+(?:pending|[0-9a-f]{64})$",
        )
        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41206_xauxag-samecal-huber10_card.md"
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
            "41206,xauxag-samecal-huber10,0,XAUUSD.DWX,412060000",
            magic_rows,
        )
        self.assertIn(
            "41206,xauxag-samecal-huber10,1,XAGUSD.DWX,412060001",
            magic_rows,
        )
        resolver = (
            REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("412060000", resolver)
        self.assertIn("412060001", resolver)

        basket = json.loads(
            (EA_DIR / "basket_manifest.json").read_text(encoding="utf-8")
        )
        self.assertEqual(
            basket["logical_symbol"],
            "QM5_41206_XAU_XAG_SAMECAL_HUBER10_D1",
        )
        self.assertEqual(basket["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(
            basket["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"]
        )
        self.assertEqual(basket["traded_symbols"], basket["basket_symbols"])


if __name__ == "__main__":
    unittest.main()
