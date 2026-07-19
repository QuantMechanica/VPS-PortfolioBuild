"""Static contract checks for the isolated QM5_20009 research build.

These tests deliberately do not invoke a shared MT5 terminal.  They protect the
frozen mechanics that are easiest to regress during later compile remediation.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EA = (ROOT / "QM5_20009_ict-liquidity-portfolio.mq5").read_text(encoding="utf-8")
RULES = (ROOT / "ICT_LiquidityRules.mqh").read_text(encoding="utf-8")


def function_body(source: str, name: str) -> str:
    """Return a brace-balanced MQL function body for ordering assertions."""

    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", source, re.S)
    if not match:
        raise AssertionError(f"function not found: {name}")
    start = match.end() - 1
    depth = 0
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1 : index]
    raise AssertionError(f"unbalanced function: {name}")


class FrozenContractTests(unittest.TestCase):
    def test_only_closed_bars_feed_decisions(self) -> None:
        self.assertRegex(EA, r"CopyRates\([^;]+,\s*1\s*,\s*requested\s*,\s*rates\)")
        self.assertRegex(EA, r"iTime\([^;]+,\s*1\)")
        self.assertNotIn("TimeGMT(", EA + RULES)
        self.assertNotRegex(EA, r"CopyRates\([^;]+,\s*0\s*,")
        self.assertNotRegex(EA + RULES, r"\bi(?:Open|High|Low|Close)\([^;]+,\s*0\s*\)")

    def test_management_precedes_every_entry_filter(self) -> None:
        body = function_body(EA, "OnTick")
        management = body.index("Strategy_ManageExposure();")
        friday = body.index("QM_FrameworkHandleFridayClose()")
        kill_switch = body.index("QM_KillSwitchCheck()")
        history = body.index("Strategy_HistoryBudgetClear")
        news = body.index("Strategy_EntryNewsAllows")
        governor = body.index("Strategy_GovernorAllowsEntry")
        entry = body.index("QM_TM_OpenPosition")
        self.assertLess(management, friday)
        self.assertLess(friday, kill_switch)
        self.assertLess(kill_switch, history)
        self.assertLess(history, news)
        self.assertLess(news, governor)
        self.assertLess(governor, entry)

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
        self.assertIn("result.consumed = true; // the first chronological eligible reclaim owns budget.", RULES)
        self.assertIn("signal.fvg_bar_time != closed_bar", EA)
        self.assertIn("Strategy_HistoryBudgetClear(signal.budget_key)", EA)
        self.assertIn("Strategy_HasPositionOrPending()", EA)
        self.assertIn("ICT_RECONSTRUCTED_STATE", EA)

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


if __name__ == "__main__":
    unittest.main()
