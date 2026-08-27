from __future__ import annotations

import dataclasses
from itertools import combinations
import json
import math
from pathlib import Path
import re
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41186_xtixng-median-runs-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41186_xtixng-median-runs-rv_QM5_41186_XTI_XNG_MEDRUN_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41186_xtixng-median-runs-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"


@dataclasses.dataclass(frozen=True)
class MedianRunsRatioSignal:
    direction: int
    ranks: tuple[int, ...]
    rank_sum: int
    median_index: int
    signs: tuple[int, ...]
    low_count: int
    high_count: int
    run_count: int
    newest_rank: int


def count_runs(signs: tuple[int, ...]) -> int:
    if len(signs) != 12 or any(sign not in (-1, 1) for sign in signs):
        raise ValueError("exactly twelve binary states required")
    run_count = 1 + sum(left != right for left, right in zip(signs, signs[1:]))
    if not 2 <= run_count <= 12:
        raise ValueError("balanced dichotomy requires 2..12 runs")
    return run_count


def validate_rank_state(
    ranks: tuple[int, ...], signs: tuple[int, ...], median_index: int
) -> int:
    if len(ranks) != 13 or sorted(ranks) != list(range(1, 14)):
        raise ValueError("strict 1..13 rank permutation required")
    median_indices = tuple(index for index, rank in enumerate(ranks) if rank == 7)
    if median_indices != (median_index,):
        raise ValueError("the unique median rank must be the omitted observation")
    expected_signs = tuple(-1 if rank < 7 else 1 for rank in ranks if rank != 7)
    if signs != expected_signs:
        raise ValueError("median omission or chronological sign path is wrong")
    if signs.count(-1) != 6 or signs.count(1) != 6:
        raise ValueError("six/six dichotomy required")
    return count_runs(signs)


def median_runs_ratio_signal(
    ratios: list[float], max_runs: int = 7
) -> MedianRunsRatioSignal:
    if len(ratios) != 13 or max_runs != 7:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) for value in ratios):
        raise ValueError("finite log ratios required")
    if len(set(ratios)) != len(ratios):
        raise ValueError("ties fail closed")

    ordered = sorted(ratios)
    ranks = tuple(ordered.index(value) + 1 for value in ratios)
    median_indices = tuple(index for index, rank in enumerate(ranks) if rank == 7)
    if len(median_indices) != 1:
        raise AssertionError("unique median broken")
    median_index = median_indices[0]
    signs = tuple(-1 if rank < 7 else 1 for rank in ranks if rank != 7)
    run_count = validate_rank_state(ranks, signs, median_index)
    newest_rank = ranks[-1]

    # Positive means BUY XTI / SELL XNG. The basket fades the newest ratio
    # regime, so its side is the inverse of the outright persistence rule.
    direction = 0
    if run_count <= max_runs:
        if newest_rank > 7:
            direction = -1
        elif newest_rank < 7:
            direction = 1
    return MedianRunsRatioSignal(
        direction=direction,
        ranks=ranks,
        rank_sum=sum(ranks),
        median_index=median_index,
        signs=signs,
        low_count=signs.count(-1),
        high_count=signs.count(1),
        run_count=run_count,
        newest_rank=newest_rank,
    )


def ranks_for_signs(signs: tuple[int, ...], median_position: int) -> list[float]:
    if len(signs) != 12 or signs.count(-1) != 6 or signs.count(1) != 6:
        raise ValueError("requires six lows and six highs")
    if not 0 <= median_position <= 12:
        raise ValueError("median position outside 13-state path")
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
            signal = median_runs_ratio_signal(
                ranks_for_signs(signs, median_position)
            )
            total += 1
            if signal.direction > 0:
                buy += 1
            elif signal.direction < 0:
                sell += 1
            else:
                flat += 1
    return total, buy, sell, flat


def log_ratios(xti: list[float], xng: list[float]) -> list[float]:
    if len(xti) != 13 or len(xng) != 13:
        raise ValueError("exactly thirteen synchronized closes required")
    if any(not math.isfinite(value) or value <= 0.0 for value in xti + xng):
        raise ValueError("positive finite closes required")
    return [
        math.log(oil) - math.log(gas)
        for oil, gas in zip(xti, xng, strict=True)
    ]


