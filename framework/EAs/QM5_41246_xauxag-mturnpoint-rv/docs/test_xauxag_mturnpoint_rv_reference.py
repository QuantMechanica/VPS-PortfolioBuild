from __future__ import annotations

import json
import math
import re
import unittest
from dataclasses import dataclass
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41246_xauxag-mturnpoint-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41246_xauxag-mturnpoint-rv_QM5_41246_XAU_XAG_MTURNPOINT_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41246_xauxag-mturnpoint-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"


@dataclass(frozen=True)
class TurningPointSignal:
    direction: int
    turning_points: int
    displacement: float


def turning_point_signal(
    values: list[float],
    maximum: int = 7,
    epsilon: float = 1.0e-12,
) -> TurningPointSignal:
    if len(values) != 13 or maximum != 7 or epsilon != 1.0e-12:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) for value in values):
        raise ValueError("finite log ratios required")
    if any(
        abs(values[right] - values[left]) <= epsilon
        for left in range(len(values) - 1)
        for right in range(left + 1, len(values))
    ):
        raise ValueError("pairwise ratio ties consume flat")
    turning_points = sum(
        (values[index - 1] < values[index] > values[index + 1])
        or (values[index - 1] > values[index] < values[index + 1])
        for index in range(1, len(values) - 1)
    )
    if not 0 <= turning_points <= 11:
        raise AssertionError("turning-point invariant broken")
    displacement = values[-1] - values[0]
    direction = 0
    if turning_points <= maximum and 3 * turning_points < 22:
        direction = -1 if displacement > epsilon else 1 if displacement < -epsilon else 0
    return TurningPointSignal(direction, turning_points, displacement)


def log_ratios(xau: list[float], xag: list[float]) -> list[float]:
    if len(xau) != 13 or len(xag) != 13:
        raise ValueError("exactly thirteen synchronized closes required")
    if any(not math.isfinite(value) or value <= 0.0 for value in xau + xag):
        raise ValueError("positive finite closes required")
    return [
        math.log(gold) - math.log(silver)
        for gold, silver in zip(xau, xag, strict=True)
    ]


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    return (
        len(endpoints) == 13
        and next_month_key(endpoints[-1]) == current_month
        and all(
            next_month_key(left) == right
            for left, right in zip(endpoints[:-1], endpoints[1:], strict=True)
        )
    )


def cumulative_path(increments: list[float]) -> list[float]:
    values = [0.0]
    for increment in increments:
        values.append(values[-1] + increment)
    return values


def parse_setfile(path: Path) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";"):
            continue
        key, value = line.split("=", 1)
        parsed[key] = value
    return parsed


class MonthlyTurningPointRatioReferenceTests(unittest.TestCase):
    def test_monotone_paths_open_exact_contrarian_sides(self) -> None:
        upward = turning_point_signal([float(value) for value in range(1, 14)])
        downward = turning_point_signal([float(value) for value in range(13, 0, -1)])
        self.assertEqual((upward.direction, upward.turning_points), (-1, 0))
        self.assertEqual((downward.direction, downward.turning_points), (1, 0))

    def test_integer_boundary_separates_seven_from_eight(self) -> None:
        seven = cumulative_path([1, -2, 3, -4, 5, -6, 7, -8, -9, -10, -11, -12])
        eight = cumulative_path([1, -2, 3, -4, 5, -6, 7, -8, 9, 10, 11, 12])
        seven_signal = turning_point_signal(seven)
        eight_signal = turning_point_signal(eight)
        self.assertEqual((seven_signal.turning_points, seven_signal.direction), (7, 1))
        self.assertEqual((eight_signal.turning_points, eight_signal.direction), (8, 0))
        self.assertLess(3 * seven_signal.turning_points, 22)
        self.assertGreaterEqual(3 * eight_signal.turning_points, 22)

    def test_maximum_alternation_is_flat(self) -> None:
        alternating = [0.0, 20.0, 1.0, 19.0, 2.0, 18.0, 3.0,
                       17.0, 4.0, 16.0, 5.0, 15.0, 6.0]
        result = turning_point_signal(alternating)
        self.assertEqual((result.turning_points, result.direction), (11, 0))

    def test_ties_and_invalid_values_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            turning_point_signal([1.0] * 13)
        near_tie = [float(value) for value in range(13)]
        near_tie[-1] = near_tie[0] + 1.0e-12
        with self.assertRaises(ValueError):
            turning_point_signal(near_tie)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 12 + [0.0], [1.0] * 13)
        with self.assertRaises(ValueError):
            turning_point_signal([float(value) for value in range(12)] + [math.inf])

    def test_ratio_orientation_and_month_sequence(self) -> None:
        xau = [100.0 * math.exp(0.01 * index) for index in range(13)]
        xag = [10.0] * 13
        self.assertEqual(turning_point_signal(log_ratios(xau, xag)).direction, -1)
        endpoints = [
            202507, 202508, 202509, 202510, 202511, 202512, 202601,
            202602, 202603, 202604, 202605, 202606, 202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        endpoints[7] = 202603
        self.assertFalse(validate_month_keys(202608, endpoints))

    def test_source_manifest_set_and_card_copy_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41246",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_max_turning_points": "7",
            "strategy_ratio_tie_epsilon": "0.000000000001",
            "strategy_history_bars_d1": "900",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41246_XAU_XAG_MTURNPOINT_RV_D1")
        self.assertIn("++turning_point_count", source)
        self.assertIn("3 * turning_point_count < 22", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertIn("Strategy_RefreshExpectedDirection()", source)
        self.assertIn("Strategy_PairCompositionValid(direction)", source)
        self.assertIn("Strategy_PairCompositionValid(g_pair_expected_direction)", source)
        self.assertNotRegex(source, re.compile(r"iRSI|iMACD|iBands|WebRequest"))
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )

    def test_only_factory_and_logical_fixed_risk_backtest_sets_exist(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertIn(LOGICAL_SET, setfiles)
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))
        for path in setfiles:
            values = parse_setfile(path)
            self.assertEqual(
                (values["RISK_FIXED"], values["RISK_PERCENT"]),
                ("1000", "0"),
            )


if __name__ == "__main__":
    unittest.main()
