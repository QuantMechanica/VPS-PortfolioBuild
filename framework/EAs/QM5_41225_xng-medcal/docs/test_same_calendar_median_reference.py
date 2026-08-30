"""Independent deterministic fixtures for QM5_41225.

The suite covers normalized XNG D1 labels, completed-month endpoints, exact
Y-1..Y-10 sampling, ordinary odd/even sample medians, durable monthly
attempts, quote and lifecycle boundaries, non-duplicate disagreement vectors,
and static card/build conformance. It does not invoke MT5.
"""

from __future__ import annotations

import datetime as dt
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


def date_key(value: dt.datetime) -> int:
    return value.year * 10000 + value.month * 100 + value.day


def month_key(value: dt.datetime) -> int:
    return value.year * 100 + value.month


def adjacent_month(value: int, step: int) -> int:
    year, month = divmod(value, 100)
    month += step
    if month == 0:
        return (year - 1) * 100 + 12
    if month == 13:
        return (year + 1) * 100 + 1
    return year * 100 + month


def normalized_sessions(
    current_label: dt.datetime,
    previous_label: dt.datetime,
    broker_now: dt.datetime,
) -> tuple[dt.datetime, dt.datetime, int] | None:
    elapsed = broker_now - current_label
    if dt.timedelta(0) <= elapsed < DAY:
        offset = 0
    elif DAY <= elapsed < 2 * DAY:
        offset = 1
    else:
        return None
    current = current_label + offset * DAY
    previous = previous_label + offset * DAY
    if (
        current <= previous
        or date_key(current) != date_key(broker_now)
        or adjacent_month(month_key(previous), 1) != month_key(current)
    ):
        return None
    return current, previous, offset


def completed_month_return(
    bars: tuple[Bar, ...], target_month: int, label_offset_days: int
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
        if month_key(bar.label) == target_month
    ]
    if not indices:
        return None
    first, last = indices[0], indices[-1]
    if first <= 0 or last + 1 >= len(normalized):
        return None
    if indices != list(range(first, last + 1)):
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


def median_signal(
    observations: list[float],
    minimum: int = 5,
    maximum: int = 10,
    epsilon: float = EPSILON,
) -> tuple[float | None, int]:
    if not minimum <= len(observations) <= maximum:
        return None, 0
    if not all(math.isfinite(value) for value in observations):
        return None, 0
    ordered = sorted(observations)
    middle = len(ordered) // 2
    if len(ordered) % 2:
        median = ordered[middle]
    else:
        median = (ordered[middle - 1] + ordered[middle]) / 2.0
    direction = (median > epsilon) - (median < -epsilon)
    return median, direction


