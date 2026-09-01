from __future__ import annotations

import dataclasses
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41264_wti-myuen20-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41264_wti-myuen20-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41264_wti-myuen20-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MIN_SE2 = 1e-18


@dataclasses.dataclass(frozen=True)
class YuenBlock:
    trimmed_mean: float
    winsor_mean: float
    winsor_variance: float


@dataclasses.dataclass(frozen=True)
class YuenSignal:
    direction: int
    returns: tuple[float, ...]
    old: YuenBlock
    recent: YuenBlock
    se2: float
    score: float


def closes_from_returns(returns: list[float], initial: float = 100.0) -> list[float]:
    closes = [initial]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def yuen_block(values: tuple[float, ...]) -> YuenBlock:
    if len(values) != 10 or any(not math.isfinite(value) for value in values):
        raise ValueError("fixed block must contain ten finite returns")
    ordered = sorted(values)
    trimmed_mean = sum(ordered[2:8]) / 6
    winsorized = [ordered[2]] * 3 + ordered[3:7] + [ordered[7]] * 3
    if len(winsorized) != 10:
        raise AssertionError("Winsorized block construction drift")
    winsor_mean = sum(winsorized) / 10
    winsor_variance = (
        sum((value - winsor_mean) ** 2 for value in winsorized) / 5
    )
    return YuenBlock(trimmed_mean, winsor_mean, winsor_variance)


