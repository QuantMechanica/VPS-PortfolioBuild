from __future__ import annotations

import math
import unittest
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
SOURCE = EA_DIR / "QM5_41275_wti-mqndisp-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41275_wti-mqndisp-tr_XTIUSD.DWX_D1_backtest.set"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41275_wti-mqndisp-tr_card.md"
)


def closes_from_returns(values: list[float], start: float = 100.0) -> list[float]:
    closes = [start]
    for value in values:
        closes.append(closes[-1] * math.exp(value))
    return closes


def qn_metrics(closes: list[float]) -> tuple[int, float, float, list[float]]:
    if len(closes) != 17 or any(not math.isfinite(x) or x <= 0 for x in closes):
        raise ValueError("seventeen positive finite closes required")
    returns = [
        math.log(closes[index + 1] / closes[index]) for index in range(16)
    ]
    net = sum(returns)
    endpoint = math.log(closes[16] / closes[0])
    if abs(net - endpoint) > 1e-10:
        raise ValueError("endpoint identity failed")
    distances = sorted(
        abs(returns[right] - returns[left])
        for left in range(15)
        for right in range(left + 1, 16)
    )
    if len(distances) != 120:
        raise ValueError("distance count failed")
    q_core = distances[35]
    direction = classify(net, q_core)
    return direction, net, q_core, distances


def classify(net: float, q_core: float) -> int:
    if not math.isfinite(net) or not math.isfinite(q_core) or q_core <= 1e-12:
        return 0
    threshold = 4.0 * q_core
    if net >= threshold:
        return 1
    if net <= -threshold:
        return -1
    return 0


def l1_direction(values: list[float]) -> int:
    net = sum(values)
    path = sum(abs(value) for value in values)
    if path <= 0:
        return 0
    efficiency = abs(net) / path
    return (1 if net > 0 else -1) if efficiency >= 0.20 else 0


def rms_direction(values: list[float]) -> int:
    mean = sum(values) / len(values)
    rms = math.sqrt(sum(value * value for value in values) / len(values))
    if rms <= 0:
        return 0
    coherence = abs(mean) / rms
    return (1 if mean > 0 else -1) if coherence >= 0.15 else 0


