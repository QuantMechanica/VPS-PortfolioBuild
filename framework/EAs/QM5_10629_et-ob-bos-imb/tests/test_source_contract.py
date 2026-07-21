"""Outcome-blind source-contract checks for the QM5_10629 repair.

These tests inspect build inputs only.  They neither compile MQL5 nor open any
Strategy Tester output.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "QM5_10629_et-ob-bos-imb.mq5").read_text(encoding="utf-8")
SPEC = (ROOT / "SPEC.md").read_text(encoding="utf-8")
USDJPY_SET = (
    ROOT / "sets" / "QM5_10629_et-ob-bos-imb_USDJPY.DWX_H1_backtest.set"
).read_text(encoding="utf-8-sig")


def function_body(name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", SOURCE, re.S)
    if not match:
        raise AssertionError(f"function not found: {name}")
    start = match.end() - 1
    depth = 0
    index = start
    in_string = in_line_comment = in_block_comment = False
    while index < len(SOURCE):
        char = SOURCE[index]
        next_char = SOURCE[index + 1] if index + 1 < len(SOURCE) else ""
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
                return SOURCE[start + 1 : index]
        index += 1
    raise AssertionError(f"unbalanced function: {name}")


class QM10629SourceContractTests(unittest.TestCase):
    def test_usdjpy_arm_remains_exact_dwx_h1_slot_two(self) -> None:
        self.assertIn("symbol:       USDJPY.DWX", USDJPY_SET)
        self.assertIn("timeframe:    H1", USDJPY_SET)
        self.assertIn("magic_slot:   2", USDJPY_SET)
        self.assertIn("qm_magic_slot_offset=2", USDJPY_SET)

    def test_swing_levels_are_confirmed_strictly_before_each_event(self) -> None:
        find_swing = function_body("Strategy_FindRecentSwingAtEvent")
        self.assertIn("event_shift + width + 1", find_swing)
        self.assertIn("event_shift + MathMax(strategy_structure_lookback", find_swing)
        freeze = function_body("Strategy_FreezeSetupForBOS")
        self.assertIn("Strategy_FindRecentSwingAtEvent(true, sweep_shift", freeze)
        self.assertIn("Strategy_FindRecentSwingAtEvent(false, sweep_shift", freeze)

    def test_sweep_bos_fvg_and_order_decision_use_distinct_closed_bars(self) -> None:
        find_latest = function_body("Strategy_FindLatestSetup")
        freeze = function_body("Strategy_FreezeSetupForBOS")
        find_ob = function_body("Strategy_FindOrderBlockBeforeBOS")
        self.assertIn("for(int bos_shift = 2;", find_latest)
        self.assertIn("for(int sweep_shift = bos_shift + 1;", freeze)
        self.assertIn("sweep_stamp >= bos_stamp", freeze)
        self.assertIn("bos_low > fvg_reference_high", freeze)
        self.assertIn("bos_high < fvg_reference_low", freeze)
        self.assertIn("strategy_bos_body_atr_mult * bos_atr", freeze)
        self.assertIn("bos_close > break_level && previous_close <= break_level", freeze)
        self.assertIn("bos_close < break_level && previous_close >= break_level", freeze)
        self.assertIn("for(int shift = bos_shift + 1;", find_ob)

    def test_midpoint_cannot_be_backfilled_after_mitigation(self) -> None:
        pristine = function_body("Strategy_SetupStillPristine")
        self.assertIn("for(int shift = setup.bos_shift - 1; shift >= 1;", pristine)
        self.assertIn("low <= entry", pristine)
        self.assertIn("high >= entry", pristine)
        build = function_body("Strategy_BuildRetestOrder")
        self.assertIn("Strategy_SetupStillPristine(setup, entry)", build)

    def test_restart_reconstruction_is_history_fail_closed_and_idempotent(self) -> None:
        used = function_body("Strategy_SetupPreviouslyUsed")
        entry = function_body("Strategy_EntrySignal")
        self.assertIn("HistorySelect(history_from, now)", used)
        self.assertIn("HistoryOrdersTotal()", used)
        self.assertIn("HistoryDealsTotal()", used)
        self.assertIn("ORDER_COMMENT", used)
        self.assertIn("DEAL_COMMENT", used)
        self.assertIn("!history_ready || already_used", entry)
        self.assertIn("Strategy_HasOurPosition()", entry)
        self.assertIn("Strategy_HasOurWorkingOrder()", entry)
        self.assertNotIn("g_consumed_", SOURCE)
        self.assertNotIn("g_long_sweep", SOURCE)
        self.assertNotIn("g_short_sweep", SOURCE)

    def test_spread_filter_is_enabled_and_rechecked_at_entry(self) -> None:
        no_trade = function_body("Strategy_NoTradeFilter")
        entry = function_body("Strategy_EntrySignal")
        spread = function_body("Strategy_SpreadAllowed")
        self.assertIn("strategy_max_spread_atr_fraction = 0.20;", SOURCE)
        self.assertIn("QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1)", spread)
        self.assertIn("atr * strategy_max_spread_atr_fraction", spread)
        self.assertNotIn("strategy_max_spread_points", SOURCE)
        self.assertIn("review_028ddeae-f90a-4b8f-a766-0eede693b995.json", SPEC)
        self.assertIn("not symbol/outcome calibrated", SPEC)
        self.assertIn("Strategy_SpreadAllowed()", no_trade)
        self.assertIn("!Strategy_SpreadAllowed()", entry)

    def test_order_prices_are_tick_normalized_with_card_exits_preserved(self) -> None:
        build = function_body("Strategy_BuildRetestOrder")
        self.assertIn("Strategy_NormalizeNearestTick", build)
        self.assertIn("Strategy_NormalizeDownTick", build)
        self.assertIn("Strategy_NormalizeUpTick", build)
        self.assertIn("risk * strategy_rr_target", build)
        self.assertIn("MathMin(rr_tp, setup.opposing_liquidity)", build)
        self.assertIn("MathMax(rr_tp, setup.opposing_liquidity)", build)
        self.assertIn("remaining_bars * PeriodSeconds(PERIOD_H1)", build)

    def test_opposite_bos_exit_is_closed_h1_bar_only(self) -> None:
        exit_signal = function_body("Strategy_ExitSignal")
        on_tick = function_body("OnTick")
        self.assertIn("const double close1 = BarClose(1);", exit_signal)
        self.assertNotIn("SYMBOL_BID", exit_signal)
        self.assertNotIn("SYMBOL_ASK", exit_signal)
        self.assertLess(on_tick.index("if(!QM_IsNewBar())"), on_tick.index("Strategy_ExitSignal()"))
        self.assertLess(on_tick.index("Strategy_ExitSignal()"), on_tick.index("Strategy_NewsFilterHook"))
        self.assertLess(on_tick.index("QM_FrameworkHandleFridayClose()"), on_tick.index("if(!QM_IsNewBar())"))
        self.assertIn("strategy_time_exit_bars", exit_signal)
        held_bars = function_body("Strategy_TryClosedH1BarsSince")
        self.assertIn("iBarShift(_Symbol, PERIOD_H1, opened_at, false)", held_bars)
        self.assertGreaterEqual(held_bars.count("CopyRates(_Symbol, PERIOD_H1"), 3)
        self.assertIn("CopyRates(_Symbol, PERIOD_H1, 1, verify_count", held_bars)
        self.assertIn("closed_bars = open_shift", held_bars)
        self.assertIn("Strategy_TryClosedH1BarsSince(opened_at, closed_bars)", exit_signal)
        self.assertIn("closed_bars >= max_hold_bars", exit_signal)
        self.assertNotIn("now - opened_at", exit_signal)
        self.assertNotIn("max_hold_seconds", exit_signal)


if __name__ == "__main__":
    unittest.main()
