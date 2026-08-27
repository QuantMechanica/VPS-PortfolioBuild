from __future__ import annotations

import dataclasses
from itertools import combinations
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41184_wti-mww-runs-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41184_wti-mww-runs-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41184_wti-mww-runs-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"


@dataclasses.dataclass(frozen=True)
class TwoSampleRunsSignal:
    direction: int
    label_runs: int
    membership_path: tuple[str, ...]
    old_median: float
    new_median: float


def two_sample_runs_signal(
    closes: list[float], max_label_runs: int = 6
) -> TwoSampleRunsSignal:
    if len(closes) != 10 or max_label_runs != 6:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")
    if len(set(closes)) != len(closes):
        raise ValueError("ties fail closed")

    ordered = sorted(enumerate(closes), key=lambda item: item[1])
    membership = tuple("O" if index < 5 else "N" for index, _ in ordered)
    old_count = membership.count("O")
    new_count = membership.count("N")
    label_runs = 1 + sum(
        left != right for left, right in zip(membership, membership[1:])
    )
    if old_count != 5 or new_count != 5 or not 2 <= label_runs <= 10:
        raise AssertionError("pooled membership scan broken")

    old_median = sorted(closes[:5])[2]
    new_median = sorted(closes[5:])[2]
    direction = 0
    if label_runs <= max_label_runs:
        direction = (new_median > old_median) - (new_median < old_median)
    return TwoSampleRunsSignal(
        direction=direction,
        label_runs=label_runs,
        membership_path=membership,
        old_median=old_median,
        new_median=new_median,
    )


def closes_for_old_ranks(old_ranks: tuple[int, ...]) -> list[float]:
    old_set = set(old_ranks)
    if len(old_ranks) != 5 or len(old_set) != 5:
        raise ValueError("requires five distinct old ranks")
    new_ranks = tuple(rank for rank in range(1, 11) if rank not in old_set)
    if len(new_ranks) != 5:
        raise ValueError("requires five complementary new ranks")
    return [float(rank) for rank in old_ranks + new_ranks]


def exact_assignment_density() -> tuple[
    dict[int, int], int, int, int, int
]:
    distribution = {run_count: 0 for run_count in range(2, 11)}
    total = buy = sell = flat = 0
    for old_ranks in combinations(range(1, 11), 5):
        signal = two_sample_runs_signal(closes_for_old_ranks(old_ranks))
        distribution[signal.label_runs] += 1
        total += 1
        if signal.direction > 0:
            buy += 1
        elif signal.direction < 0:
            sell += 1
        else:
            flat += 1
    return distribution, total, buy, sell, flat


def mann_whitney_u_new(closes: list[float]) -> int:
    if len(closes) != 10 or len(set(closes)) != 10:
        raise ValueError("requires ten strict values")
    return sum(new > old for old in closes[:5] for new in closes[5:])


def signed_ecdf_counts(membership: tuple[str, ...]) -> tuple[int, int]:
    old_seen = new_seen = d_plus = d_minus = 0
    for label in membership:
        if label == "O":
            old_seen += 1
        elif label == "N":
            new_seen += 1
        else:
            raise ValueError("unknown membership label")
        delta = old_seen - new_seen
        d_plus = max(d_plus, delta)
        d_minus = max(d_minus, -delta)
    return d_plus, d_minus


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 10 or next_month_key(endpoints[-1]) != current_month:
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


