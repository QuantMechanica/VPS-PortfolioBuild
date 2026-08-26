from __future__ import annotations

import collections
import math
import re
import unittest
from dataclasses import dataclass
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
EA_SOURCE = EA_DIR / "QM5_41169_wti-foster-record-tr.mq5"
SET_FILE = (
    EA_DIR
    / "sets"
    / "QM5_41169_wti-foster-record-tr_XTIUSD.DWX_D1_backtest.set"
)


@dataclass(frozen=True)
class RecordSignal:
    direction: int
    upper_count: int
    lower_count: int
    neutral_count: int
    record_difference: int


def record_signal(closes: list[float], threshold: int = 2) -> RecordSignal:
    if len(closes) != 13 or any(
        not math.isfinite(value) or value <= 0.0 for value in closes
    ):
        raise ValueError("exactly thirteen positive finite closes required")
    if threshold != 2:
        raise ValueError("the approved threshold is locked at two")

    running_high = closes[0]
    running_low = closes[0]
    upper_count = 0
    lower_count = 0
    neutral_count = 0
    for value in closes[1:]:
        if value > running_high:
            upper_count += 1
            running_high = value
        elif value < running_low:
            lower_count += 1
            running_low = value
        else:
            neutral_count += 1

    if upper_count + lower_count + neutral_count != 12:
        raise AssertionError("record classification must conserve all comparisons")
    difference = upper_count - lower_count
    direction = 1 if difference >= 2 else -1 if difference <= -2 else 0
    return RecordSignal(
        direction=direction,
        upper_count=upper_count,
        lower_count=lower_count,
        neutral_count=neutral_count,
        record_difference=difference,
    )


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    if month == 12:
        return (year + 1) * 100 + 1
    return year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 13:
        return False
    if any(
        next_month_key(left) != right
        for left, right in zip(endpoints[:-1], endpoints[1:], strict=True)
    ):
        return False
    return next_month_key(endpoints[-1]) == current_month


def strict_sign(value: float) -> int:
    return 1 if value > 0.0 else -1 if value < 0.0 else 0


def mann_kendall_score(values: list[float]) -> int:
    return sum(
        strict_sign(values[newer] - values[older])
        for older in range(len(values) - 1)
        for newer in range(older + 1, len(values))
    )


def cox_stuart_counts(values: list[float]) -> tuple[int, int]:
    signs = [strict_sign(values[index + 7] - values[index]) for index in range(7)]
    return signs.count(1), signs.count(-1)


def quarterly_up_count(values: list[float]) -> int:
    return sum(values[start + 3] > values[start] for start in (1, 4, 7, 10))


def ols_centered_numerator(values: list[float]) -> float:
    return sum(
        (2 * index - (len(values) - 1)) * value
        for index, value in enumerate(values)
    )


def exact_distinct_rank_distribution(n: int) -> collections.Counter[int]:
    """Count forward-record differences over all n! rank permutations."""
    if n < 1:
        raise ValueError("positive rank count required")
    states = [collections.Counter() for _ in range(1 << n)]
    for rank in range(n):
        states[1 << rank][0] = 1
    all_bits = (1 << n) - 1
    for mask in range(1, all_bits):
        if not states[mask]:
            continue
        low = (mask & -mask).bit_length() - 1
        high = mask.bit_length() - 1
        remaining = all_bits ^ mask
        while remaining:
            bit = remaining & -remaining
            rank = bit.bit_length() - 1
            delta = 1 if rank > high else -1 if rank < low else 0
            for difference, ways in states[mask].items():
                states[mask | bit][difference + delta] += ways
            remaining ^= bit
    return states[all_bits]


