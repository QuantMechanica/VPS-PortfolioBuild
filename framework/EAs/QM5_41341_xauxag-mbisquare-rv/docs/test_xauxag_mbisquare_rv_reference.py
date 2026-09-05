"""Independent reference fixtures for QM5_41341 robust pair signal."""

import math
import unittest


MAD_NORMALIZER = 1.4826
BISQUARE_CUTOFF = 4.685
STEPS = 32
EPSILON = 1e-12


def bisquare_location(returns):
    if len(returns) != 12 or not all(math.isfinite(x) for x in returns):
        return None
    ordered = sorted(returns)
    median = 0.5 * (ordered[5] + ordered[6])
    deviations = sorted(abs(x - median) for x in returns)
    mad = 0.5 * (deviations[5] + deviations[6])
    cutoff = BISQUARE_CUTOFF * MAD_NORMALIZER * mad
    if not math.isfinite(cutoff) or cutoff <= 0:
        return None
    location = median
    for _ in range(STEPS):
        weights = []
        for value in returns:
            normalized = (value - location) / cutoff
            weight = (1.0 - normalized * normalized) ** 2 if abs(normalized) < 1.0 else 0.0
            weights.append(weight)
        total = sum(weights)
        if not math.isfinite(total) or total <= 0:
            return None
        location = sum(w * x for w, x in zip(weights, returns)) / total
        if not math.isfinite(location):
            return None
    return median, mad, cutoff, location


def pair_direction(returns):
    result = bisquare_location(returns)
    if result is None:
        return 0
    location = result[-1]
    if location > EPSILON:
        return -1  # sell XAU, buy XAG
    if location < -EPSILON:
        return 1  # buy XAU, sell XAG
    return 0


class XauXagBisquareReference(unittest.TestCase):
    def test_positive_center_is_faded_short_ratio(self):
        returns = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06,
                   0.07, 0.08, 0.09, 0.10, 0.11, 0.12]
        median, mad, cutoff, location = bisquare_location(returns)
        self.assertAlmostEqual(median, 0.065, places=15)
        self.assertAlmostEqual(mad, 0.03, places=15)
        self.assertAlmostEqual(cutoff, 0.20837943, places=12)
        self.assertAlmostEqual(location, 0.065, places=15)
        self.assertEqual(pair_direction(returns), -1)

    def test_negative_reflection_is_faded_long_ratio(self):
        returns = [-x for x in [0.01, 0.02, 0.03, 0.04, 0.05, 0.06,
                                0.07, 0.08, 0.09, 0.10, 0.11, 0.12]]
        self.assertAlmostEqual(bisquare_location(returns)[-1], -0.065, places=15)
        self.assertEqual(pair_direction(returns), 1)

    def test_remote_outlier_has_zero_tail_influence(self):
        returns = [0.006, 0.007, 0.008, 0.009, 0.010, 0.011,
                   0.012, 0.013, 0.014, 0.015, 0.016, -1.0]
        median, mad, cutoff, location = bisquare_location(returns)
        self.assertAlmostEqual(median, 0.0105, places=15)
        self.assertAlmostEqual(mad, 0.003, places=15)
        self.assertAlmostEqual(cutoff, 0.020837943, places=12)
        self.assertAlmostEqual(location, 0.011, places=15)
        self.assertEqual(pair_direction(returns), -1)

    def test_reflection_changes_only_pair_side(self):
        returns = [0.006, 0.007, 0.008, 0.009, 0.010, 0.011,
                   0.012, 0.013, 0.014, 0.015, 0.016, -1.0]
        reflected = [-x for x in returns]
        self.assertAlmostEqual(bisquare_location(reflected)[-1],
                               -bisquare_location(returns)[-1], places=15)
        self.assertEqual(pair_direction(reflected), -pair_direction(returns))

    def test_zero_mad_fails_closed(self):
        self.assertIsNone(bisquare_location([0.01] * 12))
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
