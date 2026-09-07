"""Convert verified hourly bi5 files into append-only TDM-compatible CSVs.

The output is intentionally a scratch/source artifact for the existing
``prepare_import.py`` binary stager. This tool never writes into T1 and never
starts or attaches to MetaTrader.
"""

from __future__ import annotations

import argparse
import contextlib
import csv
import datetime as dt
import json
import math
import os
from dataclasses import dataclass
from pathlib import Path

try:
    from .common import (
        UTC,
        atomic_write_json,
        decode_hourly_bi5,
        default_point_size,
        default_price_scale,
        format_utc,
        hourly_relative_path,
        load_json_lines,
        parse_utc,
        sha256_file,
        utc_msc_to_broker_msc,
    )
except ImportError:  # direct script execution
    from common import (  # type: ignore
        UTC,
        atomic_write_json,
        decode_hourly_bi5,
        default_point_size,
        default_price_scale,
        format_utc,
        hourly_relative_path,
        load_json_lines,
        parse_utc,
        sha256_file,
        utc_msc_to_broker_msc,
    )


SIDECAR_SCHEMA = "qm.dukascopy-import-source/v1"


@dataclass
class MinuteBar:
    minute_epoch: int
    open: float
    high: float
    low: float
    close: float
    tick_count: int
    spread_points_sum: float

    @classmethod
    def first(cls, minute_epoch: int, bid: float, spread_points: float) -> "MinuteBar":
        return cls(minute_epoch, bid, bid, bid, bid, 1, spread_points)

    def add(self, bid: float, spread_points: float) -> None:
        self.high = max(self.high, bid)
        self.low = min(self.low, bid)
        self.close = bid
        self.tick_count += 1
        self.spread_points_sum += spread_points


def _price(value: float) -> str:
    return f"{value:.10f}".rstrip("0").rstrip(".")


def _broker_tick_timestamp(broker_msc: int) -> str:
    seconds, milliseconds = divmod(broker_msc, 1000)
    wall = dt.datetime.utcfromtimestamp(seconds)
    return wall.strftime("%Y.%m.%d %H:%M:%S") + f".{milliseconds:03d}"


def _write_bar(writer: csv.writer, bar: MinuteBar) -> None:
    wall = dt.datetime.utcfromtimestamp(bar.minute_epoch * 60)
    mean_spread = bar.spread_points_sum / bar.tick_count
    writer.writerow([
        wall.strftime("%Y.%m.%d"),
        wall.strftime("%H:%M:%S"),
        _price(bar.open),
        _price(bar.high),
        _price(bar.low),
        _price(bar.close),
        bar.tick_count,
        f"{mean_spread:.6f}".rstrip("0").rstrip("."),
    ])


def _downloaded_entries(manifest_path: Path, symbol: str) -> list[dict[str, object]]:
    latest_by_url: dict[str, dict[str, object]] = {}
    for row in load_json_lines(manifest_path):
        if str(row.get("symbol") or "").upper() != symbol:
            continue
        url = str(row.get("url") or "")
        if url:
            latest_by_url[url] = row
    unresolved = [
        row
        for row in latest_by_url.values()
        if row.get("status") not in {"downloaded", "no_data"}
    ]
    if unresolved:
        hours = sorted(str(row.get("hour_utc") or "") for row in unresolved)
        raise ValueError(
            f"manifest has {len(unresolved)} unresolved download row(s) for "
            f"{symbol}: {hours[:5]}"
        )
    result = [
        row for row in latest_by_url.values() if row.get("status") == "downloaded"
    ]
    result.sort(key=lambda row: str(row.get("hour_utc") or ""))
    if not result:
        raise ValueError(f"manifest has no downloaded files for {symbol}")
    hours = [str(row.get("hour_utc") or "") for row in result]
    if len(hours) != len(set(hours)):
        raise ValueError(f"manifest has duplicate downloaded hours for {symbol}")
    return result


