from __future__ import annotations

import csv
import dataclasses
import json
import math
from pathlib import Path
import re
import unittest

import numpy as np


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41315_wti-archlm-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41315_wti-archlm-tr_XTIUSD.DWX_D1_backtest.set"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41315_wti-archlm-tr_card.md"
)
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
NULL_RECEIPT = REPO_ROOT / "artifacts" / "qm5_wti_archlm_tr_null_density_20260902.json"

RETURN_COUNT = 60
ARCH_LAGS = 6
REGRESSION_ROWS = 54
ENERGY_FLOOR = 1e-18
SST_FLOOR = 1e-18
ARCH_LM_BOUNDARY = 4.73
MOMENTUM_MONTHS = 12
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class ArchLmState:
    mean_return: float
    residual_energy: float
    regression_y_mean: float
    centered_sst: float
    residual_sse: float
    centered_r_squared: float
    arch_lm: float
    coefficients: tuple[float, ...]


@dataclasses.dataclass(frozen=True)
class Signal:
    direction: int
    state: ArchLmState
    qualified: bool
    momentum_12: float


def direct_arch_lm(values: list[float]) -> ArchLmState:
    if len(values) != RETURN_COUNT or any(not math.isfinite(v) for v in values):
        raise ValueError("sixty finite returns required")

    mean_return = sum(values) / RETURN_COUNT
    residuals = [value - mean_return for value in values]
    residual_energy = sum(value * value for value in residuals) / RETURN_COUNT
    if not math.isfinite(residual_energy) or residual_energy <= ENERGY_FLOOR:
        raise ValueError("residual energy at or below floor")
    squares = [value * value / residual_energy for value in residuals]

    rows: list[list[float]] = []
    response: list[float] = []
    for current in range(ARCH_LAGS, RETURN_COUNT):
        response.append(squares[current])
        rows.append([1.0] + [squares[current - lag] for lag in range(1, 7)])
    if len(rows) != REGRESSION_ROWS:
        raise AssertionError("wrong lag alignment")

    x = np.asarray(rows, dtype=np.float64)
    y = np.asarray(response, dtype=np.float64)
    normal = x.T @ x
    normal_rhs = x.T @ y
    try:
        coefficients = np.linalg.solve(normal, normal_rhs)
    except np.linalg.LinAlgError as exc:
        raise ValueError("singular auxiliary regression") from exc
    if np.linalg.matrix_rank(x) != 7:
        raise ValueError("rank-deficient auxiliary regression")

    y_mean = float(np.mean(y))
    fitted = x @ coefficients
    centered_sst = float(np.sum((y - y_mean) ** 2))
    residual_sse = float(np.sum((y - fitted) ** 2))
    if not math.isfinite(centered_sst) or centered_sst <= SST_FLOOR:
        raise ValueError("centered SST at or below floor")
    centered_r_squared = 1.0 - residual_sse / centered_sst
    if not -1e-10 <= centered_r_squared <= 1.0 + 1e-10:
        raise ValueError("invalid centered R-squared")
    centered_r_squared = min(1.0, max(0.0, centered_r_squared))
    arch_lm = REGRESSION_ROWS * centered_r_squared
    state = ArchLmState(
        mean_return=mean_return,
        residual_energy=residual_energy,
        regression_y_mean=y_mean,
        centered_sst=centered_sst,
        residual_sse=residual_sse,
        centered_r_squared=centered_r_squared,
        arch_lm=arch_lm,
        coefficients=tuple(float(value) for value in coefficients),
    )
    numeric = dataclasses.astuple(state)[:-1]
    if any(not math.isfinite(value) for value in numeric):
        raise ValueError("invalid ARCH-LM state")
    return state


def lstsq_arch_lm(values: list[float]) -> ArchLmState:
    array = np.asarray(values, dtype=np.float64)
    residuals = array - np.mean(array)
    energy = float(np.mean(residuals**2))
    squares = residuals**2 / energy
    y = squares[6:]
    x = np.column_stack(
        [np.ones(REGRESSION_ROWS)]
        + [squares[6 - lag : 60 - lag] for lag in range(1, 7)]
    )
    coefficients = np.linalg.lstsq(x, y, rcond=None)[0]
    fitted = x @ coefficients
    sst = float(np.sum((y - np.mean(y)) ** 2))
    sse = float(np.sum((y - fitted) ** 2))
    r_squared = 1.0 - sse / sst
    return ArchLmState(
        float(np.mean(array)),
        energy,
        float(np.mean(y)),
        sst,
        sse,
        r_squared,
        REGRESSION_ROWS * r_squared,
        tuple(float(value) for value in coefficients),
    )


