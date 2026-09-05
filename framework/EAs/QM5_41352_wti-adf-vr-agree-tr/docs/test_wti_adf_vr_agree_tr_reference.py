from __future__ import annotations

import csv
import json
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41352_wti-adf-vr-agree-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41352_wti-adf-vr-agree-tr_XTIUSD.DWX_D1_backtest.set"
CARD = REPO_ROOT / "strategy-seeds" / "cards" / "approved" / "QM5_41352_wti-adf-vr-agree-tr_card.md"
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
FIXTURE = REPO_ROOT / "artifacts" / "qm5_wti_adf_vr_agree_tr_reference_fixture_20260905.json"


def adf_t(levels: list[float]) -> float:
    if len(levels) != 60 or any(not math.isfinite(v) for v in levels):
        raise ValueError("sixty finite levels required")
    y = [levels[t] - levels[t - 1] for t in range(2, 60)]
    z = [levels[t - 1] for t in range(2, 60)]
    w = [levels[t - 1] - levels[t - 2] for t in range(2, 60)]
    my, mz, mw = (sum(values) / 58 for values in (y, z, w))
    yc = [value - my for value in y]
    zc = [value - mz for value in z]
    wc = [value - mw for value in w]
    szz = sum(value * value for value in zc)
    sww = sum(value * value for value in wc)
    szw = sum(a * b for a, b in zip(zc, wc))
    szy = sum(a * b for a, b in zip(zc, yc))
    swy = sum(a * b for a, b in zip(wc, yc))
    determinant = szz * sww - szw * szw
    if szz <= 1e-18 or sww <= 1e-18 or determinant <= 1e-12 * szz * sww:
        raise ValueError("singular ADF regression")
    gamma = (szy * sww - swy * szw) / determinant
    phi = (swy * szz - szy * szw) / determinant
    alpha = my - gamma * mz - phi * mw
    sse = sum(
        (yy - alpha - gamma * zz - phi * ww) ** 2
        for yy, zz, ww in zip(y, z, w)
    )
    if sse <= 1e-18:
        raise ValueError("ADF residual energy at floor")
    return gamma / math.sqrt((sse / 55) * sww / determinant)


def robust_vr(levels: list[float]) -> tuple[float, float, float]:
    returns = [levels[index] - levels[index - 1] for index in range(28, 60)]
    mean = sum(returns) / 32
    deviations = [value - mean for value in returns]
    squared_sum = sum(value * value for value in deviations)
    if squared_sum <= 1e-18:
        raise ValueError("variance-ratio denominator at floor")
    variance_ratio = 1.0
    robust_variance = 0.0
    for lag in range(1, 4):
        rho = sum(
            deviations[index] * deviations[index - lag]
            for index in range(lag, 32)
        ) / squared_sum
        delta = sum(
            deviations[index] ** 2 * deviations[index - lag] ** 2
            for index in range(lag, 32)
        ) / squared_sum**2
        variance_ratio += 2.0 * (1.0 - lag / 4.0) * rho
        robust_variance += (2.0 * (4 - lag) / 4.0) ** 2 * delta
    if robust_variance <= 1e-18:
        raise ValueError("robust variance at floor")
    return variance_ratio, robust_variance, (variance_ratio - 1.0) / math.sqrt(robust_variance)


def fixture_levels(generator: str) -> list[float]:
    if generator in {"persistent_up", "persistent_down"}:
        sign = 1.0 if generator == "persistent_up" else -1.0
        level = 4.0 if sign > 0 else 5.0
        ret = 0.005 * sign
        levels = [level]
        for index in range(1, 60):
            innovation = 0.0015 * math.sin(0.71 * index) + 0.0010 * math.cos(1.37 * index)
            ret = 0.7 * ret + 0.0009 * sign + innovation * sign
            level += ret
            levels.append(level)
        return levels
    if generator == "adf_only":
        return [
            4.0 + 0.012 * index + 0.025 * math.sin(0.73 * index) + 0.009 * math.cos(1.91 * index)
            for index in range(60)
        ]
    if generator == "vr_only":
        return [
            4.0 + 0.080 * math.sin(0.70 * index) + 0.030 * math.cos(0.41 * index)
            for index in range(60)
        ]
    raise ValueError(generator)


def parse_setfile() -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in SETFILE.read_text(encoding="utf-8-sig").splitlines():
        if "=" in raw and not raw.lstrip().startswith(";"):
            key, value = raw.split("=", 1)
            values[key.strip()] = value.strip()
    return values


class WtiAdfVarianceRatioAgreementTests(unittest.TestCase):
    def test_fixture_matches_independent_formulas(self) -> None:
        receipt = json.loads(FIXTURE.read_text(encoding="utf-8"))
        for expected in receipt["fixtures"]:
            levels = fixture_levels(expected["generator"])
            actual_adf = adf_t(levels)
            actual_vr, actual_robust_variance, actual_z = robust_vr(levels)
            momentum = levels[59] - levels[47]
            adf_ok = actual_adf >= -2.594
            vr_ok = actual_z > 1.64485362695147
            direction = 0
            if adf_ok and vr_ok:
                direction = 1 if momentum > 1e-12 else -1 if momentum < -1e-12 else 0
            self.assertAlmostEqual(actual_adf, expected["adf_t"], places=9)
            self.assertAlmostEqual(actual_vr, expected["variance_ratio"], places=11)
            self.assertAlmostEqual(actual_robust_variance, expected["robust_variance"], places=11)
            self.assertAlmostEqual(actual_z, expected["vr_z"], places=11)
            self.assertAlmostEqual(momentum, expected["momentum_12"], places=11)
            self.assertEqual(adf_ok, expected["adf_qualified"])
            self.assertEqual(vr_ok, expected["vr_qualified"])
            self.assertEqual(direction, expected["direction"])

    def test_positive_vr_boundary_is_strict(self) -> None:
        self.assertFalse(1.64485362695147 > 1.64485362695147)
        self.assertTrue(math.nextafter(1.64485362695147, math.inf) > 1.64485362695147)
        self.assertFalse(-2.0 > 1.64485362695147)

    def test_contract_files_and_registry(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8")
        self.assertIn("qm_ea_id                      = 41352", source)
        self.assertIn("metrics.adf_t >= strategy_adf_t_min", source)
        self.assertIn("metrics.vr_z > strategy_vr_z_min", source)
        self.assertIn("const int right_index = index + 28", source)
        self.assertIn("const int left_index = index + 27", source)
        self.assertEqual(CARD.read_bytes(), EA_CARD.read_bytes())
        with MAGIC.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        row = [r for r in rows if r["ea_id"] == "41352" and r["symbol_slot"] == "0"]
        self.assertEqual(len(row), 1)
        self.assertEqual(row[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(row[0]["magic"], "413520000")
        self.assertEqual(row[0]["status"], "active")

    def test_backtest_set_is_fixed_and_locked(self) -> None:
        values = parse_setfile()
        expected = {
            "qm_ea_id": "41352",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_level_count": "60",
            "strategy_regression_observations": "58",
            "strategy_residual_dof": "55",
            "strategy_adf_t_min": "-2.594",
            "strategy_vr_return_count": "32",
            "strategy_vr_q": "4",
            "strategy_vr_z_min": "1.64485362695147",
            "strategy_momentum_months": "12",
            "strategy_history_bars": "1800",
            "strategy_atr_period": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_stale_days": "40",
            "strategy_max_spread_points": "1500",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)


if __name__ == "__main__":
    unittest.main()
