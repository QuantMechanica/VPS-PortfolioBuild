from __future__ import annotations

from dataclasses import dataclass
from itertools import combinations
import math
import re
from statistics import NormalDist, median
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41266_wti-mfk-scale-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41266_wti-mfk-scale-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41266_wti-mfk-scale-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"

RETURN_COUNT = 12
BLOCK_SIZE = 6
SCORE_TABLE_SIZE = 23
RELATIVE_EPSILON = 1e-12
MIN_SCORE_VARIANCE = 1e-18
RANK2_SCORE = {
    rank2: NormalDist().inv_cdf(0.5 + (rank2 / 2.0) / 26.0)
    for rank2 in range(2, 25)
}

FK_ONLY_RETURNS = (
    6.75,
    -4.25,
    0.5,
    5.0,
    7.5,
    4.5,
    -3.0,
    -3.25,
    6.25,
    -6.25,
    2.5,
    -2.75,
)
NEIGHBOR_ONLY_RETURNS = (
    5.25,
    -1.75,
    -6.75,
    3.5,
    -4.5,
    7.5,
    6.25,
    4.25,
    -6.25,
    0.25,
    7.75,
    -2.0,
)


@dataclass(frozen=True)
class Signal:
    direction: int
    median_old: float
    median_recent: float
    deviations: tuple[float, ...]
    rank2: tuple[int, ...]
    scores: tuple[float, ...]
    score_mean_old: float
    score_mean_recent: float
    score_mean_all: float
    score_variance: float
    statistic_x2: float
    recent_return: float
    tie_run_count: int
    recent_scale_expanding: bool


def median6(values: tuple[float, ...] | list[float]) -> float:
    if len(values) != BLOCK_SIZE or any(not math.isfinite(v) for v in values):
        raise ValueError("six finite values required")
    ordered = sorted(values)
    return 0.5 * ordered[2] + 0.5 * ordered[3]


def anchored_midranks(
    values: tuple[float, ...] | list[float],
) -> tuple[tuple[int, ...], int]:
    if len(values) != RETURN_COUNT:
        raise ValueError("twelve pooled deviations required")
    if any(not math.isfinite(v) or v < 0.0 for v in values):
        raise ValueError("finite nonnegative deviations required")

    ordered = sorted((value, index) for index, value in enumerate(values))
    rank2: list[int | None] = [None] * RETURN_COUNT
    run_start = 0
    tie_run_count = 0
    while run_start < RETURN_COUNT:
        anchor = ordered[run_start][0]
        run_end = run_start
        while run_end + 1 < RETURN_COUNT:
            candidate = ordered[run_end + 1][0]
            tolerance = RELATIVE_EPSILON * max(
                1.0, abs(anchor), abs(candidate)
            )
            if abs(candidate - anchor) > tolerance:
                break
            run_end += 1
        run_rank2 = run_start + run_end + 2
        for position in range(run_start, run_end + 1):
            original_index = ordered[position][1]
            if rank2[original_index] is not None:
                raise ValueError("duplicate midrank assignment")
            rank2[original_index] = run_rank2
        tie_run_count += 1
        run_start = run_end + 1

    if any(value is None for value in rank2):
        raise ValueError("incomplete midrank assignment")
    locked_rank2 = tuple(int(value) for value in rank2)
    if sum(locked_rank2) != 156:
        raise ValueError("pooled rank sum must be 78")
    return locked_rank2, tie_run_count


def fligner_killeen_signal(
    returns: tuple[float, ...] | list[float],
) -> Signal:
    if len(returns) != RETURN_COUNT or any(
        not math.isfinite(value) for value in returns
    ):
        raise ValueError("locked finite twelve-return sample required")

    old = tuple(returns[:BLOCK_SIZE])
    recent = tuple(returns[BLOCK_SIZE:])
    median_old = median6(old)
    median_recent = median6(recent)
    deviations = tuple(abs(value - median_old) for value in old) + tuple(
        abs(value - median_recent) for value in recent
    )
    rank2, tie_run_count = anchored_midranks(deviations)
    scores = tuple(RANK2_SCORE[value] for value in rank2)
    score_mean_old = sum(scores[:BLOCK_SIZE]) / BLOCK_SIZE
    score_mean_recent = sum(scores[BLOCK_SIZE:]) / BLOCK_SIZE
    score_mean_all = sum(scores) / RETURN_COUNT
    score_variance = (
        sum((score - score_mean_all) ** 2 for score in scores) / 11.0
    )
    if not math.isfinite(score_variance) or score_variance <= MIN_SCORE_VARIANCE:
        raise ValueError("degenerate pooled score variance")
    statistic_x2 = (
        6.0
        * (
            (score_mean_old - score_mean_all) ** 2
            + (score_mean_recent - score_mean_all) ** 2
        )
        / score_variance
    )
    if not math.isfinite(statistic_x2) or statistic_x2 < 0.0:
        raise ValueError("invalid Fligner-Killeen statistic")

    scale_tolerance = RELATIVE_EPSILON * max(
        1.0, abs(score_mean_old), abs(score_mean_recent)
    )
    recent_scale_expanding = (
        score_mean_recent > score_mean_old + scale_tolerance
    )
    recent_return = sum(recent)
    direction = 0
    if recent_scale_expanding and recent_return > RELATIVE_EPSILON:
        direction = 1
    elif recent_scale_expanding and recent_return < -RELATIVE_EPSILON:
        direction = -1
    return Signal(
        direction,
        median_old,
        median_recent,
        deviations,
        rank2,
        scores,
        score_mean_old,
        score_mean_recent,
        score_mean_all,
        score_variance,
        statistic_x2,
        recent_return,
        tie_run_count,
        recent_scale_expanding,
    )