def parse_setfile(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    values: dict[str, str] = {}
    headers: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith(";"):
            match = re.match(r";\s*([a-z_]+):\s*(\S+)", line)
            if match:
                headers[match.group(1)] = match.group(2)
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values, headers


class MonthlyFosterStuartRecordReferenceTests(unittest.TestCase):
    def test_monotone_directions_and_count_conservation(self) -> None:
        upward = record_signal([float(index) for index in range(1, 14)])
        downward = record_signal([float(index) for index in range(13, 0, -1)])
        self.assertEqual(upward, RecordSignal(1, 12, 0, 0, 12))
        self.assertEqual(downward, RecordSignal(-1, 0, 12, 0, -12))

    def test_strict_records_and_equality_is_neutral(self) -> None:
        closes = [
            10.0, 12.0, 12.0, 8.0, 11.0, 8.0, 13.0,
            9.0, 7.0, 7.0, 12.0, 6.0, 10.0,
        ]
        signal = record_signal(closes)
        self.assertEqual(signal.upper_count, 2)
        self.assertEqual(signal.lower_count, 3)
        self.assertEqual(signal.neutral_count, 7)
        self.assertEqual(signal.record_difference, -1)
        self.assertEqual(signal.direction, 0)

    def test_absolute_two_threshold_is_symmetric(self) -> None:
        path = [5, 6, 4, 7, 3, 5, 8, 4, 7, 5, 6, 4, 9]
        buy = record_signal(path)
        sell = record_signal([-value + 20 for value in path])
        self.assertEqual(
            (buy.upper_count, buy.lower_count, buy.record_difference),
            (4, 2, 2),
        )
        self.assertEqual((buy.direction, sell.direction), (1, -1))
        self.assertEqual(sell.record_difference, -2)

    def test_positive_close_finite_length_and_threshold_guards(self) -> None:
        with self.assertRaises(ValueError):
            record_signal([1.0] * 12)
        with self.assertRaises(ValueError):
            record_signal([1.0] * 12 + [0.0])
        with self.assertRaises(ValueError):
            record_signal([1.0] * 12 + [math.inf])
        with self.assertRaises(ValueError):
            record_signal([1.0] * 13, threshold=1)

    def test_month_sequence_and_year_rollover(self) -> None:
        endpoints = [
            202412, 202501, 202502, 202503, 202504, 202505, 202506,
            202507, 202508, 202509, 202510, 202511, 202512,
        ]
        self.assertTrue(validate_month_keys(202601, endpoints))
        broken = endpoints.copy()
        broken[7] = 202508
        self.assertFalse(validate_month_keys(202601, broken))
        self.assertFalse(validate_month_keys(202512, endpoints))

    def test_locked_functional_separation_vectors(self) -> None:
        vector_a = [1, 8, 2, 6, 9, 10, 4, 12, 5, 13, 11, 0, 3, 7]
        vector_b = [1, 2, 0, 7, 4, 3, 13, 10, 9, 8, 11, 6, 5, 12]

        candidate_a = record_signal([float(value + 1) for value in vector_a[1:]])
        self.assertEqual(
            (candidate_a.upper_count, candidate_a.lower_count, candidate_a.record_difference),
            (4, 2, 2),
        )
        self.assertEqual(candidate_a.direction, 1)
        self.assertLess(vector_a[-1], vector_a[1])
        self.assertEqual(mann_kendall_score(vector_a[1:]), 2)
        self.assertEqual(cox_stuart_counts(vector_a), (4, 3))
        self.assertEqual(quarterly_up_count(vector_a), 2)
        self.assertLess(ols_centered_numerator(vector_a[1:]), 0)

        candidate_b = record_signal([float(value + 1) for value in vector_b[1:]])
        self.assertEqual(
            (candidate_b.upper_count, candidate_b.lower_count, candidate_b.record_difference),
            (2, 1, 1),
        )
        self.assertEqual(candidate_b.direction, 0)
        self.assertGreater(vector_b[-1], vector_b[1])
        self.assertEqual(mann_kendall_score(vector_b[1:]), 28)
        self.assertEqual(cox_stuart_counts(vector_b), (6, 1))
        self.assertEqual(quarterly_up_count(vector_b), 4)
        self.assertGreater(ols_centered_numerator(vector_b[1:]), 0)

    def test_exact_thirteen_rank_density_prior(self) -> None:
        distribution = exact_distinct_rank_distribution(13)
        total = sum(distribution.values())
        qualifying = sum(
            ways
            for difference, ways in distribution.items()
            if abs(difference) >= 2
        )
        self.assertEqual(total, math.factorial(13))
        self.assertEqual(qualifying, 2_963_909_390)
        self.assertAlmostEqual(qualifying / total, 0.475975508224, places=12)
        self.assertAlmostEqual(12.0 * qualifying / total, 5.7117060987, places=10)

    def test_source_and_fixed_risk_setfile_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values, headers = parse_setfile(SET_FILE)
        expected = {
            "qm_ea_id": "41169",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_record_threshold": "2",
            "strategy_history_bars_d1": "900",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "40",
            "strategy_max_spread_points": "1500",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertEqual(headers["environment"], "backtest")
        self.assertTrue(
            headers["build_hash"] == "PENDING_COMPILE"
            or re.fullmatch(r"[0-9a-f]{64}", headers["build_hash"])
        )
        self.assertIn("if(value > running_high)", source)
        self.assertIn("else if(value < running_low)", source)
        self.assertIn(
            "metrics.neutral_count != strategy_endpoint_count - 1", source
        )
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertNotIn("MathLog", source)
        self.assertNotIn("strategy_pair_count", source)
        self.assertNotRegex(
            source, re.compile(r"iRSI|iMACD|iBands|WebRequest|FileOpen")
        )


if __name__ == "__main__":
    unittest.main()
