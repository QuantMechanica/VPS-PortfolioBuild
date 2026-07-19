"""Build a hash-bound slippage ledger from explicitly supplied offline evidence.

There are deliberately no default terminal roots and no implicit globbing in
this module.  A caller must provide an input specification containing exact
files.  This keeps collection/snapshot policy separate from deterministic
parsing, joining, calculation, and publication.

The qualification sample unit is one executed order/request.  Multiple deal
tickets belonging to that order are aggregated to a volume-weighted fill price
so partial fills cannot inflate the sample count.
"""

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import sys
import uuid
from collections import defaultdict
from decimal import Decimal, InvalidOperation, localcontext
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


SCHEMA_VERSION = 2
ARTIFACT_TYPE = "QM_SLIPPAGE_LEDGER"
ALIAS_ARTIFACT_TYPE = "QM_EXECUTION_SYMBOL_ALIASES"
MINIMUM_SAMPLES_PER_SYMBOL = 30
QUANTILE = Decimal("0.95")
QUANTILE_METHOD = "NEAREST_RANK_CEIL_NO_INTERPOLATION"
ELIGIBLE_REFERENCE_KINDS = frozenset(
    {"REQUEST_EXACT", "PENDING_TRIGGER_EXACT", "SERVER_LEVEL_EXACT"}
)
SOURCE_ROLES = frozenset(
    {"EA_JSON_LOG", "TERMINAL_JOURNAL", "HISTORY_DEALS_JSONL"}
)
RESERVED_SOURCE_IDS = frozenset({"INPUT_SPEC", "ALIAS_POLICY", "GENERATOR"})
LOGICAL_SYMBOL_RE = re.compile(r"^[A-Z][A-Z0-9]{1,15}\.DWX$")
DECIMAL_TOKEN = r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)"
JOURNAL_DEAL_RE = re.compile(
    rf"'(?P<account>\d+)':\s+deal\s+#(?P<deal>\d+)\s+"
    rf"(?P<side>buy|sell)\s+(?P<volume>{DECIMAL_TOKEN})\s+"
    rf"(?P<symbol>\S+)\s+at\s+(?P<price>{DECIMAL_TOKEN})\s+done\s+"
    rf"\(based on order\s+#(?P<order>\d+)\)",
    re.IGNORECASE,
)


class LedgerError(RuntimeError):
    """Raised when evidence is malformed, ambiguous, or changes while read."""


def _reject_json_constant(value: str) -> None:
    raise LedgerError(f"non-finite JSON number is forbidden: {value}")


def _reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise LedgerError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def strict_json_loads(text: str, *, label: str) -> Any:
    try:
        return json.loads(
            text,
            parse_float=Decimal,
            parse_int=int,
            parse_constant=_reject_json_constant,
            object_pairs_hook=_reject_duplicate_pairs,
        )
    except LedgerError:
        raise
    except (json.JSONDecodeError, TypeError, ValueError) as exc:
        raise LedgerError(f"invalid JSON in {label}: {exc}") from exc


def _require_exact_keys(
    value: Any,
    expected: set[str],
    *,
    label: str,
) -> Mapping[str, Any]:
    if not isinstance(value, dict):
        raise LedgerError(f"{label} must be an object")
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise LedgerError(f"{label} keys invalid; missing={missing}, extra={extra}")
    return value


def _nonempty_string(value: Any, *, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise LedgerError(f"{label} must be a non-empty string")
    return value


def _positive_int(value: Any, *, label: str, allow_zero: bool = False) -> int:
    if isinstance(value, bool):
        raise LedgerError(f"{label} must be an integer")
    if isinstance(value, str) and not re.fullmatch(r"0|[1-9]\d*", value):
        raise LedgerError(f"{label} must be an integer")
    try:
        result = int(value)
    except (TypeError, ValueError, OverflowError) as exc:
        raise LedgerError(f"{label} must be an integer") from exc
    minimum = 0 if allow_zero else 1
    if result < minimum or (not isinstance(value, str) and result != value):
        raise LedgerError(f"{label} must be an integer >= {minimum}")
    return result


def _decimal(value: Any, *, label: str, positive: bool = False) -> Decimal:
    if isinstance(value, bool) or value is None:
        raise LedgerError(f"{label} must be a finite decimal")
    try:
        result = value if isinstance(value, Decimal) else Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise LedgerError(f"{label} must be a finite decimal") from exc
    if not result.is_finite() or (positive and result <= 0):
        qualifier = "positive " if positive else ""
        raise LedgerError(f"{label} must be a finite {qualifier}decimal")
    return result


def canonical_decimal(value: Decimal) -> str:
    if not value.is_finite():
        raise LedgerError("cannot serialize a non-finite decimal")
    if value == 0:
        return "0"
    rendered = format(value, "f")
    if "." in rendered:
        rendered = rendered.rstrip("0").rstrip(".")
    return rendered


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def pretty_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            allow_nan=False,
            sort_keys=True,
            indent=2,
        )
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def nearest_rank(values: Sequence[Decimal], quantile: Decimal = QUANTILE) -> Decimal:
    """Return the non-interpolating nearest-rank quantile.

    The rank is ``ceil(q*n)`` using one-based indexing.  This can never return
    a value outside the observed range.
    """

    if not values:
        raise LedgerError("nearest_rank requires at least one observation")
    q = _decimal(quantile, label="quantile", positive=True)
    if q > 1:
        raise LedgerError("quantile must be <= 1")
    ordered = sorted(_decimal(value, label="quantile observation") for value in values)
    rank = int((q * len(ordered)).to_integral_value(rounding="ROUND_CEILING"))
    result = ordered[rank - 1]
    if result < ordered[0] or result > ordered[-1]:  # defensive invariant
        raise LedgerError("nearest-rank result escaped the observed range")
    return result


@dataclasses.dataclass(frozen=True)
class SourceSpec:
    source_id: str
    venue_id: str
    account_id: str
    server: str
    role: str
    path: Path


@dataclasses.dataclass(frozen=True)
class SourceBinding:
    source_id: str
    venue_id: str
    account_id: str
    server: str
    role: str
    path: str
    size_bytes: int
    mtime_ns: int
    sha256: str

    def manifest_record(self) -> dict[str, Any]:
        return {
            "source_id": self.source_id,
            "venue_id": self.venue_id,
            "account_id": self.account_id,
            "server": self.server,
            "role": self.role,
            "path": self.path,
            "size_bytes": self.size_bytes,
            "mtime_ns": self.mtime_ns,
            "sha256": self.sha256,
        }


