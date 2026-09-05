from __future__ import annotations

import csv
import json
import math
from pathlib import Path
import random
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41338_wti-adf-vn-agree-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41338_wti-adf-vn-agree-tr_XTIUSD.DWX_D1_backtest.set"
CARD = REPO_ROOT / "strategy-seeds" / "cards" / "approved" / "QM5_41338_wti-adf-vn-agree-tr_card.md"
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
FIXTURE = REPO_ROOT / "artifacts" / "qm5_wti_adf_vn_agree_tr_reference_fixture_20260905.json"


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
    sse = sum((yy - alpha - gamma * zz - phi * ww) ** 2 for yy, zz, ww in zip(y, z, w))
    if sse <= 1e-18:
        raise ValueError("ADF residual energy at floor")
    se_gamma = math.sqrt((sse / 55) * sww / determinant)
    if se_gamma <= 1e-18:
        raise ValueError("ADF standard error at floor")
    return gamma / se_gamma


def von_neumann_eta(levels: list[float]) -> float:
    returns = [levels[index] - levels[index - 1] for index in range(40, 60)]
    mean = sum(returns) / 20
    variance_sum = sum((value - mean) ** 2 for value in returns)
    successive_sum = sum((returns[index + 1] - returns[index]) ** 2 for index in range(19))
    if variance_sum <= 1e-18:
        raise ValueError("von Neumann denominator at floor")
    return successive_sum / variance_sum


def fixture_levels(generator: str) -> list[float]:
    rng = random.Random(0)
    if generator == "rw":
        levels = [4.5]
        for _ in range(59):
            levels.append(levels[-1] + 0.006 + rng.gauss(0.0, 0.035))
        return levels
    if generator == "ar":
        levels: list[float] = []
        value = 4.5
        for index in range(60):
            value = 4.5 + 0.25 * (value - 4.5) + 0.025 * math.sin(2 * math.pi * index / 6) + rng.gauss(0.0, 0.004)
            levels.append(value)
        return levels
    if generator in {"up", "down"}:
        sign = 1.0 if generator == "up" else -1.0
        levels = [4.5]
        for index in range(59):
            change = sign * 0.007 + 0.018 * math.cos(2 * math.pi * index / 12) + 0.006 * math.cos(2 * math.pi * index / 6) + rng.gauss(0.0, 0.002)
            levels.append(levels[-1] + change)
        return levels
    raise ValueError(generator)


def parse_setfile() -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in SETFILE.read_text(encoding="utf-8-sig").splitlines():
        if "=" in raw and not raw.lstrip().startswith(";"):
            key, value = raw.split("=", 1)
            values[key.strip()] = value.strip()
    return values


class WtiAdfVonNeumannAgreementTests(unittest.TestCase):
    def test_fixture_matches_independent_formulas(self) -> None:
        receipt = json.loads(FIXTURE.read_text(encoding="utf-8"))
        for expected in receipt["fixtures"]:
            levels = fixture_levels(expected["generator"])
            actual_adf = adf_t(levels)
            actual_eta = von_neumann_eta(levels)
            momentum = levels[59] - levels[47]
            adf_ok = actual_adf >= -2.594
            vn_ok = actual_eta < 2.0
            direction = 0
            if adf_ok and vn_ok:
                direction = 1 if momentum > 1e-12 else -1 if momentum < -1e-12 else 0
            self.assertAlmostEqual(actual_adf, expected["adf_t"], places=11)
            self.assertAlmostEqual(actual_eta, expected["von_neumann_eta"], places=11)
            self.assertAlmostEqual(momentum, expected["momentum_12"], places=11)
            self.assertEqual(adf_ok, expected["adf_qualified"])
            self.assertEqual(vn_ok, expected["von_neumann_qualified"])
            self.assertEqual(direction, expected["direction"])

    def test_contract_files_and_registry(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8")
        self.assertIn("qm_ea_id                      = 41338", source)
        self.assertIn("metrics.adf_t >= strategy_adf_t_min", source)
        self.assertIn("metrics.vn_eta < strategy_vn_eta_max", source)
        self.assertIn("const int right_index = index + 40", source)
        self.assertIn("const int left_index = index + 39", source)
        self.assertNotIn("strategy_spectral", source)
        self.assertEqual(CARD.read_bytes(), EA_CARD.read_bytes())
        rows = list(csv.DictReader(MAGIC.open(encoding="utf-8-sig", newline="")))
        row = [r for r in rows if r["ea_id"] == "41338" and r["symbol_slot"] == "0"]
        self.assertEqual(len(row), 1)
        self.assertEqual(row[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(row[0]["magic"], "413380000")
        self.assertEqual(row[0]["status"], "active")

    def test_backtest_set_is_fixed_and_locked(self) -> None:
        values = parse_setfile()
        expected = {
            "qm_ea_id": "41338",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_level_count": "60",
            "strategy_regression_observations": "58",
            "strategy_residual_dof": "55",
            "strategy_adf_t_min": "-2.594",
            "strategy_vn_return_count": "20",
            "strategy_vn_eta_max": "2.0",
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
