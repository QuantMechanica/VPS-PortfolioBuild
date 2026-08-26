from __future__ import annotations

from collections import Counter
import dataclasses
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41173_wti-mspearman-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41173_wti-mspearman-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41173_wti-mspearman-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"


@dataclasses.dataclass(frozen=True)
class SpearmanSignal:
    direction: int
    ranks: tuple[int, ...]
    rank_sum: int
    displacements: tuple[int, ...]
    displacement_sum: int
    signed_score: int


def spearman_signal(
    closes: list[float], min_abs_score: int = 104
) -> SpearmanSignal:
    if len(closes) != 13 or min_abs_score != 104:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")
    if len(set(closes)) != len(closes):
        raise ValueError("ties fail closed")

    ordered = sorted(closes)
    ranks = tuple(ordered.index(value) + 1 for value in closes)
    if sorted(ranks) != list(range(1, 14)) or sum(ranks) != 91:
        raise AssertionError("rank permutation broken")

    displacements = tuple(rank - index for index, rank in enumerate(ranks, 1))
    displacement_sum = sum(value * value for value in displacements)
    signed_score = 364 - displacement_sum
    if (
        not 0 <= displacement_sum <= 728
        or not -364 <= signed_score <= 364
        or displacement_sum % 2 != 0
        or signed_score % 2 != 0
        or signed_score != 364 - displacement_sum
    ):
        raise AssertionError("Spearman integer identity broken")

    direction = 0
    if signed_score >= min_abs_score:
        direction = 1
    elif signed_score <= -min_abs_score:
        direction = -1
    return SpearmanSignal(
        direction=direction,
        ranks=ranks,
        rank_sum=sum(ranks),
        displacements=displacements,
        displacement_sum=displacement_sum,
        signed_score=signed_score,
    )


def exact_displacement_distribution(size: int = 13) -> Counter[int]:
    """Count every price-rank/time-rank displacement sum by subset DP."""
    layer: dict[int, Counter[int]] = {0: Counter({0: 1})}
    for time_rank in range(1, size + 1):
        next_layer: dict[int, Counter[int]] = {}
        for used_mask, distribution in layer.items():
            for price_rank in range(1, size + 1):
                bit = 1 << (price_rank - 1)
                if used_mask & bit:
                    continue
                increment = (price_rank - time_rank) ** 2
                destination = next_layer.setdefault(
                    used_mask | bit, Counter()
                )
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