def ansari_bradley_state(
    returns: tuple[float, ...] | list[float],
) -> tuple[int, int]:
    ordered = sorted((value, index >= BLOCK_SIZE) for index, value in enumerate(returns))
    if any(left[0] == right[0] for left, right in zip(ordered, ordered[1:])):
        return 0, 0
    weights = (1, 2, 3, 4, 5, 6, 6, 5, 4, 3, 2, 1)
    score = sum(weight for weight, (_, recent) in zip(weights, ordered) if recent)
    recent_return = sum(returns[BLOCK_SIZE:])
    direction = 0
    if score <= 21 and recent_return > RELATIVE_EPSILON:
        direction = 1
    elif score <= 21 and recent_return < -RELATIVE_EPSILON:
        direction = -1
    return score, direction


def block_mad(values: list[float]) -> float:
    center = median(values)
    return median(abs(value - center) for value in values)


def permutation_mad_state(
    returns: tuple[float, ...] | list[float],
) -> tuple[float, int, int]:
    observed = block_mad(list(returns[BLOCK_SIZE:])) - block_mad(
        list(returns[:BLOCK_SIZE])
    )
    tail = 0
    all_indices = set(range(RETURN_COUNT))
    for recent_indices_tuple in combinations(range(RETURN_COUNT), BLOCK_SIZE):
        recent_indices = set(recent_indices_tuple)
        pseudo_recent = [returns[index] for index in recent_indices]
        pseudo_old = [returns[index] for index in all_indices - recent_indices]
        delta = block_mad(pseudo_recent) - block_mad(pseudo_old)
        tail += delta >= observed - 1e-14
    recent_return = sum(returns[BLOCK_SIZE:])
    direction = 0
    if observed > RELATIVE_EPSILON and tail <= 416:
        if recent_return > RELATIVE_EPSILON:
            direction = 1
        elif recent_return < -RELATIVE_EPSILON:
            direction = -1
    return observed, tail, direction


def closes_from_returns(
    returns: tuple[float, ...] | list[float], start: float = 70.0
) -> list[float]:
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


