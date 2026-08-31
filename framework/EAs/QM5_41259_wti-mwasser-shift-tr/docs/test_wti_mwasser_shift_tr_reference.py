from __future__ import annotations

import itertools
import math
from dataclasses import dataclass
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41259_wti-mwasser-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41259_wti-mwasser-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41259_wti-mwasser-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"

RETURN_COUNT = 12
BLOCK_SIZE = 6
ASSIGNMENT_COUNT = 924
TAIL_NUMERATOR = 3
TAIL_DENOMINATOR = 5
TAIL_COUNT_MAX = 554
WASSERSTEIN_EPSILON = 1e-12
DIRECTION_EPSILON = 1e-12
ASSIGNMENTS = tuple(itertools.combinations(range(RETURN_COUNT), BLOCK_SIZE))


@dataclass(frozen=True)
class Signal:
    direction: int
    tail_count: int
    observed_wasserstein: float
    median_delta: float


def split_assignment(
    values: list[float], recent_indices: tuple[int, ...]
) -> tuple[list[float], list[float]]:
    if len(values) != RETURN_COUNT or any(not math.isfinite(v) for v in values):
        raise ValueError("locked finite twelve-return sample required")
    recent_set = set(recent_indices)
    if len(recent_set) != BLOCK_SIZE or any(
        index < 0 or index >= RETURN_COUNT for index in recent_set
    ):
        raise ValueError("six unique recent indices required")
    old = [value for index, value in enumerate(values) if index not in recent_set]
    recent = [value for index, value in enumerate(values) if index in recent_set]
    return old, recent


def wasserstein_for_assignment(
    values: list[float], recent_indices: tuple[int, ...]
) -> float:
    old, recent = split_assignment(values, recent_indices)
    old.sort()
    recent.sort()
    distance = sum(abs(a - b) for a, b in zip(old, recent)) / BLOCK_SIZE
    if not math.isfinite(distance) or distance < 0.0:
        raise ValueError("invalid Wasserstein arithmetic")
    return distance


def mean_ordered_distance(left: list[float], right: list[float]) -> float:
    return sum(abs(a - b) for a in left for b in right) / 36.0


def energy_for_assignment(
    values: list[float], recent_indices: tuple[int, ...]
) -> float:
    old, recent = split_assignment(values, recent_indices)
    cross = mean_ordered_distance(old, recent)
    within_old = mean_ordered_distance(old, old)
    within_recent = mean_ordered_distance(recent, recent)
    return 3.0 * (2.0 * cross - within_old - within_recent)


def exact_tail_count(values: list[float], observed: tuple[int, ...]) -> int:
    observed_distance = wasserstein_for_assignment(values, observed)
    tolerance = WASSERSTEIN_EPSILON * max(1.0, abs(observed_distance))
    return sum(
        wasserstein_for_assignment(values, assignment) + tolerance
        >= observed_distance
        for assignment in ASSIGNMENTS
    )


def energy_tail_count(values: list[float], observed: tuple[int, ...]) -> int:
    observed_energy = energy_for_assignment(values, observed)
    tolerance = WASSERSTEIN_EPSILON * max(1.0, abs(observed_energy))
    return sum(
        energy_for_assignment(values, assignment) + tolerance >= observed_energy
        for assignment in ASSIGNMENTS
    )


def median6(values: list[float]) -> float:
    if len(values) != BLOCK_SIZE or any(not math.isfinite(v) for v in values):
        raise ValueError("six finite values required")
    ordered = sorted(values)
    return (ordered[2] + ordered[3]) / 2.0


def wasserstein_signal(returns: list[float]) -> Signal:
    if len(returns) != RETURN_COUNT or any(
        not math.isfinite(value) for value in returns
    ):
        raise ValueError("locked finite twelve-return sample required")
    observed = tuple(range(BLOCK_SIZE, RETURN_COUNT))
    observed_distance = wasserstein_for_assignment(returns, observed)
    tail = exact_tail_count(returns, observed)
    qualified = tail <= TAIL_COUNT_MAX and (
        TAIL_DENOMINATOR * tail <= TAIL_NUMERATOR * ASSIGNMENT_COUNT
    )
    delta = median6(returns[BLOCK_SIZE:]) - median6(returns[:BLOCK_SIZE])
    direction = 0
    if qualified and delta > DIRECTION_EPSILON:
        direction = 1
    elif qualified and delta < -DIRECTION_EPSILON:
        direction = -1
    return Signal(direction, tail, observed_distance, delta)


