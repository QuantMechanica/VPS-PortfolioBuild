"""Static causal/lifecycle contracts for QM5_10628.

These checks deliberately do not compile or run MT5. They guard source-level
properties of the repair and complement, rather than replace, an isolated
MetaEditor compile and later tick-data validation.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EA = (ROOT / "QM5_10628_et-fvg-sweep-fill.mq5").read_text(encoding="utf-8")


def function_body(source: str, name: str) -> str:
    """Return an MQL function body while ignoring strings and comments."""

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


class CausalSourceContractTests(unittest.TestCase):
    def test_card_parameters_remain_frozen_and_no_outcome_tuning_exists(self) -> None:
        required_defaults = (
            "strategy_sweep_depth_atr         = 0.20",
            "strategy_sweep_reclaim_bars      = 3",
            "strategy_displacement_window     = 8",
            "strategy_displacement_body_atr   = 1.20",
            "strategy_fvg_min_width_atr       = 0.15",
            "strategy_fvg_max_width_atr       = 1.20",
            "strategy_pending_bars            = 6",
            "strategy_time_exit_bars          = 24",
            "strategy_rr_cap                  = 2.00",
        )
        for token in required_defaults:
            self.assertIn(token, EA)
        for forbidden in (
            "TesterStatistics",
            "STAT_",
            "FileOpen(",
            "FileRead(",
            "WebRequest(",
            'if(_Symbol == "SP500',
        ):
            self.assertNotIn(forbidden, EA)
        self.assertIn("return QM_DefaultObjective();", function_body(EA, "OnTester"))

    def test_fsm_has_strict_non_collapsing_states(self) -> None:
        for state in (
            "STRATEGY_WAIT_LIQUIDITY",
            "STRATEGY_WAIT_RECLAIM",
            "STRATEGY_WAIT_DISPLACEMENT",
            "STRATEGY_FVG_READY",
            "STRATEGY_WAIT_MITIGATION",
            "STRATEGY_POSITION_LIVE",
        ):
            self.assertIn(state, EA)
        process = function_body(EA, "Strategy_ProcessClosedBar")
        self.assertIn("switch(g_phase)", process)
        self.assertIn("Strategy_DetectAndFreezeSweep(bar_shift);\n         return false;", process)
        self.assertIn("Strategy_ProcessReclaim(bar_shift);\n         return false;", process)
        self.assertNotIn("Strategy_DetectAndFreezeFvg", function_body(EA, "Strategy_DetectAndFreezeSweep"))
        self.assertNotIn("Strategy_DetectAndFreezeFvg", function_body(EA, "Strategy_ProcessReclaim"))

    def test_displacement_and_fvg_are_on_strictly_later_closed_bars(self) -> None:
        fvg = function_body(EA, "Strategy_DetectAndFreezeFvg")
        required = (
            "displacement_shift = bar_shift + 1",
            "older_shift = bar_shift + 2",
            "fvg_time <= displacement_time || displacement_time <= g_reclaim_time",
            "Strategy_ClosedBarsBetween(g_reclaim_time",
            "displacement_after_reclaim < 1",
            "displacement_after_reclaim > strategy_displacement_window",
        )
        for token in required:
            self.assertIn(token, fvg)
        process = function_body(EA, "Strategy_ProcessClosedBar")
        self.assertIn("bar_shift != 1 || !entry_allowed", process)

    def test_liquidity_pool_is_event_time_relative_and_then_frozen(self) -> None:
        pool = function_body(EA, "Strategy_BuildFrozenLiquidityPool")
        self.assertIn("iBarShift(_Symbol, frames[f], event_time, false)", pool)
        self.assertIn("first_pivot = event_htf_shift + 2", pool)
        sweep = function_body(EA, "Strategy_DetectAndFreezeSweep")
        for token in ("g_pool_time = event_time", "g_pool_hash = pool_hash", "g_pool_level ="):
            self.assertIn(token, sweep)
        downstream = (
            function_body(EA, "Strategy_ProcessReclaim")
            + function_body(EA, "Strategy_DetectAndFreezeFvg")
        )
        self.assertNotIn("Strategy_BuildFrozenLiquidityPool", downstream)
        self.assertNotIn("PERIOD_H4", downstream)
        self.assertNotIn("PERIOD_D1", downstream)

    def test_limit_is_armed_after_fvg_and_fill_requires_later_mitigation(self) -> None:
        pending = function_body(EA, "Strategy_PreparePendingRequest")
        self.assertIn("SymbolInfoTick(_Symbol, quote)", pending)
        self.assertIn("ask < g_entry_price + tick", pending)
        self.assertIn("bid > g_entry_price - tick", pending)
        self.assertIn("QM_BUY_LIMIT : QM_SELL_LIMIT", pending)
        self.assertIn("req.expiration_seconds = 0", pending)
        self.assertNotIn("QM_BUY : QM_SELL", pending)

    def test_pending_and_position_lifetimes_use_closed_bars_not_seconds(self) -> None:
        pending = function_body(EA, "Strategy_ManagePendingOrder")
        exit_signal = function_body(EA, "Strategy_ExitSignal")
        self.assertIn("Strategy_ClosedBarsBetween(g_fvg_time, newest_closed)", pending)
        self.assertIn("closed_bars >= strategy_pending_bars", pending)
        self.assertIn("QM_TM_RemovePendingOrder", pending)
        self.assertIn("Strategy_ClosedBarsSinceTime(opened)", exit_signal)
        self.assertIn("closed_bars_held >= strategy_time_exit_bars", exit_signal)
        forbidden = (
            "strategy_pending_bars * PeriodSeconds",
            "strategy_time_exit_bars * PeriodSeconds",
            "TimeCurrent() - opened",
        )
        for token in forbidden:
            self.assertNotIn(token, EA)

    def test_geometry_is_tick_grid_normalized_before_validation(self) -> None:
        tick = function_body(EA, "Strategy_TickSize")
        normalize = function_body(EA, "Strategy_ToTick")
        geometry = function_body(EA, "Strategy_FreezeOrderGeometry")
        self.assertIn("SYMBOL_TRADE_TICK_SIZE", tick)
        self.assertIn("SYMBOL_POINT", tick)
        for token in ("MathRound", "MathFloor", "MathCeil", "NormalizeDouble"):
            self.assertIn(token, normalize)
        self.assertIn("Strategy_ToTick(raw_entry, 0)", geometry)
        self.assertIn("Strategy_ToTick(g_sweep_extreme", geometry)
        self.assertIn("Strategy_ToTick(raw_target", geometry)
        self.assertLess(geometry.index("Strategy_ToTick(raw_entry, 0)"), geometry.index("g_stop_price >= g_entry_price"))

    def test_persistence_is_two_phase_and_tester_state_is_process_local(self) -> None:
        persist = function_body(EA, "Strategy_PersistState")
        restore = function_body(EA, "Strategy_RestoreState")
        claim = function_body(EA, "Strategy_ClaimSetup")
        self.assertLess(persist.index("Strategy_IsTester()"), persist.index("Strategy_WriteStateValue"))
        self.assertLess(persist.index('"begin"'), persist.index('"phase"'))
        self.assertLess(
            persist.index("GlobalVariablesFlush();"),
            persist.index('Strategy_WriteStateValue("commit"'),
        )
        self.assertIn("begin_value != commit_value", restore)
        self.assertIn("STRATEGY_STATE_VERSION", restore)
        self.assertLess(claim.index("Strategy_IsTester()"), claim.index("GlobalVariableCheck"))
        for field in (
            '"pool_t"', '"pool_h"', '"pool_l"', '"pen_t"', '"reclaim_t"',
            '"fvg_t"', '"fvg_lo"', '"fvg_hi"', '"entry"', '"sl"', '"tp"',
            '"pending_t"', '"consumed_t"', '"last_bar"',
        ):
            self.assertIn(field, persist)

    def test_setup_is_claimed_before_send_and_restart_never_reuses_it(self) -> None:
        self.assertIn('StringFormat("claim.%I64d.%u", (long)g_fvg_time, g_pool_hash)', EA)
        claim = function_body(EA, "Strategy_ClaimSetup")
        self.assertIn("GlobalVariableSetOnCondition", claim)
        self.assertNotIn("GlobalVariableDel", EA)
        pending = function_body(EA, "Strategy_PreparePendingRequest")
        self.assertIn("Strategy_ClaimSetup()", pending)
        init = function_body(EA, "OnInit")
        self.assertIn("Strategy_RecoverConsumedFromHistory();", init)
        self.assertIn("Strategy_RecoverExposureLifecycle();", init)
        self.assertIn("if(g_phase == STRATEGY_FVG_READY)", init)
        on_tick = function_body(EA, "OnTick")
        self.assertLess(on_tick.index("Strategy_EntrySignal(req)"), on_tick.index("QM_TM_OpenPosition(req"))

    def test_news_only_gates_entry_and_friday_removes_pending_first(self) -> None:
        on_tick = function_body(EA, "OnTick")
        mae = on_tick.index("QM_FrameworkTrackOpenPositionMae();")
        kill = on_tick.index("QM_KillSwitchCheck()")
        friday_pending = on_tick.index("Strategy_HandleFridayPending();")
        friday_framework = on_tick.index("QM_FrameworkHandleFridayClose()")
        management = on_tick.index("Strategy_ManageOpenPosition();")
        exit_signal = on_tick.index("Strategy_ExitSignal()")
        new_bar = on_tick.index("QM_IsNewBar()")
        entry = on_tick.index("Strategy_EntrySignal(req)")
        self.assertLess(mae, kill)
        self.assertLess(kill, friday_pending)
        self.assertLess(friday_pending, friday_framework)
        self.assertLess(friday_framework, management)
        self.assertLess(management, exit_signal)
        self.assertLess(exit_signal, new_bar)
        self.assertLess(new_bar, entry)
        self.assertNotIn("QM_NewsAllowsTrade", on_tick)
        self.assertIn("Strategy_EntryNewsAllows(TimeCurrent())", function_body(EA, "Strategy_EntrySignal"))
        friday = function_body(EA, "Strategy_HandleFridayPending")
        self.assertIn("QM_FrameworkFridayCloseNow()", friday)
        self.assertIn("Strategy_FindOwnPending", friday)
        self.assertIn("QM_TM_RemovePendingOrder", friday)


if __name__ == "__main__":
    unittest.main()
