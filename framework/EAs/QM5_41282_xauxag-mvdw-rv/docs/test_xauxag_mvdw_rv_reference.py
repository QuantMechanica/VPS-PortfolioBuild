from __future__ import annotations

import itertools
import json
import math
import re
import unittest
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from statistics import NormalDist


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41282_xauxag-mvdw-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41282_xauxag-mvdw-rv_"
    "QM5_41282_XAU_XAG_VDW_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41282_xauxag-mvdw-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"

N = 12
BLOCK = 6
TAIL_MAX = 462
SCORE_DENOMINATOR = 1_000_000_000_000_000
SCORE_NUMERATORS = (
    -1_426_076_872_272_847,
    -1_020_076_232_786_202,
    -736_315_917_376_130,
    -502_402_223_373_355,
    -293_381_232_121_193,
    -96_558_615_289_639,
    96_558_615_289_639,
    293_381_232_121_193,
    502_402_223_373_355,
    736_315_917_376_130,
    1_020_076_232_786_202,
    1_426_076_872_272_847,
)
SAVAGE_DENOMINATOR = 27_720
SAVAGE_NUMERATORS = (
    -25_410,
    -22_890,
    -20_118,
    -17_038,
    -13_573,
    -9_613,
    -4_993,
    551,
    7_481,
    16_721,
    30_581,
    58_301,
)
RELATIVE_EPSILON = 1.0e-12


@dataclass(frozen=True)
class VanDerWaerdenSignal:
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


def labels_from_path(path: str) -> tuple[int, ...]:
    if len(path) != N or path.count("O") != BLOCK or path.count("R") != BLOCK:
        raise ValueError("strict six-by-six label path required")
    return tuple(1 if char == "R" else 0 for char in path)


def score_numerator(
    labels: tuple[int, ...], numerators: tuple[int, ...]
) -> int:
    if len(labels) != N or labels.count(0) != BLOCK or labels.count(1) != BLOCK:
        raise ValueError("exactly six old and six recent labels required")
    return sum(numerators[index] for index, label in enumerate(labels) if label)


def vdw_numerator(labels: tuple[int, ...]) -> int:
    return score_numerator(labels, SCORE_NUMERATORS)


@lru_cache(maxsize=1)
def all_score_numerators() -> tuple[int, ...]:
    return tuple(vdw_numerator(labels) for labels in all_label_paths())


def relatively_tied(left: float, right: float) -> bool:
    tolerance = RELATIVE_EPSILON * max(1.0, abs(left), abs(right))
    return abs(left - right) <= tolerance


def exact_vdw_signal(changes: list[float]) -> VanDerWaerdenSignal:
    if len(changes) != N or any(not math.isfinite(value) for value in changes):
        raise ValueError("twelve finite changes required")
    if any(
        relatively_tied(changes[left], changes[right])
        for left in range(N)
        for right in range(left + 1, N)
    ):
        return VanDerWaerdenSignal(0, 0.0, 0, 0, 0, "", True)

    labelled = [
        (value, 0 if index < BLOCK else 1)
        for index, value in enumerate(changes)
    ]
    labelled.sort(key=lambda item: item[0])
    labels = tuple(label for _, label in labelled)
    observed_numerator = vdw_numerator(labels)
    scores = all_score_numerators()
    tail_count = sum(
        abs(value) >= abs(observed_numerator) for value in scores
    )
    qualifies = tail_count <= TAIL_MAX and observed_numerator != 0
    direction = 0
    if qualifies:
        direction = -1 if observed_numerator > 0 else 1
    return VanDerWaerdenSignal(
        direction,
        observed_numerator / SCORE_DENOMINATOR,
        observed_numerator,
        len(scores),
        tail_count,
        "".join("R" if label else "O" for label in labels),
    )


