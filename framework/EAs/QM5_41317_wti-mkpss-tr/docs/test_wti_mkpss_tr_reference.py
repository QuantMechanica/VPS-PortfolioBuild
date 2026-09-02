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
EA_SOURCE = EA_DIR / "QM5_41317_wti-mkpss-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41317_wti-mkpss-tr_XTIUSD.DWX_D1_backtest.set"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41317_wti-mkpss-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
FIXTURE = REPO_ROOT / "artifacts" / "qm5_wti_mkpss_tr_reference_fixture_20260902.json"

LEVEL_COUNT = 60
COVARIANCE_LAGS = 4
RESIDUAL_ENERGY_FLOOR = 1e-18
LONG_RUN_VARIANCE_FLOOR = 1e-18
KPSS_BOUNDARY = 0.347
MOMENTUM_MONTHS = 12
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class KPSSState:
    mean: float
    residual_energy: float
    eta: float
    lag_cross: tuple[float, ...]
    long_run_variance: float
    statistic: float


@dataclasses.dataclass(frozen=True)
class Signal:
    direction: int
    qualified: bool
    momentum_12: float
    state: KPSSState


def direct_kpss(levels: list[float]) -> KPSSState:
    """Independent scalar implementation of the locked constant-only KPSS."""
    if len(levels) != LEVEL_COUNT or any(not math.isfinite(x) for x in levels):
        raise ValueError("sixty finite log levels required")
    mean = sum(levels) / LEVEL_COUNT
    residuals = [value - mean for value in levels]
    residual_energy = sum(value * value for value in residuals)
    if residual_energy <= RESIDUAL_ENERGY_FLOOR:
        raise ValueError("residual energy at or below floor")

    running = 0.0
    partial_squares: list[float] = []
    for value in residuals:
        running += value
        partial_squares.append(running * running)
    eta = sum(partial_squares) / (LEVEL_COUNT * LEVEL_COUNT)

    lag_cross = tuple(
        sum(residuals[t] * residuals[t - lag] for t in range(lag, LEVEL_COUNT))
        for lag in range(1, COVARIANCE_LAGS + 1)
    )
    numerator = residual_energy + 2.0 * sum(
        (1.0 - lag / (COVARIANCE_LAGS + 1.0)) * lag_cross[lag - 1]
        for lag in range(1, COVARIANCE_LAGS + 1)
    )
    long_run_variance = numerator / LEVEL_COUNT
    if not math.isfinite(long_run_variance) or long_run_variance <= LONG_RUN_VARIANCE_FLOOR:
        raise ValueError("long-run variance at or below floor")
    statistic = eta / long_run_variance
    if not math.isfinite(statistic) or statistic < 0.0:
        raise ValueError("invalid KPSS statistic")
    return KPSSState(
        mean,
        residual_energy,
        eta,
        lag_cross,
        long_run_variance,
        statistic,
    )


def independently_weighted_long_run_variance(levels: list[float]) -> float:
    """Second construction using explicit locked Bartlett weights."""
    mean = math.fsum(levels) / len(levels)
    residuals = [value - mean for value in levels]
    weighted = math.fsum(value * value for value in residuals)
    for lag, weight in enumerate((0.8, 0.6, 0.4, 0.2), start=1):
        covariance_sum = math.fsum(
            left * right for left, right in zip(residuals[lag:], residuals[:-lag])
        )
        weighted += 2.0 * weight * covariance_sum
    return weighted / len(levels)


def classify(statistic: float, momentum_12: float) -> int:
    if (
        not math.isfinite(statistic)
        or not math.isfinite(momentum_12)
        or statistic < KPSS_BOUNDARY
    ):
        return 0
    if momentum_12 > DIRECTION_EPSILON:
        return 1
    if momentum_12 < -DIRECTION_EPSILON:
        return -1
    return 0