def returns_for_recent_ranks(
    pooled_values: list[float], recent_ranks: tuple[int, ...]
) -> list[float]:
    if len(pooled_values) != RETURN_COUNT:
        raise ValueError("twelve pooled values required")
    recent = set(recent_ranks)
    if len(recent) != BLOCK_SIZE:
        raise ValueError("six unique recent ranks required")
    old_values = [value for rank, value in enumerate(pooled_values) if rank not in recent]
    recent_values = [value for rank, value in enumerate(pooled_values) if rank in recent]
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


def integrated_ecdf_tail(recent_ranks: tuple[int, ...]) -> int:
    observed = integrated_path_score(recent_ranks)
    return sum(integrated_path_score(assignment) >= observed for assignment in ASSIGNMENTS)


def qualifying_state_count(values: list[float]) -> int:
    distances = [
        wasserstein_for_assignment(values, assignment) for assignment in ASSIGNMENTS
    ]
    qualifying = 0
    for observed_distance in distances:
        tolerance = WASSERSTEIN_EPSILON * max(1.0, abs(observed_distance))
        tail = sum(value + tolerance >= observed_distance for value in distances)
        if tail <= TAIL_COUNT_MAX and TAIL_DENOMINATOR * tail <= (
            TAIL_NUMERATOR * ASSIGNMENT_COUNT
        ):
            qualifying += 1
    return qualifying


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


