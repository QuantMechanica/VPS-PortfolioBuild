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
        for bound in (
            "bounded_history_first",
            "bounded_event_first",
            "bounded_event_last",
        ):
            self.assertIn(bound, function_body(RULES, "ICT_BuildSequence"))

    def test_management_precedes_every_entry_filter(self) -> None:
        safety = function_body(EA, "Strategy_RunMandatorySafety")
        kill_switch = safety.index("QM_KillSwitchCheck()")
        friday = safety.index("QM_FrameworkHandleFridayClose()")
        management = safety.index("Strategy_ManageExposure();")
        self.assertLess(kill_switch, friday)
        self.assertLess(friday, management)

        tick = function_body(EA, "OnTick")
        safety_call = tick.index("Strategy_RunMandatorySafety()")
        history = tick.index("Strategy_HistoryBudgetClear")
        news = tick.index("Strategy_EntryNewsAllows")
        governor = tick.index("Strategy_GovernorAllowsEntry")
        claim = tick.index("Strategy_ClaimAttempt(signal)")
        entry = tick.index("QM_TM_OpenPosition")
        self.assertLess(safety_call, history)
        self.assertLess(history, news)
        self.assertLess(news, governor)
        self.assertLess(governor, claim)
        self.assertLess(claim, entry)

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
        self.assertRegex(CONTRACT, r"compliance\s+`FTMO`")
        self.assertIn("placeholder `DXZ`", CONTRACT)

    def test_frozen_windows_and_complete_reference_counts(self) -> None:
        required = (
            "9 * 60 + 30,\n                          10 * 60,\n                          30,",
            "10 * 60,\n                     11 * 60,",
            "20 * 60,\n                            24 * 60,\n                            48,",
            "2 * 60,\n                            5 * 60,\n                            36,",
            "ICT_SESSION_LONDON,\n                           2 * 60,\n                           5 * 60,",
            "ICT_SESSION_NEW_YORK,\n                           7 * 60,\n                           10 * 60,",
        )
        for token in required:
            self.assertIn(token, EA)
        self.assertIn("range.bars == expected_bars", RULES)
        self.assertIn("distinct_dates >= 3", RULES)

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
        self.assertIn("Strategy_BindConsumedAttempt(reconstructed)", init)
        self.assertIn("signal.consumed && !Strategy_BindConsumedAttempt(signal)", tick)
        self.assertLess(
            tick.index("Strategy_ClaimAttempt(signal)"),
            tick.index("QM_TM_OpenPosition"),
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
        self.assertIn("ict_session_pending_cancel", EA)

    def test_stop_and_fixed_target_contract(self) -> None:
        self.assertIn("MathMax(2.0 * observed_spread", RULES)
        self.assertIn("sl_buffer_atr * fvg_atr", RULES)
        self.assertIn("reward / risk + 1e-12 < min_rr", RULES)
        self.assertIn("opening_range.high,\n                     opening_range.low,", EA)
        self.assertIn("asian.high,\n                           asian.low,", EA)
        self.assertIn("london_reference.high,\n                           london_reference.low,", EA)

    def test_volatility_definition_and_fvg_threshold_are_explicit(self) -> None:
        atr = function_body(RULES, "ICT_SMA_TR14At")
        self.assertIn("atr /= 14.0", atr)
        self.assertIn("not Wilder-smoothed ATR", RULES)
        self.assertIn("SMA-TR(14)", CONTRACT)
        self.assertNotIn("ICT_ATR14At", RULES)
        self.assertNotIn("tick_size * 0.25", RULES)
        self.assertIn("gap + comparison_epsilon < minimum_gap", RULES)

    def test_pending_prices_are_aligned_to_trade_tick_grid(self) -> None:
        self.assertIn("SYMBOL_TRADE_TICK_SIZE", EA)
        self.assertIn("Strategy_NormalizeToTick(signal.entry, 0)", EA)
        self.assertIn("(signal.direction > 0) ? -1 : 1", EA)
        self.assertIn(
            "Strategy_QuoteAllowsFreshLimit(signal.direction,\n"
            "                                      request.price,",
            EA,
        )
        build = function_body(EA, "Strategy_BuildEntryRequest")
        self.assertLess(build.index("Strategy_NormalizeToTick"), build.index("const double risk"))
        self.assertLess(build.index("Strategy_QuoteAllowsFreshLimit"), build.index("const double risk"))

    def test_pending_geometry_uses_one_atomic_quote_and_all_broker_distances(self) -> None:
        quote = function_body(EA, "Strategy_QuoteAllowsFreshLimit")
        self.assertIn("SymbolInfoTick(_Symbol, quote)", quote)
        self.assertNotIn("SYMBOL_ASK", quote)
        self.assertNotIn("SYMBOL_BID", quote)
        self.assertIn("SYMBOL_TRADE_STOPS_LEVEL", quote)
        required = (
            "ask - entry + comparison_epsilon < minimum_distance",
            "entry - bid + comparison_epsilon < minimum_distance",
            "entry - stop + comparison_epsilon < minimum_distance",
            "target - entry + comparison_epsilon < minimum_distance",
            "stop - entry + comparison_epsilon < minimum_distance",
            "entry - target + comparison_epsilon < minimum_distance",
        )
        for token in required:
            self.assertIn(token, quote)

    def test_pending_expiration_has_specified_then_gtc_timer_fallback(self) -> None:
        expiration = function_body(EA, "Strategy_AssignPendingExpiration")
        build = function_body(EA, "Strategy_BuildEntryRequest")
        timer = function_body(EA, "OnTimer")
        self.assertIn("SYMBOL_EXPIRATION_MODE", expiration)
        self.assertIn("SYMBOL_EXPIRATION_SPECIFIED", expiration)
        self.assertIn("SYMBOL_EXPIRATION_GTC", expiration)
        self.assertIn("request.expiration_seconds = 0", expiration)
        self.assertIn("Strategy_AssignPendingExpiration", build)
        self.assertIn("Strategy_RunMandatorySafety();", timer)


if __name__ == "__main__":
    unittest.main()