def convert_symbol(
    *,
    manifest_path: Path,
    raw_root: Path,
    symbol: str,
    splice_utc: dt.datetime,
    out_dir: Path,
    price_scale: int | None = None,
    point_size: float | None = None,
    reconciliation_from_utc: dt.datetime | None = None,
) -> dict[str, object]:
    symbol = str(symbol).strip().upper()
    manifest_path = manifest_path.resolve()
    raw_root = raw_root.resolve()
    out_dir = out_dir.resolve()
    if not manifest_path.is_file():
        raise ValueError(f"download manifest is missing: {manifest_path}")
    if not raw_root.is_dir():
        raise ValueError(f"raw download root is missing: {raw_root}")
    scale = int(
        default_price_scale(symbol) or 0
        if price_scale is None
        else price_scale
    )
    if scale <= 0:
        raise ValueError(
            f"{symbol} is not an FX pair with a format-authenticated scale; "
            "supply --price-scale from reviewed instrument metadata"
        )
    effective_point = float(
        default_point_size(symbol) or (1.0 / scale)
        if point_size is None
        else point_size
    )
    if not math.isfinite(effective_point) or effective_point <= 0:
        raise ValueError("point_size must be finite and positive")
    splice = splice_utc.astimezone(UTC)
    splice_msc = int(splice.timestamp() * 1000)
    reconciliation_from = (
        reconciliation_from_utc.astimezone(UTC)
        if reconciliation_from_utc is not None
        else None
    )
    reconciliation_from_msc = (
        int(reconciliation_from.timestamp() * 1000)
        if reconciliation_from is not None
        else None
    )
    entries = _downloaded_entries(manifest_path, symbol)

    root_name = symbol.removesuffix(".DWX")
    tick_csv = out_dir / f"{root_name}_GMT+2_US-DST.csv"
    m1_csv = out_dir / f"{root_name}_GMT+2_US-DST_M1.csv"
    reconciliation_m1_csv = (
        out_dir / f"{root_name}_GMT+2_US-DST_RECONCILIATION_ONLY_M1.csv"
        if reconciliation_from is not None
        else None
    )
    sidecar = out_dir / f"{symbol}.dukascopy-source.json"
    outputs = tuple(
        path
        for path in (tick_csv, m1_csv, reconciliation_m1_csv, sidecar)
        if path is not None
    )
    if any(path.exists() for path in outputs):
        raise ValueError(
            "append-only conversion output already exists: "
            + ", ".join(str(path) for path in outputs if path.exists())
        )
    out_dir.mkdir(parents=True, exist_ok=True)
    tick_tmp = tick_csv.with_name(tick_csv.name + ".tmp")
    m1_tmp = m1_csv.with_name(m1_csv.name + ".tmp")
    reconciliation_m1_tmp = (
        reconciliation_m1_csv.with_name(reconciliation_m1_csv.name + ".tmp")
        if reconciliation_m1_csv is not None
        else None
    )
    temporary_outputs = tuple(
        path
        for path in (tick_tmp, m1_tmp, reconciliation_m1_tmp)
        if path is not None
    )
    if any(path.exists() for path in temporary_outputs):
        raise ValueError("stale temporary output exists; inspect it before retrying")

    tick_count = 0
    first_utc_msc: int | None = None
    last_utc_msc: int | None = None
    last_broker_msc: int | None = None
    current_bar: MinuteBar | None = None
    bar_count = 0
    reconciliation_current_bar: MinuteBar | None = None
    reconciliation_bar_count = 0
    reconciliation_tick_count = 0
    reconciliation_first_utc_msc: int | None = None
    reconciliation_last_utc_msc: int | None = None
    reconciliation_last_broker_msc: int | None = None
    last_decoded_utc_msc: int | None = None
    source_files: list[dict[str, object]] = []
    try:
        reconciliation_context = (
            reconciliation_m1_tmp.open("w", encoding="utf-8", newline="")
            if reconciliation_m1_tmp is not None
            else contextlib.nullcontext()
        )
        with tick_tmp.open("w", encoding="utf-8", newline="") as tick_handle, \
                m1_tmp.open("w", encoding="utf-8", newline="") as bar_handle, \
                reconciliation_context as reconciliation_handle:
            tick_writer = csv.writer(tick_handle, lineterminator="\n")
            bar_writer = csv.writer(bar_handle, lineterminator="\n")
            reconciliation_writer = (
                csv.writer(reconciliation_handle, lineterminator="\n")
                if reconciliation_handle is not None
                else None
            )
            for entry in entries:
                relative = Path(str(entry.get("relative_path") or ""))
                source_path = (raw_root / relative).resolve()
                if raw_root not in source_path.parents:
                    raise ValueError(f"source path escapes raw root: {source_path}")
                if not source_path.is_file():
                    raise ValueError(f"manifest-bound source file is missing: {source_path}")
                expected_sha = str(entry.get("sha256") or "").lower()
                actual_sha = sha256_file(source_path).lower()
                if len(expected_sha) != 64 or actual_sha != expected_sha:
                    raise ValueError(
                        f"source checksum mismatch: {source_path} "
                        f"expected={expected_sha} actual={actual_sha}"
                    )
                hour = parse_utc(str(entry.get("hour_utc") or ""))
                expected_relative = hourly_relative_path(symbol, hour)
                if relative.as_posix() != expected_relative.as_posix():
                    raise ValueError(
                        f"manifest relative path does not bind {symbol} {format_utc(hour)}: "
                        f"{relative.as_posix()} != {expected_relative.as_posix()}"
                    )
                content = source_path.read_bytes()
                file_ticks = 0
                reconciliation_file_ticks = 0
                for tick in decode_hourly_bi5(content, hour, scale):
                    if (
                        last_decoded_utc_msc is not None
                        and tick.utc_time_msc < last_decoded_utc_msc
                    ):
                        raise ValueError("source UTC tick order regressed across files")
                    last_decoded_utc_msc = tick.utc_time_msc
                    broker_msc = utc_msc_to_broker_msc(tick.utc_time_msc)
                    spread_points = (tick.ask - tick.bid) / effective_point
                    if (
                        reconciliation_from_msc is not None
                        and tick.utc_time_msc >= reconciliation_from_msc
                    ):
                        if (
                            reconciliation_last_broker_msc is not None
                            and broker_msc < reconciliation_last_broker_msc
                        ):
                            raise ValueError(
                                "reconciliation broker-wall order regressed at DST boundary"
                            )
                        reconciliation_minute = broker_msc // 60000
                        if reconciliation_current_bar is None:
                            reconciliation_current_bar = MinuteBar.first(
                                reconciliation_minute, tick.bid, spread_points
                            )
                        elif reconciliation_minute != reconciliation_current_bar.minute_epoch:
                            assert reconciliation_writer is not None
                            _write_bar(reconciliation_writer, reconciliation_current_bar)
                            reconciliation_bar_count += 1
                            reconciliation_current_bar = MinuteBar.first(
                                reconciliation_minute, tick.bid, spread_points
                            )
                        else:
                            reconciliation_current_bar.add(tick.bid, spread_points)
                        reconciliation_first_utc_msc = (
                            tick.utc_time_msc
                            if reconciliation_first_utc_msc is None
                            else reconciliation_first_utc_msc
                        )
                        reconciliation_last_utc_msc = tick.utc_time_msc
                        reconciliation_last_broker_msc = broker_msc
                        reconciliation_tick_count += 1
                        reconciliation_file_ticks += 1
                    if tick.utc_time_msc <= splice_msc:
                        continue
                    if last_broker_msc is not None and broker_msc < last_broker_msc:
                        raise ValueError(
                            "broker-wall tick order regressed at DST boundary; refuse import"
                        )
                    tick_writer.writerow([
                        _broker_tick_timestamp(broker_msc),
                        _price(tick.bid),
                        _price(tick.ask),
                    ])
                    minute = broker_msc // 60000
                    if current_bar is None:
                        current_bar = MinuteBar.first(minute, tick.bid, spread_points)
                    elif minute != current_bar.minute_epoch:
                        _write_bar(bar_writer, current_bar)
                        bar_count += 1
                        current_bar = MinuteBar.first(minute, tick.bid, spread_points)
                    else:
                        current_bar.add(tick.bid, spread_points)
                    first_utc_msc = (
                        tick.utc_time_msc if first_utc_msc is None else first_utc_msc
                    )
                    last_utc_msc = tick.utc_time_msc
                    last_broker_msc = broker_msc
                    tick_count += 1
                    file_ticks += 1
                source_files.append({
                    "path": str(source_path),
                    "relative_path": relative.as_posix(),
                    "sha256": actual_sha,
                    "bytes": source_path.stat().st_size,
                    "hour_utc": format_utc(hour),
                    "emitted_ticks": file_ticks,
                    "reconciliation_ticks": reconciliation_file_ticks,
                })
            if current_bar is not None:
                _write_bar(bar_writer, current_bar)
                bar_count += 1
            if reconciliation_current_bar is not None:
                assert reconciliation_writer is not None
                _write_bar(reconciliation_writer, reconciliation_current_bar)
                reconciliation_bar_count += 1
            tick_handle.flush()
            os.fsync(tick_handle.fileno())
            bar_handle.flush()
            os.fsync(bar_handle.fileno())
            if reconciliation_handle is not None:
                reconciliation_handle.flush()
                os.fsync(reconciliation_handle.fileno())
        if tick_count <= 0 or first_utc_msc is None or last_utc_msc is None:
            raise ValueError("no tick strictly newer than the splice UTC timestamp")
        if reconciliation_from is not None and (
            reconciliation_tick_count <= 0
            or reconciliation_first_utc_msc is None
            or reconciliation_last_utc_msc is None
        ):
            raise ValueError("no tick at or after reconciliation_from_utc")
        if first_utc_msc <= splice_msc:
            raise AssertionError("append-only splice boundary invariant failed")
        os.replace(tick_tmp, tick_csv)
        os.replace(m1_tmp, m1_csv)
        if reconciliation_m1_tmp is not None and reconciliation_m1_csv is not None:
            os.replace(reconciliation_m1_tmp, reconciliation_m1_csv)
    except BaseException:
        for temporary in temporary_outputs:
            try:
                temporary.unlink(missing_ok=True)
            except OSError:
                pass
        raise

    result: dict[str, object] = {
        "schema": SIDECAR_SCHEMA,
        "source": "dukascopy",
        "production_import": False,
        "symbol": symbol,
        "splice_timestamp_utc": format_utc(splice),
        "append_only_contract": "every emitted source UTC tick is strictly greater than splice_timestamp_utc",
        "price_scale": scale,
        "point_size": effective_point,
        "download_manifest": {
            "path": str(manifest_path),
            "sha256": sha256_file(manifest_path),
        },
        "source_files": source_files,
        "tick_output": {
            "path": str(tick_csv),
            "sha256": sha256_file(tick_csv),
            "rows": tick_count,
            "first_source_utc_msc": first_utc_msc,
            "last_source_utc_msc": last_utc_msc,
            "first_source_utc": format_utc(dt.datetime.fromtimestamp(first_utc_msc / 1000, tz=UTC)),
            "last_source_utc": format_utc(dt.datetime.fromtimestamp(last_utc_msc / 1000, tz=UTC)),
        },
        "m1_output": {
            "path": str(m1_csv),
            "sha256": sha256_file(m1_csv),
            "rows": bar_count,
            "price_basis": "bid",
            "spread_basis": "mean ask-minus-bid per active minute in point_size units",
        },
        "prepare_import_contract": {
            "tick_columns": ["broker_time_msc", "bid", "ask"],
            "m1_columns": [
                "broker_date", "broker_time", "open", "high", "low", "close",
                "tick_volume", "mean_spread_points",
            ],
            "tick_record_size_after_prepare_import": 24,
            "m1_record_size_after_prepare_import": 48,
        },
        "rollback_contract": {
            "source_is_reproducible": True,
            "signed_2017_2025_archive_must_remain_untouched": True,
            "remove_only_the_exact_import_range_bound_by_this_sidecar": True,
            "import_first_source_utc_msc": first_utc_msc,
            "import_last_source_utc_msc": last_utc_msc,
            "source_file_sha256s": [row["sha256"] for row in source_files],
        },
    }
    if reconciliation_m1_csv is not None:
        result["reconciliation_m1_output"] = {
            "path": str(reconciliation_m1_csv),
            "sha256": sha256_file(reconciliation_m1_csv),
            "rows": reconciliation_bar_count,
            "source_ticks": reconciliation_tick_count,
            "from_source_utc": format_utc(reconciliation_from),
            "first_source_utc_msc": reconciliation_first_utc_msc,
            "last_source_utc_msc": reconciliation_last_utc_msc,
            "import_authorized": False,
            "purpose": "Dukascopy/DWX overlap reconciliation only",
        }
    try:
        atomic_write_json(sidecar, result)
    except BaseException:
        # The sidecar is the visibility/lineage marker. If it cannot be made
        # durable, remove only this invocation's scratch CSVs so a retry is
        # possible and no unbound source pair is mistaken for a complete job.
        for output in outputs:
            if output != sidecar:
                output.unlink(missing_ok=True)
        raise
    result["sidecar_path"] = str(sidecar)
    result["sidecar_sha256"] = sha256_file(sidecar)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--raw-root", required=True, type=Path)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--splice-utc", required=True)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--price-scale", type=int)
    parser.add_argument("--point-size", type=float)
    parser.add_argument(
        "--reconciliation-from-utc",
        help="emit a separate non-importable overlap M1 CSV from this UTC instant",
    )
    args = parser.parse_args(argv)
    try:
        result = convert_symbol(
            manifest_path=args.manifest,
            raw_root=args.raw_root,
            symbol=args.symbol,
            splice_utc=parse_utc(args.splice_utc),
            out_dir=args.out,
            price_scale=args.price_scale,
            point_size=args.point_size,
            reconciliation_from_utc=(
                parse_utc(args.reconciliation_from_utc)
                if args.reconciliation_from_utc
                else None
            ),
        )
    except (OSError, ValueError) as exc:
        print(json.dumps({"status": "REFUSED", "error": str(exc)}))
        return 2
    print(json.dumps({"status": "PASS", **result}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
