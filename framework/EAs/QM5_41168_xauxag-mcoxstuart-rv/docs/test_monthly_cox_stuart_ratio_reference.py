from __future__ import annotations

import json
import math
import re
import unittest
from dataclasses import dataclass
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
EA_SOURCE = EA_DIR / "QM5_41168_xauxag-mcoxstuart-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41168_xauxag-mcoxstuart-rv_QM5_41168_XAU_XAG_MCOXSTUART_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"


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


def signal_from_log_ratios(log_ratios: list[float]) -> PairedSignSignal:
    if len(log_ratios) != 14 or any(
        not math.isfinite(value) for value in log_ratios
    ):
        raise ValueError("exactly fourteen finite log ratios required")
    pair_signs = tuple(
        strict_sign(log_ratios[index + 7] - log_ratios[index])
        for index in range(7)
    )
    positive_count = pair_signs.count(1)
    negative_count = pair_signs.count(-1)
    tie_count = pair_signs.count(0)
    if tie_count:
        direction = 0
    elif positive_count >= 5:
        direction = -1  # SELL XAU / BUY XAG
    elif negative_count >= 5:
        direction = 1  # BUY XAU / SELL XAG
    else:
        direction = 0
    return PairedSignSignal(
        direction=direction,
        pair_signs=pair_signs,
        positive_count=positive_count,
        negative_count=negative_count,
        tie_count=tie_count,
    )


def log_ratios(xau: list[float], xag: list[float]) -> list[float]:
    if len(xau) != 14 or len(xag) != 14:
        raise ValueError("exactly fourteen synchronized closes required")
    if any(
        not math.isfinite(value) or value <= 0.0 for value in xau + xag
    ):
        raise ValueError("positive finite closes required")
    return [math.log(gold) - math.log(silver) for gold, silver in zip(xau, xag, strict=True)]


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


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
    return sum(values[start + 3] > values[start] for start in (1, 4, 7, 10))


def parse_setfile(path: Path) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";"):
            continue
        key, value = line.split("=", 1)
        parsed[key] = value
    return parsed


class MonthlyCoxStuartRatioReferenceTests(unittest.TestCase):
    def test_monotone_paths_open_exact_contrarian_sides(self) -> None:
        upward = signal_from_log_ratios([0.01 * index for index in range(14)])
        downward = signal_from_log_ratios([-0.01 * index for index in range(14)])
        self.assertEqual((upward.direction, upward.pair_signs), (-1, (1,) * 7))
        self.assertEqual((downward.direction, downward.pair_signs), (1, (-1,) * 7))

    def test_five_two_threshold_and_four_three_flat(self) -> None:
        five_two = [0, 8, 3, 7, 10, 2, 4, 6, 13, 11, 12, 9, 5, 1]
        four_three = [12, 4, 0, 3, 7, 8, 13, 2, 5, 1, 9, 6, 10, 11]
        short_ratio = signal_from_log_ratios([rank * 0.01 for rank in five_two])
        flat = signal_from_log_ratios([rank * 0.01 for rank in four_three])
        self.assertEqual(short_ratio.pair_signs, (1, 1, 1, 1, -1, 1, -1))
        self.assertEqual(
            (short_ratio.positive_count, short_ratio.negative_count, short_ratio.direction),
            (5, 2, -1),
        )
        self.assertEqual((flat.positive_count, flat.negative_count, flat.direction), (4, 3, 0))

    def test_any_tie_consumes_flat(self) -> None:
        ratios = [0.0] + [float(index) for index in range(1, 14)]
        ratios[7] = ratios[0]
        signal = signal_from_log_ratios(ratios)
        self.assertEqual((signal.tie_count, signal.positive_count, signal.direction), (1, 6, 0))

    def test_close_and_finite_guards(self) -> None:
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 13, [1.0] * 14)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 13 + [0.0], [1.0] * 14)
        with self.assertRaises(ValueError):
            signal_from_log_ratios([0.0] * 13 + [math.inf])

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
        self.assertEqual(signal_from_log_ratios(five_two).direction, -1)
        self.assertEqual(mann_kendall_score(five_two[1:]), 2)
        self.assertLess(five_two[-1], five_two[1])
        self.assertEqual(quarterly_up_count(five_two), 2)
        self.assertEqual(signal_from_log_ratios(four_three).direction, 0)
        self.assertEqual(mann_kendall_score(four_three[1:]), 30)
        self.assertGreater(four_three[-1], four_three[1])
        self.assertEqual(quarterly_up_count(four_three), 3)

    def test_density_prior_arithmetic_only(self) -> None:
        qualifying = 2 * sum(math.comb(7, count) for count in range(5, 8))
        self.assertEqual(qualifying, 58)
        self.assertAlmostEqual(12.0 * qualifying / (2**7), 5.4375)

    def test_log_ratio_orientation(self) -> None:
        xau = [100.0 * math.exp(0.01 * index) for index in range(14)]
        xag = [10.0] * 14
        signal = signal_from_log_ratios(log_ratios(xau, xag))
        self.assertEqual(signal.direction, -1)

    def test_source_manifest_and_fixed_risk_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41168",
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
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41168_XAU_XAG_MCOXSTUART_RV_D1")
        self.assertRegex(source, r"const int newer\s*=\s*pair \+ strategy_pair_count;")
        self.assertIn("if(tie_count > 0)", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertNotRegex(source, re.compile(r"iRSI|iMACD|iBands|WebRequest"))


if __name__ == "__main__":
    unittest.main()
