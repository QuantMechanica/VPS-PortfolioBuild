#!/usr/bin/env python3
"""Shared execution primitives for the Velocity research harness v2.

This module is deliberately read-only.  It decodes the terminal's MT5 custom
tick cache (``.tkc``) so an offline prescreen can observe the same bid/ask pair
that the real-tick tester saw at order placement.  It also centralises the
fail-closed OCO and gap-through rules used by the F1 and H-V prescreens.

The decoded TKC layout is bound by CRC and length checks on every stream:

* 228-byte file header (magic ``0x01fd``), followed by 31 day table slots;
* 48-byte day entries (12 little-endian uint32 values);
* 383-byte day header, then independently zlib-compressed column streams;
* stream types 1/2/4 are delta milliseconds / bid / ask respectively.

No archive, terminal setting, registry, card, EA, or factory row is changed.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import struct
import sys
import zlib
from array import array
from collections import defaultdict
from dataclasses import asdict, dataclass
from functools import lru_cache
from pathlib import Path
from typing import Iterable

REPO = Path("C:/QM/repo")
TKC_HEADER = 228
TKC_MAGIC = 0x01FD
TKC_DAY_SLOTS = 31
TKC_DAY_ENTRY = struct.Struct("<12I")
TKC_DAY_HEADER = 383
TKC_STREAM_COUNT_OFFSET = 0xA3
TKC_STREAM_TABLE_OFFSET = 0xA7
TKC_STREAM_DESC = struct.Struct("<9I")
TKC_STREAM_TIME_MSC = 1
TKC_STREAM_BID = 2
TKC_STREAM_ASK = 4
TKC_TERMINALS = tuple(
    Path(f"D:/QM/mt5/T{i}/Bases/Custom/ticks") for i in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
)
CUSTOM_SYMBOL_CATALOG = Path("D:/QM/mt5/T1/Bases/symbols.custom.dat")
TESTER_DEFAULTS = REPO / "framework/registry/tester_defaults.json"
TESTER_STOP_LEVEL_EVIDENCE = REPO / "docs/ops/FRAMEWORK_LATENT_DEFECT_AUDIT_2026-07-06.md"


class TickArchiveError(RuntimeError):
    """The tick archive exists but does not satisfy the decoded format contract."""


@dataclass(frozen=True)
class TickQuote:
    requested_epoch: int
    tick_time_msc: int
    bid: float
    ask: float
    source_path: str

    @property
    def spread(self) -> float:
        return self.ask - self.bid

    def to_dict(self) -> dict:
        out = asdict(self)
        out["spread"] = self.spread
        return out


@dataclass(frozen=True)
class SymbolExecutionSpec:
    symbol: str
    point: float
    stops_level_points: int
    freeze_level_points: int
    source: str
    tester_defaults_sha256: str
    custom_symbol_catalog_sha256: str

    @property
    def minimum_distance(self) -> float:
        return max(self.stops_level_points, self.freeze_level_points) * self.point

    def to_dict(self) -> dict:
        out = asdict(self)
        out["minimum_distance"] = self.minimum_distance
        return out


@dataclass(frozen=True)
class PlacementDecision:
    status: str
    buy_ok: bool | None
    sell_ok: bool | None
    reason: str
    bid: float | None
    ask: float | None
    minimum_distance: float

    @property
    def pair_accepted(self) -> bool:
        return self.status == "PAIR_ACCEPTED"

    def to_dict(self) -> dict:
        return asdict(self)


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


@lru_cache(maxsize=1)
def _execution_source_hashes() -> tuple[str, str]:
    if not TESTER_DEFAULTS.is_file():
        raise FileNotFoundError(TESTER_DEFAULTS)
    if not CUSTOM_SYMBOL_CATALOG.is_file():
        raise FileNotFoundError(CUSTOM_SYMBOL_CATALOG)
    # Parsing this also proves that the bound registry file is valid JSON.  Its
    # fixed-risk and tester-model settings remain unchanged by this tool.
    json.loads(TESTER_DEFAULTS.read_text(encoding="utf-8"))
    return _sha256(TESTER_DEFAULTS), _sha256(CUSTOM_SYMBOL_CATALOG)


def tester_execution_spec(symbol: str, point: float) -> SymbolExecutionSpec:
    """Return the governed custom-tester distance defaults for a .DWX symbol.

    The fleet custom symbols use the MT5 custom-symbol defaults of zero stops
    and freeze points.  That tester fact is already recorded in
    ``FRAMEWORK_LATENT_DEFECT_AUDIT_2026-07-06.md`` ("0 on .DWX in tester").
    We bind both the canonical tester-default registry and the actual encrypted
    custom-symbol catalogue by SHA-256 rather than inventing a live-venue
    distance.  Non-.DWX symbols fail closed.
    """
    if not symbol.endswith(".DWX"):
        raise ValueError(f"no governed custom-tester distance default for {symbol}")
    if point <= 0:
        raise ValueError(f"invalid point for {symbol}: {point}")
    if not TESTER_STOP_LEVEL_EVIDENCE.is_file():
        raise FileNotFoundError(TESTER_STOP_LEVEL_EVIDENCE)
    evidence = TESTER_STOP_LEVEL_EVIDENCE.read_text(encoding="utf-8")
    if "SYMBOL_TRADE_STOPS_LEVEL (0 on .DWX in tester" not in evidence:
        raise ValueError("bound .DWX tester stop-level evidence is absent")
    defaults_sha, catalogue_sha = _execution_source_hashes()
    return SymbolExecutionSpec(
        symbol=symbol,
        point=point,
        stops_level_points=0,
        freeze_level_points=0,
        source=(
            "MT5 .DWX custom-tester defaults; stop-level value recorded in "
            "docs/ops/FRAMEWORK_LATENT_DEFECT_AUDIT_2026-07-06.md and bound "
            "to D:/QM/mt5/T1/Bases/symbols.custom.dat"
        ),
        tester_defaults_sha256=defaults_sha,
        custom_symbol_catalog_sha256=catalogue_sha,
    )


def infer_point_from_prices(prices: Iterable[float], max_digits: int = 8) -> float:
    """Infer the imported custom symbol's point from its stored quote precision."""
    sample = [float(p) for p in prices if p and p > 0]
    if not sample:
        raise ValueError("cannot infer point from an empty price sample")
    for digits in range(max_digits + 1):
        scale = 10**digits
        if all(abs(p * scale - round(p * scale)) <= 1e-7 for p in sample):
            return 1.0 / scale
    raise ValueError(f"price precision exceeds {max_digits} digits")