def classify(arch_lm: float, momentum_12: float) -> int:
    if (
        not math.isfinite(arch_lm)
        or not math.isfinite(momentum_12)
        or arch_lm < ARCH_LM_BOUNDARY
    ):
        return 0
    if momentum_12 > DIRECTION_EPSILON:
        return 1
    if momentum_12 < -DIRECTION_EPSILON:
        return -1
    return 0


def signal_from_returns(values: list[float]) -> Signal:
    state = direct_arch_lm(values)
    momentum_12 = sum(values[-MOMENTUM_MONTHS:])
    qualified = state.arch_lm >= ARCH_LM_BOUNDARY
    return Signal(classify(state.arch_lm, momentum_12), state, qualified, momentum_12)


def closes_from_returns(values: list[float], initial: float = 70.0) -> list[float]:
    closes = [initial]
    for value in values:
        closes.append(closes[-1] * math.exp(value))
    return closes


def signal_from_closes(closes: list[float]) -> Signal:
    if len(closes) != 61 or any(
        not math.isfinite(value) or value <= 0.0 for value in closes
    ):
        raise ValueError("sixty-one positive finite closes required")
    values = [math.log(right / left) for left, right in zip(closes, closes[1:])]
    return signal_from_returns(values)


def fixture_returns() -> list[float]:
    return [
        0.012 * math.sin(0.41 * index)
        + 0.007 * math.cos(0.17 * index)
        + 0.00008 * index
        + 0.003 * math.sin(0.09 * index * index)
        for index in range(60)
    ]


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 61 or next_month_key(endpoints[-1]) != current_month:
        return False
    return all(next_month_key(left) == right for left, right in zip(endpoints, endpoints[1:]))


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


