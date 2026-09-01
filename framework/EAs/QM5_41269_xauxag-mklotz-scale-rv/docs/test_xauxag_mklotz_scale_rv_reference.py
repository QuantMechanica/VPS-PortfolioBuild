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
EA_SOURCE = EA_DIR / "QM5_41269_xauxag-mklotz-scale-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41269_xauxag-mklotz-scale-rv_"
    "QM5_41269_XAU_XAG_KLOTZ_SCALE_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41269_xauxag-mklotz-scale-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"

EPSILON = 1.0e-12
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
KLOTZ_DENOMINATOR = 1.2716448806860048


@dataclass(frozen=True)
class KlotzSignal:
    direction: int
    old_mean: float
    recent_mean: float
    residuals: tuple[float, ...]
    recent_ranks: tuple[int, ...]
    recent_score: float
    standardized_t1: float
    assignment_count: int
    tail_count: int
    tie_detected: bool


@lru_cache(maxsize=1)
def assignment_scores() -> tuple[float, ...]:
    return tuple(
        sum(KLOTZ_SCORES[index] for index in recent_indices)
        for recent_indices in itertools.combinations(range(12), 6)
    )


def klotz_signal(changes: list[float]) -> KlotzSignal:
    if len(changes) != 12 or any(not math.isfinite(value) for value in changes):
        raise ValueError("twelve finite changes required")
    old = changes[:6]
    recent = changes[6:]
    old_mean = sum(old) / 6.0
    recent_mean = sum(recent) / 6.0
    residuals = tuple(
        value - (old_mean if index < 6 else recent_mean)
        for index, value in enumerate(changes)
    )
    if any(not math.isfinite(value) for value in residuals):
        raise ValueError("nonfinite centered residual")
    for left, right in itertools.combinations(residuals, 2):
        tolerance = EPSILON * max(1.0, abs(left), abs(right))
        if abs(left - right) <= tolerance:
            return KlotzSignal(
                0,
                old_mean,
                recent_mean,
                residuals,
                (),
                0.0,
                0.0,
                0,
                0,
                True,
            )

    ranked = sorted(
        (value, index, index >= 6) for index, value in enumerate(residuals)
    )
    ranks_by_index = {
        original_index: rank
        for rank, (_, original_index, _) in enumerate(ranked, start=1)
    }
    recent_ranks = tuple(ranks_by_index[index] for index in range(6, 12))
    recent_score = sum(KLOTZ_SCORES[rank - 1] for rank in recent_ranks)
    standardized_t1 = (recent_score - KLOTZ_EXPECTED) / KLOTZ_DENOMINATOR
    if not math.isfinite(recent_score) or not math.isfinite(standardized_t1):
        raise ValueError("nonfinite Klotz arithmetic")

    scores = assignment_scores()
    tolerance = EPSILON * max(1.0, abs(recent_score))
    tail_count = sum(score + tolerance >= recent_score for score in scores)
    if len(scores) != 924 or not 0 <= tail_count <= 924:
        raise ValueError("incomplete Klotz assignment enumeration")

    direction = 0
    expected_tolerance = EPSILON * max(1.0, abs(KLOTZ_EXPECTED))
    if recent_score + expected_tolerance >= KLOTZ_EXPECTED and tail_count <= 494:
        mean_delta = recent_mean - old_mean
        location_tolerance = EPSILON * max(
            1.0, abs(old_mean), abs(recent_mean)
        )
        if mean_delta > location_tolerance:
            direction = -1
        elif mean_delta < -location_tolerance:
            direction = 1
    return KlotzSignal(
        direction,
        old_mean,
        recent_mean,
        residuals,
        recent_ranks,
        recent_score,
        standardized_t1,
        len(scores),
        tail_count,
        False,
    )


def median_six(values: list[float]) -> float:
    ordered = sorted(values)
    return 0.5 * (ordered[2] + ordered[3])


def brown_forsythe_direction(changes: list[float]) -> int:
    old = changes[:6]
    recent = changes[6:]
    old_median = median_six(old)
    recent_median = median_six(recent)
    old_z_mean = sum(abs(value - old_median) for value in old) / 6.0
    recent_z_mean = sum(abs(value - recent_median) for value in recent) / 6.0
    scale_tolerance = EPSILON * max(1.0, abs(old_z_mean), abs(recent_z_mean))
    if recent_z_mean <= old_z_mean + scale_tolerance:
        return 0
    delta = recent_median - old_median
    tolerance = EPSILON * max(1.0, abs(old_median), abs(recent_median))
    return -1 if delta > tolerance else 1 if delta < -tolerance else 0