def sign_score_direction(observations: list[float]) -> int:
    successes = sum(value >= 0.0 for value in observations)
    score = (2 * successes - len(observations)) / math.sqrt(
        len(observations)
    )
    return (score > 1.0 + 1.0e-10) - (score < -1.0 - 1.0e-10)


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
    spread = (ask - bid) / point
    return (
        math.isfinite(spread)
        and 0.0 <= spread <= maximum_spread_points
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
    return current >= opened + 35 * DAY


def exit_due(opened: dt.datetime, current: dt.datetime) -> bool:
    return month_key(opened) != month_key(current) or stale_exit_due(
        opened, current
    )


class SameCalendarMedianReferenceTests(unittest.TestCase):
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
        self.assertIsNone(
            normalized_sessions(
                dt.datetime(2026, 8, 18),
                dt.datetime(2026, 8, 17),
                dt.datetime(2026, 8, 18, 1),
            )
        )

    def test_completed_month_uses_prior_close_and_confirmation(self) -> None:
        bars = (
            Bar(dt.datetime(2025, 12, 30), 90.0),
            Bar(dt.datetime(2026, 1, 1), 92.0),
            Bar(dt.datetime(2026, 1, 29), 99.0),
            Bar(dt.datetime(2026, 2, 1), 101.0),
        )
        observed = completed_month_return(bars, 202601, 1)
        self.assertIsNotNone(observed)
        self.assertAlmostEqual(observed or 0.0, math.log(99.0 / 90.0))
        self.assertIsNone(completed_month_return(bars[:-1], 202601, 1))

    def test_december_january_wrap_is_exact(self) -> None:
        self.assertEqual(adjacent_month(202601, -1), 202512)
        self.assertEqual(adjacent_month(202512, 1), 202601)

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
        self.assertIsNone(
            exact_prior_sample({(2025, 1): 0.01}, 2026, 1)
        )

    def test_odd_and_even_medians_use_center_only(self) -> None:
        odd, odd_direction = median_signal(
            [-0.04, 0.01, 0.03, 0.02, 0.50]
        )
        even, even_direction = median_signal(
            [-0.04, -0.01, 0.02, 0.04, 0.10, 0.50]
        )
        self.assertAlmostEqual(odd or 0.0, 0.02)
        self.assertEqual(odd_direction, 1)
        self.assertAlmostEqual(even or 0.0, 0.03)
        self.assertEqual(even_direction, 1)

    def test_mean_and_median_lock_opposite_directions(self) -> None:
        observations = [0.01, 0.01, 0.01, 0.01, -0.20]
        median, direction = median_signal(observations)
        self.assertGreater(median or 0.0, 0.0)
        self.assertEqual(direction, 1)
        self.assertLess(statistics.mean(observations), 0.0)

    def test_sign_score_can_abstain_while_median_buys(self) -> None:
        observations = [0.001, -0.20, -0.20, 0.20, 0.20]
        median, direction = median_signal(observations)
        self.assertGreater(median or 0.0, 0.0)
        self.assertEqual(direction, 1)
        self.assertEqual(sign_score_direction(observations), 0)

    def test_sample_bounds_nonfinite_and_epsilon_fail_closed(self) -> None:
        self.assertEqual(median_signal([0.01] * 4), (None, 0))
        self.assertEqual(median_signal([0.01] * 11), (None, 0))
        self.assertEqual(median_signal([0.01] * 4 + [math.nan]), (None, 0))
        self.assertEqual(median_signal([EPSILON] * 5)[1], 0)
        self.assertEqual(median_signal([-EPSILON] * 5)[1], 0)
        self.assertEqual(median_signal([2 * EPSILON] * 5)[1], 1)
        self.assertEqual(median_signal([-2 * EPSILON] * 5)[1], -1)

    def test_attempt_consumes_before_failure_and_survives_restart(self) -> None:
        storage: dict[str, int] = {}
        first = AttemptLedger(storage)
        self.assertFalse(first.consume_before(202608, downstream_gate=False))
        self.assertFalse(first.consume_before(202608, downstream_gate=True))
        restarted = AttemptLedger(storage)
        self.assertFalse(restarted.consume_before(202608, downstream_gate=True))
        self.assertTrue(restarted.consume_before(202609, downstream_gate=True))

    def test_quote_boundaries_accept_zero_and_cap(self) -> None:
        self.assertTrue(quote_allows(2.5, 2.5, 0.001))
        self.assertTrue(quote_allows(2.5, 5.5, 0.001))
        self.assertFalse(quote_allows(2.5, 5.501, 0.001))
        self.assertFalse(quote_allows(2.501, 2.5, 0.001))

    def test_next_month_and_exact_thirty_five_day_stale_exit(self) -> None:
        opened = dt.datetime(2026, 1, 3)
        self.assertFalse(stale_exit_due(opened, opened + 34 * DAY))
        self.assertTrue(stale_exit_due(opened, opened + 35 * DAY))
        self.assertTrue(exit_due(opened, dt.datetime(2026, 2, 2)))

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41225_xng-medcal.mq5").read_text(
            encoding="utf-8"
        )
        set_path = (
            EA_DIR
            / "sets"
            / "QM5_41225_xng-medcal_XNGUSD.DWX_D1_backtest.set"
        )
        setfile = set_path.read_text(encoding="utf-8")
        for marker in (
            "qm_ea_id                     = 41225;",
            "qm_rng_seed                  = 42;",
            "RISK_PERCENT                 = 0.0;",
            "RISK_FIXED                   = 1000.0;",
            "qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;",
            "qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;",
            "qm_friday_close_enabled       = false;",
            "qm_stress_reject_probability  = 0.0;",
            'const string g_symbol = "XNGUSD.DWX";',
            "strategy_lookback_years       = 10;",
            "strategy_min_observations     = 5;",
            "strategy_history_bars_d1      = 3000;",
            "strategy_signal_epsilon       = 1.0e-12;",
            "Strategy_CompletedMonthReturn",
            "Strategy_MedianSignal",
            "Strategy_SortAscending",
            "ArraySetAsSeries(rates, false);",
            "Strategy_NormalizedLabel",
            "Strategy_RecordMonthAttempt(g_decision_month_key)",
            "modeled_spread_points < 0.0",
            "req.tp = 0.0;",
            "strategy_atr_period_d1, 1);",
            "strategy_atr_sl_mult);",
            "QM_FrameworkTrackOpenPositionMae();",
        ):
            self.assertIn(marker, source)
        for banned in (
            "irsi(",
            "imacd(",
            "ibands(",
            "webrequest(",
            "fileopen(",
            "strategy_huber",
            "strategy_sign_score",
            "strategy_sample_mean",
            "continuity_correction",
        ):
            self.assertNotIn(banned, source.lower())
        self.assertNotIn(
            "SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)", source
        )

        prepare = source[
            source.index("void Strategy_PrepareDecisionSignal") :
            source.index("bool Strategy_NoTradeFilter")
        ]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadMedianSignal"),
        )
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("QM_FrameworkTrackOpenPositionMae();"),
            on_tick.index("Strategy_NoTradeFilter()"),
        )

        for marker in (
            "qm_ea_id=41225",
            "qm_magic_slot_offset=0",
            "qm_rng_seed=42",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_news_temporal=0",
            "qm_news_compliance=0",
            "qm_friday_close_enabled=false",
            "strategy_lookback_years=10",
            "strategy_min_observations=5",
            "strategy_history_bars_d1=3000",
            "strategy_signal_epsilon=0.000000000001",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
            "strategy_max_hold_days=35",
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
            / "QM5_41225_xng-medcal_card.md"
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
            "41225,xng-medcal,0,XNGUSD.DWX,412250000", magic_rows
        )
        resolver = (
            REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("412250000", resolver)


if __name__ == "__main__":
    unittest.main()
