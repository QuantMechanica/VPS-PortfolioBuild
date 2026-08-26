from __future__ import annotations

import csv
import math
import unittest
from dataclasses import dataclass
from datetime import date
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
LOSS_TOLERANCE = 1.0e-12


@dataclass(frozen=True)
class RobustConsensus:
    direction: int
    theilsen: float
    lad: float
    repeated_median: float
    lad_intercept: float
    minimum_loss: float
    final_loss: float
    pair_count: int
    objective_count: int
    minimizer_count: int
    pivot_count: int
    grouped_slope_count: int


def ordinary_median(values: list[float]) -> float:
    if not values or any(not math.isfinite(value) for value in values):
        raise ValueError("finite nonempty values required")
    ordered = sorted(values)
    center = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[center]
    return ordered[center - 1] / 2.0 + ordered[center] / 2.0


def strict_sign(value: float) -> int:
    if not math.isfinite(value):
        raise ValueError("finite value required")
    return 1 if value > 0 else -1 if value < 0 else 0


def consensus_from_logs(log_prices: list[float]) -> RobustConsensus:
    if len(log_prices) != 13 or any(
        not math.isfinite(value) for value in log_prices
    ):
        raise ValueError("exactly thirteen finite log prices required")

    pair_slopes = [
        (log_prices[newer] - log_prices[older]) / (newer - older)
        for older in range(12)
        for newer in range(older + 1, 13)
    ]
    if len(pair_slopes) != 78:
        raise AssertionError("pair-slope contract broken")
    theilsen = ordinary_median(pair_slopes)

    losses: list[float] = []
    for slope in pair_slopes:
        residuals = [
            log_prices[index] - slope * index for index in range(13)
        ]
        intercept = sorted(residuals)[6]
        loss = sum(
            abs(log_prices[index] - intercept - slope * index)
            for index in range(13)
        )
        if not math.isfinite(intercept) or not math.isfinite(loss) or loss < 0:
            raise AssertionError("invalid profiled LAD objective")
        losses.append(loss)

    minimum_loss = min(losses)
    minimizers = sorted(
        slope
        for slope, loss in zip(pair_slopes, losses, strict=True)
        if abs(loss - minimum_loss) <= LOSS_TOLERANCE
    )
    lad = ordinary_median(minimizers)
    final_residuals = [
        log_prices[index] - lad * index for index in range(13)
    ]
    lad_intercept = sorted(final_residuals)[6]
    final_loss = sum(
        abs(log_prices[index] - lad_intercept - lad * index)
        for index in range(13)
    )
    if abs(final_loss - minimum_loss) > LOSS_TOLERANCE:
        raise AssertionError("median minimizer left minimum-loss face")

    pivot_medians: list[float] = []
    grouped_slope_count = 0
    for pivot in range(13):
        slopes: list[float] = []
        for other in range(13):
            if other == pivot:
                continue
            older, newer = sorted((pivot, other))
            slopes.append(
                (log_prices[newer] - log_prices[older]) / (newer - older)
            )
            grouped_slope_count += 1
        if len(slopes) != 12:
            raise AssertionError("pivot-slope contract broken")
        pivot_medians.append(ordinary_median(slopes))
    repeated_median = ordinary_median(pivot_medians)

    signs = tuple(strict_sign(value) for value in (theilsen, lad, repeated_median))
    direction = signs[0] if signs[0] != 0 and len(set(signs)) == 1 else 0
    return RobustConsensus(
        direction=direction,
        theilsen=theilsen,
        lad=lad,
        repeated_median=repeated_median,
        lad_intercept=lad_intercept,
        minimum_loss=minimum_loss,
        final_loss=final_loss,
        pair_count=len(pair_slopes),
        objective_count=len(losses),
        minimizer_count=len(minimizers),
        pivot_count=len(pivot_medians),
        grouped_slope_count=grouped_slope_count,
    )


