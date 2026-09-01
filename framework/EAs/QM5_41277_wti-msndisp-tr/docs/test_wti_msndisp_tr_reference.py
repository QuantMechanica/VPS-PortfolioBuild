from __future__ import annotations

import math
import unittest
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
SOURCE = EA_DIR / "QM5_41277_wti-msndisp-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41277_wti-msndisp-tr_XTIUSD.DWX_D1_backtest.set"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41277_wti-msndisp-tr_card.md"
)


def closes_from_returns(values: list[float], start: float = 100.0) -> list[float]:
    closes = [start]
    for value in values:
        closes.append(closes[-1] * math.exp(value))
    return closes


def classify_sn(net: float, sn_core: float) -> int:
    if not math.isfinite(net) or not math.isfinite(sn_core) or sn_core <= 1e-12:
        return 0
    threshold = 3.0 * sn_core
    if net >= threshold:
        return 1
    if net <= -threshold:
        return -1
    return 0


def sn_metrics(
    closes: list[float],
) -> tuple[int, float, float, list[float], list[list[float]]]:
    if len(closes) != 17 or any(not math.isfinite(x) or x <= 0 for x in closes):
        raise ValueError("seventeen positive finite closes required")
    returns = [
        math.log(closes[index + 1] / closes[index]) for index in range(16)
    ]
    net = sum(returns)
    endpoint = math.log(closes[16] / closes[0])
    if abs(net - endpoint) > 1e-10:
        raise ValueError("endpoint identity failed")

    distance_rows = [
        sorted(
            abs(returns[subject] - returns[peer])
            for peer in range(16)
            if peer != subject
        )
        for subject in range(16)
    ]
    if any(len(row) != 15 for row in distance_rows):
        raise ValueError("leave-one-out distance count failed")
    inner_medians = sorted(row[7] for row in distance_rows)
    if len(inner_medians) != 16:
        raise ValueError("outer count failed")
    sn_core = inner_medians[7]
    return classify_sn(net, sn_core), net, sn_core, inner_medians, distance_rows


def qn_direction(values: list[float]) -> int:
    distances = sorted(
        abs(values[right] - values[left])
        for left in range(15)
        for right in range(left + 1, 16)
    )
    core = distances[35]
    net = sum(values)
    if core <= 1e-12:
        return 0
    if net >= 4.0 * core:
        return 1
    if net <= -4.0 * core:
        return -1
    return 0


def l1_direction(values: list[float]) -> int:
    net = sum(values)
    path = sum(abs(value) for value in values)
    if path <= 0:
        return 0
    return (1 if net > 0 else -1) if abs(net) / path >= 0.20 else 0


def rms_direction(values: list[float]) -> int:
    mean = sum(values) / len(values)
    rms = math.sqrt(sum(value * value for value in values) / len(values))
    if rms <= 0:
        return 0
    return (1 if mean > 0 else -1) if abs(mean) / rms >= 0.15 else 0


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


FIXTURE_SN_ONLY = [
    0.008232,
    0.000939,
    -0.003412,
    -0.014585,
    -0.001265,
    0.003701,
    0.005557,
    -0.004145,
    0.001404,
    -0.005253,
    -0.016244,
    0.018212,
    0.000576,
    -0.000055,
    0.025836,
    -0.002419,
]

FIXTURE_QN_L1_RMS_ONLY = [
    0.001685,
    -0.010370,
    -0.005073,
    -0.006910,
    -0.007936,
    0.005197,
    0.013921,
    -0.001685,
    0.003583,
    0.008084,
    0.003411,
    -0.002320,
    0.011475,
    0.001997,
    -0.001300,
    0.005011,
]


