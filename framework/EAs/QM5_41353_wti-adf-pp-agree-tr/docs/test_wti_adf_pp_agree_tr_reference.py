from __future__ import annotations

import csv
import math
from pathlib import Path
import re
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41353_wti-adf-pp-agree-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41353_wti-adf-pp-agree-tr_XTIUSD.DWX_D1_backtest.set"
CANONICAL_CARD = REPO_ROOT / "strategy-seeds/cards/approved/QM5_41353_wti-adf-pp-agree-tr_card.md"
EA_CARD = EA_DIR / "docs/strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework/registry/magic_numbers.csv"

N = 60
ADF_ROWS = 58
ADF_DOF = 55
PP_ROWS = 59
PP_DOF = 57
PP_LAGS = 11
FLOOR = 1e-18
DET_FLOOR = 1e-12
BOUNDARY = -2.594
EPSILON = 1e-12


def adf_t(levels: list[float]) -> float:
    if len(levels) != N or any(not math.isfinite(x) for x in levels):
        raise ValueError("sixty finite levels required")
    rows = [
        (levels[t] - levels[t - 1], levels[t - 1], levels[t - 1] - levels[t - 2])
        for t in range(2, N)
    ]
    means = tuple(sum(row[j] for row in rows) / ADF_ROWS for j in range(3))
    centered = [tuple(row[j] - means[j] for j in range(3)) for row in rows]
    szz = sum(row[1] ** 2 for row in centered)
    sww = sum(row[2] ** 2 for row in centered)
    szw = sum(row[1] * row[2] for row in centered)
    szy = sum(row[1] * row[0] for row in centered)
    swy = sum(row[2] * row[0] for row in centered)
    determinant_scale = szz * sww
    determinant = determinant_scale - szw * szw
    if min(szz, sww, determinant_scale) <= FLOOR or determinant <= DET_FLOOR * determinant_scale:
        raise ValueError("singular ADF regression")
    gamma = (szy * sww - swy * szw) / determinant
    phi = (swy * szz - szy * szw) / determinant
    alpha = means[0] - gamma * means[1] - phi * means[2]
    sse = sum((y - alpha - gamma * z - phi * w) ** 2 for y, z, w in rows)
    if sse <= FLOOR:
        raise ValueError("invalid ADF residual energy")
    se_gamma = math.sqrt((sse / ADF_DOF) * sww / determinant)
    return gamma / se_gamma


def pp_z_tau(levels: list[float]) -> float:
    if len(levels) != N or any(not math.isfinite(x) for x in levels):
        raise ValueError("sixty finite levels required")
    lhs, rhs = levels[1:], levels[:-1]
    mean_lhs = sum(lhs) / PP_ROWS
    mean_rhs = sum(rhs) / PP_ROWS
    sxx = sum((x - mean_rhs) ** 2 for x in rhs)
    sxy = sum((x - mean_rhs) * (y - mean_lhs) for x, y in zip(rhs, lhs))
    if sxx <= FLOOR:
        raise ValueError("singular PP regression")
    rho = sxy / sxx
    alpha = mean_lhs - rho * mean_rhs
    residuals = [y - alpha - rho * x for x, y in zip(rhs, lhs)]
    sse = sum(u * u for u in residuals)
    if sse <= FLOOR:
        raise ValueError("invalid PP residual energy")
    s2 = sse / PP_DOF
    sigma = math.sqrt(s2)
    gamma0 = sse / PP_ROWS
    se_rho = math.sqrt(s2 / sxx)
    lambda2 = gamma0 + 2.0 * sum(
        (1.0 - lag / (PP_LAGS + 1.0))
        * sum(residuals[i] * residuals[i - lag] for i in range(lag, PP_ROWS))
        / PP_ROWS
        for lag in range(1, PP_LAGS + 1)
    )
    if min(s2, sigma, gamma0, se_rho, lambda2) <= FLOOR:
        raise ValueError("invalid PP variance path")
    raw_tau = (rho - 1.0) / se_rho
    return (
        math.sqrt(gamma0 / lambda2) * raw_tau
        - 0.5 * ((lambda2 - gamma0) / math.sqrt(lambda2)) * (PP_ROWS * se_rho / sigma)
    )


def classify(levels: list[float]) -> tuple[int, float, float]:
    adf = adf_t(levels)
    pp = pp_z_tau(levels)
    momentum = levels[-1] - levels[47]
    if adf < BOUNDARY or pp < BOUNDARY:
        return 0, adf, pp
    if momentum > EPSILON:
        return 1, adf, pp
    if momentum < -EPSILON:
        return -1, adf, pp
    return 0, adf, pp


def fixture(name: str) -> list[float]:
    if name == "agree_up":
        return [4.0 + 0.012*t + 0.025*math.sin(0.73*t) + 0.009*math.cos(1.91*t) for t in range(N)]
    if name == "agree_down":
        return [5.0 - 0.010*t + 0.023*math.sin(0.71*t) + 0.008*math.cos(1.83*t) for t in range(N)]
    if name == "adf_only":
        return [4.0 + 0.020*math.sin(0.11*t) + 0.010*math.cos(1.91*t) for t in range(N)]
    if name == "pp_only":
        return [4.0 - 0.002*t + 0.018*math.sin(1.19*t) + 0.009*math.cos(1.91*t) for t in range(N)]
    if name == "mean_reverting":
        return [4.0 + 0.080*math.sin(1.17*t) + 0.030*math.cos(0.41*t) for t in range(N)]
    raise KeyError(name)