def consensus_from_closes(closes: list[float]) -> RobustConsensus:
    if len(closes) != 13 or any(
        not math.isfinite(value) or value <= 0 for value in closes
    ):
        raise ValueError("exactly thirteen positive finite closes required")
    return consensus_from_logs([math.log(value) for value in closes])


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    if month == 12:
        return (year + 1) * 100 + 1
    return year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 13:
        return False
    if any(
        next_month_key(left) != right
        for left, right in zip(endpoints, endpoints[1:])
    ):
        return False
    return next_month_key(endpoints[-1]) == current_month


class MonthlyRobustThreeConsensusReferenceTests(unittest.TestCase):
    def test_unanimous_positive_negative_and_zero(self) -> None:
        upward = consensus_from_logs([0.01 * index for index in range(13)])
        downward = consensus_from_logs([-0.01 * index for index in range(13)])
        flat = consensus_from_logs([0.0] * 13)

        self.assertEqual((upward.direction, downward.direction, flat.direction), (1, -1, 0))
        for value in (upward.theilsen, upward.lad, upward.repeated_median):
            self.assertAlmostEqual(value, 0.01, places=14)
        for value in (downward.theilsen, downward.lad, downward.repeated_median):
            self.assertAlmostEqual(value, -0.01, places=14)
        self.assertEqual(flat.minimizer_count, 78)

    def test_repeated_median_disagreement_consumes_flat(self) -> None:
        logs = [
            0.0,
            0.01,
            0.06,
            0.11,
            0.14,
            0.13,
            0.11,
            0.12,
            0.09,
            0.04,
            0.02,
            0.05,
            0.10,
        ]
        signal = consensus_from_logs(logs)
        self.assertAlmostEqual(signal.theilsen, 0.00155555555555556, places=14)
        self.assertAlmostEqual(signal.lad, 0.00375, places=14)
        self.assertAlmostEqual(signal.repeated_median, -0.0045, places=14)
        self.assertEqual(signal.direction, 0)

    def test_lad_disagreement_consumes_flat(self) -> None:
        logs = [
            0.0,
            0.02,
            0.0,
            0.0,
            -0.06,
            -0.09,
            -0.05,
            -0.05,
            0.03,
            0.06,
            -0.02,
            -0.03,
            0.05,
        ]
        signal = consensus_from_logs(logs)
        self.assertAlmostEqual(signal.lad, -0.002, places=14)
        self.assertGreater(signal.theilsen, 0.0)
        self.assertGreater(signal.repeated_median, 0.0)
        self.assertEqual(signal.direction, 0)

    def test_exact_counts_and_lad_minimum_face(self) -> None:
        logs = [0.003 * index + (0.02 if index == 4 else 0.0) for index in range(13)]
        signal = consensus_from_logs(logs)
        self.assertEqual(signal.pair_count, 78)
        self.assertEqual(signal.objective_count, 78)
        self.assertGreaterEqual(signal.minimizer_count, 1)
        self.assertEqual(signal.pivot_count, 13)
        self.assertEqual(signal.grouped_slope_count, 156)
        self.assertAlmostEqual(signal.final_loss, signal.minimum_loss, places=12)

    def test_close_transform_matches_log_level_solver(self) -> None:
        logs = [0.015 * index - (0.04 if index in (2, 9) else 0.0) for index in range(13)]
        from_logs = consensus_from_logs(logs)
        from_closes = consensus_from_closes([math.exp(value) for value in logs])
        self.assertAlmostEqual(from_logs.theilsen, from_closes.theilsen, places=14)
        self.assertAlmostEqual(from_logs.lad, from_closes.lad, places=14)
        self.assertAlmostEqual(
            from_logs.repeated_median, from_closes.repeated_median, places=14
        )
        self.assertEqual(from_logs.direction, from_closes.direction)

    def test_invalid_price_packages_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            consensus_from_closes([1.0] * 12)
        with self.assertRaises(ValueError):
            consensus_from_closes([1.0] * 12 + [0.0])
        with self.assertRaises(ValueError):
            consensus_from_logs([0.0] * 12 + [math.inf])

    def test_thirteen_consecutive_months_and_year_rollover(self) -> None:
        endpoints = [
            202412,
            202501,
            202502,
            202503,
            202504,
            202505,
            202506,
            202507,
            202508,
            202509,
            202510,
            202511,
            202512,
        ]
        self.assertTrue(validate_month_keys(202601, endpoints))
        self.assertFalse(validate_month_keys(202601, endpoints[:-1]))
        broken = endpoints.copy()
        broken[6] = 202505
        self.assertFalse(validate_month_keys(202601, broken))
        self.assertFalse(validate_month_keys(202602, endpoints))

    def test_latest_endpoint_freshness_contract(self) -> None:
        newest = date(2026, 7, 31)
        decision = date(2026, 8, 3)
        stale_decision = date(2026, 8, 11)
        self.assertLessEqual((decision - newest).days, 10)
        self.assertGreater((stale_decision - newest).days, 10)

    def test_source_contains_locked_estimators_and_consume_order(self) -> None:
        source = (EA_DIR / "QM5_41165_wti-mrobust3-agree-tr.mq5").read_text(
            encoding="utf-8"
        )
        required = (
            "Strategy_RobustConsensusSignal",
            "expected_pairs != 78",
            "sorted_pairs[38]",
            "sorted_pairs[39]",
            "metrics.lad_objective_count",
            "strategy_loss_tie_tolerance",
            "metrics.repeated_pivot_count != 13",
            "metrics.repeated_grouped_slope_count != expected_grouped",
            "theilsen_sign == lad_sign",
            "theilsen_sign == repeated_sign",
            "RISK_FIXED                    = 1000.0",
            "qm_friday_close_enabled       = false",
        )
        for token in required:
            self.assertIn(token, source)
        prepare = source[source.index("void Strategy_PrepareDecisionSignal()") :]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadMonthlyEndpoints"),
        )
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_ManageOpenPosition"),
            on_tick.index("Strategy_EntrySignal"),
        )
        for forbidden in ("iRSI(", "iMACD(", "iStochastic(", "iBands("):
            self.assertNotIn(forbidden, source)

    def test_setfile_is_single_locked_fixed_risk_baseline(self) -> None:
        setfiles = list((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 1)
        text = setfiles[0].read_text(encoding="utf-8")
        required = (
            "; environment:  backtest",
            "qm_ea_id=41165",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "strategy_price_points=13",
            "strategy_loss_tie_tolerance=0.000000000001",
            "qm_friday_close_enabled=false",
        )
        for token in required:
            self.assertIn(token, text)

    def test_identity_magic_and_approved_card_are_bound(self) -> None:
        with (REPO_ROOT / "framework/registry/ea_id_registry.csv").open(
            newline="", encoding="utf-8-sig"
        ) as handle:
            identities = [
                row
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41165" and row["status"] == "active"
            ]
        self.assertEqual(len(identities), 1)
        self.assertEqual(identities[0]["slug"], "wti-mrobust3-agree-tr")

        with (REPO_ROOT / "framework/registry/magic_numbers.csv").open(
            newline="", encoding="utf-8-sig"
        ) as handle:
            magics = [
                row
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41165" and row["status"] == "active"
            ]
        self.assertEqual(len(magics), 1)
        self.assertEqual(
            (magics[0]["symbol_slot"], magics[0]["symbol"], magics[0]["magic"]),
            ("0", "XTIUSD.DWX", "411650000"),
        )

        approved = REPO_ROOT / (
            "strategy-seeds/cards/approved/"
            "QM5_41165_wti-mrobust3-agree-tr_card.md"
        )
        local = EA_DIR / "docs/strategy_card.md"
        self.assertEqual(approved.read_bytes(), local.read_bytes())


if __name__ == "__main__":
    unittest.main()
