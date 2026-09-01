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
EA_SOURCE = EA_DIR / "QM5_41278_xauxag-mcucconi-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41278_xauxag-mcucconi-rv_QM5_41278_XAU_XAG_CUCCONI_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41278_xauxag-mcucconi-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"

N = 12
BLOCK = 6
EXPECTED_SQUARE_SUM = 325.0
SQUARE_SUM_SD = math.sqrt(6955.0)
RHO = -479.0 / 535.0
RELATIVE_EPSILON = 1.0e-12


@dataclass(frozen=True)
class CucconiSignal:
    direction: int
    statistic: float
    assignment_count: int
    tail_count: int
    recent_rank_sum: int
    label_path: str
    tie_detected: bool = False


def cucconi_from_labels(labels: tuple[int, ...]) -> tuple[float, int]:
    if len(labels) != N or labels.count(0) != BLOCK or labels.count(1) != BLOCK:
        raise ValueError("exactly six old and six recent labels required")
    recent_ranks = [rank for rank, label in enumerate(labels, start=1) if label]
    rank_square_sum = sum(rank * rank for rank in recent_ranks)
    contrary_square_sum = sum((N + 1 - rank) ** 2 for rank in recent_ranks)
    u = (rank_square_sum - EXPECTED_SQUARE_SUM) / SQUARE_SUM_SD
    v = (contrary_square_sum - EXPECTED_SQUARE_SUM) / SQUARE_SUM_SD
    statistic = (u * u + v * v - 2.0 * RHO * u * v) / (
        2.0 * (1.0 - RHO * RHO)
    )
    return statistic, sum(recent_ranks)


@lru_cache(maxsize=1)
def all_label_paths() -> tuple[tuple[int, ...], ...]:
    paths: list[tuple[int, ...]] = []
    for recent_ranks in itertools.combinations(range(N), BLOCK):
        recent = set(recent_ranks)
        paths.append(tuple(1 if rank in recent else 0 for rank in range(N)))
    return tuple(paths)


@lru_cache(maxsize=1)
def all_statistics() -> tuple[float, ...]:
    return tuple(cucconi_from_labels(labels)[0] for labels in all_label_paths())


def relatively_tied(left: float, right: float) -> bool:
    tolerance = RELATIVE_EPSILON * max(1.0, abs(left), abs(right))
    return abs(left - right) <= tolerance