def kuiper_from_labels(labels: tuple[int, ...]) -> float:
    old_seen = 0
    recent_seen = 0
    d_plus = 0.0
    d_minus = 0.0
    for label in labels:
        old_seen += label == 0
        recent_seen += label == 1
        delta = recent_seen / 6.0 - old_seen / 6.0
        d_plus = max(d_plus, delta)
        d_minus = max(d_minus, -delta)
    return d_plus + d_minus


@lru_cache(maxsize=1)
def label_paths() -> tuple[tuple[int, ...], ...]:
    paths: list[tuple[int, ...]] = []
    for recent_indices in itertools.combinations(range(12), 6):
        recent_set = set(recent_indices)
        paths.append(
            tuple(1 if index in recent_set else 0 for index in range(12))
        )
    return tuple(paths)


def raw_kuiper_direction(changes: list[float]) -> tuple[int, float, int]:
    if len(changes) != 12 or len(set(changes)) != 12:
        return 0, 0.0, 0
    labelled = sorted(
        (value, 0 if index < 6 else 1) for index, value in enumerate(changes)
    )
    labels = tuple(label for _, label in labelled)
    observed = kuiper_from_labels(labels)
    tolerance = EPSILON * max(1.0, abs(observed))
    tail = sum(
        kuiper_from_labels(path) + tolerance >= observed for path in label_paths()
    )
    rank_sum = sum(rank for rank, label in enumerate(labels, start=1) if label)
    side = -1 if rank_sum > 39 else 1 if rank_sum < 39 else 0
    direction = side if observed + EPSILON >= 0.5 and tail <= 798 else 0
    return direction, observed, tail


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


