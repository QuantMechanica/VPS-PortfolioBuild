from __future__ import annotations

import itertools
import json
import math
import re
import unittest
from collections import Counter
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41285_xauxag-mjt-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41285_xauxag-mjt-rv_"
    "QM5_41285_XAU_XAG_JT_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41285_xauxag-mjt-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"

N = 12
GROUP_COUNT = 3
GROUP_SIZE = 4
COMPARISONS = 48
CENTER = 24
TAIL_MAX = 18_034
LOWER = 19
UPPER = 29
RELATIVE_EPSILON = 1.0e-12

VDW_NUMERATORS = (
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


@dataclass(frozen=True)
class JonckheereTerpstraSignal:
    direction: int
    score: int
    score_deviation: int
    assignment_count: int
    tail_count: int
    label_path: str
    tie_detected: bool = False


@lru_cache(maxsize=1)
def all_label_allocations() -> tuple[tuple[int, ...], ...]:
    allocations: list[tuple[int, ...]] = []
    universe = tuple(range(N))
    for group_zero_ranks in itertools.combinations(universe, GROUP_SIZE):
        group_zero = set(group_zero_ranks)
        remaining = tuple(rank for rank in universe if rank not in group_zero)
        for group_one_ranks in itertools.combinations(remaining, GROUP_SIZE):
            group_one = set(group_one_ranks)
            allocations.append(
                tuple(
                    0 if rank in group_zero else 1 if rank in group_one else 2
                    for rank in universe
                )
            )
    return tuple(allocations)


def jt_score(labels: tuple[int, ...]) -> int:
    if len(labels) != N or any(labels.count(group) != GROUP_SIZE for group in range(GROUP_COUNT)):
        raise ValueError("strict labeled 4/4/4 allocation required")
    score = sum(
        labels[lower_rank] < labels[higher_rank]
        for lower_rank in range(N)
        for higher_rank in range(lower_rank + 1, N)
    )
    if not 0 <= score <= COMPARISONS:
        raise AssertionError("Jonckheere-Terpstra score escaped support")
    return score


@lru_cache(maxsize=1)
def all_jt_scores() -> tuple[int, ...]:
    return tuple(jt_score(labels) for labels in all_label_allocations())


def relatively_tied(left: float, right: float) -> bool:
    tolerance = RELATIVE_EPSILON * max(1.0, abs(left), abs(right))
    return abs(left - right) <= tolerance


def labels_from_changes(changes: list[float]) -> tuple[int, ...]:
    order = sorted(range(N), key=changes.__getitem__)
    return tuple(index // GROUP_SIZE for index in order)


def exact_jt_signal(changes: list[float]) -> JonckheereTerpstraSignal:
    if len(changes) != N or any(not math.isfinite(value) for value in changes):
        raise ValueError("twelve finite changes required")
    if any(
        relatively_tied(changes[left], changes[right])
        for left in range(N)
        for right in range(left + 1, N)
    ):
        return JonckheereTerpstraSignal(0, 0, 0, 0, 0, "", True)

    labels = labels_from_changes(changes)
    observed = jt_score(labels)
    deviation = abs(observed - CENTER)
    scores = all_jt_scores()
    tail = sum(abs(candidate - CENTER) >= deviation for candidate in scores)
    qualifies_by_tail = tail <= TAIL_MAX
    qualifies_by_score = observed <= LOWER or observed >= UPPER
    if qualifies_by_tail != qualifies_by_score:
        raise AssertionError("locked tail and score boundary disagree")
    direction = -1 if observed >= UPPER else 1 if observed <= LOWER else 0
    return JonckheereTerpstraSignal(
        direction,
        observed,
        deviation,
        len(scores),
        tail,
        "".join(str(label) for label in labels),
    )


def changes_from_label_allocation(labels: tuple[int, ...]) -> list[float]:
    grouped: list[list[float]] = [[] for _ in range(GROUP_COUNT)]
    for rank, label in enumerate(labels, start=1):
        grouped[label].append(float(rank))
    return [value for group in grouped for value in group]


def mann_whitney_neighbor(changes: list[float]) -> tuple[int, int]:
    old, recent = changes[:6], changes[6:]
    u_recent = sum(new > prior for new in recent for prior in old)
    direction = -1 if u_recent >= 24 else 1 if u_recent <= 12 else 0
    return u_recent, direction


@lru_cache(maxsize=1)
def all_vdw_scores() -> tuple[int, ...]:
    return tuple(
        sum(VDW_NUMERATORS[rank] for rank in recent_ranks)
        for recent_ranks in itertools.combinations(range(N), 6)
    )


def vdw_neighbor(changes: list[float]) -> tuple[int, int, int]:
    order = sorted(range(N), key=changes.__getitem__)
    score = sum(
        VDW_NUMERATORS[rank]
        for rank, original_index in enumerate(order)
        if original_index >= 6
    )
    tail = sum(abs(candidate) >= abs(score) for candidate in all_vdw_scores())
    direction = -1 if tail <= 462 and score > 0 else 1 if tail <= 462 and score < 0 else 0
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


def parse_setfile(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    headers: dict[str, str] = {}
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith(";"):
            body = line[1:].strip()
            if ":" in body:
                key, value = body.split(":", 1)
                headers[key.strip()] = value.strip()
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return headers, values


class MonthlyExactJonckheereTerpstraReferenceTests(unittest.TestCase):
    def test_complete_allocation_distribution_and_symmetry_are_locked(self) -> None:
        scores = all_jt_scores()
        distribution = Counter(scores)
        self.assertEqual(len(all_label_allocations()), 34_650)
        self.assertEqual((min(scores), max(scores)), (0, 48))
        self.assertEqual(distribution[24], 1_968)
        self.assertTrue(
            all(distribution[score] == distribution[48 - score] for score in range(49))
        )
        self.assertEqual(
            (
                sum(score <= LOWER for score in scores),
                sum(score >= UPPER for score in scores),
            ),
            (9_017, 9_017),
        )

    def test_inclusive_tail_boundary_is_exactly_equivalent_to_19_29(self) -> None:
        scores = all_jt_scores()

        def tail(observed: int) -> int:
            return sum(abs(candidate - CENTER) >= abs(observed - CENTER) for candidate in scores)

        self.assertEqual((tail(19), tail(29)), (18_034, 18_034))
        self.assertEqual((tail(20), tail(28)), (21_412, 21_412))
        self.assertTrue(
            all(
                (tail(score) <= TAIL_MAX) == (score <= LOWER or score >= UPPER)
                for score in range(49)
            )
        )

    def test_extremes_are_symmetric_and_contrarian(self) -> None:
        ascending = exact_jt_signal([float(value) for value in range(1, 13)])
        descending = exact_jt_signal([float(value) for value in range(12, 0, -1)])
        self.assertEqual(
            (ascending.score, ascending.tail_count, ascending.direction),
            (48, 2, -1),
        )
        self.assertEqual(
            (descending.score, descending.tail_count, descending.direction),
            (0, 2, 1),
        )

    def test_locked_nonduplicate_fixtures_disagree_with_neighbors(self) -> None:
        candidate_only = [10, 3, 1, 4, 12, 7, 9, 6, 11, 8, 2, 5]
        mw_only = [7, 8, 5, 12, 6, 9, 1, 3, 2, 10, 11, 4]
        opposite_vdw = [2, 8, 6, 4, 11, 12, 3, 1, 9, 7, 5, 10]

        first = exact_jt_signal(list(map(float, candidate_only)))
        self.assertEqual((first.score, first.tail_count, first.direction), (29, 18_034, -1))
        self.assertEqual(mann_whitney_neighbor(candidate_only), (20, 0))
        self.assertEqual(vdw_neighbor(candidate_only)[1:], (748, 0))

        second = exact_jt_signal(list(map(float, mw_only)))
        self.assertEqual((second.score, second.tail_count, second.direction), (21, 25_010, 0))
        self.assertEqual(mann_whitney_neighbor(mw_only), (10, 1))

        third = exact_jt_signal(list(map(float, opposite_vdw)))
        self.assertEqual((third.score, third.tail_count, third.direction), (30, 14_950, -1))
        self.assertEqual(vdw_neighbor(opposite_vdw), (-1_120_497_265_731_046, 430, 1))

    def test_ties_invalid_values_and_label_contract_fail_closed(self) -> None:
        tied = [float(value) for value in range(12)]
        tied[-1] = tied[-2] + 5.0e-13
        signal = exact_jt_signal(tied)
        self.assertTrue(signal.tie_detected)
        self.assertEqual((signal.assignment_count, signal.direction), (0, 0))
        with self.assertRaises(ValueError):
            exact_jt_signal([float(value) for value in range(11)] + [math.inf])
        with self.assertRaises(ValueError):
            jt_score((0,) * 12)

    def test_ratio_orientation_and_month_sequence_are_exact(self) -> None:
        changes = [value / 100.0 for value in [10, 3, 1, 4, 12, 7, 9, 6, 11, 8, 2, 5]]
        ratios = [math.log(10.0)]
        for change in changes:
            ratios.append(ratios[-1] + change)
        xag = [10.0] * 13
        xau = [silver * math.exp(ratio) for silver, ratio in zip(xag, ratios, strict=True)]
        derived = log_ratios(xau, xag)
        derived_changes = [right - left for left, right in zip(derived[:-1], derived[1:], strict=True)]
        self.assertEqual(exact_jt_signal(derived_changes).direction, -1)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 12 + [0.0], [1.0] * 13)
        endpoints = [
            202507, 202508, 202509, 202510, 202511, 202512, 202601,
            202602, 202603, 202604, 202605, 202606, 202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        endpoints[7] = 202603
        self.assertFalse(validate_month_keys(202608, endpoints))

    def test_source_manifest_registry_and_card_copy_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        headers, values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41285",
            "qm_magic_slot_offset": "0",
            "qm_rng_seed": "42",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_return_count": "12",
            "strategy_group_count": "3",
            "strategy_group_size": "4",
            "strategy_comparison_count": "48",
            "strategy_assignment_count": "34650",
            "strategy_tail_count_max": "18034",
            "strategy_score_center": "24",
            "strategy_lower_score_max": "19",
            "strategy_upper_score_min": "29",
            "strategy_relative_epsilon": "0.000000000001",
            "strategy_history_bars_d1": "900",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41285_XAU_XAG_JT_RV_D1")
        self.assertEqual(
            (
                manifest["host_symbol"], manifest["host_timeframe"],
                manifest["tester_currency"], manifest["tester_deposit"],
                manifest["q02_from_date"], manifest["q02_to_date"],
            ),
            ("XAUUSD.DWX", "D1", "USD", 100000, "2018.07.02", "2024.12.31"),
        )
        self.assertIn("Strategy_JonckheereTerpstraScoreFromLabels", source)
        self.assertIn("labels[lower_rank] < labels[higher_rank]", source)
        self.assertIn("int four_rank_masks[495]", source)
        self.assertIn("assignment_count != strategy_assignment_count", source)
        self.assertIn("qualifies_by_tail != qualifies_by_score", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertIn("QM_BasketOpenPosition", source)
        self.assertIn("double raw_xau_lots = 0.5 * full_xau_lots", source)
        self.assertIn("Strategy_PairCompositionValid(g_pair_expected_direction)", source)
        self.assertIn("Strategy_CloseAllOwned(QM_EXIT_TIME_STOP)", source)
        self.assertNotRegex(
            source,
            re.compile(r"\bi(?:RSI|MACD|Bands)\b|WebRequest|FileOpen|Python|ONNX|tensorflow|torch|sklearn|keras", re.I),
        )
        registry = MAGIC_REGISTRY.read_text(encoding="utf-8-sig")
        self.assertIn("41285,xauxag-mjt-rv,0,XAUUSD.DWX,412850000", registry)
        self.assertIn("41285,xauxag-mjt-rv,1,XAGUSD.DWX,412850001", registry)
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )

    def test_only_logical_and_component_fixed_risk_backtest_sets_exist(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertIn(LOGICAL_SET, setfiles)
        self.assertFalse(
            any(token in path.name.lower() for path in setfiles for token in ("live", "demo", "shadow", "stress"))
        )
        input_names = set(
            re.findall(
                r"(?m)^input\s+(?!group\b)(?:\w+\s+)+(\w+)\s*=",
                EA_SOURCE.read_text(encoding="utf-8-sig"),
            )
        )
        for path in setfiles:
            headers, values = parse_setfile(path)
            self.assertEqual((values["RISK_FIXED"], values["RISK_PERCENT"]), ("1000", "0"))
            self.assertEqual(values["PORTFOLIO_WEIGHT"], "1")
            self.assertEqual(set(values), input_names)
            self.assertEqual(headers["environment"], "backtest")
            self.assertEqual(headers["risk_mode"], "FIXED")
            self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")


if __name__ == "__main__":
    unittest.main()