@dataclasses.dataclass(frozen=True)
class CapturedSource:
    spec: SourceSpec
    binding: SourceBinding
    raw_bytes: bytes


def capture_source(spec: SourceSpec) -> CapturedSource:
    path = spec.path.resolve(strict=True)
    before = path.stat()
    raw = path.read_bytes()
    after = path.stat()
    if (
        before.st_size != after.st_size
        or before.st_mtime_ns != after.st_mtime_ns
        or len(raw) != after.st_size
    ):
        raise LedgerError(f"source changed while being captured: {path}")
    binding = SourceBinding(
        source_id=spec.source_id,
        venue_id=spec.venue_id,
        account_id=spec.account_id,
        server=spec.server,
        role=spec.role,
        path=str(path),
        size_bytes=len(raw),
        mtime_ns=after.st_mtime_ns,
        sha256=sha256_bytes(raw),
    )
    return CapturedSource(spec=dataclasses.replace(spec, path=path), binding=binding, raw_bytes=raw)


def verify_source_binding(binding: SourceBinding) -> None:
    path = Path(binding.path)
    try:
        current = capture_source(
            SourceSpec(
                source_id=binding.source_id,
                venue_id=binding.venue_id,
                account_id=binding.account_id,
                server=binding.server,
                role=binding.role,
                path=path,
            )
        ).binding
    except (FileNotFoundError, OSError) as exc:
        raise LedgerError(f"bound source is no longer readable: {path}") from exc
    if current != binding:
        raise LedgerError(f"source hash/stat drift detected: {path}")


@dataclasses.dataclass(frozen=True)
class Provenance:
    source_id: str
    path: str
    line_number: int
    line_sha256: str

    def as_dict(self) -> dict[str, Any]:
        return dataclasses.asdict(self)


@dataclasses.dataclass(frozen=True)
class RequestRecord:
    venue_id: str
    account_id: str
    server: str
    raw_symbol: str
    side: str
    volume: Decimal
    reference_price: Decimal
    reference_kind: str
    execution_kind: str
    order_ticket: int | None
    deal_ticket: int | None
    ticket_hint: int | None
    magic: int | None
    ea_id: int | None
    request_time: str | None
    result_request_id: int | None
    provenance: tuple[Provenance, ...]


@dataclasses.dataclass(frozen=True)
class DealRecord:
    venue_id: str
    account_id: str
    server: str
    raw_symbol: str
    side: str
    volume: Decimal
    fill_price: Decimal
    deal_ticket: int
    order_ticket: int | None
    position_id: int | None
    fill_time: str | None
    entry_kind: str | None
    reason: str | None
    server_reference_price: Decimal | None
    server_reference_kind: str | None
    magic: int | None
    provenance: tuple[Provenance, ...]


@dataclasses.dataclass(frozen=True)
class SymbolProperties:
    venue_id: str
    account_id: str
    raw_symbol: str
    point: Decimal
    digits: int
    trade_tick_size: Decimal
    volume_step: Decimal


class AliasPolicy:
    def __init__(
        self,
        mapping: Mapping[tuple[str, str, str, str], str],
        *,
        qualification_scope: str,
        cross_venue_pooling: bool,
    ) -> None:
        self._mapping = dict(mapping)
        self.qualification_scope = qualification_scope
        self.cross_venue_pooling = cross_venue_pooling

    def resolve(self, venue_id: str, account_id: str, server: str, raw_symbol: str) -> str:
        key = (venue_id, account_id, server, raw_symbol)
        try:
            return self._mapping[key]
        except KeyError as exc:
            raise LedgerError(f"no exact symbol alias for {key!r}") from exc


def load_alias_policy_bytes(raw: bytes, *, label: str) -> AliasPolicy:
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise LedgerError(f"alias policy is not UTF-8: {label}") from exc
    root = _require_exact_keys(
        strict_json_loads(text, label=label),
        {
            "schema_version",
            "artifact_type",
            "status",
            "matching",
            "qualification_scope",
            "cross_venue_pooling_for_qualification",
            "venues",
        },
        label="alias policy",
    )
    if root["schema_version"] != 1 or root["artifact_type"] != ALIAS_ARTIFACT_TYPE:
        raise LedgerError("unsupported alias policy schema/artifact type")
    if root["status"] != "ACTIVE":
        raise LedgerError("alias policy is not ACTIVE")
    if root["matching"] != "EXACT_CASE_SENSITIVE_VENUE_ACCOUNT_SERVER_RAW_SYMBOL":
        raise LedgerError("alias policy must require exact matching")
    if root["qualification_scope"] != "VENUE_ACCOUNT_LOGICAL_SYMBOL":
        raise LedgerError("alias policy qualification scope is unsafe")
    if root["cross_venue_pooling_for_qualification"] is not False:
        raise LedgerError("cross-venue qualification pooling is forbidden")
    venues = root["venues"]
    if not isinstance(venues, list) or not venues:
        raise LedgerError("alias policy venues must be a non-empty array")
    mapping: dict[tuple[str, str, str, str], str] = {}
    venue_keys: set[tuple[str, str, str]] = set()
    for venue_index, venue_raw in enumerate(venues):
        venue = _require_exact_keys(
            venue_raw,
            {"venue_id", "account_id", "server", "symbols"},
            label=f"alias venue[{venue_index}]",
        )
        venue_id = _nonempty_string(venue["venue_id"], label="venue_id")
        account_id = _nonempty_string(venue["account_id"], label="account_id")
        server = _nonempty_string(venue["server"], label="server")
        venue_key = (venue_id, account_id, server)
        if venue_key in venue_keys:
            raise LedgerError(f"duplicate alias venue: {venue_key!r}")
        venue_keys.add(venue_key)
        symbols = venue["symbols"]
        if not isinstance(symbols, list) or not symbols:
            raise LedgerError(f"alias venue {venue_id} has no symbols")
        for symbol_index, symbol_raw in enumerate(symbols):
            symbol = _require_exact_keys(
                symbol_raw,
                {"raw_symbol", "logical_symbol"},
                label=f"alias venue[{venue_index}].symbols[{symbol_index}]",
            )
            raw_symbol = _nonempty_string(symbol["raw_symbol"], label="raw_symbol")
            logical_symbol = _nonempty_string(
                symbol["logical_symbol"], label="logical_symbol"
            )
            if not LOGICAL_SYMBOL_RE.fullmatch(logical_symbol):
                raise LedgerError(f"invalid logical symbol: {logical_symbol}")
            key = (*venue_key, raw_symbol)
            if key in mapping:
                raise LedgerError(f"duplicate exact symbol alias: {key!r}")
            mapping[key] = logical_symbol
    return AliasPolicy(
        mapping,
        qualification_scope=root["qualification_scope"],
        cross_venue_pooling=False,
    )


