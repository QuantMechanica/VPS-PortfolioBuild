from __future__ import annotations

import json
import math
import re
import unittest
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO = Path(__file__).resolve().parents[4]
EA_PATH = EA_DIR / "QM5_41185_xauxag-fracd-rv.mq5"
CARD_PATH = (
    REPO
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41185_xauxag-fracd-rv_card.md"
)
LOCAL_CARD_PATH = EA_DIR / "docs" / "strategy_card.md"
MANIFEST_PATH = EA_DIR / "basket_manifest.json"
SET_DIR = EA_DIR / "sets"


def fractional_weights(order: float = 0.40, lags: int = 64) -> list[float]:
    if not (0.0 < order < 1.0) or lags < 2:
        raise ValueError("invalid fixed filter")
    weights = [1.0]
    for lag in range(1, lags):
        weights.append(weights[-1] * (lag - 1.0 - order) / lag)
    return weights


def fractional_signal(
    ratios: list[float],
    *,
    order: float = 0.40,
    lags: int = 64,
    baseline_outputs: int = 252,
    threshold: float = 0.50,
) -> tuple[float, int, float, float, list[float]]:
    expected = lags + baseline_outputs
    if len(ratios) != expected or not all(math.isfinite(value) for value in ratios):
        raise ValueError("wrong ratio history")
    weights = fractional_weights(order, lags)
    outputs: list[float] = []
    for endpoint in range(lags - 1, len(ratios)):
        outputs.append(
            sum(weights[lag] * ratios[endpoint - lag] for lag in range(lags))
        )
    if len(outputs) != baseline_outputs + 1:
        raise AssertionError("wrong filtered-output count")
    baseline = outputs[:baseline_outputs]
    mean = sum(baseline) / baseline_outputs
    variance = sum((value - mean) ** 2 for value in baseline) / (
        baseline_outputs - 1
    )
    if not math.isfinite(variance) or math.sqrt(variance) <= 1.0e-12:
        raise ValueError("invalid baseline variance")
    sd = math.sqrt(variance)
    z_score = (outputs[-1] - mean) / sd
    direction = -1 if z_score >= threshold else 1 if z_score <= -threshold else 0
    return z_score, direction, mean, sd, outputs


