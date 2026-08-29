"""Independent deterministic fixtures for QM5_41208.

The suite covers normalized month labels, exact completed-month endpoints,
realized-observation exclusion, missing-year skips, five-through-ten-sample
arithmetic, n-1 scaling, strict z boundaries, contrarian direction, durable
monthly attempts, quote/spread reachability, lifecycle repair, and static
card/build conformance. It does not invoke MT5 order plumbing.
"""

from __future__ import annotations

import datetime as dt
import math
import statistics
import unittest
from dataclasses import dataclass
from pathlib import Path


DAY = dt.timedelta(days=1)
ENTRY_Z = 0.50
TOLERANCE = 1.0e-10
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]


@dataclass(frozen=True)
class Bar:
    label: dt.datetime
    close: float


@dataclass(frozen=True)
class SurpriseResult:
    realized: float
    observations: tuple[float, ...]
    mean: float
    sample_sd: float
    z: float
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
    bars: tuple[Bar, ...],
    target_month: int,
    label_offset_days: int,
    terminal_following_month: int = 0,
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
    if first == 0 or indices != list(range(first, last + 1)):
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
    if last + 1 < len(normalized):
        if month_key(normalized[last + 1].label) != adjacent_month(
            target_month, 1
        ):
            return None
    elif terminal_following_month != adjacent_month(target_month, 1):
        return None
    prior_close = normalized[first - 1].close
    end_close = normalized[last].close
    if not all(
        math.isfinite(value) and value > 0.0
        for value in (prior_close, end_close)
    ):
        return None
    return math.log(end_close / prior_close)


def same_calendar_sample(
    returns_by_month: dict[int, float],
    realized_month: int,
    *,
    history_years: int = 10,
    minimum: int = 5,
) -> list[float] | None:
    year, month = divmod(realized_month, 100)
    observations: list[float] = []
    for offset in range(1, history_years + 1):
        key = (year - offset) * 100 + month
        value = returns_by_month.get(key)
        if value is None:
            continue
        if not math.isfinite(value):
            continue
        observations.append(value)
    return observations if len(observations) >= minimum else None


def seasonal_surprise(
    realized: float, observations: list[float]
) -> SurpriseResult | None:
    if not math.isfinite(realized) or not 5 <= len(observations) <= 10:
        return None
    if not all(math.isfinite(value) for value in observations):
        return None
    mean = sum(observations) / len(observations)
    variance = sum((value - mean) ** 2 for value in observations) / (
        len(observations) - 1
    )
    if not math.isfinite(variance) or variance <= 0.0:
        return None
    sample_sd = math.sqrt(variance)
    z = (realized - mean) / sample_sd
    if not math.isfinite(z):
        return None
    boundary = ENTRY_Z + TOLERANCE
    direction = -1 if z > boundary else 1 if z < -boundary else 0
    return SurpriseResult(
        realized=realized,
        observations=tuple(observations),
        mean=mean,
        sample_sd=sample_sd,
        z=z,
        direction=direction,
    )


def quote_spread_allows(bid: float, ask: float, point: float) -> bool:
    if not all(math.isfinite(value) for value in (bid, ask, point)):
        return False
    if bid <= 0.0 or ask <= 0.0 or point <= 0.0 or ask < bid:
        return False
    spread_points = (ask - bid) / point
    return math.isfinite(spread_points) and 0.0 <= spread_points <= 3000.0


def monthly_exit_due(opened: dt.datetime, current: dt.datetime) -> bool:
    return month_key(opened) != month_key(current)


def stale_exit_due(opened: dt.datetime, current: dt.datetime) -> bool:
    return current - opened >= 40 * DAY


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