def _decode_text(raw: bytes, *, label: str) -> str:
    encodings = ("utf-16",) if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else ("utf-8-sig",)
    try:
        return raw.decode(encodings[0])
    except UnicodeDecodeError as exc:
        raise LedgerError(f"cannot decode {label} as {encodings[0]}") from exc


def _line_provenance(captured: CapturedSource, line_number: int, line: str) -> Provenance:
    return Provenance(
        source_id=captured.spec.source_id,
        path=str(captured.spec.path),
        line_number=line_number,
        line_sha256=sha256_bytes(line.encode("utf-8")),
    )


def _side_from_order_type(value: Any, *, label: str) -> str:
    if isinstance(value, bool):
        raise LedgerError(f"{label} order type invalid")
    if isinstance(value, (int, Decimal)):
        integer = _positive_int(value, label=label, allow_zero=True)
        if integer == 0:
            return "BUY"
        if integer == 1:
            return "SELL"
        raise LedgerError(f"{label} supports only BUY/SELL deal types")
    text = _nonempty_string(value, label=label).upper()
    if text.startswith("QM_BUY") or text in {"BUY", "ORDER_TYPE_BUY", "DEAL_TYPE_BUY"}:
        return "BUY"
    if text.startswith("QM_SELL") or text in {"SELL", "ORDER_TYPE_SELL", "DEAL_TYPE_SELL"}:
        return "SELL"
    raise LedgerError(f"{label} supports only BUY/SELL deal types: {value!r}")


def _optional_ticket(value: Any, *, label: str) -> int | None:
    if value is None or value == 0 or value == "0":
        return None
    return _positive_int(value, label=label)


def parse_ea_json_log(captured: CapturedSource) -> list[RequestRecord]:
    text = _decode_text(captured.raw_bytes, label=str(captured.spec.path))
    requests: list[RequestRecord] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        if not line.strip():
            continue
        row = strict_json_loads(line, label=f"{captured.spec.path}:{line_number}")
        if not isinstance(row, dict):
            raise LedgerError(f"EA log row must be an object: {captured.spec.path}:{line_number}")
        event = row.get("event")
        payload = row.get("payload")
        if event == "ENTRY_ACCEPTED":
            if not isinstance(payload, dict):
                raise LedgerError(f"ENTRY_ACCEPTED payload invalid at line {line_number}")
            ticket = _positive_int(payload.get("ticket"), label="ENTRY_ACCEPTED ticket")
            raw_symbol = _nonempty_string(payload.get("symbol"), label="ENTRY_ACCEPTED symbol")
            envelope_symbol = row.get("symbol")
            if envelope_symbol not in (None, raw_symbol):
                raise LedgerError("ENTRY_ACCEPTED envelope/payload symbol conflict")
            order_type = _nonempty_string(payload.get("type"), label="ENTRY_ACCEPTED type")
            side = _side_from_order_type(order_type, label="ENTRY_ACCEPTED type")
            pending = "_STOP" in order_type.upper() or "_LIMIT" in order_type.upper()
            requests.append(
                RequestRecord(
                    venue_id=captured.spec.venue_id,
                    account_id=captured.spec.account_id,
                    server=captured.spec.server,
                    raw_symbol=raw_symbol,
                    side=side,
                    volume=_decimal(payload.get("lots"), label="ENTRY_ACCEPTED lots", positive=True),
                    reference_price=_decimal(
                        payload.get("price"), label="ENTRY_ACCEPTED price", positive=True
                    ),
                    reference_kind="PENDING_TRIGGER_EXACT" if pending else "REQUEST_EXACT",
                    execution_kind="PENDING_ENTRY" if pending else "MARKET_ENTRY",
                    order_ticket=None,
                    deal_ticket=None,
                    ticket_hint=ticket,
                    magic=_optional_ticket(payload.get("magic"), label="ENTRY_ACCEPTED magic"),
                    ea_id=_optional_ticket(row.get("ea_id"), label="ENTRY_ACCEPTED ea_id"),
                    request_time=str(row.get("ts_utc")) if row.get("ts_utc") is not None else None,
                    result_request_id=None,
                    provenance=(_line_provenance(captured, line_number, line),),
                )
            )
        elif event in {"TM_CLOSE", "TM_PARTIAL_CLOSE"}:
            if not isinstance(payload, dict) or payload.get("schema_version") != 2:
                continue  # legacy close: it has no exact request-price reference
            if payload.get("ok") is not True:
                continue  # a rejected request produced no fill observation
            raw_symbol = _nonempty_string(payload.get("symbol"), label="TM_CLOSE symbol")
            requests.append(
                RequestRecord(
                    venue_id=captured.spec.venue_id,
                    account_id=captured.spec.account_id,
                    server=captured.spec.server,
                    raw_symbol=raw_symbol,
                    side=_side_from_order_type(
                        payload.get("request_type"), label="TM_CLOSE request_type"
                    ),
                    volume=_decimal(
                        payload.get("request_volume"), label="TM_CLOSE request_volume", positive=True
                    ),
                    reference_price=_decimal(
                        payload.get("request_price"), label="TM_CLOSE request_price", positive=True
                    ),
                    reference_kind="REQUEST_EXACT",
                    execution_kind="MARKET_CLOSE",
                    order_ticket=_optional_ticket(
                        payload.get("result_order"), label="TM_CLOSE result_order"
                    ),
                    deal_ticket=_optional_ticket(
                        payload.get("result_deal"), label="TM_CLOSE result_deal"
                    ),
                    ticket_hint=None,
                    magic=_optional_ticket(payload.get("magic"), label="TM_CLOSE magic"),
                    ea_id=_optional_ticket(row.get("ea_id"), label="TM_CLOSE ea_id"),
                    request_time=str(row.get("ts_utc")) if row.get("ts_utc") is not None else None,
                    result_request_id=_optional_ticket(
                        payload.get("result_request_id"), label="TM_CLOSE result_request_id"
                    ),
                    provenance=(_line_provenance(captured, line_number, line),),
                )
            )
    return requests


