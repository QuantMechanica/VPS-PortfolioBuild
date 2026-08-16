#!/usr/bin/env python3
"""Build the bound QM5_1537 monthly volatility-sleeve calendar.

The source data are MT5 ``Daily.hc`` cache files, not tick files.  The cache
layout used here is the MetaTrader 5 HistoryCache v502 layout already produced
by T_Export: a 432-byte header, an int64 time vector, then count-prefixed
double vectors for OHLC.  Only timestamps and closes are consumed.
"""

from __future__ import annotations

import argparse
import bisect
import csv
import hashlib
import json
import math
import struct
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


SCHEMA_VERSION = "qm1537.monthly_sleeve.v1"
MIN_DAILY_BARS = 270
VOL_LOOKBACK_DAYS = 252
ANNUALIZATION_DAYS = 252
TOP_N = 3
TIE_BREAK = "basket_slot_ascending"
EVALUATION = "first_host_d1_bar_of_calendar_month"
HISTORY_CACHE_VERSION = 502
HISTORY_CACHE_HEADER_SIZE = 432
HISTORY_CACHE_COUNT_OFFSET = 428

UNIVERSE = (
    "XAUUSD.DWX", "XAGUSD.DWX", "XNGUSD.DWX", "XTIUSD.DWX",
    "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX", "SP500.DWX",
    "AUDCAD.DWX", "AUDCHF.DWX", "AUDJPY.DWX", "AUDNZD.DWX", "AUDUSD.DWX",
    "CADCHF.DWX", "CADJPY.DWX", "CHFJPY.DWX", "EURAUD.DWX", "EURCAD.DWX",
    "EURCHF.DWX", "EURGBP.DWX", "EURJPY.DWX", "EURNZD.DWX", "EURUSD.DWX",
    "GBPAUD.DWX", "GBPCAD.DWX", "GBPCHF.DWX", "GBPJPY.DWX", "GBPNZD.DWX",
    "GBPUSD.DWX", "NZDCAD.DWX", "NZDCHF.DWX", "NZDJPY.DWX", "NZDUSD.DWX",
    "USDCAD.DWX", "USDCHF.DWX", "USDJPY.DWX",
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def ranking_contract_payload() -> str:
    return (
        f"schema={SCHEMA_VERSION}"
        f"|min_daily_bars={MIN_DAILY_BARS}"
        f"|vol_lookback_days={VOL_LOOKBACK_DAYS}"
        f"|annualization_days={ANNUALIZATION_DAYS}"
        f"|top_n={TOP_N}"
        f"|tie_break={TIE_BREAK}"
        f"|evaluation={EVALUATION}"
        f"|universe={','.join(UNIVERSE)}"
    )


CONTRACT_SHA256 = sha256_bytes(ranking_contract_payload().encode("utf-8"))


@dataclass(frozen=True)
class DailySeries:
    symbol: str
    path: Path
    file_sha256: str
    times: tuple[int, ...]
    closes: tuple[float, ...]

    @property
    def first_month(self) -> int:
        return month_key(self.times[0])

    @property
    def last_month(self) -> int:
        return month_key(self.times[-1])


def _read_count(raw: bytes, offset: int, expected: int, label: str) -> int:
    if offset + 4 > len(raw):
        raise ValueError(f"{label}: truncated count")
    value = struct.unpack_from("<I", raw, offset)[0]
    if value != expected:
        raise ValueError(f"{label}: vector count {value} != header count {expected}")
    return offset + 4


def load_daily_cache(path: Path, symbol: str) -> DailySeries:
    raw = path.read_bytes()
    if len(raw) < HISTORY_CACHE_HEADER_SIZE:
        raise ValueError(f"{path}: cache shorter than {HISTORY_CACHE_HEADER_SIZE} bytes")
    version = struct.unpack_from("<I", raw, 0)[0]
    if version != HISTORY_CACHE_VERSION:
        raise ValueError(f"{path}: HistoryCache version {version} != {HISTORY_CACHE_VERSION}")
    count = struct.unpack_from("<I", raw, HISTORY_CACHE_COUNT_OFFSET)[0]
    if count <= 0:
        raise ValueError(f"{path}: empty Daily cache")

    offset = HISTORY_CACHE_HEADER_SIZE
    times = struct.unpack_from(f"<{count}Q", raw, offset)
    offset += count * 8
    offset = _read_count(raw, offset, count, f"{path}: open")
    offset += count * 8
    offset = _read_count(raw, offset, count, f"{path}: high")
    offset += count * 8
    offset = _read_count(raw, offset, count, f"{path}: low")
    offset += count * 8
    offset = _read_count(raw, offset, count, f"{path}: close")
    if offset + count * 8 > len(raw):
        raise ValueError(f"{path}: truncated close vector")
    closes = struct.unpack_from(f"<{count}d", raw, offset)

    if any(right <= left for left, right in zip(times, times[1:])):
        raise ValueError(f"{path}: Daily timestamps are not strictly increasing")
    if any((not math.isfinite(value) or value <= 0.0) for value in closes):
        raise ValueError(f"{path}: invalid close value")
    return DailySeries(
        symbol=symbol,
        path=path.resolve(),
        file_sha256=sha256_bytes(raw),
        times=tuple(int(value) for value in times),
        closes=tuple(float(value) for value in closes),
    )


def month_key(epoch_seconds: int) -> int:
    value = datetime.fromtimestamp(epoch_seconds, timezone.utc)
    return value.year * 100 + value.month


def first_host_bar_by_month(series: DailySeries) -> dict[int, int]:
    result: dict[int, int] = {}
    for timestamp in series.times:
        result.setdefault(month_key(timestamp), timestamp)
    return result


def realized_volatility(series: DailySeries, asof_epoch: int) -> float | None:
    stop = bisect.bisect_left(series.times, asof_epoch)
    if stop < MIN_DAILY_BARS:
        return None
    newest = [series.closes[stop - 1 - index] for index in range(VOL_LOOKBACK_DAYS + 1)]
    total = 0.0
    total_sq = 0.0
    for index in range(VOL_LOOKBACK_DAYS):
        daily_return = math.log(newest[index] / newest[index + 1])
        total += daily_return
        total_sq += daily_return * daily_return
    mean = total / VOL_LOOKBACK_DAYS
    variance = (
        total_sq - VOL_LOOKBACK_DAYS * mean * mean
    ) / (VOL_LOOKBACK_DAYS - 1)
    if variance < 0.0:
        variance = 0.0
    return math.sqrt(variance) * math.sqrt(ANNUALIZATION_DAYS) * 100.0


def load_universe(history_root: Path) -> dict[str, DailySeries]:
    result: dict[str, DailySeries] = {}
    for symbol in UNIVERSE:
        path = history_root / symbol / "cache" / "Daily.hc"
        if not path.is_file():
            raise FileNotFoundError(f"missing governed D1 cache: {path}")
        result[symbol] = load_daily_cache(path, symbol)
    return result


def input_manifest_rows(series_by_symbol: dict[str, DailySeries]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for slot, symbol in enumerate(UNIVERSE):
        series = series_by_symbol[symbol]
        rows.append(
            {
                "slot": slot,
                "symbol": symbol,
                "path": str(series.path),
                "sha256": series.file_sha256,
                "bars": len(series.times),
                "first_epoch": series.times[0],
                "last_epoch": series.times[-1],
            }
        )
    return rows


def input_bundle_sha256(rows: Iterable[dict[str, object]]) -> str:
    payload = json.dumps(list(rows), sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return sha256_bytes(payload.encode("ascii"))


def iter_calendar_rows(
    series_by_symbol: dict[str, DailySeries],
    bundle_sha256: str,
    from_month: int,
    to_month: int,
) -> Iterable[dict[str, object]]:
    slot_by_symbol = {symbol: slot for slot, symbol in enumerate(UNIVERSE)}
    for host_symbol in UNIVERSE:
        host_months = first_host_bar_by_month(series_by_symbol[host_symbol])
        for current_month, asof_epoch in sorted(host_months.items()):
            if current_month < from_month or current_month > to_month:
                continue
            values: list[tuple[str, float]] = []
            for candidate in UNIVERSE:
                value = realized_volatility(series_by_symbol[candidate], asof_epoch)
                if value is not None:
                    values.append((candidate, value))
            values.sort(key=lambda item: (-item[1], slot_by_symbol[item[0]]))
            ranked_symbols = [item[0] for item in values]
            selected = ranked_symbols[:TOP_N]
            host_rank = ranked_symbols.index(host_symbol) if host_symbol in ranked_symbols else -1
            host_value = dict(values).get(host_symbol, 0.0)
            padded = selected + [""] * (TOP_N - len(selected))
            yield {
                "schema_version": SCHEMA_VERSION,
                "contract_sha256": CONTRACT_SHA256,
                "input_bundle_sha256": bundle_sha256,
                "month_key": current_month,
                "host_symbol": host_symbol,
                "host_rank": host_rank,
                "valid_count": len(values),
                "selected": int(0 <= host_rank < min(TOP_N, len(values))),
                "selected_1": padded[0],
                "selected_2": padded[1],
                "selected_3": padded[2],
                "host_vol_pct": f"{host_value:.12f}",
                "asof_epoch": asof_epoch,
            }


def build(args: argparse.Namespace) -> dict[str, object]:
    history_root = args.history_root.resolve()
    output = args.output.resolve()
    manifest_output = args.manifest_output.resolve()
    series = load_universe(history_root)
    inputs = input_manifest_rows(series)
    bundle_sha = input_bundle_sha256(inputs)
    rows = list(iter_calendar_rows(series, bundle_sha, args.from_month, args.to_month))
    if not rows:
        raise ValueError("calendar generation produced zero rows")

    output.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0])
    with output.open("w", encoding="ascii", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    calendar_sha = sha256_file(output)

    manifest: dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "generator": str(Path(__file__).resolve()),
        "history_root": str(history_root),
        "ranking_contract_payload": ranking_contract_payload(),
        "ranking_contract_sha256": CONTRACT_SHA256,
        "input_bundle_sha256": bundle_sha,
        "calendar_path": str(output),
        "calendar_sha256": calendar_sha,
        "coverage": {"from_month": args.from_month, "to_month": args.to_month},
        "row_count": len(rows),
        "inputs": inputs,
    }
    manifest_output.parent.mkdir(parents=True, exist_ok=True)
    manifest_output.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return manifest


def parser() -> argparse.ArgumentParser:
    ea_dir = Path(__file__).resolve().parents[1]
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument(
        "--history-root",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\Bases\Custom\history"),
    )
    result.add_argument(
        "--output",
        type=Path,
        default=ea_dir / "calendar" / "QM5_1537_monthly_sleeves_v1.csv",
    )
    result.add_argument(
        "--manifest-output",
        type=Path,
        default=ea_dir / "calendar" / "QM5_1537_monthly_sleeves_v1.manifest.json",
    )
    result.add_argument("--from-month", type=int, default=201710)
    result.add_argument("--to-month", type=int, default=202612)
    return result


def main() -> int:
    args = parser().parse_args()
    manifest = build(args)
    print(json.dumps({
        "status": "PASS",
        "row_count": manifest["row_count"],
        "contract_sha256": manifest["ranking_contract_sha256"],
        "input_bundle_sha256": manifest["input_bundle_sha256"],
        "calendar_sha256": manifest["calendar_sha256"],
        "calendar_path": manifest["calendar_path"],
        "manifest_path": str(args.manifest_output.resolve()),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
