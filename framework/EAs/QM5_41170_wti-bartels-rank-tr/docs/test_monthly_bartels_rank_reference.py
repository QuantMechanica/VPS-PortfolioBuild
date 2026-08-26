from __future__ import annotations

import dataclasses
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41170_wti-bartels-rank-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41170_wti-bartels-rank-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41170_wti-bartels-rank-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"


@dataclasses.dataclass(frozen=True)
class BartelsSignal:
    direction: int
    ranks: tuple[int, ...]
    rank_sum: int
    denominator: int
    numerator: int
    rvn: float


def bartels_signal(
    closes: list[float], nm_boundary: int = 364
) -> BartelsSignal:
    if len(closes) != 13 or nm_boundary != 364:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")
    if len(set(closes)) != len(closes):
        raise ValueError("ties fail closed")

    ordered = sorted(closes)
    ranks = tuple(ordered.index(value) + 1 for value in closes)
    if sorted(ranks) != list(range(1, 14)):
        raise AssertionError("rank permutation broken")
    rank_sum = sum(ranks)
    denominator = sum((rank - 7) ** 2 for rank in ranks)
    numerator = sum((right - left) ** 2 for left, right in zip(ranks, ranks[1:]))
    if rank_sum != 91 or denominator != 182 or numerator <= 0:
        raise AssertionError("Bartels invariant broken")

    direction = 0
    if numerator < nm_boundary:
        direction = 1 if closes[-1] > closes[0] else -1
    return BartelsSignal(
        direction=direction,
        ranks=ranks,
        rank_sum=rank_sum,
        denominator=denominator,
        numerator=numerator,
        rvn=numerator / denominator,
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


class MonthlyBartelsRankReferenceTests(unittest.TestCase):
    def test_monotone_vectors_qualify_symmetrically(self) -> None:
        upward = bartels_signal([float(value) for value in range(1, 14)])
        downward = bartels_signal([float(value) for value in range(13, 0, -1)])
        self.assertEqual((upward.direction, upward.numerator), (1, 12))
        self.assertEqual((downward.direction, downward.numerator), (-1, 12))
        self.assertEqual(upward.denominator, 182)
        self.assertEqual(downward.denominator, 182)

    def test_strict_boundary_363_qualifies_364_is_flat(self) -> None:
        at_363 = [10, 4, 2, 5, 6, 8, 12, 1, 7, 11, 9, 13, 3]
        at_364 = [1, 3, 8, 10, 2, 12, 9, 7, 6, 4, 11, 5, 13]
        signal_363 = bartels_signal([float(value) for value in at_363])
        signal_364 = bartels_signal([float(value) for value in at_364])
        self.assertEqual((signal_363.numerator, signal_363.direction), (363, -1))
        self.assertEqual((signal_364.numerator, signal_364.direction), (364, 0))

    def test_ties_and_invalid_values_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            bartels_signal([1.0] * 13)
        with self.assertRaises(ValueError):
            bartels_signal([float(value) for value in range(1, 13)] + [0.0])
        with self.assertRaises(ValueError):
            bartels_signal([float(value) for value in range(1, 13)] + [math.inf])
        with self.assertRaises(ValueError):
            bartels_signal([float(value) for value in range(1, 14)], 365)

    def test_locked_nonduplicate_fixtures(self) -> None:
        bartels_buy = [2, 3, 10, 5, 6, 12, 11, 4, 1, 0, 9, 8, 7]
        values_buy = [float(value + 1) for value in bartels_buy]
        candidate_buy = bartels_signal(values_buy)
        self.assertEqual((candidate_buy.numerator, candidate_buy.direction), (255, 1))
        self.assertEqual(mann_kendall_score(values_buy), 4)
        self.assertEqual(foster_stuart_difference(values_buy), 1)

        bartels_flat = [2, 5, 7, 0, 9, 3, 4, 12, 1, 10, 6, 8, 11]
        values_flat = [float(value + 1) for value in bartels_flat]
        candidate_flat = bartels_signal(values_flat)
        self.assertEqual((candidate_flat.numerator, candidate_flat.direction), (475, 0))
        self.assertEqual(mann_kendall_score(values_flat), 28)
        self.assertEqual(foster_stuart_difference(values_flat), 3)

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
        broken[6] = 202601
        broken[7] = 202603
        self.assertFalse(validate_month_keys(202608, broken))

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41170")
        self.assertEqual(headers["ea_slug"], "wti-bartels-rank-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41170",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_nm_boundary": "364",
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
        self.assertIn("bool Strategy_BartelsRankSignal", source)
        self.assertIn("metrics.rank_denominator != 182", source)
        self.assertIn("metrics.rank_numerator < strategy_nm_boundary", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41170", source)
        self.assertNotIn("strategy_record_threshold", source)
        self.assertNotIn("Strategy_FosterStuartRecordSignal", source)
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