def signal_from_levels(levels: list[float]) -> Signal:
    state = direct_kpss(levels)
    momentum_12 = levels[-1] - levels[-1 - MOMENTUM_MONTHS]
    qualified = state.statistic >= KPSS_BOUNDARY
    return Signal(
        classify(state.statistic, momentum_12),
        qualified,
        momentum_12,
        state,
    )


def signal_from_closes(closes: list[float]) -> Signal:
    if len(closes) != LEVEL_COUNT or any(
        not math.isfinite(value) or value <= 0.0 for value in closes
    ):
        raise ValueError("sixty positive finite closes required")
    return signal_from_levels([math.log(value) for value in closes])


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


class WtiMonthlyKPSSReferenceTests(unittest.TestCase):
    @staticmethod
    def stationary_levels() -> list[float]:
        return [
            4.2 + 0.02 * math.sin(0.71 * index) + 0.01 * math.cos(0.23 * index)
            for index in range(LEVEL_COUNT)
        ]

    @staticmethod
    def trending_levels() -> list[float]:
        return [
            4.0
            + 0.012 * index
            + 0.025 * math.sin(0.31 * index)
            + 0.007 * math.cos(0.13 * index)
            for index in range(LEVEL_COUNT)
        ]

    def test_receipt_and_both_reference_paths_match(self) -> None:
        receipt = json.loads(FIXTURE.read_text(encoding="utf-8"))
        self.assertEqual(receipt["schema"], "qm.kpss-reference-fixture/v1")
        self.assertEqual(receipt["contract"]["observations"], LEVEL_COUNT)
        self.assertEqual(receipt["contract"]["fixed_covariance_lags"], COVARIANCE_LAGS)
        self.assertEqual(receipt["contract"]["inclusive_critical_value"], KPSS_BOUNDARY)

        stationary = direct_kpss(self.stationary_levels())
        expected_stationary = receipt["stationary_fixture"]
        self.assertAlmostEqual(stationary.mean, expected_stationary["mean"], places=14)
        self.assertAlmostEqual(stationary.eta, expected_stationary["eta"], places=15)
        self.assertAlmostEqual(
            stationary.long_run_variance,
            expected_stationary["long_run_variance"],
            places=15,
        )
        self.assertAlmostEqual(
            stationary.statistic, expected_stationary["kpss_statistic"], places=14
        )
        self.assertFalse(signal_from_levels(self.stationary_levels()).qualified)

        trending_signal = signal_from_levels(self.trending_levels())
        expected_trending = receipt["trending_fixture"]
        self.assertAlmostEqual(trending_signal.state.mean, expected_trending["mean"], places=14)
        self.assertAlmostEqual(trending_signal.state.eta, expected_trending["eta"], places=14)
        self.assertAlmostEqual(
            trending_signal.state.long_run_variance,
            expected_trending["long_run_variance"],
            places=14,
        )
        self.assertAlmostEqual(
            trending_signal.state.statistic,
            expected_trending["kpss_statistic"],
            places=13,
        )
        self.assertAlmostEqual(
            trending_signal.momentum_12,
            expected_trending["twelve_month_log_return"],
            places=14,
        )
        self.assertTrue(trending_signal.qualified)
        self.assertEqual(trending_signal.direction, 1)

    def test_fixed_bartlett_weights_match_second_construction(self) -> None:
        for levels in (self.stationary_levels(), self.trending_levels()):
            state = direct_kpss(levels)
            self.assertAlmostEqual(
                state.long_run_variance,
                independently_weighted_long_run_variance(levels),
                places=15,
            )
            self.assertEqual(len(state.lag_cross), 4)

    def test_constant_only_additive_invariance(self) -> None:
        levels = self.trending_levels()
        original = direct_kpss(levels)
        shifted = direct_kpss([value + 7.25 for value in levels])
        self.assertAlmostEqual(original.residual_energy, shifted.residual_energy, places=12)
        self.assertAlmostEqual(original.eta, shifted.eta, places=12)
        self.assertAlmostEqual(
            original.long_run_variance, shifted.long_run_variance, places=12
        )
        self.assertAlmostEqual(original.statistic, shifted.statistic, places=12)

    def test_log_close_orientation_and_newest_twelve_month_direction(self) -> None:
        levels = self.trending_levels()
        direct = signal_from_levels(levels)
        via_closes = signal_from_closes([math.exp(value) for value in levels])
        self.assertAlmostEqual(direct.state.statistic, via_closes.state.statistic, places=12)
        self.assertAlmostEqual(direct.momentum_12, levels[59] - levels[47], places=15)
        reversed_signal = signal_from_levels([-value for value in levels])
        self.assertTrue(reversed_signal.qualified)
        self.assertEqual((direct.direction, reversed_signal.direction), (1, -1))

    def test_boundary_is_inclusive_and_direction_band_symmetric(self) -> None:
        self.assertEqual(classify(KPSS_BOUNDARY, 0.01), 1)
        self.assertEqual(classify(KPSS_BOUNDARY, -0.01), -1)
        inner = math.nextafter(KPSS_BOUNDARY, 0.0)
        self.assertEqual(classify(inner, 0.01), 0)
        self.assertEqual(classify(KPSS_BOUNDARY, DIRECTION_EPSILON), 0)
        self.assertEqual(classify(KPSS_BOUNDARY, -DIRECTION_EPSILON), 0)

    def test_degenerate_wrong_length_and_bad_close_paths_fail(self) -> None:
        with self.assertRaisesRegex(ValueError, "residual energy"):
            direct_kpss([4.2] * LEVEL_COUNT)
        with self.assertRaises(ValueError):
            direct_kpss([4.2] * (LEVEL_COUNT - 1))
        with self.assertRaises(ValueError):
            direct_kpss([4.2] * (LEVEL_COUNT - 1) + [math.inf])
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
        self.assertEqual(headers["ea_id"], "41317")
        self.assertEqual(headers["ea_slug"], "wti-mkpss-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41317",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_level_count": "60",
            "strategy_covariance_lags": "4",
            "strategy_residual_energy_floor": "0.000000000000000001",
            "strategy_long_run_variance_floor": "0.000000000000000001",
            "strategy_kpss_boundary": "0.347",
            "strategy_momentum_months": "12",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars": "1800",
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

    def test_source_contract_attempt_order_and_kpss_guards(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        for required in (
            "bool Strategy_KPSSCore",
            "bool Strategy_KPSSReferenceSelfTest",
            "bool Strategy_KPSSSignal",
            "residuals[index] = levels[index] - level_mean",
            "eta_numerator /",
            "1.0 - (double)lag / (double)(strategy_covariance_lags + 1)",
            "long_run_numerator += 2.0 * weight * lag_cross[lag - 1]",
            "kpss = eta / long_run_variance",
            "metrics.kpss >= strategy_kpss_boundary",
            "levels[strategy_level_count - 1] - levels[momentum_start]",
            "QM_FrameworkMagic() != 413170000",
            "Strategy_HasForeignSymbolPosition()",
        ):
            self.assertIn(required, source)
        prepare = source.index("void Strategy_PrepareDecisionSignal")
        consume = source.index("Strategy_RecordMonthAttempt(g_decision_month_key)", prepare)
        history = source.index("Strategy_LoadMonthlyEndpoints", consume)
        self.assertLess(consume, history)
        open_call = source.index("QM_TM_OpenPosition(req, out_ticket)")
        persist_entry = source.index("Strategy_RecordEntryMonth(g_decision_month_key)", open_call)
        self.assertLess(open_call, persist_entry)
        for prohibited in (
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
                if row["ea_id"] == "41317" and row["status"] == "active"
            ]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["ea_slug"], "wti-mkpss-tr")
        self.assertEqual(rows[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(rows[0]["magic"], "413170000")
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )


if __name__ == "__main__":
    unittest.main()
