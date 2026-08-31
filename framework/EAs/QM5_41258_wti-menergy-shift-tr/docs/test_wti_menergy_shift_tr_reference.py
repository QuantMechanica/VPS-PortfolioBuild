from __future__ import annotations

import itertools
import math
from dataclasses import dataclass
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41258_wti-menergy-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41258_wti-menergy-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41258_wti-menergy-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"

RETURN_COUNT = 12
BLOCK_SIZE = 6
ASSIGNMENT_COUNT = 924
TAIL_NUMERATOR = 3
TAIL_DENOMINATOR = 5
TAIL_COUNT_MAX = 554
ENERGY_EPSILON = 1e-12
DIRECTION_EPSILON = 1e-12
ASSIGNMENTS = tuple(itertools.combinations(range(RETURN_COUNT), BLOCK_SIZE))


@dataclass(frozen=True)
class Signal:
    direction: int
    tail_count: int
    observed_energy: float
    median_delta: float


def mean_ordered_distance(left: list[float], right: list[float]) -> float:
    if len(left) != BLOCK_SIZE or len(right) != BLOCK_SIZE:
        raise ValueError("locked six-by-six samples required")
    return sum(abs(a - b) for a in left for b in right) / 36.0


def energy_for_assignment(
    values: list[float], recent_indices: tuple[int, ...]
) -> tuple[float, float, float, float]:
    if len(values) != RETURN_COUNT or any(not math.isfinite(v) for v in values):
        raise ValueError("locked finite twelve-return sample required")
    recent_set = set(recent_indices)
    if len(recent_set) != BLOCK_SIZE or any(
        index < 0 or index >= RETURN_COUNT for index in recent_set
    ):
        raise ValueError("six unique recent indices required")
    old = [value for index, value in enumerate(values) if index not in recent_set]
    recent = [value for index, value in enumerate(values) if index in recent_set]
    cross = mean_ordered_distance(old, recent)
    within_old = mean_ordered_distance(old, old)
    within_recent = mean_ordered_distance(recent, recent)
    energy = 3.0 * (2.0 * cross - within_old - within_recent)
    if not all(math.isfinite(v) for v in (energy, cross, within_old, within_recent)):
        raise ValueError("non-finite energy arithmetic")
    return energy, cross, within_old, within_recent


def exact_tail_count(values: list[float], observed: tuple[int, ...]) -> int:
    observed_energy = energy_for_assignment(values, observed)[0]
    tolerance = ENERGY_EPSILON * max(1.0, abs(observed_energy))
    return sum(
        energy_for_assignment(values, assignment)[0] + tolerance
        >= observed_energy
        for assignment in ASSIGNMENTS
    )


def median6(values: list[float]) -> float:
    if len(values) != BLOCK_SIZE or any(not math.isfinite(v) for v in values):
        raise ValueError("six finite values required")
    ordered = sorted(values)
    return (ordered[2] + ordered[3]) / 2.0


def energy_signal(returns: list[float]) -> Signal:
    if len(returns) != RETURN_COUNT or any(
        not math.isfinite(value) for value in returns
    ):
        raise ValueError("locked finite twelve-return sample required")
    observed = tuple(range(BLOCK_SIZE, RETURN_COUNT))
    observed_energy = energy_for_assignment(returns, observed)[0]
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
    return Signal(direction, tail, observed_energy, delta)


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


