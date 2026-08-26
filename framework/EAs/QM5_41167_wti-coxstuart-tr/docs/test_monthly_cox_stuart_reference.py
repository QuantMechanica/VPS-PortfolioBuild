from __future__ import annotations

import math
import re
import unittest
from dataclasses import dataclass
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
EA_SOURCE = EA_DIR / "QM5_41167_wti-coxstuart-tr.mq5"
SET_FILE = EA_DIR / "sets" / "QM5_41167_wti-coxstuart-tr_XTIUSD.DWX_D1_backtest.set"


@dataclass(frozen=True)
class PairedSignSignal:
    direction: int
    pair_signs: tuple[int, ...]
    positive_count: int
    negative_count: int
    tie_count: int


def strict_sign(value: float) -> int:
    if not math.isfinite(value):
        raise ValueError("finite difference required")
    return 1 if value > 0.0 else -1 if value < 0.0 else 0


def signal_from_logs(log_prices: list[float]) -> PairedSignSignal:
    if len(log_prices) != 14 or any(
        not math.isfinite(value) for value in log_prices
    ):
        raise ValueError("exactly fourteen finite log prices required")
    pair_signs = tuple(
        strict_sign(log_prices[index + 7] - log_prices[index])
        for index in range(7)
    )
    positive_count = pair_signs.count(1)
    negative_count = pair_signs.count(-1)
    tie_count = pair_signs.count(0)
    if tie_count:
        direction = 0
    elif positive_count >= 5:
        direction = 1
    elif negative_count >= 5:
        direction = -1
    else:
        direction = 0
    return PairedSignSignal(
        direction=direction,
        pair_signs=pair_signs,
        positive_count=positive_count,
        negative_count=negative_count,
        tie_count=tie_count,
    )


def signal_from_closes(closes: list[float]) -> PairedSignSignal:
    if len(closes) != 14 or any(
        not math.isfinite(value) or value <= 0.0 for value in closes
    ):
        raise ValueError("exactly fourteen positive finite closes required")
    return signal_from_logs([math.log(value) for value in closes])


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    if month == 12:
        return (year + 1) * 100 + 1
    return year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 14:
        return False
    if any(
        next_month_key(left) != right
        for left, right in zip(endpoints[:-1], endpoints[1:], strict=True)
    ):
        return False
    return next_month_key(endpoints[-1]) == current_month


def mann_kendall_score(values: list[float]) -> int:
    return sum(
        strict_sign(values[newer] - values[older])
        for older in range(len(values) - 1)
        for newer in range(older + 1, len(values))
    )


def quarterly_up_count(values: list[float]) -> int:
    return sum(
        values[start + 3] > values[start]
        for start in (1, 4, 7, 10)
    )


def parse_setfile(path: Path) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";"):
            continue
        key, value = line.split("=", 1)
        parsed[key] = value
    return parsed


class MonthlyCoxStuartReferenceTests(unittest.TestCase):
    def test_monotone_directions_and_exact_pairs(self) -> None:
        upward = signal_from_logs([0.01 * index for index in range(14)])
        downward = signal_from_logs([-0.01 * index for index in range(14)])
        self.assertEqual(upward.direction, 1)
        self.assertEqual(upward.pair_signs, (1,) * 7)
        self.assertEqual(downward.direction, -1)
        self.assertEqual(downward.pair_signs, (-1,) * 7)

    def test_five_two_threshold_and_four_three_flat(self) -> None:
        five_two = [0, 8, 3, 7, 10, 2, 4, 6, 13, 11, 12, 9, 5, 1]
        four_three = [12, 4, 0, 3, 7, 8, 13, 2, 5, 1, 9, 6, 10, 11]
        buy = signal_from_logs([rank * 0.01 for rank in five_two])
        flat = signal_from_logs([rank * 0.01 for rank in four_three])
        self.assertEqual(buy.pair_signs, (1, 1, 1, 1, -1, 1, -1))
        self.assertEqual((buy.positive_count, buy.negative_count, buy.direction), (5, 2, 1))
        self.assertEqual(flat.pair_signs, (-1, 1, 1, 1, -1, 1, -1))
        self.assertEqual((flat.positive_count, flat.negative_count, flat.direction), (4, 3, 0))

    def test_any_tie_consumes_flat(self) -> None:
        logs = [0.0] + [float(index) for index in range(1, 14)]
        logs[7] = logs[0]
        signal = signal_from_logs(logs)
        self.assertEqual(signal.tie_count, 1)
        self.assertEqual(signal.positive_count, 6)
        self.assertEqual(signal.direction, 0)

    def test_positive_close_and_finite_guards(self) -> None:
        with self.assertRaises(ValueError):
            signal_from_closes([1.0] * 13)
        with self.assertRaises(ValueError):
            signal_from_closes([1.0] * 13 + [0.0])
        with self.assertRaises(ValueError):
            signal_from_logs([0.0] * 13 + [math.inf])

    def test_month_sequence_and_year_rollover(self) -> None:
        endpoints = [
            202411, 202412, 202501, 202502, 202503, 202504, 202505,
            202506, 202507, 202508, 202509, 202510, 202511, 202512,
        ]
        self.assertTrue(validate_month_keys(202601, endpoints))
        broken = endpoints.copy()
        broken[7] = 202507
        self.assertFalse(validate_month_keys(202601, broken))
        self.assertFalse(validate_month_keys(202512, endpoints))

    def test_locked_functional_separation_vectors(self) -> None:
        five_two = [0, 8, 3, 7, 10, 2, 4, 6, 13, 11, 12, 9, 5, 1]
        four_three = [12, 4, 0, 3, 7, 8, 13, 2, 5, 1, 9, 6, 10, 11]
        self.assertEqual(signal_from_logs(five_two).direction, 1)
        self.assertEqual(mann_kendall_score(five_two[1:]), 2)
        self.assertLess(five_two[-1], five_two[1])
        self.assertEqual(quarterly_up_count(five_two), 2)
        self.assertEqual(signal_from_logs(four_three).direction, 0)
        self.assertEqual(mann_kendall_score(four_three[1:]), 30)
        self.assertGreater(four_three[-1], four_three[1])
        self.assertEqual(quarterly_up_count(four_three), 3)

    def test_density_prior_arithmetic_only(self) -> None:
        qualifying = 2 * sum(math.comb(7, count) for count in range(5, 8))
        self.assertEqual(qualifying, 58)
        self.assertAlmostEqual(12.0 * qualifying / (2**7), 5.4375)

    def test_source_and_fixed_risk_setfile_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values = parse_setfile(SET_FILE)
        expected = {
            "qm_ea_id": "41167",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "14",
            "strategy_pair_count": "7",
            "strategy_signs_required": "5",
            "strategy_history_bars_d1": "900",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertRegex(source, r"const int newer\s*=\s*pair \+ strategy_pair_count;")
        self.assertIn("metrics.tie_count > 0", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertNotRegex(source, re.compile(r"iRSI|iMACD|iBands|WebRequest"))


if __name__ == "__main__":
    unittest.main()