class MonthlyTwoSampleRunsReferenceTests(unittest.TestCase):
    def test_inclusive_six_run_boundary_and_seven_run_flat(self) -> None:
        six_runs = two_sample_runs_signal(
            closes_for_old_ranks((2, 5, 6, 9, 10))
        )
        seven_runs = two_sample_runs_signal(
            closes_for_old_ranks((1, 5, 7, 9, 10))
        )
        self.assertEqual("".join(six_runs.membership_path), "NONNOONNOO")
        self.assertEqual((six_runs.label_runs, six_runs.direction), (6, -1))
        self.assertEqual("".join(seven_runs.membership_path), "ONNNONONOO")
        self.assertEqual((seven_runs.label_runs, seven_runs.direction), (7, 0))
        self.assertLess(six_runs.new_median, six_runs.old_median)
        self.assertLess(seven_runs.new_median, seven_runs.old_median)

    def test_exact_distribution_density_and_side_symmetry(self) -> None:
        distribution, total, buy, sell, flat = exact_assignment_density()
        self.assertEqual(
            distribution,
            {2: 2, 3: 8, 4: 32, 5: 48, 6: 72, 7: 48, 8: 32, 9: 8, 10: 2},
        )
        self.assertEqual((total, buy, sell, flat), (252, 81, 81, 90))
        self.assertEqual(buy + sell, 162)
        self.assertAlmostEqual((buy + sell) / total, 9 / 14, places=15)
        self.assertAlmostEqual(12 * (buy + sell) / total, 54 / 7, places=15)
        within_block_orders = math.factorial(5) ** 2
        self.assertEqual(total * within_block_orders, math.factorial(10))

    def test_every_label_reflection_preserves_runs_and_reverses_side(self) -> None:
        for old_ranks in combinations(range(1, 11), 5):
            reflected_old = tuple(
                rank for rank in range(1, 11) if rank not in set(old_ranks)
            )
            signal = two_sample_runs_signal(closes_for_old_ranks(old_ranks))
            reflected = two_sample_runs_signal(
                closes_for_old_ranks(reflected_old)
            )
            self.assertEqual(signal.label_runs, reflected.label_runs)
            self.assertEqual(signal.direction, -reflected.direction)

    def test_ties_invalid_values_and_unlocked_threshold_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            two_sample_runs_signal([1.0] * 10)
        with self.assertRaises(ValueError):
            two_sample_runs_signal([float(value) for value in range(1, 10)] + [0.0])
        with self.assertRaises(ValueError):
            two_sample_runs_signal(
                [float(value) for value in range(1, 10)] + [math.inf]
            )
        with self.assertRaises(ValueError):
            two_sample_runs_signal([float(value) for value in range(1, 11)], 5)

    def test_same_mann_whitney_sum_separates_six_and_seven_runs(self) -> None:
        qualify = closes_for_old_ranks((2, 5, 6, 9, 10))
        stay_flat = closes_for_old_ranks((1, 5, 7, 9, 10))
        qualify_signal = two_sample_runs_signal(qualify)
        flat_signal = two_sample_runs_signal(stay_flat)
        self.assertEqual(mann_whitney_u_new(qualify), 8)
        self.assertEqual(mann_whitney_u_new(stay_flat), 8)
        self.assertEqual((qualify_signal.label_runs, qualify_signal.direction), (6, -1))
        self.assertEqual((flat_signal.label_runs, flat_signal.direction), (7, 0))

    def test_signed_ecdf_tied_extrema_can_still_qualify(self) -> None:
        closes = closes_for_old_ranks((1, 2, 4, 9, 10))
        signal = two_sample_runs_signal(closes)
        self.assertEqual("".join(signal.membership_path), "OONONNNNOO")
        self.assertEqual((signal.label_runs, signal.direction), (5, 1))
        self.assertEqual(signed_ecdf_counts(signal.membership_path), (2, 2))

    def test_within_block_chronology_is_irrelevant(self) -> None:
        left = closes_for_old_ranks((1, 2, 4, 9, 10))
        right = [9.0, 1.0, 10.0, 4.0, 2.0, 8.0, 3.0, 7.0, 5.0, 6.0]
        self.assertEqual(two_sample_runs_signal(left), two_sample_runs_signal(right))

    def test_ten_consecutive_completed_months(self) -> None:
        endpoints = [
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
        broken[6] = 202603
        self.assertFalse(validate_month_keys(202608, broken))

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41184")
        self.assertEqual(headers["ea_slug"], "wti-mww-runs-shift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        expected = {
            "qm_ea_id": "41184",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "qm_rng_seed": "42",
            "qm_news_temporal": "0",
            "qm_news_compliance": "0",
            "qm_news_mode_legacy": "0",
            "qm_friday_close_enabled": "false",
            "qm_stress_reject_probability": "0",
            "strategy_endpoint_count": "10",
            "strategy_block_size": "5",
            "strategy_max_label_runs": "6",
            "strategy_history_bars_d1": "900",
            "strategy_entry_window_minutes": "180",
            "strategy_max_endpoint_gap_days": "10",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "40",
            "strategy_max_spread_points": "1500",
            "strategy_deviation_points": "20",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

    def test_source_contract_card_copy_and_magic(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_TwoSampleRunsSignal", source)
        self.assertIn("member_old != previous_old", source)
        self.assertIn("metrics.label_runs <= strategy_max_label_runs", source)
        self.assertIn("strategy_max_label_runs != 6", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41184", source)
        self.assertNotIn("Strategy_MannWhitneySignal", source)
        self.assertNotIn("Strategy_SignedEcdfSignal", source)
        self.assertNotIn("iRSI", source)
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )
        rows = MAGIC_REGISTRY.read_text(encoding="utf-8-sig").splitlines()
        self.assertEqual(
            [row for row in rows if row.startswith("41184,")],
            [
                "41184,wti-mww-runs-shift-tr,0,XTIUSD.DWX,411840000,"
                "2026-08-27,Codex governed allocator,active"
            ],
        )

    def test_only_backtest_setfile_exists(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
