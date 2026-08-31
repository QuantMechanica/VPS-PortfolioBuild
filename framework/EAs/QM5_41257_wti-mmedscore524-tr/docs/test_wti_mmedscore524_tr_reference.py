from __future__ import annotations

from collections import Counter
import itertools
import math
from dataclasses import dataclass
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41257_wti-mmedscore524-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41257_wti-mmedscore524-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41257_wti-mmedscore524-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"

RETURN_COUNT = 12
BLOCK_SIZE = 6
ASSIGNMENT_COUNT = 924
TAIL_COUNT_MAX = 524
LONG_MIN = 4
SHORT_MAX = 2


@dataclass(frozen=True)
class Signal:
    direction: int
    recent_high_count: int
    tail_count: int
    recent_ranks: tuple[int, ...]
    pooled_tie: bool = False


def all_assignments() -> tuple[tuple[int, ...], ...]:
    return tuple(itertools.combinations(range(RETURN_COUNT), BLOCK_SIZE))


def recent_high_count(recent_ranks: tuple[int, ...]) -> int:
    if len(recent_ranks) != BLOCK_SIZE or len(set(recent_ranks)) != BLOCK_SIZE:
        raise ValueError("six unique recent ranks required")
    if any(rank < 0 or rank >= RETURN_COUNT for rank in recent_ranks):
        raise ValueError("rank outside pooled sample")
    return sum(rank >= BLOCK_SIZE for rank in recent_ranks)


