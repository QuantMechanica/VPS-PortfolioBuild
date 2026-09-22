from __future__ import annotations

import copy
import tempfile
import unittest
from unittest.mock import patch
from dataclasses import replace
from datetime import date
from decimal import Decimal
from pathlib import Path

from replay_adapter import ReplayEvent
from strategy_runner import (
    ARM_IDS, MINUTE, NS, SCALE, TICK, DataInvalid, FrozenSignal, SessionPolicy,
    TradeBar, candidate_contract, cash_ns, check_period, fixed_risk_size,
    load_frozen, policy_outcome, readiness_plan, run_session_reference,
    timestamp_ns, trade_bars,
)

DAY = "2019-06-06"
NOW = timestamp_ns("2026-09-22T12:00:00Z")
ID = 1234


def px(number):
    return int(Decimal(str(number))*SCALE)


def bar(minute, close=100, low=99, high=101, symbol="MESM9", available=None):
    start = cash_ns(DAY,"09:30:00")+minute*MINUTE
    return TradeBar(symbol,start,start+MINUTE if available is None else available,
                    px(min(high,max(low,100))),px(high),px(low),px(close),minute)


def all_bars(*, direction="BUY", signal=True, symbol="MESM9"):
    rows = [bar(i,symbol=symbol) for i in range(385)]
    if signal:
        rows[5] = bar(5,102 if direction == "BUY" else 98,
                      99 if direction == "BUY" else 97.75,
                      102.25 if direction == "BUY" else 101,symbol)
    return rows


def quote(ordinal, stamp, bid=102, ask=102.25, size=10, *, kind="mbp-1", action=None):
    ns = cash_ns(DAY,stamp) if isinstance(stamp,str) else stamp
    return ReplayEvent(kind=kind,replay_ordinal=ordinal,source_ordinal=ordinal,
        ts_recv_ns=ns,ts_exchange_ns=ns,instrument_id=ID,publisher_id=1,
        source_sequence=ordinal,action=ord("A") if action is None else action,
        bid_px_raw=px(bid),ask_px_raw=px(ask),bid_size=size,ask_size=size,
        trading_indicator=ord("Y"),quoting_indicator=ord("Y"))


def status():
    return quote(0,"09:29:00",kind="status",action=7)


def policy(**kwargs):
    values = dict(day=DAY,calendar_verified=True,regular_cash_session=True,
        news_covered=True,news_as_of_ns=NOW,definitions_verified=True,
        raw_contract_data_verified=True,stage1_technical_pass=False,
        input_manifest_sha256="a"*64,fill_instrument_id=ID)
    values.update(kwargs)
    return SessionPolicy(**values)


class FrozenTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = load_frozen()

    def test_plan_all_cells_and_development_not_future_blocked(self):
        result = readiness_plan(self.config,DAY,as_of=date(2026,9,22))
        self.assertEqual((result["hypothesis_count"],result["arm_count"],result["trial_cell_count"]),(2,5,60))
        self.assertEqual(len({x["cell_id"] for x in result["cells"]}),60)
        self.assertTrue(all(x["result_status"] == "NOT_RUN" for x in result["cells"]))
        self.assertTrue(result["development_not_blocked_until_2027"])

    def test_config_mutation_and_nonfrozen_arms_rejected(self):
        changed = copy.deepcopy(self.config)
        changed["risk"]["max_micro_contracts"] = 3
        with self.assertRaisesRegex(DataInvalid,"OBJECT_CHANGED"):
            FrozenSignal(changed,ARM_IDS[0],DAY)
        with self.assertRaisesRegex(DataInvalid,"ARM_NOT_FROZEN"):
            FrozenSignal(self.config,"A6",DAY)

    def test_file_hash_pin_rejects_even_reformatted_input(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/"changed.json"
            path.write_text("{}",encoding="utf-8")
            with self.assertRaisesRegex(DataInvalid,"HASH_MISMATCH"):
                load_frozen(path)

    def test_embargo_blocks_only_prospective_holdout(self):
        check_period(self.config,"development",DAY,date(2026,9,22))
        with self.assertRaisesRegex(DataInvalid,"EMBARGO"):
            check_period(self.config,"untouched_holdout","2026-09-23",date(2026,9,22))
        check_period(self.config,"untouched_holdout","2026-09-23",date(2027,4,1))
        changed = copy.deepcopy(self.config)
        changed["periods"][-1]["economic_access_not_before"] = "2026-09-23"
        with self.assertRaisesRegex(DataInvalid,"OBJECT_CHANGED"):
            check_period(changed,"untouched_holdout","2026-09-23",date(2026,9,24))

    def test_dst_and_frozen_calendar_roll(self):
        self.assertEqual(cash_ns("2019-06-06","09:30:00"),timestamp_ns("2019-06-06T13:30:00Z"))
        self.assertEqual(cash_ns("2019-12-06","09:30:00"),timestamp_ns("2019-12-06T14:30:00Z"))
        self.assertEqual(candidate_contract("MES","2019-06-14"),("MESM9",False))
        self.assertEqual(candidate_contract("MES","2019-06-17"),("MESU9",True))
        self.assertEqual(candidate_contract("ES","2019-06-18"),("ESU9",False))

    def test_orb_strict_close_and_one_attempt(self):
        kernel = FrozenSignal(self.config,ARM_IDS[0],DAY)
        for i in range(5): self.assertIsNone(kernel.on_bar(bar(i)))
        self.assertIsNone(kernel.on_bar(bar(5,101)))
        signal = kernel.on_bar(bar(6,102,high=102))
        self.assertEqual((signal.side,signal.stop_raw),("BUY",px(99)))
        self.assertIsNone(signal.target_raw)
        self.assertIsNone(kernel.on_bar(bar(7,98,low=98)))

    def test_mini_signal_uses_micro_stop(self):
        kernel = FrozenSignal(self.config,ARM_IDS[1],DAY)
        for i in range(5):
            kernel.on_bar(bar(i))
            kernel.on_bar(bar(i,110,109,111,"ESM9"))
        intent = kernel.on_bar(bar(5,112,99,112,"ESM9"))
        self.assertEqual(intent.stop_raw,px(99))
        self.assertEqual(intent.side,"BUY")

    def test_mnq_transfer_keeps_distinct_signal_root(self):
        for arm,signal in ((ARM_IDS[3],"MNQM9"),(ARM_IDS[4],"NQM9")):
            model = FrozenSignal(self.config,arm,DAY)
            self.assertEqual((model.signal_symbol,model.fill_symbol),(signal,"MNQM9"))

    def test_reversion_four_ticks_same_bar_confirmation_and_two_tick_stop(self):
        kernel = FrozenSignal(self.config,ARM_IDS[2],DAY)
        for i in range(5): kernel.on_bar(bar(i))
        intent = kernel.on_bar(bar(5,99.25,98,101))
        self.assertEqual((intent.side,intent.stop_raw,intent.target_raw),("BUY",px(97.5),px(100)))

    def test_reversion_both_sides_consumes_attempt(self):
        kernel = FrozenSignal(self.config,ARM_IDS[2],DAY)
        for i in range(5): kernel.on_bar(bar(i))
        self.assertIsNone(kernel.on_bar(bar(5,100,98,102)))
        self.assertEqual(kernel.reason,"AMBIGUOUS_BOTH_SIDES")
        self.assertIsNone(kernel.on_bar(bar(6,99.5,98,101)))

    def test_reversion_timeout_includes_excursion_bar_no_reset(self):
        kernel = FrozenSignal(self.config,ARM_IDS[2],DAY)
        for i in range(5): kernel.on_bar(bar(i))
        for i in range(5,20):
            self.assertIsNone(kernel.on_bar(bar(i,98.5,98,101)))
        self.assertEqual(kernel.reason,"EXCURSION_TIMED_OUT_SOLE_ATTEMPT")
        self.assertIsNone(kernel.on_bar(bar(20,99.5,98,101)))

    def test_reversion_confirmation_on_fifteenth_bar_is_allowed(self):
        kernel = FrozenSignal(self.config,ARM_IDS[2],DAY)
        for i in range(5): kernel.on_bar(bar(i))
        for i in range(5,19): kernel.on_bar(bar(i,98.5,98,101))
        self.assertIsNotNone(kernel.on_bar(bar(19,99.5,98,101)))

    def test_missing_minutes_and_wrong_symbols_are_invalid(self):
        kernel = FrozenSignal(self.config,ARM_IDS[0],DAY)
        kernel.on_bar(bar(0))
        with self.assertRaisesRegex(DataInvalid,"MISSING_OR_REORDERED"):
            kernel.on_bar(bar(2))
        with self.assertRaisesRegex(DataInvalid,"UNEXPECTED_RAW"):
            FrozenSignal(self.config,ARM_IDS[0],DAY).on_bar(bar(0,symbol="MES.c.0"))

    def test_fixed_cost_sizing_boundaries(self):
        base = self.config["execution"]["scenarios"][0]
        self.assertEqual(fixed_risk_size(px(9),"MES",base),2)  # 2*(45+4.40)=98.80
        self.assertEqual(fixed_risk_size(px(9.25),"MES",base),1)
        self.assertEqual(fixed_risk_size(px(20),"MES",base),0)

    def test_news_missing_stale_boundary_and_nfp(self):
        self.assertEqual(policy_outcome(policy(news_covered=False),NOW,1)[0],"NEWS_BLACKOUT")
        self.assertEqual(policy_outcome(policy(news_as_of_ns=NOW-169*3600*NS),NOW,1)[0],"NEWS_BLACKOUT")
        self.assertEqual(policy_outcome(policy(high_usd_event_ns=(cash_ns(DAY,"09:00:00"),)),NOW,1)[0],"NEWS_BLACKOUT")
        self.assertIsNone(policy_outcome(policy(high_usd_event_ns=(cash_ns(DAY,"08:30:00"),)),NOW,1))

    def test_roll_and_stage_no_economic_selection(self):
        self.assertEqual(policy_outcome(policy(day="2019-06-17"),NOW,1)[0],"ROLL_EXCLUDED")
        self.assertEqual(policy_outcome(policy(),NOW,2)[1],"MNQ_IMPORT_TECHNICAL_STAGE_GATE")
        self.assertIsNone(policy_outcome(policy(stage1_technical_pass=True),NOW,2))


class BarTests(unittest.TestCase):
    def trade(self,i,exchange,receive=None,price=100,sequence=None):
        e = quote(i,exchange,action=ord("T"))
        return replace(e,ts_recv_ns=e.ts_recv_ns if receive is None else receive,
                       trade_price_raw=px(price),trade_size=1,source_sequence=i if sequence is None else sequence)

    def test_completed_bar_available_only_after_receipt_and_preserves_ties(self):
        start = cash_ns(DAY,"09:30:00")
        events = [self.trade(0,start,price=100,sequence=10),
                  self.trade(1,start,price=100.25,sequence=10),
                  self.trade(2,start+MINUTE,start+MINUTE+100,price=101,sequence=11)]
        rows = list(trade_bars(events,"MESM9",end_watermark_ns=start+2*MINUTE))
        self.assertEqual(rows[0].close_raw,px(100.25))
        self.assertEqual(rows[0].available_ns,start+MINUTE+100)

    def test_late_trade_is_not_repaired_using_future_knowledge(self):
        start = cash_ns(DAY,"09:30:00")
        events = [self.trade(0,start),self.trade(1,start+MINUTE),
                  self.trade(2,start+1,start+MINUTE+1)]
        with self.assertRaisesRegex(DataInvalid,"LATE_TRADE"):
            list(trade_bars(events,"MESM9",end_watermark_ns=start+2*MINUTE))

    def test_delayed_monotonic_trades_finalize_only_on_later_exchange_minute(self):
        start = cash_ns(DAY,"09:30:00")
        boundary = start+MINUTE
        events = [self.trade(0,boundary-2000,boundary+1000,100),
                  self.trade(1,boundary-1000,boundary+2000,101),
                  self.trade(2,boundary+1000,boundary+3000,102)]
        rows = list(trade_bars(events,"MESM9",end_watermark_ns=start+2*MINUTE))
        self.assertEqual(rows[0].close_raw,px(101))
        self.assertEqual(rows[0].available_ns,boundary+3000)
        self.assertEqual(rows[0].last_source_ordinal,1)

    def test_quote_receive_boundary_cannot_finalize_exchange_trade_bar(self):
        start = cash_ns(DAY,"09:30:00")
        boundary = start+MINUTE
        clock_quote = replace(quote(1,boundary+1500),ts_exchange_ns=boundary-1500)
        events = [self.trade(0,boundary-2000,boundary+1000,100),clock_quote,
                  self.trade(2,boundary-1000,boundary+2000,101),
                  self.trade(3,boundary+1000,boundary+3000,102)]
        rows = list(trade_bars(events,"MESM9",end_watermark_ns=start+2*MINUTE))
        self.assertEqual(rows[0].close_raw,px(101))
        self.assertEqual(rows[0].available_ns,boundary+3000)

    def test_unresolved_source_order_and_future_timestamp_rejected(self):
        start = cash_ns(DAY,"09:30:00")
        with self.assertRaisesRegex(DataInvalid,"UNRESOLVED"):
            list(trade_bars([self.trade(1,start),self.trade(1,start+1)],"MESM9",end_watermark_ns=start+MINUTE))
        with self.assertRaisesRegex(DataInvalid,"BEFORE_EXCHANGE"):
            list(trade_bars([self.trade(1,start+1,start)],"MESM9",end_watermark_ns=start+MINUTE))

    def test_quality_flags_and_crossed_signal_trade_fail_closed(self):
        start = cash_ns(DAY,"09:30:00")
        for flag in (8,4,32,168):
            with self.subTest(flag=flag),self.assertRaisesRegex(DataInvalid,"SIGNAL_EVENT_QUALITY"):
                list(trade_bars([replace(self.trade(1,start),flags=flag)],"MESM9",end_watermark_ns=start+MINUTE))
        crossed = replace(self.trade(1,start),bid_px_raw=px(101),ask_px_raw=px(100))
        with self.assertRaisesRegex(DataInvalid,"CROSSED_BBO"):
            list(trade_bars([crossed],"MESM9",end_watermark_ns=start+MINUTE))
        # Trades-only mini input has no BBO; never invent a book to validate it.
        mini = replace(self.trade(1,start),kind="trades",bid_px_raw=None,ask_px_raw=None,bid_size=0,ask_size=0)
        self.assertEqual(len(list(trade_bars([mini],"ESM9",end_watermark_ns=start+MINUTE))),1)


class ExecutionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.config = load_frozen()

    def run_case(self,events,**kwargs):
        rows = kwargs.pop("bars",all_bars())
        return run_session_reference(self.config,kwargs.pop("arm_id",ARM_IDS[0]),kwargs.pop("scenario","BASE"),
            kwargs.pop("policy",policy()),rows,rows,events,now_ns=NOW,**kwargs)

    def test_buy_side_costs_flat_latency_and_no_frozen_claim(self):
        events = [status(),quote(1,"09:36:00.050"),quote(2,"09:36:00.100"),
                  quote(3,"15:55:00.050",105,105.25),quote(4,"15:55:00.100",105,105.25)]
        row = self.run_case(events)
        self.assertEqual(row["outcome"],"TRADE")
        self.assertEqual(row["trade"]["entry_ordinal"],2)
        self.assertEqual(row["trade"]["entry_raw"],px(102.5))
        self.assertEqual(row["trade"]["exit_raw"],px(104.75))
        self.assertEqual(Decimal(row["net_profit_usd"]),Decimal("18.7"))
        self.assertEqual(row["frozen_trial_result_status"],"NOT_RUN")
        self.assertFalse(row["economic_success_certified"])

    def test_short_uses_bid_entry_ask_exit(self):
        events = [status(),quote(1,"09:36:00.100",97.75,98),quote(2,"15:55:00.100",94.75,95)]
        row = self.run_case(events,bars=all_bars(direction="SELL"))
        self.assertEqual(row["trade"]["entry_raw"],px(97.5))
        self.assertEqual(row["trade"]["exit_raw"],px(95.25))

    def test_stop_gap_uses_later_quote_not_stop_level(self):
        row = self.run_case([status(),quote(1,"09:36:00.100"),quote(2,"09:37:00",98,98.25),quote(3,"09:37:00.100",95,95.25)])
        self.assertEqual(row["trade"]["exit_reason"],"STOP")
        self.assertEqual(row["trade"]["exit_raw"],px(94.75))

    def test_missing_flat_quote_invalid_not_zero_profit(self):
        row = self.run_case([status(),quote(1,"09:36:00.100"),quote(2,"15:59:30.001")])
        self.assertEqual(row["outcome"],"DATA_INVALID")
        self.assertIsNone(row["net_profit_usd"])
        self.assertIsNone(row["ending_balance_usd"])
        self.assertFalse(row["account_path_valid"])

    def test_no_signal_retained_and_missing_minutes_invalid(self):
        row = self.run_case([status(),quote(1,"15:55:00.100"),quote(2,"15:59:30.001")],bars=all_bars(signal=False))
        self.assertEqual((row["outcome"],row["net_profit_usd"]),("NO_SIGNAL","0"))
        bad = self.run_case([],bars=all_bars()[:-1])
        self.assertEqual(bad["outcome"],"DATA_INVALID")

    def test_empty_status_only_and_truncated_fill_stream_invalid(self):
        for events in ([],[status()],[status(),quote(1,"09:36:00.100",size=0)],
                       [status(),quote(1,"15:59:30.001")],
                       [status(),quote(1,"09:36:00.100",size=0),quote(2,"15:59:30.001")]):
            with self.subTest(events=events):
                row = self.run_case(events)
                self.assertEqual(row["outcome"],"DATA_INVALID")
                self.assertIsNone(row["net_profit_usd"])
                self.assertIsNone(row["ending_balance_usd"])
                self.assertFalse(row["account_path_valid"])

    def test_blackout_never_reads_events_or_bars(self):
        def forbidden():
            raise AssertionError("data was read during excluded session")
            yield
        row = self.run_case(forbidden(),bars=forbidden(),policy=policy(news_covered=False))
        self.assertEqual((row["outcome"],row["net_profit_usd"]),("NEWS_BLACKOUT","0"))

    def test_insufficient_size_not_silently_reduced(self):
        row = self.run_case([status(),quote(1,"09:36:00.100",size=1),quote(2,"09:36:00.200"),quote(3,"15:55:00.100",105,105.25)])
        self.assertEqual(row["trade"]["entry_ordinal"],2)
        self.assertEqual(row["trade"]["quantity"],2)

    def test_marked_drawdown_breach_stays_after_recovery(self):
        row = self.run_case([status(),quote(1,"09:36:00.100"),quote(2,"09:37:00",1,1.25),quote(3,"09:37:00.100",104,104.25)])
        self.assertTrue(row["research_halt"])
        self.assertGreater(Decimal(row["max_daily_loss_pct"]),2)
        self.assertGreater(Decimal(row["net_profit_usd"]),0)

    def test_all_three_cost_scenarios_and_reference_label(self):
        results = []
        for scenario in ("BASE","ADVERSE","SEVERE"):
            row = self.run_case([status(),quote(1,"09:36:01"),quote(2,"15:55:01",105,105.25)],
                scenario=scenario,mode="DEVELOPMENT_DIAGNOSTIC")
            self.assertEqual(row["classification"],"DEVELOPMENT_REFERENCE_DIAGNOSTIC")
            results.append(Decimal(row["net_profit_usd"]))
        self.assertGreater(results[0],results[1])
        self.assertGreater(results[1],results[2])


class HarnessTests(unittest.TestCase):
    def test_fixed_scope_is_180_not_90_rows(self):
        from run_june2019_reference import dates, SCENARIOS
        self.assertEqual(len(dates()),20)
        self.assertEqual(len(dates())*len(ARM_IDS[:3])*len(SCENARIOS),180)

    def test_invalid_account_cannot_resume(self):
        from run_june2019_reference import carry_forward
        state = {"valid":True,"balance":Decimal("50000"),"high":Decimal("50000"),"halt":False}
        carry_forward(state,{"account_path_valid":False,"ending_balance_usd":None,"chicago_trade_date":"2019-06-06"})
        self.assertFalse(state["valid"])
        self.assertIsNone(state["balance"])
        self.assertEqual(state["invalid_at"],"2019-06-06")
        with self.assertRaisesRegex(DataInvalid,"CANNOT_RESUME_POISONED_ACCOUNT"):
            carry_forward(state,{"account_path_valid":True,"ending_balance_usd":"50100",
                                  "high_watermark_usd":"50100","research_halt":False})

    def test_carry_keeps_actual_balance_high_watermark_and_sticky_halt(self):
        from run_june2019_reference import carry_forward
        state = {"valid":True,"balance":Decimal("50000"),"high":Decimal("50000"),"halt":True}
        carry_forward(state,{"account_path_valid":True,"ending_balance_usd":"49900",
                              "high_watermark_usd":"50100","research_halt":False})
        self.assertEqual(state["balance"],Decimal("49900"))
        self.assertEqual(state["high"],Decimal("50100"))
        self.assertTrue(state["halt"])

    def test_cash_cache_preserves_ordinals_and_refuses_changed_source(self):
        import hashlib
        import run_june2019_reference as harness
        start = cash_ns(DAY,"09:30:00")
        rows = []
        for recv in (start-1,start,start+1,cash_ns(DAY,"16:00:00")):
            rows.append(harness.TRADE.pack(12,0,1,736,recv,px(100),1,ord("T"),ord("B"),0,0,recv,0,len(rows)))
        raw = b"HEADER00"+b"".join(rows)
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)/"source.dbn"
            source.write_bytes(raw)
            proof = {"path":str(source),"schema":"trades","symbol":"ESM9",
                     "file_sha256":hashlib.sha256(raw).hexdigest(),"record_count":4}
            def header(stream,digest):
                digest.update(stream.read(8))
                return {"dbn_version":3,"schema_code":4}
            with patch.object(harness,"read_header",side_effect=header):
                cache = harness.extract_cash(proof,[DAY])
                kept = list(harness.cached_records(cache[DAY],harness.TRADE))
                self.assertEqual([row[0] for row in kept],[1,2])
                self.assertEqual([row[1] for row in kept],rows[1:3])
                proof["file_sha256"] = "0"*64
                with self.assertRaisesRegex(DataInvalid,"HASH_OR_COUNT_CHANGED"):
                    harness.extract_cash(proof,[DAY])

    def test_exclusive_plan_receipt_never_overwrites(self):
        from run_june2019_reference import save_exclusive,binding,verify_binding
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/"plan.json"
            save_exclusive(path,{"fixed":True})
            bound = binding(path)
            with self.assertRaises(FileExistsError):
                save_exclusive(path,{"fixed":False})
            verify_binding(bound)
            path.write_text("changed",encoding="utf-8")
            with self.assertRaisesRegex(DataInvalid,"BOUND_INPUT_CHANGED"):
                verify_binding(bound)


if __name__ == "__main__":
    unittest.main()
