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
EA_SOURCE = EA_DIR / "QM5_41263_xauxag-mkuiper-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41263_xauxag-mkuiper-rv_QM5_41263_XAU_XAG_MKUIPER_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41263_xauxag-mkuiper-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"


@dataclass(frozen=True)
class KuiperSignal:
    direction: int
    statistic: float
    d_plus: float
    d_minus: float
    assignment_count: int
    tail_count: int
    recent_rank_sum: int
    label_path: str


def kuiper_from_labels(labels: tuple[int, ...]) -> tuple[float, float, float]:
    if len(labels) != 12 or labels.count(0) != 6 or labels.count(1) != 6:
        raise ValueError("exactly six old and six recent labels required")
    old_seen = 0
    recent_seen = 0
    d_plus = 0.0
    d_minus = 0.0
    for label in labels:
        old_seen += label == 0
        recent_seen += label == 1
        recent_minus_old = recent_seen / 6.0 - old_seen / 6.0
        d_plus = max(d_plus, recent_minus_old)
        d_minus = max(d_minus, -recent_minus_old)
    return d_plus + d_minus, d_plus, d_minus


def ad2_from_labels(labels: tuple[int, ...]) -> float:
    """Independent closest-neighbor comparator used only by dedup fixtures."""
    if len(labels) != 12 or labels.count(0) != 6 or labels.count(1) != 6:
        raise ValueError("exactly six old and six recent labels required")
    old_seen = 0
    recent_seen = 0
    total = 0.0
    for rank, label in enumerate(labels[:-1], start=1):
        old_seen += label == 0
        recent_seen += label == 1
        old_delta = 12 * old_seen - 6 * rank
        recent_delta = 12 * recent_seen - 6 * rank
        total += (
            old_delta * old_delta / 6.0 + recent_delta * recent_delta / 6.0
        ) / (rank * (12 - rank))
    return total / 12.0


@lru_cache(maxsize=1)
def all_label_paths() -> tuple[tuple[int, ...], ...]:
    paths: list[tuple[int, ...]] = []
    for recent_ranks in itertools.combinations(range(12), 6):
        recent = set(recent_ranks)
        paths.append(tuple(1 if rank in recent else 0 for rank in range(12)))
    return tuple(paths)


@lru_cache(maxsize=1)
def all_kuiper_statistics() -> tuple[float, ...]:
    return tuple(kuiper_from_labels(labels)[0] for labels in all_label_paths())


@lru_cache(maxsize=1)
def all_ad2_statistics() -> tuple[float, ...]:
    return tuple(ad2_from_labels(labels) for labels in all_label_paths())


def exact_kuiper_signal(changes: list[float]) -> KuiperSignal:
    if len(changes) != 12 or any(not math.isfinite(value) for value in changes):
        raise ValueError("twelve finite changes required")
    if len(set(changes)) != 12:
        return KuiperSignal(0, 0.0, 0.0, 0.0, 0, 0, 0, "")

    labelled = [(value, 0 if index < 6 else 1) for index, value in enumerate(changes)]
    labelled.sort(key=lambda item: item[0])
    labels = tuple(label for _, label in labelled)
    observed, d_plus, d_minus = kuiper_from_labels(labels)
    epsilon = 1.0e-12 * max(1.0, abs(observed))
    statistics = all_kuiper_statistics()
    tail_count = sum(value + epsilon >= observed for value in statistics)
    rank_sum = sum(rank for rank, label in enumerate(labels, start=1) if label == 1)
    qualifies = observed + 1.0e-12 >= 0.5 and tail_count <= 798
    direction = 0
    if qualifies and rank_sum != 39:
        direction = -1 if rank_sum > 39 else 1
    return KuiperSignal(
        direction,
        observed,
        d_plus,
        d_minus,
        len(statistics),
        tail_count,
        rank_sum,
        "".join("R" if label else "O" for label in labels),
    )


def changes_from_label_path(path: str) -> list[float]:
    if len(path) != 12 or path.count("O") != 6 or path.count("R") != 6:
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


