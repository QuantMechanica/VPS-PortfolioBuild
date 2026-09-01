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
EA_SOURCE = EA_DIR / "QM5_41267_wti-mmood-scale-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41267_wti-mmood-scale-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41267_wti-mmood-scale-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"

RETURN_COUNT = 12
BLOCK_SIZE = 6
RANK_CENTER = 6.5
SCORE_EXPECTATION = 71.5
SCORE_VARIANCE = 364.0
RELATIVE_EPSILON = 1e-12

MOOD_ONLY_RETURNS = (
    6.5,
    8.0,
    -2.75,
    -1.5,
    6.0,
    -2.5,
    7.0,
    -3.25,
    -1.25,
    -0.75,
    -6.25,
    1.25,
)
FK_ONLY_RETURNS = (
    3.0,
    -6.5,
    -6.0,
    -2.5,
    4.0,
    -2.0,
    3.5,
    2.75,
    -4.25,
    -7.5,
    -5.0,
    -3.0,
)


@dataclass(frozen=True)
class Signal:
    direction: int
    ranks: tuple[int, ...]
    score_old: float
    score_expectation: float
    score_variance: float
    statistic_z: float
    recent_return: float
    recent_scale_noncontracting: bool


def anchored_unique_ranks(
    values: tuple[float, ...] | list[float],
) -> tuple[int, ...]:
    if len(values) != RETURN_COUNT:
        raise ValueError("twelve pooled raw returns required")
    if any(not math.isfinite(value) for value in values):
        raise ValueError("finite pooled raw returns required")

    ordered = sorted((value, index) for index, value in enumerate(values))
    ranks: list[int | None] = [None] * RETURN_COUNT
    run_start = 0
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
        if run_end != run_start:
            raise ValueError("anchored relative tie")
        rank = run_start + 1
        original_index = ordered[run_start][1]
        if ranks[original_index] is not None:
            raise ValueError("duplicate rank assignment")
        ranks[original_index] = rank
        run_start = run_end + 1

    if any(value is None for value in ranks):
        raise ValueError("incomplete rank assignment")
    locked_ranks = tuple(int(value) for value in ranks)
    if set(locked_ranks) != set(range(1, RETURN_COUNT + 1)):
        raise ValueError("ranks must be unique integers 1 through 12")
    if sum(locked_ranks) != 78:
        raise ValueError("pooled rank sum must be 78")
    return locked_ranks


def mood_signal(
    returns: tuple[float, ...] | list[float],
) -> Signal:
    if len(returns) != RETURN_COUNT or any(
        not math.isfinite(value) for value in returns
    ):
        raise ValueError("locked finite twelve-return sample required")

    ranks = anchored_unique_ranks(returns)
    score_old = sum(
        (rank - RANK_CENTER) ** 2 for rank in ranks[:BLOCK_SIZE]
    )
    statistic_z = (
        score_old - SCORE_EXPECTATION
    ) / math.sqrt(SCORE_VARIANCE)
    if not math.isfinite(statistic_z):
        raise ValueError("invalid Mood statistic")
    recent_scale_noncontracting = score_old <= SCORE_EXPECTATION
    recent_return = sum(returns[BLOCK_SIZE:])
    direction = 0
    if (
        recent_scale_noncontracting
        and recent_return > RELATIVE_EPSILON
    ):
        direction = 1
    elif (
        recent_scale_noncontracting
        and recent_return < -RELATIVE_EPSILON
    ):
        direction = -1
    return Signal(
        direction,
        ranks,
        score_old,
        SCORE_EXPECTATION,
        SCORE_VARIANCE,
        statistic_z,
        recent_return,
        recent_scale_noncontracting,
    )


