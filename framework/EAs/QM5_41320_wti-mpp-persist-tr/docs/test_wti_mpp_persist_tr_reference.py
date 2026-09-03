from __future__ import annotations

import csv
import dataclasses
import json
import math
from pathlib import Path
import re
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41320_wti-mpp-persist-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41320_wti-mpp-persist-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41320_wti-mpp-persist-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
FIXTURE = (
    REPO_ROOT
    / "artifacts"
    / "qm5_wti_mpp_persist_tr_reference_fixture_20260903.json"
)

LEVEL_COUNT = 60
OBSERVATION_COUNT = 59
RESIDUAL_DOF = 57
BARTLETT_LAGS = 11
ENERGY_FLOOR = 1e-18
PP_Z_TAU_MIN = -2.594
MOMENTUM_MONTHS = 12
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class PPState:
    mean_lhs: float
    mean_rhs: float
    sxx: float
    sxy: float
    alpha: float
    rho: float
    sse: float
    residual_variance: float
    regression_sigma: float
    gamma0: float
    autocovariances: tuple[float, ...]
    long_run_variance: float
    se_rho: float
    raw_tau: float
    pp_z_tau: float


@dataclasses.dataclass(frozen=True)
class Signal:
    direction: int
    qualified: bool
    momentum_12: float
    state: PPState


def direct_pp(levels: list[float]) -> PPState:
    """Independent scalar transcription of the locked PP Z-tau formula."""
    if len(levels) != LEVEL_COUNT or any(not math.isfinite(x) for x in levels):
        raise ValueError("sixty finite log levels required")
    lhs = levels[1:]
    rhs = levels[:-1]
    if len(lhs) != OBSERVATION_COUNT or len(rhs) != OBSERVATION_COUNT:
        raise ValueError("fifty-nine AR(1) observations required")
    mean_lhs = sum(lhs) / OBSERVATION_COUNT
    mean_rhs = sum(rhs) / OBSERVATION_COUNT
    sxx = sum((value - mean_rhs) ** 2 for value in rhs)
    sxy = sum(
        (x_value - mean_rhs) * (y_value - mean_lhs)
        for x_value, y_value in zip(rhs, lhs)
    )
    if not math.isfinite(sxx) or sxx <= ENERGY_FLOOR:
        raise ValueError("lag-level energy at or below floor")
    rho = sxy / sxx
    alpha = mean_lhs - rho * mean_rhs
    residuals = tuple(
        y_value - alpha - rho * x_value
        for x_value, y_value in zip(rhs, lhs)
    )
    sse = sum(value * value for value in residuals)
    if not math.isfinite(sse) or sse <= ENERGY_FLOOR:
        raise ValueError("residual energy at or below floor")
    residual_variance = sse / RESIDUAL_DOF
    regression_sigma = math.sqrt(residual_variance)
    gamma0 = sse / OBSERVATION_COUNT
    se_rho = math.sqrt(residual_variance / sxx)
    autocovariances = tuple(
        sum(
            residuals[row] * residuals[row - lag]
            for row in range(lag, OBSERVATION_COUNT)
        )
        / OBSERVATION_COUNT
        for lag in range(1, BARTLETT_LAGS + 1)
    )
    long_run_variance = gamma0 + 2.0 * sum(
        (1.0 - lag / (BARTLETT_LAGS + 1.0)) * autocovariances[lag - 1]
        for lag in range(1, BARTLETT_LAGS + 1)
    )
    if (
        not math.isfinite(residual_variance)
        or not math.isfinite(regression_sigma)
        or not math.isfinite(gamma0)
        or not math.isfinite(long_run_variance)
        or not math.isfinite(se_rho)
        or min(
            residual_variance,
            regression_sigma,
            gamma0,
            long_run_variance,
            se_rho,
        )
        <= ENERGY_FLOOR
    ):
        raise ValueError("invalid variance path")
    raw_tau = (rho - 1.0) / se_rho
    pp_z_tau = (
        math.sqrt(gamma0 / long_run_variance) * raw_tau
        - 0.5
        * ((long_run_variance - gamma0) / math.sqrt(long_run_variance))
        * (OBSERVATION_COUNT * se_rho / regression_sigma)
    )
    if not math.isfinite(raw_tau) or not math.isfinite(pp_z_tau):
        raise ValueError("invalid PP statistic")
    return PPState(
        mean_lhs,
        mean_rhs,
        sxx,
        sxy,
        alpha,
        rho,
        sse,
        residual_variance,
        regression_sigma,
        gamma0,
        autocovariances,
        long_run_variance,
        se_rho,
        raw_tau,
        pp_z_tau,
    )


