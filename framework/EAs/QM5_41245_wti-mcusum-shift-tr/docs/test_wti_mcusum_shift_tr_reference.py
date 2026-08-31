from __future__ import annotations

import dataclasses
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41245_wti-mcusum-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41245_wti-mcusum-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41245_wti-mcusum-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class CusumSignal:
    direction: int
    returns: tuple[float, ...]
    mean_return: float
    cusums: tuple[float, ...]
    max_abs_cusum: float
    change_index: int
    selected_cusum: float
    maxima_count: int
    post_mean: float


def closes_from_returns(returns: list[float], initial: float = 100.0) -> list[float]:
    closes = [initial]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def cusum_signal(
    closes: list[float],
    month_returns: int = 12,
    min_split: int = 4,
    max_split: int = 8,
    epsilon: float = EPSILON,
) -> CusumSignal:
    if (
        month_returns != 12
        or min_split != 4
        or max_split != 8
        or epsilon != EPSILON
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

    mean_return = sum(returns) / month_returns
    if not math.isfinite(mean_return):
        raise ValueError("mean must be finite")
    running = 0.0
    path: list[float] = []
    for split in range(1, month_returns):
        running += returns[split - 1]
        value = running - split * mean_return
        if not math.isfinite(value):
            raise ValueError("path must be finite")
        path.append(value)
    cusums = tuple(path)
    if len(cusums) != 11:
        raise AssertionError("terminal zero was included")

    maximum = max(abs(value) for value in cusums)
    maxima = tuple(
        split
        for split, value in enumerate(cusums, start=1)
        if abs(abs(value) - maximum) <= epsilon
    )
    change_index = maxima[0]
    selected = cusums[change_index - 1]
    direction = 0
    post_mean = 0.0
    if (
        maximum > epsilon
        and len(maxima) == 1
        and min_split <= change_index <= max_split
    ):
        post = returns[change_index:]
        post_mean = sum(post) / len(post)
        if not math.isfinite(post_mean):
            raise ValueError("post mean must be finite")
        if post_mean > epsilon:
            direction = 1
        elif post_mean < -epsilon:
            direction = -1

    return CusumSignal(
        direction=direction,
        returns=returns,
        mean_return=mean_return,
        cusums=cusums,
        max_abs_cusum=maximum,
        change_index=change_index,
        selected_cusum=selected,
        maxima_count=len(maxima),
        post_mean=post_mean,
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


class WtiMonthlyCusumReferenceTests(unittest.TestCase):
    def test_unique_central_shift_is_symmetric(self) -> None:
        buy = cusum_signal(closes_from_returns([-0.02] * 6 + [0.03] * 6))
        sell = cusum_signal(closes_from_returns([0.02] * 6 + [-0.03] * 6))
        self.assertEqual((buy.direction, buy.change_index, buy.maxima_count), (1, 6, 1))
        self.assertEqual((sell.direction, sell.change_index, sell.maxima_count), (-1, 6, 1))
        self.assertAlmostEqual(buy.max_abs_cusum, 0.15, places=12)
        self.assertAlmostEqual(sell.max_abs_cusum, 0.15, places=12)
        self.assertAlmostEqual(buy.post_mean, 0.03, places=12)
        self.assertAlmostEqual(sell.post_mean, -0.03, places=12)

    def test_tied_and_edge_maxima_consume_flat(self) -> None:
        tied = cusum_signal(closes_from_returns([0.02, -0.02] * 6))
        edge = cusum_signal(closes_from_returns([-0.05] * 2 + [0.01] * 10))
        self.assertEqual((tied.direction, tied.maxima_count), (0, 6))
        self.assertEqual((edge.direction, edge.change_index, edge.maxima_count), (0, 2, 1))

    def test_zero_post_mean_and_zero_path_consume_flat(self) -> None:
        zero_post = cusum_signal(
            closes_from_returns([-0.02] * 6 + [0.01, -0.01] * 3)
        )
        zero_path = cusum_signal(closes_from_returns([0.01] * 12))
        self.assertEqual((zero_post.change_index, zero_post.maxima_count), (6, 1))
        self.assertEqual(zero_post.direction, 0)
        self.assertAlmostEqual(zero_post.post_mean, 0.0, places=12)
        self.assertEqual(zero_path.direction, 0)
        self.assertLessEqual(zero_path.max_abs_cusum, EPSILON)

    def test_terminal_zero_is_not_a_candidate(self) -> None:
        signal = cusum_signal(closes_from_returns([-0.02] * 6 + [0.03] * 6))
        terminal = sum(signal.returns) - 12 * signal.mean_return
        self.assertEqual(len(signal.cusums), 11)
        self.assertAlmostEqual(terminal, 0.0, places=15)

    def test_invalid_endpoints_and_parameters_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            cusum_signal([100.0] * 12)
        with self.assertRaises(ValueError):
            cusum_signal([100.0] * 12 + [0.0])
        with self.assertRaises(ValueError):
            cusum_signal([100.0] * 12 + [math.inf])
        with self.assertRaises(ValueError):
            cusum_signal([100.0] * 13, min_split=3)

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
        self.assertEqual(headers["ea_id"], "41245")
        self.assertEqual(headers["ea_slug"], "wti-mcusum-shift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41245",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "12",
            "strategy_min_split": "4",
            "strategy_max_split": "8",
            "strategy_tie_epsilon": "0.000000000001",
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
        self.assertIn("bool Strategy_CusumSignal", source)
        self.assertIn("ArrayResize(cusums, strategy_month_returns - 1)", source)
        self.assertIn("metrics.maxima_count == 1", source)
        self.assertIn("metrics.post_mean > strategy_tie_epsilon", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41245", source)
        self.assertNotIn("Strategy_PettittSignal", source)
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
