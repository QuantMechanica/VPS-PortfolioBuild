from __future__ import annotations

import dataclasses
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41171_wti-mturnpoint-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41171_wti-mturnpoint-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41171_wti-mturnpoint-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"


@dataclasses.dataclass(frozen=True)
class TurningPointSignal:
    direction: int
    turning_points: int
    comparison_lhs: int
    null_mean_numerator: int


def turning_point_signal(
    closes: list[float], max_turning_points: int = 7
) -> TurningPointSignal:
    if len(closes) != 13 or max_turning_points != 7:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")
    if len(set(closes)) != len(closes):
        raise ValueError("ties fail closed")

    turning_points = sum(
        (
            closes[index - 1] < closes[index] > closes[index + 1]
            or closes[index - 1] > closes[index] < closes[index + 1]
        )
        for index in range(1, len(closes) - 1)
    )
    if not 0 <= turning_points <= 11:
        raise AssertionError("turning-point invariant broken")

    comparison_lhs = 3 * turning_points
    null_mean_numerator = 22
    below_null_mean = comparison_lhs < null_mean_numerator
    if below_null_mean != (turning_points <= max_turning_points):
        raise AssertionError("integer boundary equivalence broken")

    direction = 0
    if below_null_mean:
        direction = 1 if closes[-1] > closes[0] else -1
    return TurningPointSignal(
        direction=direction,
        turning_points=turning_points,
        comparison_lhs=comparison_lhs,
        null_mean_numerator=null_mean_numerator,
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


def bartels_numerator(values: list[float]) -> int:
    ordered = sorted(values)
    ranks = [ordered.index(value) + 1 for value in values]
    return sum((right - left) ** 2 for left, right in zip(ranks, ranks[1:]))


def mann_kendall_score(values: list[float]) -> int:
    return sum(
        (values[right] > values[left]) - (values[right] < values[left])
        for left in range(len(values))
        for right in range(left + 1, len(values))
    )


def foster_stuart_difference(values: list[float]) -> int:
    high = low = values[0]
    upper = lower = 0
    for value in values[1:]:
        if value > high:
            upper += 1
            high = value
        elif value < low:
            lower += 1
            low = value
    return upper - lower


def longest_return_runs(values: list[float]) -> tuple[int, int]:
    positive_best = negative_best = 0
    positive_now = negative_now = 0
    for left, right in zip(values, values[1:]):
        if right > left:
            positive_now += 1
            negative_now = 0
        else:
            negative_now += 1
            positive_now = 0
        positive_best = max(positive_best, positive_now)
        negative_best = max(negative_best, negative_now)
    return positive_best, negative_best


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


class MonthlyTurningPointReferenceTests(unittest.TestCase):
    def test_monotone_vectors_qualify_symmetrically(self) -> None:
        upward = turning_point_signal([float(value) for value in range(1, 14)])
        downward = turning_point_signal([float(value) for value in range(13, 0, -1)])
        self.assertEqual((upward.direction, upward.turning_points), (1, 0))
        self.assertEqual((downward.direction, downward.turning_points), (-1, 0))
        self.assertEqual(upward.null_mean_numerator, 22)
        self.assertEqual(downward.null_mean_numerator, 22)

    def test_strict_boundary_seven_qualifies_eight_is_flat(self) -> None:
        at_seven = [1, 13, 2, 12, 3, 11, 4, 10, 9, 8, 7, 6, 5]
        at_eight = [1, 13, 2, 12, 3, 11, 4, 10, 5, 6, 7, 8, 9]
        signal_seven = turning_point_signal([float(value) for value in at_seven])
        signal_eight = turning_point_signal([float(value) for value in at_eight])
        self.assertEqual(
            (signal_seven.turning_points, signal_seven.comparison_lhs, signal_seven.direction),
            (7, 21, 1),
        )
        self.assertEqual(
            (signal_eight.turning_points, signal_eight.comparison_lhs, signal_eight.direction),
            (8, 24, 0),
        )

    def test_alternating_path_has_eleven_turns_and_is_flat(self) -> None:
        alternating = [1, 13, 2, 12, 3, 11, 4, 10, 5, 9, 6, 8, 7]
        signal = turning_point_signal([float(value) for value in alternating])
        self.assertEqual((signal.turning_points, signal.direction), (11, 0))

    def test_ties_and_invalid_values_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            turning_point_signal([1.0] * 13)
        with self.assertRaises(ValueError):
            turning_point_signal([float(value) for value in range(1, 13)] + [0.0])
        with self.assertRaises(ValueError):
            turning_point_signal([float(value) for value in range(1, 13)] + [math.inf])
        with self.assertRaises(ValueError):
            turning_point_signal([float(value) for value in range(1, 14)], 8)

    def test_locked_nonduplicate_fixtures(self) -> None:
        candidate_buy = [8, 4, 1, 7, 9, 10, 3, 12, 6, 0, 5, 2, 11]
        values_buy = [float(value + 1) for value in candidate_buy]
        signal_buy = turning_point_signal(values_buy)
        self.assertEqual((signal_buy.turning_points, signal_buy.direction), (7, 1))
        self.assertEqual(bartels_numerator(values_buy), 383)
        self.assertEqual(mann_kendall_score(values_buy), 0)
        self.assertEqual(foster_stuart_difference(values_buy), 0)
        self.assertEqual(longest_return_runs(values_buy), (3, 2))

        candidate_flat = [5, 1, 6, 2, 0, 8, 3, 7, 12, 4, 11, 9, 10]
        values_flat = [float(value + 1) for value in candidate_flat]
        signal_flat = turning_point_signal(values_flat)
        self.assertEqual((signal_flat.turning_points, signal_flat.direction), (9, 0))
        self.assertEqual(bartels_numerator(values_flat), 309)
        self.assertEqual(mann_kendall_score(values_flat), 36)

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
        self.assertEqual(headers["ea_id"], "41171")
        self.assertEqual(headers["ea_slug"], "wti-mturnpoint-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41171",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_max_turning_points": "7",
            "strategy_history_bars_d1": "900",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "40",
            "strategy_max_spread_points": "1500",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

    def test_source_contract_and_card_copy(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_TurningPointSignal", source)
        self.assertIn("metrics.comparison_lhs = 3 * metrics.turning_points", source)
        self.assertIn("metrics.comparison_lhs < metrics.null_mean_numerator", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41171", source)
        self.assertNotIn("strategy_nm_boundary", source)
        self.assertNotIn("Strategy_BartelsRankSignal", source)
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