def pettitt_direction(ranks: tuple[int, ...]) -> tuple[int, tuple[int, ...]]:
    path = tuple(
        2 * sum(ranks[:change_index]) - 14 * change_index
        for change_index in range(1, 13)
    )
    maximum = max(abs(value) for value in path)
    maxima = tuple(
        index
        for index, value in enumerate(path, 1)
        if abs(value) == maximum
    )
    if len(maxima) != 1 or not 4 <= maxima[0] <= 9:
        return 0, maxima
    signed_value = path[maxima[0] - 1]
    return (1 if signed_value < 0 else -1), maxima


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 13 or next_month_key(endpoints[-1]) != current_month:
        return False
    return all(
        next_month_key(left) == right
        for left, right in zip(endpoints, endpoints[1:])
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
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return headers, values


class MonthlySpearmanReferenceTests(unittest.TestCase):
    def test_monotonic_paths_and_score_identity_are_symmetric(self) -> None:
        upward = spearman_signal([float(value) for value in range(1, 14)])
        downward = spearman_signal([float(value) for value in range(13, 0, -1)])
        self.assertEqual(
            (upward.direction, upward.displacement_sum, upward.signed_score),
            (1, 0, 364),
        )
        self.assertEqual(
            (downward.direction, downward.displacement_sum, downward.signed_score),
            (-1, 728, -364),
        )
        self.assertEqual(upward.signed_score, -downward.signed_score)

    def test_exact_threshold_is_inclusive_and_weak_paths_are_flat(self) -> None:
        boundary = (1, 2, 3, 6, 10, 12, 13, 11, 9, 8, 7, 5, 4)
        weak = (1, 2, 3, 6, 10, 13, 12, 11, 9, 8, 7, 5, 4)
        positive = spearman_signal([float(value) for value in boundary])
        negative = spearman_signal([float(14 - value) for value in boundary])
        weak_positive = spearman_signal([float(value) for value in weak])
        weak_negative = spearman_signal([float(14 - value) for value in weak])
        self.assertEqual((positive.direction, positive.signed_score), (1, 104))
        self.assertEqual((negative.direction, negative.signed_score), (-1, -104))
        self.assertEqual((weak_positive.direction, weak_positive.signed_score), (0, 102))
        self.assertEqual((weak_negative.direction, weak_negative.signed_score), (0, -102))

    def test_exact_density_lock_covers_all_thirteen_factorial_paths(self) -> None:
        distribution = exact_displacement_distribution()
        positive = sum(count for value, count in distribution.items() if value <= 260)
        negative = sum(count for value, count in distribution.items() if value >= 468)
        self.assertEqual(sum(distribution.values()), math.factorial(13))
        self.assertEqual(positive, 1_069_921_254)
        self.assertEqual(negative, 1_069_921_254)
        self.assertEqual(positive + negative, 2_139_842_508)
        self.assertAlmostEqual(
            (positive + negative) / math.factorial(13),
            0.3436382463986631,
            places=15,
        )

    def test_ties_and_invalid_values_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            spearman_signal([1.0] * 13)
        with self.assertRaises(ValueError):
            spearman_signal([float(value) for value in range(1, 13)] + [0.0])
        with self.assertRaises(ValueError):
            spearman_signal([float(value) for value in range(1, 13)] + [math.inf])
        with self.assertRaises(ValueError):
            spearman_signal([float(value) for value in range(1, 14)], 102)

    def test_locked_nonduplicate_fixtures(self) -> None:
        spearman_buy_mk_flat = (3, 2, 10, 1, 4, 12, 11, 8, 7, 9, 6, 5, 13)
        first = spearman_signal([float(value) for value in spearman_buy_mk_flat])
        self.assertEqual((first.direction, first.signed_score), (1, 170))
        self.assertEqual(mann_kendall_score(first.ranks), 20)

        spearman_flat_mk_buy = (13, 1, 4, 12, 5, 2, 3, 6, 7, 8, 9, 10, 11)
        second = spearman_signal([float(value) for value in spearman_flat_mk_buy])
        self.assertEqual((second.direction, second.signed_score), (0, 98))
        self.assertEqual(mann_kendall_score(second.ranks), 28)

        spearman_buy_pettitt_flat = (1, 11, 3, 5, 7, 12, 4, 8, 10, 2, 13, 9, 6)
        third = spearman_signal([float(value) for value in spearman_buy_pettitt_flat])
        self.assertEqual((third.direction, third.signed_score), (1, 106))
        self.assertEqual(pettitt_direction(third.ranks), (0, (4, 5)))

        spearman_flat_pettitt_buy = (8, 3, 9, 2, 13, 11, 1, 12, 6, 7, 4, 5, 10)
        fourth = spearman_signal([float(value) for value in spearman_flat_pettitt_buy])
        self.assertEqual((fourth.direction, fourth.signed_score), (0, 8))
        self.assertEqual(pettitt_direction(fourth.ranks), (1, (4,)))

    def test_thirteen_consecutive_completed_months(self) -> None:
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
        self.assertFalse(validate_month_keys(202608, endpoints[:-1]))
        broken = endpoints.copy()
        broken[7] = 202603
        self.assertFalse(validate_month_keys(202608, broken))

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41173")
        self.assertEqual(headers["ea_slug"], "wti-mspearman-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        expected = {
            "qm_ea_id": "41173",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_min_abs_score": "104",
            "strategy_history_bars_d1": "900",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "40",
            "strategy_max_spread_points": "1500",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

    def test_source_contract_and_card_copy(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_SpearmanSignal", source)
        self.assertIn("ranks[index] - (index + 1)", source)
        self.assertIn("metrics.signed_score = 364 - metrics.displacement_sum", source)
        self.assertIn("metrics.signed_score >= strategy_min_abs_score", source)
        self.assertIn("metrics.signed_score <= -strategy_min_abs_score", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41173", source)
        self.assertNotIn("Strategy_PettittSignal", source)
        self.assertNotIn("strategy_min_change_index", source)
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )

    def test_only_backtest_setfile_exists(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