class MonthlyExactKuiperReferenceTests(unittest.TestCase):
    def test_locked_dedup_fixtures_disagree_with_ad2(self) -> None:
        kuiper_only = exact_kuiper_signal(changes_from_label_path("RROROROOROOR"))
        ad2_only = exact_kuiper_signal(changes_from_label_path("RROROROROORO"))
        reverse = exact_kuiper_signal(changes_from_label_path("OORORORRORRO"))
        self.assertEqual(
            (
                kuiper_only.label_path,
                kuiper_only.statistic,
                kuiper_only.tail_count,
                kuiper_only.recent_rank_sum,
                kuiper_only.direction,
            ),
            ("RROROROOROOR", 0.5, 798, 34, 1),
        )
        self.assertAlmostEqual(ad2_only.statistic, 1 / 3, places=15)
        self.assertEqual((ad2_only.tail_count, ad2_only.direction), (922, 0))
        self.assertEqual((reverse.tail_count, reverse.direction), (798, -1))
        kuiper_labels = tuple(1 if char == "R" else 0 for char in kuiper_only.label_path)
        ad2_labels = tuple(1 if char == "R" else 0 for char in ad2_only.label_path)
        kuiper_ad_tail = sum(
            value + 1.0e-12 >= ad2_from_labels(kuiper_labels)
            for value in all_ad2_statistics()
        )
        ad2_ad_tail = sum(
            value + 1.0e-12 >= ad2_from_labels(ad2_labels)
            for value in all_ad2_statistics()
        )
        self.assertEqual((kuiper_ad_tail, ad2_ad_tail), (532, 428))

    def test_exact_enumeration_prior_is_locked_and_market_free(self) -> None:
        signals = [
            exact_kuiper_signal(changes_from_label_path("".join("R" if x else "O" for x in path)))
            for path in all_label_paths()
        ]
        qualifying = [
            signal
            for signal in signals
            if signal.statistic + 1.0e-12 >= 0.5 and signal.tail_count <= 798
        ]
        neutral = [signal for signal in qualifying if signal.recent_rank_sum == 39]
        directional = [signal for signal in qualifying if signal.direction != 0]
        self.assertEqual(len(all_label_paths()), 924)
        self.assertEqual((len(qualifying), len(neutral), len(directional)), (798, 38, 760))
        histogram: dict[float, int] = {}
        for value in all_kuiper_statistics():
            key = round(value, 12)
            histogram[key] = histogram.get(key, 0) + 1
        self.assertEqual(
            histogram,
            {
                round(1 / 6, 12): 2,
                round(1 / 3, 12): 124,
                0.5: 390,
                round(2 / 3, 12): 300,
                round(5 / 6, 12): 96,
                1.0: 12,
            },
        )

    def test_formula_adds_opposing_extrema_and_is_label_symmetric(self) -> None:
        labels = tuple(1 if char == "R" else 0 for char in "RROROROOROOR")
        complement = tuple(1 - label for label in labels)
        observed, d_plus, d_minus = kuiper_from_labels(labels)
        reverse, reverse_plus, reverse_minus = kuiper_from_labels(complement)
        self.assertAlmostEqual(observed, 0.5, places=15)
        self.assertAlmostEqual(d_plus, 1 / 3, places=15)
        self.assertAlmostEqual(d_minus, 1 / 6, places=15)
        self.assertAlmostEqual(observed, reverse, places=15)
        self.assertAlmostEqual(d_plus, reverse_minus, places=15)
        self.assertAlmostEqual(d_minus, reverse_plus, places=15)
        with self.assertRaises(ValueError):
            kuiper_from_labels(labels[:-1])

    def test_exact_change_tie_and_invalid_values_consume_or_fail_closed(self) -> None:
        tied = [float(value) for value in range(11)] + [10.0]
        self.assertEqual(
            exact_kuiper_signal(tied),
            KuiperSignal(0, 0.0, 0.0, 0.0, 0, 0, 0, ""),
        )
        with self.assertRaises(ValueError):
            exact_kuiper_signal([float(value) for value in range(11)] + [math.inf])

    def test_ratio_orientation_and_month_sequence_are_exact(self) -> None:
        changes = changes_from_label_path("RROROROOROOR")
        ratio_path = [math.log(10.0)]
        for change in changes:
            ratio_path.append(ratio_path[-1] + change)
        xag = [10.0] * 13
        xau = [silver * math.exp(ratio) for silver, ratio in zip(xag, ratio_path, strict=True)]
        derived = log_ratios(xau, xag)
        self.assertEqual(exact_kuiper_signal([b - a for a, b in zip(derived[:-1], derived[1:], strict=True)]).direction, 1)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 12 + [0.0], [1.0] * 13)
        endpoints = [
            202507, 202508, 202509, 202510, 202511, 202512, 202601,
            202602, 202603, 202604, 202605, 202606, 202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        endpoints[7] = 202603
        self.assertFalse(validate_month_keys(202608, endpoints))

    def test_source_manifest_set_and_card_copy_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41263",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_return_count": "12",
            "strategy_block_size": "6",
            "strategy_assignment_count": "924",
            "strategy_min_kuiper_v": "0.5",
            "strategy_tail_count_max": "798",
            "strategy_stat_epsilon": "0.000000000001",
            "strategy_neutral_rank_sum": "39",
            "strategy_history_bars_d1": "900",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41263_XAU_XAG_MKUIPER_RV_D1")
        self.assertIn("Strategy_KuiperFromLabels", source)
        self.assertIn("for(int mask = 0; mask < (1 << strategy_return_count); ++mask)", source)
        self.assertIn("permutation_v + tail_epsilon >= observed_v", source)
        self.assertIn("d_plus = MathMax(d_plus, recent_minus_old)", source)
        self.assertIn("d_minus = MathMax(d_minus, old_minus_recent)", source)
        self.assertIn("observed_v + strategy_stat_epsilon >= strategy_min_kuiper_v", source)
        self.assertIn("tail_count <= strategy_tail_count_max", source)
        self.assertIn("recent_rank_sum > strategy_neutral_rank_sum", source)
        self.assertIn("relative_returns[left] == relative_returns[right]", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertIn("Strategy_RefreshExpectedDirection()", source)
        self.assertIn("Strategy_PairCompositionValid(g_pair_expected_direction)", source)
        self.assertNotRegex(source, re.compile(r"iRSI|iMACD|iBands|WebRequest"))
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )

    def test_only_factory_and_logical_fixed_risk_backtest_sets_exist(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertIn(LOGICAL_SET, setfiles)
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))
        for path in setfiles:
            values = parse_setfile(path)
            self.assertEqual((values["RISK_FIXED"], values["RISK_PERCENT"]), ("1000", "0"))


if __name__ == "__main__":
    unittest.main()
