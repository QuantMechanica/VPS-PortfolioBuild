"""Independent reference checks for QM5_21516's locked statistical contract."""

from __future__ import annotations

import math
import unittest


RETURN_DAYS = 63
CORRELATION_CEILING = 0.30
CORRELATION_TOLERANCE = 1.0e-12
TREND_MONTHS = 12


def simple_returns(closes: list[float]) -> list[float]:
    if len(closes) < 2:
        raise ValueError("at least two closes are required")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")
    return [next_value / prior_value - 1.0 for prior_value, next_value in zip(closes, closes[1:])]


def sample_pearson(xti_closes: list[float], xng_closes: list[float]) -> float:
    if len(xti_closes) != RETURN_DAYS + 1 or len(xng_closes) != RETURN_DAYS + 1:
        raise ValueError("exactly 64 synchronized closes are required")
    x_values = simple_returns(xti_closes)
    y_values = simple_returns(xng_closes)
    x_mean = math.fsum(x_values) / RETURN_DAYS
    y_mean = math.fsum(y_values) / RETURN_DAYS
    denominator = RETURN_DAYS - 1
    x_variance = math.fsum((value - x_mean) ** 2 for value in x_values) / denominator
    y_variance = math.fsum((value - y_mean) ** 2 for value in y_values) / denominator
    covariance = math.fsum(
        (x_value - x_mean) * (y_value - y_mean)
        for x_value, y_value in zip(x_values, y_values)
    ) / denominator
    if x_variance <= 0.0 or y_variance <= 0.0:
        raise ValueError("sample variance must be positive")
    correlation = covariance / math.sqrt(x_variance * y_variance)
    if not math.isfinite(correlation) or abs(correlation) > 1.0 + CORRELATION_TOLERANCE:
        raise ValueError("correlation is invalid")
    return max(-1.0, min(1.0, correlation))


def admitted(correlation: float) -> bool:
    if not math.isfinite(correlation):
        raise ValueError("correlation must be finite")
    return abs(correlation) <= CORRELATION_CEILING + CORRELATION_TOLERANCE


def twelve_month_trend(month_end_closes: list[float]) -> float:
    if len(month_end_closes) != TREND_MONTHS + 1:
        raise ValueError("exactly thirteen month-end closes are required")
    if any(not math.isfinite(value) or value <= 0.0 for value in month_end_closes):
        raise ValueError("month-end closes must be positive and finite")
    endpoint = math.log(month_end_closes[-1] / month_end_closes[0])
    chained = math.fsum(
        math.log(next_value / prior_value)
        for prior_value, next_value in zip(month_end_closes, month_end_closes[1:])
    )
    if not math.isclose(endpoint, chained, rel_tol=0.0, abs_tol=1.0e-10):
        raise AssertionError("endpoint and chained log returns disagree")
    return endpoint


def locked_signal(correlation: float, trend: float) -> int:
    if not admitted(correlation) or trend == 0.0:
        return 0
    return 1 if trend > 0.0 else -1


def closes_from_returns(values: list[float], start: float = 100.0) -> list[float]:
    closes = [start]
    for value in values:
        if value <= -1.0 or not math.isfinite(value):
            raise ValueError("invalid simple return")
        closes.append(closes[-1] * (1.0 + value))
    return closes


class DecoupledTrendReferenceTest(unittest.TestCase):
    def test_pearson_perfect_positive_and_negative(self) -> None:
        x = [0.001 * math.sin(index * 0.31) + 0.0002 * index for index in range(RETURN_DAYS)]
        positive = [2.0 * value + 0.0007 for value in x]
        negative = [-3.0 * value - 0.0004 for value in x]
        self.assertAlmostEqual(sample_pearson(closes_from_returns(x), closes_from_returns(positive)), 1.0, places=12)
        self.assertAlmostEqual(sample_pearson(closes_from_returns(x), closes_from_returns(negative)), -1.0, places=12)

    def test_sample_covariance_uses_n_minus_one(self) -> None:
        x = [0.0003 * index + 0.001 * math.sin(index) for index in range(RETURN_DAYS)]
        y = [0.0001 * index + 0.0013 * math.cos(index * 0.7) for index in range(RETURN_DAYS)]
        x_mean = math.fsum(x) / RETURN_DAYS
        y_mean = math.fsum(y) / RETURN_DAYS
        covariance = math.fsum((a - x_mean) * (b - y_mean) for a, b in zip(x, y)) / 62
        x_variance = math.fsum((a - x_mean) ** 2 for a in x) / 62
        y_variance = math.fsum((b - y_mean) ** 2 for b in y) / 62
        expected = covariance / math.sqrt(x_variance * y_variance)
        observed = sample_pearson(closes_from_returns(x), closes_from_returns(y))
        self.assertAlmostEqual(observed, expected, places=12)

    def test_absolute_threshold_is_symmetric_and_inclusive(self) -> None:
        self.assertTrue(admitted(CORRELATION_CEILING + CORRELATION_TOLERANCE))
        self.assertTrue(admitted(-CORRELATION_CEILING - CORRELATION_TOLERANCE))
        self.assertFalse(admitted(CORRELATION_CEILING + 2.0 * CORRELATION_TOLERANCE))
        self.assertFalse(admitted(-CORRELATION_CEILING - 2.0 * CORRELATION_TOLERANCE))

    def test_twelve_month_endpoint_and_direction(self) -> None:
        rising = [100.0, 96.0, 104.0, 101.0, 108.0, 103.0, 111.0, 109.0, 114.0, 112.0, 117.0, 116.0, 120.0]
        falling = list(reversed(rising))
        flat = [100.0, 120.0, 90.0, 130.0, 80.0, 105.0, 95.0, 115.0, 85.0, 125.0, 75.0, 110.0, 100.0]
        self.assertAlmostEqual(twelve_month_trend(rising), math.log(1.2), places=14)
        self.assertEqual(locked_signal(0.0, twelve_month_trend(rising)), 1)
        self.assertEqual(locked_signal(0.0, twelve_month_trend(falling)), -1)
        self.assertEqual(locked_signal(0.0, twelve_month_trend(flat)), 0)
        self.assertEqual(locked_signal(0.31, twelve_month_trend(rising)), 0)

    def test_exact_support_and_invalid_variance_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "exactly 64"):
            sample_pearson([100.0] * 63, [100.0] * 63)
        variable = closes_from_returns([0.001 * math.sin(index) for index in range(RETURN_DAYS)])
        with self.assertRaisesRegex(ValueError, "variance"):
            sample_pearson([100.0] * 64, variable)
        with self.assertRaisesRegex(ValueError, "thirteen"):
            twelve_month_trend([100.0] * 12)

    def test_read_only_state_never_changes_trend_carrier(self) -> None:
        wti_month_ends = [100.0 + 2.0 * index for index in range(13)]
        trend = twelve_month_trend(wti_month_ends)
        self.assertGreater(trend, 0.0)
        self.assertEqual(locked_signal(0.10, trend), 1)
        self.assertEqual(locked_signal(0.80, trend), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