def parse_terminal_journal(captured: CapturedSource) -> list[DealRecord]:
    text = _decode_text(captured.raw_bytes, label=str(captured.spec.path))
    deals: list[DealRecord] = []
    date_match = re.fullmatch(r"(?P<date>\d{8})\.log", captured.spec.path.name)
    journal_date = date_match.group("date") if date_match else None
    for line_number, line in enumerate(text.splitlines(), start=1):
        match = JOURNAL_DEAL_RE.search(line)
        if not match or match.group("account") != captured.spec.account_id:
            continue
        fields = line.split("\t")
        clock = fields[2] if len(fields) >= 3 else None
        fill_time = f"{journal_date}T{clock}" if journal_date and clock else clock
        deals.append(
            DealRecord(
                venue_id=captured.spec.venue_id,
                account_id=captured.spec.account_id,
                server=captured.spec.server,
                raw_symbol=match.group("symbol"),
                side=match.group("side").upper(),
                volume=_decimal(match.group("volume"), label="journal deal volume", positive=True),
                fill_price=_decimal(match.group("price"), label="journal deal price", positive=True),
                deal_ticket=_positive_int(match.group("deal"), label="journal deal ticket"),
                order_ticket=_positive_int(match.group("order"), label="journal order ticket"),
                position_id=None,
                fill_time=fill_time,
                entry_kind=None,
                reason=None,
                server_reference_price=None,
                server_reference_kind=None,
                magic=None,
                provenance=(_line_provenance(captured, line_number, line),),
            )
        )
    return deals


HISTORY_DEAL_KEYS = {
    "account_id",
    "server",
    "deal_ticket",
    "order_ticket",
    "position_id",
    "time_msc",
    "type",
    "entry",
    "reason",
    "magic",
    "symbol",
    "volume",
    "price",
    "sl",
    "tp",
    "commission",
    "swap",
    "profit",
    "fee",
}


def parse_history_deals_jsonl(captured: CapturedSource) -> list[DealRecord]:
    text = _decode_text(captured.raw_bytes, label=str(captured.spec.path))
    deals: list[DealRecord] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        if not line.strip():
            continue
        row = _require_exact_keys(
            strict_json_loads(line, label=f"{captured.spec.path}:{line_number}"),
            HISTORY_DEAL_KEYS,
            label=f"history deal line {line_number}",
        )
        if str(row["account_id"]) != captured.spec.account_id or row["server"] != captured.spec.server:
            raise LedgerError(f"history deal source identity mismatch at line {line_number}")
        entry_kind = _nonempty_string(row["entry"], label="history deal entry").upper()
        reason = _nonempty_string(row["reason"], label="history deal reason").upper()
        sl = _decimal(row["sl"], label="history deal sl")
        tp = _decimal(row["tp"], label="history deal tp")
        reference: Decimal | None = None
        reference_kind: str | None = None
        if entry_kind in {"DEAL_ENTRY_OUT", "DEAL_ENTRY_OUT_BY", "DEAL_ENTRY_INOUT"}:
            if reason == "DEAL_REASON_SL" and sl > 0:
                reference = sl
                reference_kind = "SERVER_LEVEL_EXACT"
            elif reason == "DEAL_REASON_TP" and tp > 0:
                reference = tp
                reference_kind = "SERVER_LEVEL_EXACT"
        deals.append(
            DealRecord(
                venue_id=captured.spec.venue_id,
                account_id=captured.spec.account_id,
                server=captured.spec.server,
                raw_symbol=_nonempty_string(row["symbol"], label="history deal symbol"),
                side=_side_from_order_type(row["type"], label="history deal type"),
                volume=_decimal(row["volume"], label="history deal volume", positive=True),
                fill_price=_decimal(row["price"], label="history deal price", positive=True),
                deal_ticket=_positive_int(row["deal_ticket"], label="history deal ticket"),
                order_ticket=_optional_ticket(row["order_ticket"], label="history order ticket"),
                position_id=_optional_ticket(row["position_id"], label="history position id"),
                fill_time=str(row["time_msc"]),
                entry_kind=entry_kind,
                reason=reason,
                server_reference_price=reference,
                server_reference_kind=reference_kind,
                magic=_optional_ticket(row["magic"], label="history magic"),
                provenance=(_line_provenance(captured, line_number, line),),
            )
        )
    return deals


def _unique_provenance(values: Iterable[Provenance]) -> tuple[Provenance, ...]:
    return tuple(
        sorted(
            set(values),
            key=lambda item: (item.source_id, item.path, item.line_number, item.line_sha256),
        )
    )


def _request_key(request: RequestRecord) -> tuple[str, str, str, int]:
    if request.deal_ticket is not None:
        return (request.venue_id, request.account_id, "DEAL", request.deal_ticket)
    if request.order_ticket is not None:
        return (request.venue_id, request.account_id, "ORDER", request.order_ticket)
    if request.ticket_hint is not None:
        return (request.venue_id, request.account_id, "HINT", request.ticket_hint)
    raise LedgerError("request has no ticket identity")


def _merge_optional(left: Any, right: Any, *, label: str) -> Any:
    if left is None:
        return right
    if right is None:
        return left
    if left != right:
        raise LedgerError(f"conflicting duplicate {label}: {left!r} != {right!r}")
    return left


def deduplicate_requests(requests: Iterable[RequestRecord]) -> list[RequestRecord]:
    merged: dict[tuple[str, str, str, int], RequestRecord] = {}
    for request in requests:
        key = _request_key(request)
        existing = merged.get(key)
        if existing is None:
            merged[key] = request
            continue
        semantic_fields = (
            "venue_id",
            "account_id",
            "server",
            "raw_symbol",
            "side",
            "volume",
            "reference_price",
            "reference_kind",
            "execution_kind",
        )
        if any(getattr(existing, field) != getattr(request, field) for field in semantic_fields):
            raise LedgerError(f"conflicting duplicate request for {key!r}")
        merged[key] = dataclasses.replace(
            existing,
            order_ticket=_merge_optional(
                existing.order_ticket, request.order_ticket, label="request order ticket"
            ),
            deal_ticket=_merge_optional(
                existing.deal_ticket, request.deal_ticket, label="request deal ticket"
            ),
            ticket_hint=_merge_optional(
                existing.ticket_hint, request.ticket_hint, label="request ticket hint"
            ),
            magic=_merge_optional(existing.magic, request.magic, label="request magic"),
            ea_id=_merge_optional(existing.ea_id, request.ea_id, label="request ea_id"),
            request_time=_merge_optional(
                existing.request_time, request.request_time, label="request time"
            ),
            result_request_id=_merge_optional(
                existing.result_request_id,
                request.result_request_id,
                label="request result_request_id",
            ),
            provenance=_unique_provenance((*existing.provenance, *request.provenance)),
        )
    return sorted(merged.values(), key=_request_key)