def exact_tail_count(observed_high_count: int) -> int:
    if observed_high_count < 0 or observed_high_count > BLOCK_SIZE:
        raise ValueError("invalid upper-half count")
    observed_distance = abs(observed_high_count - BLOCK_SIZE // 2)
    return sum(
        abs(recent_high_count(ranks) - BLOCK_SIZE // 2) >= observed_distance
        for ranks in all_assignments()
    )


def median_score_signal(returns: list[float]) -> Signal:
    if len(returns) != RETURN_COUNT or any(not math.isfinite(v) for v in returns):
        raise ValueError("locked finite twelve-return sample required")
    ordered = sorted((value, index >= BLOCK_SIZE) for index, value in enumerate(returns))
    if any(left[0] == right[0] for left, right in zip(ordered, ordered[1:])):
        return Signal(0, 0, 0, (), True)
    recent_ranks = tuple(
        rank for rank, (_, is_recent) in enumerate(ordered) if is_recent
    )
    high_count = recent_high_count(recent_ranks)
    tail = exact_tail_count(high_count)
    qualified_by_tail = tail <= TAIL_COUNT_MAX
    qualified_by_count = high_count >= LONG_MIN or high_count <= SHORT_MAX
    if qualified_by_tail != qualified_by_count:
        raise ValueError("tail and count boundaries disagree")
    direction = 1 if high_count >= LONG_MIN else -1 if high_count <= SHORT_MAX else 0
    return Signal(direction, high_count, tail, recent_ranks)


def returns_for_recent_ranks(recent_ranks: tuple[int, ...]) -> list[float]:
    recent = set(recent_ranks)
    if len(recent) != BLOCK_SIZE:
        raise ValueError("six unique recent ranks required")
    old_values = [float(rank) for rank in range(RETURN_COUNT) if rank not in recent]
    recent_values = [float(rank) for rank in range(RETURN_COUNT) if rank in recent]
    return old_values + recent_values


def integrated_path_score(recent_ranks: tuple[int, ...]) -> int:
    recent = set(recent_ranks)
    old_seen = recent_seen = score = 0
    for rank in range(RETURN_COUNT):
        if rank in recent:
            recent_seen += 1
        else:
            old_seen += 1
        score += (old_seen - recent_seen) ** 2
    return score


def closes_from_returns(returns: list[float], start: float = 70.0) -> list[float]:
    closes = [start]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


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


class WtiMedianScore524ReferenceTests(unittest.TestCase):
    def test_exact_assignment_distribution_and_tail_mapping(self) -> None:
        assignments = all_assignments()
        self.assertEqual(len(assignments), ASSIGNMENT_COUNT)
        self.assertEqual(len(set(assignments)), ASSIGNMENT_COUNT)
        self.assertEqual(
            Counter(recent_high_count(ranks) for ranks in assignments),
            Counter({0: 1, 1: 36, 2: 225, 3: 400, 4: 225, 5: 36, 6: 1}),
        )
        self.assertEqual(
            {high: exact_tail_count(high) for high in range(BLOCK_SIZE + 1)},
            {0: 2, 1: 74, 2: 524, 3: 924, 4: 524, 5: 74, 6: 2},
        )

    def test_every_count_has_locked_symmetric_direction(self) -> None:
        expected_direction = {0: -1, 1: -1, 2: -1, 3: 0, 4: 1, 5: 1, 6: 1}
        for high_count in range(BLOCK_SIZE + 1):
            low_needed = BLOCK_SIZE - high_count
            ranks = tuple(range(low_needed)) + tuple(
                range(BLOCK_SIZE, BLOCK_SIZE + high_count)
            )
            signal = median_score_signal(returns_for_recent_ranks(ranks))
            self.assertEqual(signal.recent_high_count, high_count)
            self.assertEqual(signal.direction, expected_direction[high_count])
            self.assertEqual(signal.tail_count, exact_tail_count(high_count))

    def test_internal_rank_path_and_rank_sum_are_not_the_signal(self) -> None:
        first = (0, 1, 6, 7, 8, 9)
        second = (0, 1, 6, 7, 8, 10)
        first_signal = median_score_signal(returns_for_recent_ranks(first))
        second_signal = median_score_signal(returns_for_recent_ranks(second))
        self.assertEqual(
            (first_signal.recent_high_count, first_signal.tail_count, first_signal.direction),
            (4, 524, 1),
        )
        self.assertEqual(
            (second_signal.recent_high_count, second_signal.tail_count, second_signal.direction),
            (4, 524, 1),
        )
        self.assertNotEqual(integrated_path_score(first), integrated_path_score(second))
        self.assertNotEqual(sum(first), sum(second))

    def test_pooled_tie_consumes_flat(self) -> None:
        returns = returns_for_recent_ranks((0, 1, 8, 9, 10, 11))
        returns[-1] = returns[0]
        tied = median_score_signal(returns)
        self.assertTrue(tied.pooled_tie)
        self.assertEqual(tied.direction, 0)

    def test_close_return_orientation_is_chronological(self) -> None:
        returns = [-0.03, 0.02, -0.01, 0.04, -0.02, 0.01] * 2
        closes = closes_from_returns(returns)
        recovered = [
            math.log(closes[index + 1] / closes[index])
            for index in range(RETURN_COUNT)
        ]
        for actual, expected in zip(recovered, returns):
            self.assertAlmostEqual(actual, expected, places=14)

    def test_source_contains_literal_formula_and_attempt_order(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        required = (
            "bool Strategy_MedianScoreSignal",
            "bool Strategy_RecentHighCountForMask",
            "rank = strategy_block_size",
            "perm_distance >= metrics.neutral_distance",
            "metrics.assignment_count != strategy_assignment_count",
            "metrics.tail_count <= strategy_tail_count_max",
            "metrics.recent_high_count >= strategy_recent_high_long_min",
            "metrics.recent_high_count <= strategy_recent_high_short_max",
            "ordered_returns[rank] == ordered_returns[rank - 1]",
            "QM_FrameworkMagic() != 412570000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41257",
        )
        for literal in required:
            self.assertIn(literal, source)
        prepare = source[source.index("void Strategy_PrepareDecisionSignal") :]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadMonthlyEndpoints"),
        )
        for banned in ("iRSI", "iBands", "iMA(", "MathRand"):
            self.assertNotIn(banned, source)

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41257")
        self.assertEqual(headers["ea_slug"], "wti-mmedscore524-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41257",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "12",
            "strategy_block_size": "6",
            "strategy_assignment_count": "924",
            "strategy_tail_count_max": "524",
            "strategy_recent_high_long_min": "4",
            "strategy_recent_high_short_max": "2",
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

    def test_card_copy_and_only_backtest_set_exist(self) -> None:
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
