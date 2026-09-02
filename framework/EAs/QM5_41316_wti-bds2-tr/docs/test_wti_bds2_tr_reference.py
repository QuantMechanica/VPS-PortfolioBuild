from __future__ import annotations

import csv
import dataclasses
import json
import math
from pathlib import Path
import re
import statistics
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41316_wti-bds2-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41316_wti-bds2-tr_XTIUSD.DWX_D1_backtest.set"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41316_wti-bds2-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
NULL_RECEIPT = REPO_ROOT / "artifacts" / "qm5_wti_bds2_tr_null_density_20260902.json"

RETURN_COUNT = 48
DISTANCE_MULTIPLIER = 1.5
SAMPLE_VARIANCE_FLOOR = 1e-18
EPSILON_FLOOR = 1e-12
BDS_VARIANCE_FLOOR = 1e-18
ABS_BDS_BOUNDARY = 0.6744897501960817
MOMENTUM_MONTHS = 12
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class BDS2State:
    mean_return: float
    sample_variance: float
    sample_sd: float
    epsilon: float
    c1_full: float
    k_full: float
    c1_truncated: float
    c2_joint: float
    bds_variance: float
    bds2: float


@dataclasses.dataclass(frozen=True)
class Signal:
    direction: int
    state: BDS2State
    qualified: bool
    momentum_12: float


def strict_indicator_matrix(values: list[float], epsilon: float) -> list[list[int]]:
    if epsilon <= 0.0 or not math.isfinite(epsilon):
        raise ValueError("positive finite epsilon required")
    return [
        [int(abs(left - right) < epsilon) for right in values]
        for left in values
    ]


def direct_bds2(values: list[float]) -> BDS2State:
    """Scalar port matching the card and bounded MQL implementation."""
    if len(values) != RETURN_COUNT or any(not math.isfinite(v) for v in values):
        raise ValueError("forty-eight finite returns required")
    mean_return = sum(values) / RETURN_COUNT
    sample_variance = sum((value - mean_return) ** 2 for value in values) / 47
    if not math.isfinite(sample_variance) or sample_variance <= SAMPLE_VARIANCE_FLOOR:
        raise ValueError("sample variance at or below floor")
    sample_sd = math.sqrt(sample_variance)
    epsilon = DISTANCE_MULTIPLIER * sample_sd
    if epsilon <= EPSILON_FLOOR or not math.isfinite(epsilon):
        raise ValueError("epsilon at or below floor")

    indicator = strict_indicator_matrix(values, epsilon)
    full_pairs = RETURN_COUNT * 47 // 2
    c1_full = sum(
        indicator[left][right]
        for left in range(RETURN_COUNT)
        for right in range(left + 1, RETURN_COUNT)
    ) / full_pairs
    rows = [sum(row) for row in indicator]
    indicator_sum = sum(rows)
    k_full = (
        sum(row * row for row in rows) - 3 * indicator_sum + 2 * RETURN_COUNT
    ) / (RETURN_COUNT * 47 * 46)

    conditioned_pairs = 47 * 46 // 2
    c1_truncated = sum(
        indicator[left][right]
        for left in range(1, RETURN_COUNT)
        for right in range(left + 1, RETURN_COUNT)
    ) / conditioned_pairs
    c2_joint = sum(
        indicator[left][right] * indicator[left + 1][right + 1]
        for left in range(47)
        for right in range(left + 1, 47)
    ) / conditioned_pairs

    bds_variance = 4.0 * (k_full - c1_full * c1_full) ** 2
    if not math.isfinite(bds_variance) or bds_variance <= BDS_VARIANCE_FLOOR:
        raise ValueError("BDS variance at or below floor")
    bds2 = math.sqrt(47) * (c2_joint - c1_truncated**2) / math.sqrt(bds_variance)
    if not math.isfinite(bds2):
        raise ValueError("invalid BDS statistic")
    return BDS2State(
        mean_return,
        sample_variance,
        sample_sd,
        epsilon,
        c1_full,
        k_full,
        c1_truncated,
        c2_joint,
        bds_variance,
        bds2,
    )


def delay_vector_bds2(values: list[float]) -> tuple[float, float, float]:
    """Independent sup-norm delay-vector construction of C1T, C2, and BDS2."""
    epsilon = DISTANCE_MULTIPLIER * statistics.stdev(values)
    one_dimensional = values[1:]
    delay_vectors = list(zip(values[:-1], values[1:]))

    def correlation_sum(points: list[float] | list[tuple[float, float]]) -> float:
        hits = 0
        pairs = 0
        for left_index, left in enumerate(points):
            for right in points[left_index + 1 :]:
                if isinstance(left, tuple):
                    distance = max(abs(left[0] - right[0]), abs(left[1] - right[1]))
                else:
                    distance = abs(left - right)
                hits += int(distance < epsilon)
                pairs += 1
        return hits / pairs

    c1_truncated = correlation_sum(one_dimensional)
    c2_joint = correlation_sum(delay_vectors)
    direct = direct_bds2(values)
    bds2 = (
        math.sqrt(47)
        * (c2_joint - c1_truncated**2)
        / math.sqrt(direct.bds_variance)
    )
    return c1_truncated, c2_joint, bds2