def exact_cucconi_signal(changes: list[float]) -> CucconiSignal:
    if len(changes) != N or any(not math.isfinite(value) for value in changes):
        raise ValueError("twelve finite changes required")
    if any(
        relatively_tied(changes[left], changes[right])
        for left in range(N)
        for right in range(left + 1, N)
    ):
        return CucconiSignal(0, 0.0, 0, 0, 0, "", True)

    labelled = [(value, 0 if index < BLOCK else 1) for index, value in enumerate(changes)]
    labelled.sort(key=lambda item: item[0])
    labels = tuple(label for _, label in labelled)
    observed, rank_sum = cucconi_from_labels(labels)
    tolerance = RELATIVE_EPSILON * max(1.0, abs(observed))
    statistics = all_statistics()
    tail_count = sum(value + tolerance >= observed for value in statistics)
    qualifies = tail_count <= 480
    direction = 0
    if qualifies and rank_sum != 39:
        direction = -1 if rank_sum > 39 else 1
    return CucconiSignal(
        direction,
        observed,
        len(statistics),
        tail_count,
        rank_sum,
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


class MonthlyExactCucconiReferenceTests(unittest.TestCase):
    def test_locked_nonduplicate_fixtures_have_exact_tail_decisions(self) -> None:
        ad_boundary = exact_cucconi_signal(changes_from_label_path("RROROROOORRO"))
        kuiper_boundary = exact_cucconi_signal(changes_from_label_path("RROROROROROO"))
        klotz_reject = exact_cucconi_signal(changes_from_label_path("RRRRROOROOOO"))
        klotz_only = exact_cucconi_signal(changes_from_label_path("RROROROROORO"))
        self.assertAlmostEqual(ad_boundary.statistic, 0.7655677655677652, places=15)
        self.assertEqual((ad_boundary.tail_count, ad_boundary.recent_rank_sum, ad_boundary.direction), (480, 34, 1))
        self.assertAlmostEqual(kuiper_boundary.statistic, 0.8205128205128197, places=15)
        self.assertEqual((kuiper_boundary.tail_count, kuiper_boundary.recent_rank_sum, kuiper_boundary.direction), (456, 31, 1))
        self.assertAlmostEqual(klotz_reject.statistic, 3.2875457875457896, places=15)
        self.assertEqual((klotz_reject.tail_count, klotz_reject.recent_rank_sum, klotz_reject.direction), (14, 23, 1))
        self.assertAlmostEqual(klotz_only.statistic, 0.7161172161172157, places=15)
        self.assertEqual((klotz_only.tail_count, klotz_only.direction), (484, 0))

    def test_exact_enumeration_prior_and_sell_symmetry_are_locked(self) -> None:
        signals = [
            exact_cucconi_signal(
                changes_from_label_path("".join("R" if value else "O" for value in path))
            )
            for path in all_label_paths()
        ]
        qualifying = [signal for signal in signals if signal.tail_count <= 480]
        neutral = [signal for signal in qualifying if signal.recent_rank_sum == 39]
        directional = [signal for signal in qualifying if signal.direction != 0]
        self.assertEqual(len(all_label_paths()), 924)
        self.assertEqual((len(qualifying), len(neutral), len(directional)), (480, 18, 462))
        buy = exact_cucconi_signal(changes_from_label_path("RROROROOORRO"))
        complement = "".join("O" if value == "R" else "R" for value in buy.label_path)
        sell = exact_cucconi_signal(changes_from_label_path(complement))
        self.assertAlmostEqual(buy.statistic, sell.statistic, places=15)
        self.assertEqual((buy.direction, sell.direction), (1, -1))

    def test_source_defined_moments_and_correlation_are_exact(self) -> None:
        self.assertAlmostEqual(SQUARE_SUM_SD, 83.3966426182733, places=13)
        self.assertAlmostEqual(RHO, -0.8953271028037383, places=15)
        statistic, rank_sum = cucconi_from_labels(tuple(1 if char == "R" else 0 for char in "RROROROOORRO"))
        self.assertAlmostEqual(statistic, 0.7655677655677652, places=15)
        self.assertEqual(rank_sum, 34)
        with self.assertRaises(ValueError):
            cucconi_from_labels((0,) * 12)

    def test_relative_change_tie_and_invalid_values_fail_closed(self) -> None:
        tied = [float(value) for value in range(12)]
        tied[-1] = tied[-2] + 5.0e-13
        signal = exact_cucconi_signal(tied)
        self.assertTrue(signal.tie_detected)
        self.assertEqual((signal.assignment_count, signal.direction), (0, 0))
        with self.assertRaises(ValueError):
            exact_cucconi_signal([float(value) for value in range(11)] + [math.inf])

    def test_ratio_orientation_and_month_sequence_are_exact(self) -> None:
        changes = changes_from_label_path("RROROROOORRO")
        ratio_path = [math.log(10.0)]
        for change in changes:
            ratio_path.append(ratio_path[-1] + change)
        xag = [10.0] * 13
        xau = [silver * math.exp(ratio) for silver, ratio in zip(xag, ratio_path, strict=True)]
        derived = log_ratios(xau, xag)
        derived_changes = [right - left for left, right in zip(derived[:-1], derived[1:], strict=True)]
        self.assertEqual(exact_cucconi_signal(derived_changes).direction, 1)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 12 + [0.0], [1.0] * 13)
        endpoints = [
            202507, 202508, 202509, 202510, 202511, 202512, 202601,
            202602, 202603, 202604, 202605, 202606, 202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        endpoints[7] = 202603
        self.assertFalse(validate_month_keys(202608, endpoints))

    def test_source_manifest_set_registry_and_card_copy_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41278",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_return_count": "12",
            "strategy_block_size": "6",
            "strategy_assignment_count": "924",
            "strategy_tail_count_max": "480",
            "strategy_relative_epsilon": "0.000000000001",
            "strategy_rank_square_expectation": "325.0",
            "strategy_rank_square_sd": "83.3966426182733",
            "strategy_rank_component_rho": "-0.8953271028037383",
            "strategy_neutral_rank_sum": "39",
            "strategy_history_bars_d1": "900",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41278_XAU_XAG_CUCCONI_RV_D1")
        self.assertEqual((manifest["tester_currency"], manifest["tester_deposit"]), ("USD", 100000))
        self.assertIn("Strategy_CucconiFromLabels", source)
        self.assertIn("rank_square_sum += rank * rank", source)
        self.assertIn("contrary_rank_square_sum += contrary_rank * contrary_rank", source)
        self.assertIn("for(int mask = 0; mask < (1 << strategy_return_count); ++mask)", source)
        self.assertIn("permutation_c + tail_epsilon >= observed_c", source)
        self.assertIn("tail_count <= strategy_tail_count_max", source)
        self.assertIn("MathAbs(relative_returns[left] - relative_returns[right]) <=", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertIn("Strategy_RefreshExpectedDirection()", source)
        self.assertIn("Strategy_PairCompositionValid(g_pair_expected_direction)", source)
        self.assertIn("Strategy_CloseAllOwned(QM_EXIT_TIME_STOP)", source)
        self.assertNotRegex(source, re.compile(r"iRSI|iMACD|iBands|WebRequest"))
        registry = MAGIC_REGISTRY.read_text(encoding="utf-8-sig")
        self.assertIn("41278,xauxag-mcucconi-rv,0,XAUUSD.DWX,412780000", registry)
        self.assertIn("41278,xauxag-mcucconi-rv,1,XAGUSD.DWX,412780001", registry)
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
            self.assertEqual((values["RISK_FIXED"], values["RISK_PERCENT"]), ("1000", "0"))
            self.assertEqual(values["PORTFOLIO_WEIGHT"], "1")


if __name__ == "__main__":
    unittest.main()
