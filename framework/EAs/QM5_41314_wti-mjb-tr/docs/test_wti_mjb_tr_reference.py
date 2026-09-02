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
EA_SOURCE = EA_DIR / "QM5_41314_wti-mjb-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41314_wti-mjb-tr_XTIUSD.DWX_D1_backtest.set"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41314_wti-mjb-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
NULL_RECEIPT = (
    REPO_ROOT / "artifacts" / "qm5_wti_mjb_tr_null_density_20260902.json"
)

RETURN_COUNT = 48
VARIANCE_FLOOR = 1e-18
JB_BOUNDARY = 1.04
MOMENTUM_MONTHS = 12
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class JarqueBeraState:
    mean_return: float
    m2: float
    m3: float
    m4: float
    skewness: float
    excess_kurtosis: float
    jarque_bera: float


@dataclasses.dataclass(frozen=True)
class Signal:
    direction: int
    state: JarqueBeraState
    qualified: bool
    momentum_12: float


def direct_jarque_bera(values: list[float]) -> JarqueBeraState:
    if len(values) < 4 or any(not math.isfinite(v) for v in values):
        raise ValueError("at least four finite returns required")
    count = len(values)
    mean_return = sum(values) / count
    centered = [value - mean_return for value in values]
    m2 = sum(value**2 for value in centered) / count
    m3 = sum(value**3 for value in centered) / count
    m4 = sum(value**4 for value in centered) / count
    if not math.isfinite(m2) or m2 <= VARIANCE_FLOOR:
        raise ValueError("biased second moment at or below floor")
    skewness = m3 / (m2**1.5)
    excess_kurtosis = m4 / (m2**2) - 3.0
    jarque_bera = count / 6.0 * (
        skewness**2 + excess_kurtosis**2 / 4.0
    )
    state = JarqueBeraState(
        mean_return, m2, m3, m4, skewness, excess_kurtosis, jarque_bera
    )
    if any(not math.isfinite(value) for value in dataclasses.astuple(state)):
        raise ValueError("invalid Jarque-Bera state")
    return state


def numpy_jarque_bera(values: list[float]) -> JarqueBeraState:
    array = np.asarray(values, dtype=np.float64)
    centered = array - np.mean(array)
    m2 = float(np.mean(centered**2))
    m3 = float(np.mean(centered**3))
    m4 = float(np.mean(centered**4))
    skewness = m3 / m2**1.5
    excess_kurtosis = m4 / m2**2 - 3.0
    jarque_bera = len(values) / 6.0 * (
        skewness**2 + excess_kurtosis**2 / 4.0
    )
    return JarqueBeraState(
        float(np.mean(array)), m2, m3, m4, skewness, excess_kurtosis, jarque_bera
    )


def classify(jarque_bera: float, momentum_12: float) -> int:
    if (
        not math.isfinite(jarque_bera)
        or not math.isfinite(momentum_12)
        or jarque_bera < JB_BOUNDARY
    ):
        return 0
    if momentum_12 > DIRECTION_EPSILON:
        return 1
    if momentum_12 < -DIRECTION_EPSILON:
        return -1
    return 0


def signal_from_returns(values: list[float]) -> Signal:
    if len(values) != RETURN_COUNT:
        raise ValueError("forty-eight returns required")
    state = direct_jarque_bera(values)
    momentum_12 = sum(values[-MOMENTUM_MONTHS:])
    qualified = state.jarque_bera >= JB_BOUNDARY
    return Signal(
        classify(state.jarque_bera, momentum_12), state, qualified, momentum_12
    )


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


