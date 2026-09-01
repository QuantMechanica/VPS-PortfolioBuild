from __future__ import annotations

from collections import Counter
from functools import lru_cache
import itertools
import math
from dataclasses import dataclass
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41271_wti-msiegel-tukey-scale-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41271_wti-msiegel-tukey-scale-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41271_wti-msiegel-tukey-scale-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"

RETURN_COUNT = 16
BLOCK_SIZE = 8
ASSIGNMENT_COUNT = 12870
SCORE_MAX = 68
TAIL_COUNT_MAX = 6698
DIRECTION_EPSILON = 1e-12
SIEGEL_TUKEY_SCORES = (
    1,
    4,
    5,
    8,
    9,
    12,
    13,
    16,
    15,
    14,
    11,
    10,
    7,
    6,
    3,
    2,
)
ANSARI_BRADLEY_SCORES = (1, 2, 3, 4, 5, 6, 6, 5, 4, 3, 2, 1)


@dataclass(frozen=True)
class Signal:
    direction: int
    siegel_tukey_score: int
    tail_count: int
    recent_return: float
    recent_ranks: tuple[int, ...]
    pooled_tie: bool = False


def nist_alternating_extremes_scores(size: int = RETURN_COUNT) -> tuple[int, ...]:
    if size != 16:
        raise ValueError("locked sixteen-observation construction required")
    # NIST order: smallest, largest, next-largest, second-smallest; repeat.
    rank_positions = (0, 15, 14, 1, 2, 13, 12, 3, 4, 11, 10, 5, 6, 9, 8, 7)
    scores = [0] * size
    for score, rank_position in enumerate(rank_positions, start=1):
        scores[rank_position] = score
    return tuple(scores)


@lru_cache(maxsize=1)
def all_assignments() -> tuple[tuple[int, ...], ...]:
    return tuple(itertools.combinations(range(RETURN_COUNT), BLOCK_SIZE))


def siegel_tukey_score(recent_ranks: tuple[int, ...]) -> int:
    if len(recent_ranks) != BLOCK_SIZE or len(set(recent_ranks)) != BLOCK_SIZE:
        raise ValueError("eight unique recent ranks required")
    if any(rank < 0 or rank >= RETURN_COUNT for rank in recent_ranks):
        raise ValueError("rank outside pooled sample")
    return sum(SIEGEL_TUKEY_SCORES[rank] for rank in recent_ranks)


@lru_cache(maxsize=None)
def exact_lower_tail_count(observed_score: int) -> int:
    return sum(
        siegel_tukey_score(ranks) <= observed_score
        for ranks in all_assignments()
    )


def siegel_tukey_signal(returns: list[float]) -> Signal:
    if len(returns) != RETURN_COUNT or any(not math.isfinite(v) for v in returns):
        raise ValueError("locked finite sixteen-return sample required")
    ordered = sorted(
        (value, index >= BLOCK_SIZE) for index, value in enumerate(returns)
    )
    recent_return = sum(returns[BLOCK_SIZE:])
    if any(left[0] == right[0] for left, right in zip(ordered, ordered[1:])):
        return Signal(0, 0, 0, recent_return, (), True)
    recent_ranks = tuple(
        rank for rank, (_, is_recent) in enumerate(ordered) if is_recent
    )
    score = siegel_tukey_score(recent_ranks)
    tail = exact_lower_tail_count(score)
    score_qualified = score <= SCORE_MAX
    tail_qualified = tail <= TAIL_COUNT_MAX
    if score_qualified != tail_qualified:
        raise ValueError("score and exact-tail boundaries disagree")
    direction = 0
    if score_qualified and recent_return > DIRECTION_EPSILON:
        direction = 1
    elif score_qualified and recent_return < -DIRECTION_EPSILON:
        direction = -1
    return Signal(direction, score, tail, recent_return, recent_ranks)


def returns_for_recent_ranks(recent_ranks: tuple[int, ...]) -> list[float]:
    recent = set(recent_ranks)
    if len(recent) != BLOCK_SIZE:
        raise ValueError("eight unique recent ranks required")
    pooled = [float(rank) - 7.5 for rank in range(RETURN_COUNT)]
    old_values = [pooled[rank] for rank in range(RETURN_COUNT) if rank not in recent]
    recent_values = [pooled[rank] for rank in range(RETURN_COUNT) if rank in recent]
    return old_values + recent_values


def existing_ansari_bradley_score_on_latest_twelve(returns: list[float]) -> int:
    latest = returns[-12:]
    ordered = sorted((value, index >= 6) for index, value in enumerate(latest))
    if any(left[0] == right[0] for left, right in zip(ordered, ordered[1:])):
        raise ValueError("fixture must remain distinct")
    return sum(
        ANSARI_BRADLEY_SCORES[rank]
        for rank, (_, is_recent) in enumerate(ordered)
        if is_recent
    )


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