def validate_oco_placement(
    buy_stop: float,
    sell_stop: float,
    quote: TickQuote | None,
    spec: SymbolExecutionSpec,
) -> PlacementDecision:
    """Validate both pending-stop sides against ask/bid and fail closed.

    MT5 validates a buy stop against Ask and a sell stop against Bid.  A single
    accepted side is not a trade: the EA cancels that survivor, so the harness
    returns ``CANCEL_NO_TRADE_ONE_SIDED``.
    """
    if quote is None:
        return PlacementDecision(
            "UNKNOWN", None, None, "tick_quote_unavailable", None, None, spec.minimum_distance
        )
    if quote.bid <= 0 or quote.ask <= 0 or quote.ask < quote.bid:
        return PlacementDecision(
            "UNKNOWN", None, None, "invalid_tick_quote", quote.bid, quote.ask, spec.minimum_distance
        )
    eps = spec.point * 1e-7
    buy_distance = buy_stop - quote.ask
    sell_distance = quote.bid - sell_stop
    # A pending stop must first be strictly on the correct side of the market.
    # A non-zero broker distance may itself be met at equality.
    buy_ok = buy_distance > eps and buy_distance + eps >= spec.minimum_distance
    sell_ok = sell_distance > eps and sell_distance + eps >= spec.minimum_distance
    if buy_ok and sell_ok:
        status, reason = "PAIR_ACCEPTED", "both_pending_stops_valid"
    elif buy_ok or sell_ok:
        status, reason = "CANCEL_NO_TRADE_ONE_SIDED", "one_side_rejected_peer_cancelled"
    else:
        status, reason = "CANCEL_NO_TRADE_BOTH_INVALID", "both_pending_stops_rejected"
    return PlacementDecision(status, buy_ok, sell_ok, reason, quote.bid, quote.ask, spec.minimum_distance)