def fligner_killeen_neighbor_state(
    returns: tuple[float, ...] | list[float],
) -> tuple[float, float, int]:
    old = tuple(returns[:BLOCK_SIZE])
    recent = tuple(returns[BLOCK_SIZE:])
    deviations = tuple(
        abs(value - median(old)) for value in old
    ) + tuple(abs(value - median(recent)) for value in recent)
    ordered = sorted((value, index) for index, value in enumerate(deviations))
    rank2: list[int | None] = [None] * RETURN_COUNT
    run_start = 0
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
            rank2[ordered[position][1]] = run_rank2
        run_start = run_end + 1
    scores = tuple(
        NormalDist().inv_cdf(0.5 + (int(value) / 2.0) / 26.0)
        for value in rank2
    )
    mean_old = sum(scores[:BLOCK_SIZE]) / BLOCK_SIZE
    mean_recent = sum(scores[BLOCK_SIZE:]) / BLOCK_SIZE
    tolerance = RELATIVE_EPSILON * max(
        1.0, abs(mean_old), abs(mean_recent)
    )
    direction = 0
    if mean_recent > mean_old + tolerance:
        recent_return = sum(recent)
        if recent_return > RELATIVE_EPSILON:
            direction = 1
        elif recent_return < -RELATIVE_EPSILON:
            direction = -1
    return mean_old, mean_recent, direction


def ansari_bradley_state(
    returns: tuple[float, ...] | list[float],
) -> tuple[int, int]:
    ordered = sorted(
        (value, index >= BLOCK_SIZE) for index, value in enumerate(returns)
    )
    if any(left[0] == right[0] for left, right in zip(ordered, ordered[1:])):
        return 0, 0
    weights = (1, 2, 3, 4, 5, 6, 6, 5, 4, 3, 2, 1)
    score = sum(
        weight for weight, (_, recent) in zip(weights, ordered) if recent
    )
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
        pseudo_old = [
            returns[index] for index in all_indices - recent_indices
        ]
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


