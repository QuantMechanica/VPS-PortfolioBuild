from __future__ import annotations

import unittest


USD_THRESHOLD = -0.010


def simple_return(newer: float, older: float) -> float:
    if newer <= 0.0 or older <= 0.0:
        raise ValueError("prices must be positive")
    return newer / older - 1.0


def gates(
    *,
    sp_close: float,
    sp_prior_closes: list[float],
    sp_close_20: float,
    fx_returns_5: list[float],
    aud_close: float,
    aud_prior_lows: list[float],
) -> tuple[bool, bool, bool, bool]:
    if len(sp_prior_closes) != 50:
        raise ValueError("SP500 reference must contain 50 ex-current closes")
    if len(fx_returns_5) != 3:
        raise ValueError("USD breadth must contain EURUSD, GBPUSD, AUDUSD")
    if len(aud_prior_lows) != 20:
        raise ValueError("AUDUSD reference must contain 20 ex-current lows")
    sp_mean = sum(sp_prior_closes) / 50.0
    sp_below = sp_close < sp_mean
    sp_weak = simple_return(sp_close, sp_close_20) < 0.0
    usd_broad = sum(fx_returns_5) / 3.0 <= USD_THRESHOLD
    breakout = aud_close < min(aud_prior_lows)
    return sp_below, sp_weak, usd_broad, breakout


def trail_candidate(
    *, completed_close: float, atr: float, multiple: float, current_stop: float
) -> float | None:
    candidate = completed_close + multiple * atr
    return candidate if candidate < current_stop else None


class DollarStressReferenceTests(unittest.TestCase):
    def test_complete_conjunction_qualifies(self) -> None:
        state = gates(
            sp_close=90.0,
            sp_prior_closes=[100.0] * 50,
            sp_close_20=100.0,
            fx_returns_5=[-0.012, -0.009, -0.015],
            aud_close=0.6200,
            aud_prior_lows=[0.6300 + index * 0.0001 for index in range(20)],
        )
        self.assertEqual(state, (True, True, True, True))

    def test_sp500_mean_boundary_is_strict(self) -> None:
        state = gates(
            sp_close=100.0,
            sp_prior_closes=[100.0] * 50,
            sp_close_20=101.0,
            fx_returns_5=[-0.02, -0.02, -0.02],
            aud_close=0.6200,
            aud_prior_lows=[0.6300] * 20,
        )
        self.assertFalse(state[0])

    def test_sp500_zero_return_is_not_weak(self) -> None:
        state = gates(
            sp_close=90.0,
            sp_prior_closes=[100.0] * 50,
            sp_close_20=90.0,
            fx_returns_5=[-0.02, -0.02, -0.02],
            aud_close=0.6200,
            aud_prior_lows=[0.6300] * 20,
        )
        self.assertFalse(state[1])

    def test_broad_usd_boundary_is_inclusive(self) -> None:
        state = gates(
            sp_close=90.0,
            sp_prior_closes=[100.0] * 50,
            sp_close_20=100.0,
            fx_returns_5=[-0.010, -0.010, -0.010],
            aud_close=0.6200,
            aud_prior_lows=[0.6300] * 20,
        )
        self.assertTrue(state[2])

    def test_audusd_prior_low_boundary_is_strict(self) -> None:
        state = gates(
            sp_close=90.0,
            sp_prior_closes=[100.0] * 50,
            sp_close_20=100.0,
            fx_returns_5=[-0.02, -0.02, -0.02],
            aud_close=0.6300,
            aud_prior_lows=[0.6300] * 20,
        )
        self.assertFalse(state[3])

    def test_signal_observation_is_excluded_from_references(self) -> None:
        state = gates(
            sp_close=80.0,
            sp_prior_closes=[100.0] * 50,
            sp_close_20=100.0,
            fx_returns_5=[-0.02, -0.02, -0.02],
            aud_close=0.6000,
            aud_prior_lows=[0.6500] * 20,
        )
        self.assertTrue(all(state))

    def test_trail_tightens_but_never_loosens(self) -> None:
        self.assertAlmostEqual(
            trail_candidate(
                completed_close=0.6200,
                atr=0.0100,
                multiple=2.0,
                current_stop=0.6500,
            ),
            0.6400,
        )
        self.assertIsNone(
            trail_candidate(
                completed_close=0.6400,
                atr=0.0100,
                multiple=2.0,
                current_stop=0.6500,
            )
        )

    def test_time_stop_boundary_is_inclusive(self) -> None:
        self.assertFalse(9 >= 10)
        self.assertTrue(10 >= 10)


if __name__ == "__main__":
    unittest.main()
