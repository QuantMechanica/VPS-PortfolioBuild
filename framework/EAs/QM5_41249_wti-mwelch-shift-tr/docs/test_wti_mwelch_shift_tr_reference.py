from __future__ import annotations

import dataclasses
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41249_wti-mwelch-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41249_wti-mwelch-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41249_wti-mwelch-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
ZERO_EPSILON = 1e-12
MIN_SE2 = 1e-18


@dataclasses.dataclass(frozen=True)
class WelchSignal:
    direction: int
    returns: tuple[float, ...]
    mean_old: float
    mean_recent: float
    var_old: float
    var_recent: float
    se2: float
    score: float


def closes_from_returns(returns: list[float], initial: float = 100.0) -> list[float]:
    closes = [initial]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def sample_variance(values: tuple[float, ...], mean: float) -> float:
    if len(values) != 6:
        raise ValueError("fixed sample must contain six returns")
    return sum((value - mean) ** 2 for value in values) / 5


def welch_signal(
    closes: list[float],
    month_returns: int = 12,
    block_size: int = 6,
    score_floor: float = 0.75,
    zero_epsilon: float = ZERO_EPSILON,
    min_se2: float = MIN_SE2,
) -> WelchSignal:
    if (
        month_returns != 12
        or block_size != 6
        or score_floor != 0.75
        or zero_epsilon != ZERO_EPSILON
        or min_se2 != MIN_SE2
        or len(closes) != month_returns + 1
    ):
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")

    returns = tuple(
        math.log(right / left) for left, right in zip(closes, closes[1:])
    )
    if len(returns) != month_returns or any(
        not math.isfinite(value) for value in returns
    ):
        raise ValueError("returns must be finite")

    old = returns[:block_size]
    recent = returns[block_size:]
    mean_old = sum(old) / block_size
    mean_recent = sum(recent) / block_size
    var_old = sample_variance(old, mean_old)
    var_recent = sample_variance(recent, mean_recent)
    se2 = var_old / block_size + var_recent / block_size
    if any(
        not math.isfinite(value)
        for value in (mean_old, mean_recent, var_old, var_recent, se2)
    ) or min(var_old, var_recent, se2) < 0.0:
        raise ValueError("Welch arithmetic must be finite and nonnegative")

    direction = 0
    score = 0.0
    if se2 > min_se2:
        score = (mean_recent - mean_old) / math.sqrt(se2)
        if not math.isfinite(score):
            raise ValueError("score must be finite")
        if score >= score_floor and mean_recent > zero_epsilon:
            direction = 1
        elif score <= -score_floor and mean_recent < -zero_epsilon:
            direction = -1

    return WelchSignal(
        direction=direction,
        returns=returns,
        mean_old=mean_old,
        mean_recent=mean_recent,
        var_old=var_old,
        var_recent=var_recent,
        se2=se2,
        score=score,
    )


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 13 or next_month_key(endpoints[-1]) != current_month:
        return False
    return all(
        next_month_key(left) == right
        for left, right in zip(endpoints, endpoints[1:])
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


class WtiMonthlyWelchReferenceTests(unittest.TestCase):
    def test_positive_and_negative_shift_are_symmetric(self) -> None:
        noise = [-0.003, -0.002, -0.001, 0.001, 0.002, 0.003]
        buy_returns = [value - 0.02 for value in noise] + [
            value + 0.02 for value in noise
        ]
        sell_returns = [value + 0.02 for value in noise] + [
            value - 0.02 for value in noise
        ]
        buy = welch_signal(closes_from_returns(buy_returns))
        sell = welch_signal(closes_from_returns(sell_returns))
        self.assertEqual((buy.direction, sell.direction), (1, -1))
        self.assertAlmostEqual(buy.score, -sell.score, places=11)
        self.assertGreaterEqual(buy.score, 0.75)
        self.assertLessEqual(sell.score, -0.75)

    def test_unbiased_variance_and_fixed_membership(self) -> None:
        noise = [-0.003, -0.002, -0.001, 0.001, 0.002, 0.003]
        result = welch_signal(closes_from_returns(noise + noise))
        expected = sum(value * value for value in noise) / 5
        self.assertAlmostEqual(result.mean_old, 0.0, places=14)
        self.assertAlmostEqual(result.mean_recent, 0.0, places=14)
        self.assertAlmostEqual(result.var_old, expected, places=14)
        self.assertAlmostEqual(result.var_recent, expected, places=14)
        self.assertAlmostEqual(result.se2, 2 * expected / 6, places=14)
        self.assertEqual(result.direction, 0)

    def test_degenerate_denominator_consumes_flat(self) -> None:
        result = welch_signal(closes_from_returns([0.01] * 6 + [0.02] * 6))
        self.assertLessEqual(result.se2, MIN_SE2)
        self.assertEqual((result.direction, result.score), (0, 0.0))

    def test_recent_mean_must_align_with_score(self) -> None:
        noise = [-0.003, -0.002, -0.001, 0.001, 0.002, 0.003]
        positive_shift_but_negative_recent = [
            value - 0.02 for value in noise
        ] + [value - 0.01 for value in noise]
        negative_shift_but_positive_recent = [
            value + 0.02 for value in noise
        ] + [value + 0.01 for value in noise]
        first = welch_signal(closes_from_returns(positive_shift_but_negative_recent))
        second = welch_signal(closes_from_returns(negative_shift_but_positive_recent))
        self.assertGreaterEqual(first.score, 0.75)
        self.assertLessEqual(second.score, -0.75)
        self.assertEqual((first.direction, second.direction), (0, 0))

    def test_inclusive_boundary_is_literal_in_source(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("metrics.score >= strategy_score_floor", source)
        self.assertIn("metrics.score <= -strategy_score_floor", source)
        self.assertNotIn("metrics.score > strategy_score_floor", source)
        self.assertNotIn("metrics.score < -strategy_score_floor", source)

    def test_invalid_endpoints_and_parameters_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            welch_signal([100.0] * 12)
        with self.assertRaises(ValueError):
            welch_signal([100.0] * 12 + [0.0])
        with self.assertRaises(ValueError):
            welch_signal([100.0] * 12 + [math.inf])
        with self.assertRaises(ValueError):
            welch_signal([100.0] * 13, block_size=5)

    def test_thirteen_consecutive_completed_months(self) -> None:
        endpoints = [
            202507, 202508, 202509, 202510, 202511, 202512, 202601,
            202602, 202603, 202604, 202605, 202606, 202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        self.assertFalse(validate_month_keys(202608, endpoints[:-1]))
        broken = endpoints.copy()
        broken[7] = 202603
        self.assertFalse(validate_month_keys(202608, broken))

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41249")
        self.assertEqual(headers["ea_slug"], "wti-mwelch-shift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41249",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "12",
            "strategy_block_size": "6",
            "strategy_score_floor": "0.75",
            "strategy_zero_epsilon": "0.000000000001",
            "strategy_min_se2": "0.000000000000000001",
            "strategy_history_bars": "900",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_stale_days": "40",
            "strategy_max_spread_points": "1500",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

    def test_source_contract_and_card_copy(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_WelchSignal", source)
        self.assertIn("variance_denominator != 5", source)
        self.assertIn("metrics.se2 <= strategy_min_se2", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41249", source)
        self.assertNotIn("Strategy_CusumSignal", source)
        self.assertNotIn("iRSI", source)
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )

    def test_only_backtest_setfile_exists(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
