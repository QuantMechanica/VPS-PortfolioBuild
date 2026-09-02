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
EA_SOURCE = EA_DIR / "QM5_41313_wti-ljungbox-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41313_wti-ljungbox-tr_XTIUSD.DWX_D1_backtest.set"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41313_wti-ljungbox-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
NULL_RECEIPT = (
    REPO_ROOT / "artifacts" / "qm5_wti_ljungbox_tr_null_density_20260902.json"
)

RETURN_COUNT = 48
LAGS = 6
VARIANCE_FLOOR = 1e-18
Q_BOUNDARY = 5.35
MOMENTUM_MONTHS = 12
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class PortmanteauState:
    mean_return: float
    variance_sum: float
    autocorrelations: tuple[float, ...]
    q6: float


@dataclasses.dataclass(frozen=True)
class Signal:
    direction: int
    state: PortmanteauState
    qualified: bool
    momentum_12: float


def direct_portmanteau(values: list[float]) -> PortmanteauState:
    if len(values) != RETURN_COUNT or any(not math.isfinite(v) for v in values):
        raise ValueError("forty-eight finite returns required")
    mean_return = sum(values) / RETURN_COUNT
    centered = [value - mean_return for value in values]
    variance_sum = sum(value * value for value in centered)
    if not math.isfinite(variance_sum) or variance_sum <= VARIANCE_FLOOR:
        raise ValueError("centered variance at or below floor")
    autocorrelations = tuple(
        sum(centered[index] * centered[index - lag] for index in range(lag, 48))
        / variance_sum
        for lag in range(1, LAGS + 1)
    )
    q6 = RETURN_COUNT * (RETURN_COUNT + 2) * sum(
        rho * rho / (RETURN_COUNT - lag)
        for lag, rho in enumerate(autocorrelations, start=1)
    )
    if not math.isfinite(q6) or q6 < 0.0:
        raise ValueError("invalid portmanteau statistic")
    return PortmanteauState(mean_return, variance_sum, autocorrelations, q6)


def numpy_portmanteau(values: list[float]) -> PortmanteauState:
    centered = np.asarray(values, dtype=np.float64) - np.mean(values)
    correlation = np.correlate(centered, centered, mode="full")
    denominator = float(correlation[RETURN_COUNT - 1])
    rhos = tuple(
        float(correlation[RETURN_COUNT - 1 + lag] / denominator)
        for lag in range(1, LAGS + 1)
    )
    q6 = RETURN_COUNT * (RETURN_COUNT + 2) * sum(
        rho * rho / (RETURN_COUNT - lag)
        for lag, rho in enumerate(rhos, start=1)
    )
    return PortmanteauState(float(np.mean(values)), denominator, rhos, q6)


def classify(q6: float, momentum_12: float) -> int:
    if not math.isfinite(q6) or not math.isfinite(momentum_12) or q6 < Q_BOUNDARY:
        return 0
    if momentum_12 > DIRECTION_EPSILON:
        return 1
    if momentum_12 < -DIRECTION_EPSILON:
        return -1
    return 0


def signal_from_returns(values: list[float]) -> Signal:
    state = direct_portmanteau(values)
    momentum_12 = sum(values[-MOMENTUM_MONTHS:])
    qualified = state.q6 >= Q_BOUNDARY
    return Signal(classify(state.q6, momentum_12), state, qualified, momentum_12)


def closes_from_returns(values: list[float], initial: float = 70.0) -> list[float]:
    closes = [initial]
    for value in values:
        closes.append(closes[-1] * math.exp(value))
    return closes


def signal_from_closes(closes: list[float]) -> Signal:
    if len(closes) != 49 or any(
        not math.isfinite(value) or value <= 0.0 for value in closes
    ):
        raise ValueError("forty-nine positive finite closes required")
    values = [math.log(right / left) for left, right in zip(closes, closes[1:])]
    return signal_from_returns(values)


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 49 or next_month_key(endpoints[-1]) != current_month:
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