def deduplicate_deals(deals: Iterable[DealRecord]) -> list[DealRecord]:
    merged: dict[tuple[str, str, int], DealRecord] = {}
    for deal in deals:
        key = (deal.venue_id, deal.account_id, deal.deal_ticket)
        existing = merged.get(key)
        if existing is None:
            merged[key] = deal
            continue
        semantic_fields = (
            "venue_id",
            "account_id",
            "server",
            "raw_symbol",
            "side",
            "volume",
            "fill_price",
        )
        if any(getattr(existing, field) != getattr(deal, field) for field in semantic_fields):
            raise LedgerError(f"conflicting duplicate deal for {key!r}")
        if existing.entry_kind is not None and deal.entry_kind is not None:
            fill_time = _merge_optional(
                existing.fill_time, deal.fill_time, label="history deal fill time"
            )
        elif deal.entry_kind is not None:
            fill_time = deal.fill_time
        else:
            fill_time = existing.fill_time or deal.fill_time
        merged[key] = dataclasses.replace(
            existing,
            order_ticket=_merge_optional(
                existing.order_ticket, deal.order_ticket, label="deal order ticket"
            ),
            position_id=_merge_optional(
                existing.position_id, deal.position_id, label="deal position id"
            ),
            fill_time=fill_time,
            entry_kind=_merge_optional(
                existing.entry_kind, deal.entry_kind, label="deal entry kind"
            ),
            reason=_merge_optional(existing.reason, deal.reason, label="deal reason"),
            server_reference_price=_merge_optional(
                existing.server_reference_price,
                deal.server_reference_price,
                label="deal server reference price",
            ),
            server_reference_kind=_merge_optional(
                existing.server_reference_kind,
                deal.server_reference_kind,
                label="deal server reference kind",
            ),
            magic=_merge_optional(existing.magic, deal.magic, label="deal magic"),
            provenance=_unique_provenance((*existing.provenance, *deal.provenance)),
        )
    return sorted(merged.values(), key=lambda item: (item.venue_id, item.account_id, item.deal_ticket))


def load_symbol_properties(raw_rows: Any) -> dict[tuple[str, str, str], SymbolProperties]:
    if not isinstance(raw_rows, list) or not raw_rows:
        raise LedgerError("symbol_properties must be a non-empty array")
    result: dict[tuple[str, str, str], SymbolProperties] = {}
    expected = {
        "venue_id",
        "account_id",
        "raw_symbol",
        "point",
        "digits",
        "trade_tick_size",
        "volume_step",
    }
    for index, raw in enumerate(raw_rows):
        row = _require_exact_keys(raw, expected, label=f"symbol_properties[{index}]")
        properties = SymbolProperties(
            venue_id=_nonempty_string(row["venue_id"], label="symbol venue_id"),
            account_id=_nonempty_string(row["account_id"], label="symbol account_id"),
            raw_symbol=_nonempty_string(row["raw_symbol"], label="symbol raw_symbol"),
            point=_decimal(row["point"], label="symbol point", positive=True),
            digits=_positive_int(row["digits"], label="symbol digits", allow_zero=True),
            trade_tick_size=_decimal(
                row["trade_tick_size"], label="symbol trade_tick_size", positive=True
            ),
            volume_step=_decimal(row["volume_step"], label="symbol volume_step", positive=True),
        )
        tick_ratio = properties.trade_tick_size / properties.point
        if tick_ratio != tick_ratio.to_integral_value():
            raise LedgerError(
                f"trade_tick_size must be an integer multiple of point for {properties.raw_symbol}"
            )
        key = (properties.venue_id, properties.account_id, properties.raw_symbol)
        if key in result:
            raise LedgerError(f"duplicate symbol properties: {key!r}")
        result[key] = properties
    return result


def _request_maps(
    requests: Sequence[RequestRecord],
) -> tuple[
    Mapping[tuple[str, str, int], list[RequestRecord]],
    Mapping[tuple[str, str, int], list[RequestRecord]],
    Mapping[tuple[str, str, int], list[RequestRecord]],
]:
    by_deal: dict[tuple[str, str, int], list[RequestRecord]] = defaultdict(list)
    by_order: dict[tuple[str, str, int], list[RequestRecord]] = defaultdict(list)
    by_hint: dict[tuple[str, str, int], list[RequestRecord]] = defaultdict(list)
    for request in requests:
        prefix = (request.venue_id, request.account_id)
        if request.deal_ticket is not None:
            by_deal[(*prefix, request.deal_ticket)].append(request)
        if request.order_ticket is not None:
            by_order[(*prefix, request.order_ticket)].append(request)
        if request.ticket_hint is not None:
            by_hint[(*prefix, request.ticket_hint)].append(request)
    return by_deal, by_order, by_hint


def _one_request(candidates: Sequence[RequestRecord], *, label: str) -> RequestRecord | None:
    unique = {_request_key(candidate): candidate for candidate in candidates}
    if len(unique) > 1:
        raise LedgerError(f"ambiguous request join for {label}: {sorted(unique)}")
    return next(iter(unique.values()), None)


def _signed_slippage(side: str, fill: Decimal, reference: Decimal) -> Decimal:
    if side == "BUY":
        return fill - reference
    if side == "SELL":
        return reference - fill
    raise LedgerError(f"unsupported execution side: {side}")


