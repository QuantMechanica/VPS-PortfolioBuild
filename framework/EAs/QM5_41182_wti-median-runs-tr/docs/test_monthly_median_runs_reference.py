from __future__ import annotations

import dataclasses
from itertools import combinations
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41182_wti-median-runs-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41182_wti-median-runs-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41182_wti-median-runs-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"


@dataclasses.dataclass(frozen=True)
class MedianRunsSignal:
    direction: int
    ranks: tuple[int, ...]
    rank_sum: int
    median_index: int
    signs: tuple[int, ...]
    low_count: int
    high_count: int
    run_count: int
    newest_rank: int


def median_runs_signal(
    closes: list[float], max_runs: int = 7
) -> MedianRunsSignal:
    if len(closes) != 13 or max_runs != 7:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")
    if len(set(closes)) != len(closes):
        raise ValueError("ties fail closed")

    ordered = sorted(closes)
    ranks = tuple(ordered.index(value) + 1 for value in closes)
    if sorted(ranks) != list(range(1, 14)) or sum(ranks) != 91:
        raise AssertionError("rank permutation broken")

    median_indices = tuple(index for index, rank in enumerate(ranks) if rank == 7)
    if len(median_indices) != 1:
        raise AssertionError("unique median broken")
    signs = tuple(-1 if rank < 7 else 1 for rank in ranks if rank != 7)
    low_count = signs.count(-1)
    high_count = signs.count(1)
    if len(signs) != 12 or low_count != 6 or high_count != 6:
        raise AssertionError("balanced dichotomy broken")
    run_count = 1 + sum(left != right for left, right in zip(signs, signs[1:]))
    if not 2 <= run_count <= 12:
        raise AssertionError("run-count bounds broken")

    newest_rank = ranks[-1]
    direction = 0
    if run_count <= max_runs:
        if newest_rank > 7:
            direction = 1
        elif newest_rank < 7:
            direction = -1
    return MedianRunsSignal(
        direction=direction,
        ranks=ranks,
        rank_sum=sum(ranks),
        median_index=median_indices[0],
        signs=signs,
        low_count=low_count,
        high_count=high_count,
        run_count=run_count,
        newest_rank=newest_rank,
    )


def ranks_for_signs(signs: tuple[int, ...], median_position: int) -> list[float]:
    if len(signs) != 12 or signs.count(-1) != 6 or signs.count(1) != 6:
        raise ValueError("requires six lows and six highs")
    lows = iter(range(1, 7))
    highs = iter(range(8, 14))
    ranks = [next(lows) if sign < 0 else next(highs) for sign in signs]
    ranks.insert(median_position, 7)
    return [float(rank) for rank in ranks]


def exact_representation_density() -> tuple[int, int, int, int]:
    total = buy = sell = flat = 0
    for high_positions in combinations(range(12), 6):
        high_set = set(high_positions)
        signs = tuple(1 if index in high_set else -1 for index in range(12))
        for median_position in range(13):
            signal = median_runs_signal(ranks_for_signs(signs, median_position))
            total += 1
            if signal.direction > 0:
                buy += 1
            elif signal.direction < 0:
                sell += 1
            else:
                flat += 1
    return total, buy, sell, flat


def mann_kendall_score(ranks: tuple[int, ...]) -> int:
    return sum(
        (ranks[right] > ranks[left]) - (ranks[right] < ranks[left])
        for left in range(len(ranks))
        for right in range(left + 1, len(ranks))
    )


def spearman_integer_score(ranks: tuple[int, ...]) -> int:
    displacement_sum = sum(
        (rank - time_rank) ** 2
        for time_rank, rank in enumerate(ranks, 1)
    )
    return 364 - displacement_sum


def monthly_return_sign_runs(ranks: tuple[int, ...]) -> tuple[int, int]:
    signs = tuple(
        (right > left) - (right < left)
        for left, right in zip(ranks, ranks[1:])
    )
    longest = {-1: 0, 1: 0}
    current_sign = 0
    current_length = 0
    for sign in signs:
        if sign == current_sign:
            current_length += 1
        else:
            current_sign = sign
            current_length = 1
        longest[sign] = max(longest[sign], current_length)
    return longest[1], longest[-1]


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


