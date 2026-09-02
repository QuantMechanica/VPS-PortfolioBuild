from __future__ import annotations

import csv
import dataclasses
import json
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41310_wti-mvnratio-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41310_wti-mvnratio-tr_XTIUSD.DWX_D1_backtest.set"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41310_wti-mvnratio-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
DENSITY_RECEIPT = (
    REPO_ROOT / "artifacts" / "qm5_wti_mvnratio_tr_null_density_20260902.json"
)

RETURN_COUNT = 20
ETA_BOUNDARY = 2.0
VARIANCE_FLOOR = 1e-18
MOMENTUM_MONTHS = 12
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class RawVonNeumannSignal:
    direction: int
    returns: tuple[float, ...]
    mean_return: float
    variance_sum: float
    successive_difference_sum: float
    eta: float
    momentum_12: float


def signal_from_returns(
    returns: list[float],
    month_returns: int = RETURN_COUNT,
    eta_boundary: float = ETA_BOUNDARY,
    variance_floor: float = VARIANCE_FLOOR,
    momentum_months: int = MOMENTUM_MONTHS,
    direction_epsilon: float = DIRECTION_EPSILON,
) -> RawVonNeumannSignal:
    if (
        month_returns != RETURN_COUNT
        or eta_boundary != ETA_BOUNDARY
        or variance_floor != VARIANCE_FLOOR
        or momentum_months != MOMENTUM_MONTHS
        or direction_epsilon != DIRECTION_EPSILON
        or len(returns) != RETURN_COUNT
        or any(not math.isfinite(value) for value in returns)
    ):
        raise ValueError("locked finite twenty-return baseline required")

    mean_return = sum(returns) / RETURN_COUNT
    variance_sum = sum((value - mean_return) ** 2 for value in returns)
    successive_difference_sum = sum(
        (right - left) ** 2 for left, right in zip(returns, returns[1:])
    )
    momentum_12 = sum(returns[RETURN_COUNT - momentum_months :])
    if (
        not all(
            math.isfinite(value)
            for value in (
                mean_return,
                variance_sum,
                successive_difference_sum,
                momentum_12,
            )
        )
        or variance_sum <= variance_floor
        or successive_difference_sum < 0.0
    ):
        raise ValueError("invalid raw von Neumann state")

    eta = successive_difference_sum / variance_sum
    if not math.isfinite(eta) or eta < 0.0:
        raise ValueError("invalid raw von Neumann ratio")

    direction = 0
    if eta < eta_boundary:
        if momentum_12 > direction_epsilon:
            direction = 1
        elif momentum_12 < -direction_epsilon:
            direction = -1
    return RawVonNeumannSignal(
        direction=direction,
        returns=tuple(returns),
        mean_return=mean_return,
        variance_sum=variance_sum,
        successive_difference_sum=successive_difference_sum,
        eta=eta,
        momentum_12=momentum_12,
    )


def closes_from_returns(returns: list[float], initial: float = 70.0) -> list[float]:
    closes = [initial]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def signal_from_closes(closes: list[float]) -> RawVonNeumannSignal:
    if len(closes) != 21 or any(
        not math.isfinite(value) or value <= 0.0 for value in closes
    ):
        raise ValueError("twenty-one positive finite closes required")
    returns = [math.log(right / left) for left, right in zip(closes, closes[1:])]
    return signal_from_returns(returns)


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 21 or next_month_key(endpoints[-1]) != current_month:
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