class WtiMonthlySnDispersionReferenceTests(unittest.TestCase):
    def test_raw_nested_lower_medians(self) -> None:
        values = [float(index) / 1000.0 for index in range(16)]
        _, _, sn_core, inner_medians, rows = sn_metrics(
            closes_from_returns(values)
        )
        self.assertEqual(sum(len(row) for row in rows), 240)
        self.assertTrue(all(len(row) == 15 for row in rows))
        self.assertEqual(inner_medians, sorted(row[7] for row in rows))
        self.assertEqual(sn_core, inner_medians[7])
        self.assertNotEqual(sn_core, 1.1926 * inner_medians[7])

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
        _, net, _, _, _ = sn_metrics(closes)
        self.assertAlmostEqual(net, sum(values), places=12)
        self.assertAlmostEqual(net, math.log(closes[-1] / closes[0]), places=12)

    def test_inclusive_three_core_boundaries(self) -> None:
        self.assertEqual(classify_sn(0.03, 0.01), 1)
        self.assertEqual(classify_sn(-0.03, 0.01), -1)
        self.assertEqual(classify_sn(math.nextafter(0.03, 0.0), 0.01), 0)
        self.assertEqual(classify_sn(math.nextafter(-0.03, 0.0), 0.01), 0)
        self.assertEqual(classify_sn(0.03, 1e-12), 0)

    def test_sn_only_fixture_disagrees_with_three_neighbors(self) -> None:
        direction, net, core, _, _ = sn_metrics(
            closes_from_returns(FIXTURE_SN_ONLY)
        )
        self.assertEqual(direction, 1)
        self.assertGreaterEqual(net, 3.0 * core)
        self.assertEqual(qn_direction(FIXTURE_SN_ONLY), 0)
        self.assertEqual(l1_direction(FIXTURE_SN_ONLY), 0)
        self.assertEqual(rms_direction(FIXTURE_SN_ONLY), 0)

        reverse, _, reverse_core, _, _ = sn_metrics(
            closes_from_returns([-value for value in FIXTURE_SN_ONLY])
        )
        self.assertEqual(reverse, -1)
        self.assertAlmostEqual(reverse_core, core, places=12)

    def test_flat_fixture_qualifies_qn_l1_and_rms_neighbors(self) -> None:
        direction, net, core, _, _ = sn_metrics(
            closes_from_returns(FIXTURE_QN_L1_RMS_ONLY)
        )
        self.assertEqual(direction, 0)
        self.assertLess(abs(net), 3.0 * core)
        self.assertEqual(qn_direction(FIXTURE_QN_L1_RMS_ONLY), 1)
        self.assertEqual(l1_direction(FIXTURE_QN_L1_RMS_ONLY), 1)
        self.assertEqual(rms_direction(FIXTURE_QN_L1_RMS_ONLY), 1)

    def test_zero_core_fails_closed(self) -> None:
        direction, _, core, _, _ = sn_metrics(
            closes_from_returns([0.001] * 16)
        )
        self.assertEqual(core, 0.0)
        self.assertEqual(direction, 0)

    def test_source_contract_and_no_banned_indicators(self) -> None:
        source = SOURCE.read_text(encoding="utf-8-sig")
        required = (
            'const string g_symbol = "XTIUSD.DWX"',
            "double log_returns[16]",
            "double inner_medians[16]",
            "double distances[15]",
            "inner_medians[subject] = distances[7]",
            "metrics.sn_core = inner_medians[7]",
            "metrics.directed_distance_count != 240",
            "metrics.net_return >= metrics.threshold",
            "metrics.net_return <= -metrics.threshold",
            "metrics.endpoint_error > strategy_endpoint_tolerance",
            "Strategy_RecordMonthAttempt",
            "Strategy_LoadCompletedMonthCloses",
            "QM_FrameworkMagic() != 412770000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41277",
        )
        for literal in required:
            self.assertIn(literal, source)
        prepare = source[source.index("void Strategy_PrepareDecisionSignal") :]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadCompletedMonthCloses"),
        )
        self.assertNotIn("1.1926", source)
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
        self.assertEqual(headers["ea_id"], "41277")
        self.assertEqual(headers["ea_slug"], "wti-msndisp-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41277",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_sessions_min": "17",
            "strategy_month_sessions_max": "23",
            "strategy_close_count": "17",
            "strategy_return_count": "16",
            "strategy_inner_distance_count": "15",
            "strategy_inner_median_one_based": "8",
            "strategy_outer_count": "16",
            "strategy_outer_lomed_one_based": "8",
            "strategy_sn_core_floor": "0.000000000001",
            "strategy_net_core_multiplier": "3.0",
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

