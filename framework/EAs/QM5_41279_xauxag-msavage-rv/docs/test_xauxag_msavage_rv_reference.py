from __future__ import annotations

import itertools
import json
import math
import re
import unittest
from dataclasses import dataclass
from fractions import Fraction
from functools import lru_cache
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41279_xauxag-msavage-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41279_xauxag-msavage-rv_"
    "QM5_41279_XAU_XAG_SAVAGE_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41279_xauxag-msavage-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"

N = 12
BLOCK = 6
SCORE_DENOMINATOR = 27720
SCORE_NUMERATORS = (
    -25410,
    -22890,
    -20118,
    -17038,
    -13573,
    -9613,
    -4993,
    551,
    7481,
    16721,
    30581,
    58301,
)
RELATIVE_EPSILON = 1.0e-12
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


@dataclass(frozen=True)
class SavageSignal:
    direction: int
    score: float
    score_numerator: int
    assignment_count: int
    tail_count: int
    label_path: str
    tie_detected: bool = False


@lru_cache(maxsize=1)
def all_label_paths() -> tuple[tuple[int, ...], ...]:
    paths: list[tuple[int, ...]] = []
    for recent_ranks in itertools.combinations(range(N), BLOCK):
        recent = set(recent_ranks)
        paths.append(tuple(1 if rank in recent else 0 for rank in range(N)))
    return tuple(paths)


def savage_numerator(labels: tuple[int, ...]) -> int:
    if len(labels) != N or labels.count(0) != BLOCK or labels.count(1) != BLOCK:
        raise ValueError("exactly six old and six recent labels required")
    return sum(
        SCORE_NUMERATORS[index] for index, label in enumerate(labels) if label
    )


@lru_cache(maxsize=1)
def all_score_numerators() -> tuple[int, ...]:
    return tuple(savage_numerator(labels) for labels in all_label_paths())


def relatively_tied(left: float, right: float) -> bool:
    tolerance = RELATIVE_EPSILON * max(1.0, abs(left), abs(right))
    return abs(left - right) <= tolerance


def exact_savage_signal(changes: list[float]) -> SavageSignal:
    if len(changes) != N or any(not math.isfinite(value) for value in changes):
        raise ValueError("twelve finite changes required")
    if any(
        relatively_tied(changes[left], changes[right])
        for left in range(N)
        for right in range(left + 1, N)
    ):
        return SavageSignal(0, 0.0, 0, 0, 0, "", True)

    labelled = [
        (value, 0 if index < BLOCK else 1)
        for index, value in enumerate(changes)
    ]
    labelled.sort(key=lambda item: item[0])
    labels = tuple(label for _, label in labelled)
    observed_numerator = savage_numerator(labels)
    observed_score = observed_numerator / SCORE_DENOMINATOR
    scores = all_score_numerators()
    tail_count = sum(
        abs(value / SCORE_DENOMINATOR) + RELATIVE_EPSILON
        >= abs(observed_score)
        for value in scores
    )
    qualifies = tail_count <= 462 and abs(observed_score) > RELATIVE_EPSILON
    direction = 0
    if qualifies:
        direction = -1 if observed_score > 0.0 else 1
    return SavageSignal(
        direction,
        observed_score,
        observed_numerator,
        len(scores),
        tail_count,
        "".join("R" if label else "O" for label in labels),
    )


def changes_from_label_path(path: str) -> list[float]:
    if len(path) != N or path.count("O") != BLOCK or path.count("R") != BLOCK:
        raise ValueError("strict six-by-six label path required")
    old: list[float] = []
    recent: list[float] = []
    for rank, label in enumerate(path, start=1):
        (recent if label == "R" else old).append(float(rank))
    return old + recent


def cucconi_decision(path: str) -> tuple[int, int, int]:
    labels = tuple(1 if char == "R" else 0 for char in path)
    expected = 325.0
    sd = math.sqrt(6955.0)
    rho = -479.0 / 535.0

    def statistic(candidate: tuple[int, ...]) -> tuple[float, int]:
        ranks = [rank for rank, label in enumerate(candidate, start=1) if label]
        u = (sum(rank * rank for rank in ranks) - expected) / sd
        v = (sum((N + 1 - rank) ** 2 for rank in ranks) - expected) / sd
        value = (u * u + v * v - 2.0 * rho * u * v) / (
            2.0 * (1.0 - rho * rho)
        )
        return value, sum(ranks)

    observed, rank_sum = statistic(labels)
    tolerance = RELATIVE_EPSILON * max(1.0, abs(observed))
    tail = sum(
        statistic(candidate)[0] + tolerance >= observed
        for candidate in all_label_paths()
    )
    direction = 0
    if tail <= 480 and rank_sum != 39:
        direction = -1 if rank_sum > 39 else 1
    return tail, rank_sum, direction