class WtiMoodScaleTrendReferenceTests(unittest.TestCase):
    def test_fixed_mood_moments_match_no_tie_formula(self) -> None:
        sample_x = sample_y = BLOCK_SIZE
        pooled = RETURN_COUNT
        expectation = sample_x * (pooled**2 - 1) / 12
        variance = (
            sample_x
            * sample_y
            * (pooled + 1)
            * (pooled + 2)
            * (pooled - 2)
            / 180
        )
        self.assertEqual(expectation, SCORE_EXPECTATION)
        self.assertEqual(variance, SCORE_VARIANCE)

    def test_mood_only_fixture_is_exact_sell(self) -> None:
        signal = mood_signal(MOOD_ONLY_RETURNS)
        self.assertEqual(
            signal.ranks,
            (10, 12, 3, 5, 9, 4, 11, 2, 6, 7, 1, 8),
        )
        self.assertEqual(signal.score_old, 69.5)
        self.assertEqual(signal.score_expectation, 71.5)
        self.assertEqual(signal.score_variance, 364.0)
        self.assertAlmostEqual(
            signal.statistic_z, -0.10482848367219183, places=15
        )
        self.assertTrue(signal.recent_scale_noncontracting)
        self.assertEqual((signal.recent_return, signal.direction), (-3.25, -1))

    def test_fk_only_fixture_is_mood_flat(self) -> None:
        signal = mood_signal(FK_ONLY_RETURNS)
        self.assertEqual(
            signal.ranks,
            (10, 2, 3, 7, 12, 8, 11, 9, 5, 1, 4, 6),
        )
        self.assertEqual(signal.score_old, 77.5)
        self.assertAlmostEqual(
            signal.statistic_z, 0.3144854510165755, places=15
        )
        self.assertFalse(signal.recent_scale_noncontracting)
        self.assertEqual((signal.recent_return, signal.direction), (-13.5, 0))

    def test_fixed_fixtures_prove_both_nonduplicate_directions(self) -> None:
        mood_only = mood_signal(MOOD_ONLY_RETURNS)
        fk_old, fk_recent, fk_direction = fligner_killeen_neighbor_state(
            MOOD_ONLY_RETURNS
        )
        ab_score, ab_direction = ansari_bradley_state(MOOD_ONLY_RETURNS)
        mad_delta, mad_tail, mad_direction = permutation_mad_state(
            MOOD_ONLY_RETURNS
        )
        self.assertEqual(mood_only.direction, -1)
        self.assertGreater(fk_old, fk_recent)
        self.assertEqual(fk_direction, 0)
        self.assertEqual((ab_score, ab_direction), (22, 0))
        self.assertEqual((mad_delta, mad_tail, mad_direction), (-2.25, 683, 0))

        mood_flat = mood_signal(FK_ONLY_RETURNS)
        fk_old, fk_recent, fk_direction = fligner_killeen_neighbor_state(
            FK_ONLY_RETURNS
        )
        ab_score, ab_direction = ansari_bradley_state(FK_ONLY_RETURNS)
        mad_delta, mad_tail, mad_direction = permutation_mad_state(
            FK_ONLY_RETURNS
        )
        self.assertEqual(mood_flat.direction, 0)
        self.assertGreater(fk_recent, fk_old)
        self.assertEqual(fk_direction, -1)
        self.assertEqual((ab_score, ab_direction), (22, 0))
        self.assertEqual(
            (mad_delta, mad_tail, mad_direction), (-1.375, 761, 0)
        )

    def test_anchored_relative_ties_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "anchored relative tie"):
            anchored_unique_ranks(
                (0.0, 0.75e-12, 2.0, 3.0, 4.0, 5.0,
                 6.0, 7.0, 8.0, 9.0, 10.0, 11.0)
            )
        with self.assertRaisesRegex(ValueError, "anchored relative tie"):
            anchored_unique_ranks(
                (1.0e6, 1.0e6 + 0.5e-6, 2.0e6, 3.0e6, 4.0e6, 5.0e6,
                 6.0e6, 7.0e6, 8.0e6, 9.0e6, 10.0e6, 11.0e6)
            )

    def test_qualifying_scale_with_neutral_recent_return_is_flat(self) -> None:
        returns = (
            -3.5, -2.5, -1.5, 1.5, 2.5, 3.5,
            -5.5, -4.5, -0.5, 0.5, 4.5, 5.5,
        )
        signal = mood_signal(returns)
        self.assertTrue(signal.recent_scale_noncontracting)
        self.assertEqual(signal.recent_return, 0.0)
        self.assertEqual(signal.direction, 0)

    def test_fixed_unique_rank_activity_prior(self) -> None:
        below = equal = above = 0
        for old_ranks in combinations(range(1, RETURN_COUNT + 1), BLOCK_SIZE):
            score = sum((rank - RANK_CENTER) ** 2 for rank in old_ranks)
            below += score < SCORE_EXPECTATION
            equal += score == SCORE_EXPECTATION
            above += score > SCORE_EXPECTATION
        self.assertEqual((below, equal, above), (426, 72, 426))
        self.assertEqual(below + equal, 498)

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
            "bool Strategy_MoodSignal",
            "const double anchor = ordered_returns[run_start]",
            "MathAbs(candidate - anchor) > tie_tolerance",
            "if(run_end != run_start)",
            "const int rank = run_start + 1",
            "metrics.rank_sum != 78",
            "metrics.score_old += rank_delta * rank_delta",
            "(metrics.score_old - metrics.score_expectation)",
            "metrics.score_old <= metrics.score_expectation",
            "metrics.recent_return > strategy_relative_epsilon",
            "metrics.recent_return < -strategy_relative_epsilon",
            "QM_FrameworkMagic() != 412670000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41267",
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
            "NormalDist",
            "ChiSquare",
        ):
            self.assertNotIn(banned, source)
        self.assertIsNone(re.search(r"\bp_?value\b", source, re.IGNORECASE))

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41267")
        self.assertEqual(headers["ea_slug"], "wti-mmood-scale-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertRegex(headers["build_hash"], r"^(pending|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41267",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_return_count": "12",
            "strategy_block_size": "6",
            "strategy_rank_center": "6.5",
            "strategy_score_expectation": "71.5",
            "strategy_score_variance": "364.0",
            "strategy_relative_epsilon": "0.000000000001",
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
        self.assertEqual(EA_CARD.read_bytes(), CANONICAL_CARD.read_bytes())
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