class WtiMonthlyRawVonNeumannReferenceTests(unittest.TestCase):
    def test_exact_mean_numerator_denominator_and_ratio(self) -> None:
        returns = [-0.0095 + 0.001 * index for index in range(20)]
        signal = signal_from_returns(returns)
        self.assertAlmostEqual(signal.mean_return, 0.0, places=15)
        self.assertAlmostEqual(signal.variance_sum, 0.000665, places=15)
        self.assertAlmostEqual(signal.successive_difference_sum, 0.000019, places=15)
        self.assertAlmostEqual(signal.eta, 0.000019 / 0.000665, places=15)

    def test_smooth_paths_follow_newest_twelve_month_direction(self) -> None:
        rising = [-0.0095 + 0.001 * index for index in range(20)]
        falling = list(reversed(rising))
        buy = signal_from_closes(closes_from_returns(rising))
        sell = signal_from_closes(closes_from_returns(falling))
        self.assertLess(buy.eta, ETA_BOUNDARY)
        self.assertLess(sell.eta, ETA_BOUNDARY)
        self.assertGreater(buy.momentum_12, DIRECTION_EPSILON)
        self.assertLess(sell.momentum_12, -DIRECTION_EPSILON)
        self.assertEqual((buy.direction, sell.direction), (1, -1))

    def test_eta_equal_two_is_strictly_flat(self) -> None:
        returns = [value + 0.0001 for value in ([0.01, -0.01, -0.01, 0.01] * 5)]
        signal = signal_from_returns(returns)
        self.assertEqual(signal.eta, ETA_BOUNDARY)
        self.assertGreater(signal.momentum_12, DIRECTION_EPSILON)
        self.assertEqual(signal.direction, 0)

    def test_eta_above_two_consumes_positive_momentum_flat(self) -> None:
        returns = [0.012 if index % 2 == 0 else -0.008 for index in range(20)]
        signal = signal_from_returns(returns)
        self.assertGreater(signal.eta, ETA_BOUNDARY)
        self.assertGreater(signal.momentum_12, DIRECTION_EPSILON)
        self.assertEqual(signal.direction, 0)

    def test_zero_variance_and_nonfinite_state_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            signal_from_returns([0.001] * 20)
        with self.assertRaises(ValueError):
            signal_from_returns([0.001] * 19 + [math.nan])
        with self.assertRaises(ValueError):
            signal_from_closes([70.0] * 20 + [0.0])

    def test_momentum_tie_stays_flat_on_qualifying_path(self) -> None:
        returns = [-0.0095 + 0.001 * index for index in range(20)]
        offset = sum(returns[8:]) / 12.0
        tied = [value - offset for value in returns]
        signal = signal_from_returns(tied)
        self.assertLess(signal.eta, ETA_BOUNDARY)
        self.assertLessEqual(abs(signal.momentum_12), DIRECTION_EPSILON)
        self.assertEqual(signal.direction, 0)

    def test_raw_statistic_retains_magnitude_information(self) -> None:
        base = [0.001 + 0.0001 * index for index in range(20)]
        changed = list(base)
        changed[-1] = 0.02
        base_signal = signal_from_returns(base)
        changed_signal = signal_from_returns(changed)
        self.assertEqual(
            [value > 0 for value in base],
            [value > 0 for value in changed],
        )
        self.assertNotAlmostEqual(base_signal.eta, changed_signal.eta, places=6)

    def test_consecutive_completed_month_contract(self) -> None:
        endpoints = [202412]
        for _ in range(20):
            endpoints.append(next_month_key(endpoints[-1]))
        current_month = next_month_key(endpoints[-1])
        self.assertTrue(validate_month_keys(current_month, endpoints))
        broken = list(endpoints)
        broken[10] = next_month_key(broken[10])
        self.assertFalse(validate_month_keys(current_month, broken))
        self.assertFalse(validate_month_keys(endpoints[-1], endpoints))

    def test_fixed_seed_density_receipt_is_only_a_cadence_prior(self) -> None:
        receipt = json.loads(DENSITY_RECEIPT.read_text(encoding="utf-8"))
        experiment = receipt["experiment"]
        self.assertEqual(experiment["sample_length"], 20)
        self.assertEqual(experiment["draws"], 200_000)
        self.assertEqual(experiment["seed"], 20_260_902)
        self.assertEqual(experiment["qualified_draws"], 99_943)
        self.assertEqual(experiment["qualified_fraction"], 0.499715)
        self.assertIn("not market evidence", receipt["boundary"])

    def test_source_implements_formula_and_consume_before_fallible_gates(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8")
        required = (
            "metrics.endpoint_count != strategy_month_returns + 1",
            "monthly_returns[index] = MathLog(close_ratio);",
            "metrics.variance_sum += centered * centered;",
            "metrics.successive_difference_sum += delta * delta;",
            "metrics.successive_difference_sum / metrics.variance_sum",
            "if(metrics.eta < strategy_eta_boundary)",
            "if(metrics.momentum_12 > strategy_direction_epsilon)",
            "else if(metrics.momentum_12 < -strategy_direction_epsilon)",
        )
        for fragment in required:
            self.assertIn(fragment, source)
        prepare = source[source.index("void Strategy_PrepareDecisionSignal()") :]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadMonthlyEndpoints"),
        )
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_ManageOpenPosition"),
            on_tick.index("Strategy_NewsFilterHook"),
        )
        for forbidden in ("iRSI(", "iMACD(", "iBands(", "WebRequest(", "FileOpen("):
            self.assertNotIn(forbidden, source)

    def test_setfile_is_single_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41310")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        expected = {
            "qm_ea_id": "41310",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "20",
            "strategy_eta_boundary": "2.0",
            "strategy_variance_floor": "0.000000000000000001",
            "strategy_momentum_months": "12",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars_d1": "1000",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "40",
            "strategy_max_spread_points": "1500",
        }
        self.assertEqual(values, expected)
        self.assertEqual(list((EA_DIR / "sets").glob("*.set")), [SETFILE])

    def test_card_copy_and_governed_magic_are_exact(self) -> None:
        self.assertEqual(
            CANONICAL_CARD.read_bytes().replace(b"\r\n", b"\n"),
            EA_CARD.read_bytes().replace(b"\r\n", b"\n"),
        )
        with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
            rows = [
                row
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41310" and row["status"] == "active"
            ]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["ea_slug"], "wti-mvnratio-tr")
        self.assertEqual(rows[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(rows[0]["magic"], "413100000")


if __name__ == "__main__":
    unittest.main()
