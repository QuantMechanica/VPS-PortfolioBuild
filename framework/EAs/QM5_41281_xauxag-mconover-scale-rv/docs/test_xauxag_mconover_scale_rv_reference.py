from __future__ import annotations

import itertools
import json
import math
import re
import unittest
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41281_xauxag-mconover-scale-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41281_xauxag-mconover-scale-rv_"
    "QM5_41281_XAU_XAG_CONOVER_SCALE_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41281_xauxag-mconover-scale-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"

EPSILON = 1.0e-12
SCORE_TOTAL = sum(rank * rank for rank in range(1, 13))
SCORE_EXPECTED = SCORE_TOTAL // 2
SCORE_MIN = 326
TAIL_MAX = 461
KLOTZ_SCORES = (
    2.0336952456315065,
    1.0405555206952889,
    0.54216113018145117,
    0.25240799405049096,
    0.086072547360949524,
    0.0093235661866525334,
    0.0093235661866525334,
    0.086072547360949524,
    0.25240799405049096,
    0.54216113018145117,
    1.0405555206952889,
    2.0336952456315065,
)
KLOTZ_EXPECTED = 3.9642160041063397


@dataclass(frozen=True)
class ConoverSignal:
    direction: int
    old_mean: float
    recent_mean: float
    deviations: tuple[float, ...]
    recent_ranks: tuple[int, ...]
    recent_score: int
    assignment_count: int
    tail_count: int
    tie_detected: bool


@lru_cache(maxsize=1)
def assignment_scores() -> tuple[int, ...]:
    return tuple(
        sum(rank * rank for rank in recent_ranks)
        for recent_ranks in itertools.combinations(range(1, 13), 6)
    )


def conover_signal(changes: list[float]) -> ConoverSignal:
    if len(changes) != 12 or any(not math.isfinite(value) for value in changes):
        raise ValueError("twelve finite changes required")
    old = changes[:6]
    recent = changes[6:]
    old_mean = sum(old) / 6.0
    recent_mean = sum(recent) / 6.0
    deviations = tuple(
        abs(value - (old_mean if index < 6 else recent_mean))
        for index, value in enumerate(changes)
    )
    if any(not math.isfinite(value) for value in deviations):
        raise ValueError("nonfinite absolute deviation")
    for left, right in itertools.combinations(deviations, 2):
        tolerance = EPSILON * max(1.0, abs(left), abs(right))
        if abs(left - right) <= tolerance:
            return ConoverSignal(
                0,
                old_mean,
                recent_mean,
                deviations,
                (),
                0,
                0,
                0,
                True,
            )

    ranked = sorted(
        (value, index, index >= 6) for index, value in enumerate(deviations)
    )
    ranks_by_index = {
        original_index: rank
        for rank, (_, original_index, _) in enumerate(ranked, start=1)
    }
    recent_ranks = tuple(ranks_by_index[index] for index in range(6, 12))
    recent_score = sum(rank * rank for rank in recent_ranks)
    scores = assignment_scores()
    tail_count = sum(score >= recent_score for score in scores)
    if len(scores) != 924 or not 0 <= tail_count <= 924:
        raise ValueError("incomplete Conover assignment enumeration")

    direction = 0
    if recent_score >= SCORE_MIN and tail_count <= TAIL_MAX:
        mean_delta = recent_mean - old_mean
        if mean_delta > EPSILON:
            direction = -1
        elif mean_delta < -EPSILON:
            direction = 1
    return ConoverSignal(
        direction,
        old_mean,
        recent_mean,
        deviations,
        recent_ranks,
        recent_score,
        len(scores),
        tail_count,
        False,
    )


@lru_cache(maxsize=1)
def klotz_assignment_scores() -> tuple[float, ...]:
    return tuple(
        sum(KLOTZ_SCORES[index] for index in recent_indices)
        for recent_indices in itertools.combinations(range(12), 6)
    )


def klotz_neighbor(changes: list[float]) -> tuple[int, float, int]:
    old_mean = sum(changes[:6]) / 6.0
    recent_mean = sum(changes[6:]) / 6.0
    residuals = [
        value - (old_mean if index < 6 else recent_mean)
        for index, value in enumerate(changes)
    ]
    ranked = sorted(
        (value, index, index >= 6) for index, value in enumerate(residuals)
    )
    ranks = {
        original_index: rank
        for rank, (_, original_index, _) in enumerate(ranked, start=1)
    }
    score = sum(KLOTZ_SCORES[ranks[index] - 1] for index in range(6, 12))
    tolerance = EPSILON * max(1.0, abs(score))
    tail = sum(
        candidate + tolerance >= score for candidate in klotz_assignment_scores()
    )
    direction = 0
    expected_tolerance = EPSILON * max(1.0, abs(KLOTZ_EXPECTED))
    if score + expected_tolerance >= KLOTZ_EXPECTED and tail <= 494:
        delta = recent_mean - old_mean
        location_tolerance = EPSILON * max(
            1.0, abs(old_mean), abs(recent_mean)
        )
        direction = (
            -1
            if delta > location_tolerance
            else 1
            if delta < -location_tolerance
            else 0
        )
    return direction, score, tail


