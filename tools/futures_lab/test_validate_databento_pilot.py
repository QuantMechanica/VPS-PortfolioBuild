"""Offline regression checks; no credentials, endpoints or paid data needed."""
from __future__ import annotations

from copy import deepcopy
from decimal import Decimal
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import validate_databento_pilot as v


START = "2026-09-15T22:00:00+00:00"
END = "2026-09-16T21:00:00+00:00"
T = v.ns(START) + 1_000_000_000
ID = 42001581


def header(schema="mbp-1", version=3):
    meta = bytearray(198)
    meta[:9] = b"GLBX.MDP3"
    struct.pack_into("<H", meta, 16, {"mbp-1": 1, "definition": 9, "status": 11}[schema])
    return b"DBN" + bytes([version]) + struct.pack("<I", len(meta)) + meta


def mbp(ts=T, instrument_id=ID, bid=6000_000_000_000, ask=6000_250_000_000,
        bid_size=3, sequence=7):
    raw = bytearray(80)
    struct.pack_into("<BBHIQ", raw, 0, 20, 1, 1, instrument_id, ts-100)
    struct.pack_into("<qIBBBBQiIqqIIII", raw, 16, ask, 1, ord("A"), ord("B"), 128,
                     0, ts, 100, sequence, bid, ask, bid_size, 4, 1, 1)
    return bytes(raw)


def definition(ts=T):
    # Deliberately only a common header: fake economics are supplied by a stub.
    # A separate official-fixture test checks real wire framing and decoder use.
    return struct.pack("<BBHIQQ8x", 8, 0x13, 1, ID, ts-100, ts)


def status(ts=T):
    return struct.pack("<BBHIQQHHHBBB7x", 10, 0x12, 1, ID, ts-100, ts, 3, 0, 0,
                       ord("Y"), ord("Y"), ord("N"))


def instrument(**changes):
    from nautilus_trader.model.currencies import USD
    from nautilus_trader.model.enums import AssetClass
    from nautilus_trader.model.identifiers import InstrumentId, Symbol
    from nautilus_trader.model.instruments import FuturesContract
    from nautilus_trader.model.objects import Price, Quantity
    fields = dict(instrument_id=InstrumentId.from_str("MESZ6.GLBX"), raw_symbol=Symbol("MESZ6"),
                  asset_class=AssetClass.INDEX, currency=USD, price_precision=2,
                  price_increment=Price.from_str("0.25"), multiplier=Quantity.from_int(5),
                  lot_size=Quantity.from_int(1), underlying="MES", exchange="XCME",
                  activation_ns=v.ns("2025-01-01T00:00:00Z"),
                  expiration_ns=v.ns("2026-12-18T14:30:00Z"), ts_event=T, ts_init=T)
    fields.update(changes)
    return FuturesContract(**fields)


class StubLoader:
    """Never accesses credentials/network and never overrides decoded identity."""
    def __init__(self, items=None):
        self._pyo3_loader = self
        self.items = items if items is not None else [instrument(), instrument()]
        self.full_load_calls = 0

    def schema_for_file(self, path):
        import pyarrow as pa
        with pa.input_stream(path, compression="zstd") as stream:
            prefix = stream.read(26)
        return {1: "mbp-1", 9: "definition", 11: "status"}[struct.unpack_from("<H", prefix, 24)[0]]

    def from_dbn_file(self, path):
        self.full_load_calls += 1
        if self.schema_for_file(str(path)) != "definition":
            raise AssertionError("Large-schema list decoding is forbidden")
        return self.items


class ValidatorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.scratch_patch = patch.object(v, "SCRATCH_ROOT", self.root / "scratch")
        self.scratch_patch.start()
        self.addCleanup(self.scratch_patch.stop)
        self.addCleanup(self.temp.cleanup)

    def quoted_row(self, schema, count, record_bytes):
        return {"schema": schema, "record_count": count, "billable_uncompressed_bytes": record_bytes,
                "start": START, "end": END}

    def scan(self, raw, *, count=1, record_bytes=None, schema="mbp-1", chunks=1):
        path = self.root / (schema + ".dbn")
        path.write_bytes(raw)
        sizes = {"mbp-1": 80, "status": 40, "definition": 32}
        row = self.quoted_row(schema, count, sizes[schema] * count if record_bytes is None else record_bytes)
        return v.scan_dbn(path, schema, row, ID, chunk_records=chunks)

    def inputs(self):
        payloads = {"definition": definition() * 2, "mbp-1": mbp() + mbp(T+1) + mbp(T+2),
                    "status": status() + status(T+2)}
        rows = [self.quoted_row(s, {"definition": 2, "mbp-1": 3, "status": 2}[s], len(payloads[s]))
                for s in v.SCHEMAS]
        req = {"dataset": "GLBX.MDP3", "symbol": "MESZ6", "stype_in": "raw_symbol",
               "schemas": list(v.SCHEMAS), "start": START, "end": END,
               "schema_windows": {s: {"start": START, "end": END} for s in v.SCHEMAS},
               "local_storage_budget_bytes": 2**20}
        quote = {"schema": "qm.databento-quote/v1", "classification": "QUOTE_ONLY",
                 "status": "WITHIN_QUOTE_LIMITS", "request": req, "request_sha256": v.sha(v.canonical_bytes(req)),
                 "resolution": {"status": "FULL_DATE_COVERAGE_ONE_ID", "instrument_id": str(ID)},
                 "quotes": rows, "blockers": []}
        quote_path = self.root / "quote.json"
        quote_path.write_text(json.dumps(quote), encoding="utf-8")
        for schema in v.SCHEMAS:
            raw = header(schema) + payloads[schema]
            (self.root / (schema + ".dbn")).write_bytes(raw)
            receipt = {"status": "COMPLETE", "schema": schema, "file_sha256": v.sha(raw),
                       "actual_file_bytes": len(raw), "quote_sha256": v.sha(quote_path.read_bytes()),
                       "quote_request_sha256": quote["request_sha256"]}
            (self.root / (schema + ".attempt.json")).write_text(json.dumps(receipt), encoding="utf-8")
        return quote_path, quote

    def reconciliation_inputs(self):
        """Synthetic exact-file case; production pins are patched ONLY in tests."""
        quote_path, quote = self.inputs()
        quote["quotes"][2].update(record_count=12, billable_uncompressed_bytes=480)
        quote_path.write_text(json.dumps(quote), encoding="utf-8")
        quote_sha = v.sha(quote_path.read_bytes())

        def file_bytes(records, start, end):
            meta = bytearray(header("status")[8:])
            meta.extend(b"\0" * (352-len(meta)))
            struct.pack_into("<Q", meta, 18, v.ns(start))
            struct.pack_into("<Q", meta, 26, v.ns(end))
            return b"DBN\x03" + struct.pack("<I", len(meta)) + meta + b"".join(records)

        d0 = v.ns("2026-09-15T00:00:00Z")
        d1 = v.ns("2026-09-16T00:00:00Z")
        day_records = [
            [status(d0+i*3600*10**9) for i in range(4)] + [status(v.ns(START)+100), status(v.ns(START)+200)],
            [status(d1)] + [status(v.ns(END)+i*60*10**9) for i in range(1, 6)],
        ]
        original = file_bytes(day_records[0][-2:] + day_records[1][:1], START, END)
        (self.root / "status.dbn").write_bytes(original)
        days = []
        pins = {"quote": quote_sha, "original": v.sha(original)}
        folder = self.root / "status_utc_day_diagnostic"
        folder.mkdir(exist_ok=True)
        for records, (label, start, end) in zip(day_records, v.STATUS_DAY_WINDOWS):
            payload = file_bytes(records, start, end)
            path = folder / (label + ".status.dbn")
            path.write_bytes(payload)
            pins[label] = v.sha(payload)
            days.append({"label": label, "params": {"dataset": "GLBX.MDP3", "symbols": "MESZ6",
                         "schema": "status", "stype_in": "raw_symbol", "stype_out": "instrument_id",
                         "start": start, "end": end}, "status": "COMPLETE", "http_status": 200,
                         "path": str(path), "file_sha256": v.sha(payload), "file_bytes": 600,
                         "metadata_bytes": 360, "record_bytes": 240, "quote_billable_bytes": 240,
                         "quote_record_count": 6, "actual_record_count": 6})
        proof = {"schema": "qm.databento-status-utc-day-reconciliation/v1",
                 "status": "MATCHED_FOR_THESE_EXACT_FILES", "original_quote_sha256": quote_sha,
                 "original_status_sha256": v.sha(original), "original_quote_record_count": 12,
                 "original_actual_record_count": 3, "original_metadata_bytes": 360,
                 "original_window_reconstructed_count": 3,
                 "original_record_bytes_equal_in_order_without_deduplication": True, "days": days,
                 "comparisons": [{"label": label, "start": start, "end": end,
                    "record_count_quote": 6, "billable_size_quote": 240,
                    "actual_reconstructed_record_count": count}
                    for label, start, end, count, _ in v.STATUS_MICRO_WINDOWS]}
        proof_path = self.root / "reconciliation.json"
        proof_path.write_text(json.dumps(proof))
        for schema in v.SCHEMAS:
            path = self.root / (schema + ".attempt.json")
            receipt = json.loads(path.read_text())
            payload = (self.root / (schema + ".dbn")).read_bytes()
            receipt.update(quote_sha256=quote_sha, file_sha256=v.sha(payload), actual_file_bytes=len(payload))
            path.write_text(json.dumps(receipt))
        return quote_path, quote, proof_path, proof, pins

    def test_definition_proof_is_available_before_market_files_and_exactly_bound(self):
        path, quote = self.inputs()
        for schema in ("mbp-1", "status"):
            (self.root / (schema + ".dbn")).unlink()
            (self.root / (schema + ".attempt.json")).unlink()
        result = v.validate_pilot(path, self.root, definitions_only=True, loader=StubLoader())
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["instrument_id"], str(ID))
        self.assertEqual(result["definition_sha256"], v.sha((self.root / "definition.dbn").read_bytes()))
        self.assertEqual(result["quote_sha256"], v.sha(path.read_bytes()))
        self.assertEqual((result["symbol"], result["multiplier"], result["tick_size"], result["currency"]),
                         ("MESZ6", "5", "0.25", "USD"))
        self.assertFalse(result["all_requested_schemas_validated"])
        self.assertEqual(list((self.root / "scratch").iterdir()), [])

    def test_full_scan_uses_no_quote_or_status_object_list(self):
        path, _ = self.inputs()
        loader = StubLoader()
        result = v.validate_pilot(path, self.root, loader=loader)
        self.assertEqual(result["status"], "TECHNICAL_PASS")
        self.assertEqual(loader.full_load_calls, 1)
        self.assertEqual(sum(x["record_count"] for x in result["files"]), 7)
        self.assertTrue(all(x["all_records_scanned"] for x in result["files"]))

    def test_false_or_incomplete_or_wrong_quote_receipt_never_passes(self):
        for change in ({"status": "ATTEMPT_RESERVED"}, {"status": True},
                       {"quote_sha256": "0"*64}, {"quote_request_sha256": "0"*64},
                       {"schema": "status"}, {"actual_file_bytes": True}, {"file_sha256": "0"*64}):
            with self.subTest(change=change):
                path, _ = self.inputs()
                receipt_path = self.root / "definition.attempt.json"
                receipt = json.loads(receipt_path.read_text())
                receipt.update(change)
                receipt_path.write_text(json.dumps(receipt))
                with self.assertRaises(v.ValidationError):
                    v.validate_pilot(path, self.root, definitions_only=True, loader=StubLoader())

    def test_part_file_never_substitutes_for_complete_dbn(self):
        path, _ = self.inputs()
        source = self.root / "definition.dbn"
        source.rename(self.root / "definition.dbn.part")
        with self.assertRaises(FileNotFoundError):
            v.validate_pilot(path, self.root, definitions_only=True, loader=StubLoader())

    def test_contract_economics_identity_and_lifetime_are_not_overridden(self):
        from nautilus_trader.model.objects import Price, Quantity
        from nautilus_trader.model.currencies import EUR
        from nautilus_trader.model.identifiers import InstrumentId, Symbol
        changes = [dict(multiplier=Quantity.from_int(50)), dict(price_increment=Price.from_str("0.50")),
                   dict(currency=EUR), dict(instrument_id=InstrumentId.from_str("MESZ6.XCME")),
                   dict(raw_symbol=Symbol("ESZ6")), dict(activation_ns=v.ns(END)),
                   dict(expiration_ns=v.ns(START))]
        for change in changes:
            with self.subTest(change=change):
                with self.assertRaises(v.ValidationError):
                    v.verify_definitions([instrument(**change)], 1, v.ns(START), v.ns(END))
        with self.assertRaises(v.ValidationError):
            v.verify_definitions([object()], 1, v.ns(START), v.ns(END))
        with self.assertRaises(v.ValidationError):
            v.verify_definitions([], 1, v.ns(START), v.ns(END))

    def test_malformed_header_framing_identity_and_count_are_blocked(self):
        bad_record_length = bytearray(mbp()); bad_record_length[0] = 19
        bad_rtype = bytearray(mbp()); bad_rtype[1] = 0x12
        cases = [b"DBN", b"DBN\x04" + b"\0"*4, b"DBN\x03" + struct.pack("<I", 2**24),
                 header()[:-1], header() + mbp()[:-1], header() + bad_record_length,
                 header() + bad_rtype, header() + mbp(instrument_id=ID+1), header()]
        for raw in cases:
            with self.subTest(length=len(raw)):
                with self.assertRaises(v.ValidationError):
                    self.scan(raw)
        with self.assertRaisesRegex(v.ValidationError, "RECORD_COUNT_EXCEEDED"):
            self.scan(header() + mbp()*2)
        with self.assertRaisesRegex(v.ValidationError, "RECORD_BYTES_MISMATCH"):
            self.scan(header() + mbp(), record_bytes=81)

    def test_cross_chunk_equal_timestamps_are_retained_backsteps_reported(self):
        report = self.scan(header() + mbp(T, sequence=5) + mbp(T, sequence=6) + mbp(T-1, sequence=1), count=3)
        self.assertEqual(report["record_count"], 3)
        self.assertEqual(report["timestamps"]["ts_recv"]["equal_adjacent"], 1)
        self.assertEqual(report["timestamps"]["ts_recv"]["backsteps"], 1)
        self.assertEqual(report["quality_counts"]["sequence_backsteps_or_resets"], 1)
        self.assertEqual(report["quality_counts"]["usable_two_sided_positive_unlocked_on_tick_bbo"], 3)

    def test_missing_crossed_locked_offtick_and_out_of_window_are_explicit(self):
        raw = header() + mbp(bid=v.UNDEF_PRICE, bid_size=0) + mbp(bid=6001_000_000_000)
        raw += mbp(bid=6000_250_000_000) + mbp(v.ns(END), bid=6000_000_000_001)
        report = self.scan(raw, count=4)
        quality = report["quality_counts"]
        for key in ("missing_bid_price", "zero_bid_size", "crossed_bbo", "locked_bbo", "bid_off_tick"):
            self.assertEqual(quality[key], 1)
        self.assertEqual(report["timestamps"]["ts_recv"]["outside_query_window"], 1)
        self.assertEqual(quality["usable_two_sided_positive_unlocked_on_tick_bbo"], 0)
        self.assertIn("mbp-1:crossed_bbo", v.review_flags([report]))

    def test_status_fields_are_not_discarded(self):
        report = self.scan(header("status") + status(), schema="status")
        row = report["status_records"][0]
        self.assertEqual((row["action"], row["is_trading"], row["is_quoting"]), (3, ord("Y"), ord("Y")))
        self.assertEqual(row["ts_recv"], T)

    def test_total_file_bytes_cannot_mask_status_record_count_discrepancy(self):
        meta = bytearray(header("status")[8:])
        meta.extend(b"\0" * (352-len(meta)))
        raw = b"DBN\x03" + struct.pack("<I", len(meta)) + meta + status()*3
        self.assertEqual(len(raw), 480)  # coincidentally equals 12 * 40 quoted bytes
        with self.assertRaisesRegex(v.ValidationError, "RECORD_COUNT_MISMATCH"):
            self.scan(raw, schema="status", count=12, record_bytes=480)

    def test_modified_quote_hash_unknown_and_duplicate_schema_fail(self):
        _, quote = self.inputs()
        quote["request"]["symbol"] = "ESZ6"
        with self.assertRaisesRegex(v.ValidationError, "QUOTE_REQUEST_HASH_MISMATCH"):
            v.validate_quote(quote)
        _, quote = self.inputs()
        quote["quotes"][1]["schema"] = "definition"
        with self.assertRaisesRegex(v.ValidationError, "INCOMPLETE_SCHEMA_QUOTES"):
            v.validate_quote(quote)
        _, quote = self.inputs()
        quote["quotes"][1]["record_count"] = True
        with self.assertRaises(v.ValidationError):
            v.validate_quote(quote)

    def test_reconciliation_requires_optional_proof_and_preserves_original_quote(self):
        path, quote, proof_path, _, pins = self.reconciliation_inputs()
        with patch.object(v, "STATUS_RECONCILIATION_PINS", pins):
            with self.assertRaisesRegex(v.ValidationError, "RECORD_COUNT_MISMATCH"):
                v.validate_pilot(path, self.root, loader=StubLoader())
            result = v.validate_pilot(path, self.root, loader=StubLoader(), status_reconciliation=proof_path)
        self.assertEqual(result["status"], "TECHNICAL_PASS")
        row = next(s for s in result["files"] if s["schema"] == "status")
        self.assertEqual((row["record_count"], row["record_bytes"]), (3, 120))
        self.assertEqual((row["quoted_record_count"], row["quoted_billable_uncompressed_bytes"]), (12, 480))
        self.assertEqual(result["status_reconciliation"]["original_quote"], quote["quotes"][2])
        self.assertFalse(result["status_reconciliation"]["general_vendor_rounding_semantics_inferred"])
        self.assertEqual(json.loads(path.read_text()), quote)

    def test_synthetic_self_consistent_proof_cannot_bypass_production_exact_file_pins(self):
        path, _, proof_path, _, _ = self.reconciliation_inputs()
        with self.assertRaisesRegex(v.ValidationError, "RECORD_COUNT_MISMATCH"):
            v.validate_pilot(path, self.root, loader=StubLoader(), status_reconciliation=proof_path)

    def test_reconciliation_tampered_proof_counts_flags_paths_and_windows_fail_closed(self):
        mutations = [
            lambda p: p.update(original_quote_sha256="0"*64),
            lambda p: p.update(original_status_sha256="0"*64),
            lambda p: p.update(original_record_bytes_equal_in_order_without_deduplication=1),
            lambda p: p.update(original_window_reconstructed_count=4),
            lambda p: p["days"][0].update(actual_record_count=True),
            lambda p: p["days"][0].update(quote_billable_bytes=241),
            lambda p: p["days"][0].update(metadata_bytes=359),
            lambda p: p["days"][0].update(path=str(self.root / "status.dbn")),
            lambda p: p["days"][0]["params"].update(end=END),
            lambda p: p["days"].reverse(),
            lambda p: p["comparisons"][1].update(actual_reconstructed_record_count=1),
            lambda p: p["comparisons"][1].update(billable_size_quote=40),
            lambda p: p["comparisons"][2].update(start="2026-09-16T00:00:01Z"),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                path, _, proof_path, proof, pins = self.reconciliation_inputs()
                mutate(proof)
                proof_path.write_text(json.dumps(proof))
                with patch.object(v, "STATUS_RECONCILIATION_PINS", pins):
                    with self.assertRaisesRegex(v.ValidationError, "RECORD_COUNT_MISMATCH"):
                        v.validate_pilot(path, self.root, loader=StubLoader(), status_reconciliation=proof_path)

    def test_reconciliation_rehashing_changed_day_does_not_bypass_pins(self):
        path, _, proof_path, proof, pins = self.reconciliation_inputs()
        day_path = Path(proof["days"][0]["path"])
        raw = bytearray(day_path.read_bytes()); raw[-1] ^= 1
        day_path.write_bytes(raw)
        proof["days"][0]["file_sha256"] = v.sha(raw)
        proof_path.write_text(json.dumps(proof))
        with patch.object(v, "STATUS_RECONCILIATION_PINS", pins):
            with self.assertRaisesRegex(v.ValidationError, "RECORD_COUNT_MISMATCH"):
                v.validate_pilot(path, self.root, loader=StubLoader(), status_reconciliation=proof_path)

    def test_reconciliation_checks_raw_order_not_only_counts_and_prices(self):
        _, quote, proof_path, proof, pins = self.reconciliation_inputs()
        path = self.root / "status.dbn"
        raw = path.read_bytes()
        # Preserve physical count but reverse the two nearly simultaneous events.
        changed = raw[:360] + raw[400:440] + raw[360:400] + raw[440:]
        path.write_bytes(changed)
        proof["original_status_sha256"] = pins["original"] = v.sha(changed)
        proof_path.write_text(json.dumps(proof))
        with patch.object(v, "STATUS_RECONCILIATION_PINS", pins):
            with self.assertRaisesRegex(v.ValidationError, "STATUS_RECONCILIATION_RAW_BYTES_DIFFER"):
                v.reconcile_status(proof_path, self.root, pins["quote"], quote["quotes"][2], ID)

    def test_reconciliation_checks_day_framing_and_metadata_even_with_test_hashes_rebound(self):
        for offset, value, expected in ((360, 9, "RECORD_LENGTH_MISMATCH"),
                                         (26, 1, "STATUS_RECONCILIATION_WINDOW_MISMATCH")):
            with self.subTest(offset=offset):
                _, quote, proof_path, proof, pins = self.reconciliation_inputs()
                path = Path(proof["days"][0]["path"])
                raw = bytearray(path.read_bytes()); raw[offset] = value
                path.write_bytes(raw)
                proof["days"][0]["file_sha256"] = pins["20260915"] = v.sha(raw)
                proof_path.write_text(json.dumps(proof))
                with patch.object(v, "STATUS_RECONCILIATION_PINS", pins):
                    with self.assertRaisesRegex(v.ValidationError, expected):
                        v.reconcile_status(proof_path, self.root, pins["quote"], quote["quotes"][2], ID)

    def test_actual_official_fixture_and_native_quote_decode_check_wire_offsets(self):
        """Existing hash-pinned official ES fixture; no downloaded MES evidence."""
        import pyarrow as pa
        fixture = Path("D:/QM/futures_lab/data/fixtures/definition-glbx-es-fut.dbn.zst")
        if not fixture.exists():
            self.skipTest("Existing official fixture unavailable; offline unit tests remain")
        manifest_path = Path(__file__).with_name("fixtures_manifest.json")
        manifest = json.loads(manifest_path.read_text())
        expected = next(r for r in manifest["fixtures"] if r["name"] == fixture.name)
        self.assertEqual(v.sha(fixture.read_bytes()), expected["sha256"])
        with pa.input_stream(str(fixture), compression="zstd") as stream:
            raw = stream.read()
        offset = 8 + struct.unpack_from("<I", raw, 4)[0]
        path = self.root / "fixture-definition.dbn"
        path.write_bytes(raw)
        row = {"record_count": 2, "billable_uncompressed_bytes": len(raw)-offset,
               "start": "2023-04-01T00:00:00Z", "end": "2023-04-05T00:00:00Z"}
        scan = v.scan_dbn(path, "definition", row, 95414)
        loader = v.make_loader()
        decoded = v.official_decode(path, "definition", loader, definitions=True)
        self.assertEqual(scan["record_count"], len(decoded))
        self.assertEqual(str(decoded[0].id), "ESM3.GLBX")
        self.assertEqual(decoded[0].ts_init, struct.unpack_from("<Q", raw, offset+16)[0])
        # Reuse genuine symbol metadata; independently decode a tiny MBP-1
        # fixture to pin custom scanner offsets against the official decoder.
        meta = bytearray(raw[:offset]); struct.pack_into("<H", meta, 24, 1)
        ts = decoded[0].ts_init
        path = self.root / "tiny-mbp.dbn"
        path.write_bytes(meta + mbp(ts, instrument_id=95414))
        native_path = self.root / "tiny-mbp.dbn.zst"
        native_path.write_bytes(pa.compress(path.read_bytes(), codec="zstd").to_pybytes())
        quote = loader.from_dbn_file(native_path)[0]
        row = {**row, "record_count": 1, "billable_uncompressed_bytes": 80}
        scan = v.scan_dbn(path, "mbp-1", row, 95414)
        self.assertEqual(quote.bid_price.as_decimal(), Decimal("6000"))
        self.assertEqual(quote.ask_price.as_decimal(), Decimal("6000.25"))
        self.assertEqual(quote.bid_size.as_decimal(), Decimal("3"))
        self.assertEqual(quote.ask_size.as_decimal(), Decimal("4"))
        self.assertEqual(quote.ts_init, scan["timestamps"]["ts_recv"]["min_ns"])
        self.assertEqual(scan["quality_counts"]["usable_two_sided_positive_unlocked_on_tick_bbo"], 1)
        # Status is schema code 11 (record rtype 0x12), not schema code 12.
        struct.pack_into("<H", meta, 24, 11)
        status_raw = bytearray(status(ts)); struct.pack_into("<I", status_raw, 4, 95414)
        path = self.root / "tiny-status.dbn"
        path.write_bytes(meta + status_raw)
        native_path.write_bytes(pa.compress(path.read_bytes(), codec="zstd").to_pybytes())
        native_status = loader.from_dbn_file(native_path)[0]
        scan = v.scan_dbn(path, "status", {**row, "billable_uncompressed_bytes": 40}, 95414)
        self.assertEqual(native_status.ts_init, scan["status_records"][0]["ts_recv"])
        self.assertEqual(native_status.ts_event, scan["status_records"][0]["ts_event"])
        self.assertTrue(native_status.is_trading)
        self.assertTrue(native_status.is_quoting)


if __name__ == "__main__":
    unittest.main()