def spearman_direction(ranks: tuple[int, ...]) -> tuple[int, int]:
    if len(ranks) != 13 or sorted(ranks) != list(range(1, 14)):
        raise ValueError("thirteen strict ranks required")
    score = 364 - sum(
        (rank - time_rank) ** 2
        for time_rank, rank in enumerate(ranks, 1)
    )
    return (-1 if score >= 104 else 1 if score <= -104 else 0), score


def mann_whitney_direction(values: list[float]) -> tuple[int, int]:
    sample = values[-12:]
    if len(sample) != 12 or len(set(sample)) != 12:
        raise ValueError("twelve strict values required")
    older, newer = sample[:6], sample[6:]
    u_new = sum(new > old for new in newer for old in older)
    return (-1 if u_new >= 24 else 1 if u_new <= 12 else 0), u_new


def cox_stuart_direction(values: list[float]) -> tuple[int, tuple[int, ...]]:
    if len(values) != 14 or len(set(values)) != 14:
        raise ValueError("fourteen strict values required")
    signs = tuple(
        (values[index + 7] > values[index])
        - (values[index + 7] < values[index])
        for index in range(7)
    )
    positives = signs.count(1)
    negatives = signs.count(-1)
    direction = -1 if positives >= 5 else 1 if negatives >= 5 else 0
    return direction, signs


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