class SeasonalSurpriseReferenceTests(unittest.TestCase):
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

    def test_realized_terminal_endpoint_and_year_wrap(self) -> None:
        bars = (
            Bar(dt.datetime(2025, 11, 28), 90.0),
            Bar(dt.datetime(2025, 12, 1), 92.0),
            Bar(dt.datetime(2025, 12, 31), 99.0),
        )
        observed = completed_month_return(
            bars, 202512, 0, terminal_following_month=202601
        )
        self.assertIsNotNone(observed)
        self.assertAlmostEqual(observed or 0.0, math.log(99.0 / 90.0))
        self.assertEqual(adjacent_month(202601, -1), 202512)
        self.assertIsNone(completed_month_return(bars, 202512, 0))

    def test_historical_endpoint_requires_both_neighbor_months(self) -> None:
        complete = (
            Bar(dt.datetime(2019, 6, 28), 3.0),
            Bar(dt.datetime(2019, 7, 1), 3.1),
            Bar(dt.datetime(2019, 7, 31), 3.3),
            Bar(dt.datetime(2019, 8, 1), 3.2),
        )
        self.assertAlmostEqual(
            completed_month_return(complete, 201907, 0) or 0.0,
            math.log(3.3 / 3.0),
        )
        self.assertIsNone(completed_month_return(complete[1:], 201907, 0))

    def test_missing_year_is_skipped_without_substitution(self) -> None:
        values = {
            (2026 - offset) * 100 + 7: offset / 100.0
            for offset in range(1, 13)
        }
        del values[202307]
        values[202607] = 99.0
        sample = same_calendar_sample(values, 202607)
        self.assertIsNotNone(sample)
        self.assertEqual(len(sample or []), 9)
        self.assertNotIn(99.0, sample or [])
        self.assertNotIn(11 / 100.0, sample or [])
        self.assertNotIn(12 / 100.0, sample or [])
        sparse = dict(list(values.items())[:4])
        self.assertIsNone(same_calendar_sample(sparse, 202607))

    def test_five_through_ten_use_arithmetic_mean_and_n_minus_one(self) -> None:
        base = [-0.14, -0.12, -0.11, -0.10, -0.09, -0.08, -0.07, -0.06, -0.05, -0.04]
        for count in range(5, 11):
            observations = base[:count]
            result = seasonal_surprise(-0.02, observations)
            self.assertIsNotNone(result)
            assert result is not None
            self.assertAlmostEqual(result.mean, statistics.mean(observations))
            self.assertAlmostEqual(result.sample_sd, statistics.stdev(observations))
            self.assertEqual(result.direction, -1)

    def test_strict_boundaries_and_contrarian_sides(self) -> None:
        observations = [-2.0, -1.0, 0.0, 1.0, 2.0]
        sample_sd = statistics.stdev(observations)
        boundary = ENTRY_Z + TOLERANCE
        equal_high = seasonal_surprise(boundary * sample_sd, observations)
        equal_low = seasonal_surprise(-boundary * sample_sd, observations)
        above = seasonal_surprise((boundary + 1e-8) * sample_sd, observations)
        below = seasonal_surprise(-(boundary + 1e-8) * sample_sd, observations)
        self.assertEqual(equal_high.direction if equal_high else 9, 0)
        self.assertEqual(equal_low.direction if equal_low else 9, 0)
        self.assertEqual(above.direction if above else 9, -1)
        self.assertEqual(below.direction if below else 9, 1)

    def test_seasonal_adjustment_differs_from_raw_month_fade(self) -> None:
        observations = [-0.14, -0.12, -0.11, -0.10, -0.09, -0.08]
        realized = -0.02
        result = seasonal_surprise(realized, observations)
        self.assertIsNotNone(result)
        self.assertEqual(result.direction if result else 9, -1)
        unconditional_one_month_contrarian = 1
        self.assertNotEqual(result.direction if result else 1, unconditional_one_month_contrarian)

    def test_nonfinite_short_and_zero_scale_fail_closed(self) -> None:
        self.assertIsNone(seasonal_surprise(0.1, [0.0] * 5))
        self.assertIsNone(seasonal_surprise(math.nan, [-2, -1, 0, 1, 2]))
        self.assertIsNone(seasonal_surprise(0.1, [-2, -1, 0, 1]))
        self.assertIsNone(seasonal_surprise(0.1, [-2, -1, 0, 1, math.inf]))

    def test_zero_spread_reachable_crossed_and_excessive_rejected(self) -> None:
        self.assertTrue(quote_spread_allows(2.5, 2.5, 0.001))
        self.assertTrue(quote_spread_allows(2.5, 5.5, 0.001))
        self.assertFalse(quote_spread_allows(2.5, 5.501, 0.001))
        self.assertFalse(quote_spread_allows(2.5, 2.4, 0.001))

    def test_attempt_is_consumed_before_failure_and_survives_restart(self) -> None:
        storage: dict[str, int] = {}
        first_process = AttemptLedger(storage)
        self.assertFalse(first_process.consume_before(202608, downstream_gate=False))
        self.assertFalse(first_process.consume_before(202608, downstream_gate=True))
        restarted = AttemptLedger(storage)
        self.assertFalse(restarted.consume_before(202608, downstream_gate=True))
        self.assertTrue(restarted.consume_before(202609, downstream_gate=True))

    def test_monthly_renewal_and_forty_day_stale_guard(self) -> None:
        opened = dt.datetime(2026, 8, 3, 1)
        self.assertFalse(monthly_exit_due(opened, dt.datetime(2026, 8, 31)))
        self.assertTrue(monthly_exit_due(opened, dt.datetime(2026, 9, 1)))
        self.assertFalse(stale_exit_due(opened, opened + 40 * DAY - DAY / 2))
        self.assertTrue(stale_exit_due(opened, opened + 40 * DAY))

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41208_xng-seas-surprise-rv.mq5").read_text(encoding="utf-8")
        set_path = EA_DIR / "sets" / "QM5_41208_xng-seas-surprise-rv_XNGUSD.DWX_D1_backtest.set"
        setfile = set_path.read_text(encoding="utf-8")
        for marker in (
            "input int    qm_ea_id                     = 41208;",
            "input int    strategy_history_years        = 10;",
            "input int    strategy_min_observations     = 5;",
            "input double strategy_entry_z              = 0.50;",
            "input double strategy_signal_tolerance     = 1.0e-10;",
            "squared_deviation_sum / (double)(sample_count - 1);",
            "if(surprise_z > boundary)",
            "else if(surprise_z < -boundary)",
            "Strategy_RecordMonthAttempt(g_decision_month_key)",
            "req.tp = 0.0;",
            "strategy_atr_period_d1, 1);",
            "strategy_atr_sl_mult);",
            "tick.ask < tick.bid",
            "QM_FRIDAY_CLOSE_DISABLED",
            "QM_FrameworkTrackOpenPositionMae();",
        ):
            self.assertIn(marker, source)
        for banned in (
            "irsi(", "imacd(", "ibands(", "webrequest(", "fileopen(",
            "matrix", "machine learning", "huber", "median", "winsor",
        ):
            self.assertNotIn(banned, source.lower())

        prepare = source[source.index("void Strategy_PrepareDecisionSignal()") : source.index("bool Strategy_NoTradeFilter()")]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt(g_decision_month_key)"),
            prepare.index("Strategy_LoadSeasonalSurpriseSignal"),
        )
        loader = source[source.index("bool Strategy_LoadSeasonalSurpriseSignal") : source.index("void Strategy_PrepareDecisionSignal()")].lower()
        for forbidden in ("symbolinfo", "tickvolume", "real_volume", "current_month_return"):
            self.assertNotIn(forbidden, loader)

        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(on_tick.index("Strategy_ManageOpenPosition();"), on_tick.index("Strategy_NoTradeFilter()"))
        for marker in (
            "qm_ea_id=41208",
            "qm_magic_slot_offset=0",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "strategy_history_years=10",
            "strategy_min_observations=5",
            "strategy_entry_z=0.50",
            "strategy_signal_tolerance=0.0000000001",
            "strategy_history_bars_d1=3000",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
            "strategy_max_hold_days=40",
            "strategy_max_spread_points=3000",
        ):
            self.assertIn(marker, setfile)
        self.assertRegex(setfile, r"(?m)^; build_hash:\s+(?:pending|[0-9a-f]{64})$")
        self.assertEqual([set_path], list((EA_DIR / "sets").glob("*.set")))
        self.assertEqual([], list((EA_DIR / "sets").glob("*live*")))

        approved = REPO_ROOT / "strategy-seeds" / "cards" / "approved" / "QM5_41208_xng-seas-surprise-rv_card.md"
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local.read_text(encoding="utf-8").rstrip(), approved.read_text(encoding="utf-8").rstrip())
        magic_rows = (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").read_text(encoding="utf-8-sig")
        self.assertIn("41208,xng-seas-surprise-rv,0,XNGUSD.DWX,412080000", magic_rows)
        resolver = (REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh").read_text(encoding="utf-8")
        self.assertIn("412080000", resolver)


if __name__ == "__main__":
    unittest.main()
