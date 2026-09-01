from __future__ import annotations

from collections import Counter
import itertools
import math
import statistics
from dataclasses import dataclass
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41261_wti-mab-scale-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41261_wti-mab-scale-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41261_wti-mab-scale-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"

RETURN_COUNT = 12
BLOCK_SIZE = 6
ASSIGNMENT_COUNT = 924
SCORE_MAX = 21
TAIL_COUNT_MAX = 522
DIRECTION_EPSILON = 1e-12
SYMMETRIC_SCORES = (1, 2, 3, 4, 5, 6, 6, 5, 4, 3, 2, 1)


@dataclass(frozen=True)
class Signal:
    direction: int
    symmetric_score: int
    tail_count: int
    recent_return: float
    recent_ranks: tuple[int, ...]
    pooled_tie: bool = False


def all_assignments() -> tuple[tuple[int, ...], ...]:
    return tuple(itertools.combinations(range(RETURN_COUNT), BLOCK_SIZE))


def symmetric_score(recent_ranks: tuple[int, ...]) -> int:
    if len(recent_ranks) != BLOCK_SIZE or len(set(recent_ranks)) != BLOCK_SIZE:
        raise ValueError("six unique recent ranks required")
    if any(rank < 0 or rank >= RETURN_COUNT for rank in recent_ranks):
        raise ValueError("rank outside pooled sample")
    return sum(SYMMETRIC_SCORES[rank] for rank in recent_ranks)


def exact_lower_tail_count(observed_score: int) -> int:
    return sum(
        symmetric_score(ranks) <= observed_score for ranks in all_assignments()
    )


def ansari_bradley_signal(returns: list[float]) -> Signal:
    if len(returns) != RETURN_COUNT or any(not math.isfinite(v) for v in returns):
        raise ValueError("locked finite twelve-return sample required")
    ordered = sorted(
        (value, index >= BLOCK_SIZE) for index, value in enumerate(returns)
    )
    if any(left[0] == right[0] for left, right in zip(ordered, ordered[1:])):
        return Signal(0, 0, 0, sum(returns[BLOCK_SIZE:]), (), True)
    recent_ranks = tuple(
        rank for rank, (_, is_recent) in enumerate(ordered) if is_recent
    )
    score = symmetric_score(recent_ranks)
    tail = exact_lower_tail_count(score)
    score_qualified = score <= SCORE_MAX
    tail_qualified = tail <= TAIL_COUNT_MAX
    if score_qualified != tail_qualified:
        raise ValueError("score and exact-tail boundaries disagree")
    recent_return = sum(returns[BLOCK_SIZE:])
    direction = 0
    if score_qualified and recent_return > DIRECTION_EPSILON:
        direction = 1
    elif score_qualified and recent_return < -DIRECTION_EPSILON:
        direction = -1
    return Signal(direction, score, tail, recent_return, recent_ranks)


def returns_for_recent_ranks(recent_ranks: tuple[int, ...]) -> list[float]:
    recent = set(recent_ranks)
    if len(recent) != BLOCK_SIZE:
        raise ValueError("six unique recent ranks required")
    pooled = [float(rank) - 5.5 for rank in range(RETURN_COUNT)]
    old_values = [pooled[rank] for rank in range(RETURN_COUNT) if rank not in recent]
    recent_values = [pooled[rank] for rank in range(RETURN_COUNT) if rank in recent]
    return old_values + recent_values


def block_mad(values: list[float]) -> float:
    center = statistics.median(values)
    return statistics.median(abs(value - center) for value in values)


def permutation_mad_expansion_tail(recent_ranks: tuple[int, ...]) -> tuple[float, int]:
    pooled = [float(rank) - 5.5 for rank in range(RETURN_COUNT)]

    def delta(ranks: tuple[int, ...]) -> float:
        recent = set(ranks)
        return block_mad([pooled[rank] for rank in ranks]) - block_mad(
            [pooled[rank] for rank in range(RETURN_COUNT) if rank not in recent]
        )

    observed = delta(recent_ranks)
    tail = sum(delta(ranks) >= observed for ranks in all_assignments())
    return observed, tail


def upper_half_recent_count(recent_ranks: tuple[int, ...]) -> int:
    return sum(rank >= BLOCK_SIZE for rank in recent_ranks)


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


