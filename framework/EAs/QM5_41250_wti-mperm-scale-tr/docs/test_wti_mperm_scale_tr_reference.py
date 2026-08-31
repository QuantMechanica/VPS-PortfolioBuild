from __future__ import annotations

import dataclasses
import itertools
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41250_wti-mperm-scale-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41250_wti-mperm-scale-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41250_wti-mperm-scale-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
SCALE_EPSILON = 1e-12
COMPARE_TOLERANCE = 1e-14
DIRECTION_EPSILON = 1e-12
TAIL_COUNT_MAX = 416


@dataclasses.dataclass(frozen=True)
class PermutationScaleSignal:
    direction: int
    returns: tuple[float, ...]
    mean_old: float
    mean_recent: float
    median_old: float
    median_recent: float
    mad_old: float
    mad_recent: float
    observed_scale_delta: float
    assignment_count: int
    tail_count: int
    tail_fraction: float


def closes_from_returns(returns: list[float], initial: float = 100.0) -> list[float]:
    closes = [initial]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def median6(values: tuple[float, ...]) -> float:
    if len(values) != 6 or any(not math.isfinite(value) for value in values):
        raise ValueError("fixed sample must contain six finite values")
    ordered = sorted(values)
    return (ordered[2] + ordered[3]) / 2.0


def mad6(values: tuple[float, ...]) -> tuple[float, float]:
    center = median6(values)
    deviations = tuple(abs(value - center) for value in values)
    mad = median6(deviations)
    if not math.isfinite(mad) or mad < 0.0:
        raise ValueError("MAD must be finite and nonnegative")
    return center, mad


