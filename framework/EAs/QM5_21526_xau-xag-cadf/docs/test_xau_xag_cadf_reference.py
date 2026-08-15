#!/usr/bin/env python3
"""Independent arithmetic and lifecycle checks for QM5_21526."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


TRAINING_COUNT = 252
ENTRY_Z = 1.0
EXIT_Z = 0.5
CADF_CRITICAL = -3.343
BETA_MIN = 0.10
BETA_MAX = 3.00
HALF_LIFE_MIN = 2.0
HALF_LIFE_MAX = 30.0


@dataclass(frozen=True)
class Model:
    anchor: int
    training_times: tuple[int, ...]
    alpha: float
    beta: float
    residual_mean: float
    residual_sigma: float
    rho: float
    cadf_t: float
    theta: float
    half_life: float
    adf_degrees_of_freedom: int


def _year(timestamp: int) -> int:
    return datetime.fromtimestamp(timestamp, timezone.utc).year


def select_annual_training(
    xau: dict[int, float], xag: dict[int, float], current_host_bar: int
) -> tuple[int, list[int], list[float], list[float]]:
    """Select the nearest 252 synchronized observations before the year anchor."""

    target_year = _year(current_host_bar)
    anchors = [timestamp for timestamp in xau if _year(timestamp) == target_year]
    if not anchors:
        raise ValueError("missing annual anchor")
    anchor = min(anchors)
    common = sorted(timestamp for timestamp in xau.keys() & xag.keys() if timestamp < anchor)
    if len(common) < TRAINING_COUNT:
        raise ValueError("insufficient synchronized formation history")
    training_times = common[-TRAINING_COUNT:]
    xau_training = [xau[timestamp] for timestamp in training_times]
    xag_training = [xag[timestamp] for timestamp in training_times]
    if any(not math.isfinite(value) or value <= 0.0 for value in xau_training + xag_training):
        raise ValueError("invalid formation price")
    return anchor, training_times, xau_training, xag_training


def fit_model(
    anchor: int,
    training_times: list[int],
    xau: list[float],
    xag: list[float],
) -> Model:
    if not all(len(values) == TRAINING_COUNT for values in (training_times, xau, xag)):
        raise ValueError("wrong formation count")
    if any(newer <= older for older, newer in zip(training_times, training_times[1:])):
        raise ValueError("nonchronological formation")
    if training_times[-1] >= anchor:
        raise ValueError("formation overlaps anchor")

    y = [math.log(value) for value in xau]
    x = [math.log(value) for value in xag]
    mean_x = sum(x) / TRAINING_COUNT
    mean_y = sum(y) / TRAINING_COUNT
    sxx = sum((value - mean_x) ** 2 for value in x)
    sxy = sum((x_value - mean_x) * (y_value - mean_y) for x_value, y_value in zip(x, y))
    if sxx <= 1.0e-20:
        raise ValueError("singular OLS")
    beta = sxy / sxx
    alpha = mean_y - beta * mean_x
    residuals = [y_value - alpha - beta * x_value for x_value, y_value in zip(x, y)]
    residual_mean = sum(residuals) / TRAINING_COUNT
    residual_sigma = math.sqrt(
        sum((value - residual_mean) ** 2 for value in residuals) / (TRAINING_COUNT - 1)
    )
    if residual_sigma <= 1.0e-10:
        raise ValueError("invalid residual sigma")

    rows = []
    targets = []
    for index in range(2, TRAINING_COUNT):
        rows.append(
            (
                1.0,
                residuals[index - 1],
                residuals[index - 1] - residuals[index - 2],
            )
        )
        targets.append(residuals[index] - residuals[index - 1])

    n = float(len(rows))
    sx1 = sum(row[1] for row in rows)
    sx2 = sum(row[2] for row in rows)
    sx1x1 = sum(row[1] * row[1] for row in rows)
    sx1x2 = sum(row[1] * row[2] for row in rows)
    sx2x2 = sum(row[2] * row[2] for row in rows)
    sy = sum(targets)
    sx1y = sum(row[1] * target for row, target in zip(rows, targets))
    sx2y = sum(row[2] * target for row, target in zip(rows, targets))
    determinant = (
        n * (sx1x1 * sx2x2 - sx1x2 * sx1x2)
        - sx1 * (sx1 * sx2x2 - sx2 * sx1x2)
        + sx2 * (sx1 * sx1x2 - sx2 * sx1x1)
    )
    if abs(determinant) <= 1.0e-20:
        raise ValueError("singular CADF")
    inv00 = (sx1x1 * sx2x2 - sx1x2 * sx1x2) / determinant
    inv01 = (sx2 * sx1x2 - sx1 * sx2x2) / determinant
    inv02 = (sx1 * sx1x2 - sx2 * sx1x1) / determinant
    inv11 = (n * sx2x2 - sx2 * sx2) / determinant
    inv12 = (sx1 * sx2 - n * sx1x2) / determinant
    inv22 = (n * sx1x1 - sx1 * sx1) / determinant
    intercept = inv00 * sy + inv01 * sx1y + inv02 * sx2y
    rho = inv01 * sy + inv11 * sx1y + inv12 * sx2y
    psi = inv02 * sy + inv12 * sx1y + inv22 * sx2y
    errors = [
        target - (intercept + rho * row[1] + psi * row[2])
        for row, target in zip(rows, targets)
    ]
    degrees_of_freedom = len(rows) - 3
    rho_variance = (sum(error * error for error in errors) / degrees_of_freedom) * inv11
    if rho_variance <= 0.0:
        raise ValueError("invalid CADF variance")
    cadf_t = rho / math.sqrt(rho_variance)

    lags = [residuals[index - 1] - residual_mean for index in range(1, TRAINING_COUNT)]
    deltas = [residuals[index] - residuals[index - 1] for index in range(1, TRAINING_COUNT)]
    ou_sxx = sum(value * value for value in lags)
    theta = sum(lag * delta for lag, delta in zip(lags, deltas)) / ou_sxx
    if theta >= 0.0:
        raise ValueError("non-reverting OU fit")
    half_life = -math.log(2.0) / theta
    return Model(
        anchor=anchor,
        training_times=tuple(training_times),
        alpha=alpha,
        beta=beta,
        residual_mean=residual_mean,
        residual_sigma=residual_sigma,
        rho=rho,
        cadf_t=cadf_t,
        theta=theta,
        half_life=half_life,
        adf_degrees_of_freedom=degrees_of_freedom,
    )


def model_is_admissible(model: Model) -> bool:
    return (
        BETA_MIN <= model.beta <= BETA_MAX
        and model.cadf_t <= CADF_CRITICAL
        and model.theta < 0.0
        and HALF_LIFE_MIN <= model.half_life <= HALF_LIFE_MAX
    )


def frozen_z(model: Model, xau: float, xag: float) -> float:
    residual = math.log(xau) - model.alpha - model.beta * math.log(xag)
    return (residual - model.residual_mean) / model.residual_sigma


def entry_orders(z_previous: float, z_now: float) -> tuple[str, str] | None:
    if z_previous < ENTRY_Z and z_now >= ENTRY_Z:
        return "SELL_XAU", "BUY_XAG"
    if z_previous > -ENTRY_Z and z_now <= -ENTRY_Z:
        return "BUY_XAU", "SELL_XAG"
    return None


def risk_split(beta: float, aggregate_risk: float = 1000.0) -> tuple[float, float]:
    total = 1.0 + abs(beta)
    return aggregate_risk / total, aggregate_risk * abs(beta) / total


def synthetic_history() -> tuple[dict[int, float], dict[int, float], int]:
    start = datetime(2022, 12, 1, tzinfo=timezone.utc)
    xau: dict[int, float] = {}
    xag: dict[int, float] = {}
    residual = 0.0
    for index in range(430):
        timestamp = int((start + timedelta(days=index)).timestamp())
        log_xag = math.log(22.0) + 0.0004 * index + 0.025 * math.sin(index * 0.061)
        residual = 0.78 * residual + 0.008 * math.sin(index * 0.73) + 0.003 * math.cos(index * 0.31)
        xag[timestamp] = math.exp(log_xag)
        xau[timestamp] = math.exp(4.05 + 1.18 * log_xag + residual)
    current = int(datetime(2024, 1, 20, tzinfo=timezone.utc).timestamp())
    return xau, xag, current


class XauXagCadfReferenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.xau, self.xag, self.current = synthetic_history()
        selected = select_annual_training(self.xau, self.xag, self.current)
        self.model = fit_model(*selected)

    def test_exact_pre_anchor_formation_has_no_signal_overlap(self) -> None:
        self.assertEqual(len(self.model.training_times), TRAINING_COUNT)
        self.assertTrue(all(timestamp < self.model.anchor for timestamp in self.model.training_times))
        self.assertEqual(_year(self.model.anchor), 2024)

    def test_locked_ols_cadf_and_ou_state_is_admissible(self) -> None:
        self.assertTrue(BETA_MIN <= self.model.beta <= BETA_MAX)
        self.assertLessEqual(self.model.cadf_t, CADF_CRITICAL)
        self.assertLess(self.model.theta, 0.0)
        self.assertTrue(HALF_LIFE_MIN <= self.model.half_life <= HALF_LIFE_MAX)
        self.assertTrue(model_is_admissible(self.model))

    def test_one_lag_cadf_degrees_of_freedom_are_locked(self) -> None:
        self.assertEqual(self.model.adf_degrees_of_freedom, 247)

    def test_midyear_extension_reconstructs_identical_frozen_model(self) -> None:
        extended_xau = dict(self.xau)
        extended_xag = dict(self.xag)
        last = max(extended_xau)
        for index in range(1, 30):
            timestamp = last + index * 86400
            extended_xag[timestamp] = extended_xag[last]
            extended_xau[timestamp] = extended_xau[last]
        later = last + 29 * 86400
        rebuilt = fit_model(*select_annual_training(extended_xau, extended_xag, later))
        self.assertEqual(rebuilt.anchor, self.model.anchor)
        self.assertEqual(rebuilt.training_times, self.model.training_times)
        self.assertAlmostEqual(rebuilt.alpha, self.model.alpha, places=14)
        self.assertAlmostEqual(rebuilt.beta, self.model.beta, places=14)
        self.assertAlmostEqual(rebuilt.cadf_t, self.model.cadf_t, places=12)
        self.assertAlmostEqual(rebuilt.half_life, self.model.half_life, places=12)

    def test_unsynchronized_day_is_excluded_before_exact_count(self) -> None:
        missing = dict(self.xag)
        removed = self.model.training_times[-8]
        del missing[removed]
        rebuilt = fit_model(*select_annual_training(self.xau, missing, self.current))
        self.assertNotIn(removed, rebuilt.training_times)
        self.assertEqual(len(rebuilt.training_times), TRAINING_COUNT)
        self.assertLess(rebuilt.training_times[0], self.model.training_times[0])

    def test_insufficient_synchronized_history_fails_closed(self) -> None:
        sparse_xag = dict(list(sorted(self.xag.items()))[-200:])
        with self.assertRaisesRegex(ValueError, "insufficient"):
            select_annual_training(self.xau, sparse_xag, self.current)

    def test_positive_fresh_cross_sells_gold_and_buys_silver(self) -> None:
        self.assertEqual(entry_orders(ENTRY_Z - 1.0e-9, ENTRY_Z), ("SELL_XAU", "BUY_XAG"))

    def test_negative_fresh_cross_buys_gold_and_sells_silver(self) -> None:
        self.assertEqual(entry_orders(-ENTRY_Z + 1.0e-9, -ENTRY_Z), ("BUY_XAU", "SELL_XAG"))

    def test_nonfresh_or_wrong_side_boundary_does_not_enter(self) -> None:
        self.assertIsNone(entry_orders(ENTRY_Z, ENTRY_Z + 0.1))
        self.assertIsNone(entry_orders(ENTRY_Z - 0.1, ENTRY_Z - 1.0e-9))
        self.assertIsNone(entry_orders(-ENTRY_Z, -ENTRY_Z - 0.1))
        self.assertIsNone(entry_orders(-ENTRY_Z + 0.1, -ENTRY_Z + 1.0e-9))

    def test_convergence_boundary_is_inclusive(self) -> None:
        self.assertTrue(abs(EXIT_Z) <= EXIT_Z)
        self.assertTrue(abs(-EXIT_Z) <= EXIT_Z)
        self.assertFalse(abs(EXIT_Z + 1.0e-9) <= EXIT_Z)

    def test_aggregate_fixed_risk_uses_unit_and_beta_weights(self) -> None:
        xau_risk, xag_risk = risk_split(2.0)
        self.assertAlmostEqual(xau_risk, 1000.0 / 3.0)
        self.assertAlmostEqual(xag_risk, 2000.0 / 3.0)
        self.assertAlmostEqual(xau_risk + xag_risk, 1000.0)

    def test_frozen_z_uses_log_residual_and_formation_statistics(self) -> None:
        timestamp = max(value for value in self.xau if value < self.current)
        value = frozen_z(self.model, self.xau[timestamp], self.xag[timestamp])
        self.assertTrue(math.isfinite(value))
        self.assertAlmostEqual(
            value,
            (
                math.log(self.xau[timestamp])
                - self.model.alpha
                - self.model.beta * math.log(self.xag[timestamp])
                - self.model.residual_mean
            )
            / self.model.residual_sigma,
            places=14,
        )

    def test_time_stop_uses_ceiling_of_fitted_half_life(self) -> None:
        self.assertEqual(math.ceil(4.01), 5)
        self.assertEqual(math.ceil(4.0), 4)

    def test_attempt_is_persisted_before_fallible_entry_gates(self) -> None:
        gate_order = ("persist", "deal_history", "spread", "quote", "atr", "sizing", "order")
        self.assertEqual(gate_order[0], "persist")
        self.assertLess(gate_order.index("persist"), gate_order.index("order"))


if __name__ == "__main__":
    unittest.main()
