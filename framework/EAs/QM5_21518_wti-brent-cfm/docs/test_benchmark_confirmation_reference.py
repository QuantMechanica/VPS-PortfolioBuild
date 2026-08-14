"""Independent reference checks for QM5_21518's locked signal contract."""

from __future__ import annotations

import math
import unittest


TREND_MONTHS = 12
RETURN_TOLERANCE = 1.0e-10


def twelve_month_return(month_end_closes: list[float]) -> float:
    if len(month_end_closes) != TREND_MONTHS + 1:
        raise ValueError("exactly thirteen month-end closes are required")
    if any(not math.isfinite(value) or value <= 0.0 for value in month_end_closes):
        raise ValueError("month-end closes must be positive and finite")
    endpoint = math.log(month_end_closes[-1] / month_end_closes[0])
    chained = math.fsum(
        math.log(next_value / prior_value)
        for prior_value, next_value in zip(month_end_closes, month_end_closes[1:])
    )
    if not math.isclose(endpoint, chained, rel_tol=0.0, abs_tol=RETURN_TOLERANCE):
        raise AssertionError("endpoint and chained log returns disagree")
    return endpoint


def next_month(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if not 1 <= month <= 12:
        raise ValueError("invalid month key")
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_synchronized_months(wti_keys: list[int], brent_keys: list[int]) -> None:
    if len(wti_keys) != TREND_MONTHS + 1 or len(brent_keys) != TREND_MONTHS + 1:
        raise ValueError("exactly thirteen synchronized month keys are required")
    if wti_keys != brent_keys:
        raise ValueError("benchmark month keys must match exactly")
    if any(observed != next_month(prior) for prior, observed in zip(wti_keys, wti_keys[1:])):
        raise ValueError("month keys must be consecutive")


def benchmark_signal(wti_return: float, brent_return: float) -> int:
    if not math.isfinite(wti_return) or not math.isfinite(brent_return):
        raise ValueError("returns must be finite")
    if wti_return == 0.0 or brent_return == 0.0:
        return 0
    if (wti_return > 0.0) != (brent_return > 0.0):
        return 0
    return 1 if wti_return > 0.0 else -1


class BenchmarkConfirmationReferenceTest(unittest.TestCase):
    def test_same_sign_matrix_is_strict(self) -> None:
        self.assertEqual(benchmark_signal(0.2, 0.1), 1)
        self.assertEqual(benchmark_signal(-0.2, -0.1), -1)
        self.assertEqual(benchmark_signal(0.2, -0.1), 0)
        self.assertEqual(benchmark_signal(-0.2, 0.1), 0)
        self.assertEqual(benchmark_signal(0.0, 0.1), 0)
        self.assertEqual(benchmark_signal(-0.1, 0.0), 0)

    def test_independent_returns_determine_wti_direction(self) -> None:
        wti_rising = [100.0, 98.0, 103.0, 101.0, 106.0, 104.0, 109.0, 108.0, 112.0, 111.0, 116.0, 115.0, 120.0]
        brent_rising = [80.0, 79.0, 82.0, 81.0, 84.0, 83.0, 86.0, 85.0, 88.0, 87.0, 90.0, 89.0, 92.0]
        self.assertEqual(
            benchmark_signal(twelve_month_return(wti_rising), twelve_month_return(brent_rising)),
            1,
        )
        self.assertEqual(
            benchmark_signal(twelve_month_return(list(reversed(wti_rising))), twelve_month_return(list(reversed(brent_rising)))),
            -1,
        )

    def test_disagreement_consumes_month_flat(self) -> None:
        wti = [100.0 + index for index in range(13)]
        brent = [100.0 - index for index in range(13)]
        self.assertEqual(benchmark_signal(twelve_month_return(wti), twelve_month_return(brent)), 0)

    def test_exact_support_and_invalid_prices_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "thirteen"):
            twelve_month_return([100.0] * 12)
        with self.assertRaisesRegex(ValueError, "positive"):
            twelve_month_return([100.0] * 12 + [0.0])

    def test_month_keys_are_synchronized_and_consecutive(self) -> None:
        keys = [202512, 202601, 202602, 202603, 202604, 202605, 202606, 202607, 202608, 202609, 202610, 202611, 202612]
        validate_synchronized_months(keys, list(keys))
        with self.assertRaisesRegex(ValueError, "match"):
            validate_synchronized_months(keys, keys[:-1] + [202701])
        with self.assertRaisesRegex(ValueError, "consecutive"):
            validate_synchronized_months(keys[:-1] + [202702], keys[:-1] + [202702])

    def test_read_only_brent_magnitude_never_sizes_or_inverts_wti(self) -> None:
        self.assertEqual(benchmark_signal(0.01, 0.50), 1)
        self.assertEqual(benchmark_signal(-0.01, -0.50), -1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