def pending_stop_fill(side: int, level: float, bar_open: float, bar_high: float, bar_low: float) -> float | None:
    """M1 pending-stop fill with gap-through at the first available M1 price."""
    if side > 0:
        return max(level, bar_open) if bar_high >= level else None
    if side < 0:
        return min(level, bar_open) if bar_low <= level else None
    raise ValueError("side must be +1 or -1")


def protective_stop_fill(side: int, level: float, bar_open: float, bar_high: float, bar_low: float) -> float | None:
    """Protective-stop fill, charging an opening gap through the stop."""
    if side > 0:
        return min(level, bar_open) if bar_low <= level else None
    if side < 0:
        return max(level, bar_open) if bar_high >= level else None
    raise ValueError("side must be +1 or -1")


def target_fill(side: int, level: float, bar_open: float, bar_high: float, bar_low: float) -> float | None:
    """Take-profit fill with the same first-available M1 gap rule."""
    if side > 0:
        return max(level, bar_open) if bar_high >= level else None
    if side < 0:
        return min(level, bar_open) if bar_low <= level else None
    raise ValueError("side must be +1 or -1")


def _open_month(symbol: str, year: int, month: int) -> tuple[bytes, str]:
    name = f"{year:04d}{month:02d}.tkc"
    last: Exception | None = None
    for root in TKC_TERMINALS:
        path = root / symbol / name
        if not path.is_file():
            continue
        try:
            return path.read_bytes(), str(path)
        except PermissionError as exc:
            last = exc
    raise FileNotFoundError(f"{symbol}/{name} unreadable in T1-T10 ({last})")


def _valid_day_entries(blob: bytes):
    if len(blob) < TKC_HEADER or struct.unpack_from("<I", blob, 0)[0] != TKC_MAGIC:
        raise TickArchiveError("bad TKC header/magic")
    for slot in range(TKC_DAY_SLOTS):
        pos = TKC_HEADER + slot * TKC_DAY_ENTRY.size
        if pos + TKC_DAY_ENTRY.size > len(blob):
            break
        entry = TKC_DAY_ENTRY.unpack_from(blob, pos)
        size, offset = entry[2], entry[3]
        if size <= TKC_DAY_HEADER or offset < TKC_HEADER or offset + size > len(blob):
            continue
        yield entry, blob[offset : offset + size]


def _stream_descriptors(block: bytes) -> dict[int, tuple[int, int, int, int]]:
    if len(block) < TKC_DAY_HEADER:
        raise TickArchiveError("short TKC day block")
    count = struct.unpack_from("<I", block, TKC_STREAM_COUNT_OFFSET)[0]
    if count < 3 or count > 16:
        raise TickArchiveError(f"implausible TKC stream count: {count}")
    out: dict[int, tuple[int, int, int, int]] = {}
    for i in range(count):
        pos = TKC_STREAM_TABLE_OFFSET + i * TKC_STREAM_DESC.size
        if pos + TKC_STREAM_DESC.size > TKC_DAY_HEADER:
            raise TickArchiveError("TKC stream table crosses day header")
        offset, size, raw_size, stream_type, crc, *_ = TKC_STREAM_DESC.unpack_from(block, pos)
        out[stream_type] = (offset, size, raw_size, crc)
    return out