def classify(pp_z_tau: float, momentum_12: float) -> int:
    if (
        not math.isfinite(pp_z_tau)
        or not math.isfinite(momentum_12)
        or pp_z_tau < PP_Z_TAU_MIN
    ):
        return 0
    if momentum_12 > DIRECTION_EPSILON:
        return 1
    if momentum_12 < -DIRECTION_EPSILON:
        return -1
    return 0


def signal_from_levels(levels: list[float]) -> Signal:
    state = direct_pp(levels)
    momentum_12 = levels[-1] - levels[-1 - MOMENTUM_MONTHS]
    return Signal(
        classify(state.pp_z_tau, momentum_12),
        state.pp_z_tau >= PP_Z_TAU_MIN,
        momentum_12,
        state,
    )


def signal_from_closes(closes: list[float]) -> Signal:
    if len(closes) != LEVEL_COUNT or any(
        not math.isfinite(value) or value <= 0.0 for value in closes
    ):
        raise ValueError("sixty positive finite closes required")
    return signal_from_levels([math.log(value) for value in closes])


def fixture_levels(name: str) -> list[float]:
    if name == "persistent_up_qualifies_buy":
        return [
            4.0
            + 0.012 * t
            + 0.025 * math.sin(0.73 * t)
            + 0.009 * math.cos(1.91 * t)
            for t in range(LEVEL_COUNT)
        ]
    if name == "persistent_down_qualifies_sell":
        return [
            5.0
            - 0.010 * t
            + 0.023 * math.sin(0.71 * t)
            + 0.008 * math.cos(1.83 * t)
            for t in range(LEVEL_COUNT)
        ]
    if name == "mean_reverting_rejected_flat":
        return [
            4.0 + 0.080 * math.sin(1.17 * t) + 0.030 * math.cos(0.41 * t)
            for t in range(LEVEL_COUNT)
        ]
    raise KeyError(name)


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != LEVEL_COUNT or next_month_key(endpoints[-1]) != current_month:
        return False
    return all(
        next_month_key(left) == right for left, right in zip(endpoints, endpoints[1:])
    )