def median_six(values: list[float]) -> float:
    ordered = sorted(values)
    return 0.5 * (ordered[2] + ordered[3])


def brown_forsythe_direction(changes: list[float]) -> int:
    old = changes[:6]
    recent = changes[6:]
    old_median = median_six(old)
    recent_median = median_six(recent)
    old_deviation_mean = sum(abs(value - old_median) for value in old) / 6.0
    recent_deviation_mean = (
        sum(abs(value - recent_median) for value in recent) / 6.0
    )
    scale_tolerance = EPSILON * max(
        1.0, abs(old_deviation_mean), abs(recent_deviation_mean)
    )
    if recent_deviation_mean <= old_deviation_mean + scale_tolerance:
        return 0
    delta = recent_median - old_median
    location_tolerance = EPSILON * max(
        1.0, abs(old_median), abs(recent_median)
    )
    return (
        -1
        if delta > location_tolerance
        else 1
        if delta < -location_tolerance
        else 0
    )


def log_ratios(xau: list[float], xag: list[float]) -> list[float]:
    if len(xau) != 13 or len(xag) != 13:
        raise ValueError("exactly thirteen synchronized closes required")
    if any(not math.isfinite(value) or value <= 0.0 for value in xau + xag):
        raise ValueError("positive finite closes required")
    return [
        math.log(gold) - math.log(silver)
        for gold, silver in zip(xau, xag, strict=True)
    ]


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    return (
        len(endpoints) == 13
        and next_month_key(endpoints[-1]) == current_month
        and all(
            next_month_key(left) == right
            for left, right in zip(endpoints[:-1], endpoints[1:], strict=True)
        )
    )


def parse_setfile(path: Path) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";"):
            continue
        key, value = line.split("=", 1)
        parsed[key] = value
    return parsed


