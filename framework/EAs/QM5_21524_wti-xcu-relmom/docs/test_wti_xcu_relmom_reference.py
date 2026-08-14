#!/usr/bin/env python3
"""Independent arithmetic checks for QM5_21524's locked signal contract."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timezone


WINDOW = 12
DEADBAND = 1.0e-10
MAX_ENDPOINT_AGE_DAYS = 10


@dataclass(frozen=True)
class Endpoint:
    month_key: int
    timestamp: int
    close: float


def previous_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year <= 0 or month < 1 or month > 12:
        raise ValueError("invalid month key")
    if month == 1:
        return (year - 1) * 100 + 12
    return year * 100 + month - 1


def month_keys_desc(latest: int, count: int) -> list[int]:
    keys = [latest]
    while len(keys) < count:
        keys.append(previous_month_key(keys[-1]))
    return keys


def direction_from_difference(difference: float) -> int:
    if not math.isfinite(difference):
        raise ValueError("nonfinite rank")
    if difference > DEADBAND:
        return 1
    if difference < -DEADBAND:
        return -1
    return 0


def average_simple_returns(endpoints: list[Endpoint]) -> float:
    if len(endpoints) != WINDOW + 1:
        raise ValueError("wrong endpoint count")
    total = 0.0
    for newer, older in zip(endpoints, endpoints[1:]):
        if older.month_key != previous_month_key(newer.month_key):
            raise ValueError("nonconsecutive month")
        if newer.timestamp <= older.timestamp:
            raise ValueError("nonchronological endpoint")
        if newer.close <= 0.0 or older.close <= 0.0:
            raise ValueError("invalid close")
        value = newer.close / older.close - 1.0
        if not math.isfinite(value):
            raise ValueError("nonfinite return")
        total += value
    return total / WINDOW


def signal(
    wti: list[Endpoint],
    xcu: list[Endpoint],
    decision_time: int,
    expected_latest_month: int,
) -> tuple[float, float, int]:
    if len(wti) != WINDOW + 1 or len(xcu) != WINDOW + 1:
        raise ValueError("wrong endpoint count")
    if wti[0].month_key != expected_latest_month:
        raise ValueError("wrong latest month")
    for left, right in zip(wti, xcu):
        if left.month_key != right.month_key or left.timestamp != right.timestamp:
            raise ValueError("unsynchronized endpoint")
        if left.timestamp >= decision_time:
            raise ValueError("current endpoint")
    age_seconds = decision_time - wti[0].timestamp
    if age_seconds < 0 or age_seconds > MAX_ENDPOINT_AGE_DAYS * 86400:
        raise ValueError("stale endpoint")
    wti_average = average_simple_returns(wti)
    xcu_average = average_simple_returns(xcu)
    return wti_average, xcu_average, direction_from_difference(wti_average - xcu_average)


def endpoints(latest_key: int, monthly_growth: float) -> list[Endpoint]:
    keys = month_keys_desc(latest_key, WINDOW + 1)
    values: list[Endpoint] = []
    for index, key in enumerate(keys):
        year, month = divmod(key, 100)
        timestamp = int(datetime(year, month, 28, tzinfo=timezone.utc).timestamp())
        close = 100.0 * (1.0 + monthly_growth) ** (WINDOW - index)
        values.append(Endpoint(key, timestamp, close))
    return values


class WtiXcuRelativeMomentumReferenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.decision_time = int(datetime(2026, 8, 1, tzinfo=timezone.utc).timestamp())
        self.wti = endpoints(202607, 0.02)
        self.xcu = endpoints(202607, 0.01)

    def test_january_rolls_to_prior_december(self) -> None:
        self.assertEqual(previous_month_key(202601), 202512)
        self.assertEqual(previous_month_key(202608), 202607)

    def test_higher_wti_average_buys_wti_and_sells_copper(self) -> None:
        wti_average, xcu_average, direction = signal(
            self.wti, self.xcu, self.decision_time, 202607
        )
        self.assertAlmostEqual(wti_average, 0.02, places=14)
        self.assertAlmostEqual(xcu_average, 0.01, places=14)
        self.assertEqual(direction, 1)

    def test_higher_copper_average_sells_wti_and_buys_copper(self) -> None:
        _, _, direction = signal(
            endpoints(202607, 0.005),
            endpoints(202607, 0.015),
            self.decision_time,
            202607,
        )
        self.assertEqual(direction, -1)

    def test_deadband_is_strict(self) -> None:
        self.assertEqual(direction_from_difference(DEADBAND), 0)
        self.assertEqual(direction_from_difference(-DEADBAND), 0)
        self.assertEqual(direction_from_difference(DEADBAND * 1.0001), 1)
        self.assertEqual(direction_from_difference(-DEADBAND * 1.0001), -1)

    def test_arithmetic_mean_uses_twelve_simple_monthly_returns(self) -> None:
        keys = month_keys_desc(202607, WINDOW + 1)
        returns = [0.10, -0.05] + [0.01] * 10
        closes_oldest_first = [100.0]
        for value in reversed(returns):
            closes_oldest_first.append(closes_oldest_first[-1] * (1.0 + value))
        closes = list(reversed(closes_oldest_first))
        sample = [
            Endpoint(
                key,
                int(datetime(*divmod(key, 100), 28, tzinfo=timezone.utc).timestamp()),
                close,
            )
            for key, close in zip(keys, closes)
        ]
        self.assertAlmostEqual(average_simple_returns(sample), sum(returns) / WINDOW, places=14)

    def test_timestamp_mismatch_fails_closed(self) -> None:
        broken = list(self.xcu)
        broken[3] = Endpoint(broken[3].month_key, broken[3].timestamp + 86400, broken[3].close)
        with self.assertRaisesRegex(ValueError, "unsynchronized"):
            signal(self.wti, broken, self.decision_time, 202607)

    def test_missing_month_fails_closed(self) -> None:
        broken = list(self.wti)
        broken[5] = Endpoint(previous_month_key(broken[5].month_key), broken[5].timestamp, broken[5].close)
        with self.assertRaisesRegex(ValueError, "nonconsecutive"):
            signal(broken, broken, self.decision_time, 202607)

    def test_stale_latest_endpoint_fails_closed(self) -> None:
        stale_decision = int(datetime(2026, 8, 20, tzinfo=timezone.utc).timestamp())
        with self.assertRaisesRegex(ValueError, "stale"):
            signal(self.wti, self.xcu, stale_decision, 202607)

    def test_fixed_risk_is_split_into_two_equal_halves(self) -> None:
        aggregate_risk = 1000.0
        weights = [1.0, 1.0]
        allocations = [aggregate_risk * weight / sum(weights) for weight in weights]
        self.assertEqual(allocations, [500.0, 500.0])


if __name__ == "__main__":
    unittest.main()
