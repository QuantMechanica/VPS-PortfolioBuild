"""Independent deterministic fixtures for QM5_41202.

The suite covers native and prior-day energy-label normalization, exact
completed calendar-month endpoints, the all-or-nothing Y-1..Y-5 sample, all
five sorted observations, exact one-per-tail capping, the retained five-term
mean, durable monthly attempts, lifecycle repair, and static card/build conformance.  It
does not invoke MT5 or duplicate framework order plumbing.
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


@dataclass(frozen=True)
class WinsorizedResult:
    observations: tuple[float, ...]
    ordered: tuple[float, ...]
    retained: tuple[float, ...]
    value: float
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


def exact_prior_five_sample(
    returns_by_month: dict[int, float], decision_month: int
) -> list[float] | None:
    year, month = divmod(decision_month, 100)
    required = [(year - offset) * 100 + month for offset in range(1, 6)]
    if any(key not in returns_by_month for key in required):
        return None
    sample = [returns_by_month[key] for key in required]
    if not all(math.isfinite(value) for value in sample):
        return None
    return sample


def winsorized_direction(
    observations: list[float], epsilon: float = EPSILON
) -> WinsorizedResult | None:
    if len(observations) != 5:
        return None
    if not all(math.isfinite(value) for value in observations):
        return None
    ordered = tuple(sorted(observations))
    retained = (ordered[1], ordered[1], ordered[2], ordered[3], ordered[3])
    value = sum(retained) / 5.0
    direction = (value > epsilon) - (value < -epsilon)
    return WinsorizedResult(
        observations=tuple(observations),
        ordered=ordered,
        retained=retained,
        value=value,
        direction=direction,
    )


def trimmed_mean(observations: list[float]) -> float:
    ordered = sorted(observations)
    return sum(ordered[1:4]) / 3.0


def pairwise_central(observations: list[float]) -> float:
    pairs = sorted(
        (observations[left] + observations[right]) / 2.0
        for left in range(5)
        for right in range(left, 5)
    )
    return pairs[7]


def ten_year_signed_rank_direction(observations: list[float]) -> int:
    if len(observations) != 10:
        raise ValueError("the signed-rank neighbor requires ten years")
    if not all(math.isfinite(value) and value != 0.0 for value in observations):
        raise ValueError("invalid signed-rank sample")
    magnitudes = [abs(value) for value in observations]
    if len(set(magnitudes)) != len(magnitudes):
        raise ValueError("tie handling is outside this structural fixture")
    ranks = [1 + sum(other < value for other in magnitudes) for value in magnitudes]
    score = sum(
        rank if value > 0.0 else -rank
        for rank, value in zip(ranks, observations)
    )
    return (score > 0) - (score < 0)


def monthly_exit_due(opened: dt.datetime, current: dt.datetime) -> bool:
    return month_key(opened) != month_key(current)


def stale_exit_due(
    opened: dt.datetime, current: dt.datetime, maximum_days: int = 35
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


class SameCalendarWinsorizedFiveReferenceTests(unittest.TestCase):
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
        self.assertEqual(
            is_month_boundary(
                dt.datetime(2026, 8, 18),
                dt.datetime(2026, 8, 17),
                dt.datetime(2026, 8, 18, 1),
            )[0],
            False,
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

    def test_partial_or_malformed_endpoints_fail_closed(self) -> None:
        missing_prior = (
            Bar(dt.datetime(2026, 1, 2), 92.0),
            Bar(dt.datetime(2026, 1, 30), 99.0),
            Bar(dt.datetime(2026, 2, 2), 101.0),
        )
        missing_following = (
            Bar(dt.datetime(2025, 12, 31), 90.0),
            Bar(dt.datetime(2026, 1, 2), 92.0),
            Bar(dt.datetime(2026, 1, 30), 99.0),
        )
        nonmonotone = (
            Bar(dt.datetime(2025, 12, 31), 90.0),
            Bar(dt.datetime(2026, 1, 30), 99.0),
            Bar(dt.datetime(2026, 1, 2), 92.0),
            Bar(dt.datetime(2026, 2, 2), 101.0),
        )
        self.assertIsNone(completed_month_return(missing_prior, 202601, 0))
        self.assertIsNone(completed_month_return(missing_following, 202601, 0))
        self.assertIsNone(completed_month_return(nonmonotone, 202601, 0))

    def test_exact_prior_five_years_allow_no_skip_or_substitution(self) -> None:
        values = {
            202501: 0.01,
            202401: 0.02,
            202301: -0.03,
            202201: 0.04,
            202101: 0.05,
            202001: -9.99,
        }
        self.assertEqual(
            exact_prior_five_sample(values, 202601),
            [0.01, 0.02, -0.03, 0.04, 0.05],
        )
        del values[202301]
        self.assertIsNone(exact_prior_five_sample(values, 202601))

    def test_exact_one_per_tail_cap_and_five_term_mean(self) -> None:
        observations = [0.11, -0.07, 0.03, 0.08, 0.01]
        result = winsorized_direction(observations)
        self.assertIsNotNone(result)
        assert result is not None
        self.assertEqual(result.ordered, (-0.07, 0.01, 0.03, 0.08, 0.11))
        self.assertEqual(result.retained, (0.01, 0.01, 0.03, 0.08, 0.08))
        self.assertAlmostEqual(result.value, (2 * 0.01 + 0.03 + 2 * 0.08) / 5)

    def test_locked_neighbor_disagreement_vectors(self) -> None:
        short_vector = [-12.0, -11.0, 3.0, 9.0, 10.0]
        long_vector = [-12.0, -9.0, 3.0, 8.0, 9.0]
        long_result = winsorized_direction(long_vector)
        short_result = winsorized_direction(short_vector)
        assert long_result is not None and short_result is not None
        self.assertAlmostEqual(long_result.value, 0.2)
        self.assertEqual(long_result.direction, 1)
        self.assertAlmostEqual(short_result.value, -0.2)
        self.assertEqual(short_result.direction, -1)
        self.assertLess(statistics.mean(long_vector), 0.0)
        self.assertLess(pairwise_central(long_vector), 0.0)
        self.assertGreater(statistics.median(short_vector), 0.0)
        self.assertGreater(trimmed_mean(short_vector), 0.0)
        self.assertEqual(sum(value > 0.0 for value in short_vector), 3)

    def test_hit_rate_and_ten_year_signed_rank_are_different_contracts(self) -> None:
        hit_long = [-12.0, -11.0, 3.0, 9.0, 10.0]
        result = winsorized_direction(hit_long)
        assert result is not None
        self.assertEqual(sum(value > 0.0 for value in hit_long), 3)
        self.assertGreater(statistics.median(hit_long), 0.0)
        self.assertEqual(result.direction, -1)
        with self.assertRaisesRegex(ValueError, "requires ten years"):
            ten_year_signed_rank_direction(hit_long)
        self.assertEqual(
            ten_year_signed_rank_direction(
                [-10.0, -9.0, -8.0, -7.0, -6.0, 1.0, 2.0, 3.0, 4.0, 5.0]
            ),
            -1,
        )

    def test_count_nonfinite_and_inclusive_epsilon_band_fail_closed(self) -> None:
        self.assertIsNone(winsorized_direction([0.01] * 4))
        self.assertIsNone(
            winsorized_direction([0.01, 0.02, math.nan, 0.04, 0.05])
        )
        for center in (-EPSILON, 0.0, EPSILON):
            tied = winsorized_direction([center] * 5)
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

    def test_monthly_renewal_and_thirty_five_day_survivor_guard(self) -> None:
        opened = dt.datetime(2026, 8, 3, 1)
        self.assertFalse(monthly_exit_due(opened, dt.datetime(2026, 8, 31)))
        self.assertTrue(monthly_exit_due(opened, dt.datetime(2026, 9, 1)))
        self.assertFalse(stale_exit_due(opened, opened + 35 * DAY - DAY / 2))
        self.assertTrue(stale_exit_due(opened, opened + 35 * DAY))

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41202_wti-samecal-win5.mq5").read_text(
            encoding="utf-8"
        )
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41202_wti-samecal-win5_XTIUSD.DWX_D1_backtest.set"
        ).read_text(encoding="utf-8")
        for marker in (
            "input int    qm_ea_id                     = 41202;",
            "input int    strategy_winsor_tail_count     = 1;",
            "Strategy_SortAscending(sorted_values, sample_count);",
            "winsorized[0] = boundary_low;",
            "winsorized[sample_count - 1] = boundary_high;",
            "(2.0 * boundary_low + median_value + 2.0 * boundary_high) / 5.0;",
            "if(winsor_value > strategy_signal_epsilon)",
            "Strategy_RecordMonthAttempt(g_decision_month_key)",
            "req.tp = 0.0;",
            "strategy_atr_period_d1, 1);",
            "strategy_atr_sl_mult);",
            "QM_FRIDAY_CLOSE_DISABLED",
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
        ):
            self.assertNotIn(banned, source.lower())

        prepare = source[
            source.index("void Strategy_PrepareDecisionSignal()") :
            source.index("bool Strategy_NoTradeFilter()")
        ]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt(g_decision_month_key)"),
            prepare.index("Strategy_LoadWinsorizedSignal"),
        )
        signal_loader = source[
            source.index("bool Strategy_LoadWinsorizedSignal") :
            source.index("void Strategy_PrepareDecisionSignal()")
        ].lower()
        for forbidden_current_month_input in (
            "symbolinfo",
            "tickvolume",
            "real_volume",
            "current_month_return",
        ):
            self.assertNotIn(forbidden_current_month_input, signal_loader)

        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_ManageOpenPosition();"),
            on_tick.index("Strategy_NoTradeFilter()"),
        )
        for marker in (
            "qm_ea_id=41202",
            "qm_magic_slot_offset=0",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "strategy_history_years=5",
            "strategy_required_observations=5",
            "strategy_winsor_tail_count=1",
            "strategy_signal_epsilon=0.000000000001",
            "strategy_history_bars_d1=3000",
            "strategy_atr_period_d1=20",
            "strategy_atr_sl_mult=3.5",
            "strategy_max_hold_days=35",
            "strategy_max_spread_points=1500",
        ):
            self.assertIn(marker, setfile)

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41202_wti-samecal-win5_card.md"
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
            "41202,wti-samecal-win5,0,XTIUSD.DWX,412020000", magic_rows
        )
        resolver = (
            REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("412020000", resolver)


if __name__ == "__main__":
    unittest.main()