class MonthlyMedianRunsReferenceTests(unittest.TestCase):
    def test_median_is_omitted_before_adjacency(self) -> None:
        ranks = [10, 3, 8, 5, 1, 11, 7, 12, 9, 13, 2, 6, 4]
        signal = median_runs_signal([float(value) for value in ranks])
        self.assertEqual(signal.median_index, 6)
        self.assertEqual(
            signal.signs,
            (1, -1, 1, -1, -1, 1, 1, 1, 1, -1, -1, -1),
        )
        self.assertEqual((signal.run_count, signal.newest_rank, signal.direction), (6, 4, -1))

    def test_inclusive_seven_run_boundary_and_eight_run_flat(self) -> None:
        seven_runs = (1, 1, -1, -1, 1, 1, -1, -1, 1, -1, -1, 1)
        buy = median_runs_signal(ranks_for_signs(seven_runs, 5))
        sell = median_runs_signal(
            [float(14 - int(value)) for value in ranks_for_signs(seven_runs, 5)]
        )
        self.assertEqual((buy.run_count, buy.direction), (7, 1))
        self.assertEqual((sell.run_count, sell.direction), (7, -1))

        eight_runs = (-1, -1, -1, 1, -1, 1, -1, 1, -1, 1, 1, 1)
        flat = median_runs_signal(ranks_for_signs(eight_runs, 6))
        self.assertEqual((flat.run_count, flat.newest_rank, flat.direction), (8, 13, 0))

    def test_newest_median_is_flat_even_when_persistent(self) -> None:
        signs = (-1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1)
        signal = median_runs_signal(ranks_for_signs(signs, 12))
        self.assertEqual((signal.run_count, signal.newest_rank, signal.direction), (2, 7, 0))

    def test_exact_density_and_side_symmetry(self) -> None:
        total, buy, sell, flat = exact_representation_density()
        self.assertEqual((total, buy, sell, flat), (12_012, 3_372, 3_372, 5_268))
        self.assertEqual(buy + sell, 6_744)
        self.assertAlmostEqual((buy + sell) / total, 562 / 1001, places=15)
        within_regime_orders = math.factorial(6) ** 2
        self.assertEqual(total * within_regime_orders, math.factorial(13))
        self.assertEqual((buy + sell) * within_regime_orders, 3_496_089_600)

    def test_ties_invalid_values_and_unlocked_threshold_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            median_runs_signal([1.0] * 13)
        with self.assertRaises(ValueError):
            median_runs_signal([float(value) for value in range(1, 13)] + [0.0])
        with self.assertRaises(ValueError):
            median_runs_signal([float(value) for value in range(1, 13)] + [math.inf])
        with self.assertRaises(ValueError):
            median_runs_signal([float(value) for value in range(1, 14)], 6)

    def test_locked_nonduplicate_fixture(self) -> None:
        ranks = (10, 3, 8, 5, 1, 11, 7, 12, 9, 13, 2, 6, 4)
        signal = median_runs_signal([float(value) for value in ranks])
        self.assertEqual((signal.direction, signal.run_count), (-1, 6))
        self.assertEqual(mann_kendall_score(signal.ranks), 0)
        self.assertEqual(spearman_integer_score(signal.ranks), -8)
        self.assertEqual(monthly_return_sign_runs(signal.ranks), (1, 2))

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
        self.assertEqual(headers["ea_id"], "41182")
        self.assertEqual(headers["ea_slug"], "wti-median-runs-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        expected = {
            "qm_ea_id": "41182",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_max_runs": "7",
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

    def test_source_contract_card_copy_and_magic(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_MedianRunsSignal", source)
        self.assertIn("if(rank == 7)", source)
        self.assertIn("signs[index] != signs[index - 1]", source)
        self.assertIn("metrics.run_count <= strategy_max_runs", source)
        self.assertIn("metrics.newest_rank > 7", source)
        self.assertIn("metrics.newest_rank < 7", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41182", source)
        self.assertNotIn("Strategy_SpearmanSignal", source)
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )
        rows = MAGIC_REGISTRY.read_text(encoding="utf-8-sig").splitlines()
        self.assertEqual(
            [row for row in rows if row.startswith("41182,")],
            [
                "41182,wti-median-runs-tr,0,XTIUSD.DWX,411820000,"
                "2026-08-27,Codex governed allocator,active"
            ],
        )

    def test_only_backtest_setfile_exists(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
