from __future__ import annotations

from copy import deepcopy
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import unittest

from replay_adapter import QuoteGate, ReplayEvent
from strategy_runner import ARM_IDS, MINUTE, NS, SessionPolicy, TradeBar, cash_ns, load_frozen
from native_strategy_parity import (
    CONTRACT_SHA256,
    DEFAULT_SOURCE_PLAN,
    REFERENCE_RESULT_SHA256,
    SOURCE_PLAN_SHA256,
    AccountCarry,
    MarkAudit,
    carry_forward,
    load_contract,
    native_replay_orders,
    raw_quote_binding,
    read_json,
    run_contract_session,
    sha256_file,
)


DAY = "2019-06-06"
INSTRUMENT_ID = 1234


def px(value) -> int:
    return int(Decimal(str(value)) * NS)


def quote(ordinal: int, stamp: int, *, bid="102.00", ask="102.25",
          bid_size=10, ask_size=10, flags=128, action=ord("A")) -> ReplayEvent:
    raw = (f"raw-{ordinal}-{stamp}-{bid}-{ask}-{bid_size}-{ask_size}".encode() + bytes(80))[:80]
    return ReplayEvent(
        "mbp-1", ordinal, 10_000 + ordinal, stamp, stamp - 50_000,
        INSTRUMENT_ID, 1, ordinal, action, flags=flags,
        bid_px_raw=px(bid), ask_px_raw=px(ask),
        bid_size=bid_size, ask_size=ask_size, raw_record=raw,
    )


def status(ordinal: int, stamp: int, *, trading=True) -> ReplayEvent:
    flag = ord("Y") if trading else ord("N")
    return ReplayEvent(
        "status", ordinal, 20_000 + ordinal, stamp, stamp,
        INSTRUMENT_ID, 1, None, 7,
        trading_indicator=flag, quoting_indicator=flag,
        raw_record=(f"status-{ordinal}".encode() + bytes(40))[:40],
    )


def bars(*, signal_close="102.00") -> tuple[TradeBar, ...]:
    opening = cash_ns(DAY, "09:30:00")
    end = cash_ns(DAY, "15:55:00")
    rows = []
    for index, start in enumerate(range(opening, end, MINUTE)):
        close = Decimal(signal_close) if index >= 5 else Decimal("100")
        high = max(Decimal("101"), close)
        low = Decimal("99")
        rows.append(TradeBar(
            "MESM9", start, start + MINUTE + 10,
            px("100"), px(high), px(low), px(close), index + 1,
        ))
    return tuple(rows)


def policy() -> SessionPolicy:
    return SessionPolicy(
        day=DAY,
        calendar_verified=True,
        regular_cash_session=True,
        news_covered=True,
        news_as_of_ns=1_569_999_999_000_000_000,
        definitions_verified=True,
        raw_contract_data_verified=True,
        stage1_technical_pass=True,
        input_manifest_sha256=SOURCE_PLAN_SHA256,
        fill_instrument_id=INSTRUMENT_ID,
        calendar_basis="TEST_ONLY",
    )


def run_orb(events):
    config = load_frozen()
    contract = load_contract()
    return run_contract_session(
        config, contract, ARM_IDS[0], "BASE", policy(), bars(), bars(), iter(events),
        plan_sha256=SOURCE_PLAN_SHA256,
        now_ns=1_569_999_999_000_000_000,
        starting_balance=Decimal("50000"),
        prior_high_watermark=Decimal("50000"),
        prior_halt=False,
    )


def native_quote_binding(ordinal: int, stamp: int, bid: str, ask: str,
                         bid_size=10, ask_size=10) -> dict:
    event = quote(ordinal, stamp, bid=bid, ask=ask,
                  bid_size=bid_size, ask_size=ask_size)
    return raw_quote_binding(event)


