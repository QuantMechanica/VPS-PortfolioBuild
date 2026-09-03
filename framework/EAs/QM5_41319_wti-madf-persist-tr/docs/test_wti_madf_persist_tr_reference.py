from __future__ import annotations

import csv
import dataclasses
import json
import math
from pathlib import Path
import re
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41319_wti-madf-persist-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41319_wti-madf-persist-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41319_wti-madf-persist-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
FIXTURE = (
    REPO_ROOT
    / "artifacts"
    / "qm5_wti_madf_persist_tr_reference_fixture_20260903.json"
)

LEVEL_COUNT = 60
OBSERVATION_COUNT = 58
RESIDUAL_DOF = 55
ENERGY_FLOOR = 1e-18
DETERMINANT_RELATIVE_FLOOR = 1e-12
ADF_T_MIN = -2.594
MOMENTUM_MONTHS = 12
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class ADFState:
    mean_y: float
    mean_z: float
    mean_w: float
    szz: float
    sww: float
    szw: float
    szy: float
    swy: float
    determinant: float
    alpha: float
    gamma: float
    phi: float
    sse: float
    residual_variance: float
    se_gamma: float
    adf_t: float


@dataclasses.dataclass(frozen=True)
class Signal:
    direction: int
    qualified: bool
    momentum_12: float
    state: ADFState


def direct_adf(levels: list[float]) -> ADFState:
    """Scalar construction matching the locked centered-cross-product OLS."""
    if len(levels) != LEVEL_COUNT or any(not math.isfinite(x) for x in levels):
        raise ValueError("sixty finite log levels required")
    rows = [
        (levels[t] - levels[t - 1], levels[t - 1], levels[t - 1] - levels[t - 2])
        for t in range(2, LEVEL_COUNT)
    ]
    if len(rows) != OBSERVATION_COUNT:
        raise ValueError("fifty-eight regression observations required")
    mean_y = sum(row[0] for row in rows) / OBSERVATION_COUNT
    mean_z = sum(row[1] for row in rows) / OBSERVATION_COUNT
    mean_w = sum(row[2] for row in rows) / OBSERVATION_COUNT
    szz = sum((z - mean_z) ** 2 for _, z, _ in rows)
    sww = sum((w - mean_w) ** 2 for _, _, w in rows)
    szw = sum((z - mean_z) * (w - mean_w) for _, z, w in rows)
    szy = sum((z - mean_z) * (y - mean_y) for y, z, _ in rows)
    swy = sum((w - mean_w) * (y - mean_y) for y, _, w in rows)
    if szz <= ENERGY_FLOOR or sww <= ENERGY_FLOOR:
        raise ValueError("regressor energy at or below floor")
    determinant_scale = szz * sww
    determinant = determinant_scale - szw * szw
    if (
        not math.isfinite(determinant)
        or determinant <= DETERMINANT_RELATIVE_FLOOR * determinant_scale
    ):
        raise ValueError("singular or ill-conditioned regression")
    gamma = (szy * sww - swy * szw) / determinant
    phi = (swy * szz - szy * szw) / determinant
    alpha = mean_y - gamma * mean_z - phi * mean_w
    sse = sum((y - alpha - gamma * z - phi * w) ** 2 for y, z, w in rows)
    if not math.isfinite(sse) or sse <= ENERGY_FLOOR:
        raise ValueError("residual energy at or below floor")
    residual_variance = sse / RESIDUAL_DOF
    se_gamma = math.sqrt(residual_variance * sww / determinant)
    if not math.isfinite(se_gamma) or se_gamma <= ENERGY_FLOOR:
        raise ValueError("lagged-level standard error at or below floor")
    adf_t = gamma / se_gamma
    if not math.isfinite(adf_t):
        raise ValueError("invalid ADF t statistic")
    return ADFState(
        mean_y,
        mean_z,
        mean_w,
        szz,
        sww,
        szw,
        szy,
        swy,
        determinant,
        alpha,
        gamma,
        phi,
        sse,
        residual_variance,
        se_gamma,
        adf_t,
    )


def classify(adf_t: float, momentum_12: float) -> int:
    if (
        not math.isfinite(adf_t)
        or not math.isfinite(momentum_12)
        or adf_t < ADF_T_MIN
    ):
        return 0
    if momentum_12 > DIRECTION_EPSILON:
        return 1
    if momentum_12 < -DIRECTION_EPSILON:
        return -1
    return 0


def signal_from_levels(levels: list[float]) -> Signal:
    state = direct_adf(levels)
    momentum_12 = levels[-1] - levels[-1 - MOMENTUM_MONTHS]
    return Signal(
        classify(state.adf_t, momentum_12),
        state.adf_t >= ADF_T_MIN,
        momentum_12,
        state,
    )


