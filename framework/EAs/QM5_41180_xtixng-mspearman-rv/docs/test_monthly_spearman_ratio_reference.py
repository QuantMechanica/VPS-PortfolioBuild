from __future__ import annotations

from collections import Counter
import json
import math
import re
import unittest
from dataclasses import dataclass
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41180_xtixng-mspearman-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41180_xtixng-mspearman-rv_QM5_41180_XTI_XNG_MSPEARMAN_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41180_xtixng-mspearman-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"


@dataclass(frozen=True)
class SpearmanRatioSignal:
    direction: int
    ranks: tuple[int, ...]
    displacement_sum: int
    signed_score: int


def spearman_ratio_signal(values: list[float], threshold: int = 104) -> SpearmanRatioSignal:
    if len(values) != 13 or threshold != 104:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) for value in values):
        raise ValueError("finite log ratios required")
    if len(set(values)) != len(values):
        raise ValueError("ties consume flat")
    ordered = sorted(values)
    ranks = tuple(ordered.index(value) + 1 for value in values)
    if sorted(ranks) != list(range(1, 14)):
        raise AssertionError("rank permutation broken")
    displacement_sum = sum(
        (rank - time_rank) ** 2
        for time_rank, rank in enumerate(ranks, 1)
    )
    signed_score = 364 - displacement_sum
    if (
        not 0 <= displacement_sum <= 728
        or not -364 <= signed_score <= 364
        or displacement_sum % 2
        or signed_score % 2
    ):
        raise AssertionError("Spearman integer identity broken")
    direction = -1 if signed_score >= threshold else 1 if signed_score <= -threshold else 0
    return SpearmanRatioSignal(direction, ranks, displacement_sum, signed_score)


def log_ratios(xti: list[float], xng: list[float]) -> list[float]:
    if len(xti) != 13 or len(xng) != 13:
        raise ValueError("exactly thirteen synchronized closes required")
    if any(not math.isfinite(value) or value <= 0.0 for value in xti + xng):
        raise ValueError("positive finite closes required")
    return [
        math.log(oil) - math.log(gas)
        for oil, gas in zip(xti, xng, strict=True)
    ]


def exact_displacement_distribution(size: int = 13) -> Counter[int]:
    layer: dict[int, Counter[int]] = {0: Counter({0: 1})}
    for time_rank in range(1, size + 1):
        next_layer: dict[int, Counter[int]] = {}
        for used_mask, distribution in layer.items():
            for price_rank in range(1, size + 1):
                bit = 1 << (price_rank - 1)
                if used_mask & bit:
                    continue
                increment = (price_rank - time_rank) ** 2
                destination = next_layer.setdefault(used_mask | bit, Counter())
                for prior_sum, count in distribution.items():
                    destination[prior_sum + increment] += count
        layer = next_layer
    return layer[(1 << size) - 1]


def mann_kendall_score(ranks: tuple[int, ...]) -> int:
    return sum(
        (ranks[right] > ranks[left]) - (ranks[right] < ranks[left])
        for left in range(len(ranks))
        for right in range(left + 1, len(ranks))
    )


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


class MonthlySpearmanRatioReferenceTests(unittest.TestCase):
    def test_monotone_paths_open_exact_contrarian_sides(self) -> None:
        upward = spearman_ratio_signal([float(value) for value in range(1, 14)])
        downward = spearman_ratio_signal([float(value) for value in range(13, 0, -1)])
        self.assertEqual((upward.direction, upward.displacement_sum, upward.signed_score), (-1, 0, 364))
        self.assertEqual((downward.direction, downward.displacement_sum, downward.signed_score), (1, 728, -364))

    def test_exact_threshold_is_inclusive(self) -> None:
        boundary = (1, 2, 3, 6, 10, 12, 13, 11, 9, 8, 7, 5, 4)
        weak = (1, 2, 3, 6, 10, 13, 12, 11, 9, 8, 7, 5, 4)
        self.assertEqual(
            (spearman_ratio_signal(list(map(float, boundary))).direction,
             spearman_ratio_signal(list(map(float, boundary))).signed_score),
            (-1, 104),
        )
        self.assertEqual(spearman_ratio_signal(list(map(float, weak))).direction, 0)
        inverse = [float(14 - value) for value in boundary]
        self.assertEqual(
            (spearman_ratio_signal(inverse).direction, spearman_ratio_signal(inverse).signed_score),
            (1, -104),
        )

    def test_exact_density_lock(self) -> None:
        distribution = exact_displacement_distribution()
        positive = sum(count for value, count in distribution.items() if value <= 260)
        negative = sum(count for value, count in distribution.items() if value >= 468)
        self.assertEqual(sum(distribution.values()), math.factorial(13))
        self.assertEqual((positive, negative), (1_069_921_254, 1_069_921_254))
        self.assertAlmostEqual(
            (positive + negative) / math.factorial(13),
            0.3436382463986631,
            places=15,
        )

    def test_ties_and_invalid_values_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            spearman_ratio_signal([1.0] * 13)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 12 + [0.0], [1.0] * 13)
        with self.assertRaises(ValueError):
            spearman_ratio_signal([float(value) for value in range(1, 13)] + [math.inf])

    def test_locked_nonduplicate_fixtures(self) -> None:
        first = spearman_ratio_signal([3, 2, 10, 1, 4, 12, 11, 8, 7, 9, 6, 5, 13])
        second = spearman_ratio_signal([13, 1, 4, 12, 5, 2, 3, 6, 7, 8, 9, 10, 11])
        self.assertEqual((first.direction, first.signed_score, mann_kendall_score(first.ranks)), (-1, 170, 20))
        self.assertEqual((second.direction, second.signed_score, mann_kendall_score(second.ranks)), (0, 98, 28))

    def test_log_ratio_orientation_and_month_sequence(self) -> None:
        xti = [100.0 * math.exp(0.01 * index) for index in range(13)]
        xng = [10.0] * 13
        self.assertEqual(spearman_ratio_signal(log_ratios(xti, xng)).direction, -1)
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
            "qm_ea_id": "41180",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_score_threshold": "104",
            "strategy_history_bars_d1": "900",
            "strategy_xti_max_spread_points": "1500",
            "strategy_xng_max_spread_points": "3000",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(manifest["basket_symbols"], ["XTIUSD.DWX", "XNGUSD.DWX"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41180_XTI_XNG_MSPEARMAN_RV_D1")
        self.assertIn("rank_score = 364 - rank_displacement_sum", source)
        self.assertIn("rank_score >= strategy_score_threshold", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xng)", source)
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