def _decode_stream(block: bytes, desc: tuple[int, int, int, int]) -> bytes:
    offset, size, raw_size, crc = desc
    payload = block[TKC_DAY_HEADER:]
    if offset + size > len(payload):
        raise TickArchiveError("TKC compressed stream lies outside day block")
    raw = zlib.decompress(payload[offset : offset + size])
    if len(raw) != raw_size:
        raise TickArchiveError(f"TKC raw stream length {len(raw)} != {raw_size}")
    if zlib.crc32(raw) & 0xFFFFFFFF != crc:
        raise TickArchiveError("TKC stream CRC mismatch")
    return raw


def _uint64_array(raw: bytes) -> array:
    if len(raw) % 8:
        raise TickArchiveError("TKC uint64 stream is not 8-byte aligned")
    values = array("Q")
    values.frombytes(raw)
    if sys.byteorder != "little":
        values.byteswap()
    return values


def quotes_at_or_after(symbol: str, epochs: Iterable[int]) -> dict[int, TickQuote]:
    """Return the first real tick at/after each server epoch.

    Requests are grouped by month and day; each daily time/bid/ask column is
    decompressed once and then discarded.  Missing archive coverage simply
    leaves the request absent from the result so callers can emit ``UNKNOWN``.
    Corrupt archive data raises ``TickArchiveError`` and never falls back to an
    invented spread.
    """
    requested = sorted(set(int(v) for v in epochs))
    by_month: dict[tuple[int, int], list[int]] = defaultdict(list)
    for epoch in requested:
        stamp = dt.datetime.fromtimestamp(epoch, dt.timezone.utc)
        by_month[(stamp.year, stamp.month)].append(epoch)
    found: dict[int, TickQuote] = {}
    for (year, month), month_epochs in sorted(by_month.items()):
        try:
            blob, source = _open_month(symbol, year, month)
        except FileNotFoundError:
            continue
        by_day: dict[dt.date, list[int]] = defaultdict(list)
        for epoch in month_epochs:
            by_day[dt.datetime.fromtimestamp(epoch, dt.timezone.utc).date()].append(epoch)
        for entry, block in _valid_day_entries(blob):
            descs = _stream_descriptors(block)
            required = (TKC_STREAM_TIME_MSC, TKC_STREAM_BID, TKC_STREAM_ASK)
            if any(kind not in descs for kind in required):
                raise TickArchiveError(f"{source}: day block lacks time/bid/ask streams")
            time_raw = _decode_stream(block, descs[TKC_STREAM_TIME_MSC])
            deltas = _uint64_array(time_raw)
            tick_count = entry[6]
            if len(deltas) != tick_count or tick_count == 0:
                raise TickArchiveError(f"{source}: table tick count {tick_count} != {len(deltas)}")
            first_day = dt.datetime.fromtimestamp(deltas[0] / 1000.0, dt.timezone.utc).date()
            targets = sorted(by_day.get(first_day, ()))
            if not targets:
                continue
            bid_raw = _decode_stream(block, descs[TKC_STREAM_BID])
            ask_raw = _decode_stream(block, descs[TKC_STREAM_ASK])
            if len(bid_raw) != tick_count * 8 or len(ask_raw) != tick_count * 8:
                raise TickArchiveError(f"{source}: price stream length/count mismatch")
            target_i = 0
            target_ms = targets[target_i] * 1000
            current_ms = deltas[0]
            for tick_i in range(tick_count):
                if tick_i:
                    current_ms += deltas[tick_i]
                while target_i < len(targets) and current_ms >= target_ms:
                    epoch = targets[target_i]
                    bid = struct.unpack_from("<d", bid_raw, tick_i * 8)[0]
                    ask = struct.unpack_from("<d", ask_raw, tick_i * 8)[0]
                    found[epoch] = TickQuote(epoch, current_ms, bid, ask, source)
                    target_i += 1
                    if target_i >= len(targets):
                        break
                    target_ms = targets[target_i] * 1000
                if target_i >= len(targets):
                    break
    return found


def deterministic_json_bytes(value: object) -> bytes:
    return (json.dumps(value, indent=1, sort_keys=True, separators=(",", ": ")) + "\n").encode("utf-8")
