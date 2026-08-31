from __future__ import annotations

import itertools
import math
from dataclasses import dataclass
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41255_wti-mcvm-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41255_wti-mcvm-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41255_wti-mcvm-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"

RETURN_COUNT = 12
BLOCK_SIZE = 6
ASSIGNMENT_COUNT = 924
TAIL_COUNT_MAX = 460
SCORE_MIN = 22
DIRECTION_EPSILON = 1e-12


@dataclass(frozen=True)
class Signal:
    direction: int
    observed_score: int
    tail_count: int
    recent_ranks: tuple[int, ...]
    median_old: float
    median_recent: float
    pooled_tie: bool = False


def path_score(recent_ranks: tuple[int, ...]) -> int:
    if len(recent_ranks) != BLOCK_SIZE or len(set(recent_ranks)) != BLOCK_SIZE:
        raise ValueError("six unique recent ranks required")
    recent = set(recent_ranks)
    if any(rank < 0 or rank >= RETURN_COUNT for rank in recent):
        raise ValueError("rank outside pooled sample")
    old_seen = 0
    recent_seen = 0
    score = 0
    for rank in range(RETURN_COUNT):
        if rank in recent:
            recent_seen += 1
        else:
            old_seen += 1
        score += (old_seen - recent_seen) ** 2
    if old_seen != BLOCK_SIZE or recent_seen != BLOCK_SIZE:
        raise ValueError("six/six membership required")
    return score


def all_assignments() -> tuple[tuple[int, ...], ...]:
    return tuple(itertools.combinations(range(RETURN_COUNT), BLOCK_SIZE))


def tail_count(observed_score: int) -> int:
    return sum(path_score(ranks) >= observed_score for ranks in all_assignments())


def median6(values: list[float]) -> float:
    if len(values) != BLOCK_SIZE or any(not math.isfinite(v) for v in values):
        raise ValueError("six finite values required")
    ordered = sorted(values)
    return (ordered[2] + ordered[3]) / 2.0


def mad6(values: list[float]) -> float:
    center = median6(values)
    return median6([abs(value - center) for value in values])


def scale_permutation_tail(returns: list[float]) -> tuple[float, int]:
    if len(returns) != RETURN_COUNT:
        raise ValueError("twelve returns required")
    observed = mad6(returns[6:]) - mad6(returns[:6])
    tail = 0
    for recent_indices in all_assignments():
        recent_set = set(recent_indices)
        recent = [returns[index] for index in recent_indices]
        old = [
            returns[index]
            for index in range(RETURN_COUNT)
            if index not in recent_set
        ]
        if mad6(recent) - mad6(old) >= observed - 1e-14:
            tail += 1
    return observed, tail


def integrated_ecdf_signal(returns: list[float]) -> Signal:
    if len(returns) != RETURN_COUNT or any(not math.isfinite(v) for v in returns):
        raise ValueError("locked finite twelve-return sample required")
    ordered = sorted((value, index >= BLOCK_SIZE) for index, value in enumerate(returns))
    if any(left[0] == right[0] for left, right in zip(ordered, ordered[1:])):
        return Signal(0, 0, 0, (), median6(returns[:6]), median6(returns[6:]), True)
    recent_ranks = tuple(
        rank for rank, (_, is_recent) in enumerate(ordered) if is_recent
    )
    score = path_score(recent_ranks)
    tail = tail_count(score)
    if (tail <= TAIL_COUNT_MAX) != (score >= SCORE_MIN):
        raise ValueError("tail and score boundaries disagree")
    old_median = median6(returns[:6])
    recent_median = median6(returns[6:])
    delta = recent_median - old_median
    direction = 0
    if tail <= TAIL_COUNT_MAX:
        if delta > DIRECTION_EPSILON:
            direction = 1
        elif delta < -DIRECTION_EPSILON:
            direction = -1
    return Signal(direction, score, tail, recent_ranks, old_median, recent_median)


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


