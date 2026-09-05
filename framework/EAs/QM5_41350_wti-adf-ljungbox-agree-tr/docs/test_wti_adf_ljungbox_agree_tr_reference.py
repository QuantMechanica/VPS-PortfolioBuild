from __future__ import annotations

import csv
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41350_wti-adf-ljungbox-agree-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41350_wti-adf-ljungbox-agree-tr_XTIUSD.DWX_D1_backtest.set"
CARD = REPO_ROOT / "strategy-seeds" / "cards" / "approved" / "QM5_41350_wti-adf-ljungbox-agree-tr_card.md"
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"


def adf_t(levels: list[float]) -> float:
    if len(levels) != 60 or any(not math.isfinite(v) for v in levels):
        raise ValueError("60 finite levels required")
    y = [levels[t] - levels[t - 1] for t in range(2, 60)]
    z = [levels[t - 1] for t in range(2, 60)]
    w = [levels[t - 1] - levels[t - 2] for t in range(2, 60)]
    my, mz, mw = (sum(v) / 58 for v in (y, z, w))
    yc = [v - my for v in y]
    zc = [v - mz for v in z]
    wc = [v - mw for v in w]
    szz = sum(v * v for v in zc)
    sww = sum(v * v for v in wc)
    szw = sum(a * b for a, b in zip(zc, wc))
    szy = sum(a * b for a, b in zip(zc, yc))
    swy = sum(a * b for a, b in zip(wc, yc))
    determinant = szz * sww - szw * szw
    if szz <= 1e-18 or sww <= 1e-18 or determinant <= 1e-12 * szz * sww:
        raise ValueError("singular ADF")
    gamma = (szy * sww - swy * szw) / determinant
    phi = (swy * szz - szy * szw) / determinant
    alpha = my - gamma * mz - phi * mw
    sse = sum((yy - alpha - gamma * zz - phi * ww) ** 2 for yy, zz, ww in zip(y, z, w))
    if sse <= 1e-18:
        raise ValueError("zero ADF residual energy")
    se_gamma = math.sqrt((sse / 55) * sww / determinant)
    if se_gamma <= 1e-18:
        raise ValueError("zero ADF standard error")
    return gamma / se_gamma


def ljung_box_q(values: list[float]) -> float:
    if len(values) != 48 or any(not math.isfinite(v) for v in values):
        raise ValueError("48 finite returns required")
    mean = sum(values) / 48
    centered = [v - mean for v in values]
    denominator = sum(v * v for v in centered)
    if denominator <= 1e-18:
        raise ValueError("zero return energy")
    return 48 * 50 * sum(
        (sum(centered[i] * centered[i - lag] for i in range(lag, 48)) / denominator) ** 2
        / (48 - lag)
        for lag in range(1, 7)
    )


def signal(levels: list[float]) -> tuple[int, float, float, float]:
    adf = adf_t(levels)
    q6 = ljung_box_q([levels[i] - levels[i - 1] for i in range(12, 60)])
    momentum = levels[59] - levels[47]
    direction = 0
    if adf >= -2.594 and q6 >= 5.35:
        direction = 1 if momentum > 1e-12 else -1 if momentum < -1e-12 else 0
    return direction, adf, q6, momentum


def fixture(name: str) -> list[float]:
    if name == "up":
        return [4.0 + 0.012 * i + 0.025 * math.sin(0.73 * i) + 0.009 * math.cos(1.91 * i) for i in range(60)]
    if name == "down":
        return [5.0 - 0.010 * i + 0.023 * math.sin(0.71 * i) + 0.008 * math.cos(1.83 * i) for i in range(60)]
    if name == "ljungbox_only":
        return [4.0 + 0.080 * math.sin(1.17 * i) + 0.030 * math.cos(0.41 * i) for i in range(60)]
    if name == "adf_only":
        levels = [4.5]
        for index in range(59):
            next_return = 0.003 + sum(
                0.003 * math.cos(2 * math.pi * bin_number * index / 48 + 0.11 * bin_number)
                for bin_number in range(1, 24)
            )
            levels.append(levels[-1] + next_return)
        return levels
    raise ValueError(name)


def parse_set(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    headers: dict[str, str] = {}
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line.startswith(";") and ":" in line:
            key, value = line[1:].split(":", 1)
            headers[key.strip()] = value.strip()
        elif "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return headers, values


class WtiAdfLjungBoxAgreementTests(unittest.TestCase):
    def test_reference_paths_and_disagreement(self) -> None:
        expected = {
            "up": (1, -0.28754973622603336, 56.575156509612995, 0.12845800868758506),
            "down": (-1, -0.34439061991466297, 59.78359480621714, -0.15505319427565833),
            "ljungbox_only": (0, -20.092593377208576, 124.98985402381666, 0.06343917227189211),
            "adf_only": (0, 0.4245704987551788, 0.399423947901974, 0.09679502134286633),
        }
        for name, target in expected.items():
            actual = signal(fixture(name))
            self.assertEqual(actual[0], target[0])
            for observed, wanted in zip(actual[1:], target[1:]):
                self.assertAlmostEqual(observed, wanted, places=10)

    def test_ljung_box_formula_and_degeneracy(self) -> None:
        alternating = [0.01 if i % 2 == 0 else -0.01 for i in range(48)]
        self.assertGreater(ljung_box_q(alternating), 5.35)
        with self.assertRaises(ValueError):
            ljung_box_q([0.01] * 48)
        with self.assertRaises(ValueError):
            adf_t([4.2] * 60)

    def test_fixed_risk_set_contract(self) -> None:
        headers, values = parse_set(SETFILE)
        self.assertEqual(headers["ea_id"], "41350")
        self.assertEqual(headers["ea_slug"], "wti-adf-ljungbox-agree-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41350",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_level_count": "60",
            "strategy_ljungbox_return_count": "48",
            "strategy_ljungbox_lags": "6",
            "strategy_adf_t_min": "-2.594",
            "strategy_ljungbox_q_min": "5.35",
        }
        for key, value in expected.items():
            self.assertEqual(values[key], value)

    def test_source_contract_card_mirror_and_magic(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8")
        for token in (
            "Strategy_ADFCore",
            "Strategy_LjungBoxCore",
            "rho * rho / (double)(value_count - lag)",
            "metrics.adf_qualified && metrics.ljungbox_qualified",
            "strategy_adf_t_min - (-2.594)",
            "strategy_ljungbox_q_min - 5.35",
            "RISK_FIXED != 1000.0",
            "QM_FrameworkMagic() != 413500000",
        ):
            self.assertIn(token, source)
        self.assertNotIn("SpectralEntropy", source)
        self.assertEqual(CARD.read_text(encoding="utf-8"), EA_CARD.read_text(encoding="utf-8"))
        with MAGIC.open(encoding="utf-8-sig", newline="") as handle:
            rows = [r for r in csv.DictReader(handle) if r["ea_id"] == "41350" and r["status"] == "active"]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["ea_slug"], "wti-adf-ljungbox-agree-tr")
        self.assertEqual(rows[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(rows[0]["magic"], "413500000")


if __name__ == "__main__":
    unittest.main()
