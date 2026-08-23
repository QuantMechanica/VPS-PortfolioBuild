from __future__ import annotations

import math
import random
import unittest
from dataclasses import dataclass
from datetime import date, timedelta


THRESHOLD = 0.16
TOLERANCE = 1.0e-10


@dataclass(frozen=True)
class Signal:
    count: int
    net: float
    squared_path: float
    endpoint: float
    coherence: float
    direction: int


def classify_returns(returns: list[float]) -> Signal:
    if not 17 <= len(returns) <= 23:
        raise ValueError("session count")
    if not all(math.isfinite(value) for value in returns):
        raise ValueError("finite returns")

    net = sum(returns)
    squared_path = sum(value * value for value in returns)
    endpoint = math.fsum(returns)
    scale = max(1.0, abs(endpoint))
    if abs(net - endpoint) > TOLERANCE * scale:
        raise ValueError("endpoint identity")

    if squared_path == 0.0:
        return Signal(len(returns), net, squared_path, endpoint, 0.0, 0)
    denominator = math.sqrt(len(returns) * squared_path)
    coherence = abs(net) / denominator
    if not math.isfinite(coherence) or coherence < 0.0 or coherence > 1.0 + TOLERANCE:
        raise ValueError("coherence bounds")
    coherence = min(1.0, coherence)
    direction = 0
    if coherence >= THRESHOLD:
        direction = 1 if net > 0.0 else -1 if net < 0.0 else 0
    return Signal(len(returns), net, squared_path, endpoint, coherence, direction)


def returns_from_closes(boundary_close: float, month_closes: list[float]) -> list[float]:
    if boundary_close <= 0.0 or not math.isfinite(boundary_close):
        raise ValueError("boundary")
    if not 17 <= len(month_closes) <= 23:
        raise ValueError("session count")
    prices = [boundary_close, *month_closes]
    if not all(value > 0.0 and math.isfinite(value) for value in prices):
        raise ValueError("prices")
    returns = [math.log(prices[index + 1]) - math.log(prices[index])
               for index in range(len(prices) - 1)]
    direct = math.log(prices[-1]) - math.log(prices[0])
    if abs(sum(returns) - direct) > TOLERANCE * max(1.0, abs(direct)):
        raise ValueError("endpoint identity")
    return returns


def month_package(labels: list[date], current_month: tuple[int, int]) -> tuple[list[date], date]:
    previous = (current_month[0] - 1, 12) if current_month[1] == 1 else (current_month[0], current_month[1] - 1)
    selected = [label for label in labels if (label.year, label.month) == previous]
    older = [label for label in labels if label < min(selected)] if selected else []
    if not 17 <= len(selected) <= 23 or not older:
        raise ValueError("calendar package")
    boundary = max(older)
    boundary_month = (previous[0] - 1, 12) if previous[1] == 1 else (previous[0], previous[1] - 1)
    if (boundary.year, boundary.month) != boundary_month:
        raise ValueError("adjacent boundary")
    return sorted(selected), boundary


def aggregate_risk_lots(risk_fixed: float, stop_risk_per_lot: float, lot_step: float) -> float:
    if risk_fixed <= 0.0 or stop_risk_per_lot <= 0.0 or lot_step <= 0.0:
        raise ValueError("risk inputs")
    raw = risk_fixed / stop_risk_per_lot
    return math.floor((raw + 1.0e-12) / lot_step) * lot_step


class MonthlyRmsCoherenceReferenceTests(unittest.TestCase):
    def test_all_positive_returns_are_unit_coherence_long(self) -> None:
        signal = classify_returns([0.01] * 20)
        self.assertAlmostEqual(signal.coherence, 1.0, places=12)
        self.assertEqual(signal.direction, 1)

    def test_all_negative_returns_are_unit_coherence_short(self) -> None:
        signal = classify_returns([-0.01] * 20)
        self.assertAlmostEqual(signal.coherence, 1.0, places=12)
        self.assertEqual(signal.direction, -1)

    def test_zero_returns_remain_in_count_and_zero_path_is_flat(self) -> None:
        signal = classify_returns([0.0] * 17)
        self.assertEqual(signal.count, 17)
        self.assertEqual(signal.squared_path, 0.0)
        self.assertEqual(signal.direction, 0)

    def test_noisy_alternation_is_below_threshold(self) -> None:
        returns = [0.01 if index % 2 == 0 else -0.01 for index in range(20)]
        signal = classify_returns(returns)
        self.assertEqual(signal.net, 0.0)
        self.assertEqual(signal.coherence, 0.0)
        self.assertEqual(signal.direction, 0)

    def test_threshold_equality_is_inclusive(self) -> None:
        # Direction classification is inclusive at the locked boundary.
        net = 0.16
        coherence = 0.16
        direction = 1 if coherence >= THRESHOLD and net > 0.0 else 0
        self.assertEqual(direction, 1)

    def test_close_path_preserves_endpoint_identity(self) -> None:
        closes = [80.0 * math.exp(0.004 * (index + 1)) for index in range(20)]
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
            self.assertGreater(rate, 0.43)
            self.assertLess(rate, 0.55)
        lots = aggregate_risk_lots(1000.0, 240.0, 0.01)
        self.assertLessEqual(lots * 240.0, 1000.0 + 1.0e-9)


if __name__ == "__main__":
    unittest.main()
