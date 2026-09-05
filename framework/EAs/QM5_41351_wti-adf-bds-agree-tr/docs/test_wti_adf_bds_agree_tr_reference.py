from __future__ import annotations

import csv
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41351_wti-adf-bds-agree-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41351_wti-adf-bds-agree-tr_XTIUSD.DWX_D1_backtest.set"
CARD = REPO_ROOT / "strategy-seeds" / "cards" / "approved" / "QM5_41351_wti-adf-bds-agree-tr_card.md"
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"


def adf_t(levels: list[float]) -> float:
    if len(levels) != 60 or any(not math.isfinite(v) for v in levels):
        raise ValueError("60 finite levels required")
    y = [levels[t] - levels[t - 1] for t in range(2, 60)]
    z = [levels[t - 1] for t in range(2, 60)]
    w = [levels[t - 1] - levels[t - 2] for t in range(2, 60)]
    my, mz, mw = (sum(v) / 58 for v in (y, z, w))
    yc, zc, wc = ([v - m for v in values] for values, m in ((y, my), (z, mz), (w, mw)))
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
    return gamma / math.sqrt((sse / 55) * sww / determinant)


def bds2(values: list[float]) -> float:
    if len(values) != 48 or any(not math.isfinite(v) for v in values):
        raise ValueError("48 finite returns required")
    mean = sum(values) / 48
    variance = sum((v - mean) ** 2 for v in values) / 47
    if variance <= 1e-18:
        raise ValueError("zero sample variance")
    epsilon = 1.5 * math.sqrt(variance)
    close = [[int(abs(a - b) < epsilon) for b in values] for a in values]
    c1 = sum(close[i][j] for i in range(48) for j in range(i + 1, 48)) / 1128
    row_sums = [sum(row) for row in close]
    total = sum(row_sums)
    k = (sum(v * v for v in row_sums) - 3 * total + 96) / 103776
    c1t = sum(close[i][j] for i in range(1, 48) for j in range(i + 1, 48)) / 1081
    c2 = sum(close[i][j] * close[i + 1][j + 1] for i in range(47) for j in range(i + 1, 47)) / 1081
    variance2 = 4 * (k - c1 * c1) ** 2
    if variance2 <= 1e-18:
        raise ValueError("zero BDS variance")
    return math.sqrt(47) * (c2 - c1t * c1t) / math.sqrt(variance2)


def signal(levels: list[float]) -> tuple[int, float, float, float]:
    if len(levels) != 61:
        raise ValueError("61 endpoints required")
    adf = adf_t(levels[1:])
    bds = bds2([levels[i + 1] - levels[i] for i in range(12, 60)])
    momentum = levels[60] - levels[48]
    direction = 0
    if adf >= -2.594 and abs(bds) >= 0.6744897501960817:
        direction = 1 if momentum > 1e-12 else -1 if momentum < -1e-12 else 0
    return direction, adf, bds, momentum


def fixture(name: str) -> list[float]:
    if name in {"up", "down"}:
        levels = [4.5]
        drift = 0.01 if name == "up" else -0.02
        for i in range(60):
            if i < 12:
                base = 0.003 * math.sin(0.7 * i)
            else:
                j = i - 12
                base = 0.012 * math.sin(0.41 * j) + 0.006 * math.cos(0.17 * j) + 0.003 * (j % 5 - 2) + 0.00015 * j
            levels.append(levels[-1] + base + drift)
        return levels
    if name == "bds_only":
        return [4 + 0.08 * math.sin(0.3 * i) + 0.03 * math.cos(0.41 * i) for i in range(61)]
    if name == "adf_only":
        return [4 + 0.012 * i + 0.025 * math.sin(0.73 * i) + 0.009 * math.cos(1.91 * i) for i in range(61)]
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


class WtiAdfBdsAgreementTests(unittest.TestCase):
    def test_reference_paths_and_disagreement(self) -> None:
        expected = {
            "up": (1, 0.18420960924814, 12.555681198874424, 0.19900234096568958),
            "down": (-1, -0.9697478041064327, 12.555681198874424, -0.1609976590343103),
            "bds_only": (0, -30.01147827220134, 28.007510559449905, -0.13172550024810326),
            "adf_only": (0, -0.22138187450429062, -0.29844575981701243, 0.15923847444865125),
        }
        for name, target in expected.items():
            actual = signal(fixture(name))
            self.assertEqual(actual[0], target[0])
            for observed, wanted in zip(actual[1:], target[1:]):
                self.assertAlmostEqual(observed, wanted, places=9)

    def test_degenerate_paths_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            bds2([0.01] * 48)
        with self.assertRaises(ValueError):
            adf_t([4.2] * 60)

    def test_fixed_risk_set_contract(self) -> None:
        headers, values = parse_set(SETFILE)
        self.assertEqual(headers["ea_id"], "41351")
        self.assertEqual(headers["ea_slug"], "wti-adf-bds-agree-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41351", "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000", "RISK_PERCENT": "0", "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "61", "strategy_adf_level_count": "60",
            "strategy_bds_return_count": "48", "strategy_adf_t_min": "-2.594",
            "strategy_abs_bds_boundary": "0.6744897501960817",
        }
        for key, value in expected.items():
            self.assertEqual(values[key], value)

    def test_source_contract_card_mirror_and_magic(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8")
        for token in (
            "Strategy_ADFCore", "Strategy_BDS2Core",
            "(distance < epsilon) ? 1 : 0",
            "metrics.adf_qualified && metrics.bds_qualified",
            "strategy_adf_t_min - (-2.594)",
            "strategy_abs_bds_boundary - 0.6744897501960817",
            "RISK_FIXED != 1000.0", "QM_FrameworkMagic() != 413510000",
        ):
            self.assertIn(token, source)
        self.assertNotIn("iMA(", source)
        self.assertNotIn("iRSI(", source)
        self.assertEqual(CARD.read_text(encoding="utf-8"), EA_CARD.read_text(encoding="utf-8"))
        with MAGIC.open(encoding="utf-8-sig", newline="") as handle:
            rows = [r for r in csv.DictReader(handle) if r["ea_id"] == "41351" and r["status"] == "active"]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["ea_slug"], "wti-adf-bds-agree-tr")
        self.assertEqual(rows[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(rows[0]["magic"], "413510000")


if __name__ == "__main__":
    unittest.main()