def build_observations(
    requests: Iterable[RequestRecord],
    deals: Iterable[DealRecord],
    *,
    aliases: AliasPolicy,
    symbol_properties: Mapping[tuple[str, str, str], SymbolProperties],
) -> list[dict[str, Any]]:
    request_rows = deduplicate_requests(requests)
    deal_rows = deduplicate_deals(deals)
    by_deal, by_order, by_hint = _request_maps(request_rows)
    groups: dict[tuple[str, str, int, int], list[DealRecord]] = defaultdict(list)
    for deal in deal_rows:
        groups[
            (
                deal.venue_id,
                deal.account_id,
                deal.order_ticket or 0,
                0 if deal.order_ticket is not None else deal.deal_ticket,
            )
        ].append(deal)

    observations: list[dict[str, Any]] = []
    for group_key in sorted(groups):
        group = sorted(groups[group_key], key=lambda item: item.deal_ticket)
        first = group[0]
        for deal in group[1:]:
            if (
                deal.server != first.server
                or deal.raw_symbol != first.raw_symbol
                or deal.side != first.side
            ):
                raise LedgerError(f"order group has conflicting deal identity: {group_key!r}")
        properties_key = (first.venue_id, first.account_id, first.raw_symbol)
        try:
            properties = symbol_properties[properties_key]
        except KeyError as exc:
            raise LedgerError(f"missing symbol properties for {properties_key!r}") from exc
        logical_symbol = aliases.resolve(
            first.venue_id, first.account_id, first.server, first.raw_symbol
        )

        direct = [
            candidate
            for deal in group
            for candidate in by_deal.get(
                (deal.venue_id, deal.account_id, deal.deal_ticket), []
            )
        ]
        order_ticket = first.order_ticket
        explicit_order = (
            by_order.get((first.venue_id, first.account_id, order_ticket), [])
            if order_ticket is not None
            else []
        )
        hinted_order = (
            by_hint.get((first.venue_id, first.account_id, order_ticket), [])
            if order_ticket is not None
            else []
        )
        hinted_deal = [
            candidate
            for deal in group
            for candidate in by_hint.get(
                (deal.venue_id, deal.account_id, deal.deal_ticket), []
            )
        ]
        if direct:
            request = _one_request(direct, label=f"deal {first.deal_ticket}")
            join_method = "RESULT_DEAL_EXACT"
        elif explicit_order:
            request = _one_request(explicit_order, label=f"order {order_ticket}")
            join_method = "RESULT_ORDER_EXACT"
        elif hinted_order:
            request = _one_request(hinted_order, label=f"entry order {order_ticket}")
            join_method = "ENTRY_TICKET_TO_ORDER_EXACT"
        elif hinted_deal:
            request = _one_request(hinted_deal, label=f"entry deal {first.deal_ticket}")
            join_method = "ENTRY_TICKET_TO_DEAL_EXACT"
        else:
            request = None
            join_method = "NO_REQUEST_JOIN"

        total_volume = sum((deal.volume for deal in group), Decimal(0))
        with localcontext() as context:
            context.prec = 50
            fill_vwap = sum(
                (deal.fill_price * deal.volume for deal in group), Decimal(0)
            ) / total_volume

        diagnostic_reasons: list[str] = []
        volume_complete = True
        if request is not None:
            if (
                request.server != first.server
                or request.raw_symbol != first.raw_symbol
                or request.side != first.side
            ):
                raise LedgerError(f"request/deal identity conflict for {group_key!r}")
            tolerance = properties.volume_step / Decimal(2)
            if total_volume - request.volume > tolerance:
                raise LedgerError(f"filled volume exceeds request for {group_key!r}")
            volume_complete = abs(total_volume - request.volume) <= tolerance
            if not volume_complete:
                diagnostic_reasons.append("PARTIAL_VOLUME_INCOMPLETE")
            reference_price = request.reference_price
            reference_kind = request.reference_kind
            execution_kind = request.execution_kind
        else:
            exact_levels = {
                (deal.server_reference_kind, deal.server_reference_price)
                for deal in group
                if deal.server_reference_kind is not None
                and deal.server_reference_price is not None
            }
            if len(exact_levels) > 1:
                raise LedgerError(f"conflicting exact server levels for {group_key!r}")
            if exact_levels:
                reference_kind, reference_price = next(iter(exact_levels))
                reasons = {deal.reason for deal in group}
                execution_kind = (
                    "SL_EXIT" if reasons == {"DEAL_REASON_SL"} else "TP_EXIT"
                    if reasons == {"DEAL_REASON_TP"}
                    else "SERVER_EXIT"
                )
                join_method = "HISTORY_SERVER_LEVEL_EXACT"
            else:
                reference_price = None
                reference_kind = "NONE"
                execution_kind = "UNREFERENCED_EXECUTION"
                diagnostic_reasons.append("NO_EXACT_REFERENCE")

        signed_price: Decimal | None = None
        signed_points: Decimal | None = None
        adverse_points: Decimal | None = None
        signed_bps: Decimal | None = None
        if reference_price is not None:
            with localcontext() as context:
                context.prec = 50
                signed_price = _signed_slippage(first.side, fill_vwap, reference_price)
                signed_points = signed_price / properties.point
                adverse_points = max(Decimal(0), signed_points)
                signed_bps = signed_price / fill_vwap * Decimal(10000)

        eligible = (
            reference_kind in ELIGIBLE_REFERENCE_KINDS
            and reference_price is not None
            and volume_complete
        )
        if not eligible and not diagnostic_reasons:
            diagnostic_reasons.append("REFERENCE_NOT_QUALIFICATION_ELIGIBLE")
        identity = {
            "venue_id": first.venue_id,
            "account_id": first.account_id,
            "order_ticket": order_ticket or 0,
            "deal_tickets": [deal.deal_ticket for deal in group],
            "reference_kind": reference_kind,
        }
        observation_id = sha256_bytes(canonical_json_bytes(identity))
        observations.append(
            {
                "observation_id": observation_id,
                "venue_id": first.venue_id,
                "account_id": first.account_id,
                "server": first.server,
                "logical_symbol": logical_symbol,
                "raw_symbol": first.raw_symbol,
                "symbol_point": canonical_decimal(properties.point),
                "digits": properties.digits,
                "trade_tick_size": canonical_decimal(properties.trade_tick_size),
                "volume_step": canonical_decimal(properties.volume_step),
                "order_ticket": order_ticket,
                "deal_tickets": [deal.deal_ticket for deal in group],
                "position_ids": sorted(
                    {deal.position_id for deal in group if deal.position_id is not None}
                ),
                "magic": request.magic if request is not None else first.magic,
                "ea_id": request.ea_id if request is not None else None,
                "result_request_id": request.result_request_id if request is not None else None,
                "execution_kind": execution_kind,
                "side": first.side,
                "request_time": request.request_time if request is not None else None,
                "fill_times": [deal.fill_time for deal in group if deal.fill_time is not None],
                "requested_volume": canonical_decimal(request.volume)
                if request is not None
                else None,
                "filled_volume": canonical_decimal(total_volume),
                "volume_complete": volume_complete,
                "reference_price": canonical_decimal(reference_price)
                if reference_price is not None
                else None,
                "fill_vwap": canonical_decimal(fill_vwap),
                "signed_slip_price": canonical_decimal(signed_price)
                if signed_price is not None
                else None,
                "signed_slip_points": canonical_decimal(signed_points)
                if signed_points is not None
                else None,
                "adverse_points": canonical_decimal(adverse_points)
                if adverse_points is not None
                else None,
                "signed_slip_bps": canonical_decimal(signed_bps)
                if signed_bps is not None
                else None,
                "reference_kind": reference_kind,
                "eligibility": "QUALIFICATION" if eligible else "DIAGNOSTIC",
                "diagnostic_reasons": diagnostic_reasons,
                "join_confidence": "EXACT" if reference_price is not None else "NONE",
                "join_method": join_method,
                "request_provenance": [item.as_dict() for item in request.provenance]
                if request is not None
                else [],
                "fill_provenance": [
                    item.as_dict()
                    for deal in group
                    for item in deal.provenance
                ],
            }
        )
    return sorted(observations, key=lambda row: row["observation_id"])