class WtiFlignerKilleenScaleTrendReferenceTests(unittest.TestCase):
    def test_all_23_locked_normal_scores_match_formula(self) -> None:
        self.assertEqual(len(RANK2_SCORE), SCORE_TABLE_SIZE)
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        matches = re.findall(
            r"case\s+(\d+):\s+score\s*=\s*([0-9.]+);\s+break;", source
        )
        source_scores = {int(rank2): float(score) for rank2, score in matches}
        self.assertEqual(set(source_scores), set(range(2, 25)))
        for rank2, expected in RANK2_SCORE.items():
            self.assertAlmostEqual(source_scores[rank2], expected, places=15)

    def test_anchored_relative_tie_runs_do_not_chain(self) -> None:
        deviations = (
            0.0,
            0.75e-12,
            1.50e-12,
            1.0,
            2.0,
            3.0,
            4.0,
            5.0,
            6.0,
            7.0,
            8.0,
            9.0,
        )
        rank2, run_count = anchored_midranks(deviations)
        self.assertEqual(rank2[:3], (3, 3, 6))
        self.assertEqual(sum(rank2), 156)
        self.assertEqual(run_count, 11)

    def test_fk_only_fixture_is_exact_sell(self) -> None:
        signal = fligner_killeen_signal(FK_ONLY_RETURNS)
        self.assertEqual((signal.median_old, signal.median_recent), (4.75, -2.875))
        self.assertEqual(
            signal.rank2,
            (12, 22, 18, 7, 14, 7, 3, 10, 24, 16, 20, 3),
        )
        self.assertEqual(signal.tie_run_count, 10)
        self.assertAlmostEqual(signal.score_mean_old, 0.747635842132864, places=15)
        self.assertAlmostEqual(signal.score_mean_recent, 0.77154543665157, places=15)
        self.assertAlmostEqual(signal.score_variance, 0.26574272782971864, places=15)
        self.assertAlmostEqual(signal.statistic_x2, 0.006453633347384549, places=15)
        self.assertTrue(signal.recent_scale_expanding)
        self.assertEqual((signal.recent_return, signal.direction), (-6.5, -1))

    def test_neighbor_only_fixture_is_fk_flat(self) -> None:
        signal = fligner_killeen_signal(NEIGHBOR_ONLY_RETURNS)
        self.assertEqual((signal.median_old, signal.median_recent), (0.875, 2.25))
        self.assertAlmostEqual(signal.score_mean_old, 0.8197335318351365, places=15)
        self.assertAlmostEqual(signal.score_mean_recent, 0.6994477469492976, places=15)
        self.assertAlmostEqual(signal.statistic_x2, 0.1633384683422851, places=15)
        self.assertFalse(signal.recent_scale_expanding)
        self.assertEqual((signal.recent_return, signal.direction), (10.25, 0))

    def test_fixed_fixtures_prove_both_nonduplicate_directions(self) -> None:
        fk_only = fligner_killeen_signal(FK_ONLY_RETURNS)
        ab_score, ab_direction = ansari_bradley_state(FK_ONLY_RETURNS)
        mad_delta, mad_tail, mad_direction = permutation_mad_state(FK_ONLY_RETURNS)
        self.assertEqual((fk_only.direction, ab_score, ab_direction), (-1, 22, 0))
        self.assertEqual((mad_delta, mad_tail, mad_direction), (-0.5, 647, 0))

        neighbor_only = fligner_killeen_signal(NEIGHBOR_ONLY_RETURNS)
        ab_score, ab_direction = ansari_bradley_state(NEIGHBOR_ONLY_RETURNS)
        mad_delta, mad_tail, mad_direction = permutation_mad_state(
            NEIGHBOR_ONLY_RETURNS
        )
        self.assertEqual((neighbor_only.direction, ab_score, ab_direction), (0, 21, 1))
        self.assertEqual((mad_delta, mad_tail, mad_direction), (-0.75, 602, 0))

    def test_qualifying_scale_with_neutral_recent_return_is_flat(self) -> None:
        shifted = list(FK_ONLY_RETURNS)
        shift = -sum(shifted[BLOCK_SIZE:]) / BLOCK_SIZE
        shifted[BLOCK_SIZE:] = [value + shift for value in shifted[BLOCK_SIZE:]]
        signal = fligner_killeen_signal(shifted)
        self.assertTrue(signal.recent_scale_expanding)
        self.assertLessEqual(abs(signal.recent_return), RELATIVE_EPSILON)
        self.assertEqual(signal.direction, 0)

    def test_degenerate_score_variance_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "degenerate pooled score variance"):
            fligner_killeen_signal((0.0,) * RETURN_COUNT)

    def test_fixed_score_label_symmetry_activity_prior(self) -> None:
        fixed_scores = [RANK2_SCORE[2 * rank] for rank in range(1, 13)]
        above = below = tied = 0
        all_indices = set(range(RETURN_COUNT))
        for recent_tuple in combinations(range(RETURN_COUNT), BLOCK_SIZE):
            recent = set(recent_tuple)
            recent_sum = sum(fixed_scores[index] for index in recent)
            old_sum = sum(fixed_scores[index] for index in all_indices - recent)
            above += recent_sum > old_sum
            below += recent_sum < old_sum
            tied += recent_sum == old_sum
        self.assertEqual((above, below, tied), (462, 462, 0))

    def test_close_return_orientation_is_chronological(self) -> None:
        returns = (-0.03, 0.02, -0.01, 0.04, -0.02, 0.01) * 2
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
            "bool Strategy_FlignerKilleenSignal",
            "bool Strategy_Median6",
            "bool Strategy_NormalScoreForRank2",
            "MathAbs(returns[index] - center)",
            "const double anchor = ordered_deviations[run_start]",
            "MathAbs(candidate - anchor) > tie_tolerance",
            "const int rank2 = run_start + run_end + 2",
            "metrics.rank2_sum != 156",
            "metrics.score_variance = variance_sum / 11.0",
            "metrics.statistic_x2 =",
            "metrics.score_mean_recent >",
            "metrics.score_mean_old + metrics.scale_tolerance",
            "metrics.recent_return > strategy_relative_epsilon",
            "metrics.recent_return < -strategy_relative_epsilon",
            "QM_FrameworkMagic() != 412660000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41266",
        )
        for literal in required:
            self.assertIn(literal, source)
        prepare = source[source.index("void Strategy_PrepareDecisionSignal") :]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadMonthlyEndpoints"),
        )
        self.assertEqual(source.count('input group "'), 6)
        for banned in (
            "iRSI",
            "iBands",
            "iMA(",
            "iMACD",
            "MathRand",
            "WebRequest",
            "FileOpen",
            "ChiSquare",
        ):
            self.assertNotIn(banned, source)
        self.assertIsNone(re.search(r"\bp_?value\b", source, re.IGNORECASE))

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41266")
        self.assertEqual(headers["ea_slug"], "wti-mfk-scale-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertRegex(headers["build_hash"], r"^(pending|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41266",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_return_count": "12",
            "strategy_block_size": "6",
            "strategy_score_table_size": "23",
            "strategy_relative_epsilon": "0.000000000001",
            "strategy_min_score_variance": "0.000000000000000001",
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
