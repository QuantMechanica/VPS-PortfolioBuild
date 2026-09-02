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
EA_SOURCE = EA_DIR / "QM5_41286_xauxag-msiegel-tukey-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41286_xauxag-msiegel-tukey-rv_"
    "QM5_41286_XAU_XAG_ST_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41286_xauxag-msiegel-tukey-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"

N = 16
BLOCK = 8
SCORE_MAX = 68
TAIL_MAX = 6_698
RELATIVE_EPSILON = 1.0e-12
SIEGEL_TUKEY_SCORES = (1, 4, 5, 8, 9, 12, 13, 16, 15, 14, 11, 10, 7, 6, 3, 2)
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


@dataclass(frozen=True)
class SiegelTukeySignal:
    direction: int
    score: int
    assignment_count: int
    tail_count: int
    recent_move: float
    label_path: str
    tie_detected: bool = False


@lru_cache(maxsize=1)
def all_label_paths() -> tuple[tuple[int, ...], ...]:
    paths: list[tuple[int, ...]] = []
    for recent_ranks in itertools.combinations(range(N), BLOCK):
        recent = set(recent_ranks)
        paths.append(tuple(1 if rank in recent else 0 for rank in range(N)))
    return tuple(paths)


def st_score(labels: tuple[int, ...]) -> int:
    if len(labels) != N or labels.count(0) != BLOCK or labels.count(1) != BLOCK:
        raise ValueError("strict eight-by-eight label path required")
    return sum(score for score, label in zip(SIEGEL_TUKEY_SCORES, labels, strict=True) if label)


@lru_cache(maxsize=1)
def all_st_scores() -> tuple[int, ...]:
    return tuple(st_score(labels) for labels in all_label_paths())


def relatively_tied(left: float, right: float) -> bool:
    tolerance = RELATIVE_EPSILON * max(1.0, abs(left), abs(right))
    return abs(left - right) <= tolerance


def exact_st_signal(changes: list[float]) -> SiegelTukeySignal:
    if len(changes) != N or any(not math.isfinite(value) for value in changes):
        raise ValueError("sixteen finite changes required")
    recent_move = sum(changes[BLOCK:])
    if any(
        relatively_tied(changes[left], changes[right])
        for left in range(N)
        for right in range(left + 1, N)
    ):
        return SiegelTukeySignal(0, 0, 0, 0, recent_move, "", True)

    labelled = [(value, 0 if index < BLOCK else 1) for index, value in enumerate(changes)]
    labelled.sort(key=lambda item: item[0])
    labels = tuple(label for _, label in labelled)
    observed = st_score(labels)
    scores = all_st_scores()
    tail = sum(candidate <= observed for candidate in scores)
    qualifies_by_score = observed <= SCORE_MAX
    qualifies_by_tail = tail <= TAIL_MAX
    if qualifies_by_score != qualifies_by_tail:
        raise AssertionError("locked score and inclusive lower tail disagree")
    direction = 0
    if qualifies_by_score and recent_move != 0.0:
        direction = -1 if recent_move > 0.0 else 1
    return SiegelTukeySignal(
        direction,
        observed,
        len(scores),
        tail,
        recent_move,
        "".join("R" if label else "O" for label in labels),
    )


def centered_rank_changes(ranks: list[int]) -> list[float]:
    if sorted(ranks) != list(range(1, N + 1)):
        raise ValueError("one copy of every rank from one through sixteen required")
    return [rank - 8.5 for rank in ranks]


def changes_from_recent_rank_indexes(recent_indexes: tuple[int, ...]) -> list[float]:
    recent = set(recent_indexes)
    if len(recent) != BLOCK or not recent <= set(range(N)):
        raise ValueError("eight unique zero-based ranks required")
    old_values = [rank + 1 - 8.5 for rank in range(N) if rank not in recent]
    recent_values = [rank + 1 - 8.5 for rank in range(N) if rank in recent]
    return old_values + recent_values


@lru_cache(maxsize=None)
def all_neighbor_scores(numerators: tuple[int, ...]) -> tuple[int, ...]:
    return tuple(
        sum(numerators[index] for index in recent)
        for recent in itertools.combinations(range(12), 6)
    )


def twelve_change_neighbor(
    changes: list[float], numerators: tuple[int, ...], tail_max: int
) -> tuple[int, int, int]:
    latest = changes[-12:]
    order = sorted(range(12), key=latest.__getitem__)
    score = sum(
        numerators[rank]
        for rank, original_index in enumerate(order)
        if original_index >= 6
    )
    tail = sum(abs(candidate) >= abs(score) for candidate in all_neighbor_scores(numerators))
    direction = -1 if tail <= tail_max and score > 0 else 1 if tail <= tail_max and score < 0 else 0
    return score, tail, direction