class ContractTests(unittest.TestCase):
    def test_contract_and_retained_reference_are_hash_bound(self):
        contract = load_contract()
        self.assertEqual(contract["entry"]["quantity_policy"],
                         "FIRST_ELIGIBLE_SUBMISSION_QUOTE_FIXED_NO_RESIZE")
        self.assertEqual(contract["scope"]["planned_session_rows"], 180)
        self.assertEqual(contract["scope"]["formal_frozen_trial_status"], "NOT_RUN")
        self.assertEqual(sha256_file(DEFAULT_SOURCE_PLAN), SOURCE_PLAN_SHA256)
        reference = DEFAULT_SOURCE_PLAN.parent / "result.json"
        self.assertEqual(sha256_file(reference), REFERENCE_RESULT_SHA256)
        self.assertEqual(len(read_json(DEFAULT_SOURCE_PLAN)["rows"]), 180)
        self.assertEqual(len(CONTRACT_SHA256), 64)

    def test_raw_binding_keeps_both_times_order_fields_and_bytes(self):
        event = quote(7, 123_456_789, bid="99.75", ask="100.00", bid_size=3, ask_size=2)
        bound = raw_quote_binding(event)
        self.assertEqual(bound["replay_ordinal"], 7)
        self.assertEqual(bound["source_ordinal"], 10_007)
        self.assertEqual(bound["ts_recv_ns"], 123_456_789)
        self.assertEqual(bound["ts_exchange_ns"], 123_406_789)
        self.assertEqual(bound["bid_px_raw"], px("99.75"))
        self.assertEqual(bound["ask_px_raw"], px("100.00"))
        self.assertEqual(bound["raw_record_sha256"], hashlib.sha256(event.raw_record).hexdigest())

    def test_stale_bbo_timer_cannot_authorize_submission(self):
        gate = QuoteGate(max_quote_age_ns=0, instrument_id=INSTRUMENT_ID)
        start = 1_000_000_000
        gate.consume(status(0, start - 1))
        gate.consume(quote(1, start))
        decision = gate.execution_quote(start + 100_000_000, "BUY", 1,
                                        after_ordinal=0, eligible_at_ns=start + 100_000_000)
        self.assertFalse(decision.eligible)
        self.assertIn("REPLAY_CLOCK_NOT_AT_REQUEST", decision.reasons)

    def test_quantity_freezes_before_submit_and_does_not_resize(self):
        decision = cash_ns(DAY, "09:36:00") + 10
        latency = 100_000_000
        flat = cash_ns(DAY, "15:55:00")
        events = [
            status(0, cash_ns(DAY, "09:29:59")),
            quote(1, decision),
            # Quantity two freezes here, but visible ask depth one blocks submit.
            quote(2, decision + latency, bid="102.00", ask="102.25", ask_size=1),
            # A recomputation at this much worse price would yield quantity one.
            quote(3, decision + latency + 1, bid="110.00", ask="110.25", ask_size=2),
            quote(4, flat + latency, bid="110.50", ask="110.75", bid_size=2),
        ]
        row = run_orb(events)
        self.assertEqual(row["outcome"], "TRADE")
        self.assertEqual(row["orders"][0]["quantity"], 2)
        self.assertEqual(row["orders"][0]["sizing_quote"]["replay_ordinal"], 2)
        self.assertEqual(row["orders"][0]["quote"]["replay_ordinal"], 3)
        self.assertIn("INSUFFICIENT_DISPLAYED_SIZE", row["eligibility_rejections"])

    def test_stop_gap_uses_post_trigger_fresh_quote_not_stop_price(self):
        decision = cash_ns(DAY, "09:36:00") + 10
        latency = 100_000_000
        trigger = cash_ns(DAY, "10:00:00")
        events = [
            status(0, cash_ns(DAY, "09:29:59")),
            quote(1, decision),
            quote(2, decision + latency, bid="102.00", ask="102.25", ask_size=2),
            quote(3, trigger, bid="98.00", ask="98.25", bid_size=2),
            quote(4, trigger + latency, bid="95.00", ask="95.25", bid_size=2),
        ]
        row = run_orb(events)
        self.assertEqual(row["outcome"], "TRADE")
        self.assertEqual(row["reason_code"], "STOP")
        self.assertEqual(row["orders"][1]["quote"]["replay_ordinal"], 4)
        self.assertEqual(row["trade"]["exit_raw"], px("94.75"))
        self.assertNotEqual(row["trade"]["exit_raw"], row["trade"]["stop_raw"])

    def test_missing_flat_confirmation_poison_account_path(self):
        decision = cash_ns(DAY, "09:36:00") + 10
        latency = 100_000_000
        deadline = cash_ns(DAY, "15:59:30")
        events = [
            status(0, cash_ns(DAY, "09:29:59")),
            quote(1, decision),
            quote(2, decision + latency, bid="102.00", ask="102.25", ask_size=2),
            quote(3, deadline + 1, bid="103.00", ask="103.25", bid_size=2),
        ]
        row = run_orb(events)
        self.assertEqual(row["outcome"], "DATA_INVALID")
        self.assertEqual(row["reason_code"], "NO_CONFIRMED_FLAT_BY_155930")
        self.assertFalse(row["account_path_valid"])
        self.assertIsNone(row["ending_balance_usd"])

    def test_poisoned_account_never_resets_or_aggregates(self):
        carry = AccountCarry()
        carry_forward(carry, {
            "account_path_valid": False,
            "ending_balance_usd": None,
            "chicago_trade_date": DAY,
        })
        self.assertFalse(carry.valid)
        self.assertEqual(carry.invalid_since, DAY)
        self.assertEqual(carry.balance, Decimal("50000"))

    def test_mark_audit_retains_equal_time_source_order_without_jitter(self):
        audit = MarkAudit()
        first = quote(1, 5_000)
        second = quote(2, 5_000)
        audit.add(first, price_raw=px("100"), equity=Decimal("49999.00"))
        audit.add(second, price_raw=px("99.75"), equity=Decimal("49998.00"))
        report = audit.report()
        self.assertEqual(report["count"], 2)
        self.assertEqual(report["first"]["ts_recv_ns"], report["last"]["ts_recv_ns"])
        self.assertEqual(report["first"]["replay_ordinal"], 1)
        self.assertEqual(report["last"]["replay_ordinal"], 2)


class NativeLifecycleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = read_json(DEFAULT_SOURCE_PLAN)

    def orders(self, *, ask_size=10):
        entry_stamp = cash_ns(DAY, "10:00:00")
        exit_stamp = entry_stamp + NS
        entry_quote = native_quote_binding(1, entry_stamp, "2800.00", "2800.25",
                                           ask_size=ask_size)
        exit_quote = native_quote_binding(2, exit_stamp, "2801.00", "2801.25")
        common = {
            "raw_symbol": "MESM9",
            "quantity": 1,
            "quantity_policy": "FIRST_ELIGIBLE_SUBMISSION_QUOTE_FIXED_NO_RESIZE",
            "sizing_quote": entry_quote,
        }
        return [
            {
                **common,
                "role": "ENTRY",
                "side": "BUY",
                "reason": "TEST_ENTRY",
                "decision_ns": entry_stamp - 100_000_000,
                "eligible_at_ns": entry_stamp,
                "quote": entry_quote,
                "expected_fill": {
                    "side": "BUY", "quantity": 1, "price_raw": px("2800.50"),
                    "commission_usd": "0.95", "timestamp_ns": entry_stamp,
                },
            },
            {
                **common,
                "role": "EXIT",
                "side": "SELL",
                "reason": "TEST_EXIT",
                "decision_ns": exit_stamp - 100_000_000,
                "eligible_at_ns": exit_stamp,
                "quote": exit_quote,
                "sizing_quote": None,
                "expected_fill": {
                    "side": "SELL", "quantity": 1, "price_raw": px("2800.75"),
                    "commission_usd": "0.95", "timestamp_ns": exit_stamp,
                },
            },
        ]

    def test_native_order_fee_position_and_equal_time_lifecycle(self):
        result = native_replay_orders(
            plan=self.plan,
            orders=self.orders(),
            scenario={"commission_usd_round_turn_per_micro": 1.9,
                      "slippage_ticks_per_side": 1, "latency_ms": 100},
            starting_balance=Decimal("50000"),
            expected_ending_balance=Decimal("49999.35"),
        )
        self.assertEqual(result["status"], "PASS")
        self.assertTrue(result["ending_flat"])
        self.assertEqual(result["ending_balance_usd"], "49999.35")
        self.assertEqual(len(result["fill_model_calls"]), 2)
        self.assertTrue(result["actual_visible_depth_bound"])
        grouped = {}
        for event in result["lifecycle"]:
            grouped.setdefault(event["timestamp_ns"], []).append(event["sequence"])
        self.assertTrue(any(len(sequences) >= 3 for sequences in grouped.values()))
        self.assertTrue(all(sequences == sorted(sequences) for sequences in grouped.values()))

    def test_native_fill_refuses_quantity_above_actual_depth(self):
        orders = self.orders(ask_size=1)
        orders[0]["quantity"] = 2
        orders[0]["expected_fill"]["quantity"] = 2
        with self.assertRaisesRegex(Exception, "ACTUAL_VISIBLE_DEPTH"):
            native_replay_orders(
                plan=self.plan,
                orders=orders,
                scenario={"commission_usd_round_turn_per_micro": 1.9,
                          "slippage_ticks_per_side": 1, "latency_ms": 100},
                starting_balance=Decimal("50000"),
                expected_ending_balance=None,
            )


if __name__ == "__main__":
    unittest.main()