class WtiMonthlyEnergyShiftReferenceTests(unittest.TestCase):
    def test_assignment_space_and_hand_computed_energy(self) -> None:
        self.assertEqual(len(ASSIGNMENTS), ASSIGNMENT_COUNT)
        self.assertEqual(len(set(ASSIGNMENTS)), ASSIGNMENT_COUNT)
        energy, cross, within_old, within_recent = energy_for_assignment(
            [float(value) for value in range(RETURN_COUNT)],
            tuple(range(BLOCK_SIZE, RETURN_COUNT)),
        )
        self.assertAlmostEqual(cross, 6.0, places=14)
        self.assertAlmostEqual(within_old, 35.0 / 18.0, places=14)
        self.assertAlmostEqual(within_recent, 35.0 / 18.0, places=14)
        self.assertAlmostEqual(energy, 73.0 / 3.0, places=14)

    def test_inclusive_tail_contains_observed_and_complement(self) -> None:
        values = [float(value) for value in range(RETURN_COUNT)]
        observed = tuple(range(BLOCK_SIZE, RETURN_COUNT))
        complement = tuple(range(BLOCK_SIZE))
        observed_energy = energy_for_assignment(values, observed)[0]
        complement_energy = energy_for_assignment(values, complement)[0]
        self.assertAlmostEqual(observed_energy, complement_energy, places=14)
        self.assertEqual(exact_tail_count(values, observed), 2)

    def test_equal_spaced_reference_has_locked_activity_density(self) -> None:
        values = [float(value) for value in range(RETURN_COUNT)]
        energies = [energy_for_assignment(values, assignment)[0] for assignment in ASSIGNMENTS]
        qualifying = 0
        for observed_energy in energies:
            tolerance = ENERGY_EPSILON * max(1.0, abs(observed_energy))
            tail = sum(value + tolerance >= observed_energy for value in energies)
            if tail <= TAIL_COUNT_MAX and TAIL_DENOMINATOR * tail <= (
                TAIL_NUMERATOR * ASSIGNMENT_COUNT
            ):
                qualifying += 1
        self.assertEqual(qualifying, 540)
        self.assertAlmostEqual(12.0 * qualifying / ASSIGNMENT_COUNT, 7.012987012987013)

    def test_linear_separator_passes_energy_but_fails_integrated_ecdf(self) -> None:
        recent_ranks = (0, 1, 3, 5, 8, 10)
        returns = returns_for_recent_ranks(
            [float(value) for value in range(RETURN_COUNT)], recent_ranks
        )
        signal = energy_signal(returns)
        self.assertEqual((signal.tail_count, signal.direction), (540, -1))
        self.assertEqual(integrated_ecdf_tail(recent_ranks), 540)
        self.assertGreater(integrated_ecdf_tail(recent_ranks), 460)

    def test_squared_separator_fails_energy_but_passes_integrated_ecdf(self) -> None:
        recent_ranks = (0, 1, 2, 6, 8, 10)
        returns = returns_for_recent_ranks(
            [float(value * value) for value in range(RETURN_COUNT)], recent_ranks
        )
        signal = energy_signal(returns)
        self.assertEqual((signal.tail_count, signal.direction), (636, 0))
        self.assertEqual(integrated_ecdf_tail(recent_ranks), 460)

    def test_block_swap_preserves_energy_and_reverses_direction(self) -> None:
        recent_ranks = (0, 1, 3, 5, 8, 10)
        complement = tuple(rank for rank in range(RETURN_COUNT) if rank not in recent_ranks)
        pooled = [float(value) for value in range(RETURN_COUNT)]
        first = energy_signal(returns_for_recent_ranks(pooled, recent_ranks))
        second = energy_signal(returns_for_recent_ranks(pooled, complement))
        self.assertEqual(first.tail_count, second.tail_count)
        self.assertAlmostEqual(first.observed_energy, second.observed_energy, places=14)
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
            energy_signal([0.0] * 11)
        with self.assertRaises(ValueError):
            energy_signal([0.0] * 11 + [math.nan])
        with self.assertRaises(ValueError):
            energy_for_assignment([0.0] * 12, (0, 1, 2, 3, 4, 12))

    def test_source_contains_formula_thresholds_and_attempt_order(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        required = (
            "bool Strategy_EnergyForMask",
            "bool Strategy_EnergyDistanceSignal",
            "energy = 3.0 *",
            "2.0 * mean_cross - mean_old - mean_recent",
            "zero self-distances",
            "perm_energy + metrics.comparison_epsilon >=",
            "metrics.tail_count <= strategy_tail_count_max",
            "strategy_tail_denominator * metrics.tail_count <=",
            "QM_CalendarPeriodKey(PERIOD_MN1",
            "QM_FrameworkMagic() != 412580000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41258",
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
        self.assertEqual(headers["ea_id"], "41258")
        self.assertEqual(headers["ea_slug"], "wti-menergy-shift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41258",
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
            "strategy_energy_epsilon": "0.000000000001",
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
