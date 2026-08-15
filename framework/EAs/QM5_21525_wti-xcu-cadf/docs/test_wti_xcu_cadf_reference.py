#!/usr/bin/env python3
"""Independent arithmetic and direction checks for QM5_21525."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass


LOOKBACK = 252
ENTRY_Z = 1.0
EXIT_Z = 0.5
CADF_T_MAX = -3.043
BETA_MIN = 0.10
BETA_MAX = 3.00
HALF_LIFE_MIN = 2.0
HALF_LIFE_MAX = 60.0
MAX_ENDPOINT_AGE_DAYS = 10


@dataclass(frozen=True)
class State:
    alpha: float
    beta: float
    sigma: float
    rho: float
    cadf_t: float
    half_life: float
    z_previous: float
    z_now: float
    ols_degrees_of_freedom: int
    adf_degrees_of_freedom: int


def estimate_state(
    wti: list[float],
    copper: list[float],
    wti_times: list[int],
    copper_times: list[int],
    current_host_time: int,
) -> State:
    """Mirror the EA's chronological OLS and simple residual CADF formulas."""

    if not all(len(values) == LOOKBACK for values in (wti, copper, wti_times, copper_times)):
        raise ValueError("wrong history count")
    if wti_times != copper_times:
        raise ValueError("unsynchronized history")
    if any(newer <= older for older, newer in zip(wti_times, wti_times[1:])):
        raise ValueError("nonchronological history")
    if wti_times[-1] >= current_host_time:
        raise ValueError("current endpoint")
    if current_host_time - wti_times[-1] > MAX_ENDPOINT_AGE_DAYS * 86400:
        raise ValueError("stale endpoint")
    if any(value <= 0.0 or not math.isfinite(value) for value in wti + copper):
        raise ValueError("invalid price")

    y = [math.log(value) for value in wti]
    x = [math.log(value) for value in copper]
    mean_x = sum(x) / LOOKBACK
    mean_y = sum(y) / LOOKBACK
    sxx = sum((value - mean_x) ** 2 for value in x)
    sxy = sum((x_value - mean_x) * (y_value - mean_y) for x_value, y_value in zip(x, y))
    if sxx <= 1.0e-20:
        raise ValueError("singular OLS")

    beta = sxy / sxx
    alpha = mean_y - beta * mean_x
    residuals = [y_value - alpha - beta * x_value for x_value, y_value in zip(x, y)]
    sigma = math.sqrt(sum(value * value for value in residuals) / (LOOKBACK - 2))
    if sigma <= 1.0e-10 or not math.isfinite(sigma):
        raise ValueError("invalid residual sigma")

    lags = residuals[:-1]
    deltas = [residuals[index] - residuals[index - 1] for index in range(1, LOOKBACK)]
    adf_count = LOOKBACK - 1
    mean_lag = sum(lags) / adf_count
    mean_delta = sum(deltas) / adf_count
    adf_sxx = sum((value - mean_lag) ** 2 for value in lags)
    adf_sxy = sum(
        (lag - mean_lag) * (delta - mean_delta)
        for lag, delta in zip(lags, deltas)
    )
    if adf_sxx <= 1.0e-20:
        raise ValueError("singular CADF")

    rho = adf_sxy / adf_sxx
    intercept = mean_delta - rho * mean_lag
    adf_sse = sum(
        (delta - intercept - rho * lag) ** 2
        for lag, delta in zip(lags, deltas)
    )
    rho_standard_error = math.sqrt((adf_sse / (adf_count - 2)) / adf_sxx)
    if rho_standard_error <= 0.0 or not math.isfinite(rho_standard_error):
        raise ValueError("invalid CADF standard error")

    cadf_t = rho / rho_standard_error
    phi = 1.0 + rho
    if phi <= 0.0 or phi >= 1.0:
        raise ValueError("invalid AR coefficient")
    half_life = -math.log(2.0) / math.log(phi)
    return State(
        alpha=alpha,
        beta=beta,
        sigma=sigma,
        rho=rho,
        cadf_t=cadf_t,
        half_life=half_life,
        z_previous=residuals[-2] / sigma,
        z_now=residuals[-1] / sigma,
        ols_degrees_of_freedom=LOOKBACK - 2,
        adf_degrees_of_freedom=adf_count - 2,
    )


def model_is_admissible(state: State) -> bool:
    return (
        BETA_MIN <= state.beta <= BETA_MAX
        and state.rho < 0.0
        and state.cadf_t <= CADF_T_MAX
        and HALF_LIFE_MIN <= state.half_life <= HALF_LIFE_MAX
    )


def entry_orders(z_previous: float, z_now: float) -> tuple[str, str] | None:
    if z_now > ENTRY_Z and z_previous <= ENTRY_Z:
        return "SELL_WTI", "BUY_COPPER"
    if z_now < -ENTRY_Z and z_previous >= -ENTRY_Z:
        return "BUY_WTI", "SELL_COPPER"
    return None