def parse_setfile(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    headers: dict[str, str] = {}
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line.startswith(";") and ":" in line:
            key, value = line[1:].split(":", 1)
            headers[key.strip()] = value.strip()
        elif "=" in line and not line.startswith(";"):
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return headers, values


class AgreementReferenceTests(unittest.TestCase):
    def test_agreement_and_disagreement_fixtures(self) -> None:
        expected = {
            "agree_up": (1, -0.28754973622603336, -0.24331769997513303),
            "agree_down": (-1, -0.34439061991466297, 0.07854739371943104),
            "adf_only": (0, -2.2291816679882848, -3.571010451512681),
            "pp_only": (0, -2.638439000868299, -1.9387075563749554),
            "mean_reverting": (0, -20.092593377208576, -4.263223835451262),
        }
        for name, (direction, expected_adf, expected_pp) in expected.items():
            actual_direction, actual_adf, actual_pp = classify(fixture(name))
            self.assertEqual(actual_direction, direction, name)
            self.assertAlmostEqual(actual_adf, expected_adf, places=8, msg=name)
            self.assertAlmostEqual(actual_pp, expected_pp, places=8, msg=name)
        with self.assertRaises(ValueError):
            classify([4.2] * N)

    def test_boundaries_are_inclusive_and_direction_band_symmetric(self) -> None:
        def boundary_class(adf: float, pp: float, momentum: float) -> int:
            if adf < BOUNDARY or pp < BOUNDARY:
                return 0
            return 1 if momentum > EPSILON else -1 if momentum < -EPSILON else 0
        self.assertEqual(boundary_class(BOUNDARY, BOUNDARY, 0.01), 1)
        self.assertEqual(boundary_class(BOUNDARY, BOUNDARY, -0.01), -1)
        self.assertEqual(boundary_class(math.nextafter(BOUNDARY, -math.inf), BOUNDARY, 0.01), 0)
        self.assertEqual(boundary_class(BOUNDARY, math.nextafter(BOUNDARY, -math.inf), 0.01), 0)
        self.assertEqual(boundary_class(BOUNDARY, BOUNDARY, EPSILON), 0)

    def test_locked_set_and_source_contract(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41353")
        self.assertEqual(headers["ea_slug"], "wti-adf-pp-agree-tr")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41353", "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000", "RISK_PERCENT": "0", "PORTFOLIO_WEIGHT": "1",
            "strategy_level_count": "60", "strategy_regression_observations": "58",
            "strategy_residual_dof": "55", "strategy_energy_floor": "0.000000000000000001",
            "strategy_determinant_relative_floor": "0.000000000001",
            "strategy_adf_t_min": "-2.594", "strategy_pp_regression_observations": "59",
            "strategy_pp_residual_dof": "57", "strategy_pp_bartlett_lags": "11",
            "strategy_pp_z_tau_min": "-2.594", "strategy_momentum_months": "12",
            "strategy_direction_epsilon": "0.000000000001", "strategy_history_bars": "1800",
            "strategy_entry_grace_minutes": "180", "strategy_endpoint_stale_days": "10",
            "strategy_atr_period": "20", "strategy_atr_sl_mult": "3.5",
            "strategy_stale_days": "40", "strategy_max_spread_points": "1500",
        }
        self.assertEqual(values, expected)
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        inputs = set(re.findall(r"(?m)^input\s+(?!group\b)(?:\w+\s+)+(\w+)\s*=", source))
        self.assertTrue(set(values) <= inputs)
        self.assertTrue({x for x in inputs if x.startswith("strategy_")} <= set(values))
        for required in (
            "bool Strategy_ADFCore", "bool Strategy_PPCore", "bool Strategy_AgreementSignal",
            "strategy_pp_bartlett_lags + 1", "pp_z_tau = variance_scale * raw_tau - correction;",
            "metrics.adf_qualified && metrics.pp_qualified", "QM_FrameworkMagic() != 413530000",
        ):
            self.assertIn(required, source)
        prepare = source.index("void Strategy_PrepareDecisionSignal")
        consume = source.index("Strategy_RecordMonthAttempt(g_decision_month_key)", prepare)
        history = source.index("Strategy_LoadMonthlyEndpoints", consume)
        self.assertLess(consume, history)
        for prohibited in ("iRSI(", "iMACD(", "iBands(", "MathRand(", "WebRequest(", "FileOpen("):
            self.assertNotIn(prohibited, source)

    def test_registry_and_card_mirror(self) -> None:
        with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
            rows = [r for r in csv.DictReader(handle) if r["ea_id"] == "41353" and r["status"] == "active"]
        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0]["ea_slug"], rows[0]["symbol"], rows[0]["magic"]),
                         ("wti-adf-pp-agree-tr", "XTIUSD.DWX", "413530000"))
        self.assertEqual(EA_CARD.read_text(encoding="utf-8-sig"),
                         CANONICAL_CARD.read_text(encoding="utf-8-sig"))


if __name__ == "__main__":
    unittest.main()