def classify(bds2: float, momentum_12: float) -> int:
    if (
        not math.isfinite(bds2)
        or not math.isfinite(momentum_12)
        or abs(bds2) < ABS_BDS_BOUNDARY
    ):
        return 0
    if momentum_12 > DIRECTION_EPSILON:
        return 1
    if momentum_12 < -DIRECTION_EPSILON:
        return -1
    return 0


def signal_from_returns(values: list[float]) -> Signal:
    state = direct_bds2(values)
    momentum_12 = sum(values[-MOMENTUM_MONTHS:])
    qualified = abs(state.bds2) >= ABS_BDS_BOUNDARY
    return Signal(classify(state.bds2, momentum_12), state, qualified, momentum_12)


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
    returns = [math.log(right / left) for left, right in zip(closes, closes[1:])]
    return signal_from_returns(returns)


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


class WtiMonthlyBDS2ReferenceTests(unittest.TestCase):
    def test_pinned_upstream_monotone_sequence_dimension_two(self) -> None:
        # statsmodels' pinned Kanzler fixture is sequence 1..25. These values
        # are the fixture's dimension-two internals/output rounded to 8 places.
        values = [float(value) for value in range(1, 26)]
        mean_return = sum(values) / len(values)
        sample_variance = sum((value - mean_return) ** 2 for value in values) / 24
        epsilon = 1.5 * math.sqrt(sample_variance)
        indicator = strict_indicator_matrix(values, epsilon)
        c1 = sum(indicator[a][b] for a in range(25) for b in range(a + 1, 25)) / 300
        rows = [sum(row) for row in indicator]
        k_value = (sum(row * row for row in rows) - 3 * sum(rows) + 50) / (25 * 24 * 23)
        c1t = sum(indicator[a][b] for a in range(1, 25) for b in range(a + 1, 25)) / 276
        c2 = sum(
            indicator[a][b] * indicator[a + 1][b + 1]
            for a in range(24)
            for b in range(a + 1, 24)
        ) / 276
        variance2 = 4 * (k_value - c1 * c1) ** 2
        statistic = math.sqrt(24) * (c2 - c1t * c1t) / math.sqrt(variance2)
        self.assertAlmostEqual(c1, 0.69666667, places=8)
        self.assertAlmostEqual(k_value, 0.49898551, places=8)
        self.assertAlmostEqual(c1t, 0.71739130, places=8)
        self.assertAlmostEqual(c2, 0.71739130, places=8)
        self.assertAlmostEqual(statistic, 36.40567147, places=8)

    def test_mql_reference_fixture_matches_independent_delay_vectors(self) -> None:
        values = [
            0.012 * math.sin(0.41 * index)
            + 0.006 * math.cos(0.17 * index)
            + 0.003 * ((index % 5) - 2)
            + 0.00015 * index
            for index in range(48)
        ]
        state = direct_bds2(values)
        c1t, c2, delay_bds2 = delay_vector_bds2(values)
        self.assertAlmostEqual(state.mean_return, 0.004221652227540728, places=15)
        self.assertAlmostEqual(state.sample_variance, 0.000114021181450521, places=15)
        self.assertAlmostEqual(state.epsilon, 0.016017105177393062, places=15)
        self.assertAlmostEqual(state.c1_full, 0.6870567375886525, places=15)
        self.assertAlmostEqual(state.k_full, 0.4957600986740672, places=15)
        self.assertAlmostEqual(state.c1_truncated, c1t, places=15)
        self.assertAlmostEqual(state.c2_joint, c2, places=15)
        self.assertAlmostEqual(state.bds_variance, 0.002249251656765691, places=15)
        self.assertAlmostEqual(state.bds2, 12.555681198874424, places=12)
        self.assertAlmostEqual(state.bds2, delay_bds2, places=14)

    def test_sample_ddof_strict_epsilon_and_unit_diagonal(self) -> None:
        values = [float(index) for index in range(48)]
        state = direct_bds2(values)
        self.assertAlmostEqual(state.sample_sd, statistics.stdev(values), places=15)
        self.assertNotAlmostEqual(state.sample_sd, statistics.pstdev(values), places=10)
        equality = strict_indicator_matrix([0.0, 1.0, 2.0], 1.0)
        self.assertEqual(equality, [[1, 0, 0], [0, 1, 0], [0, 0, 1]])

    def test_affine_invariance_and_direction_uses_raw_newest_returns(self) -> None:
        carrier = [
            0.012 * math.sin(0.41 * index)
            + 0.006 * math.cos(0.17 * index)
            + 0.003 * ((index % 5) - 2)
            for index in range(48)
        ]
        original = direct_bds2(carrier)
        affine = direct_bds2([3.0 + 7.0 * value for value in carrier])
        self.assertEqual(
            (original.c1_full, original.k_full, original.c1_truncated, original.c2_joint),
            (affine.c1_full, affine.k_full, affine.c1_truncated, affine.c2_joint),
        )
        self.assertAlmostEqual(original.bds2, affine.bds2, places=12)
        buy = signal_from_closes(closes_from_returns([value + 0.03 for value in carrier]))
        sell = signal_from_closes(closes_from_returns([value - 0.03 for value in carrier]))
        self.assertTrue(buy.qualified and sell.qualified)
        self.assertEqual((buy.direction, sell.direction), (1, -1))

    def test_boundary_is_absolute_inclusive_and_direction_band_symmetric(self) -> None:
        for boundary in (ABS_BDS_BOUNDARY, -ABS_BDS_BOUNDARY):
            self.assertEqual(classify(boundary, 0.01), 1)
            self.assertEqual(classify(boundary, -0.01), -1)
        inner = math.nextafter(ABS_BDS_BOUNDARY, 0.0)
        self.assertEqual(classify(inner, 0.01), 0)
        self.assertEqual(classify(-inner, -0.01), 0)
        self.assertEqual(classify(ABS_BDS_BOUNDARY, DIRECTION_EPSILON), 0)
        self.assertEqual(classify(-ABS_BDS_BOUNDARY, -DIRECTION_EPSILON), 0)

    def test_constant_bad_and_wrong_length_paths_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "variance"):
            direct_bds2([0.01] * 48)
        with self.assertRaises(ValueError):
            direct_bds2([0.01] * 47)
        with self.assertRaises(ValueError):
            direct_bds2([0.01] * 47 + [math.inf])
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
        self.assertEqual(receipt["schema"], "qm.asymptotic-null-density/v1")
        self.assertEqual(receipt["source_contract"]["observations_per_decision"], 48)
        self.assertEqual(receipt["source_contract"]["embedding_dimension"], 2)
        self.assertEqual(
            receipt["source_contract"]["epsilon_multiplier_of_sample_sd_ddof1"], 1.5
        )
        self.assertEqual(
            receipt["locked_state_divider"]["absolute_boundary"], ABS_BDS_BOUNDARY
        )
        self.assertEqual(
            receipt["asymptotic_results"][
                "probability_abs_standard_normal_at_or_above_boundary"
            ],
            0.5,
        )
        self.assertEqual(
            receipt["asymptotic_results"]["theoretical_qualifying_clocks_per_12"],
            6.0,
        )
        self.assertIn("not WTI evidence", receipt["purpose"])

    def test_setfile_is_one_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41316")
        self.assertEqual(headers["ea_slug"], "wti-bds2-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41316",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "48",
            "strategy_embedding_dim": "2",
            "strategy_distance_multiplier": "1.5",
            "strategy_sample_variance_floor": "0.000000000000000001",
            "strategy_epsilon_floor": "0.000000000001",
            "strategy_bds_variance_floor": "0.000000000000000001",
            "strategy_abs_bds_boundary": "0.6744897501960817",
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

    def test_source_contract_attempt_order_and_bds_guards(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        for required in (
            "bool Strategy_BDS2Core",
            "bool Strategy_BDS2ReferenceSelfTest",
            "bool Strategy_BDS2Signal",
            "sample_variance = variance_numerator / (double)(value_count - 1)",
            "indicators[left][right] = (distance < epsilon) ? 1 : 0",
            "row_square_sum -",
            "3.0 * (double)total_indicator_sum",
            "indicators[left][right] * indicators[left + 1][right + 1]",
            "4.0 * variance_effect * variance_effect",
            "MathAbs(metrics.bds2) >= strategy_abs_bds_boundary",
            "strategy_month_returns - strategy_momentum_months",
            "QM_FrameworkMagic() != 413160000",
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
                if row["ea_id"] == "41316" and row["status"] == "active"
            ]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["ea_slug"], "wti-bds2-tr")
        self.assertEqual(rows[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(rows[0]["magic"], "413160000")
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )


if __name__ == "__main__":
    unittest.main()
