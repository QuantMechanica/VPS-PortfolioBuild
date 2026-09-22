"""Bounded, offline MESZ6 pilot replay; quote eligibility is not a fill model.

Both source timestamps and every source row are retained. Separate DBN schemas
have no shared transport order: merge by receive time, status first on ties, and
never let a same-time enabling status authorize a quote. No price repair, bars,
strategy, fees, orders, network or credentials are implemented here.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import struct

import validate_databento_pilot as validation

MBP = struct.Struct("<BBHIQqIBBBBQiIqqIIII")
STATUS = struct.Struct("<BBHIQQHHHBBB7x")
CHUNK_RECORDS = 8192
TICK_RAW = 250_000_000
UNDEF_PRICE = 2**63 - 1
# Nautilus v1.221.0 Cargo.lock pins dbn 0.43.0. These are upstream wire bits;
# excluding replay snapshots and unbound publisher-specific flags is our explicit
# conservative execution policy, not a claim that every snapshot book is wrong.
DBN_FLAGS_SOURCE = "https://raw.githubusercontent.com/databento/dbn/v0.43.0/rust/dbn/src/flags.rs"
DBN_LOCK_SOURCE = "https://raw.githubusercontent.com/nautechsystems/nautilus_trader/v1.221.0/Cargo.lock"
F_LAST, F_TOB, F_SNAPSHOT, F_MBP = 128, 64, 32, 16
F_BAD_TS_RECV, F_MAYBE_BAD_BOOK, F_PUBLISHER_SPECIFIC = 8, 4, 2


class ReplayError(ValueError):
    pass


def require(condition, code):
    if not condition:
        raise ReplayError(code)


def integer(value, label, minimum=0):
    require(type(value) is int and value >= minimum, label)
    return value


def utc_iso_ns(value):
    integer(value, "INVALID_TIMESTAMP")
    return (datetime.fromtimestamp(value // 10**9, timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
            + "." + str(value % 10**9).zfill(9) + "Z")


@dataclass(frozen=True, slots=True)
class ReplayEvent:
    kind: str
    replay_ordinal: int
    source_ordinal: int
    ts_recv_ns: int
    ts_exchange_ns: int
    instrument_id: int
    publisher_id: int
    source_sequence: int | None
    action: int
    side: int = 0
    flags: int = 0
    trade_price_raw: int | None = None
    trade_size: int = 0
    bid_px_raw: int | None = None
    ask_px_raw: int | None = None
    bid_size: int = 0
    ask_size: int = 0
    trading_indicator: int | None = None
    quoting_indicator: int | None = None
    raw_record: bytes = b""

    @property
    def is_trade(self):
        return self.kind == "mbp-1" and self.action == ord("T")


def _event(kind, record, replay_ordinal):
    source_ordinal, raw, row = record
    if kind == "mbp-1":
        return ReplayEvent(kind, replay_ordinal, source_ordinal, row[11], row[4], row[3], row[2],
                           row[13], row[7], row[8], row[9], row[5], row[6], row[14], row[15],
                           row[16], row[17], raw_record=raw)
    return ReplayEvent(kind, replay_ordinal, source_ordinal, row[5], row[4], row[3], row[2],
                       None, row[6], trading_indicator=row[9], quoting_indicator=row[10], raw_record=raw)


def iter_source_records(path, schema, expected, *, chunk_records=CHUNK_RECORDS):
    """All bytes hashed on exhaustion; never report completion for a prefix."""
    integer(chunk_records, "INVALID_CHUNK_SIZE", 1)
    require(chunk_records <= CHUNK_RECORDS, "CHUNK_SIZE_CAP")
    require(schema in ("mbp-1", "status"), "UNSUPPORTED_REPLAY_SCHEMA")
    decoder = MBP if schema == "mbp-1" else STATUS
    before = validation.fingerprint(path)
    require(before[0] == expected["actual_file_bytes"], "SOURCE_SIZE_CHANGED")
    digest = hashlib.sha256()
    count, previous_recv = 0, None
    with Path(path).open("rb") as handle:
        meta = validation.read_header(handle, digest)
        require(meta["schema_code"] == (1 if schema == "mbp-1" else 11), "SOURCE_SCHEMA_MISMATCH")
        while True:
            chunk = handle.read(chunk_records * decoder.size)
            if not chunk:
                break
            require(len(chunk) % decoder.size == 0, "TRUNCATED_SOURCE_RECORD")
            digest.update(chunk)
            for offset, row in enumerate(decoder.iter_unpack(chunk)):
                require(row[0] == decoder.size // 4
                        and row[1] == (0x01 if schema == "mbp-1" else 0x12), "SOURCE_FRAMING_MISMATCH")
                require(row[3] == int(expected["instrument_id"])
                        and row[2] in expected["publisher_ids"], "SOURCE_IDENTITY_MISMATCH")
                recv = row[11] if schema == "mbp-1" else row[5]
                require(0 < recv < 2**64-1 and (previous_recv is None or recv >= previous_recv),
                        "SOURCE_RECEIVE_CLOCK_REGRESSION")
                previous_recv = recv
                start = offset * decoder.size
                require(count < expected["record_count"], "SOURCE_RECORD_COUNT_EXCEEDED")
                yield count, chunk[start:start+decoder.size], row
                count += 1
    require(validation.fingerprint(path) == before, "SOURCE_CHANGED_DURING_REPLAY")
    require(count == expected["record_count"] and digest.hexdigest() == expected["file_sha256"],
            "SOURCE_HASH_OR_COUNT_CHANGED")


def merge_events(quotes, statuses):
    """Deterministic merge, not a claim of cross-schema exchange ordering."""
    statuses = iter(statuses)
    status = next(statuses, None)
    ordinal = 0
    for quote in quotes:
        while status is not None and status[2][5] <= quote[2][11]:
            yield _event("status", status, ordinal)
            ordinal += 1
            status = next(statuses, None)
        yield _event("mbp-1", quote, ordinal)
        ordinal += 1
    while status is not None:
        yield _event("status", status, ordinal)
        ordinal += 1
        status = next(statuses, None)


class PilotReplay:
    """Only the fixed, evidence-bound pilot is enabled in this implementation."""
    def __init__(self, *, quote_path, validation_path, data_root, status_reconciliation):
        self.data_root = Path(data_root)
        prior, self.validation_sha256 = validation.read_json(validation_path)
        require(prior.get("structural_status") == "PASS"
                and prior.get("all_requested_schemas_validated") is True,
                "COMPLETE_PILOT_VALIDATION_REQUIRED")
        fresh = validation.validate_pilot(quote_path, data_root, status_reconciliation=status_reconciliation)
        for field in ("quote_sha256", "quote_request_sha256", "definition_sha256", "symbol", "instrument_id",
                      "multiplier", "tick_size", "currency"):
            require(prior.get(field) == fresh[field], "VALIDATION_EVIDENCE_BINDING_MISMATCH")
        require(fresh["quote_sha256"] == validation.STATUS_RECONCILIATION_PINS["quote"], "OUTSIDE_FIXED_PILOT")
        fields = ("schema", "file_sha256", "actual_file_bytes", "record_count", "record_bytes")
        require([{k: r[k] for k in fields} for r in prior["files"]]
                == [{k: r[k] for k in fields} for r in fresh["files"]], "VALIDATION_FILE_BINDING_MISMATCH")
        require(prior["status_reconciliation"]["proof_sha256"] == fresh["status_reconciliation"]["proof_sha256"],
                "STATUS_RECONCILIATION_BINDING_MISMATCH")
        self.audit = fresh
        self.files = {r["schema"]: r for r in fresh["files"]}
        window = self.files["mbp-1"]["quoted_window"]
        self.start_ns, self.end_ns = validation.ns(window["start"]), validation.ns(window["end"])
        self.complete = False
        self.started = False

    def events(self):
        require(not self.started, "REPLAY_INSTANCE_IS_SINGLE_USE")
        self.started = True
        quotes = iter_source_records(self.data_root / "mbp-1.dbn", "mbp-1", self.files["mbp-1"])
        statuses = iter_source_records(self.data_root / "status.dbn", "status", self.files["status"])
        try:
            for event in merge_events(quotes, statuses):
                require(self.start_ns <= event.ts_recv_ns < self.end_ns, "EVENT_OUTSIDE_PILOT_WINDOW")
                yield event
            self.complete = True
        finally:
            quotes.close()
            statuses.close()


def bbo_reasons(event):
    reasons = []
    bid, ask = event.bid_px_raw, event.ask_px_raw
    bid_present, ask_present = type(bid) is int and bid != UNDEF_PRICE, type(ask) is int and ask != UNDEF_PRICE
    if not bid_present:
        reasons.append("MISSING_BID")
    elif bid <= 0:
        reasons.append("NONPOSITIVE_BID")
    elif bid % TICK_RAW:
        reasons.append("BID_OFF_TICK")
    if not ask_present:
        reasons.append("MISSING_ASK")
    elif ask <= 0:
        reasons.append("NONPOSITIVE_ASK")
    elif ask % TICK_RAW:
        reasons.append("ASK_OFF_TICK")
    if type(event.bid_size) is not int or event.bid_size <= 0:
        reasons.append("ZERO_OR_INVALID_BID_SIZE")
    if type(event.ask_size) is not int or event.ask_size <= 0:
        reasons.append("ZERO_OR_INVALID_ASK_SIZE")
    if bid_present and ask_present:
        if bid == ask:
            reasons.append("LOCKED_BBO")
        elif bid > ask:
            reasons.append("CROSSED_BBO")
    return tuple(reasons)


def data_quality_reasons(flags):
    if type(flags) is not int or not 0 <= flags <= 255:
        return ("INVALID_DBN_FLAGS",)
    reasons = []
    for bit, reason in ((F_BAD_TS_RECV, "DBN_BAD_TS_RECV"),
                        (F_MAYBE_BAD_BOOK, "DBN_MAYBE_BAD_BOOK"),
                        (F_SNAPSHOT, "DBN_SNAPSHOT_NOT_FRESH_EXECUTION"),
                        (F_PUBLISHER_SPECIFIC, "DBN_PUBLISHER_SPECIFIC_UNBOUND"),
                        (1, "DBN_RESERVED_FLAG_UNBOUND")):
        if flags & bit:
            reasons.append(reason)
    return tuple(reasons)


@dataclass(frozen=True, slots=True)
class QuoteDecision:
    eligible: bool
    reasons: tuple[str, ...]
    quote: ReplayEvent | None = None
    price_raw: int | None = None
    displayed_size: int | None = None


class QuoteGate:
    """Explicit eligibility only: no fills, liquidity reuse model or cost claims."""
    def __init__(self, *, max_quote_age_ns, window_start_ns=None, window_end_ns=None, instrument_id=42001581):
        self.max_quote_age_ns = integer(max_quote_age_ns, "INVALID_MAX_QUOTE_AGE")
        self.instrument_id = integer(instrument_id, "INVALID_INSTRUMENT_ID", 1)
        require((window_start_ns is None) == (window_end_ns is None), "INCOMPLETE_WINDOW")
        if window_start_ns is not None:
            require(integer(window_start_ns, "INVALID_WINDOW") < integer(window_end_ns, "INVALID_WINDOW"), "INVALID_WINDOW")
        self.window_start_ns, self.window_end_ns = window_start_ns, window_end_ns
        self._ordinal, self._clock = -1, None
        self._status = None
        self._trading = False
        self._enabled_at = None
        self._quote = None
        self._last_quote_reasons = ("NO_QUOTE",)
        self._book_quarantined = False

    def consume(self, event):
        integer(event.replay_ordinal, "INVALID_REPLAY_ORDINAL")
        integer(event.ts_recv_ns, "INVALID_RECEIVE_TIME", 1)
        require(type(event.instrument_id) is int and event.instrument_id == self.instrument_id, "GATE_INSTRUMENT_MISMATCH")
        require(event.replay_ordinal > self._ordinal
                and (self._clock is None or event.ts_recv_ns >= self._clock), "EVENT_ORDER_REGRESSION")
        self._ordinal, self._clock = event.replay_ordinal, event.ts_recv_ns
        if event.kind == "status":
            was_trading = self._trading
            self._status = event
            self._trading = (type(event.action) is int and event.action == 7
                             and type(event.trading_indicator) is int and event.trading_indicator == ord("Y")
                             and type(event.quoting_indicator) is int and event.quoting_indicator == ord("Y"))
            if not self._trading or not was_trading:
                self._quote = None
                self._last_quote_reasons = ("FRESH_QUOTE_REQUIRED_AFTER_STATUS",)
            if self._trading and not was_trading:
                self._enabled_at = event.ts_recv_ns
            return QuoteDecision(False, ("STATUS_EVENT_NOT_QUOTE",)
                                 + (() if self._trading else ("NON_TRADING_STATUS",)))
        require(event.kind == "mbp-1", "UNSUPPORTED_EVENT_KIND")
        reasons = list(bbo_reasons(event))
        reasons.extend(data_quality_reasons(event.flags))
        if type(event.flags) is int and event.flags & F_MAYBE_BAD_BOOK:
            self._book_quarantined = True
        if self._book_quarantined:
            reasons.append("BOOK_GAP_QUARANTINE_REQUIRES_NEW_VERIFIED_STREAM")
        if event.is_trade:
            if (type(event.trade_price_raw) is not int or event.trade_price_raw <= 0
                    or event.trade_price_raw == UNDEF_PRICE or event.trade_price_raw % TICK_RAW):
                reasons.append("INVALID_TRADE_EVENT_PRICE")
            if type(event.trade_size) is not int or event.trade_size <= 0:
                reasons.append("INVALID_TRADE_EVENT_SIZE")
        if self._status is None:
            reasons.append("TRADING_STATUS_UNKNOWN")
        elif not self._trading:
            reasons.append("NON_TRADING_STATUS")
        elif event.ts_recv_ns <= self._enabled_at:
            reasons.append("ENABLING_STATUS_TIME_TIE")
        if self.window_start_ns is not None and not self.window_start_ns <= event.ts_recv_ns < self.window_end_ns:
            reasons.append("OUTSIDE_DATA_WINDOW")
        # A bad new quote invalidates the old candidate. Never fall back to a
        # previously valid BBO across crossed/missing quotes or a trading halt.
        self._last_quote_reasons = tuple(reasons)
        self._quote = None if reasons else event
        return QuoteDecision(not reasons, tuple(reasons), self._quote)

    def execution_quote(self, now_ns, side, quantity, *, after_ordinal, eligible_at_ns):
        integer(now_ns, "INVALID_EXECUTION_TIME")
        integer(eligible_at_ns, "INVALID_LATENCY_TIME")
        integer(after_ordinal, "INVALID_DECISION_ORDINAL", -1)
        integer(quantity, "INVALID_QUANTITY", 1)
        require(side in ("BUY", "SELL"), "INVALID_ORDER_SIDE")
        reasons = []
        if self._clock is None or now_ns != self._clock:
            reasons.append("REPLAY_CLOCK_NOT_AT_REQUEST")
        if now_ns < eligible_at_ns:
            reasons.append("LATENCY_NOT_ELAPSED")
        if self.window_start_ns is not None and not self.window_start_ns <= now_ns < self.window_end_ns:
            reasons.append("OUTSIDE_DATA_WINDOW")
        if self._status is None:
            reasons.append("TRADING_STATUS_UNKNOWN")
        elif not self._trading:
            reasons.append("NON_TRADING_STATUS")
        quote = self._quote
        if quote is None:
            reasons.extend(self._last_quote_reasons or ("NO_QUOTE",))
            return QuoteDecision(False, tuple(dict.fromkeys(reasons)))
        if now_ns < quote.ts_recv_ns:
            reasons.append("QUOTE_FROM_FUTURE")
        elif now_ns - quote.ts_recv_ns > self.max_quote_age_ns:
            reasons.append("STALE_QUOTE")
        if quote.ts_recv_ns < eligible_at_ns:
            reasons.append("QUOTE_PRECEDES_LATENCY")
        if quote.replay_ordinal <= after_ordinal:
            reasons.append("QUOTE_NOT_AFTER_DECISION")
        price, displayed = ((quote.ask_px_raw, quote.ask_size) if side == "BUY"
                            else (quote.bid_px_raw, quote.bid_size))
        if quantity > displayed:
            reasons.append("INSUFFICIENT_DISPLAYED_SIZE")
        return QuoteDecision(not reasons, tuple(dict.fromkeys(reasons)), quote if not reasons else None,
                             price if not reasons else None, displayed if not reasons else None)


class RiskMarkBridge:
    """Forward every NET-equity observation, including same-time/sub-event extrema.

    Accounting is supplied by the caller. No equity or price is interpolated.
    Risk ordinals count accounting marks; source replay ordinal + phase are kept
    separately so fees/fills within one market event need no timestamp jitter.
    """
    def __init__(self):
        self.count = 0
        self._key = None
        self._time = None
        self.last_binding = None

    def point(self, event, *, session, balance, equity, end_of_session=False,
              traded=False, flat=True, phase=0):
        from prop_risk import Point, money
        integer(phase, "INVALID_ACCOUNTING_PHASE")
        integer(event.replay_ordinal, "INVALID_REPLAY_ORDINAL")
        key = (event.replay_ordinal, phase)
        require(self._key is None or key > self._key, "ACCOUNTING_SOURCE_ORDER_REGRESSION")
        require(self._time is None or event.ts_recv_ns >= self._time, "ACCOUNTING_TIME_REGRESSION")
        net_balance, net_equity = money(balance), money(equity)
        require(not flat or net_balance == net_equity, "FLAT_MARK_MUST_EQUAL_BALANCE")
        point = Point(utc_iso_ns(event.ts_recv_ns), session, net_balance, net_equity,
                      end_of_session, traded, flat, replay_ordinal=self.count)
        self.last_binding = {"risk_ordinal": self.count, "source_replay_ordinal": event.replay_ordinal,
                             "source_ordinal": event.source_ordinal, "phase": phase,
                             "ts_recv_ns": event.ts_recv_ns, "ts_exchange_ns": event.ts_exchange_ns}
        self.count += 1
        self._key, self._time = key, event.ts_recv_ns
        return point


def technical_replay(replay):
    """Visit all events, count eligibility and hash order; never place a trade."""
    gate = QuoteGate(max_quote_age_ns=0, window_start_ns=replay.start_ns, window_end_ns=replay.end_ns)
    counts, rejected, actions = Counter(), Counter(), Counter()
    flag_counts = Counter()
    digest = hashlib.sha256()
    previous_time = None
    equal_time = 0
    examples = []
    for event in replay.events():
        decision = gate.consume(event)
        counts[event.kind] += 1
        counts["all_events"] += 1
        if event.ts_recv_ns == previous_time:
            equal_time += 1
        previous_time = event.ts_recv_ns
        # The raw bytes include both timestamps, flags, sizes and source sequence.
        digest.update(struct.pack("<BQQ", 1 if event.kind == "mbp-1" else 2,
                                  event.replay_ordinal, event.source_ordinal))
        digest.update(event.raw_record)
        if event.kind == "mbp-1":
            actions[str(event.action)] += 1
            flag_counts[str(event.flags)] += 1
            counts["raw_trade_records"] += int(event.is_trade)
            if decision.eligible:
                counts["eligible_quote_events"] += 1
                counts["eligible_trade_signal_records"] += int(event.is_trade)
            else:
                counts["excluded_quote_events"] += 1
                counts["excluded_trade_signal_records"] += int(event.is_trade)
                rejected.update(decision.reasons)
                if len(examples) < 12:
                    examples.append({"replay_ordinal": event.replay_ordinal,
                                     "source_ordinal": event.source_ordinal,
                                     "ts_recv_ns": event.ts_recv_ns, "ts_exchange_ns": event.ts_exchange_ns,
                                     "bid_px_raw": event.bid_px_raw, "ask_px_raw": event.ask_px_raw,
                                     "action": event.action, "reasons": list(decision.reasons)})
            digest.update(bytes([int(decision.eligible)]))
    require(replay.complete, "REPLAY_NOT_EXHAUSTED")
    return {"schema": "qm.futures-technical-replay/v1", "status": "TECHNICAL_REPLAY_COMPLETE",
            "symbol": "MESZ6", "price_scale": 10**9, "counts": dict(counts),
            "excluded_quote_reason_counts": dict(rejected), "excluded_quote_examples": examples,
            "raw_action_byte_counts": dict(actions), "equal_receive_time_events_retained": equal_time,
            "raw_flag_byte_counts": dict(flag_counts),
            "ordered_event_and_eligibility_sha256": digest.hexdigest(),
            "eligibility_policy": {"max_quote_age_ns": 0, "mode": "FRESH_EVENT_ONLY_TECHNICAL_DIAGNOSTIC",
                                   "continuous_trading": "status action7 AND is_trading Y AND is_quoting Y",
                                   "cross_schema_tie": "status first; enabling status cannot authorize a same-time quote",
                                   "dbn_flags_source": DBN_FLAGS_SOURCE, "native_dependency_lock_source": DBN_LOCK_SOURCE,
                                   "flag_policy": "Reject BAD_TS_RECV, MAYBE_BAD_BOOK, SNAPSHOT, unbound publisher/reserved flags; MAYBE_BAD_BOOK quarantines this gate. LAST is not required."},
            "validation_report_sha256": replay.validation_sha256,
            "quote_sha256": replay.audit["quote_sha256"],
            "source_file_hashes": {s: row["file_sha256"] for s, row in replay.files.items()},
            "source_files_unchanged_and_complete": True,
            "economic_result": "NOT_RUN", "orders_submitted": 0, "network_requests": 0,
            "limitations": ["Eligibility does not manufacture fills, queue position, fees or tradable depth beyond displayed BBO.",
                            "No shared transport order exists across the separately requested status and MBP files; the conservative merge is explicit.",
                            "Definitions and exact-file status reconciliation are validated before replay; no general discrepancy tolerance is applied.",
                            "No strategy, calendar/news certification, profitability or provider qualification is claimed."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quote", type=Path, required=True)
    parser.add_argument("--validation", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--status-reconciliation", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        validation.no_reparse(args.output)
        require(not args.output.exists(), "OUTPUT_ALREADY_EXISTS")
        replay = PilotReplay(quote_path=args.quote, validation_path=args.validation,
                             data_root=args.data_root, status_reconciliation=args.status_reconciliation)
        result = technical_replay(replay)
        result["adapter_sha256"] = validation.sha(Path(__file__).read_bytes())
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8") as handle:
            json.dump(result, handle, indent=2, allow_nan=False)
            handle.write("\n")
        print(json.dumps({"status": result["status"], "counts": result["counts"],
                          "ordered_event_and_eligibility_sha256": result["ordered_event_and_eligibility_sha256"]}))
        return 0
    except (ReplayError, validation.ValidationError) as exc:
        print("REPLAY_BLOCKED " + str(exc))
        return 2
    except Exception:
        print("REPLAY_BLOCKED LOCAL_INPUT_OR_ADAPTER_ERROR")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
