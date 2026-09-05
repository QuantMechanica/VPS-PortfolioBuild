"""Independent reference checks for QM5_41340's locked signal contract."""

from __future__ import annotations

import math
import unittest


TREND_MONTHS = 12
SIGN_EPSILON = 1.0e-12
CHAIN_TOLERANCE = 1.0e-10


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
    if not math.isclose(endpoint, chained, rel_tol=0.0, abs_tol=CHAIN_TOLERANCE):
        raise AssertionError("endpoint and chained log returns disagree")
    return endpoint


def sign(value: float) -> int:
    if not math.isfinite(value):
        raise ValueError("return must be finite")
    if value > SIGN_EPSILON:
        return 1
    if value < -SIGN_EPSILON:
        return -1
    return 0


def locked_signal(wti_return: float, xng_return: float) -> int:
    wti_sign = sign(wti_return)
    xng_sign = sign(xng_return)
    if wti_sign == 0 or xng_sign == 0 or wti_sign == xng_sign:
        return 0
    return wti_sign


class WtiXngDivergenceReferenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.rising = [100.0, 96.0, 104.0, 101.0, 108.0, 103.0, 111.0,
                       109.0, 114.0, 112.0, 117.0, 116.0, 120.0]
        self.falling = list(reversed(self.rising))
        self.flat = [100.0, 120.0, 90.0, 130.0, 80.0, 105.0, 95.0,
                     115.0, 85.0, 125.0, 75.0, 110.0, 100.0]

    def test_wti_up_xng_down_is_long(self) -> None:
        self.assertEqual(
            locked_signal(twelve_month_return(self.rising),
                          twelve_month_return(self.falling)),
            1,
        )

    def test_wti_down_xng_up_is_short(self) -> None:
        self.assertEqual(
            locked_signal(twelve_month_return(self.falling),
                          twelve_month_return(self.rising)),
            -1,
        )

    def test_agreeing_signs_are_flat(self) -> None:
        positive = twelve_month_return(self.rising)
        negative = twelve_month_return(self.falling)
        self.assertEqual(locked_signal(positive, positive), 0)
        self.assertEqual(locked_signal(negative, negative), 0)

    def test_either_tie_is_flat(self) -> None:
        tied = twelve_month_return(self.flat)
        self.assertEqual(tied, 0.0)
        self.assertEqual(locked_signal(twelve_month_return(self.rising), tied), 0)
        self.assertEqual(locked_signal(tied, twelve_month_return(self.falling)), 0)
        self.assertEqual(locked_signal(SIGN_EPSILON, -0.1), 0)
        self.assertEqual(locked_signal(0.1, -SIGN_EPSILON), 0)

    def test_endpoint_and_chain_identity(self) -> None:
        self.assertAlmostEqual(
            twelve_month_return(self.rising), math.log(1.2), places=14
        )

    def test_invalid_support_and_prices_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "thirteen"):
            twelve_month_return([100.0] * 12)
        invalid = self.rising.copy()
        invalid[6] = 0.0
        with self.assertRaisesRegex(ValueError, "positive"):
            twelve_month_return(invalid)
        with self.assertRaisesRegex(ValueError, "finite"):
            locked_signal(math.nan, -0.1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
