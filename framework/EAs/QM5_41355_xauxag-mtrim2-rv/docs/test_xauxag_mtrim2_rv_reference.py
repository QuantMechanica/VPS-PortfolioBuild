"""Independent reference fixtures for QM5_41355 fixed-trim pair signal."""

import math
import unittest


TRIM_EACH_TAIL = 2
RETAINED_COUNT = 8
EPSILON = 1e-12


def trimmed_mean(returns):
    if len(returns) != 12 or not all(math.isfinite(x) for x in returns):
        return None
    ordered = sorted(returns)
    retained = ordered[TRIM_EACH_TAIL:len(ordered) - TRIM_EACH_TAIL]
    if len(retained) != RETAINED_COUNT:
        return None
    return sum(retained) / RETAINED_COUNT


def pair_direction(returns):
    location = trimmed_mean(returns)
    if location is None:
        return 0
    if location > EPSILON:
        return -1  # sell XAU, buy XAG
    if location < -EPSILON:
        return 1  # buy XAU, sell XAG
    return 0


def median(values):
    ordered = sorted(values)
    return 0.5 * (ordered[5] + ordered[6])


def hampel_location(returns):
    center = median(returns)
    deviations = sorted(abs(x - center) for x in returns)
    scale = 1.4826 * 0.5 * (deviations[5] + deviations[6])
    if scale <= 0:
        return None
    for _ in range(32):
        weights = []
        for value in returns:
            normalized = abs((value - center) / scale)
            if normalized <= 2.0:
                weight = 1.0
            elif normalized <= 4.0:
                weight = 2.0 / normalized
            elif normalized < 8.0:
                weight = 2.0 * (8.0 - normalized) / (4.0 * normalized)
            else:
                weight = 0.0
            weights.append(weight)
        center = sum(w * x for w, x in zip(weights, returns)) / sum(weights)
    return center


def bisquare_location(returns):
    center = median(returns)
    deviations = sorted(abs(x - center) for x in returns)
    cutoff = 4.685 * 1.4826 * 0.5 * (deviations[5] + deviations[6])
    if cutoff <= 0:
        return None
    for _ in range(32):
        weights = []
        for value in returns:
            u = (value - center) / cutoff
            weights.append((1.0 - u * u) ** 2 if abs(u) < 1.0 else 0.0)
        center = sum(w * x for w, x in zip(weights, returns)) / sum(weights)
    return center


class XauXagTrim2Reference(unittest.TestCase):
    def test_exact_two_per_tail_trim(self):
        returns = [12.0, 1.0, 8.0, 2.0, 11.0, 3.0,
                   10.0, 4.0, 9.0, 5.0, 7.0, 6.0]
        self.assertEqual(trimmed_mean(returns), 6.5)

    def test_positive_center_is_faded_short_ratio(self):
        returns = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06,
                   0.07, 0.08, 0.09, 0.10, 0.11, 0.12]
        self.assertAlmostEqual(trimmed_mean(returns), 0.065, places=15)
        self.assertEqual(pair_direction(returns), -1)

    def test_reflection_changes_only_pair_side(self):
        returns = [-0.044, 0.041, -0.039, 0.061, 0.052, -0.067,
                   -0.021, 0.018, 0.051, -0.038, 0.041, -0.074]
        reflected = [-x for x in returns]
        self.assertAlmostEqual(trimmed_mean(reflected),
                               -trimmed_mean(returns), places=15)
        self.assertEqual(pair_direction(reflected), -pair_direction(returns))

    def test_nearest_robust_neighbors_take_opposite_side(self):
        returns = [-0.044, 0.041, -0.039, 0.061, 0.052, -0.067,
                   -0.021, 0.018, 0.051, -0.038, 0.041, -0.074]
        self.assertAlmostEqual(trimmed_mean(returns), 0.001125, places=15)
        self.assertAlmostEqual(hampel_location(returns),
                               -0.001583333333333333, places=14)
        self.assertAlmostEqual(bisquare_location(returns),
                               -0.0012893570909377908, places=14)
        self.assertEqual(pair_direction(returns), -1)

    def test_exact_zero_consumes_flat(self):
        returns = [-0.06, -0.05, -0.04, -0.03, -0.02, -0.01,
                   0.01, 0.02, 0.03, 0.04, 0.05, 0.06]
        self.assertAlmostEqual(trimmed_mean(returns), 0.0, places=15)
        self.assertEqual(pair_direction(returns), 0)

    def test_invalid_values_fail_closed(self):
        self.assertIsNone(trimmed_mean([0.01] * 11))
        self.assertIsNone(trimmed_mean([0.01] * 11 + [math.nan]))

    def test_synchronized_log_ratio_return_identity(self):
        gold = [100.0, 110.0, 121.0]
        silver = [10.0, 10.5, 11.025]
        ratios = [math.log(g) - math.log(s) for g, s in zip(gold, silver)]
        returns = [ratios[i + 1] - ratios[i] for i in range(2)]
        direct = [math.log((gold[i + 1] / silver[i + 1]) /
                           (gold[i] / silver[i])) for i in range(2)]
        for actual, expected in zip(returns, direct):
            self.assertAlmostEqual(actual, expected, places=15)


if __name__ == "__main__":
    unittest.main()