class MonthlyMedianRunsRatioReferenceTests(unittest.TestCase):
    def test_monotone_paths_open_exact_contrarian_sides(self) -> None:
        upward = median_runs_ratio_signal([float(value) for value in range(1, 14)])
        downward = median_runs_ratio_signal(
            [float(value) for value in range(13, 0, -1)]
        )
        self.assertEqual(
            (upward.run_count, upward.newest_rank, upward.direction),
            (2, 13, -1),
        )
        self.assertEqual(
            (downward.run_count, downward.newest_rank, downward.direction),
            (2, 1, 1),
        )

    def test_median_is_omitted_before_adjacency(self) -> None:
        ratios = [10, 3, 8, 5, 1, 11, 7, 12, 9, 13, 2, 6, 4]
        signal = median_runs_ratio_signal([float(value) for value in ratios])
        self.assertEqual(signal.median_index, 6)
        self.assertEqual(
            signal.signs,
            (1, -1, 1, -1, -1, 1, 1, 1, 1, -1, -1, -1),
        )
        self.assertEqual((signal.run_count, signal.newest_rank, signal.direction), (6, 4, 1))

    def test_inclusive_seven_run_boundary_and_eight_run_flat(self) -> None:
        seven_runs = (1, 1, -1, -1, 1, 1, -1, -1, 1, -1, -1, 1)
        short_ratio = median_runs_ratio_signal(ranks_for_signs(seven_runs, 5))
        long_ratio = median_runs_ratio_signal(
            [float(14 - int(value)) for value in ranks_for_signs(seven_runs, 5)]
        )
        self.assertEqual((short_ratio.run_count, short_ratio.direction), (7, -1))
        self.assertEqual((long_ratio.run_count, long_ratio.direction), (7, 1))

        eight_runs = (-1, -1, -1, 1, -1, 1, -1, 1, -1, 1, 1, 1)
        flat = median_runs_ratio_signal(ranks_for_signs(eight_runs, 6))
        self.assertEqual((flat.run_count, flat.newest_rank, flat.direction), (8, 13, 0))

    def test_newest_median_is_flat_even_when_persistent(self) -> None:
        signs = (-1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1)
        signal = median_runs_ratio_signal(ranks_for_signs(signs, 12))
        self.assertEqual((signal.run_count, signal.newest_rank, signal.direction), (2, 7, 0))

    def test_exact_density_and_side_symmetry(self) -> None:
        total, buy, sell, flat = exact_representation_density()
        self.assertEqual((total, buy, sell, flat), (12_012, 3_372, 3_372, 5_268))
        self.assertEqual(buy + sell, 6_744)
        self.assertAlmostEqual((buy + sell) / total, 562 / 1001, places=15)
        within_regime_orders = math.factorial(6) ** 2
        self.assertEqual(total * within_regime_orders, math.factorial(13))

    def test_invalid_rank_median_balance_run_and_values_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            median_runs_ratio_signal([1.0] * 13)
        with self.assertRaises(ValueError):
            median_runs_ratio_signal([float(value) for value in range(1, 13)])
        with self.assertRaises(ValueError):
            median_runs_ratio_signal([float(value) for value in range(1, 13)] + [math.inf])
        with self.assertRaises(ValueError):
            median_runs_ratio_signal([float(value) for value in range(1, 14)], 6)
        ranks = tuple(range(1, 14))
        signs = tuple([-1] * 6 + [1] * 6)
        with self.assertRaises(ValueError):
            validate_rank_state(ranks[:-1] + (12,), signs, 6)
        with self.assertRaises(ValueError):
            validate_rank_state(ranks, signs, 5)
        with self.assertRaises(ValueError):
            validate_rank_state(ranks, tuple([-1] * 7 + [1] * 5), 6)
        with self.assertRaises(ValueError):
            count_runs(tuple([-1] * 12))

    def test_locked_fixture_separates_four_existing_mechanics(self) -> None:
        fourteen = [7, 10, 6, 3, 8, 5, 14, 12, 1, 9, 2, 4, 13, 11]
        signal = median_runs_ratio_signal([float(value) for value in fourteen[-13:]])
        self.assertEqual((signal.direction, signal.run_count), (-1, 7))
        self.assertEqual(spearman_direction(signal.ranks), (0, 38))
        self.assertEqual(mann_whitney_direction(fourteen), (0, 14))
        self.assertEqual(cox_stuart_direction(fourteen)[0], 0)
        outright_wti_persistence_direction = -signal.direction
        self.assertEqual(outright_wti_persistence_direction, 1)
        self.assertNotEqual(outright_wti_persistence_direction, signal.direction)

    def test_log_ratio_orientation_and_month_sequence(self) -> None:
        xti = [100.0 * math.exp(0.01 * index) for index in range(13)]
        xng = [10.0] * 13
        self.assertEqual(median_runs_ratio_signal(log_ratios(xti, xng)).direction, -1)
        endpoints = [
            202507, 202508, 202509, 202510, 202511, 202512, 202601,
            202602, 202603, 202604, 202605, 202606, 202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        self.assertFalse(validate_month_keys(202608, endpoints[:-1]))
        broken = endpoints.copy()
        broken[7] = 202603
        self.assertFalse(validate_month_keys(202608, broken))

    def test_source_manifest_sets_card_and_magics_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        headers, values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41186",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_max_runs": "7",
            "strategy_history_bars_d1": "900",
            "strategy_entry_window_minutes": "180",
            "strategy_max_endpoint_gap_days": "10",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_notional_ratio": "1.0",
            "strategy_max_notional_mismatch_fraction": "0.20",
            "strategy_max_hold_days": "40",
            "strategy_xti_max_spread_points": "1500",
            "strategy_xng_max_spread_points": "3000",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(headers["symbol"], manifest["logical_symbol"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41186_XTI_XNG_MEDRUN_RV_D1")
        self.assertEqual(manifest["basket_symbols"], ["XTIUSD.DWX", "XNGUSD.DWX"])
        self.assertIn("Strategy_LoadMonthlyMedianRuns", source)
        self.assertIn("if(rank == 7)", source)
        self.assertIn("signs[index] != signs[index - 1]", source)
        self.assertIn("metrics.run_count <= strategy_max_runs", source)
        self.assertIn("metrics.direction = -1", source)
        self.assertIn("metrics.direction = 1", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xng)", source)
        self.assertNotRegex(source, re.compile(r"iRSI|iMACD|iBands|WebRequest"))
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )
        rows = MAGIC_REGISTRY.read_text(encoding="utf-8-sig").splitlines()
        self.assertEqual(
            [row for row in rows if row.startswith("41186,")],
            [
                "41186,xtixng-median-runs-rv,0,XTIUSD.DWX,411860000,"
                "2026-08-27,Codex governed allocator,active",
                "41186,xtixng-median-runs-rv,1,XNGUSD.DWX,411860001,"
                "2026-08-27,Codex governed allocator,active",
            ],
        )

    def test_only_fixed_risk_backtest_sets_exist(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))
        for path in setfiles:
            headers, values = parse_setfile(path)
            self.assertEqual(headers["environment"], "backtest")
            self.assertEqual(headers["risk_mode"], "FIXED")
            self.assertEqual((values["RISK_FIXED"], values["RISK_PERCENT"]), ("1000", "0"))
            self.assertEqual(values["strategy_max_runs"], "7")


if __name__ == "__main__":
    unittest.main()
