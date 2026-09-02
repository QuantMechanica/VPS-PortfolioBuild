from __future__ import annotations

import json
import math
import re
import unittest
from dataclasses import dataclass
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41318_xauxag-msndisp-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41318_xauxag-msndisp-rv_"
    "QM5_41318_XAU_XAG_SN_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
FIXTURE = REPO_ROOT / "artifacts" / "qm5_xauxag_msndisp_rv_reference_fixture_20260902.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41318_xauxag-msndisp-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"


@dataclass(frozen=True)
class SnSignal:
    direction: int
    net: float
    endpoint: float
    endpoint_error: float
    sn_core: float
    threshold: float
    directed_distance_count: int
    inner_values: tuple[float, ...]


def raw_sn_signal(relative_returns: list[float]) -> SnSignal:
    if len(relative_returns) != 16 or any(not math.isfinite(value) for value in relative_returns):
        raise ValueError("sixteen finite relative returns required")
    inner: list[float] = []
    directed_count = 0
    for subject, value in enumerate(relative_returns):
        distances = sorted(
            abs(value - peer_value)
            for peer, peer_value in enumerate(relative_returns)
            if peer != subject
        )
        directed_count += len(distances)
        if len(distances) != 15:
            raise AssertionError("each leave-one-out array must have fifteen distances")
        inner.append(distances[7])
    ordered_inner = sorted(inner)
    sn_core = ordered_inner[7]
    net = math.fsum(relative_returns)
    endpoint = relative_returns[-1]
    for value in reversed(relative_returns[:-1]):
        endpoint += value
    endpoint_error = abs(net - endpoint)
    threshold = 3.0 * sn_core
    direction = -1 if net >= threshold else 1 if net <= -threshold else 0
    return SnSignal(
        direction,
        net,
        endpoint,
        endpoint_error,
        sn_core,
        threshold,
        directed_count,
        tuple(inner),
    )


def log_ratios(xau: list[float], xag: list[float]) -> list[float]:
    if len(xau) != 17 or len(xag) != 17:
        raise ValueError("exactly seventeen synchronized closes required")
    if any(not math.isfinite(value) or value <= 0.0 for value in xau + xag):
        raise ValueError("positive finite closes required")
    return [math.log(gold) - math.log(silver) for gold, silver in zip(xau, xag, strict=True)]


def select_final_seventeen(
    xau_pairs: list[tuple[int, float]], xag_pairs: list[tuple[int, float]]
) -> list[tuple[int, float, float]]:
    if not 17 <= len(xau_pairs) <= 23 or len(xau_pairs) != len(xag_pairs):
        raise ValueError("completed month must have 17-23 complete pairs")
    if any(left[0] != right[0] for left, right in zip(xau_pairs, xag_pairs, strict=True)):
        raise ValueError("timestamp mismatch")
    if any(right[0] <= left[0] for left, right in zip(xau_pairs[:-1], xau_pairs[1:], strict=True)):
        raise ValueError("timestamps must be unique and chronological")
    return [
        (gold[0], gold[1], silver[1])
        for gold, silver in zip(xau_pairs[-17:], xag_pairs[-17:], strict=True)
    ]


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
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return headers, values


class MonthlySnReferenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))

    def test_frozen_two_way_family_disagreement_fixtures(self) -> None:
        self.assertFalse(self.fixture["market_data"])
        contract = self.fixture["contract"]
        self.assertEqual(
            (
                contract["return_count"],
                contract["directed_distance_count"],
                contract["inner_order_index_zero_based"],
                contract["outer_order_index_zero_based"],
                contract["consistency_multiplier_applied"],
                contract["finite_sample_multiplier_applied"],
            ),
            (16, 240, 7, 7, False, False),
        )
        for fixture in self.fixture["fixtures"]:
            signal = raw_sn_signal(fixture["relative_log_returns"])
            self.assertEqual(signal.direction, fixture["candidate_direction"])
            self.assertEqual(signal.directed_distance_count, 240)
            self.assertEqual(len(signal.inner_values), 16)
            self.assertAlmostEqual(signal.net, fixture["net"], places=12)
            self.assertAlmostEqual(signal.sn_core, fixture["sn_core"], places=12)
            self.assertAlmostEqual(signal.threshold, fixture["three_core_threshold"], places=12)
        candidate_only = self.fixture["fixtures"][0]
        neighbor_only = self.fixture["fixtures"][2]
        self.assertEqual(
            (
                candidate_only["candidate_direction"],
                candidate_only["qn_four_core_direction"],
                candidate_only["l1_coherence_direction"],
                candidate_only["rms_coherence_direction"],
            ),
            (-1, 0, 0, 0),
        )
        self.assertEqual(
            (
                neighbor_only["candidate_direction"],
                neighbor_only["qn_four_core_direction"],
                neighbor_only["l1_coherence_direction"],
                neighbor_only["rms_coherence_direction"],
            ),
            (0, -1, -1, -1),
        )

    def test_ratio_orientation_endpoint_identity_and_contrarian_side(self) -> None:
        returns = self.fixture["fixtures"][0]["relative_log_returns"]
        ratios = [math.log(80.0)]
        for value in returns:
            ratios.append(ratios[-1] + value)
        xag = [25.0] * 17
        xau = [silver * math.exp(ratio) for silver, ratio in zip(xag, ratios, strict=True)]
        reconstructed = log_ratios(xau, xag)
        derived = [right - left for left, right in zip(reconstructed[:-1], reconstructed[1:], strict=True)]
        signal = raw_sn_signal(derived)
        self.assertEqual(signal.direction, -1)
        self.assertLessEqual(abs(math.fsum(derived) - (reconstructed[-1] - reconstructed[0])), 1.0e-10)
        self.assertLessEqual(signal.endpoint_error, 1.0e-15)

    def test_inclusive_three_core_boundary_is_contrarian(self) -> None:
        self.assertEqual(-1 if 0.03 >= 3.0 * 0.01 else 0, -1)
        self.assertEqual(1 if -0.03 <= -3.0 * 0.01 else 0, 1)

    def test_exact_pairing_session_bounds_and_final_seventeen(self) -> None:
        xau = [(20260801 + index, 2400.0 + index) for index in range(20)]
        xag = [(20260801 + index, 30.0 + index / 10.0) for index in range(20)]
        selected = select_final_seventeen(xau, xag)
        self.assertEqual((selected[0][0], selected[-1][0]), (20260804, 20260820))
        shifted = xag.copy()
        shifted[9] = (20990101, shifted[9][1])
        with self.assertRaises(ValueError):
            select_final_seventeen(xau, shifted)
        with self.assertRaises(ValueError):
            select_final_seventeen(xau + [(20260821 + index, 2500.0) for index in range(4)], xag + [(20260821 + index, 31.0) for index in range(4)])

    def test_source_manifest_registry_and_card_copy_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        headers, values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41318",
            "qm_magic_slot_offset": "0",
            "qm_rng_seed": "42",
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
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41318_XAU_XAG_SN_RV_D1")
        self.assertEqual(
            (
                manifest["host_symbol"], manifest["host_timeframe"],
                manifest["tester_currency"], manifest["tester_deposit"],
                manifest["q02_from_date"], manifest["q02_to_date"],
            ),
            ("XAUUSD.DWX", "D1", "USD", 100000, "2018.07.02", "2024.12.31"),
        )
        required_source_fragments = (
            "xau_bars[xau_index].time != xag_bars[xag_index].time",
            "session_count >= strategy_month_sessions_max",
            "newest_first_ratios[session_count]",
            "endpoint_error > strategy_endpoint_tolerance",
            "MathAbs(relative_returns[subject] - relative_returns[peer])",
            "directed_distance_count != 240",
            "distances[strategy_inner_median_one_based - 1]",
            "inner_medians[strategy_outer_lomed_one_based - 1]",
            "if(net_return >= threshold)",
            "direction = -1",
            "else if(net_return <= -threshold)",
            "direction = 1",
            "Strategy_ForeignExposureExists()",
            "target != 0.0",
            "double raw_xau_lots = 0.5 * full_xau_lots",
            "QM_BasketOpenPosition",
            "Strategy_PairCompositionValid(g_pair_expected_direction)",
            "Strategy_CloseAllOwned(QM_EXIT_TIME_STOP)",
        )
        for fragment in required_source_fragments:
            self.assertIn(fragment, source)
        self.assertNotRegex(source, re.compile(r"sn_core\s*=\s*1\.1926|sn_core\s*\*=|finite[_ -]?sample[_ -]?factor\s*\*", re.I))
        self.assertNotRegex(
            source,
            re.compile(r"\bi(?:RSI|MACD|Bands)\b|WebRequest|FileOpen|Python|ONNX|tensorflow|torch|sklearn|keras", re.I),
        )
        on_tick = source[source.index("void OnTick()") : source.index("void OnTimer()")]
        self.assertLess(
            on_tick.index("Strategy_RecordAttemptState(g_signal_month_key)"),
            on_tick.index("Strategy_EntryWindowReady(g_signal_month_key"),
        )
        registry = MAGIC_REGISTRY.read_text(encoding="utf-8-sig")
        self.assertIn("41318,xauxag-msndisp-rv,0,XAUUSD.DWX,413180000", registry)
        self.assertIn("41318,xauxag-msndisp-rv,1,XAGUSD.DWX,413180001", registry)
        self.assertEqual(EA_CARD.read_text(encoding="utf-8-sig"), CANONICAL_CARD.read_text(encoding="utf-8-sig"))

    def test_only_logical_and_component_fixed_risk_backtest_sets_exist(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertIn(LOGICAL_SET, setfiles)
        self.assertFalse(
            any(token in path.name.lower() for path in setfiles for token in ("live", "demo", "shadow", "stress"))
        )
        input_names = set(
            re.findall(
                r"(?m)^input\s+(?!group\b)(?:\w+\s+)+(\w+)\s*=",
                EA_SOURCE.read_text(encoding="utf-8-sig"),
            )
        )
        for path in setfiles:
            headers, values = parse_setfile(path)
            self.assertEqual((values["RISK_FIXED"], values["RISK_PERCENT"]), ("1000", "0"))
            self.assertEqual(values["PORTFOLIO_WEIGHT"], "1")
            self.assertTrue(set(values) <= input_names)
            self.assertTrue({name for name in input_names if name.startswith("strategy_")} <= set(values))
            if path == LOGICAL_SET:
                self.assertEqual(set(values), input_names)
            self.assertEqual(headers["environment"], "backtest")
            self.assertEqual(headers["risk_mode"], "FIXED")
            self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")


if __name__ == "__main__":
    unittest.main()
