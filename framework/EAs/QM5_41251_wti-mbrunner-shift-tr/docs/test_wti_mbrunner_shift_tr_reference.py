from __future__ import annotations

import dataclasses
import itertools
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41251_wti-mbrunner-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41251_wti-mbrunner-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41251_wti-mbrunner-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
SCORE_THRESHOLD = 0.625
DENOMINATOR_EPSILON = 1e-12
SCORE_CAP = 1_000_000.0


@dataclasses.dataclass(frozen=True)
class BrunnerMunzelSignal:
    direction: int
    mean_rank_old: float
    mean_rank_recent: float
    relative_effect: float
    placement_var_old: float
    placement_var_recent: float
    numerator: float
    denominator: float
    score: float
    saturated: bool


def closes_from_returns(returns: list[float], initial: float = 100.0) -> list[float]:
    closes = [initial]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def average_ranks(values: tuple[float, ...]) -> tuple[float, ...]:
    if not values or any(not math.isfinite(value) for value in values):
        raise ValueError("rank input must be finite and nonempty")
    ranks = tuple(
        sum(other < value for other in values)
        + (sum(other == value for other in values) + 1.0) / 2.0
        for value in values
    )
    expected = len(values) * (len(values) + 1.0) / 2.0
    if not math.isclose(sum(ranks), expected, rel_tol=0.0, abs_tol=1e-9):
        raise ValueError("average-rank checksum failed")
    return ranks


def score_from_samples(
    old: tuple[float, ...],
    recent: tuple[float, ...],
    score_threshold: float = SCORE_THRESHOLD,
    denominator_epsilon: float = DENOMINATOR_EPSILON,
    score_cap: float = SCORE_CAP,
) -> BrunnerMunzelSignal:
    if (
        len(old) != 10
        or len(recent) != 10
        or score_threshold != SCORE_THRESHOLD
        or denominator_epsilon != DENOMINATOR_EPSILON
        or score_cap != SCORE_CAP
        or any(not math.isfinite(value) for value in old + recent)
    ):
        raise ValueError("locked finite ten-by-ten samples required")

    pooled = old + recent
    old_ranks = average_ranks(old)
    recent_ranks = average_ranks(recent)
    pooled_ranks = average_ranks(pooled)
    mean_rank_old = sum(pooled_ranks[:10]) / 10.0
    mean_rank_recent = sum(pooled_ranks[10:]) / 10.0
    relative_effect = (mean_rank_recent - 5.5) / 10.0
    placement_var_old = sum(
        (pooled_ranks[index] - old_ranks[index] - mean_rank_old + 5.5) ** 2
        for index in range(10)
    ) / 9.0
    placement_var_recent = sum(
        (
            pooled_ranks[10 + index]
            - recent_ranks[index]
            - mean_rank_recent
            + 5.5
        )
        ** 2
        for index in range(10)
    ) / 9.0
    numerator = 100.0 * (mean_rank_recent - mean_rank_old) / 20.0
    denominator = math.sqrt(
        10.0 * placement_var_old + 10.0 * placement_var_recent
    )
    saturated = False
    score = 0.0
    if denominator <= denominator_epsilon:
        rank_difference = mean_rank_recent - mean_rank_old
        if rank_difference > denominator_epsilon:
            score = score_cap
            saturated = True
        elif rank_difference < -denominator_epsilon:
            score = -score_cap
            saturated = True
    else:
        score = numerator / denominator
    if not all(
        math.isfinite(value)
        for value in (
            mean_rank_old,
            mean_rank_recent,
            relative_effect,
            placement_var_old,
            placement_var_recent,
            numerator,
            denominator,
            score,
        )
    ):
        raise ValueError("Brunner-Munzel arithmetic must be finite")

    direction = 0
    if score >= score_threshold:
        direction = 1
    elif score <= -score_threshold:
        direction = -1
    return BrunnerMunzelSignal(
        direction=direction,
        mean_rank_old=mean_rank_old,
        mean_rank_recent=mean_rank_recent,
        relative_effect=relative_effect,
        placement_var_old=placement_var_old,
        placement_var_recent=placement_var_recent,
        numerator=numerator,
        denominator=denominator,
        score=score,
        saturated=saturated,
    )