def centered_klotz_decision(changes: list[float]) -> tuple[float, int, int]:
    old_mean = sum(changes[:BLOCK]) / BLOCK
    recent_mean = sum(changes[BLOCK:]) / BLOCK
    residuals = [
        value - (old_mean if index < BLOCK else recent_mean)
        for index, value in enumerate(changes)
    ]
    if any(
        relatively_tied(left, right)
        for left, right in itertools.combinations(residuals, 2)
    ):
        return 0.0, 0, 0
    ranked = sorted((value, index) for index, value in enumerate(residuals))
    ranks_by_index = {
        original_index: rank
        for rank, (_, original_index) in enumerate(ranked, start=1)
    }
    recent_ranks = [ranks_by_index[index] for index in range(BLOCK, N)]
    score = sum(KLOTZ_SCORES[rank - 1] for rank in recent_ranks)
    assignment_scores = [
        sum(KLOTZ_SCORES[index] for index in recent)
        for recent in itertools.combinations(range(N), BLOCK)
    ]
    tolerance = RELATIVE_EPSILON * max(1.0, abs(score))
    tail = sum(candidate + tolerance >= score for candidate in assignment_scores)
    direction = 0
    if score >= sum(KLOTZ_SCORES) / 2.0 - tolerance and tail <= 494:
        direction = -1 if recent_mean > old_mean else 1
    return score, tail, direction


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