class MonthlyConoverReferenceTests(unittest.TestCase):
    CONOVER_ONLY = [
        1.730871,
        -4.253550,
        2.942130,
        3.730888,
        -0.057275,
        0.662848,
        0.808899,
        4.555005,
        -2.252364,
        1.445557,
        2.931657,
        4.195571,
    ]
    KLOTZ_ONLY = [
        4.787636,
        4.977662,
        -0.155177,
        4.303156,
        -5.294428,
        -0.484160,
        -3.876079,
        0.557290,
        3.755243,
        -1.349457,
        -3.862835,
        -4.147329,
    ]
    BROWN_FORSYTHE_ONLY = [
        -1.068800,
        5.811016,
        -1.405426,
        -1.104323,
        -4.699905,
        -5.230559,
        -3.707560,
        -0.776133,
        1.903656,
        -4.227494,
        5.989247,
        -3.392596,
    ]
    SIDE_DISAGREEMENT = [
        1.835782,
        2.887219,
        5.865684,
        0.583978,
        0.439193,
        -1.753346,
        3.958708,
        2.429016,
        -0.440576,
        5.134423,
        -5.637578,
        3.048016,
    ]

    def test_squared_rank_support_and_upper_half_are_locked(self) -> None:
        self.assertEqual((SCORE_TOTAL, SCORE_EXPECTED), (650, 325))
        scores = assignment_scores()
        self.assertEqual(len(scores), 924)
        above = sum(score > SCORE_EXPECTED for score in scores)
        central = sum(score == SCORE_EXPECTED for score in scores)
        below = sum(score < SCORE_EXPECTED for score in scores)
        self.assertEqual((above, central, below), (461, 2, 461))
        self.assertEqual(sum(score >= SCORE_MIN for score in scores), 461)

    def test_conover_only_fixture_is_exact_and_neighbor_flat(self) -> None:
        signal = conover_signal(self.CONOVER_ONLY)
        self.assertFalse(signal.tie_detected)
        self.assertEqual(signal.direction, -1)
        self.assertAlmostEqual(signal.old_mean, 0.792652, places=12)
        self.assertAlmostEqual(signal.recent_mean, 1.9473875, places=12)
        self.assertEqual(signal.recent_ranks, (6, 9, 11, 2, 5, 8))
        self.assertEqual(
            (signal.recent_score, signal.assignment_count, signal.tail_count),
            (331, 924, 440),
        )
        self.assertEqual(klotz_neighbor(self.CONOVER_ONLY), (0, 3.3375783964753793, 640))
        self.assertEqual(brown_forsythe_direction(self.CONOVER_ONLY), 0)

    def test_neighbor_only_fixtures_are_rejected(self) -> None:
        klotz_only = conover_signal(self.KLOTZ_ONLY)
        self.assertEqual(
            (klotz_only.direction, klotz_only.recent_score, klotz_only.tail_count),
            (0, 248, 753),
        )
        klotz_direction, klotz_score, klotz_tail = klotz_neighbor(self.KLOTZ_ONLY)
        self.assertEqual((klotz_direction, klotz_tail), (1, 494))
        self.assertAlmostEqual(klotz_score, KLOTZ_EXPECTED, places=14)

        bf_only = conover_signal(self.BROWN_FORSYTHE_ONLY)
        self.assertEqual(
            (bf_only.direction, bf_only.recent_score, bf_only.tail_count),
            (0, 313, 514),
        )
        self.assertEqual(brown_forsythe_direction(self.BROWN_FORSYTHE_ONLY), 1)

    def test_side_disagreement_is_locked(self) -> None:
        signal = conover_signal(self.SIDE_DISAGREEMENT)
        self.assertEqual(
            (signal.direction, signal.recent_score, signal.tail_count),
            (1, 397, 187),
        )
        self.assertEqual(brown_forsythe_direction(self.SIDE_DISAGREEMENT), -1)

    def test_ties_neutral_location_and_invalid_states_fail_closed(self) -> None:
        tied = conover_signal([1.0] * 6 + [2.0] * 6)
        self.assertTrue(tied.tie_detected)
        self.assertEqual((tied.assignment_count, tied.direction), (0, 0))
        neutral = conover_signal(
            [1.0, 2.0, 3.0, 4.0, 5.0, -15.0]
            + [6.0, 7.0, 8.0, 9.0, 10.0, -40.0]
        )
        self.assertEqual((neutral.old_mean, neutral.recent_mean), (0.0, 0.0))
        self.assertEqual(neutral.direction, 0)
        with self.assertRaises(ValueError):
            conover_signal([0.0] * 11 + [math.inf])

    def test_ratio_orientation_and_month_sequence_are_exact(self) -> None:
        ratio_path = [math.log(80.0)]
        for change in self.CONOVER_ONLY:
            ratio_path.append(ratio_path[-1] + change / 10.0)
        xag = [20.0] * 13
        xau = [
            silver * math.exp(ratio)
            for silver, ratio in zip(xag, ratio_path, strict=True)
        ]
        derived = log_ratios(xau, xag)
        changes = [
            (right - left) * 10.0
            for left, right in zip(derived[:-1], derived[1:], strict=True)
        ]
        self.assertEqual(conover_signal(changes).direction, -1)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 12 + [0.0], [1.0] * 13)
        endpoints = [
            202507,
            202508,
            202509,
            202510,
            202511,
            202512,
            202601,
            202602,
            202603,
            202604,
            202605,
            202606,
            202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        endpoints[7] = 202603
        self.assertFalse(validate_month_keys(202608, endpoints))

    def test_source_manifest_set_card_and_magics_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41281",
            "qm_magic_slot_offset": "0",
            "qm_rng_seed": "42",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_return_count": "12",
            "strategy_block_size": "6",
            "strategy_relative_epsilon": "0.000000000001",
            "strategy_score_total": "650",
            "strategy_score_expected": "325",
            "strategy_score_min": "326",
            "strategy_assignment_count": "924",
            "strategy_tail_count_max": "461",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars_d1": "900",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(
            manifest["logical_symbol"],
            "QM5_41281_XAU_XAG_CONOVER_SCALE_RV_D1",
        )
        self.assertIn("Strategy_ConoverScore", source)
        self.assertIn("Strategy_ConoverSignal", source)
        self.assertIn("deviations[index] = MathAbs", source)
        self.assertIn("score = rank * rank", source)
        self.assertIn("total_score != strategy_score_total", source)
        self.assertIn("permutation_score >= recent_score", source)
        self.assertIn("recent_score < strategy_score_min", source)
        self.assertIn(
            "MathAbs(deviations[left] - deviations[right]) <= tie_tolerance",
            source,
        )
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertIn("Strategy_RefreshExpectedDirection()", source)
        self.assertIn(
            "Strategy_PairCompositionValid(g_pair_expected_direction)", source
        )
        self.assertNotRegex(
            source,
            re.compile(
                r"iRSI|iMACD|iBands|WebRequest|MathErf|NormalCDF|InverseNormal"
            ),
        )
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )
        registry = MAGIC_REGISTRY.read_text(encoding="utf-8-sig")
        self.assertIn(
            "41281,xauxag-mconover-scale-rv,0,XAUUSD.DWX,412810000",
            registry,
        )
        self.assertIn(
            "41281,xauxag-mconover-scale-rv,1,XAGUSD.DWX,412810001",
            registry,
        )

    def test_only_factory_and_logical_fixed_risk_backtest_sets_exist(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertIn(LOGICAL_SET, setfiles)
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))
        for path in setfiles:
            values = parse_setfile(path)
            self.assertEqual(
                (values["RISK_FIXED"], values["RISK_PERCENT"]), ("1000", "0")
            )


if __name__ == "__main__":
    unittest.main()