class WtiMonthlyJarqueBeraReferenceTests(unittest.TestCase):
    def test_pinned_scipy_fixture_has_exact_biased_statistic(self) -> None:
        values = [
            -0.160104223201523288,
            1.131262000934478040,
            -0.001235254523709458,
            -0.776440091309490987,
            -2.072959999533182884,
        ]
        state = direct_jarque_bera(values)
        self.assertAlmostEqual(state.mean_return, -0.3758955135266857, places=15)
        self.assertAlmostEqual(state.m2, 1.0997847585017662, places=15)
        self.assertAlmostEqual(state.m3, -0.29313419144364505, places=15)
        self.assertAlmostEqual(state.m4, 2.700398537026828, places=15)
        self.assertAlmostEqual(state.skewness, -0.2541586721782321, places=15)
        self.assertAlmostEqual(state.excess_kurtosis, -0.767392030299042, places=15)
        self.assertAlmostEqual(state.jarque_bera, 0.17651605223752, places=14)

    def test_direct_biased_moments_match_numpy_vector(self) -> None:
        values = [
            0.007 * math.sin(0.31 * index)
            + 0.004 * math.cos(0.77 * index)
            + 0.0002 * index
            for index in range(48)
        ]
        direct = direct_jarque_bera(values)
        vector = numpy_jarque_bera(values)
        np.testing.assert_allclose(
            dataclasses.astuple(direct),
            dataclasses.astuple(vector),
            rtol=5e-13,
            atol=1e-16,
        )

    def test_gate_is_affine_invariant_but_direction_uses_raw_returns(self) -> None:
        carrier = [0.01 if index % 2 == 0 else -0.01 for index in range(48)]
        buy = signal_from_closes(closes_from_returns([value + 0.02 for value in carrier]))
        sell = signal_from_closes(closes_from_returns([value - 0.02 for value in carrier]))
        scaled = direct_jarque_bera([3.7 * value + 0.25 for value in carrier])
        base = direct_jarque_bera(carrier)
        self.assertAlmostEqual(buy.state.jarque_bera, sell.state.jarque_bera, places=10)
        self.assertAlmostEqual(scaled.jarque_bera, base.jarque_bera, places=12)
        self.assertTrue(buy.qualified and sell.qualified)
        self.assertEqual((buy.direction, sell.direction), (1, -1))

    def test_boundary_is_inclusive_and_direction_band_is_symmetric(self) -> None:
        self.assertEqual(classify(JB_BOUNDARY, 0.01), 1)
        self.assertEqual(classify(JB_BOUNDARY, -0.01), -1)
        self.assertEqual(classify(math.nextafter(JB_BOUNDARY, -math.inf), 0.01), 0)
        self.assertEqual(classify(JB_BOUNDARY, DIRECTION_EPSILON), 0)
        self.assertEqual(classify(JB_BOUNDARY, -DIRECTION_EPSILON), 0)

    def test_constant_and_bad_paths_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "second moment"):
            direct_jarque_bera([0.01] * 48)
        with self.assertRaises(ValueError):
            direct_jarque_bera([0.01] * 3)
        with self.assertRaises(ValueError):
            direct_jarque_bera([0.01] * 47 + [math.inf])
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
        self.assertEqual(receipt["locked_statistic"]["moment_denominator"], 48)
        self.assertEqual(
            receipt["locked_statistic"]["formula"],
            "JB=48/6*(skewness^2+excess_kurtosis^2/4)",
        )
        self.assertEqual(receipt["locked_statistic"]["locked_rounded_boundary"], 1.04)
        self.assertEqual(
            receipt["results"]["qualification_fraction_at_rounded_boundary"],
            0.49981,
        )
        self.assertEqual(
            receipt["results"]["theoretical_qualifying_clocks_per_12"],
            5.99772,
        )
        self.assertIn("Pre-data finite-sample", receipt["purpose"])

    def test_setfile_is_one_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41314")
        self.assertEqual(headers["ea_slug"], "wti-mjb-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41314",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "48",
            "strategy_variance_floor": "0.000000000000000001",
            "strategy_jb_boundary": "1.04",
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

    def test_source_contract_attempt_order_and_shape_guards(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        for required in (
            "bool Strategy_JarqueBeraCore",
            "bool Strategy_JarqueBeraReferenceSelfTest",
            "bool Strategy_JarqueBeraSignal",
            "moment_2 /= count",
            "moment_3 /= count",
            "moment_4 /= count",
            "moment_3 / skew_denominator",
            "moment_4 / kurtosis_denominator - 3.0",
            "skewness * skewness",
            "excess_kurtosis * excess_kurtosis / 4.0",
            "metrics.jarque_bera >= strategy_jb_boundary",
            "strategy_month_returns - strategy_momentum_months",
            "QM_FrameworkMagic() != 413140000",
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
            "LjungBox", "autocorrelation",
        ):
            self.assertNotIn(prohibited, source)

    def test_magic_registry_and_card_copy_are_exact(self) -> None:
        with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
            rows = [
                row
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41314" and row["status"] == "active"
            ]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["ea_slug"], "wti-mjb-tr")
        self.assertEqual(rows[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(rows[0]["magic"], "413140000")
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )


if __name__ == "__main__":
    unittest.main()
