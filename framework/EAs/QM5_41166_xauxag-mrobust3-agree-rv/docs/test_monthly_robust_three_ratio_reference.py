from __future__ import annotations

import csv
import json
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
    direction: int  # +1 BUY XAU/SELL XAG; -1 SELL XAU/BUY XAG
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


def consensus_from_ratios(log_ratios: list[float]) -> RobustConsensus:
    if len(log_ratios) != 13 or any(
        not math.isfinite(value) for value in log_ratios
    ):
        raise ValueError("exactly thirteen finite log ratios required")

    pair_slopes = [
        (log_ratios[newer] - log_ratios[older]) / (newer - older)
        for older in range(12)
        for newer in range(older + 1, 13)
    ]
    if len(pair_slopes) != 78:
        raise AssertionError("pair-slope contract broken")
    theilsen = ordinary_median(pair_slopes)

    losses: list[float] = []
    for slope in pair_slopes:
        residuals = [
            log_ratios[index] - slope * index for index in range(13)
        ]
        intercept = sorted(residuals)[6]
        loss = sum(
            abs(log_ratios[index] - intercept - slope * index)
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
        log_ratios[index] - lad * index for index in range(13)
    ]
    lad_intercept = sorted(final_residuals)[6]
    final_loss = sum(
        abs(log_ratios[index] - lad_intercept - lad * index)
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
                (log_ratios[newer] - log_ratios[older]) / (newer - older)
            )
            grouped_slope_count += 1
        if len(slopes) != 12:
            raise AssertionError("pivot-slope contract broken")
        pivot_medians.append(ordinary_median(slopes))
    repeated_median = ordinary_median(pivot_medians)

    signs = tuple(
        strict_sign(value) for value in (theilsen, lad, repeated_median)
    )
    slope_sign = signs[0] if signs[0] != 0 and len(set(signs)) == 1 else 0
    direction = -slope_sign  # fade the unanimous ratio-slope sign
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


def consensus_from_closes(
    xau_closes: list[float], xag_closes: list[float]
) -> RobustConsensus:
    if len(xau_closes) != 13 or len(xag_closes) != 13:
        raise ValueError("exactly thirteen synchronized pairs required")
    if any(
        not math.isfinite(value) or value <= 0
        for value in (*xau_closes, *xag_closes)
    ):
        raise ValueError("positive finite closes required")
    return consensus_from_ratios(
        [
            math.log(xau) - math.log(xag)
            for xau, xag in zip(xau_closes, xag_closes, strict=True)
        ]
    )


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