def build_ledger_summary(
    ledger_id: str,
    cutoff_utc: str,
    generated_utc: str,
    observations: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    grouped: dict[tuple[str, str, str, str], list[Mapping[str, Any]]] = defaultdict(list)
    for observation in observations:
        grouped[
            (
                str(observation["venue_id"]),
                str(observation["account_id"]),
                str(observation["server"]),
                str(observation["logical_symbol"]),
            )
        ].append(observation)
    summaries: list[dict[str, Any]] = []
    for key in sorted(grouped):
        rows = grouped[key]
        eligible = [row for row in rows if row["eligibility"] == "QUALIFICATION"]
        adverse = [
            _decimal(row["adverse_points"], label="observation adverse_points")
            for row in eligible
        ]
        p95 = nearest_rank(adverse) if adverse else None
        observed_max = max(adverse) if adverse else None
        qualifies = (
            len(adverse) >= MINIMUM_SAMPLES_PER_SYMBOL
            and p95 is not None
            and p95 > 0
            and observed_max is not None
            and observed_max > 0
        )
        summaries.append(
            {
                "venue_id": key[0],
                "account_id": key[1],
                "server": key[2],
                "logical_symbol": key[3],
                "raw_symbols": sorted({str(row["raw_symbol"]) for row in rows}),
                "total_observations": len(rows),
                "eligible_samples": len(adverse),
                "diagnostic_observations": len(rows) - len(adverse),
                "p95_adverse_points": canonical_decimal(p95) if p95 is not None else None,
                "observed_max_adverse_points": canonical_decimal(observed_max)
                if observed_max is not None
                else None,
                "qualification_status": "PASS" if qualifies else "UNRESOLVED",
            }
        )
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": ARTIFACT_TYPE,
        "ledger_id": ledger_id,
        "status": "FROZEN",
        "immutable": True,
        "generated_utc": generated_utc,
        "cutoff_utc": cutoff_utc,
        "policy": {
            "minimum_samples_per_symbol": MINIMUM_SAMPLES_PER_SYMBOL,
            "quantile": canonical_decimal(QUANTILE),
            "quantile_method": QUANTILE_METHOD,
            "sample_unit": "EXECUTED_ORDER_VWAP",
            "sign_convention": "POSITIVE_ADVERSE_NEGATIVE_IMPROVEMENT",
            "eligible_reference_kinds": sorted(ELIGIBLE_REFERENCE_KINDS),
            "qualification_scope": "VENUE_ACCOUNT_LOGICAL_SYMBOL",
            "cross_venue_pooling_for_qualification": False,
        },
        "counts": {
            "observations": len(observations),
            "eligible": sum(
                1 for row in observations if row["eligibility"] == "QUALIFICATION"
            ),
            "diagnostic": sum(
                1 for row in observations if row["eligibility"] == "DIAGNOSTIC"
            ),
        },
        "symbols": summaries,
    }


def _parse_source_specs(raw_sources: Any, *, base_dir: Path) -> list[SourceSpec]:
    if not isinstance(raw_sources, list) or not raw_sources:
        raise LedgerError("sources must be a non-empty array")
    expected = {"source_id", "venue_id", "account_id", "server", "role", "path"}
    result: list[SourceSpec] = []
    ids: set[str] = set()
    for index, raw in enumerate(raw_sources):
        row = _require_exact_keys(raw, expected, label=f"sources[{index}]")
        source_id = _nonempty_string(row["source_id"], label="source_id")
        if source_id in RESERVED_SOURCE_IDS:
            raise LedgerError(f"source_id is reserved: {source_id}")
        if source_id in ids:
            raise LedgerError(f"duplicate source_id: {source_id}")
        ids.add(source_id)
        role = _nonempty_string(row["role"], label="source role")
        if role not in SOURCE_ROLES:
            raise LedgerError(f"unsupported source role: {role}")
        path = Path(_nonempty_string(row["path"], label="source path"))
        if not path.is_absolute():
            path = base_dir / path
        result.append(
            SourceSpec(
                source_id=source_id,
                venue_id=_nonempty_string(row["venue_id"], label="source venue_id"),
                account_id=_nonempty_string(row["account_id"], label="source account_id"),
                server=_nonempty_string(row["server"], label="source server"),
                role=role,
                path=path,
            )
        )
    return sorted(result, key=lambda item: item.source_id)


def _generic_binding(source_id: str, role: str, path: Path) -> CapturedSource:
    return capture_source(
        SourceSpec(
            source_id=source_id,
            venue_id="GLOBAL",
            account_id="GLOBAL",
            server="GLOBAL",
            role=role,
            path=path,
        )
    )


def _validate_iso_utc(value: Any, *, label: str) -> str:
    text = _nonempty_string(value, label=label)
    try:
        parsed = dt.datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError as exc:
        raise LedgerError(f"{label} must be ISO-8601") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != dt.timedelta(0):
        raise LedgerError(f"{label} must carry UTC timezone")
    return text


