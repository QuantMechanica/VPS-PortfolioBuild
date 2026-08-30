"""Independent deterministic fixtures for QM5_41213.

The suite covers normalized D1 labels, synchronized completed-month
endpoints, the exact Y-1..Y-10 scan with a five-pair floor, XAU-minus-XAG
orientation, the null-half Bernoulli sign score and strict abstention band,
durable monthly attempts, and static card/build conformance. It does not
invoke MT5 or duplicate framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import json
import math
import re
import unittest
from dataclasses import dataclass
from pathlib import Path


DAY = dt.timedelta(days=1)
THRESHOLD = 1.0
TOLERANCE = 1.0e-10
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


@dataclass(frozen=True)
class SignScoreResult:
    nonnegative_count: int
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


def score_direction(score: float) -> int:
    if not math.isfinite(score):
        return 0
    if score > THRESHOLD + TOLERANCE:
        return 1
    if score < -THRESHOLD - TOLERANCE:
        return -1
    return 0


def sign_score(observations: list[float]) -> SignScoreResult | None:
    if not 5 <= len(observations) <= 10:
        return None
    if not all(math.isfinite(value) for value in observations):
        return None
    nonnegative_count = sum(value >= 0.0 for value in observations)
    denominator = math.sqrt(len(observations) * 0.5 * (1.0 - 0.5))
    if not math.isfinite(denominator) or denominator <= 0.0:
        return None
    score = (nonnegative_count - len(observations) * 0.5) / denominator
    if not math.isfinite(score):
        return None
    return SignScoreResult(
        nonnegative_count, denominator, score, score_direction(score)
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


class SameCalendarSignScoreReferenceTests(unittest.TestCase):
    def test_native_and_prior_day_labels_detect_same_month_roll(self) -> None:
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

    def test_exact_year_scan_skips_missing_and_mismatched_pairs(self) -> None:
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
            for offset in range(1, 11)
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

    def test_null_half_score_and_orientation(self) -> None:
        observations = [0.01, 0.02, 0.03, 0.04, -0.05]
        result = sign_score(observations)
        self.assertIsNotNone(result)
        assert result is not None
        self.assertEqual(result.nonnegative_count, 4)
        self.assertAlmostEqual(result.denominator, 0.5 * math.sqrt(5))
        self.assertAlmostEqual(result.score, 3 / math.sqrt(5))
        self.assertEqual(result.direction, 1)
        inverse = sign_score([-value for value in observations])
        self.assertEqual(inverse.direction if inverse else 0, -1)

    def test_strict_threshold_and_tolerance_abstain(self) -> None:
        self.assertEqual(score_direction(THRESHOLD), 0)
        self.assertEqual(score_direction(THRESHOLD + TOLERANCE), 0)
        self.assertEqual(score_direction(-THRESHOLD - TOLERANCE), 0)
        self.assertEqual(score_direction(THRESHOLD + TOLERANCE + 1e-12), 1)
        self.assertEqual(score_direction(-THRESHOLD - TOLERANCE - 1e-12), -1)

    def test_locked_nonduplicate_vectors_change_direction_and_participation(self) -> None:
        direction_fixture = [0.09, -0.01, -0.01, -0.01, -0.01]
        direction_result = sign_score(direction_fixture)
        self.assertIsNotNone(direction_result)
        assert direction_result is not None
        self.assertGreater(sum(direction_fixture) / len(direction_fixture), 0.0)
        self.assertEqual(direction_result.direction, -1)

        participation_fixture = [0.001, 0.001, 0.001, 0.001, -0.100]
        participation_result = sign_score(participation_fixture)
        self.assertIsNotNone(participation_result)
        assert participation_result is not None
        mean = sum(participation_fixture) / len(participation_fixture)
        variance = sum(
            (value - mean) ** 2 for value in participation_fixture
        ) / (len(participation_fixture) - 1)
        t_score = mean / math.sqrt(variance / len(participation_fixture))
        self.assertLess(abs(t_score), 1.0)
        self.assertEqual(participation_result.direction, 1)

        balanced = sign_score([0.01, 0.02, 0.03, -0.01, -0.02, -0.03])
        self.assertEqual(balanced.direction if balanced else 99, 0)

    def test_count_nonfinite_and_zero_tie_contract(self) -> None:
        self.assertIsNone(sign_score([0.01] * 4))
        self.assertIsNone(sign_score([0.01] * 11))
        self.assertIsNone(sign_score([0.01] * 4 + [math.nan]))
        all_positive = sign_score([0.01] * 5)
        self.assertEqual(all_positive.direction if all_positive else 0, 1)
        all_zero = sign_score([0.0] * 5)
        self.assertEqual(all_zero.nonnegative_count if all_zero else -1, 5)
        self.assertEqual(all_zero.direction if all_zero else 0, 1)

    def test_attempt_is_consumed_before_failure_and_survives_restart(self) -> None:
        storage: dict[str, int] = {}
        first = AttemptLedger(storage)
        self.assertFalse(first.consume_before(202608, downstream_gate=False))
        self.assertFalse(first.consume_before(202608, downstream_gate=True))
        restarted = AttemptLedger(storage)
        self.assertFalse(restarted.consume_before(202608, downstream_gate=True))
        self.assertTrue(restarted.consume_before(202609, downstream_gate=True))

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41213_xauxag-samecal-signscore.mq5").read_text(
            encoding="utf-8"
        )
        set_path = (
            EA_DIR
            / "sets"
            / (
                "QM5_41213_xauxag-samecal-signscore_"
                "QM5_41213_XAU_XAG_SAMECAL_SIGNSCORE_D1_D1_backtest.set"
            )
        )
        setfile = set_path.read_text(encoding="utf-8")
        for marker in (
            "input int    qm_ea_id                    = 41213;",
            'input string strategy_xag_symbol            = "XAGUSD.DWX";',
            "input int    strategy_history_years          = 10;",
            "input int    strategy_min_observations      = 5;",
            "input double strategy_null_probability        = 0.5;",
            "input double strategy_score_threshold         = 1.0;",
            "input double strategy_signal_tolerance         = 1.0e-10;",
            "if(qm_ea_id != 41213 || qm_magic_slot_offset != 0 || qm_rng_seed != 42)",
            "if(observations[index] >= 0.0)",
            "(double)sample_count * strategy_null_probability *",
            "denominator_value = MathSqrt(null_variance);",
            "(double)nonnegative_count -",
            "strategy_score_threshold + strategy_signal_tolerance;",
            "-strategy_score_threshold - strategy_signal_tolerance;",
            "Strategy_ConsumePeriodAttempt(g_cache_period_key)",
            "Strategy_LoadSignalState(g_cache_decision_month_key",
            "ArraySetAsSeries(xau_rates, false);",
            "ArraySetAsSeries(xag_rates, false);",
            "Strategy_NormalizedHostSessions",
            "g_cache_label_offset_days",
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
            "machine learning",
            "pvalue",
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
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("QM_FrameworkTrackOpenPositionMae();"),
            on_tick.index("Strategy_NoTradeFilter()"),
        )
        for marker in (
            "qm_ea_id=41213",
            "qm_magic_slot_offset=0",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "strategy_xag_symbol=XAGUSD.DWX",
            "strategy_history_years=10",
            "strategy_min_observations=5",
            "strategy_null_probability=0.5",
            "strategy_score_threshold=1.0",
            "strategy_signal_tolerance=0.0000000001",
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
                    "QM5_41213_xauxag-samecal-signscore_"
                    "QM5_41213_XAU_XAG_SAMECAL_SIGNSCORE_D1_D1_backtest.set"
                ),
                (
                    "QM5_41213_xauxag-samecal-signscore_"
                    "XAUUSD.DWX_D1_backtest.set"
                ),
                (
                    "QM5_41213_xauxag-samecal-signscore_"
                    "XAGUSD.DWX_D1_backtest.set"
                ),
            },
        )
        for component_name in set_names - {set_path.name}:
            component = (EA_DIR / "sets" / component_name).read_text(
                encoding="utf-8"
            )
            self.assertIn("RISK_FIXED=1000", component)
            self.assertIn("RISK_PERCENT=0", component)

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41213_xauxag-samecal-signscore_card.md"
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
            "41213,xauxag-samecal-signscore,0,XAUUSD.DWX,412130000",
            magic_rows,
        )
        self.assertIn(
            "41213,xauxag-samecal-signscore,1,XAGUSD.DWX,412130001",
            magic_rows,
        )
        resolver = (
            REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("412130000", resolver)
        self.assertIn("412130001", resolver)

        basket = json.loads(
            (EA_DIR / "basket_manifest.json").read_text(encoding="utf-8")
        )
        self.assertEqual(
            basket["logical_symbol"], "QM5_41213_XAU_XAG_SAMECAL_SIGNSCORE_D1"
        )
        self.assertEqual(basket["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(
            basket["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"]
        )
        self.assertEqual(basket["traded_symbols"], basket["basket_symbols"])


if __name__ == "__main__":
    unittest.main()
