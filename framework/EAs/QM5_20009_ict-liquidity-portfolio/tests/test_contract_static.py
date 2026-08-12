"""Static contract checks for the isolated QM5_20009 research build.

These tests deliberately do not invoke a shared MT5 terminal. They protect source
structure that is easy to regress, but do not replace an isolated MT5 compile or
synthetic behavioral fixtures.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EA = (ROOT / "QM5_20009_ict-liquidity-portfolio.mq5").read_text(encoding="utf-8")
RULES = (ROOT / "ICT_LiquidityRules.mqh").read_text(encoding="utf-8")
CONTRACT = (ROOT / "docs" / "strategy_contract.md").read_text(encoding="utf-8")
FRAMEWORK_ROOT = ROOT.parents[1]
TRADE_CONTEXT = (FRAMEWORK_ROOT / "include" / "QM" / "QM_TradeContext.mqh").read_text(
    encoding="utf-8"
)
ENTRY = (FRAMEWORK_ROOT / "include" / "QM" / "QM_Entry.mqh").read_text(
    encoding="utf-8"
)
TRADE_MANAGEMENT = (
    FRAMEWORK_ROOT / "include" / "QM" / "QM_TradeManagement.mqh"
).read_text(encoding="utf-8")
RISK_SIZER = (FRAMEWORK_ROOT / "include" / "QM" / "QM_RiskSizer.mqh").read_text(
    encoding="utf-8"
)


def function_body(source: str, name: str) -> str:
    """Return an MQL body while ignoring braces in strings and comments."""

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


class FrozenContractTests(unittest.TestCase):
    def test_only_closed_bars_feed_decisions(self) -> None:
        self.assertRegex(EA, r"CopyRates\([^;]+,\s*1\s*,\s*requested\s*,\s*rates\)")
        self.assertRegex(EA, r"iTime\([^;]+,\s*1\)")
        self.assertNotIn("TimeGMT(", EA + RULES)
        self.assertNotRegex(EA, r"CopyRates\([^;]+,\s*0\s*,")
        self.assertNotRegex(EA + RULES, r"\bi(?:Open|High|Low|Close)\([^;]+,\s*0\s*\)")

    def test_incremental_replay_avoids_full_copy_on_each_bar(self) -> None:
        load = function_body(EA, "Strategy_LoadClosedRates")
        append = function_body(EA, "Strategy_AppendAndAdvanceCache")
        cached = function_body(EA, "Strategy_ReconstructCached")
        tick = function_body(EA, "OnTick")
        self.assertRegex(load, r"CopyRates\([^;]+,\s*1\s*,\s*requested\s*,\s*rates\)")
        self.assertRegex(append, r"CopyRates\([^;]+,\s*1\s*,\s*missing\s*,\s*delta\)")
        self.assertIn("Strategy_ReconstructCached(closed_bar, signal)", tick)
        self.assertNotIn("Strategy_Reconstruct(signal)", tick)
        self.assertIn("return Strategy_Reconstruct(result); // one full replay", cached)
        self.assertIn("g_strategy_replay_cache_ready = false", cached)
        self.assertIn("closed_bar >= g_strategy_replay_retry_not_before", cached)
        self.assertIn("bounded closed-bar backoff recovery", cached)
        schedule = function_body(EA, "Strategy_ScheduleReplayRetry")
        self.assertIn("g_strategy_replay_failure_count + 1", schedule)
        self.assertIn("retry_bars *= 2", schedule)
        self.assertIn("? 60 : 12", schedule)
        for bound in (
            "bounded_history_first",
            "bounded_event_first",
            "bounded_event_last",
        ):
            self.assertIn(bound, function_body(RULES, "ICT_BuildSequence"))

    def test_full_and_incremental_paths_share_the_frozen_sequence_engine(self) -> None:
        full_index = function_body(EA, "Strategy_ReconstructIndex")
        full_fx = function_body(EA, "Strategy_ReconstructFx")
        cached_index = function_body(EA, "Strategy_UpdateIndexCache")
        cached_fx = function_body(EA, "Strategy_RebuildFxSession")
        logical_window = function_body(EA, "Strategy_LogicalHistoryFirstIndex")
        sequence = function_body(RULES, "ICT_BuildSequence")

        self.assertEqual(full_index.count("ICT_BuildSequence("), 1)
        self.assertEqual(full_fx.count("ICT_BuildSequence("), 1)
        self.assertEqual(cached_index.count("ICT_BuildSequence("), 1)
        self.assertEqual(cached_fx.count("ICT_BuildSequence("), 1)
        self.assertIn("count - Strategy_ReplayRequestedBars()", logical_window)
        self.assertIn("Strategy_LogicalHistoryFirstIndex()", cached_index)
        self.assertIn("Strategy_LogicalHistoryFirstIndex()", cached_fx)
        self.assertIn("bounded_history_first", sequence)
        self.assertIn("bounded_event_first", sequence)
        self.assertIn("bounded_event_last", sequence)
        self.assertIn("ICT_LatestPrePenetrationPivot", sequence)
        self.assertIn("ICT_SMA_TR14At", sequence)

    def test_management_precedes_every_entry_filter(self) -> None:
        safety = function_body(EA, "Strategy_RunMandatorySafety")
        kill_switch = safety.index("QM_KillSwitchCheck()")
        friday = safety.index("QM_FrameworkHandleFridayClose()")
        management = safety.index("Strategy_ManageExposure();")
        self.assertLess(kill_switch, friday)
        self.assertLess(friday, management)

        tick = function_body(EA, "OnTick")
        safety_call = tick.index("Strategy_RunMandatorySafety()")
        virtual = tick.index("Strategy_ProcessVirtualLimit(true)")
        new_bar = tick.index("QM_IsNewBar")
        history = tick.index("Strategy_HistoryBudgetClear")
        news = tick.index("Strategy_EntryNewsAllows")
        governor = tick.index("Strategy_GovernorAllowsEntry")
        arm = tick.index("Strategy_ArmVirtualLimit")
        self.assertLess(safety_call, virtual)
        self.assertLess(virtual, new_bar)
        self.assertLess(new_bar, history)
        self.assertLess(history, news)
        self.assertLess(news, governor)
        self.assertLess(governor, arm)

        process = function_body(EA, "Strategy_ProcessVirtualLimit")
        gate = process.index("Strategy_VirtualLimitGateAllows")
        touched = process.index("Strategy_VirtualLimitTouched")
        consume = process.index('Strategy_DisarmVirtualLimit("touch_consumed_before_send")')
        entry = process.index("QM_TM_OpenPosition")
        self.assertLess(gate, touched)
        self.assertLess(touched, consume)
        self.assertLess(consume, entry)

    def test_mandatory_safety_retries_on_init_tick_and_timer(self) -> None:
        init = function_body(EA, "OnInit")
        tick = function_body(EA, "OnTick")
        timer = function_body(EA, "OnTimer")
        self.assertIn("Strategy_RunMandatorySafety();", init)
        self.assertIn("Strategy_RunMandatorySafety()", tick)
        self.assertLess(
            timer.index("Strategy_RunMandatorySafety();"),
            timer.index("QM_FrameworkOnTimer();"),
        )

    def test_locked_symbol_magic_and_timeframes(self) -> None:
        required = (
            '"NDX.DWX" && qm_magic_slot_offset == 0',
            '"GDAXI.DWX" && qm_magic_slot_offset == 1',
            '"GBPUSD.DWX" && qm_magic_slot_offset == 2',
            '"EURUSD.DWX" && qm_magic_slot_offset == 5',
            "return 200090005;",
            "QM_FrameworkDeclareExecutionContract(\n         PERIOD_M1,",
            "QM_FrameworkDeclareExecutionContract(\n         PERIOD_M5,",
        )
        for token in required:
            self.assertIn(token, EA)

    def test_replay_depth_and_group_labels_are_frozen_and_report_safe(self) -> None:
        parameters = function_body(EA, "Strategy_ParametersValid")
        self.assertIn("strategy_replay_bars_index != 2500", parameters)
        self.assertIn("strategy_replay_bars_fx != 10000", parameters)
        group_labels = re.findall(r'input group "([^"]+)"', EA)
        self.assertTrue(group_labels)
        for label in group_labels:
            self.assertIsNone(
                re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", label),
                f"MT5 report parser would confuse input group with input: {label}",
            )

    def test_live_path_is_exact_governor_percent_risk_only(self) -> None:
        required = (
            "QM_FTMO_SelectPolicy",
            "QM_FTMO_IsExactPolicy",
            "QM_FTMO_IdentifierValid",
            "strategy_governor_heartbeat_max_age_seconds != 5",
            "RISK_FIXED != 0.0",
            "RISK_PERCENT <= 0.0",
            'ACCOUNT_CURRENCY) != "USD"',
            "ACCOUNT_MARGIN_MODE_RETAIL_HEDGING",
            "QM_FTMO_ReadGovernorScale",
            "QM_RISK_MODE_PERCENT",
            'strategy_governor_policy_id == "FTMO_2S_P1_100K_V2"',
            'strategy_governor_policy_id == "FTMO_2S_P2_100K_V2"',
            'strategy_governor_policy_id == "FTMO_2S_FUNDED_100K_V2"',
        )
        for token in required:
            self.assertIn(token, EA)

    def test_entry_news_profile_is_frozen_to_real_ftmo_rules(self) -> None:
        self.assertIn(
            "input QM_NewsComplianceProfile qm_news_compliance = "
            "QM_NEWS_COMPLIANCE_FTMO;",
            EA,
        )
        validation = function_body(EA, "Strategy_ParametersValid")
        required = (
            "qm_news_temporal != QM_NEWS_TEMPORAL_PRE30_POST30",
            "qm_news_compliance != QM_NEWS_COMPLIANCE_FTMO",
            "qm_news_stale_max_hours != 336",
            'qm_news_min_impact != "high"',
            "qm_news_mode_legacy != QM_NEWS_OFF",
        )
        for token in required:
            self.assertIn(token, validation)
        news_gate = function_body(EA, "Strategy_EntryNewsAllows")
        self.assertIn("QM_NewsAllowsTrade2Fresh", news_gate)
        self.assertNotIn("QM_NewsAllowsTrade2(_Symbol", news_gate)
        self.assertRegex(CONTRACT, r"compliance\s+`FTMO`")
        self.assertIn("placeholder `DXZ`", CONTRACT)

    def test_frozen_windows_and_complete_reference_counts(self) -> None:
        required = (
            "9 * 60 + 30,\n                          10 * 60,\n                          30,",
            "10 * 60,\n                     11 * 60,",
            "20 * 60,\n                          24 * 60,\n                          48,",
            "ICT_SESSION_LONDON,\n                     2 * 60,\n                     5 * 60,",
        )
        for token in required:
            self.assertIn(token, EA)
        self.assertIn("range.bars == expected_bars", RULES)

    def test_fx_budget_is_daily_london_asia_only(self) -> None:
        budget = function_body(EA, "Strategy_BudgetKeyAtTime")
        full_fx = function_body(EA, "Strategy_ReconstructFx")
        session = function_body(EA, "Strategy_EventSessionForBar")
        self.assertIn("return ICT_NYDateKey(event_time);", budget)
        self.assertIn("ICT_MODE_FX_SESSION_SWEEP", EA + RULES)
        self.assertNotIn("ICT_MODE_FX_WEEKLY_SWEEP", EA + RULES)
        self.assertNotIn("ICT_TradingWeekKey", EA + RULES)
        self.assertIn("asian_range.low", full_fx)
        self.assertIn("asian_range.high", full_fx)
        self.assertEqual(full_fx.count("ICT_SESSION_LONDON"), 1)
        self.assertNotIn("ICT_SESSION_NEW_YORK", session)

    def test_preregistered_star_is_oaat_and_live_is_center_only(self) -> None:
        self.assertIn("a_deviations > 1 || b_deviations != 0", EA)
        self.assertIn("b_deviations > 1 || a_deviations != 0", EA)
        self.assertIn("else if(a_deviations != 0 || b_deviations != 0)", EA)

    def test_sequence_is_strictly_ordered_and_first_fvg_only(self) -> None:
        body = function_body(RULES, "ICT_BuildSequence")
        reclaim = body.index("result.reclaim_bar_time")
        pivot = body.index("ICT_LatestPrePenetrationPivot")
        mss = body.index("for(int i = best_reclaim + 1")
        fvg = body.index("for(int i = mss_index + 1")
        ready = body.index('result.outcome = "EARLIEST_FVG_READY"')
        self.assertLess(reclaim, pivot)
        self.assertLess(pivot, mss)
        self.assertLess(mss, fvg)
        self.assertLess(fvg, ready)
        self.assertIn("break;", body[fvg:ready])
        self.assertIn("penetration_index - wing - 1", RULES)
        self.assertIn("close_minute < end_minute", RULES)

    def test_consumed_budget_and_restart_freshness_are_both_enforced(self) -> None:
        self.assertIn(
            "result.consumed = true; // the first chronological eligible reclaim owns budget.",
            RULES,
        )
        self.assertIn("signal.fvg_bar_time != closed_bar", EA)
        self.assertIn("Strategy_HistoryBudgetClear(signal)", EA)
        self.assertIn("Strategy_HasPositionOrPending()", EA)
        self.assertIn("ICT_RECONSTRUCTED_STATE", EA)

        bind = function_body(EA, "Strategy_BindConsumedAttempt")
        claim = function_body(EA, "Strategy_ClaimAttempt")
        history = function_body(EA, "Strategy_HistoryBudgetClear")
        init = function_body(EA, "OnInit")
        tick = function_body(EA, "OnTick")
        self.assertIn("ICT_ATTEMPT_CONSUMED", bind)
        self.assertIn("signal.event_bar_time", bind)
        self.assertIn("signal.frozen_level_hash", bind)
        self.assertIn("signal.reference_hash", bind)
        self.assertIn("ICT_ATTEMPT_SUBMITTED", claim)
        self.assertIn("GlobalVariableSetOnCondition", claim)
        self.assertIn("HistoryOrdersTotal()", history)
        self.assertIn("ORDER_TIME_SETUP", history)
        self.assertIn("ORDER_COMMENT", history)
        self.assertIn("if(reconstructed.consumed)", init)
        self.assertIn("Strategy_VoidPersistedVirtualIntentOnInit", init)
        self.assertIn("Strategy_BindConsumedAttempt(reconstructed)", init)
        self.assertIn("signal.consumed && !Strategy_BindConsumedAttempt(signal)", tick)
        arm = function_body(EA, "Strategy_ArmVirtualLimit")
        self.assertLess(
            arm.index("Strategy_ClaimAttempt(signal, request, deadline)"),
            arm.index("g_strategy_virtual_limit_active = true"),
        )
        process = function_body(EA, "Strategy_ProcessVirtualLimit")
        self.assertLess(
            process.index('Strategy_DisarmVirtualLimit("touch_consumed_before_send")'),
            process.index("QM_TM_OpenPosition"),
        )

    def test_tester_attempt_state_never_uses_terminal_global_variables(self) -> None:
        bind = function_body(EA, "Strategy_BindConsumedAttempt")
        claim = function_body(EA, "Strategy_ClaimAttempt")
        tester_bind = bind[bind.index("MQLInfoInteger(MQL_TESTER)") : bind.index("bool exists")]
        tester_claim = claim[
            claim.index("MQLInfoInteger(MQL_TESTER)") : claim.index("bool exists")
        ]
        self.assertIn("g_tester_attempt_event_time", tester_bind)
        self.assertNotIn("GlobalVariable", tester_bind)
        self.assertNotIn("GlobalVariable", tester_claim)
        self.assertIn("process-local", CONTRACT)

    def test_no_disallowed_position_management(self) -> None:
        disallowed_calls = (
            "QM_TM_PartialClose(",
            "QM_TM_MoveToBreakEven(",
            "QM_TM_MoveSL(",
            "QM_TM_MoveTP(",
        )
        for call in disallowed_calls:
            self.assertNotIn(call, EA)
        self.assertIn("15 * 60 + 55", EA)
        self.assertIn("16 * 60", EA)
        self.assertIn("ict_server_pending_forbidden", EA)
        self.assertIn("Strategy_DisarmVirtualLimit", EA)

    def test_stop_and_fixed_target_contract(self) -> None:
        self.assertIn("MathMax(2.0 * observed_spread", RULES)
        self.assertIn("sl_buffer_atr * fvg_atr", RULES)
        self.assertIn("reward / risk + 1e-12 < min_rr", RULES)
        self.assertIn("opening_range.high,\n                     opening_range.low,", EA)
        self.assertIn("asian_range.high,\n                     asian_range.low,", EA)
        self.assertIn("reference.high,\n                     reference.low,", EA)

    def test_volatility_definition_and_fvg_threshold_are_explicit(self) -> None:
        atr = function_body(RULES, "ICT_SMA_TR14At")
        self.assertIn("atr /= 14.0", atr)
        self.assertIn("not Wilder-smoothed ATR", RULES)
        self.assertIn("SMA-TR(14)", CONTRACT)
        self.assertNotIn("ICT_ATR14At", RULES)
        self.assertNotIn("tick_size * 0.25", RULES)
        self.assertIn("gap + comparison_epsilon < minimum_gap", RULES)

    def test_virtual_limit_prices_are_aligned_to_trade_tick_grid(self) -> None:
        self.assertIn("SYMBOL_TRADE_TICK_SIZE", EA)
        self.assertIn("Strategy_NormalizeToTick(signal.entry, 0)", EA)
        self.assertIn("(signal.direction > 0) ? -1 : 1", EA)
        self.assertIn("Strategy_QuoteAllowsFreshVirtualLimit(signal.direction", EA)
        build = function_body(EA, "Strategy_BuildEntryRequest")
        self.assertLess(build.index("Strategy_NormalizeToTick"), build.index("const double risk"))
        self.assertLess(
            build.index("Strategy_QuoteAllowsFreshVirtualLimit"),
            build.index("const double risk"),
        )

    def test_virtual_arm_uses_atomic_quote_but_no_server_pending_distances(self) -> None:
        quote = function_body(EA, "Strategy_QuoteAllowsFreshVirtualLimit")
        self.assertIn("SymbolInfoTick(_Symbol, quote)", quote)
        self.assertNotIn("SYMBOL_ASK", quote)
        self.assertNotIn("SYMBOL_BID", quote)
        self.assertNotIn("SYMBOL_TRADE_STOPS_LEVEL", quote)
        self.assertNotIn("minimum_distance", quote)
        required = (
            "ask <= entry",
            "bid >= entry",
            "stop >= entry || target <= entry",
            "stop <= entry || target >= entry",
            'failure_reason = "edge_already_touched_at_eligibility"',
            'failure_reason = "directional_geometry_invalid_at_eligibility"',
        )
        for token in required:
            self.assertIn(token, quote)

    def test_virtual_limit_has_no_unattended_server_pending(self) -> None:
        build = function_body(EA, "Strategy_BuildEntryRequest")
        trigger = function_body(EA, "Strategy_BuildTriggeredMarketRequest")
        process = function_body(EA, "Strategy_ProcessVirtualLimit")
        manage = function_body(EA, "Strategy_ManageExposure")
        timer = function_body(EA, "OnTimer")
        self.assertNotIn("Strategy_AssignPendingExpiration", EA)
        self.assertIn("virtual intent; never sent as a pending", build)
        self.assertIn("? QM_BUY : QM_SELL", trigger)
        self.assertIn("market_request.price = 0.0", trigger)
        self.assertIn("QM_TM_OpenPosition(market_request", process)
        self.assertEqual(process.count("QM_TRADE_SEND_ONCE"), 2)
        self.assertNotIn("OrderSend", process)
        self.assertNotIn("QM_TradeContextSend", process)
        self.assertNotIn("QM_TM_OpenPosition(request", function_body(EA, "OnTick"))
        self.assertIn("ict_server_pending_forbidden", manage)
        self.assertIn("Strategy_ProcessVirtualLimit(false);", timer)
        self.assertIn("Strategy_RunMandatorySafety();", timer)

    def test_virtual_limit_touch_and_restart_are_fail_closed(self) -> None:
        touched = function_body(EA, "Strategy_VirtualLimitTouched")
        restart = function_body(EA, "Strategy_VoidPersistedVirtualIntentOnInit")
        claim = function_body(EA, "Strategy_ClaimAttempt")
        self.assertIn("quote.ask <= g_strategy_virtual_limit_request.price", touched)
        self.assertIn("quote.bid >= g_strategy_virtual_limit_request.price", touched)
        self.assertIn("ICT_VIRTUAL_LIMIT_RESTART_VOID", restart)
        self.assertIn("Strategy_DeleteVirtualIntentFields(signal)", restart)
        self.assertIn("Strategy_PersistVirtualIntentFields", claim)
        self.assertLess(
            claim.index("Strategy_PersistVirtualIntentFields"),
            claim.index("GlobalVariableSetOnCondition"),
        )

        deadline = function_body(EA, "Strategy_ComputeVirtualLimitDeadline")
        self.assertIn("QM_NewsNextBlockStart", deadline)
        self.assertIn("QM_NEWS_BLOCKSTART_DATA_ERROR", deadline)
        self.assertIn("next_news_block < deadline", deadline)
        self.assertIn("next_news_block <= broker_now", deadline)

        gate = function_body(EA, "Strategy_VirtualLimitGateAllows")
        self.assertIn("g_strategy_virtual_limit_last_gate_time", gate)
        self.assertIn("strategy_governor_heartbeat_max_age_seconds", gate)
        self.assertIn('block_reason = "gate_continuity_gap"', gate)
        self.assertLess(
            gate.index('block_reason = "gate_continuity_gap"'),
            gate.index("Strategy_EntryNewsAllows"),
        )
        self.assertGreater(
            gate.index("g_strategy_virtual_limit_last_gate_time = broker_now"),
            gate.index("Strategy_GovernorAllowsEntry"),
        )

    def test_trigger_revalidates_current_quote_rr_and_broker_distance(self) -> None:
        trigger = function_body(EA, "Strategy_BuildTriggeredMarketRequest")
        self.assertIn("SYMBOL_TRADE_STOPS_LEVEL", trigger)
        self.assertIn("? quote.ask : quote.bid", trigger)
        self.assertIn("? quote.bid : quote.ask", trigger)
        self.assertIn("stop_distance = broker_reference_price - stop", trigger)
        self.assertIn("target_distance = target - broker_reference_price", trigger)
        self.assertIn("stop_distance = stop - broker_reference_price", trigger)
        self.assertIn("target_distance = broker_reference_price - target", trigger)
        self.assertIn("stop_distance + comparison_epsilon < minimum_distance", trigger)
        self.assertIn("target_distance + comparison_epsilon < minimum_distance", trigger)
        self.assertIn("reward / risk + 1e-12 < min_rr", trigger)
        self.assertIn("trigger_beyond_stop_or_target", trigger)
        self.assertIn("trigger_broker_stop_distance", trigger)

    def test_suppressed_eligible_events_have_granular_terminal_reasons(self) -> None:
        build = function_body(EA, "Strategy_BuildEntryRequest")
        tick = function_body(EA, "OnTick")
        rebuild = function_body(EA, "Strategy_RebuildFxSession")
        update = function_body(EA, "Strategy_UpdateFxCache")
        self.assertIn("failure_reason", build)
        self.assertIn("news_blackout_at_eligibility", tick)
        self.assertIn("governor_block_at_eligibility", tick)
        for reason in (
            "ASIAN_REFERENCE_INCOMPLETE",
            "SESSION_WINDOW_INCOMPLETE",
        ):
            self.assertIn(reason, rebuild)
        self.assertIn("ICT_FX_SESSION_INCOMPLETE", update)


if __name__ == "__main__":
    unittest.main()