def signal_from_closes(closes: list[float]) -> Signal:
    if len(closes) != LEVEL_COUNT or any(
        not math.isfinite(value) or value <= 0.0 for value in closes
    ):
        raise ValueError("sixty positive finite closes required")
    return signal_from_levels([math.log(value) for value in closes])


def fixture_levels(name: str) -> list[float]:
    if name == "persistent_up_qualifies_buy":
        return [
            4.0
            + 0.012 * t
            + 0.025 * math.sin(0.73 * t)
            + 0.009 * math.cos(1.91 * t)
            for t in range(LEVEL_COUNT)
        ]
    if name == "persistent_down_qualifies_sell":
        return [
            5.0
            - 0.010 * t
            + 0.023 * math.sin(0.71 * t)
            + 0.008 * math.cos(1.83 * t)
            for t in range(LEVEL_COUNT)
        ]
    if name == "mean_reverting_rejected_flat":
        return [
            4.0 + 0.080 * math.sin(1.17 * t) + 0.030 * math.cos(0.41 * t)
            for t in range(LEVEL_COUNT)
        ]
    raise KeyError(name)


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != LEVEL_COUNT or next_month_key(endpoints[-1]) != current_month:
        return False
    return all(
        next_month_key(left) == right for left, right in zip(endpoints, endpoints[1:])
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


class WtiMonthlyADFReferenceTests(unittest.TestCase):
    def test_fixture_receipt_matches_direct_formula(self) -> None:
        receipt = json.loads(FIXTURE.read_text(encoding="utf-8"))
        self.assertEqual(receipt["schema"], "qm.strategy-reference-fixture/v1")
        self.assertFalse(receipt["market_data"])
        self.assertEqual(receipt["contract"]["level_count"], LEVEL_COUNT)
        self.assertEqual(
            receipt["contract"]["regression_observations"], OBSERVATION_COUNT
        )
        self.assertEqual(
            receipt["contract"]["residual_degrees_of_freedom"], RESIDUAL_DOF
        )
        self.assertEqual(receipt["contract"]["adf_t_min_inclusive"], ADF_T_MIN)
        for expected in receipt["fixtures"]:
            signal = signal_from_levels(fixture_levels(expected["name"]))
            for field in ("alpha", "gamma", "phi", "sse", "se_gamma", "adf_t"):
                self.assertAlmostEqual(
                    getattr(signal.state, field), expected[field], places=12
                )
            self.assertAlmostEqual(signal.momentum_12, expected["mom12"], places=12)
            self.assertEqual(signal.direction, expected["direction"])
            self.assertEqual(signal.qualified, expected["adf_t"] >= ADF_T_MIN)

    def test_normal_equations_and_additive_level_invariance(self) -> None:
        levels = fixture_levels("persistent_up_qualifies_buy")
        state = direct_adf(levels)
        rows = [
            (levels[t] - levels[t - 1], levels[t - 1], levels[t - 1] - levels[t - 2])
            for t in range(2, LEVEL_COUNT)
        ]
        residuals = [
            y - state.alpha - state.gamma * z - state.phi * w for y, z, w in rows
        ]
        self.assertAlmostEqual(sum(residuals), 0.0, places=12)
        self.assertAlmostEqual(
            sum(e * z for e, (_, z, _) in zip(residuals, rows)), 0.0, places=12
        )
        self.assertAlmostEqual(
            sum(e * w for e, (_, _, w) in zip(residuals, rows)), 0.0, places=12
        )
        shifted = direct_adf([value + 7.25 for value in levels])
        self.assertAlmostEqual(state.gamma, shifted.gamma, places=12)
        self.assertAlmostEqual(state.phi, shifted.phi, places=12)
        self.assertAlmostEqual(state.sse, shifted.sse, places=12)
        self.assertAlmostEqual(state.se_gamma, shifted.se_gamma, places=12)
        self.assertAlmostEqual(state.adf_t, shifted.adf_t, places=12)
        self.assertAlmostEqual(
            shifted.alpha, state.alpha - 7.25 * state.gamma, places=12
        )

    def test_log_close_orientation_and_newest_twelve_month_direction(self) -> None:
        for name, expected_direction in (
            ("persistent_up_qualifies_buy", 1),
            ("persistent_down_qualifies_sell", -1),
        ):
            levels = fixture_levels(name)
            direct = signal_from_levels(levels)
            via_closes = signal_from_closes([math.exp(value) for value in levels])
            self.assertAlmostEqual(direct.state.adf_t, via_closes.state.adf_t, places=12)
            self.assertAlmostEqual(
                direct.momentum_12, levels[59] - levels[47], places=15
            )
            self.assertEqual(direct.direction, expected_direction)

    def test_boundary_is_inclusive_and_direction_band_symmetric(self) -> None:
        self.assertEqual(classify(ADF_T_MIN, 0.01), 1)
        self.assertEqual(classify(ADF_T_MIN, -0.01), -1)
        below = math.nextafter(ADF_T_MIN, -math.inf)
        self.assertEqual(classify(below, 0.01), 0)
        self.assertEqual(classify(ADF_T_MIN, DIRECTION_EPSILON), 0)
        self.assertEqual(classify(ADF_T_MIN, -DIRECTION_EPSILON), 0)

    def test_degenerate_wrong_length_and_bad_close_paths_fail(self) -> None:
        with self.assertRaises(ValueError):
            direct_adf([4.2] * LEVEL_COUNT)
        with self.assertRaises(ValueError):
            direct_adf([4.2] * (LEVEL_COUNT - 1))
        with self.assertRaises(ValueError):
            direct_adf([4.2] * (LEVEL_COUNT - 1) + [math.inf])
        with self.assertRaises(ValueError):
            signal_from_closes([70.0] * (LEVEL_COUNT - 1))
        with self.assertRaises(ValueError):
            signal_from_closes([70.0] * (LEVEL_COUNT - 1) + [0.0])

    def test_sixty_consecutive_completed_months(self) -> None:
        endpoints: list[int] = []
        key = 201907
        for _ in range(LEVEL_COUNT):
            endpoints.append(key)
            key = next_month_key(key)
        self.assertTrue(validate_month_keys(key, endpoints))
        self.assertFalse(validate_month_keys(key, endpoints[:-1]))
        broken = endpoints.copy()
        broken[29] = broken[28]
        self.assertFalse(validate_month_keys(key, broken))

    def test_setfile_is_the_one_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41319")
        self.assertEqual(headers["ea_slug"], "wti-madf-persist-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41319",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_level_count": "60",
            "strategy_regression_observations": "58",
            "strategy_residual_dof": "55",
            "strategy_energy_floor": "0.000000000000000001",
            "strategy_determinant_relative_floor": "0.000000000001",
            "strategy_adf_t_min": "-2.594",
            "strategy_momentum_months": "12",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars": "1200",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_stale_days": "40",
            "strategy_max_spread_points": "1500",
        }
        self.assertEqual(values, expected)
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        input_names = set(
            re.findall(r"(?m)^input\s+(?!group\b)(?:\w+\s+)+(\w+)\s*=", source)
        )
        self.assertTrue(set(values) <= input_names)
        self.assertTrue(
            {name for name in input_names if name.startswith("strategy_")} <= set(values)
        )
        self.assertEqual(sorted((EA_DIR / "sets").glob("*.set")), [SETFILE])

    def test_source_contract_attempt_order_and_adf_guards(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        for required in (
            "bool Strategy_ADFCore",
            "bool Strategy_ADFReferenceSelfTest",
            "bool Strategy_ADFSignal",
            "const double y = levels[index] - levels[index - 1]",
            "const double z = levels[index - 1]",
            "const double w = levels[index - 1] - levels[index - 2]",
            "determinant_scale - szw * szw",
            "(szy * sww - swy * szw) / determinant",
            "(swy * szz - szy * szw) / determinant",
            "sse / (double)strategy_residual_dof",
            "residual_variance * sww / determinant",
            "adf_t = gamma / se_gamma",
            "metrics.adf_t >= strategy_adf_t_min",
            "levels[strategy_level_count - 1] - levels[momentum_start]",
            "QM_FrameworkMagic() != 413190000",
            "Strategy_HasForeignSymbolPosition()",
        ):
            self.assertIn(required, source)
        prepare = source.index("void Strategy_PrepareDecisionSignal")
        consume = source.index("Strategy_RecordMonthAttempt(g_decision_month_key)", prepare)
        history = source.index("Strategy_LoadMonthlyEndpoints", consume)
        self.assertLess(consume, history)
        open_call = source.index("QM_TM_OpenPosition(req, out_ticket)")
        persist_entry = source.index(
            "Strategy_RecordEntryMonth(g_decision_month_key)", open_call
        )
        self.assertLess(open_call, persist_entry)
        for prohibited in (
            "iRSI(",
            "iMACD(",
            "iBands(",
            "iADX(",
            "iMA(",
            "MathRand(",
            "WebRequest(",
            "FileOpen(",
            "SpectralEntropy",
            "SampleEntropy",
            "LZ76",
        ):
            self.assertNotIn(prohibited, source)

    def test_magic_registry_and_card_copy_are_exact(self) -> None:
        with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
            rows = [
                row
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41319" and row["status"] == "active"
            ]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["ea_slug"], "wti-madf-persist-tr")
        self.assertEqual(rows[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(rows[0]["magic"], "413190000")
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )


if __name__ == "__main__":
    unittest.main()