def permutation_scale_signal(
    closes: list[float],
    month_returns: int = 12,
    block_size: int = 6,
    scale_epsilon: float = SCALE_EPSILON,
    compare_tolerance: float = COMPARE_TOLERANCE,
    tail_count_max: int = TAIL_COUNT_MAX,
    direction_epsilon: float = DIRECTION_EPSILON,
) -> PermutationScaleSignal:
    if (
        month_returns != 12
        or block_size != 6
        or scale_epsilon != SCALE_EPSILON
        or compare_tolerance != COMPARE_TOLERANCE
        or tail_count_max != TAIL_COUNT_MAX
        or direction_epsilon != DIRECTION_EPSILON
        or len(closes) != month_returns + 1
    ):
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")

    returns = tuple(
        math.log(right / left) for left, right in zip(closes, closes[1:])
    )
    if len(returns) != month_returns or any(
        not math.isfinite(value) for value in returns
    ):
        raise ValueError("returns must be finite")

    old = returns[:block_size]
    recent = returns[block_size:]
    mean_old = sum(old) / block_size
    mean_recent = sum(recent) / block_size
    median_old, mad_old = mad6(old)
    median_recent, mad_recent = mad6(recent)
    observed = mad_recent - mad_old
    if any(
        not math.isfinite(value)
        for value in (
            mean_old,
            mean_recent,
            median_old,
            median_recent,
            mad_old,
            mad_recent,
            observed,
        )
    ):
        raise ValueError("scale arithmetic must be finite")

    assignment_count = 0
    tail_count = 0
    if observed > scale_epsilon:
        all_indices = frozenset(range(month_returns))
        for selected_tuple in itertools.combinations(range(month_returns), block_size):
            selected = frozenset(selected_tuple)
            pseudo_recent = tuple(returns[index] for index in selected_tuple)
            pseudo_old = tuple(returns[index] for index in sorted(all_indices - selected))
            _, pseudo_recent_mad = mad6(pseudo_recent)
            _, pseudo_old_mad = mad6(pseudo_old)
            perm_delta = pseudo_recent_mad - pseudo_old_mad
            if not math.isfinite(perm_delta):
                raise ValueError("permuted scale difference must be finite")
            if perm_delta >= observed - compare_tolerance:
                tail_count += 1
            assignment_count += 1
        if assignment_count != 924 or not 1 <= tail_count <= 924:
            raise ValueError("incomplete exact assignment set")

    tail_fraction = tail_count / assignment_count if assignment_count else 0.0
    direction = 0
    if observed > scale_epsilon and tail_count <= tail_count_max:
        if mean_recent > direction_epsilon:
            direction = 1
        elif mean_recent < -direction_epsilon:
            direction = -1

    return PermutationScaleSignal(
        direction=direction,
        returns=returns,
        mean_old=mean_old,
        mean_recent=mean_recent,
        median_old=median_old,
        median_recent=median_recent,
        mad_old=mad_old,
        mad_recent=mad_recent,
        observed_scale_delta=observed,
        assignment_count=assignment_count,
        tail_count=tail_count,
        tail_fraction=tail_fraction,
    )


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 13 or next_month_key(endpoints[-1]) != current_month:
        return False
    return all(
        next_month_key(left) == right
        for left, right in zip(endpoints, endpoints[1:])
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


class WtiMonthlyPermutationScaleReferenceTests(unittest.TestCase):
    @staticmethod
    def qualifying_returns() -> list[float]:
        return [
            -0.002,
            -0.001,
            -0.0005,
            0.0005,
            0.001,
            0.002,
            0.004,
            0.010,
            0.015,
            0.025,
            0.030,
            0.040,
        ]

    def test_positive_and_negative_directions_are_symmetric(self) -> None:
        buy_returns = self.qualifying_returns()
        sell_returns = [-value for value in buy_returns]
        buy = permutation_scale_signal(closes_from_returns(buy_returns))
        sell = permutation_scale_signal(closes_from_returns(sell_returns))
        self.assertEqual((buy.direction, sell.direction), (1, -1))
        self.assertEqual(buy.assignment_count, 924)
        self.assertEqual(buy.tail_count, sell.tail_count)
        self.assertAlmostEqual(
            buy.observed_scale_delta,
            sell.observed_scale_delta,
            places=12,
        )
        self.assertLessEqual(buy.tail_count, TAIL_COUNT_MAX)

    def test_even_sample_median_and_mad_are_exact(self) -> None:
        values = (-5.0, -2.0, -1.0, 1.0, 4.0, 9.0)
        center, mad = mad6(values)
        self.assertEqual(center, 0.0)
        self.assertEqual(mad, 3.0)

    def test_all_924_assignments_and_observed_assignment_are_inclusive(self) -> None:
        result = permutation_scale_signal(
            closes_from_returns(self.qualifying_returns())
        )
        self.assertEqual(result.assignment_count, math.comb(12, 6))
        self.assertGreaterEqual(result.tail_count, 1)
        self.assertAlmostEqual(
            result.tail_fraction,
            result.tail_count / 924,
            places=15,
        )

    def test_nonexpansion_consumes_flat_without_enumeration(self) -> None:
        old = (-0.04, -0.03, -0.01, 0.01, 0.03, 0.04)
        recent = (-0.002, -0.001, -0.0005, 0.0005, 0.001, 0.002)
        result = permutation_scale_signal(closes_from_returns(list(old + recent)))
        self.assertLessEqual(result.observed_scale_delta, SCALE_EPSILON)
        self.assertEqual(
            (result.direction, result.assignment_count, result.tail_count),
            (0, 0, 0),
        )

    def test_recent_mean_sets_direction_only_after_scale_gate(self) -> None:
        old = [-0.002, -0.001, -0.0005, 0.0005, 0.001, 0.002]
        zero_mean_recent = [-0.04, -0.03, -0.01, 0.01, 0.03, 0.04]
        flat = permutation_scale_signal(
            closes_from_returns(old + zero_mean_recent)
        )
        shifted = permutation_scale_signal(
            closes_from_returns(old + [value + 0.001 for value in zero_mean_recent])
        )
        self.assertEqual(flat.assignment_count, 924)
        self.assertEqual(flat.direction, 0)
        self.assertEqual(shifted.direction, 1)
        self.assertEqual(flat.tail_count, shifted.tail_count)

    def test_tail_contract_is_literal_in_source(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("metrics.assignment_count != 924", source)
        self.assertIn("metrics.tail_count <= strategy_tail_count_max", source)
        self.assertIn(
            "perm_delta >= metrics.observed_scale_delta -",
            source,
        )
        self.assertNotIn("Strategy_WelchSignal", source)

    def test_invalid_endpoints_and_parameters_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            permutation_scale_signal([100.0] * 12)
        with self.assertRaises(ValueError):
            permutation_scale_signal([100.0] * 12 + [0.0])
        with self.assertRaises(ValueError):
            permutation_scale_signal([100.0] * 12 + [math.inf])
        with self.assertRaises(ValueError):
            permutation_scale_signal([100.0] * 13, block_size=5)
        with self.assertRaises(ValueError):
            permutation_scale_signal([100.0] * 13, tail_count_max=415)

    def test_thirteen_consecutive_completed_months(self) -> None:
        endpoints = [
            202507,
            202508,
            202509,
            202510,
            202511,
            202512,
            202601,
            202602,
            202603,
            202604,
            202605,
            202606,
            202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        self.assertFalse(validate_month_keys(202608, endpoints[:-1]))
        broken = endpoints.copy()
        broken[7] = 202603
        self.assertFalse(validate_month_keys(202608, broken))

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41250")
        self.assertEqual(headers["ea_slug"], "wti-mperm-scale-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41250",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "12",
            "strategy_block_size": "6",
            "strategy_scale_epsilon": "0.000000000001",
            "strategy_compare_tolerance": "0.00000000000001",
            "strategy_tail_count_max": "416",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars": "900",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_stale_days": "40",
            "strategy_max_spread_points": "1500",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

    def test_source_contract_and_card_copy(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_PermutationScaleSignal", source)
        self.assertIn("bool Strategy_MadSix", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41250", source)
        self.assertNotIn("iRSI", source)
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )

    def test_only_backtest_setfile_exists(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