def changes_from_label_path(path: str) -> list[float]:
    labels = labels_from_path(path)
    old: list[float] = []
    recent: list[float] = []
    for rank, label in enumerate(labels, start=1):
        (recent if label else old).append(float(rank))
    return old + recent


def exact_linear_score_decision(
    path: str, numerators: tuple[int, ...]
) -> tuple[int, int, int]:
    labels = labels_from_path(path)
    observed = score_numerator(labels, numerators)
    assignment_scores = tuple(
        score_numerator(candidate, numerators)
        for candidate in all_label_paths()
    )
    tail = sum(abs(candidate) >= abs(observed) for candidate in assignment_scores)
    direction = 0
    if tail <= TAIL_MAX and observed != 0:
        direction = -1 if observed > 0 else 1
    return observed, tail, direction


def savage_decision(path: str) -> tuple[int, int, int]:
    return exact_linear_score_decision(path, SAVAGE_NUMERATORS)


def wilcoxon_decision(path: str) -> tuple[int, int, int]:
    labels = labels_from_path(path)
    centered = sum(
        rank for rank, label in enumerate(labels, start=1) if label
    ) - 39
    assignment_scores = tuple(
        sum(
            rank
            for rank, label in enumerate(candidate, start=1)
            if label
        )
        - 39
        for candidate in all_label_paths()
    )
    tail = sum(abs(candidate) >= abs(centered) for candidate in assignment_scores)
    direction = 0
    if tail <= TAIL_MAX and centered != 0:
        direction = -1 if centered > 0 else 1
    return centered, tail, direction


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


