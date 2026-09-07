"""Shared, deterministic contracts for the Dukascopy backfill tools."""

from __future__ import annotations

import calendar
import csv
import datetime as dt
import hashlib
import json
import lzma
import os
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator, Mapping, Sequence


UTC = dt.timezone.utc
BI5_RECORD = struct.Struct(">IIIff")
BI5_RECORD_SIZE = BI5_RECORD.size
HOURLY_MILLISECONDS = 60 * 60 * 1000

FX_SYMBOLS = (
    "AUDCAD.DWX", "AUDCHF.DWX", "AUDJPY.DWX", "AUDNZD.DWX",
    "AUDUSD.DWX", "CADCHF.DWX", "CADJPY.DWX", "CHFJPY.DWX",
    "EURAUD.DWX", "EURCAD.DWX", "EURCHF.DWX", "EURGBP.DWX",
    "EURJPY.DWX", "EURNZD.DWX", "EURUSD.DWX", "GBPAUD.DWX",
    "GBPCAD.DWX", "GBPCHF.DWX", "GBPJPY.DWX", "GBPNZD.DWX",
    "GBPUSD.DWX", "NZDCAD.DWX", "NZDCHF.DWX", "NZDJPY.DWX",
    "NZDUSD.DWX", "USDCAD.DWX", "USDCHF.DWX", "USDJPY.DWX",
)

NON_FX_INSTRUMENTS = {
    "GDAXI.DWX": "DEU.IDX/EUR",
    "SP500.DWX": "USA500.IDX/USD",
    "NDX.DWX": "USATECH.IDX/USD",
    "WS30.DWX": "USA30.IDX/USD",
    "UK100.DWX": "GBR.IDX/GBP",
    "XAUUSD.DWX": "XAUUSD",
    "XAGUSD.DWX": "XAGUSD",
    "XTIUSD.DWX": "LIGHT.CMD/USD",
    "XNGUSD.DWX": "GAS.CMD/USD",
}

CANONICAL_SYMBOLS = tuple(sorted((*FX_SYMBOLS, *NON_FX_INSTRUMENTS)))
if len(CANONICAL_SYMBOLS) != 37 or len(set(CANONICAL_SYMBOLS)) != 37:
    raise RuntimeError("Dukascopy canonical universe must contain exactly 37 symbols")


@dataclass(frozen=True)
class Tick:
    """One decoded tick with an authoritative UTC timestamp."""

    utc_time_msc: int
    ask: float
    bid: float
    ask_volume: float
    bid_volume: float