def parse_setfile(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    headers: dict[str, str] = {}
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith(";"):
            body = line[1:].strip()
            if ":" in body:
                key, value = body.split(":", 1)
                headers[key.strip()] = value.strip()
            continue
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return headers, values


class WtiMonthlyPPReferenceTests(unittest.TestCase):
    def test_fixture_receipt_matches_direct_formula_and_pinned_oracle(self) -> None:
        receipt = json.loads(FIXTURE.read_text(encoding="utf-8"))
        self.assertEqual(receipt["schema"], "qm.strategy-reference-fixture/v1")
        self.assertFalse(receipt["market_data"])
        self.assertEqual(receipt["contract"]["level_count"], LEVEL_COUNT)
        self.assertEqual(
            receipt["contract"]["regression_observations"], OBSERVATION_COUNT
        )
        self.assertEqual(
            receipt["contract"]["residual_degrees_of_freedom"], RESIDUAL_DOF
        )
        self.assertEqual(
            receipt["contract"]["bartlett_newey_west_lags"], BARTLETT_LAGS
        )
        self.assertEqual(
            receipt["contract"]["pp_z_tau_min_inclusive"], PP_Z_TAU_MIN
        )
        for expected in receipt["fixtures"]:
            signal = signal_from_levels(fixture_levels(expected["name"]))
            for field in (
                "alpha",
                "rho",
                "sxx",
                "sse",
                "residual_variance",
                "gamma0",
                "long_run_variance",
                "se_rho",
                "raw_tau",
                "pp_z_tau",
            ):
                self.assertAlmostEqual(
                    getattr(signal.state, field), expected[field], places=12
                )
            self.assertAlmostEqual(
                signal.momentum_12, expected["momentum_12"], places=12
            )
            self.assertEqual(signal.direction, expected["direction"])
            self.assertEqual(
                signal.qualified, expected["pp_z_tau"] >= PP_Z_TAU_MIN
            )
            self.assertAlmostEqual(
                signal.state.pp_z_tau,
                receipt["reference_oracle"][
                    {
                        "persistent_up_qualifies_buy": "up",
                        "persistent_down_qualifies_sell": "down",
                        "mean_reverting_rejected_flat": "mean_reverting",
                    }[expected["name"]]
                ],
                places=11,
            )

    def test_ar1_normal_equations_and_additive_level_invariance(self) -> None:
        levels = fixture_levels("persistent_up_qualifies_buy")
        state = direct_pp(levels)
        residuals = [
            levels[row + 1] - state.alpha - state.rho * levels[row]
            for row in range(OBSERVATION_COUNT)
        ]
        self.assertAlmostEqual(sum(residuals), 0.0, places=12)
        self.assertAlmostEqual(
            sum(value * levels[row] for row, value in enumerate(residuals)),
            0.0,
            places=12,
        )
        shifted = direct_pp([value + 7.25 for value in levels])
        self.assertAlmostEqual(state.rho, shifted.rho, places=12)
        self.assertAlmostEqual(state.sse, shifted.sse, places=12)
        self.assertAlmostEqual(
            state.long_run_variance, shifted.long_run_variance, places=12
        )
        self.assertAlmostEqual(state.pp_z_tau, shifted.pp_z_tau, places=12)
        self.assertAlmostEqual(
            shifted.alpha,
            state.alpha + 7.25 * (1.0 - state.rho),
            places=12,
        )

    def test_bartlett_divisor_weights_and_log_close_orientation(self) -> None:
        levels = fixture_levels("persistent_down_qualifies_sell")
        direct = signal_from_levels(levels)
        via_closes = signal_from_closes([math.exp(value) for value in levels])
        self.assertEqual(len(direct.state.autocovariances), BARTLETT_LAGS)
        self.assertAlmostEqual(
            direct.state.pp_z_tau, via_closes.state.pp_z_tau, places=12
        )
        self.assertAlmostEqual(
            direct.momentum_12, levels[59] - levels[47], places=15
        )
        self.assertEqual(direct.direction, -1)

    def test_boundary_is_inclusive_and_direction_band_symmetric(self) -> None:
        self.assertEqual(classify(PP_Z_TAU_MIN, 0.01), 1)
        self.assertEqual(classify(PP_Z_TAU_MIN, -0.01), -1)
        below = math.nextafter(PP_Z_TAU_MIN, -math.inf)
        self.assertEqual(classify(below, 0.01), 0)
        self.assertEqual(classify(PP_Z_TAU_MIN, DIRECTION_EPSILON), 0)
        self.assertEqual(classify(PP_Z_TAU_MIN, -DIRECTION_EPSILON), 0)

    def test_degenerate_wrong_length_and_bad_close_paths_fail(self) -> None:
        with self.assertRaises(ValueError):
            direct_pp([4.2] * LEVEL_COUNT)
        with self.assertRaises(ValueError):
            direct_pp([4.2] * (LEVEL_COUNT - 1))
        with self.assertRaises(ValueError):
            direct_pp([4.2] * (LEVEL_COUNT - 1) + [math.inf])
        with self.assertRaises(ValueError):
            signal_from_closes([70.0] * (LEVEL_COUNT - 1))
        with self.assertRaises(ValueError):
            signal_from_closes([70.0] * (LEVEL_COUNT - 1) + [0.0])

    def test_sixty_consecutive_completed_months(self) -> None:
        endpoints: list[int] = []
        key = 201907
        for _ in range(LEVEL_COUNT):
            endpoints.append(key)
            key = next_month_key(key)
        self.assertTrue(validate_month_keys(key, endpoints))
        self.assertFalse(validate_month_keys(key, endpoints[:-1]))
        broken = endpoints.copy()
        broken[29] = broken[28]
        self.assertFalse(validate_month_keys(key, broken))

    def test_setfile_is_the_one_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41320")
        self.assertEqual(headers["ea_slug"], "wti-mpp-persist-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41320",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_level_count": "60",
            "strategy_regression_observations": "59",
            "strategy_residual_dof": "57",
            "strategy_bartlett_lags": "11",
            "strategy_energy_floor": "0.000000000000000001",
            "strategy_pp_z_tau_min": "-2.594",
            "strategy_momentum_months": "12",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars": "1200",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_stale_days": "40",
            "strategy_max_spread_points": "1500",
        }
        self.assertEqual(values, expected)
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        input_names = set(
            re.findall(r"(?m)^input\s+(?!group\b)(?:\w+\s+)+(\w+)\s*=", source)
        )
        self.assertTrue(set(values) <= input_names)
        self.assertTrue(
            {name for name in input_names if name.startswith("strategy_")} <= set(values)
        )
        self.assertEqual(sorted((EA_DIR / "sets").glob("*.set")), [SETFILE])

    def test_source_contract_attempt_order_and_pp_guards(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        for required in (
            "bool Strategy_PPCore",
            "bool Strategy_PPReferenceSelfTest",
            "bool Strategy_PPSignal",
            "const int observation_count = level_count - 1;",
            "rho = sxy / sxx;",
            "alpha = mean_lhs - rho * mean_rhs;",
            "residual_variance = sse / (double)strategy_residual_dof;",
            "gamma0 = sse / (double)observation_count;",
            "cross_sum / (double)observation_count;",
            "2.0 * bartlett_weight * autocovariance;",
            "raw_tau = (rho - 1.0) / se_rho;",
            "pp_z_tau = variance_scale * raw_tau - correction;",
            "metrics.pp_z_tau >= strategy_pp_z_tau_min",
            "levels[strategy_level_count - 1] - levels[momentum_start]",
            "QM_FrameworkMagic() != 413200000",
            "Strategy_HasForeignSymbolPosition()",
        ):
            self.assertIn(required, source)
        prepare = source.index("void Strategy_PrepareDecisionSignal")
        consume = source.index("Strategy_RecordMonthAttempt(g_decision_month_key)", prepare)
        history = source.index("Strategy_LoadMonthlyEndpoints", consume)
        self.assertLess(consume, history)
        open_call = source.index("QM_TM_OpenPosition(req, out_ticket)")
        persist_entry = source.index(
            "Strategy_RecordEntryMonth(g_decision_month_key)", open_call
        )
        self.assertLess(open_call, persist_entry)
        for prohibited in (
            "Strategy_ADF",
            "iRSI(",
            "iMACD(",
            "iBands(",
            "iADX(",
            "iMA(",
            "MathRand(",
            "WebRequest(",
            "FileOpen(",
            "SpectralEntropy",
            "SampleEntropy",
            "LZ76",
        ):
            self.assertNotIn(prohibited, source)

    def test_magic_registry_and_card_copy_are_exact(self) -> None:
        with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
            rows = [
                row
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41320" and row["status"] == "active"
            ]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["ea_slug"], "wti-mpp-persist-tr")
        self.assertEqual(rows[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(rows[0]["magic"], "413200000")
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )


if __name__ == "__main__":
    unittest.main()
