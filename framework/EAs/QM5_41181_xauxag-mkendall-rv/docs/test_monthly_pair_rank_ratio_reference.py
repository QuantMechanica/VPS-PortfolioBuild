from __future__ import annotations

import json
import math
import re
import unittest
from dataclasses import dataclass
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41181_xauxag-mkendall-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41181_xauxag-mkendall-rv_QM5_41181_XAU_XAG_MKENDALL_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41181_xauxag-mkendall-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"


@dataclass(frozen=True)
class PairRankSignal:
    direction: int
    pair_count: int
    signed_score: int


def pair_rank_signal(values: list[float], threshold: int = 14) -> PairRankSignal:
    if len(values) != 13 or threshold != 14:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) for value in values):
        raise ValueError("finite log ratios required")
    if len(set(values)) != len(values):
        raise ValueError("ties consume flat")
    comparisons = [
        (values[newer] > values[older]) - (values[newer] < values[older])
        for older in range(len(values) - 1)
        for newer in range(older + 1, len(values))
    ]
    pair_count = len(comparisons)
    signed_score = sum(comparisons)
    if (
        pair_count != 78
        or not -pair_count <= signed_score <= pair_count
        or signed_score % 2
        or (pair_count - abs(signed_score)) % 2
    ):
        raise AssertionError("pair-score invariant broken")
    direction = -1 if signed_score >= threshold else 1 if signed_score <= -threshold else 0
    return PairRankSignal(direction, pair_count, signed_score)


def spearman_integer_score(ranks: tuple[int, ...]) -> int:
    return 364 - sum(
        (rank - time_rank) ** 2
        for time_rank, rank in enumerate(ranks, 1)
    )


def exact_inversion_distribution(size: int = 13) -> list[int]:
    counts = [1]
    for width in range(1, size + 1):
        next_counts = [0] * (len(counts) + width - 1)
        for inversions, count in enumerate(counts):
            for added in range(width):
                next_counts[inversions + added] += count
        counts = next_counts
    return counts


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


class MonthlyPairRankRatioReferenceTests(unittest.TestCase):
    def test_monotone_paths_open_exact_contrarian_sides(self) -> None:
        upward = pair_rank_signal([float(value) for value in range(1, 14)])
        downward = pair_rank_signal([float(value) for value in range(13, 0, -1)])
        self.assertEqual((upward.direction, upward.pair_count, upward.signed_score), (-1, 78, 78))
        self.assertEqual((downward.direction, downward.pair_count, downward.signed_score), (1, 78, -78))

    def test_exact_threshold_is_inclusive_and_symmetric(self) -> None:
        boundary = [1, 6, 13, 3, 7, 4, 12, 8, 10, 5, 9, 2, 11]
        weak = [9, 8, 7, 2, 6, 4, 1, 10, 3, 12, 5, 13, 11]
        self.assertEqual((pair_rank_signal(boundary).direction, pair_rank_signal(boundary).signed_score), (-1, 14))
        self.assertEqual((pair_rank_signal(weak).direction, pair_rank_signal(weak).signed_score), (0, 12))
        inverse = [14 - value for value in boundary]
        self.assertEqual((pair_rank_signal(inverse).direction, pair_rank_signal(inverse).signed_score), (1, -14))

    def test_exact_density_lock(self) -> None:
        distribution = exact_inversion_distribution()
        qualifying = sum(
            count
            for inversions, count in enumerate(distribution)
            if abs(78 - 2 * inversions) >= 14
        )
        self.assertEqual(sum(distribution), math.factorial(13))
        self.assertEqual(qualifying, 2_711_123_108)
        self.assertAlmostEqual(
            qualifying / math.factorial(13),
            0.4353804483839206,
            places=15,
        )

    def test_ties_and_invalid_values_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            pair_rank_signal([1.0] * 13)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 12 + [0.0], [1.0] * 13)
        with self.assertRaises(ValueError):
            pair_rank_signal([float(value) for value in range(1, 13)] + [math.inf])

    def test_locked_nonduplicate_fixtures(self) -> None:
        spearman_only = (9, 8, 7, 2, 6, 4, 1, 10, 3, 12, 5, 13, 11)
        pair_only = (1, 6, 13, 3, 7, 4, 12, 8, 10, 5, 9, 2, 11)
        self.assertEqual((pair_rank_signal(list(spearman_only)).signed_score, spearman_integer_score(spearman_only)), (12, 118))
        self.assertEqual((pair_rank_signal(list(pair_only)).signed_score, spearman_integer_score(pair_only)), (14, 80))

    def test_log_ratio_orientation_and_month_sequence(self) -> None:
        xau = [100.0 * math.exp(0.01 * index) for index in range(13)]
        xag = [10.0] * 13
        self.assertEqual(pair_rank_signal(log_ratios(xau, xag)).direction, -1)
        endpoints = [
            202507, 202508, 202509, 202510, 202511, 202512, 202601,
            202602, 202603, 202604, 202605, 202606, 202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        endpoints[7] = 202603
        self.assertFalse(validate_month_keys(202608, endpoints))

    def test_source_manifest_sets_and_card_copy_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41181",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_score_threshold": "14",
            "strategy_history_bars_d1": "900",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41181_XAU_XAG_MKENDALL_RV_D1")
        self.assertIn("++pair_count", source)
        self.assertIn("pair_count != 78", source)
        self.assertIn("pair_score >= strategy_score_threshold", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertNotRegex(source, re.compile(r"iRSI|iMACD|iBands|WebRequest"))
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )

    def test_only_fixed_risk_backtest_sets_exist(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))
        for path in setfiles:
            values = parse_setfile(path)
            self.assertEqual((values["RISK_FIXED"], values["RISK_PERCENT"]), ("1000", "0"))


if __name__ == "__main__":
    unittest.main()