def sha256_bytes(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def atomic_write_bytes(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    with temporary.open("wb") as handle:
        handle.write(content)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def atomic_write_text(path: Path, content: str) -> None:
    atomic_write_bytes(path, content.encode("utf-8"))


def atomic_write_json(path: Path, value: object) -> None:
    atomic_write_text(
        path,
        json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True) + "\n",
    )


def parse_utc(value: str) -> dt.datetime:
    text = str(value).strip()
    if not text:
        raise ValueError("UTC timestamp is required")
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    parsed = dt.datetime.fromisoformat(text)
    if parsed.tzinfo is None:
        raise ValueError(f"UTC timestamp must carry an offset: {value!r}")
    return parsed.astimezone(UTC)


def format_utc(value: dt.datetime) -> str:
    aware = value.astimezone(UTC)
    return aware.isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _nth_weekday(year: int, month: int, weekday: int, occurrence: int) -> int:
    first_weekday, _ = calendar.monthrange(year, month)
    return 1 + (weekday - first_weekday) % 7 + 7 * (occurrence - 1)


def us_dst_bounds_utc(year: int) -> tuple[dt.datetime, dt.datetime]:
    """Return US DST boundaries as UTC instants for the post-2007 rule."""

    march_sunday = _nth_weekday(year, 3, calendar.SUNDAY, 2)
    november_sunday = _nth_weekday(year, 11, calendar.SUNDAY, 1)
    start = dt.datetime(year, 3, march_sunday, 7, tzinfo=UTC)
    end = dt.datetime(year, 11, november_sunday, 6, tzinfo=UTC)
    return start, end


def darwinex_broker_offset_hours(value_utc: dt.datetime) -> int:
    """Darwinex NY-close offset: UTC+3 in US DST, UTC+2 otherwise."""

    aware = value_utc.astimezone(UTC)
    start, end = us_dst_bounds_utc(aware.year)
    return 3 if start <= aware < end else 2


def utc_to_broker_wall(value_utc: dt.datetime) -> dt.datetime:
    aware = value_utc.astimezone(UTC)
    return (aware + dt.timedelta(hours=darwinex_broker_offset_hours(aware))).replace(
        tzinfo=None
    )


def utc_msc_to_broker_msc(value_utc_msc: int) -> int:
    seconds, milliseconds = divmod(int(value_utc_msc), 1000)
    aware = dt.datetime.fromtimestamp(seconds, tz=UTC).replace(
        microsecond=milliseconds * 1000
    )
    wall = utc_to_broker_wall(aware)
    return calendar.timegm(wall.timetuple()) * 1000 + milliseconds


def broker_epoch_seconds_for_utc(value_utc: dt.datetime) -> int:
    return utc_msc_to_broker_msc(int(value_utc.timestamp() * 1000)) // 1000


def canonical_instrument(symbol: str) -> str:
    canonical = str(symbol).strip().upper()
    if canonical not in CANONICAL_SYMBOLS:
        raise ValueError(f"symbol is outside the 37-row DWX universe: {symbol!r}")
    if canonical in NON_FX_INSTRUMENTS:
        return NON_FX_INSTRUMENTS[canonical]
    return canonical.removesuffix(".DWX")


def instrument_url_key(instrument: str) -> str:
    key = "".join(character for character in instrument.upper() if character.isalnum())
    if not key:
        raise ValueError(f"invalid Dukascopy instrument: {instrument!r}")
    return key


def default_price_scale(symbol: str) -> int | None:
    """Return an authenticated-by-format FX scale; CFDs require an explicit scale."""

    canonical = str(symbol).strip().upper()
    if canonical not in FX_SYMBOLS:
        return None
    root = canonical.removesuffix(".DWX")
    return 1000 if root.endswith("JPY") else 100000


def default_point_size(symbol: str) -> float | None:
    scale = default_price_scale(symbol)
    return None if scale is None else 1.0 / scale


def hourly_url(
    base_url: str,
    symbol: str,
    hour_utc: dt.datetime,
) -> str:
    hour = hour_utc.astimezone(UTC)
    instrument = instrument_url_key(canonical_instrument(symbol))
    return (
        f"{base_url.rstrip('/')}/{instrument}/{hour.year:04d}/"
        f"{hour.month - 1:02d}/{hour.day:02d}/{hour.hour:02d}h_ticks.bi5"
    )


def hourly_relative_path(symbol: str, hour_utc: dt.datetime) -> Path:
    hour = hour_utc.astimezone(UTC)
    instrument = instrument_url_key(canonical_instrument(symbol))
    return Path(
        instrument,
        f"{hour.year:04d}",
        f"{hour.month - 1:02d}",
        f"{hour.day:02d}",
        f"{hour.hour:02d}h_ticks.bi5",
    )


def iter_hours(start_utc: dt.datetime, end_utc: dt.datetime) -> Iterator[dt.datetime]:
    start = start_utc.astimezone(UTC).replace(minute=0, second=0, microsecond=0)
    end = end_utc.astimezone(UTC)
    cursor = start
    while cursor < end:
        yield cursor
        cursor += dt.timedelta(hours=1)


def decompress_bi5(content: bytes) -> bytes:
    if not content:
        return b""
    try:
        return lzma.decompress(content)
    except lzma.LZMAError as first_error:
        # Some historical .bi5 files are raw LZMA1 streams. The standard
        # Dukascopy properties are lc=3, lp=0, pb=2 with an 8 MiB dictionary.
        filters = [{
            "id": lzma.FILTER_LZMA1,
            "dict_size": 8 * 1024 * 1024,
            "lc": 3,
            "lp": 0,
            "pb": 2,
        }]
        try:
            return lzma.decompress(content, format=lzma.FORMAT_RAW, filters=filters)
        except lzma.LZMAError as raw_error:
            raise ValueError(
                f"invalid LZMA bi5 payload: auto={first_error}; raw={raw_error}"
            ) from raw_error


def inspect_hourly_bi5(content: bytes) -> dict[str, int]:
    raw = decompress_bi5(content)
    if not raw:
        return {"records": 0, "raw_bytes": 0, "first_offset_msc": 0, "last_offset_msc": 0}
    if len(raw) % BI5_RECORD_SIZE:
        raise ValueError(
            f"decompressed bi5 size {len(raw)} is not divisible by {BI5_RECORD_SIZE}"
        )
    first = last = prior = None
    records = 0
    for offset in range(0, len(raw), BI5_RECORD_SIZE):
        time_msc, _ask, _bid, _ask_volume, _bid_volume = BI5_RECORD.unpack_from(
            raw, offset
        )
        if time_msc >= HOURLY_MILLISECONDS:
            raise ValueError(
                f"hourly bi5 timestamp offset is outside the hour: {time_msc}"
            )
        if prior is not None and time_msc < prior:
            raise ValueError("hourly bi5 timestamp order regressed")
        first = time_msc if first is None else first
        last = prior = time_msc
        records += 1
    return {
        "records": records,
        "raw_bytes": len(raw),
        "first_offset_msc": int(first or 0),
        "last_offset_msc": int(last or 0),
    }


def decode_hourly_bi5(
    content: bytes,
    hour_utc: dt.datetime,
    price_scale: int,
) -> Iterator[Tick]:
    if int(price_scale) <= 0:
        raise ValueError("price_scale must be positive")
    raw = decompress_bi5(content)
    if len(raw) % BI5_RECORD_SIZE:
        raise ValueError(
            f"decompressed bi5 size {len(raw)} is not divisible by {BI5_RECORD_SIZE}"
        )
    base_msc = int(hour_utc.astimezone(UTC).timestamp() * 1000)
    prior: int | None = None
    for offset in range(0, len(raw), BI5_RECORD_SIZE):
        within_hour, ask_raw, bid_raw, ask_volume, bid_volume = (
            BI5_RECORD.unpack_from(raw, offset)
        )
        if within_hour >= HOURLY_MILLISECONDS:
            raise ValueError(
                f"hourly bi5 timestamp offset is outside the hour: {within_hour}"
            )
        if prior is not None and within_hour < prior:
            raise ValueError("hourly bi5 timestamp order regressed")
        prior = within_hour
        ask = ask_raw / price_scale
        bid = bid_raw / price_scale
        if bid <= 0 or ask <= 0 or ask < bid:
            raise ValueError(
                f"decoded prices are invalid: bid={bid!r} ask={ask!r}"
            )
        yield Tick(
            utc_time_msc=base_msc + within_hour,
            ask=ask,
            bid=bid,
            ask_volume=float(ask_volume),
            bid_volume=float(bid_volume),
        )


def validate_symbol_matrix(path: Path) -> None:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    observed = {str(row.get("symbol") or "").strip().upper() for row in rows}
    if observed != set(CANONICAL_SYMBOLS):
        raise ValueError(
            "DWX symbol matrix does not exactly match downloader universe: "
            f"missing={sorted(set(CANONICAL_SYMBOLS) - observed)} "
            f"extra={sorted(observed - set(CANONICAL_SYMBOLS))}"
        )


def load_json_lines(path: Path) -> list[dict[str, object]]:
    if not path.is_file():
        return []
    rows: list[dict[str, object]] = []
    with path.open(encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            if not line.strip():
                continue
            try:
                value = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(
                    f"invalid JSONL at {path}:{line_number}: {exc}"
                ) from exc
            if not isinstance(value, dict):
                raise ValueError(f"JSONL row is not an object at {path}:{line_number}")
            rows.append(value)
    return rows


def append_json_line(path: Path, value: Mapping[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(value, sort_keys=True, ensure_ascii=True) + "\n"
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(encoded)
        handle.flush()
        os.fsync(handle.fileno())


def percentile(values: Sequence[float], proportion: float) -> float:
    if not values:
        raise ValueError("percentile requires at least one value")
    if not 0 <= proportion <= 1:
        raise ValueError("percentile proportion must be between zero and one")
    ordered = sorted(float(value) for value in values)
    if len(ordered) == 1:
        return ordered[0]
    position = (len(ordered) - 1) * proportion
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    weight = position - lower
    return ordered[lower] * (1 - weight) + ordered[upper] * weight