class WtiMonthlyWassersteinShiftReferenceTests(unittest.TestCase):
    def test_assignment_space_and_hand_computed_wasserstein(self) -> None:
        self.assertEqual(len(ASSIGNMENTS), ASSIGNMENT_COUNT)
        self.assertEqual(len(set(ASSIGNMENTS)), ASSIGNMENT_COUNT)
        distance = wasserstein_for_assignment(
            [float(value) for value in range(RETURN_COUNT)],
            tuple(range(BLOCK_SIZE, RETURN_COUNT)),
        )
        self.assertAlmostEqual(distance, 6.0, places=14)

    def test_inclusive_tail_contains_observed_and_complement(self) -> None:
        values = [float(value) for value in range(RETURN_COUNT)]
        observed = tuple(range(BLOCK_SIZE, RETURN_COUNT))
        complement = tuple(range(BLOCK_SIZE))
        observed_distance = wasserstein_for_assignment(values, observed)
        complement_distance = wasserstein_for_assignment(values, complement)
        self.assertAlmostEqual(observed_distance, complement_distance, places=14)
        self.assertEqual(exact_tail_count(values, observed), 2)

    def test_locked_activity_density_on_three_spacing_fixtures(self) -> None:
        fixtures = {
            "linear": ([float(rank) for rank in range(RETURN_COUNT)], 540),
            "squared": ([float(rank * rank) for rank in range(RETURN_COUNT)], 532),
            "exponential": ([math.exp(rank / 3.0) for rank in range(RETURN_COUNT)], 548),
        }
        for label, (values, expected) in fixtures.items():
            with self.subTest(label=label):
                self.assertEqual(qualifying_state_count(values), expected)
        self.assertAlmostEqual(12.0 * 540 / ASSIGNMENT_COUNT, 7.012987012987013)

    def test_squared_fixture_separates_wasserstein_from_energy(self) -> None:
        recent_ranks = (0, 1, 2, 5, 8, 10)
        pooled = [float(rank * rank) for rank in range(RETURN_COUNT)]
        returns = returns_for_recent_ranks(pooled, recent_ranks)
        signal = wasserstein_signal(returns)
        self.assertEqual((signal.tail_count, signal.direction), (572, 0))
        self.assertEqual(energy_tail_count(pooled, recent_ranks), 508)

    def test_exponential_fixture_separates_wasserstein_from_energy(self) -> None:
        recent_ranks = (0, 2, 3, 5, 7, 10)
        pooled = [math.exp(rank / 3.0) for rank in range(RETURN_COUNT)]
        returns = returns_for_recent_ranks(pooled, recent_ranks)
        signal = wasserstein_signal(returns)
        self.assertEqual((signal.tail_count, signal.direction), (540, -1))
        self.assertEqual(energy_tail_count(pooled, recent_ranks), 556)

    def test_exponential_fixtures_separate_wasserstein_from_integrated_ecdf(self) -> None:
        pooled = [math.exp(rank / 3.0) for rank in range(RETURN_COUNT)]
        wasserstein_only = (0, 1, 4, 6, 8, 9)
        ecdf_only = (0, 1, 2, 4, 8, 10)
        first = wasserstein_signal(returns_for_recent_ranks(pooled, wasserstein_only))
        second = wasserstein_signal(returns_for_recent_ranks(pooled, ecdf_only))
        self.assertEqual((first.tail_count, integrated_ecdf_tail(wasserstein_only)), (496, 700))
        self.assertEqual((second.tail_count, integrated_ecdf_tail(ecdf_only)), (588, 230))

    def test_block_swap_preserves_distance_and_reverses_direction(self) -> None:
        recent_ranks = (0, 2, 3, 5, 7, 10)
        complement = tuple(rank for rank in range(RETURN_COUNT) if rank not in recent_ranks)
        pooled = [math.exp(rank / 3.0) for rank in range(RETURN_COUNT)]
        first = wasserstein_signal(returns_for_recent_ranks(pooled, recent_ranks))
        second = wasserstein_signal(returns_for_recent_ranks(pooled, complement))
        self.assertEqual(first.tail_count, second.tail_count)
        self.assertAlmostEqual(
            first.observed_wasserstein, second.observed_wasserstein, places=14
        )
        self.assertAlmostEqual(first.median_delta, -second.median_delta, places=14)
        self.assertEqual(first.direction, -second.direction)

    def test_close_return_orientation_is_chronological(self) -> None:
        returns = [-0.03, 0.02, -0.01, 0.04, -0.02, 0.01] * 2
        closes = closes_from_returns(returns)
        recovered = [
            math.log(closes[index + 1] / closes[index])
            for index in range(RETURN_COUNT)
        ]
        for actual, expected in zip(recovered, returns):
            self.assertAlmostEqual(actual, expected, places=14)

    def test_invalid_samples_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            wasserstein_signal([0.0] * 11)
        with self.assertRaises(ValueError):
            wasserstein_signal([0.0] * 11 + [math.nan])
        with self.assertRaises(ValueError):
            wasserstein_for_assignment([0.0] * 12, (0, 1, 2, 3, 4, 12))

    def test_source_contains_formula_thresholds_and_attempt_order(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        required = (
            "bool Strategy_SortSix",
            "bool Strategy_WassersteinForMask",
            "bool Strategy_WassersteinSignal",
            "MathAbs(ordered_old[rank] - ordered_recent[rank])",
            "paired_difference_sum / (double)strategy_block_size",
            "perm_wasserstein + metrics.comparison_epsilon >=",
            "metrics.tail_count <= strategy_tail_count_max",
            "strategy_tail_denominator * metrics.tail_count <=",
            "QM_CalendarPeriodKey(PERIOD_MN1",
            "QM_FrameworkMagic() != 412590000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41259",
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
            "MathRand",
            "WebRequest",
            "onnx",
            "tensorflow",
        ):
            self.assertNotIn(banned, source.lower() if banned.islower() else source)

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41259")
        self.assertEqual(headers["ea_slug"], "wti-mwasser-shift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41259",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "12",
            "strategy_block_size": "6",
            "strategy_assignment_count": "924",
            "strategy_tail_numerator": "3",
            "strategy_tail_denominator": "5",
            "strategy_tail_count_max": "554",
            "strategy_wasserstein_epsilon": "0.000000000001",
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
