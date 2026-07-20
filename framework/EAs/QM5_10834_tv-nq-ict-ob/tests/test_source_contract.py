"""Outcome-blind source-contract checks for QM5_10834.

These checks inspect build inputs only. They do not open Q02 artifacts or run
the MT5 Strategy Tester.
"""

from __future__ import annotations

import hashlib
import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EA = (ROOT / "QM5_10834_tv-nq-ict-ob.mq5").read_text(encoding="utf-8")
SETS = sorted((ROOT / "sets").glob("*.set"))
SOURCE_EVIDENCE = ROOT / "docs" / "candidate-analysis" / "primary_source_evidence.json"
PINE_SOURCE = ROOT / "docs" / "candidate-analysis" / "primary_source_pine_v1.pine"
EXPECTED_PINE_SHA256 = (
    "015bb5d550a8687f506646de6c33ddfe8b29c3ed5e4ec96f3c66364edfb7f0b5"
)


def function_body(source: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", source, re.S)
    if not match:
        raise AssertionError(f"function not found: {name}")
    start = match.end() - 1
    depth = 0
    index = start
    in_string = in_line_comment = in_block_comment = False
    while index < len(source):
        char = source[index]
        next_char = source[index + 1] if index + 1 < len(source) else ""
        if in_string:
            if char == "\\":
                index += 2
                continue
            if char == '"':
                in_string = False
            index += 1
            continue
        if in_line_comment:
            if char == "\n":
                in_line_comment = False
            index += 1
            continue
        if in_block_comment:
            if char == "*" and next_char == "/":
                in_block_comment = False
                index += 2
                continue
            index += 1
            continue
        if char == '"':
            in_string = True
            index += 1
            continue
        if char == "/" and next_char == "/":
            in_line_comment = True
            index += 2
            continue
        if char == "/" and next_char == "*":
            in_block_comment = True
            index += 2
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1 : index]
        index += 1
    raise AssertionError(f"unbalanced function: {name}")


class QM10834SourceContractTests(unittest.TestCase):
    def test_public_pine_bytes_are_locally_sealed(self) -> None:
        evidence = json.loads(SOURCE_EVIDENCE.read_text(encoding="utf-8"))
        digest = hashlib.sha256(PINE_SOURCE.read_bytes()).hexdigest()
        self.assertEqual(digest, EXPECTED_PINE_SHA256)
        self.assertEqual(evidence["sha256"], EXPECTED_PINE_SHA256)
        self.assertEqual(evidence["line_endings"], "CRLF")
        self.assertIn(
            "docs/candidate-analysis/primary_source_pine_v1.pine",
            (ROOT / "SPEC.md").read_text(encoding="utf-8"),
        )

    def test_session_uses_closed_bar_and_half_open_endpoint(self) -> None:
        window = function_body(EA, "InEntryWindowAt")
        entry = function_body(EA, "Strategy_EntrySignal")
        exit_signal = function_body(EA, "EntryWindowEnded")
        self.assertIn("minutes < HHMMToMinutes(strategy_entry_end_hhmm)", window)
        self.assertIn("iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1)", entry)
        self.assertIn("!InEntryWindowAt(bar_time)", entry)
        self.assertIn(">= HHMMToMinutes(strategy_entry_end_hhmm)", exit_signal)

    def test_setup_fsm_requires_distinct_bars_and_fresh_cross(self) -> None:
        entry = function_body(EA, "Strategy_EntrySignal")
        self.assertIn("SETUP_WAIT_SWEEP", EA)
        self.assertIn("SETUP_WAIT_MSS", EA)
        self.assertIn("SETUP_WAIT_MITIGATION", EA)
        self.assertIn("bar_time > g_bull_sweep_bar_time", entry)
        self.assertIn("bar_time > g_bear_sweep_bar_time", entry)
        self.assertIn("bar_time > g_bull_mss_bar_time", entry)
        self.assertIn("bar_time > g_bear_mss_bar_time", entry)
        self.assertIn("close1 > swing_high && close2 <= swing_high", entry)
        self.assertIn("close1 < swing_low && close2 >= swing_low", entry)
        self.assertEqual(entry.count("g_bull_ob_low = ob_low;"), 1)
        self.assertEqual(entry.count("g_bear_ob_low = ob_low;"), 1)

    def test_public_pine_atr55_refinement_is_bound(self) -> None:
        refine = function_body(EA, "RefinedOBLevels")
        self.assertIn("strategy_ob_refine_atr_period = 55", EA)
        self.assertIn("candle_range <= refine_atr * 0.5", refine)
        self.assertIn("ob_low = low;", refine)
        self.assertIn("ob_high = close;", refine)
        self.assertIn("ob_low = close;", refine)
        self.assertIn("ob_high = high;", refine)
        self.assertNotIn("OB_AGGRESSIVE_HALF", EA)

    def test_missing_bias_data_is_fail_closed(self) -> None:
        bias = function_body(EA, "TryDailyBias")
        entry = function_body(EA, "Strategy_EntrySignal")
        self.assertIn("if(ema <= 0.0)", bias)
        self.assertIn("if(ref_price <= 0.0)", bias)
        self.assertIn("if(!TryDailyBias(bullish_bias))", entry)

    def test_news_cannot_preempt_management_or_force_flat(self) -> None:
        on_tick = function_body(EA, "OnTick")
        self.assertLess(
            on_tick.index("QM_FrameworkHandleFridayClose()"),
            on_tick.index("Strategy_NewsFilterHook(broker_now)"),
        )
        self.assertLess(
            on_tick.index("Strategy_ExitSignal()"),
            on_tick.index("Strategy_NewsFilterHook(broker_now)"),
        )
        self.assertLess(
            on_tick.index("Strategy_NewsFilterHook(broker_now)"),
            on_tick.index("Strategy_EntrySignal(req)"),
        )

    def test_day_is_consumed_only_after_checked_open_and_is_restored(self) -> None:
        entry = function_body(EA, "Strategy_EntrySignal")
        on_tick = function_body(EA, "OnTick")
        refresh = function_body(EA, "RefreshNYDayState")
        restore = function_body(EA, "TryRestoreTradeState")
        self.assertNotIn("g_trade_taken_today = true", entry)
        send = on_tick.index("QM_TM_OpenPosition(req, out_ticket)")
        checked = on_tick.index("&& out_ticket > 0")
        marked = on_tick.index("MarkTradeOpenedToday();")
        self.assertLess(send, checked)
        self.assertLess(checked, marked)
        self.assertIn("TryRestoreTradeState(trade_seen)", refresh)
        self.assertIn("DEAL_ENTRY_IN", restore)
        self.assertIn("NYDayKey(deal_time)", restore)

    def test_all_baseline_sets_bind_risk_news_and_source_defaults(self) -> None:
        self.assertEqual(len(SETS), 5)
        for set_path in SETS:
            content = set_path.read_text(encoding="utf-8-sig")
            self.assertIn("RISK_FIXED=1000", content)
            self.assertIn("RISK_PERCENT=0", content)
            self.assertIn("qm_news_temporal=3", content)
            self.assertIn("qm_news_compliance=1", content)
            self.assertIn("qm_news_mode_legacy=0", content)
            self.assertIn("qm_stress_reject_probability=0", content)
            self.assertIn("strategy_ob_refinement=OB_DEFENSIVE_ATR55", content)
            self.assertIn("strategy_ob_refine_atr_period=55", content)


if __name__ == "__main__":
    unittest.main()