class WtiAnsariBradleyScaleTrendReferenceTests(unittest.TestCase):
    def test_exact_assignment_score_distribution_and_lower_tail(self) -> None:
        assignments = all_assignments()
        self.assertEqual(len(assignments), ASSIGNMENT_COUNT)
        self.assertEqual(len(set(assignments)), ASSIGNMENT_COUNT)
        self.assertEqual(
            Counter(symmetric_score(ranks) for ranks in assignments),
            Counter(
                {
                    12: 1,
                    13: 4,
                    14: 9,
                    15: 20,
                    16: 34,
                    17: 56,
                    18: 75,
                    19: 96,
                    20: 107,
                    21: 120,
                    22: 107,
                    23: 96,
                    24: 75,
                    25: 56,
                    26: 34,
                    27: 20,
                    28: 9,
                    29: 4,
                    30: 1,
                }
            ),
        )
        self.assertEqual(
            {score: exact_lower_tail_count(score) for score in range(12, 31)},
            {
                12: 1,
                13: 5,
                14: 14,
                15: 34,
                16: 68,
                17: 124,
                18: 199,
                19: 295,
                20: 402,
                21: 522,
                22: 629,
                23: 725,
                24: 800,
                25: 856,
                26: 890,
                27: 910,
                28: 919,
                29: 923,
                30: 924,
            },
        )

    def test_inclusive_21_522_boundary_continues_recent_return(self) -> None:
        short_signal = ansari_bradley_signal(
            returns_for_recent_ranks((0, 1, 2, 3, 4, 5))
        )
        long_signal = ansari_bradley_signal(
            returns_for_recent_ranks((6, 7, 8, 9, 10, 11))
        )
        self.assertEqual(
            (short_signal.symmetric_score, short_signal.tail_count, short_signal.direction),
            (21, 522, -1),
        )
        self.assertEqual(
            (long_signal.symmetric_score, long_signal.tail_count, long_signal.direction),
            (21, 522, 1),
        )

    def test_score_22_and_tail_629_are_flat(self) -> None:
        signal = ansari_bradley_signal(
            returns_for_recent_ranks((0, 1, 2, 3, 5, 6))
        )
        self.assertEqual((signal.symmetric_score, signal.tail_count), (22, 629))
        self.assertEqual(signal.direction, 0)

    def test_qualified_zero_recent_return_consumes_flat(self) -> None:
        signal = ansari_bradley_signal(
            returns_for_recent_ranks((0, 1, 2, 9, 10, 11))
        )
        self.assertEqual((signal.symmetric_score, signal.tail_count), (12, 1))
        self.assertAlmostEqual(signal.recent_return, 0.0, places=15)
        self.assertEqual(signal.direction, 0)

    def test_pooled_tie_consumes_flat(self) -> None:
        returns = returns_for_recent_ranks((0, 1, 2, 3, 4, 5))
        returns[-1] = returns[0]
        tied = ansari_bradley_signal(returns)
        self.assertTrue(tied.pooled_tie)
        self.assertEqual(tied.direction, 0)

    def test_fixed_disagreement_fixtures_prove_nonduplicate_logic(self) -> None:
        mab_only = (0, 1, 2, 3, 4, 5)
        mab_signal = ansari_bradley_signal(returns_for_recent_ranks(mab_only))
        mad_delta, mad_tail = permutation_mad_expansion_tail(mab_only)
        self.assertEqual((mab_signal.symmetric_score, mab_signal.tail_count), (21, 522))
        self.assertEqual(mab_signal.direction, -1)
        self.assertEqual(mad_delta, 0.0)
        self.assertEqual(mad_tail, 584)
        self.assertGreater(mad_tail, 416)

        mad_only = (0, 1, 2, 3, 5, 6)
        mad_only_signal = ansari_bradley_signal(returns_for_recent_ranks(mad_only))
        mad_delta, mad_tail = permutation_mad_expansion_tail(mad_only)
        self.assertEqual((mad_only_signal.symmetric_score, mad_only_signal.tail_count), (22, 629))
        self.assertEqual(mad_only_signal.direction, 0)
        self.assertEqual(mad_delta, 0.5)
        self.assertEqual(mad_tail, 340)
        self.assertLessEqual(mad_tail, 416)

        median_neutral = (0, 1, 2, 6, 7, 8)
        median_neutral_signal = ansari_bradley_signal(
            returns_for_recent_ranks(median_neutral)
        )
        self.assertEqual(upper_half_recent_count(median_neutral), 3)
        self.assertEqual(
            (median_neutral_signal.symmetric_score, median_neutral_signal.tail_count),
            (21, 522),
        )
        self.assertNotEqual(median_neutral_signal.direction, 0)

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
            "bool Strategy_AnsariBradleySignal",
            "bool Strategy_SymmetricScoreForMask",
            "Strategy_ExpectedLowerTailCount",
            "perm_score <= metrics.symmetric_score",
            "metrics.assignment_count != strategy_assignment_count",
            "metrics.symmetric_score <= strategy_score_max",
            "metrics.tail_count <= strategy_tail_count_max",
            "metrics.recent_return > strategy_direction_epsilon",
            "metrics.recent_return < -strategy_direction_epsilon",
            "ordered_returns[rank] == ordered_returns[rank - 1]",
            "QM_FrameworkMagic() != 412610000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41261",
        )
        for literal in required:
            self.assertIn(literal, source)
        prepare = source[source.index("void Strategy_PrepareDecisionSignal") :]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadMonthlyEndpoints"),
        )
        for banned in (
            "iRSI",
            "iBands",
            "iMA(",
            "iMACD",
            "MathRand",
            "WebRequest",
            "FileOpen",
        ):
            self.assertNotIn(banned, source)

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41261")
        self.assertEqual(headers["ea_slug"], "wti-mab-scale-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41261",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_return_count": "12",
            "strategy_block_size": "6",
            "strategy_assignment_count": "924",
            "strategy_score_max": "21",
            "strategy_tail_count_max": "522",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars_d1": "900",
            "strategy_entry_window_minutes": "180",
            "strategy_max_endpoint_gap_days": "10",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "40",
            "strategy_max_spread_points": "1500",
            "strategy_deviation_points": "20",
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