def risk_split(beta: float, aggregate_risk: float = 1000.0) -> tuple[float, float]:
    weight_sum = 1.0 + abs(beta)
    return aggregate_risk / weight_sum, aggregate_risk * abs(beta) / weight_sum


def synthetic_histories() -> tuple[list[float], list[float], list[int], int]:
    log_copper = [
        math.log(3.0) + 0.001 * index + 0.02 * math.sin(index * 0.07)
        for index in range(LOOKBACK)
    ]
    residual = 0.0
    residuals: list[float] = []
    for index in range(LOOKBACK):
        residual = (
            0.75 * residual
            + 0.01 * math.sin(index * 0.61)
            + 0.004 * math.cos(index * 0.29)
        )
        residuals.append(residual)
    copper = [math.exp(value) for value in log_copper]
    wti = [
        math.exp(1.5 + 1.2 * x_value + error)
        for x_value, error in zip(log_copper, residuals)
    ]
    timestamps = [1_700_000_000 + index * 86400 for index in range(LOOKBACK)]
    return wti, copper, timestamps, timestamps[-1] + 86400


class WtiXcuCadfReferenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.wti, self.copper, self.times, self.current = synthetic_histories()

    def test_locked_ols_and_cadf_state_is_admissible(self) -> None:
        state = estimate_state(self.wti, self.copper, self.times, self.times, self.current)
        self.assertAlmostEqual(state.beta, 1.1932885287274362, places=12)
        self.assertAlmostEqual(state.rho, -0.1365448566897133, places=12)
        self.assertAlmostEqual(state.cadf_t, -4.266395263437633, places=11)
        self.assertAlmostEqual(state.half_life, 4.721282320047161, places=11)
        self.assertTrue(model_is_admissible(state))

    def test_locked_degrees_of_freedom(self) -> None:
        state = estimate_state(self.wti, self.copper, self.times, self.times, self.current)
        self.assertEqual(state.ols_degrees_of_freedom, 250)
        self.assertEqual(state.adf_degrees_of_freedom, 249)

    def test_positive_fresh_cross_sells_wti_and_buys_copper(self) -> None:
        self.assertEqual(entry_orders(ENTRY_Z, ENTRY_Z + 1.0e-9), ("SELL_WTI", "BUY_COPPER"))

    def test_negative_fresh_cross_buys_wti_and_sells_copper(self) -> None:
        self.assertEqual(entry_orders(-ENTRY_Z, -ENTRY_Z - 1.0e-9), ("BUY_WTI", "SELL_COPPER"))

    def test_already_extreme_or_boundary_state_does_not_enter(self) -> None:
        self.assertIsNone(entry_orders(ENTRY_Z + 0.1, ENTRY_Z + 0.2))
        self.assertIsNone(entry_orders(ENTRY_Z - 0.1, ENTRY_Z))
        self.assertIsNone(entry_orders(-ENTRY_Z - 0.1, -ENTRY_Z - 0.2))
        self.assertIsNone(entry_orders(-ENTRY_Z + 0.1, -ENTRY_Z))

    def test_convergence_boundary_is_inclusive(self) -> None:
        self.assertTrue(abs(EXIT_Z) <= EXIT_Z)
        self.assertTrue(abs(-EXIT_Z) <= EXIT_Z)
        self.assertFalse(abs(EXIT_Z + 1.0e-9) <= EXIT_Z)

    def test_aggregate_fixed_risk_uses_unit_and_beta_weights(self) -> None:
        wti_risk, copper_risk = risk_split(2.0)
        self.assertAlmostEqual(wti_risk, 1000.0 / 3.0)
        self.assertAlmostEqual(copper_risk, 2000.0 / 3.0)
        self.assertAlmostEqual(wti_risk + copper_risk, 1000.0)

    def test_timestamp_mismatch_fails_closed(self) -> None:
        copper_times = list(self.times)
        copper_times[100] += 1
        with self.assertRaisesRegex(ValueError, "unsynchronized"):
            estimate_state(self.wti, self.copper, self.times, copper_times, self.current)

    def test_stale_endpoint_fails_closed(self) -> None:
        stale_current = self.times[-1] + 11 * 86400
        with self.assertRaisesRegex(ValueError, "stale"):
            estimate_state(self.wti, self.copper, self.times, self.times, stale_current)

    def test_nonpositive_price_fails_closed(self) -> None:
        broken = list(self.wti)
        broken[17] = 0.0
        with self.assertRaisesRegex(ValueError, "invalid price"):
            estimate_state(broken, self.copper, self.times, self.times, self.current)


if __name__ == "__main__":
    unittest.main()