def _source_set_sha(bindings: Sequence[SourceBinding]) -> str:
    tuples = [
        [binding.source_id, binding.role, binding.path, binding.sha256]
        for binding in sorted(bindings, key=lambda item: item.source_id)
    ]
    return sha256_bytes(canonical_json_bytes(tuples))


def _write_bundle_exclusive(
    output_dir: Path,
    observations_bytes: bytes,
    ledger_bytes: bytes,
    manifest_bytes: bytes,
) -> None:
    output_dir = output_dir.resolve()
    output_dir.parent.mkdir(parents=True, exist_ok=True)
    if output_dir.exists():
        raise LedgerError(f"output directory already exists: {output_dir}")
    staging = output_dir.parent / f".{output_dir.name}.tmp-{uuid.uuid4().hex}"
    staging.mkdir()
    try:
        (staging / "observations.jsonl").write_bytes(observations_bytes)
        (staging / "ledger.json").write_bytes(ledger_bytes)
        (staging / "manifest.json").write_bytes(manifest_bytes)
        manifest_sha = sha256_bytes(manifest_bytes)
        (staging / "manifest.json.sha256").write_text(
            f"{manifest_sha}  manifest.json\n", encoding="ascii", newline="\n"
        )
        os.rename(staging, output_dir)
    except BaseException:
        if staging.exists():
            shutil.rmtree(staging)
        raise


def build_bundle(
    spec_path: Path,
    output_dir: Path,
    *,
    generated_utc: str | None = None,
) -> dict[str, Any]:
    """Build one immutable ledger bundle from an explicit offline spec."""

    spec_capture = _generic_binding("INPUT_SPEC", "INPUT_SPEC", spec_path)
    spec = _require_exact_keys(
        strict_json_loads(
            _decode_text(spec_capture.raw_bytes, label=str(spec_capture.spec.path)),
            label=str(spec_capture.spec.path),
        ),
        {
            "schema_version",
            "ledger_id",
            "cutoff_utc",
            "alias_policy",
            "symbol_properties",
            "sources",
        },
        label="ledger input spec",
    )
    if spec["schema_version"] != 1:
        raise LedgerError("unsupported ledger input spec schema_version")
    ledger_id = _nonempty_string(spec["ledger_id"], label="ledger_id")
    cutoff_utc = _validate_iso_utc(spec["cutoff_utc"], label="cutoff_utc")
    generated = _validate_iso_utc(
        generated_utc or dt.datetime.now(dt.UTC).isoformat(), label="generated_utc"
    )
    spec_dir = spec_capture.spec.path.parent
    alias_path = Path(_nonempty_string(spec["alias_policy"], label="alias_policy"))
    if not alias_path.is_absolute():
        alias_path = spec_dir / alias_path
    alias_capture = _generic_binding("ALIAS_POLICY", "ALIAS_POLICY", alias_path)
    aliases = load_alias_policy_bytes(alias_capture.raw_bytes, label=str(alias_path))
    properties = load_symbol_properties(spec["symbol_properties"])
    source_specs = _parse_source_specs(spec["sources"], base_dir=spec_dir)
    captured = [capture_source(source_spec) for source_spec in source_specs]
    generator_capture = _generic_binding(
        "GENERATOR", "GENERATOR", Path(__file__).resolve()
    )

    requests: list[RequestRecord] = []
    deals: list[DealRecord] = []
    parsed_rows: dict[str, int] = {}
    for source in captured:
        if source.spec.role == "EA_JSON_LOG":
            rows = parse_ea_json_log(source)
            requests.extend(rows)
        elif source.spec.role == "TERMINAL_JOURNAL":
            rows = parse_terminal_journal(source)
            deals.extend(rows)
        elif source.spec.role == "HISTORY_DEALS_JSONL":
            rows = parse_history_deals_jsonl(source)
            deals.extend(rows)
        else:  # pragma: no cover - guarded while parsing the spec
            raise LedgerError(f"unsupported source role: {source.spec.role}")
        parsed_rows[source.spec.source_id] = len(rows)

    observations = build_observations(
        requests,
        deals,
        aliases=aliases,
        symbol_properties=properties,
    )
    ledger = build_ledger_summary(ledger_id, cutoff_utc, generated, observations)
    observations_bytes = b"".join(
        canonical_json_bytes(observation) + b"\n" for observation in observations
    )
    ledger_bytes = pretty_json_bytes(ledger)

    all_captures = [spec_capture, alias_capture, generator_capture, *captured]
    for source in all_captures:
        verify_source_binding(source.binding)
    bindings = [source.binding for source in all_captures]
    source_records = []
    for binding in sorted(bindings, key=lambda item: item.source_id):
        record = binding.manifest_record()
        record["parsed_rows"] = parsed_rows.get(binding.source_id)
        source_records.append(record)
    manifest = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": ARTIFACT_TYPE,
        "ledger_id": ledger_id,
        "status": "FROZEN",
        "immutable": True,
        "generated_utc": generated,
        "cutoff_utc": cutoff_utc,
        "generator": {
            "path": generator_capture.binding.path,
            "sha256": generator_capture.binding.sha256,
            "python": sys.version.split()[0],
        },
        "policy": ledger["policy"],
        "sources": source_records,
        "source_set_sha256": _source_set_sha(bindings),
        "artifacts": {
            "observations": {
                "path": "observations.jsonl",
                "size_bytes": len(observations_bytes),
                "sha256": sha256_bytes(observations_bytes),
                "rows": len(observations),
                "eligible": ledger["counts"]["eligible"],
                "diagnostic": ledger["counts"]["diagnostic"],
            },
            "ledger": {
                "path": "ledger.json",
                "size_bytes": len(ledger_bytes),
                "sha256": sha256_bytes(ledger_bytes),
            },
        },
        "counts": ledger["counts"],
        "errors": [],
    }
    manifest_bytes = pretty_json_bytes(manifest)
    _write_bundle_exclusive(output_dir, observations_bytes, ledger_bytes, manifest_bytes)
    return manifest


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, required=True, help="Exact offline input spec")
    parser.add_argument("--output-dir", type=Path, required=True, help="New immutable output dir")
    parser.add_argument(
        "--generated-utc",
        help="Optional fixed ISO-8601 UTC generation time (for reproducible runs)",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        manifest = build_bundle(
            args.spec,
            args.output_dir,
            generated_utc=args.generated_utc,
        )
    except (LedgerError, FileNotFoundError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(manifest, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