def log_ratios(xau: list[float], xag: list[float]) -> list[float]:
    if len(xau) != 17 or len(xag) != 17:
        raise ValueError("exactly seventeen synchronized closes required")
    if any(not math.isfinite(value) or value <= 0.0 for value in xau + xag):
        raise ValueError("positive finite closes required")
    return [math.log(gold) - math.log(silver) for gold, silver in zip(xau, xag, strict=True)]


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    return (
        len(endpoints) == 17
        and next_month_key(endpoints[-1]) == current_month
        and all(next_month_key(left) == right for left, right in zip(endpoints[:-1], endpoints[1:], strict=True))
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


class MonthlySiegelTukeyReferenceTests(unittest.TestCase):
    def test_score_path_and_complete_allocation_distribution_are_locked(self) -> None:
        self.assertEqual(sorted(SIEGEL_TUKEY_SCORES), list(range(1, 17)))
        self.assertEqual(sum(SIEGEL_TUKEY_SCORES), 136)
        scores = all_st_scores()
        distribution = Counter(scores)
        self.assertEqual(len(scores), 12_870)
        self.assertEqual((min(scores), max(scores)), (36, 100))
        self.assertTrue(all(distribution[value] == distribution[136 - value] for value in range(36, 101)))
        self.assertEqual(sum(score <= SCORE_MAX for score in scores), TAIL_MAX)

    def test_inclusive_score_and_lower_tail_boundary_are_equivalent(self) -> None:
        scores = all_st_scores()

        def lower_tail(observed: int) -> int:
            return sum(candidate <= observed for candidate in scores)

        self.assertEqual(lower_tail(68), 6_698)
        self.assertEqual(lower_tail(70), 7_732)
        self.assertTrue(
            all((lower_tail(score) <= TAIL_MAX) == (score <= SCORE_MAX) for score in range(36, 101))
        )

    def test_locked_candidate_only_fixture_is_not_vdw_or_savage(self) -> None:
        changes = centered_rank_changes([7, 6, 1, 8, 14, 9, 5, 15, 2, 12, 3, 11, 4, 10, 16, 13])
        signal = exact_st_signal(changes)
        self.assertEqual(
            (signal.score, signal.tail_count, signal.recent_move, signal.direction),
            (61, 3_252, 3.0, -1),
        )
        self.assertEqual(twelve_change_neighbor(changes, VDW_NUMERATORS, 462)[1:], (854, 0))
        self.assertEqual(twelve_change_neighbor(changes, SAVAGE_NUMERATORS, 462)[1:], (798, 0))

    def test_locked_neighbor_only_fixture_keeps_candidate_flat(self) -> None:
        changes = changes_from_recent_rank_indexes((0, 1, 2, 3, 4, 5, 7, 8))
        signal = exact_st_signal(changes)
        self.assertEqual((signal.score, signal.tail_count, signal.direction), (70, 7_732, 0))
        self.assertEqual(twelve_change_neighbor(changes, VDW_NUMERATORS, 462)[1:], (396, 1))
        self.assertEqual(twelve_change_neighbor(changes, SAVAGE_NUMERATORS, 462)[1:], (130, 1))

    def test_ties_invalid_values_ratio_orientation_and_months_fail_closed(self) -> None:
        tied = [float(value) for value in range(N)]
        tied[-1] = tied[-2] + 5.0e-13
        signal = exact_st_signal(tied)
        self.assertTrue(signal.tie_detected)
        self.assertEqual((signal.assignment_count, signal.direction), (0, 0))
        with self.assertRaises(ValueError):
            exact_st_signal([float(value) for value in range(N - 1)] + [math.inf])

        changes = [value / 100.0 for value in centered_rank_changes([7, 6, 1, 8, 14, 9, 5, 15, 2, 12, 3, 11, 4, 10, 16, 13])]
        ratios = [math.log(10.0)]
        for change in changes:
            ratios.append(ratios[-1] + change)
        xag = [10.0] * 17
        xau = [silver * math.exp(ratio) for silver, ratio in zip(xag, ratios, strict=True)]
        derived = log_ratios(xau, xag)
        derived_changes = [right - left for left, right in zip(derived[:-1], derived[1:], strict=True)]
        self.assertEqual(exact_st_signal(derived_changes).direction, -1)

        endpoints = [
            202504, 202505, 202506, 202507, 202508, 202509, 202510, 202511,
            202512, 202601, 202602, 202603, 202604, 202605, 202606, 202607, 202608,
        ]
        self.assertTrue(validate_month_keys(202609, endpoints))
        endpoints[8] = 202511
        self.assertFalse(validate_month_keys(202609, endpoints))

    def test_source_manifest_registry_and_card_copy_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        headers, values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41286",
            "qm_magic_slot_offset": "0",
            "qm_rng_seed": "42",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "17",
            "strategy_return_count": "16",
            "strategy_block_size": "8",
            "strategy_assignment_count": "12870",
            "strategy_score_max": "68",
            "strategy_tail_count_max": "6698",
            "strategy_relative_epsilon": "0.000000000001",
            "strategy_history_bars_d1": "1200",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41286_XAU_XAG_ST_RV_D1")
        self.assertEqual(
            (
                manifest["host_symbol"], manifest["host_timeframe"],
                manifest["tester_currency"], manifest["tester_deposit"],
                manifest["q02_from_date"], manifest["q02_to_date"],
            ),
            ("XAUUSD.DWX", "D1", "USD", 100000, "2018.07.02", "2024.12.31"),
        )
        self.assertIn("Strategy_SiegelTukeyScoreForRank", source)
        self.assertIn("case 0:  return 1", source)
        self.assertIn("case 15: return 2", source)
        self.assertIn("permutation_score <= observed_score", source)
        self.assertIn("qualifies_by_score != qualifies_by_tail", source)
        self.assertIn("chronological_ratios[strategy_return_count]", source)
        self.assertIn("direction = (recent_move > 0.0) ? -1 : 1", source)
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
        self.assertIn("41286,xauxag-msiegel-tukey-rv,0,XAUUSD.DWX,412860000", registry)
        self.assertIn("41286,xauxag-msiegel-tukey-rv,1,XAGUSD.DWX,412860001", registry)
        self.assertEqual(EA_CARD.read_text(encoding="utf-8-sig"), CANONICAL_CARD.read_text(encoding="utf-8-sig"))

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