class WtiMcvmShiftReferenceTests(unittest.TestCase):
    def test_exact_assignment_distribution_and_locked_boundary(self) -> None:
        assignments = all_assignments()
        self.assertEqual(len(assignments), ASSIGNMENT_COUNT)
        self.assertEqual(len(set(assignments)), ASSIGNMENT_COUNT)
        self.assertEqual(tail_count(22), 460)
        self.assertEqual(tail_count(18), 540)
        for ranks in assignments:
            score = path_score(ranks)
            self.assertEqual(tail_count(score) <= TAIL_COUNT_MAX, score >= SCORE_MIN)

    def test_location_shift_direction_is_symmetric(self) -> None:
        old = [-0.03, -0.025, -0.02, -0.015, -0.01, -0.005]
        recent = [0.005, 0.01, 0.015, 0.02, 0.025, 0.03]
        buy = integrated_ecdf_signal(old + recent)
        sell = integrated_ecdf_signal(recent + old)
        self.assertEqual((buy.direction, sell.direction), (1, -1))
        self.assertEqual((buy.observed_score, sell.observed_score), (146, 146))
        self.assertEqual((buy.tail_count, sell.tail_count), (2, 2))

    def test_interleaved_path_and_pooled_tie_consume_flat(self) -> None:
        old = [0.0, 2.0, 4.0, 6.0, 8.0, 10.0]
        recent = [1.0, 3.0, 5.0, 7.0, 9.0, 11.0]
        interleaved = integrated_ecdf_signal(old + recent)
        self.assertEqual((interleaved.direction, interleaved.observed_score), (0, 6))
        self.assertEqual(interleaved.tail_count, 924)
        tied = integrated_ecdf_signal(old + [1.0, 3.0, 5.0, 7.0, 9.0, 10.0])
        self.assertTrue(tied.pooled_tie)
        self.assertEqual(tied.direction, 0)

    def test_mad_scale_neighbor_is_separated_both_ways(self) -> None:
        base = [-3.0, -2.0, -1.0, 1.0, 2.0, 3.0]
        shifted = base + [value + 10.0 for value in base]
        location_signal = integrated_ecdf_signal(shifted)
        self.assertEqual(location_signal.direction, 1)
        self.assertEqual(mad6(shifted[6:]) - mad6(shifted[:6]), 0.0)

        scale = base + [-30.0, -20.0, -10.0, 10.0, 20.0, 30.0]
        scale_signal = integrated_ecdf_signal(scale)
        scale_delta, scale_tail = scale_permutation_tail(scale)
        self.assertEqual(scale_signal.direction, 0)
        self.assertGreater(scale_delta, 0.0)
        self.assertLessEqual(scale_tail, 416)

    def test_same_rank_sum_and_signed_maxima_can_cross_score_boundary(self) -> None:
        low = (0, 1, 4, 7, 10, 11)
        high = (0, 1, 3, 8, 10, 11)
        self.assertEqual(sum(low), sum(high))

        def signed_maxima(ranks: tuple[int, ...]) -> tuple[int, int]:
            old_seen = recent_seen = plus = minus = 0
            recent = set(ranks)
            for rank in range(RETURN_COUNT):
                if rank in recent:
                    recent_seen += 1
                else:
                    old_seen += 1
                delta = old_seen - recent_seen
                plus = max(plus, delta)
                minus = max(minus, -delta)
            return plus, minus

        self.assertEqual(signed_maxima(low), signed_maxima(high))
        self.assertEqual((path_score(low), path_score(high)), (14, 22))

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
            "bool Strategy_IntegratedEcdfSignal",
            "score += delta * delta",
            "Strategy_Popcount12(mask) != strategy_block_size",
            "if(perm_score >= metrics.observed_score)",
            "metrics.assignment_count != strategy_assignment_count",
            "metrics.tail_count <= strategy_tail_count_max",
            "metrics.observed_score >= strategy_score_min",
            "metrics.median_delta > strategy_direction_epsilon",
            "ordered_returns[rank] == ordered_returns[rank - 1]",
            "QM_FrameworkMagic() != 412550000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41255",
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
        self.assertEqual(headers["ea_id"], "41255")
        self.assertEqual(headers["ea_slug"], "wti-mcvm-shift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41255",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "12",
            "strategy_block_size": "6",
            "strategy_assignment_count": "924",
            "strategy_tail_count_max": "460",
            "strategy_score_min": "22",
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
