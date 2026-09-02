from __future__ import annotations

import dataclasses
import json
import math
from pathlib import Path
import re
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41311_wti-msampen-tr.mq5"
SETFILE = (
    EA_DIR / "sets" / "QM5_41311_wti-msampen-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41311_wti-msampen-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
NULL_RECEIPT = (
    REPO_ROOT / "artifacts" / "qm5_wti_msampen_tr_null_density_20260902.json"
)

RETURN_COUNT = 60
EMBEDDING_DIMENSION = 2
EMBEDDING_LAG = 1
RADIUS_SD_FRACTION = 0.2
SD_FLOOR = 1e-12
ENTROPY_CEILING = 2.5
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class SampleEntropy:
    sample_mean: float
    sample_sd: float
    radius: float
    matches_m: int
    matches_m_plus_one: int
    value: float


@dataclasses.dataclass(frozen=True)
class Signal:
    direction: int
    entropy: SampleEntropy
    entropy_qualified: bool
    momentum_12: float


def template_pair_matches(
    values: list[float],
    left_start: int,
    right_start: int,
    dimension: int,
    lag: int,
    radius: float,
) -> bool:
    if (
        not values
        or left_start < 0
        or right_start <= left_start
        or dimension <= 0
        or lag <= 0
        or not math.isfinite(radius)
        or radius <= 0.0
        or left_start + (dimension - 1) * lag >= len(values)
        or right_start + (dimension - 1) * lag >= len(values)
    ):
        return False
    return all(
        abs(values[left_start + offset * lag] - values[right_start + offset * lag])
        < radius
        for offset in range(dimension)
    )


def sample_entropy(values: list[float]) -> SampleEntropy:
    if len(values) != RETURN_COUNT or any(not math.isfinite(v) for v in values):
        raise ValueError("sixty finite returns required")

    sample_mean = sum(values) / RETURN_COUNT
    sample_sd = math.sqrt(
        sum((value - sample_mean) ** 2 for value in values) / (RETURN_COUNT - 1)
    )
    if not math.isfinite(sample_sd) or sample_sd <= SD_FLOOR:
        raise ValueError("sample standard deviation at or below floor")
    radius = RADIUS_SD_FRACTION * sample_sd

    template_count_m = RETURN_COUNT - (EMBEDDING_DIMENSION - 1) * EMBEDDING_LAG
    template_count_m_plus_one = (
        RETURN_COUNT - EMBEDDING_DIMENSION * EMBEDDING_LAG
    )
    if (template_count_m, template_count_m_plus_one) != (59, 58):
        raise AssertionError("locked template dimensions changed")

    matches_m = sum(
        template_pair_matches(
            values,
            left,
            right,
            EMBEDDING_DIMENSION,
            EMBEDDING_LAG,
            radius,
        )
        for left in range(template_count_m)
        for right in range(left + 1, template_count_m)
    )
    matches_m_plus_one = sum(
        template_pair_matches(
            values,
            left,
            right,
            EMBEDDING_DIMENSION + 1,
            EMBEDDING_LAG,
            radius,
        )
        for left in range(template_count_m_plus_one)
        for right in range(left + 1, template_count_m_plus_one)
    )
    if matches_m <= 0 or matches_m_plus_one <= 0 or matches_m_plus_one > matches_m:
        raise ValueError("invalid sample-entropy match counts")

    value = math.log(matches_m / matches_m_plus_one)
    if not math.isfinite(value) or value < 0.0:
        raise ValueError("invalid sample entropy")
    return SampleEntropy(
        sample_mean=sample_mean,
        sample_sd=sample_sd,
        radius=radius,
        matches_m=matches_m,
        matches_m_plus_one=matches_m_plus_one,
        value=value,
    )


def signal_from_returns(values: list[float]) -> Signal:
    entropy = sample_entropy(values)
    momentum_12 = sum(values[48:60])
    entropy_qualified = entropy.value <= ENTROPY_CEILING
    direction = 0
    if entropy_qualified and momentum_12 > DIRECTION_EPSILON:
        direction = 1
    elif entropy_qualified and momentum_12 < -DIRECTION_EPSILON:
        direction = -1
    return Signal(direction, entropy, entropy_qualified, momentum_12)


def closes_from_returns(values: list[float], initial: float = 100.0) -> list[float]:
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


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 61 or next_month_key(endpoints[-1]) != current_month:
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


class WtiMonthlySampleEntropyReferenceTests(unittest.TestCase):
    def test_alternating_reference_counts_and_entropy(self) -> None:
        values = [-0.01 if index % 2 == 0 else 0.01 for index in range(60)]
        result = sample_entropy(values)
        self.assertAlmostEqual(result.sample_mean, 0.0, places=15)
        self.assertEqual((result.matches_m, result.matches_m_plus_one), (841, 812))
        self.assertAlmostEqual(result.value, math.log(841 / 812), places=15)

    def test_chebyshev_boundary_is_strict_and_self_pairs_are_excluded(self) -> None:
        values = [0.0, 0.0, 1.0, 1.0]
        self.assertFalse(template_pair_matches(values, 0, 1, 2, 1, 1.0))
        self.assertTrue(template_pair_matches(values, 0, 1, 2, 1, 1.000000000001))
        self.assertFalse(template_pair_matches(values, 0, 0, 2, 1, 2.0))

    def test_sample_sd_uses_n_minus_one_and_floor_fails_closed(self) -> None:
        values = [-0.01 if index % 2 == 0 else 0.01 for index in range(60)]
        result = sample_entropy(values)
        self.assertAlmostEqual(result.sample_sd, math.sqrt(0.006 / 59), places=15)
        self.assertAlmostEqual(result.radius, 0.2 * math.sqrt(0.006 / 59), places=15)
        with self.assertRaisesRegex(ValueError, "standard deviation"):
            sample_entropy([0.01] * 60)

    def test_newest_twelve_month_direction_and_close_orientation(self) -> None:
        buy_values = [-0.005, 0.015] * 30
        sell_values = [-0.015, 0.005] * 30
        buy = signal_from_closes(closes_from_returns(buy_values))
        sell = signal_from_closes(closes_from_returns(sell_values))
        self.assertTrue(buy.entropy_qualified)
        self.assertTrue(sell.entropy_qualified)
        self.assertEqual((buy.direction, sell.direction), (1, -1))
        self.assertAlmostEqual(buy.momentum_12, 0.06, places=12)
        self.assertAlmostEqual(sell.momentum_12, -0.06, places=12)
        self.assertLessEqual(ENTROPY_CEILING, ENTROPY_CEILING)

    def test_dimensions_and_bad_closes_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            sample_entropy([0.01] * 59)
        with self.assertRaises(ValueError):
            sample_entropy([0.01] * 59 + [math.inf])
        with self.assertRaises(ValueError):
            signal_from_closes([100.0] * 60)
        with self.assertRaises(ValueError):
            signal_from_closes([100.0] * 60 + [0.0])

    def test_sixty_one_consecutive_completed_months(self) -> None:
        endpoints: list[int] = []
        key = 201911
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
        self.assertEqual(receipt["generator"]["observations_per_draw"], 60)
        self.assertEqual(receipt["result"]["qualified"], 59_272)
        self.assertEqual(
            receipt["result"]["qualified"]
            + receipt["result"]["invalid_zero_length_3_matches"]
            + receipt["result"]["valid_above_boundary"],
            receipt["generator"]["draws"],
        )
        self.assertIn("not performance evidence", receipt["purpose"])

    def test_setfile_is_one_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41311")
        self.assertEqual(headers["ea_slug"], "wti-msampen-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41311",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "60",
            "strategy_embedding_dimension": "2",
            "strategy_embedding_lag": "1",
            "strategy_radius_sd_fraction": "0.2",
            "strategy_sd_floor": "0.000000000001",
            "strategy_entropy_ceiling": "2.5",
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
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        input_names = set(
            re.findall(r"(?m)^input\s+(?!group\b)(?:\w+\s+)+(\w+)\s*=", source)
        )
        self.assertTrue(set(values) <= input_names)
        self.assertTrue(
            {name for name in input_names if name.startswith("strategy_")} <= set(values)
        )
        self.assertEqual(sorted((EA_DIR / "sets").glob("*.set")), [SETFILE])

    def test_source_contract_attempt_order_and_entropy_guards(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        for required in (
            "bool Strategy_TemplatePairMatches",
            "bool Strategy_SampleEntropyCore",
            "bool Strategy_SampleEntropyReferenceSelfTest",
            "bool Strategy_SampleEntropySignal",
            "distance >= radius",
            "matches_m_plus_one > matches_m",
            "MathLog((double)matches_m / (double)matches_m_plus_one)",
            "metrics.sample_entropy <= strategy_entropy_ceiling",
            "strategy_month_returns - strategy_momentum_months",
            "QM_FrameworkMagic() != 413110000",
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
        self.assertIn("Strategy_RecoverEntryMonthFromDeals", source)
        self.assertIn("HistorySelectByPosition(position_id)", source)

        for prohibited in (
            "iRSI(",
            "iMACD(",
            "iBands(",
            "iADX(",
            "iMA(",
            "MathRand(",
            "WebRequest(",
            "FileOpen(",
            "LZ76",
        ):
            self.assertNotIn(prohibited, source)

    def test_magic_registry_and_card_copy_are_exact(self) -> None:
        registry = MAGIC_REGISTRY.read_text(encoding="utf-8-sig")
        self.assertIn("41311,wti-msampen-tr,0,XTIUSD.DWX,413110000", registry)
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )


if __name__ == "__main__":
    unittest.main()
