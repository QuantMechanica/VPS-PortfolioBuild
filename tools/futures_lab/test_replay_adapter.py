"""Adversarial offline adapter checks; no credentials, downloads or orders."""
from dataclasses import replace
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import replay_adapter as a
import validate_databento_pilot as v

ID = 42001581
T = 1789509600000000000


def quote(ordinal=1, time=T+1, **changes):
    fields = dict(kind="mbp-1", replay_ordinal=ordinal, source_ordinal=ordinal,
                  ts_recv_ns=time, ts_exchange_ns=time-1, instrument_id=ID, publisher_id=1,
                  source_sequence=42+ordinal, action=ord("A"), side=ord("B"), flags=128,
                  trade_price_raw=6000_250_000_000, trade_size=1,
                  bid_px_raw=6000_000_000_000, ask_px_raw=6000_250_000_000, bid_size=3, ask_size=2)
    fields.update(changes)
    return a.ReplayEvent(**fields)


def status(ordinal=0, time=T, *, trading=True, **changes):
    fields = dict(kind="status", replay_ordinal=ordinal, source_ordinal=ordinal,
                  ts_recv_ns=time, ts_exchange_ns=time-1, instrument_id=ID, publisher_id=1,
                  source_sequence=None, action=7 if trading else 2,
                  trading_indicator=ord("Y") if trading else ord("N"), quoting_indicator=ord("Y"))
    fields.update(changes)
    return a.ReplayEvent(**fields)


def raw_quote(time=T+1, sequence=1):
    return a.MBP.pack(20, 1, 1, ID, time-1, 6000_250_000_000, 1, ord("A"), ord("B"),
                      128, 0, time, 1, sequence, 6000_000_000_000, 6000_250_000_000, 3, 2, 1, 1)


def raw_status(time=T, action=7):
    return a.STATUS.pack(10, 0x12, 1, ID, time-1, time, action, 1, 0, ord("Y"), ord("Y"), ord("~"))


def metadata(schema):
    meta = bytearray(352)
    meta[:9] = b"GLBX.MDP3"
    struct.pack_into("<H", meta, 16, 1 if schema == "mbp-1" else 11)
    return b"DBN\x03" + struct.pack("<I", len(meta)) + meta


class ReplayTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)

    def source(self, schema, records):
        raw = metadata(schema) + b"".join(records)
        path = self.root / (schema + ".dbn")
        path.write_bytes(raw)
        expected = {"actual_file_bytes": len(raw), "file_sha256": hashlib.sha256(raw).hexdigest(),
                    "record_count": len(records), "instrument_id": str(ID), "publisher_ids": [1]}
        return path, expected

    def active_gate(self, **kwargs):
        gate = a.QuoteGate(max_quote_age_ns=kwargs.pop("max_quote_age_ns", 0), **kwargs)
        gate.consume(status())
        gate.consume(quote())
        return gate

    def eligible(self, gate, **changes):
        params = dict(now_ns=T+1, side="BUY", quantity=1, after_ordinal=0, eligible_at_ns=T+1)
        params.update(changes)
        return gate.execution_quote(**params)

    def test_side_correct_prices_size_and_latency_do_not_manufacture_fills(self):
        gate = self.active_gate()
        self.assertEqual(self.eligible(gate).price_raw, 6000_250_000_000)
        self.assertEqual(self.eligible(gate, side="SELL").price_raw, 6000_000_000_000)
        for change, reason in (({"quantity": 3}, "INSUFFICIENT_DISPLAYED_SIZE"),
                               ({"eligible_at_ns": T+2}, "LATENCY_NOT_ELAPSED"),
                               ({"after_ordinal": 1}, "QUOTE_NOT_AFTER_DECISION")):
            result = self.eligible(gate, **change)
            self.assertFalse(result.eligible)
            self.assertIsNone(result.quote)
            self.assertIsNone(result.price_raw)
            self.assertIn(reason, result.reasons)

    def test_invalid_bbo_clears_previous_valid_quote_for_signal_and_execution(self):
        cases = [({"bid_px_raw": a.UNDEF_PRICE}, "MISSING_BID"),
                 ({"ask_px_raw": None}, "MISSING_ASK"), ({"bid_px_raw": 0}, "NONPOSITIVE_BID"),
                 ({"ask_px_raw": -1}, "NONPOSITIVE_ASK"), ({"bid_size": 0}, "ZERO_OR_INVALID_BID_SIZE"),
                 ({"ask_size": 0}, "ZERO_OR_INVALID_ASK_SIZE"),
                 ({"bid_px_raw": 6000_250_000_000}, "LOCKED_BBO"),
                 ({"bid_px_raw": 6001_000_000_000}, "CROSSED_BBO"),
                 ({"bid_px_raw": 6000_000_000_001}, "BID_OFF_TICK")]
        for fields, reason in cases:
            with self.subTest(reason=reason):
                gate = self.active_gate(max_quote_age_ns=10**9)
                decision = gate.consume(quote(2, T+2, **fields))
                self.assertFalse(decision.eligible)
                self.assertIsNone(decision.quote)
                blocked = self.eligible(gate, now_ns=T+2)
                self.assertFalse(blocked.eligible)
                self.assertIn(reason, blocked.reasons)

    def test_invalid_trade_cannot_enter_signal_input_via_good_bbo(self):
        for fields in ({"trade_price_raw": a.UNDEF_PRICE}, {"trade_size": 0}, {"trade_price_raw": True}):
            gate = self.active_gate()
            result = gate.consume(quote(2, T+2, action=ord("T"), **fields))
            self.assertFalse(result.eligible)

    def test_bad_time_snapshot_and_book_flags_block_even_good_looking_bbo(self):
        for flags, reason in ((8, "DBN_BAD_TS_RECV"), (4, "DBN_MAYBE_BAD_BOOK"),
                              (32, "DBN_SNAPSHOT_NOT_FRESH_EXECUTION"),
                              (168, "DBN_BAD_TS_RECV"), (2, "DBN_PUBLISHER_SPECIFIC_UNBOUND"),
                              (1, "DBN_RESERVED_FLAG_UNBOUND"), (True, "INVALID_DBN_FLAGS")):
            with self.subTest(flags=flags):
                gate = self.active_gate(max_quote_age_ns=10**9)
                current = gate.consume(quote(2, T+2, flags=flags))
                self.assertFalse(current.eligible)
                self.assertIsNone(current.quote)
                self.assertIn(reason, current.reasons)
                self.assertIn(reason, self.eligible(gate, now_ns=T+2).reasons)

    def test_last_is_not_required_and_book_gap_has_no_silent_recovery(self):
        gate = self.active_gate()
        trade = quote(2, T+2, action=ord("T"), flags=0)
        self.assertTrue(gate.consume(trade).eligible)
        self.assertTrue(self.eligible(gate, now_ns=T+2).eligible)
        self.assertFalse(gate.consume(quote(3, T+3, flags=4)).eligible)
        gate.consume(status(4, T+4))
        result = gate.consume(quote(5, T+5))
        self.assertFalse(result.eligible)
        self.assertIn("BOOK_GAP_QUARANTINE_REQUIRES_NEW_VERIFIED_STREAM", result.reasons)

    def test_unknown_nontrading_and_reopen_require_new_quote(self):
        gate = a.QuoteGate(max_quote_age_ns=10**9)
        self.assertIn("TRADING_STATUS_UNKNOWN", gate.consume(quote(0, T)).reasons)
        gate.consume(status(1, T+1))
        self.assertFalse(self.eligible(gate, now_ns=T+1).eligible)
        self.assertIn("ENABLING_STATUS_TIME_TIE", gate.consume(quote(2, T+1)).reasons)
        self.assertTrue(gate.consume(quote(3, T+2)).eligible)
        gate.consume(status(4, T+3, trading=False))
        self.assertIn("NON_TRADING_STATUS", self.eligible(gate, now_ns=T+3).reasons)
        self.assertFalse(gate.consume(quote(5, T+4)).eligible)
        gate.consume(status(6, T+5))
        self.assertFalse(self.eligible(gate, now_ns=T+5).eligible)
        self.assertTrue(gate.consume(quote(7, T+6)).eligible)

    def test_trading_flags_require_continuous_action_and_explicit_Y(self):
        for fields in ({"action": 6}, {"trading_indicator": ord("~")},
                       {"quoting_indicator": ord("N")}, {"trading_indicator": True}):
            gate = a.QuoteGate(max_quote_age_ns=0)
            gate.consume(status(**fields))
            self.assertIn("NON_TRADING_STATUS", gate.consume(quote()).reasons)

    def test_staleness_and_no_future_or_outside_window_execution(self):
        gate = self.active_gate(max_quote_age_ns=2, window_start_ns=T, window_end_ns=T+10)
        gate.consume(status(2, T+5))  # Repeat active status: existing quote has aged.
        self.assertIn("STALE_QUOTE", self.eligible(gate, now_ns=T+5).reasons)
        self.assertIn("REPLAY_CLOCK_NOT_AT_REQUEST", self.eligible(gate, now_ns=T+6).reasons)
        self.assertIn("QUOTE_FROM_FUTURE", self.eligible(gate, now_ns=T).reasons)
        self.assertIn("OUTSIDE_DATA_WINDOW", self.eligible(gate, now_ns=T+10).reasons)

    def test_bool_limits_identity_and_order_regressions_rejected(self):
        for value in (True, -1, 0.5):
            with self.assertRaises(a.ReplayError):
                a.QuoteGate(max_quote_age_ns=value)
        for fields in ({"instrument_id": ID+1}, {"replay_ordinal": 1}, {"ts_recv_ns": T-1}):
            gate = self.active_gate()
            with self.assertRaises(a.ReplayError):
                gate.consume(quote(2, T+2, **fields))
        gate = self.active_gate()
        with self.assertRaises(a.ReplayError):
            self.eligible(gate, quantity=True)

    def test_raw_source_equal_times_and_cross_chunk_order_are_retained(self):
        path, expected = self.source("mbp-1", [raw_quote(T+1, 8), raw_quote(T+1, 9), raw_quote(T+2, 10)])
        result = list(a.iter_source_records(path, "mbp-1", expected, chunk_records=1))
        self.assertEqual([x[0] for x in result], [0, 1, 2])
        self.assertEqual([x[2][13] for x in result], [8, 9, 10])
        self.assertEqual(result[0][2][11], result[1][2][11])
        self.assertNotEqual(result[0][1], result[1][1])

    def test_source_hash_truncation_and_receive_clock_regressions_fail(self):
        path, expected = self.source("mbp-1", [raw_quote(T+2), raw_quote(T+1)])
        with self.assertRaisesRegex(a.ReplayError, "SOURCE_RECEIVE_CLOCK_REGRESSION"):
            list(a.iter_source_records(path, "mbp-1", expected))
        path, expected = self.source("mbp-1", [raw_quote()])
        expected["file_sha256"] = "0"*64
        with self.assertRaisesRegex(a.ReplayError, "SOURCE_HASH_OR_COUNT_CHANGED"):
            list(a.iter_source_records(path, "mbp-1", expected))
        path.write_bytes(path.read_bytes()[:-1])
        expected["actual_file_bytes"] -= 1
        with self.assertRaisesRegex(a.ReplayError, "TRUNCATED_SOURCE_RECORD"):
            list(a.iter_source_records(path, "mbp-1", expected))

    def test_merge_tie_is_explicit_not_a_hidden_global_transport_order(self):
        qp, qe = self.source("mbp-1", [raw_quote(T), raw_quote(T), raw_quote(T+1)])
        sp, se = self.source("status", [raw_status(T)])
        events = list(a.merge_events(a.iter_source_records(qp, "mbp-1", qe),
                                     a.iter_source_records(sp, "status", se)))
        self.assertEqual([e.kind for e in events], ["status", "mbp-1", "mbp-1", "mbp-1"])
        self.assertEqual([e.replay_ordinal for e in events], [0, 1, 2, 3])
        self.assertEqual([e.source_ordinal for e in events if e.kind == "mbp-1"], [0, 1, 2])
        gate = a.QuoteGate(max_quote_age_ns=0)
        decisions = [gate.consume(e) for e in events]
        self.assertEqual([x.eligible for x in decisions], [False, False, False, True])

    def test_equal_time_equity_peak_breach_recovery_is_forwarded_to_actual_risk(self):
        from prop_risk import Rules, evaluate, timestamp_ns
        bridge = a.RiskMarkBridge()
        events = [quote(1, T+123456789), quote(2, T+123456789), quote(3, T+123456789)]
        points = [bridge.point(events[0], session="s", balance=50000, equity=51500, flat=False, traded=True),
                  bridge.point(events[1], session="s", balance=50000, equity=49000, flat=False),
                  bridge.point(events[2], session="s", balance=50000, equity=50000, end_of_session=True)]
        result = evaluate(iter(points), Rules(trailing_mode="intraday_equity"), retain_trace=False)
        self.assertEqual(result["evaluation_status"], "FAILED")
        self.assertEqual(result["breach"]["equity"], "49000")
        self.assertEqual(result["breach"]["replay_ordinal"], 1)
        self.assertEqual(result["point_count"], 3)
        self.assertEqual(len({timestamp_ns(p.timestamp) for p in points}), 1)
        self.assertEqual(timestamp_ns(points[0].timestamp), T+123456789)

    def test_same_market_event_accounting_phases_keep_fee_extreme_without_jitter(self):
        bridge = a.RiskMarkBridge()
        event = quote()
        first = bridge.point(event, session="s", balance=50000, equity=50000, phase=0)
        second = bridge.point(event, session="s", balance=49998, equity=49998, phase=1)
        self.assertEqual(first.timestamp, second.timestamp)
        self.assertEqual((first.replay_ordinal, second.replay_ordinal), (0, 1))
        self.assertEqual(bridge.last_binding["source_replay_ordinal"], event.replay_ordinal)
        with self.assertRaises(a.ReplayError):
            bridge.point(event, session="s", balance=50000, equity=50000, phase=1)

    def test_raw_adapter_native_parity_for_bound_first_1000_pilot_records(self):
        import pyarrow as pa
        source = Path("D:/QM/futures_lab/pilots/mesz6_20260916/mbp-1.dbn")
        evidence = Path("D:/QM/reports/research/futures_pivot_20260922/databento_native_sample_20260922.json")
        if not source.exists() or not evidence.exists():
            self.skipTest("Locally licensed, bound pilot sample unavailable")
        with source.open("rb") as handle:
            pre = handle.read(8)
            meta = pre + handle.read(struct.unpack_from("<I", pre, 4)[0])
            records = handle.read(80*1000)
        sample = meta+records
        previous = json.loads(evidence.read_text())
        self.assertEqual(v.sha(sample), previous["sample"]["raw_prefix_sha256"])
        path = self.root / "sample.dbn"
        path.write_bytes(sample)
        expected = {"actual_file_bytes": len(sample), "record_count": 1000,
                    "file_sha256": v.sha(sample), "instrument_id": str(ID), "publisher_ids": [1]}
        events = [a._event("mbp-1", row, i) for i, row in enumerate(a.iter_source_records(path, "mbp-1", expected))]
        v.no_reparse(v.SCRATCH_ROOT)
        v.SCRATCH_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="qm-adapter-parity-", dir=v.SCRATCH_ROOT) as folder:
            adapted = Path(folder) / "sample.dbn.zst"
            adapted.write_bytes(pa.compress(sample, codec="zstd").to_pybytes())
            native = v.make_loader().from_dbn_file(adapted, include_trades=True)
        cursor = 0
        for event in events:
            item = native[cursor]; cursor += 1
            self.assertEqual(type(item).__name__, "QuoteTick")
            self.assertEqual((str(item.instrument_id), item.ts_event, item.ts_init),
                             ("MESZ6.GLBX", event.ts_recv_ns, event.ts_recv_ns))
            self.assertEqual(item.bid_price.as_decimal()*10**9, event.bid_px_raw)
            self.assertEqual(item.ask_price.as_decimal()*10**9, event.ask_px_raw)
            self.assertEqual(item.bid_size.as_decimal(), event.bid_size)
            self.assertEqual(item.ask_size.as_decimal(), event.ask_size)
            if event.is_trade:
                item = native[cursor]; cursor += 1
                self.assertEqual(type(item).__name__, "TradeTick")
                self.assertEqual(item.price.as_decimal()*10**9, event.trade_price_raw)
                self.assertEqual(item.size.as_decimal(), event.trade_size)
                self.assertEqual(item.ts_event, event.ts_recv_ns)
        self.assertEqual(cursor, len(native))
        self.assertEqual(len(native), 1182)
        self.assertIn("CROSSED_BBO", a.bbo_reasons(events[0]))


if __name__ == "__main__":
    unittest.main()
