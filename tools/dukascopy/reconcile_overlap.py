"""Fail-closed M1 reconciliation of Dukascopy and governed DWX exports."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import math
import statistics
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping, Sequence

try:
    from .common import (
        UTC,
        atomic_write_json,
        atomic_write_text,
        broker_epoch_seconds_for_utc,
        default_point_size,
        percentile,
        sha256_file,
        us_dst_bounds_utc,
    )
except ImportError:  # direct script execution
    from common import (  # type: ignore
        UTC,
        atomic_write_json,
        atomic_write_text,
        broker_epoch_seconds_for_utc,
        default_point_size,
        percentile,
        sha256_file,
        us_dst_bounds_utc,
    )


CLOSE_P95_SPREAD_MULTIPLIER = 1.5
MIN_SESSION_COVERAGE = 0.99
REQUIRED_DST_OFFSET_SECONDS = 0
MAX_COMPUTE_SECONDS = 2 * 60 * 60
SUMMARY_SCHEMA = "qm.dukascopy-dwx-overlap-reconciliation/v1"
REQUIRED_OVERLAP_START = dt.datetime(2025, 10, 1, tzinfo=UTC)
REQUIRED_OVERLAP_END = dt.datetime(2026, 4, 1, tzinfo=UTC)


@dataclass(frozen=True)
class Bar:
    time_s: int
    open: float
    high: float
    low: float
    close: float
    tick_volume: int
    spread_points: float | None


def _broker_epoch(date_text: str, time_text: str) -> int:
    parsed = dt.datetime.strptime(
        f"{date_text.strip()} {time_text.strip()}", "%Y.%m.%d %H:%M:%S"
    )
    return int(parsed.replace(tzinfo=UTC).timestamp())


def _finite_positive(value: str, field: str) -> float:
    parsed = float(value)
    if not math.isfinite(parsed) or parsed <= 0:
        raise ValueError(f"{field} must be finite and positive")
    return parsed


def _bar_from_values(
    *,
    time_s: int,
    open_value: str,
    high_value: str,
    low_value: str,
    close_value: str,
    tick_volume: str,
    spread_points: str | None,
) -> Bar:
    open_price = _finite_positive(open_value, "open")
    high = _finite_positive(high_value, "high")
    low = _finite_positive(low_value, "low")
    close = _finite_positive(close_value, "close")
    if high < max(open_price, close) or low > min(open_price, close) or high < low:
        raise ValueError("OHLC relationship is invalid")
    volume = int(float(tick_volume or 0))
    if volume < 0:
        raise ValueError("tick volume must be non-negative")
    spread: float | None = None
    if spread_points not in (None, ""):
        candidate = float(spread_points)
        if not math.isfinite(candidate) or candidate < 0:
            raise ValueError("spread points must be finite and non-negative")
        spread = candidate
    return Bar(time_s, open_price, high, low, close, volume, spread)


def read_m1_csv(path: Path) -> dict[int, Bar]:
    """Read native-export header CSV or TDM-compatible headerless M1 CSV."""

    path = path.resolve()
    if not path.is_file():
        raise ValueError(f"M1 CSV is missing: {path}")
    with path.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.reader(handle))
    if not rows:
        raise ValueError(f"M1 CSV is empty: {path}")
    first_lower = [value.strip().lower() for value in rows[0]]
    has_header = "open" in first_lower and "close" in first_lower
    bars: dict[int, Bar] = {}
    if has_header:
        header = first_lower
        index = {name: position for position, name in enumerate(header)}
        required = {"time", "open", "high", "low", "close"}
        if not required.issubset(index):
            raise ValueError(f"unsupported M1 header in {path}: {rows[0]}")
        volume_name = "tickvol" if "tickvol" in index else "tick_volume"
        if volume_name not in index:
            raise ValueError(f"M1 header lacks tick volume: {path}")
        spread_name = "spread" if "spread" in index else (
            "spread_points" if "spread_points" in index else None
        )
        data_rows = rows[1:]
        for line_number, row in enumerate(data_rows, start=2):
            try:
                bar = _bar_from_values(
                    time_s=int(float(row[index["time"]])),
                    open_value=row[index["open"]],
                    high_value=row[index["high"]],
                    low_value=row[index["low"]],
                    close_value=row[index["close"]],
                    tick_volume=row[index[volume_name]],
                    spread_points=row[index[spread_name]] if spread_name else None,
                )
            except (IndexError, ValueError) as exc:
                raise ValueError(f"invalid M1 row {path}:{line_number}: {exc}") from exc
            if bar.time_s in bars:
                raise ValueError(f"duplicate M1 timestamp {bar.time_s} in {path}")
            bars[bar.time_s] = bar
    else:
        for line_number, row in enumerate(rows, start=1):
            if len(row) < 7:
                raise ValueError(f"invalid TDM M1 row {path}:{line_number}")
            try:
                bar = _bar_from_values(
                    time_s=_broker_epoch(row[0], row[1]),
                    open_value=row[2],
                    high_value=row[3],
                    low_value=row[4],
                    close_value=row[5],
                    tick_volume=row[6],
                    spread_points=row[7] if len(row) > 7 else None,
                )
            except ValueError as exc:
                raise ValueError(f"invalid M1 row {path}:{line_number}: {exc}") from exc
            if bar.time_s in bars:
                raise ValueError(f"duplicate M1 timestamp {bar.time_s} in {path}")
            bars[bar.time_s] = bar
    ordered = list(bars)
    if ordered != sorted(ordered):
        raise ValueError(f"M1 timestamps are not strictly ordered in {path}")
    return bars


def estimate_best_offset_seconds(
    candidate_times: Iterable[int],
    reference_times: Iterable[int],
) -> tuple[int | None, int]:
    """Estimate a systematic minute offset by maximum timestamp intersection."""

    candidate = set(candidate_times)
    reference = set(reference_times)
    if not candidate or not reference:
        return None, 0
    scored: list[tuple[int, int]] = []
    for offset in range(-7200, 7201, 60):
        matches = sum(1 for value in candidate if value + offset in reference)
        scored.append((matches, offset))
    best_count = max(item[0] for item in scored)
    if best_count <= 0:
        return None, 0
    best_offsets = [offset for matches, offset in scored if matches == best_count]
    best_offset = min(best_offsets, key=lambda value: (abs(value), value))
    return best_offset, best_count


def _dst_windows(
    start_s: int,
    end_s: int,
    dukascopy: Mapping[int, Bar],
    dwx: Mapping[int, Bar],
) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    start_year = dt.datetime.fromtimestamp(start_s, tz=UTC).year - 1
    end_year = dt.datetime.fromtimestamp(end_s, tz=UTC).year + 1
    for year in range(start_year, end_year + 1):
        start, end = us_dst_bounds_utc(year)
        for label, transition in (("US_DST_START", start), ("US_DST_END", end)):
            center = broker_epoch_seconds_for_utc(transition)
            lower = center - 7 * 86400
            upper = center + 7 * 86400
            if upper < start_s or lower > end_s:
                continue
            duk_times = [value for value in dukascopy if lower <= value <= upper]
            dwx_times = [value for value in dwx if lower <= value <= upper]
            offset, matches = estimate_best_offset_seconds(duk_times, dwx_times)
            result.append({
                "transition": label,
                "year": year,
                "transition_utc": transition.isoformat().replace("+00:00", "Z"),
                "dukascopy_bars": len(duk_times),
                "dwx_bars": len(dwx_times),
                "best_offset_seconds": offset,
                "matched_at_best_offset": matches,
                "pass": offset == REQUIRED_DST_OFFSET_SECONDS and matches > 0,
            })
    return result


def reconcile_symbol(
    *,
    symbol: str,
    dukascopy_csv: Path,
    dwx_csv: Path,
    point_size: float | None = None,
    typical_spread_points: float | None = None,
) -> dict[str, object]:
    started = time.monotonic()
    symbol = str(symbol).strip().upper()
    effective_point = float(
        default_point_size(symbol) or 0 if point_size is None else point_size
    )
    if not math.isfinite(effective_point) or effective_point <= 0:
        raise ValueError(
            f"{symbol} requires an explicit positive point_size from reviewed metadata"
        )
    dukascopy = read_m1_csv(dukascopy_csv)
    dwx = read_m1_csv(dwx_csv)
    start_s = max(min(dukascopy), min(dwx))
    end_s = min(max(dukascopy), max(dwx))
    if start_s > end_s:
        raise ValueError(f"no M1 overlap for {symbol}")
    duk_overlap = {key: value for key, value in dukascopy.items() if start_s <= key <= end_s}
    dwx_overlap = {key: value for key, value in dwx.items() if start_s <= key <= end_s}
    common_times = sorted(set(duk_overlap) & set(dwx_overlap))
    if not common_times:
        raise ValueError(f"no exact M1 timestamp matches for {symbol}")

    deltas: dict[str, list[float]] = {name: [] for name in ("open", "high", "low", "close")}
    for timestamp in common_times:
        left = duk_overlap[timestamp]
        right = dwx_overlap[timestamp]
        for field in deltas:
            deltas[field].append(abs(getattr(left, field) - getattr(right, field)) / effective_point)

    dwx_spreads = [
        float(bar.spread_points)
        for bar in dwx_overlap.values()
        if bar.spread_points is not None and bar.spread_points > 0
    ]
    dukascopy_spreads = [
        float(bar.spread_points)
        for bar in duk_overlap.values()
        if bar.spread_points is not None and bar.spread_points > 0
    ]
    if typical_spread_points is not None:
        effective_spread = float(typical_spread_points)
        typical_spread_source = "operator_input"
    elif dwx_spreads:
        effective_spread = statistics.median(dwx_spreads)
        typical_spread_source = "dwx_median"
    elif dukascopy_spreads:
        effective_spread = statistics.median(dukascopy_spreads)
        typical_spread_source = "dukascopy_median_fallback"
    else:
        raise ValueError(
            f"{symbol} has no spread observations; supply typical_spread_points"
        )
    if not math.isfinite(effective_spread) or effective_spread <= 0:
        raise ValueError("typical spread must be finite and positive")

    dwx_coverage = len(common_times) / len(dwx_overlap)
    dukascopy_coverage = len(common_times) / len(duk_overlap)
    coverage = min(dwx_coverage, dukascopy_coverage)
    matched_duk_volume = sum(duk_overlap[key].tick_volume for key in common_times)
    matched_dwx_volume = sum(dwx_overlap[key].tick_volume for key in common_times)
    density_ratio = (
        matched_duk_volume / matched_dwx_volume if matched_dwx_volume > 0 else None
    )
    metrics: dict[str, object] = {}
    for field, values in deltas.items():
        metrics[f"{field}_delta_median_points"] = statistics.median(values)
        metrics[f"{field}_delta_p95_points"] = percentile(values, 0.95)
    for source, values in (
        ("dukascopy", dukascopy_spreads),
        ("dwx", dwx_spreads),
    ):
        metrics[f"{source}_spread_median_points"] = (
            statistics.median(values) if values else None
        )
        metrics[f"{source}_spread_p95_points"] = (
            percentile(values, 0.95) if values else None
        )

    dst_windows = _dst_windows(start_s, end_s, duk_overlap, dwx_overlap)
    transition_types = {str(item["transition"]) for item in dst_windows}
    dst_complete = {"US_DST_START", "US_DST_END"}.issubset(transition_types)
    dst_exact = dst_complete and all(bool(item["pass"]) for item in dst_windows)
    overlap_window_complete = (
        start_s <= broker_epoch_seconds_for_utc(REQUIRED_OVERLAP_START)
        and end_s >= broker_epoch_seconds_for_utc(REQUIRED_OVERLAP_END)
    )
    close_limit = CLOSE_P95_SPREAD_MULTIPLIER * effective_spread
    checks = {
        "close_delta_p95": metrics["close_delta_p95_points"] <= close_limit,
        "session_coverage": coverage >= MIN_SESSION_COVERAGE,
        "dst_zero_second_offset": dst_exact,
        "required_overlap_window": overlap_window_complete,
    }
    compute_seconds = time.monotonic() - started
    checks["compute_budget"] = compute_seconds < MAX_COMPUTE_SECONDS
    status = "PASS" if all(checks.values()) else "FAIL"
    return {
        "schema": SUMMARY_SCHEMA,
        "symbol": symbol,
        "status": status,
        "production_splice_authorized": False,
        "dukascopy_csv": str(dukascopy_csv.resolve()),
        "dukascopy_csv_sha256": sha256_file(dukascopy_csv.resolve()),
        "dwx_csv": str(dwx_csv.resolve()),
        "dwx_csv_sha256": sha256_file(dwx_csv.resolve()),
        "overlap_first_broker_epoch": start_s,
        "overlap_last_broker_epoch": end_s,
        "dukascopy_m1_bars": len(duk_overlap),
        "dwx_m1_bars": len(dwx_overlap),
        "matched_m1_bars": len(common_times),
        "session_coverage": coverage,
        "dwx_coverage": dwx_coverage,
        "dukascopy_coverage": dukascopy_coverage,
        "tick_density_ratio": density_ratio,
        "point_size": effective_point,
        "typical_spread_points": effective_spread,
        "typical_spread_source": typical_spread_source,
        "close_delta_p95_limit_points": close_limit,
        **metrics,
        "dst_windows": dst_windows,
        "checks": checks,
        "compute_seconds": compute_seconds,
    }


SUMMARY_COLUMNS = [
    "symbol", "status", "matched_m1_bars", "dwx_m1_bars", "session_coverage",
    "open_delta_median_points", "open_delta_p95_points",
    "high_delta_median_points", "high_delta_p95_points",
    "low_delta_median_points", "low_delta_p95_points",
    "close_delta_median_points", "close_delta_p95_points",
    "typical_spread_points", "close_delta_p95_limit_points",
    "tick_density_ratio", "dukascopy_spread_median_points",
    "dukascopy_spread_p95_points", "dwx_spread_median_points",
    "dwx_spread_p95_points",
    "dst_zero_second_offset", "compute_seconds",
]


def _csv_text(rows: Sequence[Mapping[str, object]]) -> str:
    import io

    buffer = io.StringIO(newline="")
    writer = csv.DictWriter(buffer, fieldnames=SUMMARY_COLUMNS, lineterminator="\n")
    writer.writeheader()
    for result in rows:
        flat = {key: result.get(key) for key in SUMMARY_COLUMNS}
        flat["dst_zero_second_offset"] = (result.get("checks") or {}).get(
            "dst_zero_second_offset"
        )
        writer.writerow(flat)
    return buffer.getvalue()


def _summary_markdown(rows: Sequence[Mapping[str, object]]) -> str:
    passed = sum(row.get("status") == "PASS" for row in rows)
    lines = [
        "# Dukascopy/DWX overlap reconciliation",
        "",
        f"Symbols: {len(rows)}; PASS: {passed}; FAIL: {len(rows) - passed}.",
        "",
        "A PASS here is a source-compatibility result only. It does not enqueue or authorize an import.",
        "",
        "| Symbol | Result | Close p95 (points) | Limit | Coverage | DST offset |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for row in rows:
        windows = row.get("dst_windows") or []
        offsets = sorted({str(item.get("best_offset_seconds")) for item in windows})
        lines.append(
            f"| {row['symbol']} | {row['status']} | "
            f"{float(row['close_delta_p95_points']):.6g} | "
            f"{float(row['close_delta_p95_limit_points']):.6g} | "
            f"{float(row['session_coverage']):.3%} | {','.join(offsets)} |"
        )
    lines.extend([
        "",
        "Fixed acceptance: overlap spans at least 2025-11-01 through 2026-04-01 and both intervening US-DST transition types; close p95 <= 1.5 x typical DWX spread; DWX session coverage >= 99%; every observed US-DST transition window has a best timestamp offset of 0 seconds; compute time < 2 hours.",
        "",
    ])
    return "\n".join(lines)


def write_results(results: Sequence[dict[str, object]], out_dir: Path) -> dict[str, object]:
    out_dir = out_dir.resolve()
    if out_dir.exists():
        raise ValueError(f"immutable reconciliation output already exists: {out_dir}")
    out_dir.mkdir(parents=True)
    for result in results:
        symbol_name = str(result["symbol"]).replace(".", "_")
        atomic_write_text(
            out_dir / f"{symbol_name}_reconciliation.csv", _csv_text([result])
        )
        atomic_write_json(out_dir / f"{symbol_name}_reconciliation.json", result)
    atomic_write_text(out_dir / "reconciliation_summary.csv", _csv_text(results))
    atomic_write_json(
        out_dir / "reconciliation_summary.json",
        {
            "schema": SUMMARY_SCHEMA,
            "status": "PASS" if results and all(row["status"] == "PASS" for row in results) else "FAIL",
            "production_splice_authorized": False,
            "thresholds": {
                "close_delta_p95_spread_multiplier": CLOSE_P95_SPREAD_MULTIPLIER,
                "minimum_session_coverage": MIN_SESSION_COVERAGE,
                "required_dst_offset_seconds": REQUIRED_DST_OFFSET_SECONDS,
                "maximum_compute_seconds": MAX_COMPUTE_SECONDS,
                "required_overlap_start_utc": REQUIRED_OVERLAP_START.isoformat().replace(
                    "+00:00", "Z"
                ),
                "required_overlap_end_utc": REQUIRED_OVERLAP_END.isoformat().replace(
                    "+00:00", "Z"
                ),
            },
            "results": list(results),
        },
    )
    atomic_write_text(out_dir / "README.md", _summary_markdown(results))
    return {
        "status": "PASS" if results and all(row["status"] == "PASS" for row in results) else "FAIL",
        "out_dir": str(out_dir),
        "symbols": len(results),
    }


def _jobs_from_args(args: argparse.Namespace) -> list[dict[str, object]]:
    if args.jobs:
        value = json.loads(args.jobs.read_text(encoding="utf-8"))
        if not isinstance(value, list) or not value:
            raise ValueError("jobs JSON must be a non-empty array")
        jobs = value
    else:
        required = (args.symbol, args.dukascopy_csv, args.dwx_csv)
        if any(value is None for value in required):
            raise ValueError(
                "provide --jobs or all of --symbol, --dukascopy-csv, --dwx-csv"
            )
        jobs = [{
            "symbol": args.symbol,
            "dukascopy_csv": str(args.dukascopy_csv),
            "dwx_csv": str(args.dwx_csv),
            "point_size": args.point_size,
            "typical_spread_points": args.typical_spread_points,
        }]
    return jobs


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=Path)
    parser.add_argument("--symbol")
    parser.add_argument("--dukascopy-csv", type=Path)
    parser.add_argument("--dwx-csv", type=Path)
    parser.add_argument("--point-size", type=float)
    parser.add_argument("--typical-spread-points", type=float)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        jobs = _jobs_from_args(args)
        results = [
            reconcile_symbol(
                symbol=str(job["symbol"]),
                dukascopy_csv=Path(str(job["dukascopy_csv"])),
                dwx_csv=Path(str(job["dwx_csv"])),
                point_size=(
                    float(job["point_size"]) if job.get("point_size") is not None else None
                ),
                typical_spread_points=(
                    float(job["typical_spread_points"])
                    if job.get("typical_spread_points") is not None else None
                ),
            )
            for job in jobs
        ]
        summary = write_results(results, args.out)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({"status": "REFUSED", "error": str(exc)}))
        return 2
    print(json.dumps(summary, sort_keys=True))
    return 0 if summary["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