def brunner_munzel_signal(
    closes: list[float],
    month_returns: int = 20,
    block_size: int = 10,
    score_threshold: float = SCORE_THRESHOLD,
    denominator_epsilon: float = DENOMINATOR_EPSILON,
    score_cap: float = SCORE_CAP,
) -> BrunnerMunzelSignal:
    if (
        month_returns != 20
        or block_size != 10
        or len(closes) != 21
        or any(not math.isfinite(value) or value <= 0.0 for value in closes)
    ):
        raise ValueError("locked positive twenty-one-close baseline required")
    returns = tuple(
        math.log(right / left) for left, right in zip(closes, closes[1:])
    )
    if len(returns) != 20 or any(not math.isfinite(value) for value in returns):
        raise ValueError("twenty finite log returns required")
    return score_from_samples(
        returns[:10],
        returns[10:],
        score_threshold,
        denominator_epsilon,
        score_cap,
    )


def score_distinct_rank_allocation(recent: tuple[int, ...]) -> float:
    if len(recent) != 10 or len(set(recent)) != 10:
        raise ValueError("ten distinct recent ranks required")
    recent_set = frozenset(recent)
    old = tuple(rank for rank in range(1, 21) if rank not in recent_set)
    recent_sorted = tuple(sorted(recent))
    mean_old = sum(old) / 10.0
    mean_recent = sum(recent_sorted) / 10.0
    var_old = sum(
        (rank - within_rank - mean_old + 5.5) ** 2
        for within_rank, rank in enumerate(old, start=1)
    ) / 9.0
    var_recent = sum(
        (rank - within_rank - mean_recent + 5.5) ** 2
        for within_rank, rank in enumerate(recent_sorted, start=1)
    ) / 9.0
    numerator = 100.0 * (mean_recent - mean_old) / 20.0
    denominator = math.sqrt(10.0 * var_old + 10.0 * var_recent)
    if denominator <= DENOMINATOR_EPSILON:
        return math.copysign(SCORE_CAP, numerator) if numerator else 0.0
    return numerator / denominator


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 21 or next_month_key(endpoints[-1]) != current_month:
        return False
    return all(
        next_month_key(left) == right
        for left, right in zip(endpoints, endpoints[1:])
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


class WtiMonthlyBrunnerMunzelReferenceTests(unittest.TestCase):
    def test_complete_separation_has_finite_symmetric_limit(self) -> None:
        buy = score_from_samples(tuple(range(1, 11)), tuple(range(11, 21)))
        sell = score_from_samples(tuple(range(11, 21)), tuple(range(1, 11)))
        self.assertEqual((buy.direction, sell.direction), (1, -1))
        self.assertEqual((buy.score, sell.score), (SCORE_CAP, -SCORE_CAP))
        self.assertTrue(buy.saturated and sell.saturated)
        self.assertEqual((buy.denominator, sell.denominator), (0.0, 0.0))

    def test_exact_average_ties_and_identical_samples_are_flat(self) -> None:
        self.assertEqual(average_ranks((1.0, 2.0, 2.0, 4.0)), (1.0, 2.5, 2.5, 4.0))
        flat = score_from_samples((1.0,) * 10, (1.0,) * 10)
        self.assertEqual((flat.direction, flat.score, flat.denominator), (0, 0.0, 0.0))
        self.assertFalse(flat.saturated)

    def test_equal_mann_whitney_u_can_cross_studentized_boundary(self) -> None:
        recent_flat = (1, 2, 3, 4, 5, 6, 17, 18, 19, 20)
        recent_sell = (1, 2, 3, 4, 5, 7, 16, 18, 19, 20)
        old_flat = tuple(rank for rank in range(1, 21) if rank not in recent_flat)
        old_sell = tuple(rank for rank in range(1, 21) if rank not in recent_sell)
        u_flat = sum(recent_flat) - 55
        u_sell = sum(recent_sell) - 55
        flat = score_from_samples(old_flat, recent_flat)
        sell = score_from_samples(old_sell, recent_sell)
        self.assertEqual((u_flat, u_sell), (40, 40))
        self.assertAlmostEqual(flat.score, -0.6123724356957945, places=14)
        self.assertAlmostEqual(sell.score, -0.6338656910463875, places=14)
        self.assertEqual((flat.direction, sell.direction), (0, -1))

    def test_log_return_orientation_preserves_positive_shift(self) -> None:
        returns = [value / 1000.0 for value in range(1, 21)]
        signal = brunner_munzel_signal(closes_from_returns(returns))
        self.assertEqual(signal.direction, 1)
        self.assertGreater(signal.mean_rank_recent, signal.mean_rank_old)
        self.assertGreater(signal.relative_effect, 0.5)

    def test_exact_threshold_density_matches_predata_receipt(self) -> None:
        qualifying = 0
        allocations = 0
        for recent in itertools.combinations(range(1, 21), 10):
            score = score_distinct_rank_allocation(recent)
            qualifying += abs(score) >= SCORE_THRESHOLD
            allocations += 1
        self.assertEqual(allocations, math.comb(20, 10))
        self.assertEqual((qualifying, allocations), (97_078, 184_756))

    def test_inclusive_threshold_and_rank_formula_are_literal_in_source(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("metrics.score >= strategy_score_threshold", source)
        self.assertIn("metrics.score <= -strategy_score_threshold", source)
        self.assertIn("else if(values[other] == values[index])", source)
        self.assertIn("const int variance_denominator = strategy_block_size - 1", source)
        self.assertNotIn("Strategy_WelchSignal", source)

    def test_invalid_endpoints_and_parameters_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            brunner_munzel_signal([100.0] * 20)
        with self.assertRaises(ValueError):
            brunner_munzel_signal([100.0] * 20 + [0.0])
        with self.assertRaises(ValueError):
            brunner_munzel_signal([100.0] * 20 + [math.inf])
        with self.assertRaises(ValueError):
            brunner_munzel_signal([100.0] * 21, block_size=9)
        with self.assertRaises(ValueError):
            score_from_samples(tuple(range(9)), tuple(range(10)))
        with self.assertRaises(ValueError):
            score_from_samples(tuple(range(10)), tuple(range(10)), score_threshold=0.624)

    def test_twenty_one_consecutive_completed_months(self) -> None:
        endpoints = [202411, 202412]
        endpoints.extend(202500 + month for month in range(1, 13))
        endpoints.extend(202600 + month for month in range(1, 8))
        self.assertEqual(len(endpoints), 21)
        self.assertTrue(validate_month_keys(202608, endpoints))
        self.assertFalse(validate_month_keys(202608, endpoints[:-1]))
        broken = endpoints.copy()
        broken[7] = broken[6]
        self.assertFalse(validate_month_keys(202608, broken))

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41251")
        self.assertEqual(headers["ea_slug"], "wti-mbrunner-shift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41251",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "20",
            "strategy_block_size": "10",
            "strategy_score_threshold": "0.625",
            "strategy_denominator_epsilon": "0.000000000001",
            "strategy_score_cap": "1000000.0",
            "strategy_history_bars": "1200",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_stale_days": "40",
            "strategy_max_spread_points": "1500",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

    def test_source_contract_and_card_copy(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_BrunnerMunzelSignal", source)
        self.assertIn("bool Strategy_AverageRanks", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41251", source)
        self.assertNotIn("iRSI", source)
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