def yuen_signal(
    closes: list[float],
    month_returns: int = 20,
    block_size: int = 10,
    trim_each_tail: int = 2,
    effective_size: int = 6,
    wvar_divisor: int = 5,
    score_floor: float = 0.75,
    min_se2: float = MIN_SE2,
) -> YuenSignal:
    if (
        month_returns != 20
        or block_size != 10
        or trim_each_tail != 2
        or effective_size != 6
        or wvar_divisor != 5
        or score_floor != 0.75
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

    old = yuen_block(returns[:block_size])
    recent = yuen_block(returns[block_size:])
    se2 = (
        old.winsor_variance / effective_size
        + recent.winsor_variance / effective_size
    )
    if not math.isfinite(se2) or se2 < 0.0:
        raise ValueError("unequal Winsorized variance must be finite")

    direction = 0
    score = 0.0
    if se2 > min_se2:
        score = (recent.trimmed_mean - old.trimmed_mean) / math.sqrt(se2)
        if not math.isfinite(score):
            raise ValueError("score must be finite")
        if score >= score_floor:
            direction = 1
        elif score <= -score_floor:
            direction = -1

    return YuenSignal(direction, returns, old, recent, se2, score)


def welch_41249_signal(returns: list[float]) -> tuple[int, float]:
    """Nearest-neighbor rule applied to the most-recent twelve returns."""
    values = returns[-12:]
    old = values[:6]
    recent = values[6:]
    mean_old = sum(old) / 6
    mean_recent = sum(recent) / 6
    var_old = sum((value - mean_old) ** 2 for value in old) / 5
    var_recent = sum((value - mean_recent) ** 2 for value in recent) / 5
    se2 = var_old / 6 + var_recent / 6
    if se2 <= MIN_SE2:
        return 0, 0.0
    score = (mean_recent - mean_old) / math.sqrt(se2)
    if score >= 0.75 and mean_recent > 1e-12:
        return 1, score
    if score <= -0.75 and mean_recent < -1e-12:
        return -1, score
    return 0, score


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 21 or next_month_key(endpoints[-1]) != current_month:
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


class WtiMonthlyYuen20ReferenceTests(unittest.TestCase):
    def test_positive_and_negative_trimmed_shift_are_symmetric(self) -> None:
        old = [-0.04, -0.03, -0.02, -0.01, -0.005, 0.005, 0.01, 0.02, 0.03, 0.04]
        buy_returns = old + [value + 0.02 for value in old]
        sell_returns = [value + 0.02 for value in old] + old
        buy = yuen_signal(closes_from_returns(buy_returns))
        sell = yuen_signal(closes_from_returns(sell_returns))
        self.assertEqual((buy.direction, sell.direction), (1, -1))
        self.assertAlmostEqual(buy.score, -sell.score, places=11)
        self.assertGreaterEqual(buy.score, 0.75)
        self.assertLessEqual(sell.score, -0.75)

    def test_exact_trim_and_winsor_arithmetic(self) -> None:
        block = yuen_block((-5.0, -0.5, 3.0, 0.0, 1.0, 0.0, -1.0, 0.0, 3.0, -5.0))
        expected_winsorized = (-1.0, -1.0, -1.0, -0.5, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0)
        expected_wmean = sum(expected_winsorized) / 10
        expected_wvar = sum(
            (value - expected_wmean) ** 2 for value in expected_winsorized
        ) / 5
        self.assertAlmostEqual(block.trimmed_mean, -1.0 / 12.0, places=14)
        self.assertAlmostEqual(block.winsor_mean, expected_wmean, places=14)
        self.assertAlmostEqual(block.winsor_variance, expected_wvar, places=14)

    def test_two_source_fixtures_prove_neighbor_disagreement(self) -> None:
        fixtures = [
            (
                [-5, -0.5, 3, 0, 1, 0, -1, 0, 3, -5,
                 -1, -5, -2, 0, -0.5, 1, -3, 2, -1, -3],
                -1, 0, -1.3862, 0.6079,
            ),
            (
                [-0.5, -2, -3, 3, 2, 0.5, -0.5, 3, 0, -0.5,
                 0.5, -1, -3, -3, 2, 1, 5, -5, 5, 0],
                0, 1, -0.1889, 1.5246,
            ),
        ]
        for raw, expected_yuen, expected_welch, yuen_score, welch_score in fixtures:
            scaled = [value * 0.01 for value in raw]
            result = yuen_signal(closes_from_returns(scaled))
            neighbor_direction, neighbor_score = welch_41249_signal(scaled)
            self.assertEqual(result.direction, expected_yuen)
            self.assertEqual(neighbor_direction, expected_welch)
            self.assertAlmostEqual(result.score, yuen_score, places=4)
            self.assertAlmostEqual(neighbor_score, welch_score, places=4)

    def test_degenerate_denominator_consumes_flat(self) -> None:
        result = yuen_signal(closes_from_returns([0.01] * 10 + [0.02] * 10))
        self.assertLessEqual(result.se2, MIN_SE2)
        self.assertEqual((result.direction, result.score), (0, 0.0))

    def test_inclusive_boundary_and_no_recent_mean_gate_are_literal(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("metrics.score >= strategy_score_floor", source)
        self.assertIn("metrics.score <= -strategy_score_floor", source)
        self.assertNotIn("metrics.score > strategy_score_floor", source)
        self.assertNotIn("metrics.score < -strategy_score_floor", source)
        self.assertNotIn("strategy_zero_epsilon", source)

    def test_invalid_endpoints_and_parameters_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            yuen_signal([100.0] * 20)
        with self.assertRaises(ValueError):
            yuen_signal([100.0] * 20 + [0.0])
        with self.assertRaises(ValueError):
            yuen_signal([100.0] * 20 + [math.inf])
        with self.assertRaises(ValueError):
            yuen_signal([100.0] * 21, trim_each_tail=1)

    def test_twenty_one_consecutive_completed_months(self) -> None:
        endpoints = [
            202411, 202412,
            202501, 202502, 202503, 202504, 202505, 202506,
            202507, 202508, 202509, 202510, 202511, 202512,
            202601, 202602, 202603, 202604, 202605, 202606, 202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        self.assertFalse(validate_month_keys(202608, endpoints[:-1]))
        broken = endpoints.copy()
        broken[9] = 202509
        self.assertFalse(validate_month_keys(202608, broken))

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41264")
        self.assertEqual(headers["ea_slug"], "wti-myuen20-shift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        expected = {
            "qm_ea_id": "41264",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "20",
            "strategy_block_size": "10",
            "strategy_trim_each_tail": "2",
            "strategy_effective_size": "6",
            "strategy_wvar_divisor": "5",
            "strategy_score_floor": "0.75",
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
        for token in (
            "bool Strategy_Yuen20Block",
            "bool Strategy_Yuen20Signal",
            "ArraySort(sorted);",
            "upper_index != 7",
            "index >= ArraySize(sorted)",
            "source_index >= ArraySize(sorted)",
            "index >= ArraySize(winsorized)",
            "winsor_ss / (double)strategy_wvar_divisor",
            "metrics.winsor_var_old / (double)strategy_effective_size",
            "Strategy_RecordMonthAttempt(g_decision_month_key)",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41264",
        ):
            self.assertIn(token, source)
        for forbidden in (
            "Strategy_WelchSignal", "iRSI", "iMACD", "iBands", "iStochastic"
        ):
            self.assertNotIn(forbidden, source)
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