def parse_setfile(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    headers: dict[str, str] = {}
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line.startswith(";") and ":" in line:
            key, value = line[1:].split(":", 1)
            headers[key.strip()] = value.strip()
        elif line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return headers, values


class WtiMonthlyQnDispersionReferenceTests(unittest.TestCase):
    def test_qn_index_is_raw_36th_of_120_distances(self) -> None:
        values = [float(index) / 1000.0 for index in range(16)]
        _, _, q_core, distances = qn_metrics(closes_from_returns(values))
        self.assertEqual(len(distances), math.comb(16, 2))
        self.assertEqual(math.comb(math.floor(16 / 2) + 1, 2), 36)
        self.assertEqual(q_core, distances[35])
        self.assertNotEqual(q_core, 2.2219 * distances[35])

    def test_endpoint_identity_and_return_orientation(self) -> None:
        values = [
            0.001,
            -0.003,
            0.004,
            0.002,
            -0.001,
            0.006,
            -0.002,
            0.005,
            0.003,
            -0.004,
            0.007,
            -0.005,
            0.0025,
            0.0015,
            -0.0005,
            0.0045,
        ]
        closes = closes_from_returns(values)
        _, net, _, _ = qn_metrics(closes)
        self.assertAlmostEqual(net, sum(values), places=12)
        self.assertAlmostEqual(net, math.log(closes[-1] / closes[0]), places=12)

    def test_inclusive_four_core_boundaries(self) -> None:
        self.assertEqual(classify(0.04, 0.01), 1)
        self.assertEqual(classify(-0.04, 0.01), -1)
        self.assertEqual(classify(math.nextafter(0.04, 0.0), 0.01), 0)
        self.assertEqual(classify(math.nextafter(-0.04, 0.0), 0.01), 0)
        self.assertEqual(classify(0.04, 1e-12), 0)

    def test_long_counterexample_differs_from_l1_and_rms_neighbors(self) -> None:
        values = [
            0.0010,
            0.0011,
            0.0009,
            0.0012,
            0.0008,
            0.0013,
            0.0007,
            0.0014,
            0.0006,
            0.0015,
            0.0005,
            0.0016,
            -0.0500,
            0.0491,
            -0.0400,
            0.0402,
        ]
        direction, net, q_core, _ = qn_metrics(closes_from_returns(values))
        self.assertEqual(direction, 1)
        self.assertGreaterEqual(net, 4.0 * q_core)
        self.assertEqual(l1_direction(values), 0)
        self.assertEqual(rms_direction(values), 0)
        reverse_direction, _, reverse_core, _ = qn_metrics(
            closes_from_returns([-value for value in values])
        )
        self.assertEqual(reverse_direction, -1)
        self.assertAlmostEqual(reverse_core, q_core, places=12)

    def test_flat_counterexample_qualifies_l1_and_rms_neighbors(self) -> None:
        values = [
            -0.007421,
            0.009985,
            0.000350,
            -0.014180,
            -0.012633,
            0.004963,
            0.019301,
            0.002529,
            -0.021856,
            -0.015511,
            0.017713,
            -0.026402,
            -0.027677,
            0.006700,
            0.018567,
            0.003460,
        ]
        direction, net, q_core, _ = qn_metrics(closes_from_returns(values))
        self.assertEqual(direction, 0)
        self.assertLess(abs(net), 4.0 * q_core)
        self.assertEqual(l1_direction(values), -1)
        self.assertEqual(rms_direction(values), -1)

    def test_zero_core_fails_closed(self) -> None:
        direction, _, q_core, _ = qn_metrics(
            closes_from_returns([0.001] * 16)
        )
        self.assertEqual(q_core, 0.0)
        self.assertEqual(direction, 0)

    def test_source_contract_and_no_banned_indicators(self) -> None:
        source = SOURCE.read_text(encoding="utf-8-sig")
        required = (
            'const string g_symbol = "XTIUSD.DWX"',
            "double log_returns[16]",
            "double distances[120]",
            "metrics.q_core = distances[35]",
            "metrics.net_return >= metrics.threshold",
            "metrics.net_return <= -metrics.threshold",
            "metrics.endpoint_error > strategy_endpoint_tolerance",
            "Strategy_RecordMonthAttempt",
            "Strategy_LoadCompletedMonthCloses",
            "QM_FrameworkMagic() != 412750000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41275",
        )
        for literal in required:
            self.assertIn(literal, source)
        prepare = source[source.index("void Strategy_PrepareDecisionSignal") :]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadCompletedMonthCloses"),
        )
        self.assertNotIn("2.2219", source)
        for banned in (
            "iRSI",
            "iBands",
            "iMA(",
            "iMACD",
            "MathRand",
            "WebRequest",
            "FileOpen",
        ):
            self.assertNotIn(banned, source)

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41275")
        self.assertEqual(headers["ea_slug"], "wti-mqndisp-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41275",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_sessions_min": "17",
            "strategy_month_sessions_max": "23",
            "strategy_close_count": "17",
            "strategy_return_count": "16",
            "strategy_distance_count": "120",
            "strategy_qn_order_one_based": "36",
            "strategy_qn_core_floor": "0.000000000001",
            "strategy_net_core_multiplier": "4.0",
            "strategy_endpoint_tolerance": "0.0000000001",
            "strategy_history_bars_d1": "120",
            "strategy_entry_window_minutes": "180",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "40",
            "strategy_max_spread_points": "1500",
            "strategy_deviation_points": "20",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

    def test_card_copy_and_only_backtest_set_exist(self) -> None:
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