class MonthlyExactSavageReferenceTests(unittest.TestCase):
    def test_score_table_is_exact_centered_harmonic_formula(self) -> None:
        derived = tuple(
            int(
                (
                    sum(Fraction(1, N - j + 1) for j in range(1, rank + 1))
                    - 1
                )
                * SCORE_DENOMINATOR
            )
            for rank in range(1, N + 1)
        )
        self.assertEqual(derived, SCORE_NUMERATORS)
        self.assertEqual(sum(SCORE_NUMERATORS), 0)

    def test_locked_nonduplicate_fixtures_disagree_with_neighbors(self) -> None:
        savage_only = exact_savage_signal(
            changes_from_label_path("RRROOOOOORRR")
        )
        self.assertEqual(
            (
                savage_only.score_numerator,
                savage_only.tail_count,
                savage_only.direction,
            ),
            (37185, 400, -1),
        )
        self.assertAlmostEqual(savage_only.score, 1.3414502164502164, places=15)
        self.assertEqual(cucconi_decision(savage_only.label_path), (4, 39, 0))

        cucconi_only_path = "RRRROOOROOOR"
        savage_flat = exact_savage_signal(
            changes_from_label_path(cucconi_only_path)
        )
        self.assertEqual(
            (
                savage_flat.score_numerator,
                savage_flat.tail_count,
                savage_flat.direction,
            ),
            (-26604, 536, 0),
        )
        self.assertEqual(cucconi_decision(cucconi_only_path), (88, 30, 1))

        klotz_only_path = "RRRROOOOROOR"
        savage_klotz_flat = exact_savage_signal(
            changes_from_label_path(klotz_only_path)
        )
        self.assertEqual(
            (
                savage_klotz_flat.score_numerator,
                savage_klotz_flat.tail_count,
                savage_klotz_flat.direction,
            ),
            (-19674, 632, 0),
        )
        klotz_score, klotz_tail, klotz_direction = centered_klotz_decision(
            changes_from_label_path(klotz_only_path)
        )
        self.assertAlmostEqual(klotz_score, 6.410233092890735, places=15)
        self.assertEqual((klotz_tail, klotz_direction), (26, 1))

    def test_exact_enumeration_prior_and_direction_symmetry_are_locked(self) -> None:
        signals = [
            exact_savage_signal(
                changes_from_label_path(
                    "".join("R" if value else "O" for value in path)
                )
            )
            for path in all_label_paths()
        ]
        directional = [signal for signal in signals if signal.direction != 0]
        self.assertEqual(len(all_label_paths()), 924)
        self.assertEqual(len(directional), 462)
        self.assertEqual(
            (
                sum(signal.direction == 1 for signal in directional),
                sum(signal.direction == -1 for signal in directional),
            ),
            (231, 231),
        )
        self.assertNotIn(0, all_score_numerators())
        buy = exact_savage_signal(changes_from_label_path("RRRRRROOOOOO"))
        complement = "".join(
            "O" if value == "R" else "R" for value in buy.label_path
        )
        sell = exact_savage_signal(changes_from_label_path(complement))
        self.assertEqual(buy.score_numerator, -sell.score_numerator)
        self.assertEqual((buy.tail_count, buy.direction), (sell.tail_count, 1))
        self.assertEqual(sell.direction, -1)

    def test_relative_change_tie_and_invalid_values_fail_closed(self) -> None:
        tied = [float(value) for value in range(12)]
        tied[-1] = tied[-2] + 5.0e-13
        signal = exact_savage_signal(tied)
        self.assertTrue(signal.tie_detected)
        self.assertEqual((signal.assignment_count, signal.direction), (0, 0))
        with self.assertRaises(ValueError):
            exact_savage_signal([float(value) for value in range(11)] + [math.inf])

    def test_ratio_orientation_and_month_sequence_are_exact(self) -> None:
        changes = changes_from_label_path("RRROOOOOORRR")
        ratio_path = [math.log(10.0)]
        for change in changes:
            ratio_path.append(ratio_path[-1] + change)
        xag = [10.0] * 13
        xau = [
            silver * math.exp(ratio)
            for silver, ratio in zip(xag, ratio_path, strict=True)
        ]
        derived = log_ratios(xau, xag)
        derived_changes = [
            right - left
            for left, right in zip(derived[:-1], derived[1:], strict=True)
        ]
        self.assertEqual(exact_savage_signal(derived_changes).direction, -1)
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

    def test_source_manifest_set_registry_and_card_copy_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41279",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_return_count": "12",
            "strategy_block_size": "6",
            "strategy_assignment_count": "924",
            "strategy_tail_count_max": "462",
            "strategy_relative_epsilon": "0.000000000001",
            "strategy_score_denominator": "27720",
            "strategy_history_bars_d1": "900",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(
            manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"]
        )
        self.assertEqual(
            manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"]
        )
        self.assertEqual(
            manifest["logical_symbol"], "QM5_41279_XAU_XAG_SAVAGE_RV_D1"
        )
        self.assertEqual(
            (manifest["tester_currency"], manifest["tester_deposit"]),
            ("USD", 100000),
        )
        self.assertIn("Strategy_SavageScoreNumeratorForRank", source)
        self.assertIn("case 1:  numerator = -25410", source)
        self.assertIn("case 12: numerator =  58301", source)
        self.assertIn("Strategy_SavageScoreInvariant", source)
        self.assertIn(
            "for(int mask = 0; mask < (1 << strategy_return_count); ++mask)",
            source,
        )
        self.assertIn("MathAbs(permutation_score) + tail_epsilon >=", source)
        self.assertIn("MathAbs(observed_score)", source)
        self.assertIn("tail_count <= strategy_tail_count_max", source)
        self.assertIn(
            "MathAbs(relative_returns[left] - relative_returns[right]) <=",
            source,
        )
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertIn("Strategy_RefreshExpectedDirection()", source)
        self.assertIn(
            "Strategy_PairCompositionValid(g_pair_expected_direction)", source
        )
        self.assertIn("Strategy_CloseAllOwned(QM_EXIT_TIME_STOP)", source)
        self.assertNotRegex(source, re.compile(r"iRSI|iMACD|iBands|WebRequest"))
        registry = MAGIC_REGISTRY.read_text(encoding="utf-8-sig")
        self.assertIn(
            "41279,xauxag-msavage-rv,0,XAUUSD.DWX,412790000", registry
        )
        self.assertIn(
            "41279,xauxag-msavage-rv,1,XAGUSD.DWX,412790001", registry
        )
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )

    def test_only_logical_and_component_fixed_risk_backtest_sets_exist(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertIn(LOGICAL_SET, setfiles)
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))
        for path in setfiles:
            values = parse_setfile(path)
            self.assertEqual(
                (values["RISK_FIXED"], values["RISK_PERCENT"]), ("1000", "0")
            )
            self.assertEqual(values["PORTFOLIO_WEIGHT"], "1")


if __name__ == "__main__":
    unittest.main()
