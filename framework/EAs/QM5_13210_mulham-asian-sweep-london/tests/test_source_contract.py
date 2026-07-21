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
        self.assertIn("strategy_atr_period <= 100", inputs)
        self.assertIn("strategy_fixed_rr <= 10.0", inputs)
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
        self.assertIn("g_post_sweep_high", target)
        self.assertIn("g_post_sweep_low", target)
        self.assertIn("observed_high >= target", target)
        self.assertIn("observed_low <= target", target)

    def test_pending_order_deadline_and_live_cancellation_fail_closed(self) -> None:
        deadline = function_body(EA, "QM13210_ComputeEntryDeadline")
        manage = function_body(EA, "Strategy_ManageOpenPosition")
        target = function_body(EA, "QM13210_TargetAlreadyTouched")
        self.assertIn("QM_NewsNextBlockStart", deadline)
        self.assertIn("QM_NEWS_BLOCKSTART_DATA_ERROR", deadline)
        self.assertIn("next_news_block < out_deadline", deadline)
        self.assertNotIn("g_entry_ready && g_entry_tp", target)
        self.assertIn("g_sweep_direction == 0", manage)
        self.assertIn("asian_sweep_state_missing_cancel", manage)
        self.assertIn("bid >= g_entry_tp", manage)
        self.assertIn("bid <= g_entry_tp", manage)
        self.assertIn("bid > g_sweep_high_ref", manage)
        self.assertIn("bid < g_sweep_low_ref", manage)
        self.assertIn("asian_sweep_stale_target_cancel", manage)
        self.assertIn("QM13210_NewsAllowsEntryNow(broker_now)", manage)
        self.assertIn("asian_sweep_news_cancel", manage)

    def test_source_usd_ny_news_day_veto_is_exact_and_fail_closed(self) -> None:
        window = function_body(EA, "QM13210_USDNYBrokerWindow")
        tester = function_body(EA, "QM13210_USDNYNewsDayTester")
        live = function_body(EA, "QM13210_USDNYNewsDayLive")
        status = function_body(EA, "QM13210_USDNYNewsDayStatus")

        self.assertIn("QM13210_USD_NY_DAY_DATA_ERROR = -1", EA)
        self.assertIn("QM13210_USD_NY_DAY_CLEAR      = 0", EA)
        self.assertIn("QM13210_USD_NY_DAY_VETO       = 1", EA)
        self.assertIn("window_tm.hour = 14", window)
        self.assertIn("window_tm.hour = 23", window)

        # Tester path is the already loaded/sorted/hash-bound framework union.
        self.assertIn("g_qm_news_loaded", tester)
        self.assertIn("g_qm_news_available", tester)
        self.assertIn("g_qm_news_events_sorted", tester)
        self.assertIn("g_qm_news_rows_loaded", tester)
        self.assertIn("g_qm_news_hash", tester)
        self.assertNotIn("QM_NewsInit", tester)
        self.assertNotIn("QM_NewsBuildUtcIndex", tester)
        self.assertIn("g_qm_news_events[0].event_utc > utc_from", tester)
        self.assertIn(
            "g_qm_news_events[event_count - 1].event_utc < utc_to", tester
        )
        self.assertIn("QM_NewsLowerBoundUtc(utc_from)", tester)
        self.assertIn("event.event_utc >= utc_to", tester)
        self.assertIn('currency == "USD"', tester)
        self.assertIn('event.impact_upper == "HIGH"', tester)

        # Live path has no tester/CSV source and fails closed on incomplete API data.
        self.assertIn("CalendarValueHistory", live)
        self.assertIn("broker_to - 1", live)
        self.assertIn("QM_NewsLiveCalendarHealthy", live)
        self.assertIn("CalendarEventById", live)
        self.assertIn("CalendarCountryById", live)
        self.assertIn("CALENDAR_IMPORTANCE_HIGH", live)
        self.assertIn('== "USD"', live)
        self.assertNotIn("g_qm_news_events", live)
        self.assertNotIn("QM_NewsInit", live)

        # Cache is keyed by broker day, but only immutable tester results and a
        # live VETO persist. Live CLEAR/DATA_ERROR must execute a native query again.
        self.assertIn("MQLInfoInteger(MQL_TESTER)", status)
        self.assertIn("g_usd_ny_news_cache_day_start == broker_from", status)
        self.assertIn("tester ||", status)
        self.assertIn("QM13210_USD_NY_DAY_VETO", status)
        self.assertNotIn("ttl_seconds", status)
        self.assertNotIn("g_usd_ny_news_cache_checked", EA)
        self.assertIn(
            "if(tester || result == QM13210_USD_NY_DAY_VETO)", status
        )
        self.assertIn("g_usd_ny_news_cache_valid = false", status)
        self.assertIn("QM13210_USDNYNewsDayTester", status)
        self.assertIn("QM13210_USDNYNewsDayLive", status)

    def test_source_news_day_veto_precedes_setup_entry_and_pending_fill(self) -> None:
        advance = function_body(EA, "QM13210_AdvanceStateOnNewBar")
        entry = function_body(EA, "Strategy_EntrySignal")
        manage = function_body(EA, "Strategy_ManageOpenPosition")
        hook = function_body(EA, "Strategy_NewsFilterHook")
        on_tick = function_body(EA, "OnTick")

        self.assertLess(
            advance.index("QM13210_USDNYNewsDayAllows(bar_open)"),
            advance.index("QM13210_UpdateLastSwings();"),
        )
        self.assertLess(
            entry.index("QM13210_USDNYNewsDayAllows(broker_now)"),
            entry.index("QM13210_ComputeEntryDeadline"),
        )
        self.assertLess(
            manage.index("QM13210_USDNYNewsDayAllows(broker_now)"),
            manage.index("QM13210_NewsAllowsEntryNow(broker_now)"),
        )
        self.assertIn("asian_sweep_usd_ny_news_day_cancel", manage)
        self.assertIn("!QM13210_USDNYNewsDayAllows(broker_time)", hook)
        self.assertLess(
            on_tick.index("Strategy_NewsFilterHook(broker_now)"),
            on_tick.index("QM_TM_OpenPosition(req, out_ticket)"),
        )
        self.assertNotIn("QM_NewsDayHasEvent", EA)
        self.assertNotIn("QM_NEWS_TEMPORAL_SKIP_DAY", EA)

    def test_build_stays_dwx_only_and_xau_contract_is_fail_closed(self) -> None:
        contract = function_body(EA, "QM13210_XAUSymbolSpecValid")
        no_trade = function_body(EA, "Strategy_NoTradeFilter")
        on_init = function_body(EA, "OnInit")

        self.assertIn('_Symbol != "XAUUSD.DWX"', contract)
        self.assertIn("SYMBOL_TRADE_CONTRACT_SIZE", contract)
        self.assertIn("contract_size - 100.0", contract)
        self.assertIn("SYMBOL_POINT", contract)
        self.assertIn("point - 0.01", contract)
        self.assertIn("SYMBOL_TRADE_CALC_MODE", contract)
        self.assertIn("SYMBOL_CALC_MODE_CFD", contract)
        self.assertIn("SYMBOL_CURRENCY_PROFIT", contract)
        self.assertIn('profit_currency == "USD"', contract)

        self.assertIn('_Symbol != "EURUSD.DWX" && _Symbol != "XAUUSD.DWX"', no_trade)
        self.assertIn("!QM13210_XAUSymbolSpecValid()", no_trade)
        self.assertLess(
            on_init.index("QM13210_XAUSymbolSpecValid()"),
            on_init.index("QM_FrameworkInit"),
        )
        self.assertNotIn('"EURUSD"', EA)
        self.assertNotIn('"XAUUSD"', EA)
        self.assertNotIn("ACCOUNT_LOGIN", EA)
        self.assertNotIn("ACCOUNT_SERVER", EA)
        self.assertNotIn("StringReplace", EA)
        self.assertNotIn("StringSubstr", EA)

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
        self.assertIn("bid >= g_entry_tp", entry)
        self.assertIn("bid <= g_entry_tp", entry)
        self.assertNotIn("QM13210_ORDER_PLACED", entry)
        self.assertNotIn("g_entry_ready = false", entry)
        send = on_tick.index("QM_TM_OpenPosition(req, out_ticket)")
        checked = on_tick.index("if(placed && out_ticket > 0)")
        consumed = on_tick.index("g_phase = QM13210_ORDER_PLACED")
        self.assertLess(send, checked)
        self.assertLess(checked, consumed)


if __name__ == "__main__":
    unittest.main()