class FractionalDifferenceReferenceTests(unittest.TestCase):
    def test_fixed_weight_recurrence(self) -> None:
        weights = fractional_weights()
        self.assertEqual(len(weights), 64)
        self.assertAlmostEqual(weights[0], 1.0, places=15)
        self.assertAlmostEqual(weights[1], -0.4, places=15)
        self.assertAlmostEqual(weights[2], -0.12, places=15)
        self.assertAlmostEqual(weights[3], -0.064, places=15)
        self.assertTrue(all(math.isfinite(value) for value in weights))

    def test_exact_output_count_and_sample_denominator(self) -> None:
        ratios = [0.002 * index + 0.03 * math.sin(index / 11.0) for index in range(316)]
        z_score, _, mean, sd, outputs = fractional_signal(ratios)
        self.assertEqual(len(outputs), 253)
        self.assertTrue(math.isfinite(z_score))
        self.assertTrue(math.isfinite(mean))
        manual_variance = sum((value - mean) ** 2 for value in outputs[:252]) / 251
        self.assertAlmostEqual(sd * sd, manual_variance, places=14)

    def test_latest_output_is_held_out(self) -> None:
        base = [0.002 * index + 0.03 * math.sin(index / 11.0) for index in range(316)]
        positive = list(base)
        negative = list(base)
        positive[-1] += 0.50
        negative[-1] -= 0.50
        z_pos, direction_pos, mean_pos, sd_pos, _ = fractional_signal(positive)
        z_neg, direction_neg, mean_neg, sd_neg, _ = fractional_signal(negative)
        self.assertAlmostEqual(mean_pos, mean_neg, places=15)
        self.assertAlmostEqual(sd_pos, sd_neg, places=15)
        self.assertGreaterEqual(z_pos, 0.50)
        self.assertLessEqual(z_neg, -0.50)
        self.assertEqual(direction_pos, -1)  # SELL XAU / BUY XAG
        self.assertEqual(direction_neg, 1)  # BUY XAU / SELL XAG

    def test_constant_ratio_fails_closed(self) -> None:
        with self.assertRaises(ValueError):
            fractional_signal([2.0] * 316)

    def test_ea_contract_contains_fixed_filter_and_no_old_signal(self) -> None:
        text = EA_PATH.read_text(encoding="utf-8")
        required = (
            "strategy_pair_count_d1           = 316",
            "strategy_frac_lags               = 64",
            "strategy_baseline_outputs        = 252",
            "strategy_frac_order              = 0.40",
            "strategy_entry_abs_z             = 0.50",
            "weights[lag - 1] *",
            "(double)lag - 1.0 - strategy_frac_order",
            "squared_sum / (double)(strategy_baseline_outputs - 1)",
            "baseline_sd <= 1.0e-12",
            "z_score >= strategy_entry_abs_z",
            "z_score <= -strategy_entry_abs_z",
            "Strategy_RecordAttemptState(g_signal_month_key)",
            "Strategy_OpenPair(direction)",
            "QM_CalendarPeriodKey(PERIOD_MN1, g_leg_xau, 0)",
            "QM_CalendarPeriodKey(PERIOD_MN1, g_leg_xau, 1)",
        )
        for token in required:
            self.assertIn(token, text)
        for old_token in (
            "strategy_endpoint_count",
            "strategy_score_threshold",
            "Strategy_LoadMonthlyPairScore",
            "pair_score",
            "xauxag-mkendall-rv",
            "Strategy_MonthKey",
            "Strategy_NextMonthKey",
            "iTime(",
        ):
            self.assertNotIn(old_token, text)

    def test_manifest_card_and_registry_contract(self) -> None:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        self.assertEqual(manifest["logical_symbol"], "QM5_41185_XAU_XAG_FRACD_RV_D1")
        self.assertEqual(manifest["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["traded_symbols"], manifest["basket_symbols"])
        self.assertEqual(CARD_PATH.read_bytes(), LOCAL_CARD_PATH.read_bytes())

        magic_rows = (
            REPO / "framework" / "registry" / "magic_numbers.csv"
        ).read_text(encoding="utf-8-sig").splitlines()
        self.assertEqual(
            [row for row in magic_rows if row.startswith("41185,")],
            [
                "41185,xauxag-fracd-rv,0,XAUUSD.DWX,411850000,2026-08-27,Codex governed allocator,active",
                "41185,xauxag-fracd-rv,1,XAGUSD.DWX,411850001,2026-08-27,Codex governed allocator,active",
            ],
        )

    def test_three_presets_are_backtest_only_fixed_risk(self) -> None:
        setfiles = sorted(SET_DIR.glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertFalse(list(SET_DIR.glob("*live*.set")))
        logical = [path for path in setfiles if "QM5_41185_XAU_XAG_FRACD_RV_D1" in path.name]
        self.assertEqual(len(logical), 1)
        for path in setfiles:
            text = path.read_text(encoding="utf-8")
            self.assertIn("; environment:  backtest", text)
            self.assertRegex(text, r"(?m)^RISK_FIXED=1000$")
            self.assertRegex(text, r"(?m)^RISK_PERCENT=0$")
            self.assertRegex(text, r"(?m)^PORTFOLIO_WEIGHT=1$")
            self.assertRegex(text, r"(?m)^strategy_pair_count_d1=316$")
            self.assertRegex(text, r"(?m)^strategy_frac_lags=64$")
            self.assertRegex(text, r"(?m)^strategy_baseline_outputs=252$")
            self.assertRegex(text, r"(?m)^strategy_frac_order=0\.40$")
            self.assertRegex(text, r"(?m)^strategy_entry_abs_z=0\.50$")

    def test_runtime_surface_is_native_and_non_live(self) -> None:
        text = EA_PATH.read_text(encoding="utf-8").lower()
        forbidden = (
            "webrequest",
            "fileopen",
            "socket",
            "http://",
            "https://",
            "t_live",
            "autotrading",
        )
        self.assertFalse([token for token in forbidden if token in text])
        self.assertIsNone(re.search(r"(?i)input\s+group\s+\"live\"", text))


if __name__ == "__main__":
    unittest.main()
