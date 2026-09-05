"""Independent reference fixtures for QM5_41348 robust pair signal."""

import math
import unittest


MAD_NORMALIZER = 1.4826
HAMPEL_A = 2.0
HAMPEL_B = 4.0
HAMPEL_C = 8.0
STEPS = 32
EPSILON = 1e-12


def hampel_weight(normalized):
    if not math.isfinite(normalized) or normalized < 0:
        return None
    if normalized <= HAMPEL_A:
        return 1.0
    if normalized <= HAMPEL_B:
        return HAMPEL_A / normalized
    if normalized < HAMPEL_C:
        return HAMPEL_A * (HAMPEL_C - normalized) / (
            (HAMPEL_C - HAMPEL_B) * normalized
        )
    return 0.0


def hampel_location(returns):
    if len(returns) != 12 or not all(math.isfinite(x) for x in returns):
        return None
    ordered = sorted(returns)
    median = 0.5 * (ordered[5] + ordered[6])
    deviations = sorted(abs(x - median) for x in returns)
    mad = 0.5 * (deviations[5] + deviations[6])
    scale = MAD_NORMALIZER * mad
    if not math.isfinite(scale) or scale <= 0:
        return None
    location = median
    for _ in range(STEPS):
        weights = []
        for value in returns:
            normalized = abs((value - location) / scale)
            weight = hampel_weight(normalized)
            if weight is None:
                return None
            weights.append(weight)
        total = sum(weights)
        if not math.isfinite(total) or total <= 0:
            return None
        location = sum(w * x for w, x in zip(weights, returns)) / total
        if not math.isfinite(location):
            return None
    return median, mad, scale, location


def bisquare_location(returns):
    ordered = sorted(returns)
    median = 0.5 * (ordered[5] + ordered[6])
    deviations = sorted(abs(x - median) for x in returns)
    cutoff = 4.685 * MAD_NORMALIZER * 0.5 * (deviations[5] + deviations[6])
    location = median
    for _ in range(STEPS):
        weights = []
        for value in returns:
            u = (value - location) / cutoff
            weights.append((1.0 - u * u) ** 2 if abs(u) < 1.0 else 0.0)
        location = sum(w * x for w, x in zip(weights, returns)) / sum(weights)
    return location


def pair_direction(returns):
    result = hampel_location(returns)
    if result is None:
        return 0
    location = result[-1]
    if location > EPSILON:
        return -1  # sell XAU, buy XAG
    if location < -EPSILON:
        return 1  # buy XAU, sell XAG
    return 0


class XauXagHampelReference(unittest.TestCase):
    def test_positive_center_is_faded_short_ratio(self):
        returns = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06,
                   0.07, 0.08, 0.09, 0.10, 0.11, 0.12]
        median, mad, scale, location = hampel_location(returns)
        self.assertAlmostEqual(median, 0.065, places=15)
        self.assertAlmostEqual(mad, 0.03, places=15)
        self.assertAlmostEqual(scale, 0.044478, places=12)
        self.assertAlmostEqual(location, 0.065, places=15)
        self.assertEqual(pair_direction(returns), -1)

    def test_negative_reflection_is_faded_long_ratio(self):
        returns = [-x for x in [0.01, 0.02, 0.03, 0.04, 0.05, 0.06,
                                0.07, 0.08, 0.09, 0.10, 0.11, 0.12]]
        self.assertAlmostEqual(hampel_location(returns)[-1], -0.065, places=15)
        self.assertEqual(pair_direction(returns), 1)

    def test_remote_outlier_has_zero_tail_influence(self):
        returns = [0.006, 0.007, 0.008, 0.009, 0.010, 0.011,
                   0.012, 0.013, 0.014, 0.015, 0.016, -1.0]
        median, mad, scale, location = hampel_location(returns)
        self.assertAlmostEqual(median, 0.0105, places=15)
        self.assertAlmostEqual(mad, 0.003, places=15)
        self.assertAlmostEqual(scale, 0.0044478, places=12)
        self.assertAlmostEqual(location, 0.011, places=15)
        self.assertEqual(pair_direction(returns), -1)

    def test_exact_hampel_boundaries(self):
        self.assertEqual(hampel_weight(0.0), 1.0)
        self.assertEqual(hampel_weight(2.0), 1.0)
        self.assertAlmostEqual(hampel_weight(3.0), 2.0 / 3.0)
        self.assertEqual(hampel_weight(4.0), 0.5)
        self.assertAlmostEqual(hampel_weight(6.0), 1.0 / 6.0)
        self.assertEqual(hampel_weight(8.0), 0.0)
        self.assertEqual(hampel_weight(9.0), 0.0)
        self.assertIsNone(hampel_weight(-1.0))

    def test_nearest_bisquare_neighbor_takes_opposite_side(self):
        returns = [-0.056, 0.061, -0.044, -0.046, -0.026, -0.010,
                   -0.017, -0.024, 0.067, 0.079, -0.035, 0.069]
        self.assertAlmostEqual(hampel_location(returns)[-1],
                               0.0010588545454545467, places=14)
        self.assertAlmostEqual(bisquare_location(returns),
                               -0.005703417790658595, places=14)
        self.assertEqual(pair_direction(returns), -1)

    def test_reflection_changes_only_pair_side(self):
        returns = [0.006, 0.007, 0.008, 0.009, 0.010, 0.011,
                   0.012, 0.013, 0.014, 0.015, 0.016, -1.0]
        reflected = [-x for x in returns]
        self.assertAlmostEqual(hampel_location(reflected)[-1],
                               -hampel_location(returns)[-1], places=15)
        self.assertEqual(pair_direction(reflected), -pair_direction(returns))

    def test_zero_mad_fails_closed(self):
        self.assertIsNone(hampel_location([0.01] * 12))
        self.assertEqual(pair_direction([0.01] * 12), 0)

    def test_synchronized_log_ratio_return_identity(self):
        gold = [100.0, 110.0, 121.0]
        silver = [10.0, 10.5, 11.025]
        ratios = [math.log(g) - math.log(s) for g, s in zip(gold, silver)]
        returns = [ratios[i + 1] - ratios[i] for i in range(2)]
        direct = [math.log((gold[i + 1] / silver[i + 1]) /
                           (gold[i] / silver[i])) for i in range(2)]
        self.assertEqual(len(returns), 2)
        for actual, expected in zip(returns, direct):
            self.assertAlmostEqual(actual, expected, places=15)


if __name__ == "__main__":
    unittest.main()

