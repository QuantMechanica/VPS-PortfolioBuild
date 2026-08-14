#!/usr/bin/env python3
"""Independent arithmetic checks for QM5_21517's locked signal contract."""

from __future__ import annotations

import math
import statistics
import unittest


ENTRY_Z = 0.5
EPSILON = 1.0e-10
MIN_SAMPLES = 5
VARIANCE_EPSILON = 1.0e-16


def previous_month(year: int, month: int) -> tuple[int, int]:
    if month == 1:
        return year - 1, 12
    return year, month - 1


def surprise_signal(samples: list[float], realized: float) -> tuple[float, int]:
    if len(samples) < MIN_SAMPLES:
        raise ValueError("insufficient same-calendar history")
    mean = sum(samples) / len(samples)
    variance = sum((value - mean) ** 2 for value in samples) / (len(samples) - 1)
    if not math.isfinite(variance) or variance <= VARIANCE_EPSILON:
        raise ValueError("invalid sample variance")
    z_value = (realized - mean) / math.sqrt(variance)
    if z_value > ENTRY_Z + EPSILON:
        return z_value, -1  # SELL XAU / BUY XAG
    if z_value < -ENTRY_Z - EPSILON:
        return z_value, 1  # BUY XAU / SELL XAG
    return z_value, 0


class SeasonalSurpriseReferenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.samples = [-0.02, -0.01, 0.0, 0.01, 0.02]

    def test_sample_standard_deviation_uses_n_minus_one(self) -> None:
        mean = sum(self.samples) / len(self.samples)
        variance = sum((value - mean) ** 2 for value in self.samples) / 4
        self.assertAlmostEqual(math.sqrt(variance), statistics.stdev(self.samples), places=15)

    def test_positive_surprise_is_faded_with_short_xau(self) -> None:
        z_value, direction = surprise_signal(self.samples, 0.02)
        self.assertGreater(z_value, ENTRY_Z)
        self.assertEqual(direction, -1)

    def test_negative_surprise_is_faded_with_long_xau(self) -> None:
        z_value, direction = surprise_signal(self.samples, -0.02)
        self.assertLess(z_value, -ENTRY_Z)
        self.assertEqual(direction, 1)

    def test_threshold_is_strict_and_epsilon_guarded(self) -> None:
        sd = statistics.stdev(self.samples)
        self.assertEqual(surprise_signal(self.samples, ENTRY_Z * sd)[1], 0)
        self.assertEqual(surprise_signal(self.samples, (ENTRY_Z + EPSILON) * sd)[1], 0)
        self.assertEqual(surprise_signal(self.samples, (ENTRY_Z + 2 * EPSILON) * sd)[1], -1)

    def test_inside_band_consumes_flat(self) -> None:
        z_value, direction = surprise_signal(self.samples, 0.0)
        self.assertAlmostEqual(z_value, 0.0, places=15)
        self.assertEqual(direction, 0)

    def test_zero_variance_fails_closed(self) -> None:
        with self.assertRaises(ValueError):
            surprise_signal([0.01] * 5, 0.02)

    def test_fewer_than_five_samples_fails_closed(self) -> None:
        with self.assertRaises(ValueError):
            surprise_signal(self.samples[:4], 0.02)

    def test_january_decision_maps_to_prior_december(self) -> None:
        self.assertEqual(previous_month(2026, 1), (2025, 12))
        self.assertEqual(previous_month(2026, 8), (2026, 7))


if __name__ == "__main__":
    unittest.main()