class MonthlyExactVanDerWaerdenReferenceTests(unittest.TestCase):
    def test_score_table_is_frozen_normal_quantile_lattice(self) -> None:
        normal = NormalDist()
        self.assertEqual(sum(SCORE_NUMERATORS), 0)
        self.assertEqual(
            SCORE_NUMERATORS,
            tuple(-value for value in reversed(SCORE_NUMERATORS)),
        )
        for rank, numerator in enumerate(SCORE_NUMERATORS, start=1):
            self.assertAlmostEqual(
                numerator / SCORE_DENOMINATOR,
                normal.inv_cdf(rank / (N + 1)),
                places=14,
            )

    def test_locked_nonduplicate_fixtures_disagree_with_neighbors(self) -> None:
        vdw_only = exact_vdw_signal(
            changes_from_label_path("RRROOOORORRO")
        )
        self.assertEqual(
            (
                vdw_only.score_numerator,
                vdw_only.tail_count,
                vdw_only.direction,
            ),
            (-1_132_695_640_151_654, 422, 1),
        )
        self.assertEqual(savage_decision(vdw_only.label_path)[1:], (616, 0))
        self.assertEqual(wilcoxon_decision(vdw_only.label_path), (-4, 544, 0))

        wilcoxon_only = exact_vdw_signal(
            changes_from_label_path("RRROROOOOORR")
        )
        self.assertEqual(
            (
                wilcoxon_only.score_numerator,
                wilcoxon_only.tail_count,
                wilcoxon_only.direction,
            ),
            (-1_029_697_149_497_323, 476, 0),
        )
        self.assertEqual(
            wilcoxon_decision(wilcoxon_only.label_path),
            (-5, 448, 1),
        )

        savage_only = exact_vdw_signal(
            changes_from_label_path("RRROOOOOORRR")
        )
        self.assertEqual(
            (
                savage_only.score_numerator,
                savage_only.tail_count,
                savage_only.direction,
            ),
            (0, 924, 0),
        )
        savage_numerator, savage_tail, savage_direction = savage_decision(
            savage_only.label_path
        )
        self.assertEqual((savage_numerator, savage_tail, savage_direction), (37185, 400, -1))
        self.assertAlmostEqual(
            savage_numerator / SAVAGE_DENOMINATOR,
            1.3414502164502164,
            places=15,
        )

    def test_exact_enumeration_activity_zero_states_and_symmetry_are_locked(self) -> None:
        signals = [
            exact_vdw_signal(
                changes_from_label_path(
                    "".join("R" if value else "O" for value in path)
                )
            )
            for path in all_label_paths()
        ]
        directional = [signal for signal in signals if signal.direction != 0]
        self.assertEqual(len(all_label_paths()), 924)
        self.assertEqual(all_score_numerators().count(0), 20)
        self.assertEqual(len(directional), 462)
        self.assertEqual(
            (
                sum(signal.direction == 1 for signal in directional),
                sum(signal.direction == -1 for signal in directional),
            ),
            (231, 231),
        )
        self.assertEqual(
            min(abs(signal.score_numerator) for signal in directional),
            1_041_895_523_917_931,
        )
        buy = exact_vdw_signal(changes_from_label_path("RRRRRROOOOOO"))
        sell = exact_vdw_signal(changes_from_label_path("OOOOOORRRRRR"))
        self.assertEqual(buy.score_numerator, -sell.score_numerator)
        self.assertEqual(buy.tail_count, sell.tail_count)
        self.assertEqual((buy.direction, sell.direction), (1, -1))

    def test_relative_change_tie_and_invalid_values_fail_closed(self) -> None:
        tied = [float(value) for value in range(12)]
        tied[-1] = tied[-2] + 5.0e-13
        signal = exact_vdw_signal(tied)
        self.assertTrue(signal.tie_detected)
        self.assertEqual((signal.assignment_count, signal.direction), (0, 0))
        with self.assertRaises(ValueError):
            exact_vdw_signal([float(value) for value in range(11)] + [math.inf])

    def test_ratio_orientation_and_month_sequence_are_exact(self) -> None:
        changes = changes_from_label_path("RRROOOORORRO")
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
        self.assertEqual(exact_vdw_signal(derived_changes).direction, 1)
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
            "qm_ea_id": "41282",
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
            "strategy_score_denominator": "1000000000000000",
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
            manifest["logical_symbol"], "QM5_41282_XAU_XAG_VDW_RV_D1"
        )
        self.assertEqual(
            (
                manifest["tester_currency"],
                manifest["tester_deposit"],
                manifest["q02_from_date"],
                manifest["q02_to_date"],
            ),
            ("USD", 100000, "2018.07.02", "2024.12.31"),
        )
        self.assertIn("input long   strategy_score_denominator", source)
        self.assertIn("Strategy_VanDerWaerdenScoreNumeratorForRank", source)
        self.assertIn(
            "case 1:  numerator = -1426076872272847", source
        )
        self.assertIn(
            "case 12: numerator =  1426076872272847", source
        )
        self.assertIn("Strategy_VanDerWaerdenScoreInvariant", source)
        self.assertIn(
            "for(int mask = 0; mask < (1 << strategy_return_count); ++mask)",
            source,
        )
        self.assertIn(
            "Strategy_AbsoluteScoreNumerator(permutation_score_numerator) >=",
            source,
        )
        self.assertIn(
            "Strategy_AbsoluteScoreNumerator(observed_score_numerator)",
            source,
        )
        self.assertIn("observed_score_numerator == 0", source)
        self.assertIn("tail_count <= strategy_tail_count_max", source)
        self.assertNotIn("tail_epsilon", source)
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
        self.assertNotRegex(
            source,
            re.compile(r"iRSI|iMACD|iBands|WebRequest|FileOpen|Python|ONNX"),
        )
        registry = MAGIC_REGISTRY.read_text(encoding="utf-8-sig")
        self.assertIn(
            "41282,xauxag-mvdw-rv,0,XAUUSD.DWX,412820000", registry
        )
        self.assertIn(
            "41282,xauxag-mvdw-rv,1,XAGUSD.DWX,412820001", registry
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
            self.assertEqual(
                values["strategy_score_denominator"],
                "1000000000000000",
            )


if __name__ == "__main__":
    unittest.main()

