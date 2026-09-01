from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41273_wti-msigned-rank-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41273_wti-msigned-rank-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41273_wti-msigned-rank-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"

RETURN_COUNT = 12
TOTAL_RANK_SUM = 78
SCORE_ABS_MIN = 18
ZERO_EPSILON = 1e-12
SIGN_ASSIGNMENT_COUNT = 4096
QUALIFYING_DIRECTION_COUNT = 1062
QUALIFYING_TOTAL_COUNT = 2124


@dataclass(frozen=True)
class Signal:
    direction: int
    positive_rank_sum: int
    signed_rank_score: int
    ranks: tuple[int, ...]
    positive_return_count: int
    zero_return: bool = False
    absolute_tie: bool = False


def signed_rank_signal(returns: list[float]) -> Signal:
    if len(returns) != RETURN_COUNT or any(not math.isfinite(v) for v in returns):
        raise ValueError("locked finite twelve-return sample required")
    absolute_returns = [abs(value) for value in returns]
    if any(value <= ZERO_EPSILON for value in absolute_returns):
        return Signal(0, 0, 0, (), 0, zero_return=True)
    if any(
        abs(absolute_returns[left] - absolute_returns[right]) <= ZERO_EPSILON
        for left in range(RETURN_COUNT - 1)
        for right in range(left + 1, RETURN_COUNT)
    ):
        return Signal(0, 0, 0, (), 0, absolute_tie=True)

    ranks = tuple(
        1 + sum(other < value for other in absolute_returns)
        for value in absolute_returns
    )
    if sorted(ranks) != list(range(1, RETURN_COUNT + 1)):
        raise ValueError("strict absolute ranks are not 1..12")
    if sum(ranks) != TOTAL_RANK_SUM:
        raise ValueError("rank-sum invariant failed")

    positive_rank_sum = sum(
        rank for rank, value in zip(ranks, returns) if value > ZERO_EPSILON
    )
    positive_return_count = sum(value > ZERO_EPSILON for value in returns)
    score = 2 * positive_rank_sum - TOTAL_RANK_SUM
    if score >= SCORE_ABS_MIN:
        direction = 1
    elif score <= -SCORE_ABS_MIN:
        direction = -1
    else:
        direction = 0
    return Signal(
        direction,
        positive_rank_sum,
        score,
        ranks,
        positive_return_count,
    )


def returns_for_positive_ranks(positive_ranks: set[int]) -> list[float]:
    if any(rank < 1 or rank > RETURN_COUNT for rank in positive_ranks):
        raise ValueError("positive rank outside 1..12")
    return [
        rank / 100.0 if rank in positive_ranks else -rank / 100.0
        for rank in range(1, RETURN_COUNT + 1)
    ]


def closes_from_returns(returns: list[float], start: float = 70.0) -> list[float]:
    closes = [start]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def exact_score_distribution() -> Counter[int]:
    return Counter(
        2
        * sum(rank for rank in range(1, RETURN_COUNT + 1) if mask & (1 << (rank - 1)))
        - TOTAL_RANK_SUM
        for mask in range(SIGN_ASSIGNMENT_COUNT)
    )


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


class WtiMonthlySignedRankTrendReferenceTests(unittest.TestCase):
    def test_exact_sign_support_and_symmetry(self) -> None:
        distribution = exact_score_distribution()
        self.assertEqual(sum(distribution.values()), SIGN_ASSIGNMENT_COUNT)
        self.assertEqual((min(distribution), max(distribution)), (-78, 78))
        self.assertEqual(len(distribution), 79)
        for score, count in distribution.items():
            self.assertEqual(count, distribution[-score])
        long_count = sum(count for score, count in distribution.items() if score >= 18)
        short_count = sum(count for score, count in distribution.items() if score <= -18)
        flat_count = sum(count for score, count in distribution.items() if abs(score) < 18)
        self.assertEqual((long_count, short_count), (1062, 1062))
        self.assertEqual(long_count + short_count, QUALIFYING_TOTAL_COUNT)
        self.assertEqual(flat_count, 1972)
        self.assertEqual((distribution[18], distribution[16]), (100, 104))

    def test_inclusive_absolute_18_boundary_and_inside_flat(self) -> None:
        long_signal = signed_rank_signal(returns_for_positive_ranks({6, 9, 10, 11, 12}))
        short_signal = signed_rank_signal(returns_for_positive_ranks({1, 2, 3, 4, 8, 12}))
        inside = signed_rank_signal(returns_for_positive_ranks({5, 9, 10, 11, 12}))
        self.assertEqual(
            (long_signal.positive_rank_sum, long_signal.signed_rank_score, long_signal.direction),
            (48, 18, 1),
        )
        self.assertEqual(
            (short_signal.positive_rank_sum, short_signal.signed_rank_score, short_signal.direction),
            (30, -18, -1),
        )
        self.assertEqual(
            (inside.positive_rank_sum, inside.signed_rank_score, inside.direction),
            (47, 16, 0),
        )

    def test_zero_and_absolute_tie_consume_flat(self) -> None:
        zero = returns_for_positive_ranks({6, 9, 10, 11, 12})
        zero[0] = ZERO_EPSILON
        self.assertTrue(signed_rank_signal(zero).zero_return)
        tied = returns_for_positive_ranks({6, 9, 10, 11, 12})
        tied[1] = -abs(tied[0])
        signal = signed_rank_signal(tied)
        self.assertTrue(signal.absolute_tie)
        self.assertEqual(signal.direction, 0)

    def test_cumulative_return_disagreement_fixture(self) -> None:
        returns = [rank / 100.0 for rank in range(1, 12)] + [-1.0]
        signal = signed_rank_signal(returns)
        self.assertEqual((signal.positive_rank_sum, signal.signed_rank_score), (66, 54))
        self.assertEqual(signal.direction, 1)
        self.assertLess(sum(returns), 0.0)
        negated = signed_rank_signal([-value for value in returns])
        self.assertEqual(negated.direction, -1)
        self.assertGreater(sum(-value for value in returns), 0.0)

    def test_zero_threshold_and_sign_count_disagreement_fixtures(self) -> None:
        zero_threshold = signed_rank_signal(
            returns_for_positive_ranks({7, 10, 11, 12})
        )
        self.assertEqual(
            (zero_threshold.positive_rank_sum, zero_threshold.signed_rank_score, zero_threshold.direction),
            (40, 2, 0),
        )
        sign_count = signed_rank_signal(returns_for_positive_ranks(set(range(1, 8))))
        self.assertEqual(sign_count.positive_return_count, 7)
        self.assertEqual((sign_count.signed_rank_score, sign_count.direction), (-22, -1))

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
            "bool Strategy_SignedRankSupportValid",
            "for(int mask = 0; mask < 4096; ++mask)",
            "long_count == 1062 && short_count == 1062",
            "bool Strategy_SignedRankSignal",
            "absolute_returns[index] <= strategy_zero_epsilon",
            "MathAbs(absolute_returns[left] - absolute_returns[right]) <=",
            "2 * metrics.positive_rank_sum - metrics.total_rank_sum",
            "metrics.signed_rank_score >= strategy_score_abs_min",
            "metrics.signed_rank_score <= -strategy_score_abs_min",
            "QM_FrameworkMagic() != 412730000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41273",
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
        self.assertEqual(headers["ea_id"], "41273")
        self.assertEqual(headers["ea_slug"], "wti-msigned-rank-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41273",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_return_count": "12",
            "strategy_total_rank_sum": "78",
            "strategy_score_abs_min": "18",
            "strategy_zero_epsilon": "0.000000000001",
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
