from __future__ import annotations

import math
import random
import unittest
from dataclasses import dataclass
from datetime import date, timedelta


THRESHOLD = 0.0
TOLERANCE = 1.0e-10


@dataclass(frozen=True)
class Signal:
    count: int
    net: float
    mean: float
    squared_deviation_sum: float
    adjacent_product_sum: float
    autocorrelation: float
    bias_adjustment: float
    persistence_score: float
    direction: int


def classify_returns(returns: list[float]) -> Signal:
    if not 17 <= len(returns) <= 23:
        raise ValueError("session count")
    if not all(math.isfinite(value) for value in returns):
        raise ValueError("finite returns")

    count = len(returns)
    net = sum(returns)
    mean = net / count
    centered = [value - mean for value in returns]
    squared_deviation_sum = sum(value * value for value in centered)

    if squared_deviation_sum == 0.0:
        return Signal(
            count,
            net,
            mean,
            squared_deviation_sum,
            0.0,
            0.0,
            0.0,
            0.0,
            0,
        )
    if squared_deviation_sum < 0.0 or not math.isfinite(squared_deviation_sum):
        raise ValueError("variance denominator")

    adjacent_product_sum = sum(
        centered[index] * centered[index - 1]
        for index in range(1, count)
    )
    autocorrelation = adjacent_product_sum / squared_deviation_sum
    if (
        not math.isfinite(adjacent_product_sum)
        or not math.isfinite(autocorrelation)
        or autocorrelation < -1.0 - TOLERANCE
        or autocorrelation > 1.0 + TOLERANCE
    ):
        raise ValueError("autocorrelation")
    autocorrelation = min(1.0, max(-1.0, autocorrelation))

    bias_adjustment = 1.0 / (count - 1)
    persistence_score = autocorrelation + bias_adjustment
    if not math.isfinite(persistence_score):
        raise ValueError("persistence score")

    direction = 0
    if persistence_score > THRESHOLD:
        direction = 1 if net > 0.0 else -1 if net < 0.0 else 0
    return Signal(
        count,
        net,
        mean,
        squared_deviation_sum,
        adjacent_product_sum,
        autocorrelation,
        bias_adjustment,
        persistence_score,
        direction,
    )


def returns_from_closes(boundary_close: float, month_closes: list[float]) -> list[float]:
    if boundary_close <= 0.0 or not math.isfinite(boundary_close):
        raise ValueError("boundary")
    if not 17 <= len(month_closes) <= 23:
        raise ValueError("session count")
    prices = [boundary_close, *month_closes]
    if not all(value > 0.0 and math.isfinite(value) for value in prices):
        raise ValueError("prices")
    returns = [
        math.log(prices[index + 1]) - math.log(prices[index])
        for index in range(len(prices) - 1)
    ]
    direct = math.log(prices[-1]) - math.log(prices[0])
    if abs(sum(returns) - direct) > TOLERANCE * max(1.0, abs(direct)):
        raise ValueError("endpoint identity")
    return returns


def month_package(labels: list[date], current_month: tuple[int, int]) -> tuple[list[date], date]:
    previous = (
        (current_month[0] - 1, 12)
        if current_month[1] == 1
        else (current_month[0], current_month[1] - 1)
    )
    selected = [label for label in labels if (label.year, label.month) == previous]
    older = [label for label in labels if label < min(selected)] if selected else []
    if not 17 <= len(selected) <= 23 or not older:
        raise ValueError("calendar package")
    boundary = max(older)
    boundary_month = (
        (previous[0] - 1, 12)
        if previous[1] == 1
        else (previous[0], previous[1] - 1)
    )
    if (boundary.year, boundary.month) != boundary_month:
        raise ValueError("adjacent boundary")
    return sorted(selected), boundary


def aggregate_risk_lots(risk_fixed: float, stop_risk_per_lot: float, lot_step: float) -> float:
    if risk_fixed <= 0.0 or stop_risk_per_lot <= 0.0 or lot_step <= 0.0:
        raise ValueError("risk inputs")
    raw = risk_fixed / stop_risk_per_lot
    return math.floor((raw + 1.0e-12) / lot_step) * lot_step


class MonthlyDailyPersistenceReferenceTests(unittest.TestCase):
    def test_persistent_positive_endpoint_is_long(self) -> None:
        returns = [0.001 + 0.0001 * index for index in range(20)]
        signal = classify_returns(returns)
        self.assertGreater(signal.persistence_score, 0.0)
        self.assertEqual(signal.direction, 1)

    def test_persistent_negative_endpoint_is_short(self) -> None:
        returns = [-(0.001 + 0.0001 * index) for index in range(20)]
        signal = classify_returns(returns)
        self.assertGreater(signal.persistence_score, 0.0)
        self.assertEqual(signal.direction, -1)

    def test_alternating_path_is_nonpositive_and_flat(self) -> None:
        returns = [0.01 if index % 2 == 0 else -0.009 for index in range(20)]
        signal = classify_returns(returns)
        self.assertLessEqual(signal.persistence_score, 0.0)
        self.assertEqual(signal.direction, 0)

    def test_equal_returns_have_zero_variance_and_are_flat(self) -> None:
        signal = classify_returns([0.01] * 17)
        self.assertEqual(signal.squared_deviation_sum, 0.0)
        self.assertEqual(signal.direction, 0)

    def test_fixed_bias_adjustment_depends_only_on_count(self) -> None:
        returns = [0.001 + 0.0002 * (index % 5) for index in range(23)]
        signal = classify_returns(returns)
        self.assertAlmostEqual(signal.bias_adjustment, 1.0 / 22.0, places=15)
        self.assertAlmostEqual(
            signal.persistence_score,
            signal.autocorrelation + 1.0 / 22.0,
            places=15,
        )

    def test_threshold_is_strict(self) -> None:
        score = 0.0
        self.assertFalse(score > THRESHOLD)

    def test_close_path_preserves_endpoint_identity(self) -> None:
        increments = [0.001 + 0.00005 * index for index in range(20)]
        closes = []
        price = 80.0
        for increment in increments:
            price *= math.exp(increment)
            closes.append(price)
        returns = returns_from_closes(80.0, closes)
        signal = classify_returns(returns)
        self.assertAlmostEqual(signal.net, math.log(closes[-1] / 80.0), places=12)
        self.assertEqual(signal.direction, 1)

    def test_calendar_requires_immediate_month_and_older_boundary(self) -> None:
        labels = []
        cursor = date(2026, 6, 25)
        while cursor <= date(2026, 7, 31):
            if cursor.weekday() < 5:
                labels.append(cursor)
            cursor += timedelta(days=1)
        selected, boundary = month_package(labels, (2026, 8))
        self.assertEqual((selected[0].year, selected[0].month), (2026, 7))
        self.assertEqual((boundary.year, boundary.month), (2026, 6))

    def test_design_density_and_fixed_risk_are_bounded(self) -> None:
        rng = random.Random(20260823)
        for count in (17, 20, 23):
            qualified = 0
            trials = 20_000
            for _ in range(trials):
                returns = [rng.gauss(0.0, 1.0) for _ in range(count)]
                qualified += classify_returns(returns).direction != 0
            rate = qualified / trials
            self.assertGreater(rate, 0.47)
            self.assertLess(rate, 0.53)
        lots = aggregate_risk_lots(1000.0, 240.0, 0.01)
        self.assertLessEqual(lots * 240.0, 1000.0 + 1.0e-9)


if __name__ == "__main__":
    unittest.main()