class MonthlyCenteredKlotzReferenceTests(unittest.TestCase):
    KLOTZ_ONLY = [
        2.5, 0.5, -3.5, 5.5, -1.5, -4.5,
        3.5, 1.5, -0.5, 4.5, -5.5, -2.5,
    ]
    BROWN_FORSYTHE_ONLY = [
        5.0, -4.5, -1.0, 6.5, 3.5, 2.5,
        -2.0, -3.0, 8.0, -6.0, 0.5, 1.5,
    ]
    SIDE_DISAGREEMENT = [
        2.5, -0.5, 1.5, 3.5, -4.5, -3.5,
        -5.5, 5.5, -2.5, 0.5, 4.5, -1.5,
    ]

    def test_score_table_and_complete_support_are_locked(self) -> None:
        self.assertAlmostEqual(sum(KLOTZ_SCORES), 7.928432008212679, places=14)
        self.assertAlmostEqual(KLOTZ_EXPECTED, sum(KLOTZ_SCORES) / 2.0, places=15)
        scores = assignment_scores()
        self.assertEqual(len(scores), 924)
        tolerance = EPSILON * max(1.0, abs(KLOTZ_EXPECTED))
        above = sum(score > KLOTZ_EXPECTED + tolerance for score in scores)
        central = sum(abs(score - KLOTZ_EXPECTED) <= tolerance for score in scores)
        below = sum(score < KLOTZ_EXPECTED - tolerance for score in scores)
        self.assertEqual((above, central, below), (430, 64, 430))

    def test_klotz_only_fixture_hits_inclusive_boundary(self) -> None:
        signal = klotz_signal(self.KLOTZ_ONLY)
        self.assertEqual(signal.direction, -1)
        self.assertAlmostEqual(signal.old_mean, -1.0 / 6.0, places=15)
        self.assertAlmostEqual(signal.recent_mean, 1.0 / 6.0, places=15)
        self.assertEqual(signal.recent_ranks, (10, 8, 6, 11, 1, 4))
        self.assertAlmostEqual(signal.recent_score, KLOTZ_EXPECTED, places=14)
        self.assertEqual((signal.assignment_count, signal.tail_count), (924, 494))
        self.assertEqual(brown_forsythe_direction(self.KLOTZ_ONLY), 0)
        kuiper_direction, kuiper_statistic, kuiper_tail = raw_kuiper_direction(
            self.KLOTZ_ONLY
        )
        self.assertEqual(kuiper_direction, 0)
        self.assertAlmostEqual(kuiper_statistic, 1.0 / 3.0, places=15)
        self.assertEqual(kuiper_tail, 922)

    def test_neighbor_only_and_opposite_side_fixtures_are_locked(self) -> None:
        bf_only = klotz_signal(self.BROWN_FORSYTHE_ONLY)
        self.assertEqual(bf_only.direction, 0)
        self.assertAlmostEqual(bf_only.recent_score, 3.674462867975379, places=14)
        self.assertEqual(bf_only.tail_count, 566)
        self.assertEqual(brown_forsythe_direction(self.BROWN_FORSYTHE_ONLY), 1)

        opposite = klotz_signal(self.SIDE_DISAGREEMENT)
        self.assertEqual(opposite.direction, -1)
        self.assertAlmostEqual(opposite.recent_score, 5.455750119556394, places=14)
        self.assertEqual(opposite.tail_count, 133)
        self.assertEqual(brown_forsythe_direction(self.SIDE_DISAGREEMENT), 1)

    def test_ties_neutral_location_and_invalid_states_fail_closed(self) -> None:
        tied = klotz_signal([1.0] * 6 + [2.0] * 6)
        self.assertTrue(tied.tie_detected)
        self.assertEqual((tied.assignment_count, tied.direction), (0, 0))
        neutral = klotz_signal(
            [-6.0, -4.0, -2.0, 1.0, 4.0, 7.0]
            + [-7.0, -3.0, -1.0, 2.0, 3.0, 6.0]
        )
        self.assertAlmostEqual(neutral.old_mean, neutral.recent_mean, places=15)
        self.assertEqual(neutral.direction, 0)
        with self.assertRaises(ValueError):
            klotz_signal([0.0] * 11 + [math.inf])

    def test_ratio_orientation_and_month_sequence_are_exact(self) -> None:
        ratio_path = [math.log(80.0)]
        for change in self.KLOTZ_ONLY:
            ratio_path.append(ratio_path[-1] + change / 10.0)
        xag = [20.0] * 13
        xau = [
            silver * math.exp(ratio)
            for silver, ratio in zip(xag, ratio_path, strict=True)
        ]
        derived = log_ratios(xau, xag)
        changes = [
            right - left
            for left, right in zip(derived[:-1], derived[1:], strict=True)
        ]
        self.assertEqual(klotz_signal(changes).direction, -1)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 12 + [0.0], [1.0] * 13)
        endpoints = [
            202507, 202508, 202509, 202510, 202511, 202512, 202601,
            202602, 202603, 202604, 202605, 202606, 202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        endpoints[7] = 202603
        self.assertFalse(validate_month_keys(202608, endpoints))

    def test_source_manifest_set_card_and_magics_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41269",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_return_count": "12",
            "strategy_block_size": "6",
            "strategy_relative_epsilon": "0.000000000001",
            "strategy_klotz_expected": "3.9642160041063397",
            "strategy_klotz_denominator": "1.2716448806860048",
            "strategy_assignment_count": "924",
            "strategy_tail_count_max": "494",
            "strategy_history_bars_d1": "900",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(
            manifest["logical_symbol"], "QM5_41269_XAU_XAG_KLOTZ_SCALE_RV_D1"
        )
        self.assertIn("Strategy_KlotzScore", source)
        self.assertIn("Strategy_KlotzSignal", source)
        self.assertIn("case 1:  score = 2.0336952456315065", source)
        self.assertIn("MathAbs(total_score - 7.928432008212679)", source)
        self.assertIn("assignment_count != strategy_assignment_count", source)
        self.assertIn("recent_score + score_tolerance < strategy_klotz_expected", source)
        self.assertIn("MathAbs(residuals[left] - residuals[right]) <= tie_tolerance", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertIn("Strategy_RefreshExpectedDirection()", source)
        self.assertIn("Strategy_PairCompositionValid(g_pair_expected_direction)", source)
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
            "41269,xauxag-mklotz-scale-rv,0,XAUUSD.DWX,412690000", registry
        )
        self.assertIn(
            "41269,xauxag-mklotz-scale-rv,1,XAGUSD.DWX,412690001", registry
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