class WtiMonthlyLjungBoxReferenceTests(unittest.TestCase):
    def test_alternating_fixture_has_exact_six_lag_statistic(self) -> None:
        values = [0.01 if index % 2 == 0 else -0.01 for index in range(48)]
        state = direct_portmanteau(values)
        expected_rhos = tuple((-1.0 if lag % 2 else 1.0) * (48 - lag) / 48 for lag in range(1, 7))
        self.assertAlmostEqual(state.mean_return, 0.0, places=15)
        self.assertAlmostEqual(state.variance_sum, 0.0048, places=15)
        np.testing.assert_allclose(state.autocorrelations, expected_rhos, rtol=1e-14)
        self.assertAlmostEqual(state.q6, 278.125, places=12)

    def test_direct_lag_orientation_matches_numpy_correlation(self) -> None:
        values = [
            0.007 * math.sin(0.31 * index)
            + 0.004 * math.cos(0.77 * index)
            + 0.0002 * index
            for index in range(48)
        ]
        direct = direct_portmanteau(values)
        vector = numpy_portmanteau(values)
        np.testing.assert_allclose(
            direct.autocorrelations, vector.autocorrelations, rtol=1e-14, atol=1e-16
        )
        self.assertAlmostEqual(direct.q6, vector.q6, places=12)

    def test_gate_is_shift_invariant_but_direction_uses_raw_newest_returns(self) -> None:
        carrier = [0.01 if index % 2 == 0 else -0.01 for index in range(48)]
        buy = signal_from_closes(closes_from_returns([value + 0.02 for value in carrier]))
        sell = signal_from_closes(closes_from_returns([value - 0.02 for value in carrier]))
        self.assertAlmostEqual(buy.state.q6, sell.state.q6, places=10)
        self.assertTrue(buy.qualified and sell.qualified)
        self.assertEqual((buy.direction, sell.direction), (1, -1))

    def test_boundary_is_inclusive_and_direction_band_is_symmetric(self) -> None:
        self.assertEqual(classify(Q_BOUNDARY, 0.01), 1)
        self.assertEqual(classify(Q_BOUNDARY, -0.01), -1)
        self.assertEqual(classify(math.nextafter(Q_BOUNDARY, -math.inf), 0.01), 0)
        self.assertEqual(classify(Q_BOUNDARY, DIRECTION_EPSILON), 0)
        self.assertEqual(classify(Q_BOUNDARY, -DIRECTION_EPSILON), 0)

    def test_constant_and_bad_paths_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "variance"):
            direct_portmanteau([0.01] * 48)
        with self.assertRaises(ValueError):
            direct_portmanteau([0.01] * 47)
        with self.assertRaises(ValueError):
            direct_portmanteau([0.01] * 47 + [math.inf])
        with self.assertRaises(ValueError):
            signal_from_closes([70.0] * 48)
        with self.assertRaises(ValueError):
            signal_from_closes([70.0] * 48 + [0.0])

    def test_forty_nine_consecutive_completed_months(self) -> None:
        endpoints: list[int] = []
        key = 202007
        for _ in range(49):
            endpoints.append(key)
            key = next_month_key(key)
        self.assertTrue(validate_month_keys(key, endpoints))
        self.assertFalse(validate_month_keys(key, endpoints[:-1]))
        broken = endpoints.copy()
        broken[24] = broken[23]
        self.assertFalse(validate_month_keys(key, broken))

    def test_market_free_density_receipt_is_formula_only(self) -> None:
        receipt = json.loads(NULL_RECEIPT.read_text(encoding="utf-8"))
        self.assertEqual(receipt["schema"], "qm.market-free-null-density/v1")
        self.assertEqual(receipt["generator"]["seed"], 20260902)
        self.assertEqual(receipt["generator"]["replications"], 200_000)
        self.assertEqual(receipt["generator"]["observations_per_replication"], 48)
        self.assertEqual(receipt["locked_statistic"]["autocorrelation_lags"], list(range(1, 7)))
        self.assertEqual(receipt["locked_statistic"]["locked_rounded_boundary"], 5.35)
        self.assertEqual(receipt["results"]["qualification_fraction_at_rounded_boundary"], 0.501025)
        self.assertEqual(receipt["results"]["theoretical_qualifying_clocks_per_12"], 6.0123)
        self.assertIn("Pre-data cadence", receipt["purpose"])

    def test_setfile_is_one_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41313")
        self.assertEqual(headers["ea_slug"], "wti-ljungbox-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41313",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "48",
            "strategy_ljung_box_lags": "6",
            "strategy_variance_floor": "0.000000000000000001",
            "strategy_q_boundary": "5.35",
            "strategy_momentum_months": "12",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars": "1500",
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

    def test_source_contract_attempt_order_and_portmanteau_guards(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        for required in (
            "bool Strategy_LjungBoxCore",
            "bool Strategy_LjungBoxReferenceSelfTest",
            "bool Strategy_LjungBoxSignal",
            "centered[index] * centered[index - lag]",
            "autocorrelation * autocorrelation / lag_denominator",
            "(double)value_count * (double)(value_count + 2)",
            "metrics.ljung_box_q6 >= strategy_q_boundary",
            "strategy_month_returns - strategy_momentum_months",
            "QM_FrameworkMagic() != 413130000",
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
            "WebRequest(", "FileOpen(", "SpectralEntropy", "SampleEntropy", "LZ76",
        ):
            self.assertNotIn(prohibited, source)

    def test_magic_registry_and_card_copy_are_exact(self) -> None:
        with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
            rows = [
                row
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41313" and row["status"] == "active"
            ]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["ea_slug"], "wti-ljungbox-tr")
        self.assertEqual(rows[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(rows[0]["magic"], "413130000")
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )


if __name__ == "__main__":
    unittest.main()