class MonthlyRobustThreeRatioReferenceTests(unittest.TestCase):
    def test_unanimous_positive_negative_and_zero_fade(self) -> None:
        upward = consensus_from_ratios([0.01 * index for index in range(13)])
        downward = consensus_from_ratios([-0.01 * index for index in range(13)])
        flat = consensus_from_ratios([0.0] * 13)

        self.assertEqual(
            (upward.direction, downward.direction, flat.direction), (-1, 1, 0)
        )
        for value in (upward.theilsen, upward.lad, upward.repeated_median):
            self.assertAlmostEqual(value, 0.01, places=14)
        for value in (downward.theilsen, downward.lad, downward.repeated_median):
            self.assertAlmostEqual(value, -0.01, places=14)
        self.assertEqual(flat.minimizer_count, 78)

    def test_repeated_median_disagreement_consumes_flat(self) -> None:
        ratios = [
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
        signal = consensus_from_ratios(ratios)
        self.assertAlmostEqual(signal.theilsen, 0.00155555555555556, places=14)
        self.assertAlmostEqual(signal.lad, 0.00375, places=14)
        self.assertAlmostEqual(signal.repeated_median, -0.0045, places=14)
        self.assertEqual(signal.direction, 0)

    def test_lad_disagreement_consumes_flat(self) -> None:
        ratios = [
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
        signal = consensus_from_ratios(ratios)
        self.assertAlmostEqual(signal.lad, -0.002, places=14)
        self.assertGreater(signal.theilsen, 0.0)
        self.assertGreater(signal.repeated_median, 0.0)
        self.assertEqual(signal.direction, 0)

    def test_exact_counts_and_lad_minimum_face(self) -> None:
        ratios = [
            0.003 * index + (0.02 if index == 4 else 0.0)
            for index in range(13)
        ]
        signal = consensus_from_ratios(ratios)
        self.assertEqual(signal.pair_count, 78)
        self.assertEqual(signal.objective_count, 78)
        self.assertGreaterEqual(signal.minimizer_count, 1)
        self.assertEqual(signal.pivot_count, 13)
        self.assertEqual(signal.grouped_slope_count, 156)
        self.assertAlmostEqual(signal.final_loss, signal.minimum_loss, places=12)

    def test_paired_close_transform_and_separate_scale_invariance(self) -> None:
        ratios = [
            0.015 * index - (0.04 if index in (2, 9) else 0.0)
            for index in range(13)
        ]
        xag = [25.0 + index for index in range(13)]
        xau = [xag[index] * math.exp(ratios[index]) for index in range(13)]
        direct = consensus_from_ratios(ratios)
        paired = consensus_from_closes(xau, xag)
        rescaled = consensus_from_closes(
            [value * 3.0 for value in xau],
            [value * 0.4 for value in xag],
        )
        for field in ("theilsen", "lad", "repeated_median"):
            self.assertAlmostEqual(
                getattr(direct, field), getattr(paired, field), places=14
            )
            self.assertAlmostEqual(
                getattr(paired, field), getattr(rescaled, field), places=14
            )
        self.assertEqual(direct.direction, paired.direction)
        self.assertEqual(paired.direction, rescaled.direction)

    def test_invalid_price_packages_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            consensus_from_closes([1.0] * 12, [1.0] * 12)
        with self.assertRaises(ValueError):
            consensus_from_closes([1.0] * 12 + [0.0], [1.0] * 13)
        with self.assertRaises(ValueError):
            consensus_from_ratios([0.0] * 12 + [math.inf])

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
        source = (
            EA_DIR / "QM5_41166_xauxag-mrobust3-agree-rv.mq5"
        ).read_text(encoding="utf-8")
        required = (
            "Strategy_LoadMonthlyRobustConsensus",
            "expected_pair_count != 78",
            "theilsen_low_index != 38",
            "theilsen_high_index != 39",
            "lad_candidate_count != expected_pair_count",
            "strategy_loss_tie_tolerance",
            "grouped_slope_count != 156",
            "pivot_median_count != 13",
            "theilsen < 0.0 && lad_slope < 0.0",
            "theilsen > 0.0 && lad_slope > 0.0",
            "RISK_FIXED                  = 1000.0",
            "qm_friday_close_enabled      = false",
        )
        for token in required:
            self.assertIn(token, source)
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_ManageOpenPosition"),
            on_tick.index("Strategy_DecisionClockReady"),
        )
        self.assertLess(
            on_tick.index("Strategy_RecordAttemptState"),
            on_tick.index("Strategy_EntryWindowReady"),
        )
        self.assertLess(
            on_tick.index("Strategy_RecordAttemptState"),
            on_tick.index("Strategy_EntrySignal"),
        )
        for forbidden in ("iRSI(", "iMACD(", "iStochastic(", "iBands("):
            self.assertNotIn(forbidden, source)

    def test_setfiles_are_three_locked_fixed_risk_presets(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertEqual(sum("_backtest.set" in item.name for item in setfiles), 3)
        self.assertTrue(
            any("QM5_41166_XAU_XAG_MROBUST3_AGREE_RV_D1" in p.name for p in setfiles)
        )
        for setfile in setfiles:
            text = setfile.read_text(encoding="utf-8")
            required = (
                "; environment:  backtest",
                "qm_ea_id=41166",
                "RISK_FIXED=1000",
                "RISK_PERCENT=0",
                "PORTFOLIO_WEIGHT=1",
                "strategy_month_end_count=13",
                "strategy_loss_tie_tolerance=1e-12",
                "qm_friday_close_enabled=false",
            )
            for token in required:
                self.assertIn(token, text)
            self.assertNotIn("environment:  live", text)

    def test_identity_magic_card_and_manifest_are_bound(self) -> None:
        with (REPO_ROOT / "framework/registry/ea_id_registry.csv").open(
            newline="", encoding="utf-8-sig"
        ) as handle:
            identities = [
                row
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41166" and row["status"] == "active"
            ]
        self.assertEqual(len(identities), 1)
        self.assertEqual(identities[0]["slug"], "xauxag-mrobust3-agree-rv")

        with (REPO_ROOT / "framework/registry/magic_numbers.csv").open(
            newline="", encoding="utf-8-sig"
        ) as handle:
            magics = sorted(
                (
                    row["symbol_slot"],
                    row["symbol"],
                    row["magic"],
                )
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41166" and row["status"] == "active"
            )
        self.assertEqual(
            magics,
            [
                ("0", "XAUUSD.DWX", "411660000"),
                ("1", "XAGUSD.DWX", "411660001"),
            ],
        )

        approved = REPO_ROOT / (
            "strategy-seeds/cards/approved/"
            "QM5_41166_xauxag-mrobust3-agree-rv_card.md"
        )
        local = EA_DIR / "docs/strategy_card.md"
        self.assertEqual(approved.read_bytes(), local.read_bytes())

        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text())
        self.assertEqual(
            manifest["logical_symbol"],
            "QM5_41166_XAU_XAG_MROBUST3_AGREE_RV_D1",
        )
        self.assertEqual(
            manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"]
        )
        self.assertEqual(manifest["host_symbol"], "XAUUSD.DWX")


if __name__ == "__main__":
    unittest.main()
