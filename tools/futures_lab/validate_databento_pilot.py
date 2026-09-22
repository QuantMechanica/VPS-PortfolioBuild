"""Offline, bounded technical validation of the single MESZ6 Databento pilot.

No credentials, network, orders, economic backtest, or full quote-list loading.
The pinned Nautilus 1.221.0 decoder reads the small definition file. Large DBN
files are scanned in bounded NumPy chunks, including every record and file byte.
DBN layout: the installed Nautilus Databento adapter / official DBN wire format.
Missing BBO, crossed books and clock/sequence anomalies are reported, not silently
cleaned. A technical result is not a completeness or execution-quality guarantee.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
from decimal import Decimal
import hashlib
import io
import json
from pathlib import Path
import stat
import struct
import tempfile

PINNED_NAUTILUS = "1.221.0"
SCHEMAS = ("definition", "mbp-1", "status")
MAX_METADATA = 1024 * 1024
MAX_JSON = 2 * 1024 * 1024
MAX_DEFINITION = 32 * 1024 * 1024
CHUNK_RECORDS = 16384
SCRATCH_ROOT = Path("D:/QM/futures_lab/scratch/dbn_validation")
UNDEF_PRICE = 2**63 - 1
UNDEF_TS = 2**64 - 1
TICK_RAW = 250_000_000
RTYPES = {"definition": 0x13, "mbp-1": 0x01, "status": 0x12}
# A reviewed, empirical exception for these exact bytes, never a vendor-wide
# rounding tolerance. Changing the dataset or date requires new evidence/code.
STATUS_RECONCILIATION_PINS = {
    "quote": "24c9edcb056a2e0d856ba7c7832d4ae11263570957774920c940b52e735e2ef9",
    "original": "cb1910ff2aa34797998e2d04f50d67a548924ea610ad2aef6a0a1640e0474fa4",
    "20260915": "a2bb4cd3474ba86f086fe37183bb6367a2bcace7c4121ec546b7c0fa4382f00a",
    "20260916": "d5907e60df3fccde647dfd40f8a6f7f103eefab9a0a6a1ba26ba7183c0ec2bf5",
}
STATUS_DAY_WINDOWS = (
    ("20260915", "2026-09-15T00:00:00Z", "2026-09-16T00:00:00Z"),
    ("20260916", "2026-09-16T00:00:00Z", "2026-09-17T00:00:00Z"),
)
STATUS_MICRO_WINDOWS = (
    ("known_two_open_events", "2026-09-15T22:00:00Z", "2026-09-15T22:10:00Z", 2, 0),
    ("no_events_in_downloaded_full_window", "2026-09-15T23:00:00Z", "2026-09-15T23:10:00Z", 0, 0),
    ("one_midnight_snapshot", "2026-09-16T00:00:00Z", "2026-09-16T00:10:00Z", 1, 1),
)


class ValidationError(Exception):
    """Fixed local codes only; no remote text or credential access."""


def require(condition, code):
    if not condition:
        raise ValidationError(code)


def canonical_bytes(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=True, allow_nan=False).encode("utf-8")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def no_reparse(path):
    path = Path(path).absolute()
    for part in (path, *path.parents):
        if part.exists() or part.is_symlink():
            info = part.lstat()
            require(not stat.S_ISLNK(info.st_mode)
                    and not (getattr(info, "st_file_attributes", 0) & 0x400),
                    "REPARSE_PATH_REFUSED")


def fingerprint(path):
    no_reparse(path)
    info = Path(path).stat()
    require(stat.S_ISREG(info.st_mode), "REGULAR_FILE_REQUIRED")
    return (info.st_size, info.st_mtime_ns, info.st_dev, info.st_ino)


def read_json(path):
    before = fingerprint(path)
    require(before[0] <= MAX_JSON, "JSON_SIZE_CAP")
    raw = Path(path).read_bytes()
    require(fingerprint(path) == before, "INPUT_CHANGED_DURING_READ")
    value = json.loads(raw.decode("utf-8-sig"))
    require(type(value) is dict, "JSON_OBJECT_REQUIRED")
    return value, sha(raw)


def ns(value):
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    require(parsed.tzinfo is not None and parsed.utcoffset() is not None,
            "TIMEZONE_REQUIRED")
    epoch = datetime(1970, 1, 1, tzinfo=timezone.utc)
    delta = parsed.astimezone(timezone.utc) - epoch
    return (delta.days * 86400 + delta.seconds) * 1_000_000_000 + delta.microseconds * 1000


def positive_int(value):
    require(type(value) is int and value > 0, "POSITIVE_INTEGER_REQUIRED")
    return value


def validate_quote(quote):
    require(quote.get("schema") == "qm.databento-quote/v1"
            and quote.get("classification") == "QUOTE_ONLY"
            and quote.get("status") == "WITHIN_QUOTE_LIMITS"
            and quote.get("blockers") == [], "QUOTE_NOT_VALIDATED")
    req = quote["request"]
    require(sha(canonical_bytes(req)) == quote["request_sha256"], "QUOTE_REQUEST_HASH_MISMATCH")
    require(req["dataset"] == "GLBX.MDP3" and req["symbol"] == "MESZ6"
            and req["stype_in"] == "raw_symbol"
            and len(req["schemas"]) == 3 and set(req["schemas"]) == set(SCHEMAS),
            "OUTSIDE_FIXED_MES_PILOT")
    require(quote["resolution"]["status"] == "FULL_DATE_COVERAGE_ONE_ID",
            "UNRESOLVED_INSTRUMENT")
    numeric_id = int(quote["resolution"]["instrument_id"])
    require(0 < numeric_id < 2**32, "INVALID_INSTRUMENT_ID")
    require(str(numeric_id) == quote["resolution"]["instrument_id"], "INVALID_INSTRUMENT_ID")
    require(len(quote["quotes"]) == 3, "INCOMPLETE_SCHEMA_QUOTES")
    rows = {row["schema"]: row for row in quote["quotes"]}
    require(set(rows) == set(SCHEMAS), "INCOMPLETE_SCHEMA_QUOTES")
    for schema, row in rows.items():
        positive_int(row["record_count"])
        positive_int(row["billable_uncompressed_bytes"])
        require({"start": row["start"], "end": row["end"]} == req["schema_windows"][schema],
                "SCHEMA_WINDOW_MISMATCH")
        require(ns(row["start"]) < ns(row["end"]), "INVALID_SCHEMA_WINDOW")
    require(sum(r["billable_uncompressed_bytes"] for r in rows.values())
            <= positive_int(req["local_storage_budget_bytes"]), "LOCAL_STORAGE_CAP")
    return req, rows, numeric_id


def read_header(handle, digest):
    prefix = handle.read(8)
    require(len(prefix) == 8 and prefix[:3] == b"DBN" and prefix[3] in (1, 2, 3),
            "UNCOMPRESSED_DBN_V1_V2_V3_REQUIRED")
    length = struct.unpack_from("<I", prefix, 4)[0]
    require(18 <= length <= MAX_METADATA, "INVALID_DBN_METADATA_LENGTH")
    meta = handle.read(length)
    require(len(meta) == length, "TRUNCATED_DBN_METADATA")
    digest.update(prefix)
    digest.update(meta)
    try:
        dataset = meta[:16].split(b"\0", 1)[0].decode("ascii")
    except UnicodeError:
        raise ValidationError("INVALID_DATASET_METADATA") from None
    require(dataset == "GLBX.MDP3", "DBN_DATASET_MISMATCH")
    return {"dbn_version": prefix[3], "metadata_bytes": length + 8,
            "dataset": dataset, "schema_code": struct.unpack_from("<H", meta, 16)[0]}


def dtype_for(schema):
    import numpy as np
    names = ["length", "rtype", "publisher_id", "instrument_id", "ts_event"]
    formats = ["u1", "u1", "<u2", "<u4", "<u8"]
    offsets = [0, 1, 2, 4, 8]
    if schema == "mbp-1":
        names += ["price", "size", "action", "side", "flags", "depth", "ts_recv",
                  "ts_in_delta", "sequence", "bid_px", "ask_px", "bid_sz", "ask_sz",
                  "bid_ct", "ask_ct"]
        formats += ["<i8", "<u4", "u1", "u1", "u1", "u1", "<u8", "<i4", "<u4",
                    "<i8", "<i8", "<u4", "<u4", "<u4", "<u4"]
        offsets += [16, 24, 28, 29, 30, 31, 32, 40, 44, 48, 56, 64, 68, 72, 76]
        size = 80
    else:
        require(schema == "status", "UNSUPPORTED_SCHEMA")
        names += ["ts_recv", "action", "reason", "trading_event", "is_trading", "is_quoting",
                  "is_short_sell_restricted"]
        formats += ["<u8", "<u2", "<u2", "<u2", "u1", "u1", "u1"]
        offsets += [16, 24, 26, 28, 30, 31, 32]
        size = 40
    return np.dtype({"names": names, "formats": formats, "offsets": offsets, "itemsize": size})


class StreamingStats:
    def __init__(self, schema, instrument_id, start, end):
        self.schema, self.instrument_id = schema, instrument_id
        self.start, self.end = start, end
        self.count = 0
        self.publishers = set()
        self.times = {name: {"min_ns": None, "max_ns": None, "previous": None,
                             "backsteps": 0, "equal_adjacent": 0, "max_forward_gap_ns": 0,
                             "undefined_or_zero": 0, "outside_query_window": 0}
                      for name in ("ts_event", "ts_recv")}
        self.flags = Counter()
        self.actions = Counter()
        self.quality = Counter()
        self.previous_sequence = None
        self.status_rows = []

    def clock(self, name, values):
        import numpy as np
        stats = self.times[name]
        invalid = (values == 0) | (values == UNDEF_TS)
        stats["undefined_or_zero"] += int(np.count_nonzero(invalid))
        valid = values[~invalid]
        if len(valid):
            lo, hi = int(valid.min()), int(valid.max())
            stats["min_ns"] = lo if stats["min_ns"] is None else min(lo, stats["min_ns"])
            stats["max_ns"] = hi if stats["max_ns"] is None else max(hi, stats["max_ns"])
        stats["outside_query_window"] += int(np.count_nonzero(
            ~invalid & ((values < self.start) | (values >= self.end))))
        # Compare in unsigned space; subtract only forward pairs to avoid wrap.
        previous = stats["previous"]
        if previous is not None:
            values = np.concatenate((np.array([previous], dtype="<u8"), values))
        if len(values) > 1:
            a, b = values[:-1], values[1:]
            okay = (a != 0) & (a != UNDEF_TS) & (b != 0) & (b != UNDEF_TS)
            stats["backsteps"] += int(np.count_nonzero(okay & (b < a)))
            stats["equal_adjacent"] += int(np.count_nonzero(okay & (b == a)))
            forward = okay & (b > a)
            if np.any(forward):
                stats["max_forward_gap_ns"] = max(stats["max_forward_gap_ns"],
                                                   int((b[forward] - a[forward]).max()))
        if len(values):
            stats["previous"] = int(values[-1])

    def consume(self, rows):
        import numpy as np
        require(np.all(rows["length"] == rows.dtype.itemsize // 4), "RECORD_LENGTH_MISMATCH")
        require(np.all(rows["rtype"] == RTYPES[self.schema]), "RECORD_SCHEMA_MISMATCH")
        require(np.all(rows["instrument_id"] == self.instrument_id), "RECORD_INSTRUMENT_MISMATCH")
        self.publishers.update(int(x) for x in np.unique(rows["publisher_id"]))
        require(0 not in self.publishers and len(self.publishers) == 1, "PUBLISHER_ID_MISMATCH")
        self.count += len(rows)
        self.clock("ts_event", rows["ts_event"])
        self.clock("ts_recv", rows["ts_recv"])
        vals, counts = np.unique(rows["action"], return_counts=True)
        self.actions.update({int(k): int(v) for k, v in zip(vals, counts)})
        if self.schema == "status":
            for row in rows:
                require(len(self.status_rows) < 4096, "STATUS_REPORT_ROW_CAP")
                self.status_rows.append({name: int(row[name]) for name in rows.dtype.names})
            return
        bid, ask = rows["bid_px"], rows["ask_px"]
        bvalid, avalid = bid != UNDEF_PRICE, ask != UNDEF_PRICE
        both = bvalid & avalid
        tests = {
            "missing_bid_price": ~bvalid, "missing_ask_price": ~avalid,
            "zero_bid_size": rows["bid_sz"] == 0, "zero_ask_size": rows["ask_sz"] == 0,
            "crossed_bbo": both & (bid > ask), "locked_bbo": both & (bid == ask),
            "nonpositive_bid": bvalid & (bid <= 0), "nonpositive_ask": avalid & (ask <= 0),
            "bid_off_tick": bvalid & (bid % TICK_RAW != 0),
            "ask_off_tick": avalid & (ask % TICK_RAW != 0),
            "event_price_off_tick": (rows["price"] != UNDEF_PRICE) & (rows["price"] % TICK_RAW != 0),
        }
        for key, mask in tests.items():
            self.quality[key] += int(np.count_nonzero(mask))
        self.quality["usable_two_sided_positive_unlocked_on_tick_bbo"] += int(np.count_nonzero(
            both & (bid > 0) & (ask > bid) & (rows["bid_sz"] > 0) & (rows["ask_sz"] > 0)
            & (bid % TICK_RAW == 0) & (ask % TICK_RAW == 0)))
        values, counts = np.unique(rows["flags"], return_counts=True)
        self.flags.update({int(k): int(v) for k, v in zip(values, counts)})
        sequence = rows["sequence"]
        if self.previous_sequence is not None:
            sequence = np.concatenate((np.array([self.previous_sequence], dtype="<u4"), sequence))
        self.quality["sequence_backsteps_or_resets"] += int(np.count_nonzero(sequence[1:] < sequence[:-1]))
        self.previous_sequence = int(sequence[-1])

    def report(self):
        return {"record_count": self.count, "publisher_ids": sorted(self.publishers),
                "timestamps": {k: {f: v for f, v in row.items() if f != "previous"}
                               for k, row in self.times.items()},
                "action_byte_counts": dict(sorted(self.actions.items())),
                "flag_byte_counts": dict(sorted(self.flags.items())),
                "quality_counts": dict(sorted(self.quality.items())),
                **({"status_records": self.status_rows} if self.schema == "status" else {})}


def scan_dbn(path, schema, row, instrument_id, *, chunk_records=CHUNK_RECORDS):
    """Hash and inspect ALL uncompressed records; retained memory is O(chunk size)."""
    import numpy as np
    require(type(chunk_records) is int and 0 < chunk_records <= CHUNK_RECORDS, "INVALID_CHUNK_SIZE")
    before = fingerprint(path)
    require(before[0] <= row["billable_uncompressed_bytes"] + MAX_METADATA + 8, "FILE_SIZE_CAP")
    if schema == "definition":
        require(before[0] <= MAX_DEFINITION and row["record_count"] <= 4096, "DEFINITION_SIZE_CAP")
    digest = hashlib.sha256()
    stats = StreamingStats(schema, instrument_id, ns(row["start"]), ns(row["end"]))
    record_bytes = 0
    with Path(path).open("rb") as handle:
        metadata = read_header(handle, digest)
        if schema == "definition":
            # Definition layouts change across DBN versions; the official decoder
            # below validates their economics. Common header and ts_recv are stable.
            while True:
                first = handle.read(1)
                if not first:
                    break
                size = first[0] * 4
                require(size >= 24, "INVALID_DEFINITION_RECORD_LENGTH")
                raw = first + handle.read(size - 1)
                require(len(raw) == size, "TRUNCATED_DBN_RECORD")
                digest.update(raw)
                length, rtype, publisher, actual_id, event = struct.unpack_from("<BBHIQ", raw)
                require(rtype == RTYPES[schema], "RECORD_SCHEMA_MISMATCH")
                require(actual_id == instrument_id, "RECORD_INSTRUMENT_MISMATCH")
                require(publisher > 0, "PUBLISHER_ID_MISMATCH")
                stats.publishers.add(publisher)
                require(len(stats.publishers) == 1, "PUBLISHER_ID_MISMATCH")
                recv = struct.unpack_from("<Q", raw, 16)[0]
                stats.clock("ts_event", np.array([event], dtype="<u8"))
                stats.clock("ts_recv", np.array([recv], dtype="<u8"))
                stats.count += 1
                require(stats.count <= row["record_count"], "RECORD_COUNT_EXCEEDED")
                record_bytes += size
        else:
            dtype = dtype_for(schema)
            while True:
                raw = handle.read(chunk_records * dtype.itemsize)
                if not raw:
                    break
                digest.update(raw)
                require(len(raw) % dtype.itemsize == 0, "TRUNCATED_DBN_RECORD")
                stats.consume(np.frombuffer(raw, dtype=dtype))
                require(stats.count <= row["record_count"], "RECORD_COUNT_EXCEEDED")
                record_bytes += len(raw)
    require(fingerprint(path) == before, "INPUT_CHANGED_DURING_SCAN")
    require(stats.count == row["record_count"], "RECORD_COUNT_MISMATCH")
    require(record_bytes == row["billable_uncompressed_bytes"], "RECORD_BYTES_MISMATCH")
    require(record_bytes + metadata["metadata_bytes"] == before[0], "FILE_FRAMING_MISMATCH")
    return {"schema": schema, "path": str(Path(path).absolute()), **metadata,
            "instrument_id": str(instrument_id), "file_sha256": digest.hexdigest(),
            "actual_file_bytes": before[0], "record_bytes": record_bytes,
            "quoted_window": {"start": row["start"], "end": row["end"]},
            "all_records_scanned": True, "max_chunk_records": chunk_records, **stats.report()}


def make_loader():
    import nautilus_trader
    from nautilus_trader.adapters.databento import DatabentoDataLoader
    require(nautilus_trader.__version__ == PINNED_NAUTILUS, "NAUTILUS_VERSION_MISMATCH")
    return DatabentoDataLoader()


def official_decode(path, schema, loader, *, definitions=False):
    """Pinned loader expects zstd. Adapt a bounded local copy, never raw sources.

    For market-data schemas only metadata is adapted: no quote list is created.
    PyArrow and its zstd codec are already installed in the pinned environment.
    """
    import pyarrow as pa
    before = fingerprint(path)
    if definitions:
        require(before[0] <= MAX_DEFINITION, "DEFINITION_SIZE_CAP")
    with Path(path).open("rb") as handle:
        header = read_header(handle, hashlib.sha256())
        handle.seek(0)
        raw = handle.read(before[0] if definitions else header["metadata_bytes"])
    require(fingerprint(path) == before, "INPUT_CHANGED_DURING_DEFINITION_DECODE")
    no_reparse(SCRATCH_ROOT)
    SCRATCH_ROOT.mkdir(parents=True, exist_ok=True)
    no_reparse(SCRATCH_ROOT)
    with tempfile.TemporaryDirectory(prefix="qm-dbn-metadata-", dir=SCRATCH_ROOT) as folder:
        require(Path(folder).resolve().parent == SCRATCH_ROOT.resolve(), "SCRATCH_PATH_MISMATCH")
        adapted = Path(folder) / "bounded.dbn.zst"
        adapted.write_bytes(pa.compress(raw, codec="zstd").to_pybytes())
        require(loader._pyo3_loader.schema_for_file(str(adapted)) == schema, "OFFICIAL_SCHEMA_MISMATCH")
        return loader.from_dbn_file(adapted) if definitions else None


def verify_definitions(instruments, expected_count, start_ns, end_ns):
    from nautilus_trader.model.instruments import FuturesContract
    require(len(instruments) == expected_count, "DECODED_DEFINITION_COUNT_MISMATCH")
    evidence = []
    for item in instruments:
        require(isinstance(item, FuturesContract), "DEFINITION_NOT_FUTURES_CONTRACT")
        require(str(item.raw_symbol) == "MESZ6" and str(item.id) == "MESZ6.GLBX",
                "DEFINITION_SYMBOL_MISMATCH")
        require(item.multiplier.as_decimal() == Decimal("5"), "DEFINITION_MULTIPLIER_MISMATCH")
        require(item.price_increment.as_decimal() == Decimal("0.25"), "DEFINITION_TICK_MISMATCH")
        require(str(item.quote_currency) == "USD", "DEFINITION_CURRENCY_MISMATCH")
        require(item.activation_ns <= start_ns < end_ns <= item.expiration_ns, "CONTRACT_NOT_ACTIVE_IN_PILOT")
        evidence.append(item.to_dict(item))
    require(len({row["id"] for row in evidence}) == 1, "NONUNIQUE_DEFINITION_IDENTITY")
    return evidence


def status_wire_parts(path, start, end):
    """Read only a bounded diagnostic status file; retain original record order."""
    before = fingerprint(path)
    require(before[0] <= 1024 * 1024, "STATUS_RECONCILIATION_SIZE_CAP")
    payload = Path(path).read_bytes()
    require(fingerprint(path) == before, "INPUT_CHANGED_DURING_READ")
    metadata = read_header(io.BytesIO(payload), hashlib.sha256())
    require(metadata["dbn_version"] == 3 and metadata["schema_code"] == 11
            and metadata["metadata_bytes"] == 360, "STATUS_RECONCILIATION_METADATA_MISMATCH")
    require(struct.unpack_from("<Q", payload, 26)[0] == ns(start)
            and struct.unpack_from("<Q", payload, 34)[0] == ns(end),
            "STATUS_RECONCILIATION_WINDOW_MISMATCH")
    body = payload[metadata["metadata_bytes"]:]
    require(len(body) % 40 == 0, "TRUNCATED_DBN_RECORD")
    return payload, [body[i:i+40] for i in range(0, len(body), 40)], metadata


def reconcile_status(proof_path, data_root, quote_sha, row, instrument_id):
    """Recompute the exact-file proof; never accept its success flag on trust."""
    proof, proof_sha = read_json(proof_path)
    require(proof.get("schema") == "qm.databento-status-utc-day-reconciliation/v1"
            and proof.get("status") == "MATCHED_FOR_THESE_EXACT_FILES",
            "STATUS_RECONCILIATION_PROOF_TYPE")
    require(quote_sha == STATUS_RECONCILIATION_PINS["quote"]
            and proof["original_quote_sha256"] == quote_sha
            and instrument_id == 42001581
            and ns(row["start"]) == ns("2026-09-15T22:00:00Z")
            and ns(row["end"]) == ns("2026-09-16T21:00:00Z"),
            "STATUS_RECONCILIATION_OUTSIDE_EXACT_PILOT")
    original_path = Path(data_root) / "status.dbn"
    original, original_records, original_metadata = status_wire_parts(original_path, row["start"], row["end"])
    require(sha(original) == proof["original_status_sha256"] == STATUS_RECONCILIATION_PINS["original"],
            "STATUS_RECONCILIATION_ORIGINAL_HASH")
    for value in (proof["original_quote_record_count"], proof["original_actual_record_count"],
                  proof["original_metadata_bytes"], proof["original_window_reconstructed_count"]):
        positive_int(value)
    require(row["record_count"] == proof["original_quote_record_count"] == 12
            and row["billable_uncompressed_bytes"] == 480
            and len(original_records) == proof["original_actual_record_count"] == 3
            and original_metadata["metadata_bytes"] == proof["original_metadata_bytes"] == 360
            and proof["original_window_reconstructed_count"] == 3
            and proof["original_record_bytes_equal_in_order_without_deduplication"] is True,
            "STATUS_RECONCILIATION_ORIGINAL_COUNTS")
    require(type(proof["days"]) is list and len(proof["days"]) == 2, "STATUS_RECONCILIATION_DAY_COUNT")
    all_records, day_scans = [], []
    for day, (label, start, end) in zip(proof["days"], STATUS_DAY_WINDOWS):
        expected_path = Path(data_root) / "status_utc_day_diagnostic" / (label + ".status.dbn")
        no_reparse(expected_path)
        require(day["label"] == label and Path(day["path"]).absolute() == expected_path.absolute()
                and day["status"] == "COMPLETE" and type(day["http_status"]) is int
                and day["http_status"] == 200, "STATUS_RECONCILIATION_DAY_PATH_OR_STATE")
        expected_params = {"dataset": "GLBX.MDP3", "symbols": "MESZ6", "schema": "status",
                           "stype_in": "raw_symbol", "stype_out": "instrument_id", "start": start, "end": end}
        require(day["params"] == expected_params, "STATUS_RECONCILIATION_DAY_REQUEST")
        for name in ("quote_record_count", "quote_billable_bytes", "file_bytes", "metadata_bytes",
                     "actual_record_count", "record_bytes"):
            positive_int(day[name])
        require(day["quote_record_count"] == day["actual_record_count"] == 6
                and day["quote_billable_bytes"] == day["record_bytes"] == 240
                and day["metadata_bytes"] == 360 and day["file_bytes"] == 600,
                "STATUS_RECONCILIATION_DAY_COUNTS")
        payload, records, metadata = status_wire_parts(expected_path, start, end)
        require(sha(payload) == day["file_sha256"] == STATUS_RECONCILIATION_PINS[label],
                "STATUS_RECONCILIATION_DAY_HASH")
        require(len(payload) == day["file_bytes"] and len(records) == day["actual_record_count"]
                and metadata["metadata_bytes"] == day["metadata_bytes"],
                "STATUS_RECONCILIATION_DAY_SIZE")
        scan = scan_dbn(expected_path, "status", {"record_count": day["quote_record_count"],
                        "billable_uncompressed_bytes": day["quote_billable_bytes"],
                        "start": start, "end": end}, instrument_id)
        require(scan["file_sha256"] == day["file_sha256"]
                and scan["timestamps"]["ts_recv"]["outside_query_window"] == 0
                and scan["timestamps"]["ts_recv"]["undefined_or_zero"] == 0
                and scan["timestamps"]["ts_recv"]["backsteps"] == 0,
                "STATUS_RECONCILIATION_DAY_RECEIVE_TIMES")
        all_records.extend(records)
        day_scans.append(scan)
    require(sum(d["record_count"] for d in day_scans) == row["record_count"]
            and sum(d["record_bytes"] for d in day_scans) == row["billable_uncompressed_bytes"],
            "STATUS_RECONCILIATION_AGGREGATE_COUNTS")

    def time_filter(start, end):
        return [raw for raw in all_records if ns(start) <= struct.unpack_from("<Q", raw, 16)[0] < ns(end)]

    selected = time_filter(row["start"], row["end"])
    require(len(selected) == proof["original_window_reconstructed_count"]
            and b"".join(selected) == b"".join(original_records), "STATUS_RECONCILIATION_RAW_BYTES_DIFFER")
    require(type(proof["comparisons"]) is list and len(proof["comparisons"]) == 3,
            "STATUS_RECONCILIATION_MICRO_COUNT")
    for micro, (label, start, end, count, day_index) in zip(proof["comparisons"], STATUS_MICRO_WINDOWS):
        for field in ("record_count_quote", "billable_size_quote", "actual_reconstructed_record_count"):
            require(type(micro[field]) is int and micro[field] >= 0, "STATUS_RECONCILIATION_MICRO_NUMERIC")
        require(micro["label"] == label and micro["start"] == start and micro["end"] == end
                and micro["record_count_quote"] == day_scans[day_index]["record_count"]
                and micro["billable_size_quote"] == day_scans[day_index]["record_bytes"]
                and len(time_filter(start, end)) == micro["actual_reconstructed_record_count"] == count,
                "STATUS_RECONCILIATION_MICRO_MISMATCH")
    # The only altered *scan expectation* is derived from independently verified
    # byte equality above. The original quote is retained verbatim in the report.
    actual_expectation = {**row, "record_count": len(selected), "billable_uncompressed_bytes": len(selected)*40}
    scan = scan_dbn(original_path, "status", actual_expectation, instrument_id)
    require(scan["file_sha256"] == sha(original), "STATUS_RECONCILIATION_ORIGINAL_CHANGED")
    scan.update({"quoted_record_count": row["record_count"],
                 "quoted_billable_uncompressed_bytes": row["billable_uncompressed_bytes"],
                 "direct_quote_count_match": False,
                 "count_comparison": "UTC_DAY_METADATA_DISCREPANCY_RECONCILED_FOR_EXACT_FILES"})
    return scan, {"status": "MATCHED_FOR_THESE_EXACT_FILES", "proof_sha256": proof_sha,
                  "proof_path": str(Path(proof_path).absolute()), "original_quote_sha256": quote_sha,
                  "original_file_sha256": sha(original), "original_quote": row,
                  "actual_record_count": len(selected), "actual_record_bytes": len(selected)*40,
                  "filter_field": "ts_recv", "filter_interval": "[start,end)",
                  "raw_bytes_equal_in_order_without_deduplication": True,
                  "days": day_scans, "micro_comparisons": proof["comparisons"],
                  "general_vendor_rounding_semantics_inferred": False}


def review_flags(scans):
    flags = []
    for row in scans:
        for clock_name, clock in row["timestamps"].items():
            for metric in ("backsteps", "undefined_or_zero", "outside_query_window"):
                if clock[metric]:
                    flags.append(f"{row['schema']}:{clock_name}:{metric}")
        for key, count in row["quality_counts"].items():
            if count and key != "usable_two_sided_positive_unlocked_on_tick_bbo":
                flags.append(f"{row['schema']}:{key}")
    return flags


def validate_pilot(quote_path, data_root, *, definitions_only=False, loader=None, status_reconciliation=None):
    quote, quote_sha = read_json(quote_path)
    req, rows, instrument_id = validate_quote(quote)
    data_root = Path(data_root)
    no_reparse(data_root)
    loader = make_loader() if loader is None else loader
    scans = []
    definitions = None
    reconciliation = None
    for schema in (("definition",) if definitions_only else SCHEMAS):
        path = data_root / (schema + ".dbn")
        receipt, receipt_sha = read_json(data_root / (schema + ".attempt.json"))
        require(receipt.get("status") == "COMPLETE", "DOWNLOAD_NOT_COMPLETE")
        require(receipt.get("schema") == schema and receipt.get("quote_sha256") == quote_sha
                and receipt.get("quote_request_sha256") == quote["request_sha256"],
                "DOWNLOAD_RECEIPT_BINDING_MISMATCH")
        require(type(receipt.get("actual_file_bytes")) is int, "INVALID_RECEIPT_FILE_SIZE")
        try:
            scan = scan_dbn(path, schema, rows[schema], instrument_id)
        except ValidationError as original_error:
            if schema != "status" or str(original_error) != "RECORD_COUNT_MISMATCH" or status_reconciliation is None:
                raise
            try:
                scan, reconciliation = reconcile_status(status_reconciliation, data_root, quote_sha,
                                                         rows[schema], instrument_id)
            except Exception:
                # Invalid/missing/forged reconciliation never turns the original
                # count mismatch into a pass or changes the strict scanner.
                raise ValidationError("RECORD_COUNT_MISMATCH") from None
        require(scan["file_sha256"] == receipt.get("file_sha256")
                and scan["actual_file_bytes"] == receipt["actual_file_bytes"],
                "DOWNLOAD_FILE_HASH_OR_SIZE_MISMATCH")
        # This method reads DBN metadata; do NOT call load_quotes/load_status:
        # those pinned APIs materialize every decoded object into a Python list.
        scan["download_receipt_sha256"] = receipt_sha
        scans.append(scan)
        before = fingerprint(path)
        decoded = official_decode(path, schema, loader, definitions=schema == "definition")
        require(fingerprint(path) == before, "INPUT_CHANGED_DURING_DEFINITION_DECODE")
        if schema == "definition":
            definitions = verify_definitions(decoded, rows[schema]["record_count"], ns(req["start"]), ns(req["end"]))
    require(len({tuple(s["publisher_ids"]) for s in scans}) == 1, "CROSS_SCHEMA_PUBLISHER_MISMATCH")
    flags = review_flags(scans)
    definition_scan = scans[0]
    return {
        "schema": "qm.databento-pilot-validation/v1",
        "classification": "DEFINITION_ONLY_TECHNICAL_VALIDATION" if definitions_only else "FULL_RAW_DBN_TECHNICAL_VALIDATION",
        "status": "PASS" if definitions_only else ("TECHNICAL_PASS_WITH_REVIEW_FLAGS" if flags else "TECHNICAL_PASS"),
        "structural_status": "PASS", "data_quality_status": "REVIEW_REQUIRED" if flags else "NO_CHECKED_ANOMALIES",
        "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
        "quote_sha256": quote_sha, "quote_request_sha256": quote["request_sha256"],
        "definition_sha256": definition_scan["file_sha256"],
        "symbol": "MESZ6", "instrument_id": str(instrument_id), "nautilus_instrument_id": "MESZ6.GLBX",
        "multiplier": "5", "tick_size": "0.25", "currency": "USD",
        "nautilus_version": PINNED_NAUTILUS,
        "validator_sha256": sha(Path(__file__).read_bytes()),
        "definitions": definitions, "files": scans, "review_flags": flags,
        "status_reconciliation": reconciliation,
        "all_requested_schemas_validated": not definitions_only,
        "orders_submitted": 0, "network_requests": 0, "strategy_backtest_performed": False,
        "limitations": [
            "PASS in definition-only mode means contract identity/economics and its file binding, not market-data quality.",
            "Full mode scans every raw record; Nautilus object decoding is checked only for the small definition file.",
            "Pinned Nautilus expects zstd: only metadata or the bounded definition file is temporarily compressed locally; raw files remain unchanged.",
            "Same timestamps are retained. Sequence gaps for a single contract do not prove missing exchange messages.",
            "Definition snapshots may carry earlier event timestamps. Query-window metrics use both event and receive time without silently rejecting snapshots.",
            "BBO anomalies and clock resets require review; no records were filtered, repaired or deduplicated.",
            "Optional status reconciliation proves only the pinned original/day files; it does not establish a general metadata-count tolerance.",
            "No trading-calendar completeness, executable fill, queue-position, fee, slippage or profitability claim.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quote", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--definitions-only", action="store_true")
    parser.add_argument("--status-reconciliation", type=Path)
    args = parser.parse_args()
    try:
        no_reparse(args.output)
        require(not args.output.exists(), "OUTPUT_ALREADY_EXISTS")
        protected = [args.quote, *(args.data_root / (s + suffix) for s in SCHEMAS
                                  for suffix in (".dbn", ".dbn.part", ".attempt.json"))]
        if args.status_reconciliation is not None:
            protected.append(args.status_reconciliation)
        require(args.output.absolute() not in [p.absolute() for p in protected], "OUTPUT_IS_INPUT")
        result = validate_pilot(args.quote, args.data_root, definitions_only=args.definitions_only,
                                status_reconciliation=args.status_reconciliation)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8") as handle:
            json.dump(result, handle, indent=2, allow_nan=False)
            handle.write("\n")
        print(json.dumps({key: result[key] for key in ("classification", "status", "data_quality_status", "symbol")}))
        return 0
    except ValidationError as exc:
        print("VALIDATION_BLOCKED " + str(exc))
        return 2
    except Exception:
        print("VALIDATION_BLOCKED LOCAL_INPUT_OR_DECODER_ERROR")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