class WtiMonthlyArchLmReferenceTests(unittest.TestCase):
    def test_embedded_fixture_matches_independent_lstsq(self) -> None:
        direct = direct_arch_lm(fixture_returns())
        independent = lstsq_arch_lm(fixture_returns())
        np.testing.assert_allclose(
            dataclasses.astuple(direct)[:-1],
            dataclasses.astuple(independent)[:-1],
            rtol=2e-12,
            atol=2e-14,
        )
        np.testing.assert_allclose(direct.coefficients, independent.coefficients, rtol=2e-11)
        self.assertAlmostEqual(direct.mean_return, 0.001933307718746096, places=15)
        self.assertAlmostEqual(direct.residual_energy, 0.00010520479526597679, places=17)
        self.assertAlmostEqual(direct.centered_r_squared, 0.6546522545951513, places=13)
        self.assertAlmostEqual(direct.arch_lm, 35.35122174813817, places=11)

    def test_affine_scale_invariance_but_direction_uses_raw_returns(self) -> None:
        carrier = fixture_returns()
        base = direct_arch_lm(carrier)
        affine = direct_arch_lm([3.7 * value + 0.25 for value in carrier])
        self.assertAlmostEqual(base.arch_lm, affine.arch_lm, places=10)
        buy = signal_from_closes(closes_from_returns([value + 0.02 for value in carrier]))
        sell = signal_from_closes(closes_from_returns([value - 0.02 for value in carrier]))
        self.assertTrue(buy.qualified and sell.qualified)
        self.assertEqual((buy.direction, sell.direction), (1, -1))

    def test_order_dependence_separates_lm_from_marginal_shape(self) -> None:
        values = fixture_returns()
        permuted = values[::2] + values[1::2]
        original = direct_arch_lm(values)
        reordered = direct_arch_lm(permuted)
        self.assertCountEqual(values, permuted)
        self.assertGreater(abs(original.arch_lm - reordered.arch_lm), 1.0)

    def test_boundary_is_inclusive_and_direction_band_is_symmetric(self) -> None:
        self.assertEqual(classify(ARCH_LM_BOUNDARY, 0.01), 1)
        self.assertEqual(classify(ARCH_LM_BOUNDARY, -0.01), -1)
        self.assertEqual(classify(math.nextafter(ARCH_LM_BOUNDARY, -math.inf), 0.01), 0)
        self.assertEqual(classify(ARCH_LM_BOUNDARY, DIRECTION_EPSILON), 0)
        self.assertEqual(classify(ARCH_LM_BOUNDARY, -DIRECTION_EPSILON), 0)

    def test_low_energy_singular_and_bad_paths_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "energy"):
            direct_arch_lm([0.01] * 60)
        with self.assertRaises(ValueError):
            direct_arch_lm([0.01, -0.01] * 30)
        with self.assertRaises(ValueError):
            direct_arch_lm(fixture_returns()[:-1] + [math.inf])
        with self.assertRaises(ValueError):
            signal_from_closes([70.0] * 60)
        with self.assertRaises(ValueError):
            signal_from_closes([70.0] * 60 + [0.0])

    def test_sixty_one_consecutive_completed_months(self) -> None:
        endpoints: list[int] = []
        key = 201907
        for _ in range(61):
            endpoints.append(key)
            key = next_month_key(key)
        self.assertTrue(validate_month_keys(key, endpoints))
        self.assertFalse(validate_month_keys(key, endpoints[:-1]))
        broken = endpoints.copy()
        broken[30] = broken[29]
        self.assertFalse(validate_month_keys(key, broken))

    def test_market_free_density_receipt_is_formula_only(self) -> None:
        receipt = json.loads(NULL_RECEIPT.read_text(encoding="utf-8"))
        self.assertEqual(receipt["schema"], "qm.market-free-null-density/v1")
        self.assertEqual(receipt["generator"]["seed"], 20260902)
        self.assertEqual(receipt["generator"]["replications"], 200_000)
        self.assertEqual(receipt["generator"]["observations_per_replication"], 60)
        self.assertEqual(receipt["locked_statistic"]["lag_count"], 6)
        self.assertEqual(receipt["locked_statistic"]["regression_rows"], 54)
        self.assertEqual(receipt["locked_statistic"]["locked_rounded_boundary"], 4.73)
        self.assertEqual(
            receipt["results"]["qualification_fraction_at_rounded_boundary"],
            0.500665,
        )
        self.assertEqual(
            receipt["results"]["theoretical_qualifying_clocks_per_12"],
            6.00798,
        )
        self.assertIn("pre-data finite-sample", receipt["purpose"].lower())

    def test_setfile_is_one_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41315")
        self.assertEqual(headers["ea_slug"], "wti-archlm-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41315",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "60",
            "strategy_arch_lags": "6",
            "strategy_regression_rows": "54",
            "strategy_energy_floor": "0.000000000000000001",
            "strategy_sst_floor": "0.000000000000000001",
            "strategy_arch_lm_boundary": "4.73",
            "strategy_momentum_months": "12",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars": "1800",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_stale_days": "40",
            "strategy_max_spread_points": "1500",
        }
        self.assertEqual(values, expected)
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        input_names = set(re.findall(r"(?m)^input\s+(?!group\b)(?:\w+\s+)+(\w+)\s*=", source))
        self.assertTrue(set(values) <= input_names)
        self.assertTrue({name for name in input_names if name.startswith("strategy_")} <= set(values))
        self.assertEqual(sorted((EA_DIR / "sets").glob("*.set")), [SETFILE])

    def test_source_contract_attempt_order_and_arch_guards(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        for required in (
            "bool Strategy_ARCHLMCore",
            "bool Strategy_ARCHLMReferenceSelfTest",
            "bool Strategy_ARCHLMSignal",
            "normalized_squares[index] /= residual_energy",
            "for(int current = strategy_arch_lags;",
            "x[lag] = normalized_squares[current - lag]",
            "double normal[7][8]",
            "normal[row][col] += x[row] * x[col]",
            "normal[row][7] += x[row] * y",
            "centered_r_squared = 1.0 - residual_sse / centered_sst",
            "arch_lm = (double)rows_built * centered_r_squared",
            "metrics.arch_lm >= strategy_arch_lm_boundary",
            "strategy_month_returns - strategy_momentum_months",
            "QM_FrameworkMagic() != 413150000",
            "Strategy_HasForeignSymbolPosition()",
        ):
            self.assertIn(required, source)
        prepare = source.index("void Strategy_PrepareDecisionSignal")
        consume = source.index("Strategy_RecordMonthAttempt(g_decision_month_key)", prepare)
        history = source.index("Strategy_LoadMonthlyEndpoints", consume)
        self.assertLess(consume, history)
        open_call = source.index("QM_TM_OpenPosition(req, out_ticket)")
        persist_entry = source.index("Strategy_RecordEntryMonth(g_decision_month_key)", open_call)
        self.assertLess(open_call, persist_entry)
        for prohibited in (
            "iRSI(", "iMACD(", "iBands(", "iADX(", "iMA(", "MathRand(",
            "WebRequest(", "FileOpen(", "JarqueBera", "LjungBox", "GARCH",
            "SampleEntropy", "SpectralEntropy", "autocorrelation",
        ):
            self.assertNotIn(prohibited, source)

    def test_magic_registry_and_canonical_card_are_exact(self) -> None:
        with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
            rows = [
                row
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41315" and row["status"] == "active"
            ]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["ea_slug"], "wti-archlm-tr")
        self.assertEqual(rows[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(rows[0]["magic"], "413150000")
        card = CANONICAL_CARD.read_text(encoding="utf-8-sig")
        self.assertIn("g0_status: APPROVED", card)
        self.assertIn("magic: 413150000", card)


if __name__ == "__main__":
    unittest.main()