class WtiSiegelTukeyScaleTrendReferenceTests(unittest.TestCase):
    def test_nist_algorithm_produces_locked_score_path(self) -> None:
        self.assertEqual(nist_alternating_extremes_scores(), SIEGEL_TUKEY_SCORES)
        self.assertEqual(sorted(SIEGEL_TUKEY_SCORES), list(range(1, 17)))
        self.assertEqual(sum(SIEGEL_TUKEY_SCORES), 136)

    def test_exact_assignment_distribution_and_half_support_boundary(self) -> None:
        assignments = all_assignments()
        self.assertEqual(len(assignments), ASSIGNMENT_COUNT)
        self.assertEqual(len(set(assignments)), ASSIGNMENT_COUNT)
        distribution = Counter(siegel_tukey_score(ranks) for ranks in assignments)
        self.assertEqual(sum(distribution.values()), ASSIGNMENT_COUNT)
        self.assertEqual((min(distribution), max(distribution)), (36, 100))
        self.assertEqual(distribution[68], 526)
        for score, count in distribution.items():
            self.assertEqual(count, distribution[136 - score])
        self.assertEqual(exact_lower_tail_count(67), 6172)
        self.assertEqual(exact_lower_tail_count(68), TAIL_COUNT_MAX)
        self.assertEqual(exact_lower_tail_count(69), 7217)
        for ranks in assignments:
            score = siegel_tukey_score(ranks)
            self.assertEqual(
                score <= SCORE_MAX,
                exact_lower_tail_count(score) <= TAIL_COUNT_MAX,
            )

    def test_inclusive_68_6698_boundary_continues_recent_return(self) -> None:
        short_signal = siegel_tukey_signal(
            returns_for_recent_ranks((0, 1, 2, 3, 4, 5, 6, 7))
        )
        long_signal = siegel_tukey_signal(
            returns_for_recent_ranks((0, 1, 7, 8, 9, 11, 13, 15))
        )
        self.assertEqual(
            (short_signal.siegel_tukey_score, short_signal.tail_count, short_signal.direction),
            (68, 6698, -1),
        )
        self.assertEqual(
            (long_signal.siegel_tukey_score, long_signal.tail_count, long_signal.direction),
            (68, 6698, 1),
        )

    def test_score_69_and_tail_7217_are_flat(self) -> None:
        signal = siegel_tukey_signal(
            returns_for_recent_ranks((0, 1, 2, 3, 4, 5, 7, 9))
        )
        self.assertEqual((signal.siegel_tukey_score, signal.tail_count), (69, 7217))
        self.assertEqual(signal.direction, 0)

    def test_qualified_zero_recent_return_and_tie_consume_flat(self) -> None:
        returns = returns_for_recent_ranks((0, 1, 2, 3, 12, 13, 14, 15))
        neutral = siegel_tukey_signal(returns)
        self.assertEqual((neutral.siegel_tukey_score, neutral.tail_count), (36, 1))
        self.assertAlmostEqual(neutral.recent_return, 0.0, places=15)
        self.assertEqual(neutral.direction, 0)
        returns[-1] = returns[0]
        tied = siegel_tukey_signal(returns)
        self.assertTrue(tied.pooled_tie)
        self.assertEqual(tied.direction, 0)

    def test_fixed_fixtures_prove_ansari_bradley_disagreement_both_ways(self) -> None:
        st_only_ranks = (7, 6, 1, 8, 14, 9, 5, 15, 2, 12, 3, 11, 4, 10, 16, 13)
        st_only = [float(rank) - 8.5 for rank in st_only_ranks]
        signal = siegel_tukey_signal(st_only)
        self.assertEqual((signal.siegel_tukey_score, signal.direction), (61, 1))
        self.assertEqual(existing_ansari_bradley_score_on_latest_twelve(st_only), 22)

        ab_only_ranks = (15, 14, 7, 3, 5, 10, 1, 11, 12, 6, 13, 8, 4, 2, 16, 9)
        ab_only = [float(rank) - 8.5 for rank in ab_only_ranks]
        signal = siegel_tukey_signal(ab_only)
        self.assertEqual((signal.siegel_tukey_score, signal.direction), (74, 0))
        self.assertEqual(existing_ansari_bradley_score_on_latest_twelve(ab_only), 20)
        self.assertGreater(sum(ab_only[8:]), DIRECTION_EPSILON)
        self.assertGreater(sum(ab_only[-6:]), DIRECTION_EPSILON)

    def test_close_return_orientation_is_chronological(self) -> None:
        returns = [-0.03, 0.02, -0.01, 0.04, -0.02, 0.01, -0.04, 0.03] * 2
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
            "bool Strategy_SiegelTukeySignal",
            "bool Strategy_SiegelTukeyScoreForMask",
            "int Strategy_SiegelTukeyScoreForRank",
            "for(int mask = 0; mask < 65536; ++mask)",
            "perm_score <= metrics.siegel_tukey_score",
            "metrics.assignment_count != strategy_assignment_count",
            "metrics.siegel_tukey_score <= strategy_score_max",
            "metrics.tail_count <= strategy_tail_count_max",
            "metrics.recent_return > strategy_direction_epsilon",
            "metrics.recent_return < -strategy_direction_epsilon",
            "ordered_returns[rank] == ordered_returns[rank - 1]",
            "QM_FrameworkMagic() != 412710000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41271",
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
        self.assertEqual(headers["ea_id"], "41271")
        self.assertEqual(headers["ea_slug"], "wti-msiegel-tukey-scale-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41271",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "17",
            "strategy_return_count": "16",
            "strategy_block_size": "8",
            "strategy_assignment_count": "12870",
            "strategy_score_max": "68",
            "strategy_tail_count_max": "6698",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars_d1": "1200",
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
