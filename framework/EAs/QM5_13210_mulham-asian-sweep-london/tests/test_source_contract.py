"""Outcome-blind source-contract checks for QM5_13210.

These tests inspect only the build inputs. They deliberately do not open Q02
artifacts or invoke the MT5 Strategy Tester.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EA = (ROOT / "QM5_13210_mulham-asian-sweep-london.mq5").read_text(
    encoding="utf-8"
)
SETS = sorted((ROOT / "sets").glob("*.set"))


def function_body(source: str, name: str) -> str:
    """Return an MQL function body while ignoring comments and strings."""

    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", source, re.S)
    if not match:
        raise AssertionError(f"function not found: {name}")
    start = match.end() - 1
    depth = 0
    index = start
    in_string = False
    in_line_comment = False
    in_block_comment = False
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


class QM13210SourceContractTests(unittest.TestCase):
    def test_state_advances_before_news_entry_gate(self) -> None:
        on_tick = function_body(EA, "OnTick")
        self.assertLess(
            on_tick.index("QM13210_AdvanceStateOnNewBar();"),
            on_tick.index("QM13210_NewsAllowsEntryNow(broker_now)"),
        )
        self.assertLess(
            on_tick.index("QM13210_NewsAllowsEntryNow(broker_now)"),
            on_tick.index("QM_TM_OpenPosition(req, out_ticket)"),
        )

    def test_asia_window_requires_exactly_48_contiguous_m5_bars(self) -> None:
        inputs = function_body(EA, "QM13210_InputsValid")
        complete = function_body(EA, "QM13210_AsiaWindowComplete")
        advance = function_body(EA, "QM13210_AdvanceStateOnNewBar")
        self.assertIn("QM13210_ASIA_REQUIRED_BARS = 48", EA)
        self.assertIn("QM13210_ASIA_REQUIRED_BARS * QM13210_M5_SECONDS", inputs)
        self.assertIn("g_asia_bars != QM13210_ASIA_REQUIRED_BARS", complete)
        self.assertIn("g_asia_contiguous", complete)
        self.assertIn("bar_open != g_asia_last_bar_open + QM13210_M5_SECONDS", advance)

    def test_sweep_confirmation_is_subsequent_and_invalidates_both_routes(self) -> None:
        advance = function_body(EA, "QM13210_AdvanceStateOnNewBar")
        opposite = function_body(EA, "QM13210_OppositeSweepInvalidates")
        target = function_body(EA, "QM13210_TargetAlreadyTouched")
        self.assertGreaterEqual(advance.count("g_sweep_bar_open = bar_open;"), 2)
        self.assertIn("bar_open <= g_sweep_bar_open", advance)
        self.assertGreaterEqual(
            advance.count("structure/FVG confirmation must be on a subsequent bar"), 2
        )
        self.assertIn("high > g_sweep_high_ref", opposite)
        self.assertIn("low < g_sweep_low_ref", opposite)
        self.assertIn("high >= target", target)
        self.assertIn("low <= target", target)

    def test_pending_order_deadline_and_live_cancellation_fail_closed(self) -> None:
        deadline = function_body(EA, "QM13210_ComputeEntryDeadline")
        manage = function_body(EA, "Strategy_ManageOpenPosition")
        self.assertIn("QM_NewsNextBlockStart", deadline)
        self.assertIn("QM_NEWS_BLOCKSTART_DATA_ERROR", deadline)
        self.assertIn("next_news_block < out_deadline", deadline)
        self.assertIn("QM13210_NewsAllowsEntryNow(broker_now)", manage)
        self.assertIn("asian_sweep_news_cancel", manage)

    def test_both_backtest_sets_bind_the_news_axes_explicitly(self) -> None:
        self.assertEqual(len(SETS), 2)
        for set_path in SETS:
            content = set_path.read_text(encoding="utf-8-sig")
            self.assertIn("qm_news_temporal=3", content)
            self.assertIn("qm_news_compliance=1", content)
            self.assertIn("qm_news_min_impact=high", content)
            self.assertIn("qm_news_mode_legacy=0", content)

    def test_day_is_consumed_only_after_checked_order_acceptance(self) -> None:
        entry = function_body(EA, "Strategy_EntrySignal")
        on_tick = function_body(EA, "OnTick")
        self.assertNotIn("QM13210_ORDER_PLACED", entry)
        self.assertNotIn("g_entry_ready = false", entry)
        send = on_tick.index("QM_TM_OpenPosition(req, out_ticket)")
        checked = on_tick.index("if(placed && out_ticket > 0)")
        consumed = on_tick.index("g_phase = QM13210_ORDER_PLACED")
        self.assertLess(send, checked)
        self.assertLess(checked, consumed)


if __name__ == "__main__":
    unittest.main()
