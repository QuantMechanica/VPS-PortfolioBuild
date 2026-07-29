#!/usr/bin/env python3
"""Reproducible tick-vs-timer trade and FUND_SCORE deviation analysis.

The comparator pairs exact rows first, then same-entry/same-volume rows, and
finally accounts for different-entry/extra/missing rows.  Economic metrics use
the established 100k-account, rolling-60-calendar-day formulation from
``portfolio/sleeve_improvement_targets.py``.
"""

from __future__ import annotations

import argparse
import bisect
import datetime as dt
import hashlib
import json
import os
import statistics
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

try:
    from . import dxz_cost_evidence
except ImportError:  # direct script execution
    import dxz_cost_evidence  # type: ignore


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_closed(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("event") == "TRADE_CLOSED":
                rows.append(row)
    return rows


def load_native_report(path: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    trips, stats = dxz_cost_evidence.extract_round_trips(path)
    rows: list[dict[str, Any]] = []
    for trip in trips:
        entry = dt.datetime.strptime(trip.entry_time, "%Y.%m.%d %H:%M:%S").replace(tzinfo=dt.UTC)
        exit_at = dt.datetime.strptime(trip.exit_time, "%Y.%m.%d %H:%M:%S").replace(tzinfo=dt.UTC)
        rows.append({
            "event": "TRADE_CLOSED",
            "entry_time": int(entry.timestamp()),
            "time": int(exit_at.timestamp()),
            "volume": trip.volume,
            "net": trip.gross_pnl + trip.recorded_swap + trip.native_commission,
        })
    report_net = stats.get("report_net")
    parsed_net = sum(float(row["net"]) for row in rows)
    if report_net is None or abs(parsed_net - float(report_net)) > 0.01:
        raise ValueError(
            f"native report net does not reconcile: parsed={parsed_net} report={report_net}"
        )
    return rows, stats


def _near(left: Any, right: Any, tolerance: float) -> bool:
    return abs(float(left or 0.0) - float(right or 0.0)) <= tolerance


def _exact(timer: dict[str, Any], tick: dict[str, Any], money_tol: float, vol_tol: float) -> bool:
    return (
        int(timer.get("entry_time") or 0) == int(tick.get("entry_time") or 0)
        and int(timer.get("time") or 0) == int(tick.get("time") or 0)
        and _near(timer.get("volume"), tick.get("volume"), vol_tol)
        and _near(timer.get("net"), tick.get("net"), money_tol)
    )


def _same_entry(timer: dict[str, Any], tick: dict[str, Any], vol_tol: float) -> bool:
    return (
        int(timer.get("entry_time") or 0) == int(tick.get("entry_time") or 0)
        and _near(timer.get("volume"), tick.get("volume"), vol_tol)
    )


def pair_trades(
    timer: list[dict[str, Any]],
    tick: list[dict[str, Any]],
    *,
    money_tol: float = 0.005,
    vol_tol: float = 0.005,
) -> dict[str, Any]:
    remaining_tick = list(tick)
    remaining_timer: list[dict[str, Any]] = []
    exact_pairs: list[tuple[dict[str, Any], dict[str, Any]]] = []
    for timer_row in timer:
        match = next(
            (row for row in remaining_tick if _exact(timer_row, row, money_tol, vol_tol)),
            None,
        )
        if match is None:
            remaining_timer.append(timer_row)
        else:
            exact_pairs.append((timer_row, match))
            remaining_tick.remove(match)

    same_entry_pairs: list[tuple[dict[str, Any], dict[str, Any]]] = []
    still_timer: list[dict[str, Any]] = []
    for timer_row in remaining_timer:
        match = next(
            (row for row in remaining_tick if _same_entry(timer_row, row, vol_tol)),
            None,
        )
        if match is None:
            still_timer.append(timer_row)
        else:
            same_entry_pairs.append((timer_row, match))
            remaining_tick.remove(match)

    different_entry = min(len(still_timer), len(remaining_tick))
    extra_timer = len(still_timer) - different_entry
    missing_timer = len(remaining_tick) - different_entry
    same_close_different_net = [
        pair for pair in same_entry_pairs
        if int(pair[0].get("time") or 0) == int(pair[1].get("time") or 0)
    ]
    shifted_exit = [
        pair for pair in same_entry_pairs
        if int(pair[0].get("time") or 0) != int(pair[1].get("time") or 0)
    ]
    shifts = [
        int(timer_row.get("time") or 0) - int(tick_row.get("time") or 0)
        for timer_row, tick_row in shifted_exit
    ]
    absolute_shifts = sorted(abs(value) for value in shifts)
    cross_date = sum(
        dt.datetime.fromtimestamp(int(timer_row.get("time") or 0), tz=dt.UTC).date()
        != dt.datetime.fromtimestamp(int(tick_row.get("time") or 0), tz=dt.UTC).date()
        for timer_row, tick_row in shifted_exit
    )
    timer_session_end_cluster = sum(
        dt.datetime.fromtimestamp(int(timer_row.get("time") or 0), tz=dt.UTC).strftime("%H:%M")
        == "20:55"
        for timer_row, _ in shifted_exit
    )
    largest_shifts = sorted(
        (
            {
                "entry_utc": dt.datetime.fromtimestamp(
                    int(timer_row.get("entry_time") or 0), tz=dt.UTC
                ).isoformat(),
                "tick_exit_utc": dt.datetime.fromtimestamp(
                    int(tick_row.get("time") or 0), tz=dt.UTC
                ).isoformat(),
                "timer_exit_utc": dt.datetime.fromtimestamp(
                    int(timer_row.get("time") or 0), tz=dt.UTC
                ).isoformat(),
                "shift_seconds": int(timer_row.get("time") or 0) - int(tick_row.get("time") or 0),
                "volume": float(timer_row.get("volume") or 0.0),
                "tick_net": float(tick_row.get("net") or 0.0),
                "timer_net": float(timer_row.get("net") or 0.0),
                "net_delta": float(timer_row.get("net") or 0.0) - float(tick_row.get("net") or 0.0),
            }
            for timer_row, tick_row in shifted_exit
        ),
        key=lambda row: abs(int(row["shift_seconds"])),
        reverse=True,
    )[:10]

    def percentile(values: list[int], fraction: float) -> int | None:
        if not values:
            return None
        return values[int(fraction * (len(values) - 1))]

    return {
        "timer_trades": len(timer),
        "tick_trades": len(tick),
        "exact": len(exact_pairs),
        "same_entry_same_close_different_net": len(same_close_different_net),
        "same_entry_shifted_exit": len(shifted_exit),
        "same_entry_total_non_exact": len(same_entry_pairs),
        "different_entry": different_entry,
        "extra_timer": extra_timer,
        "missing_timer_tick_only": missing_timer,
        "entry_identity_rate": (
            (len(exact_pairs) + len(same_entry_pairs)) / max(len(timer), len(tick))
            if timer or tick else 1.0
        ),
        "exact_rate": len(exact_pairs) / max(len(timer), len(tick)) if timer or tick else 1.0,
        "exit_shift_seconds": {
            "count": len(shifts),
            "median_abs": statistics.median(absolute_shifts) if absolute_shifts else None,
            "p90_abs": percentile(absolute_shifts, 0.90),
            "max_abs": max(absolute_shifts) if absolute_shifts else None,
            "min_signed": min(shifts) if shifts else None,
            "max_signed": max(shifts) if shifts else None,
            "timer_earlier": sum(value < 0 for value in shifts),
            "timer_later": sum(value > 0 for value in shifts),
            "at_most_1s": sum(abs(value) <= 1 for value in shifts),
            "at_most_5s": sum(abs(value) <= 5 for value in shifts),
            "at_most_10s": sum(abs(value) <= 10 for value in shifts),
            "at_most_30s": sum(abs(value) <= 30 for value in shifts),
            "at_most_60s": sum(abs(value) <= 60 for value in shifts),
            "over_60s": sum(abs(value) > 60 for value in shifts),
            "over_3600s": sum(abs(value) > 3600 for value in shifts),
            "cross_calendar_date": cross_date,
            "timer_exit_at_20_55_report_time": timer_session_end_cluster,
        },
        "largest_exit_shifts": largest_shifts,
    }


def economic_metrics(rows: list[dict[str, Any]], *, account: float = 100_000.0) -> dict[str, Any]:
    close_net = sorted(
        (
            dt.datetime.fromtimestamp(int(row["time"]), tz=dt.UTC).date(),
            float(row.get("net") or 0.0),
        )
        for row in rows
    )
    closes = [value[0] for value in close_net]
    nets = [value[1] for value in close_net]
    rolls: list[float] = []
    drawdowns: list[float] = []
    for index, start in enumerate(closes):
        # A 60-calendar-day window counts its starting day as day one, hence
        # the inclusive endpoint is start + 59 days.  This reproduces the
        # preregistered tick values (med60 1.76274, wDD p90 5.01877).
        end = start + dt.timedelta(days=59)
        stop = bisect.bisect_right(closes, end)
        window = nets[index:stop]
        rolls.append(sum(window) / account * 100.0)
        equity = peak = drawdown = 0.0
        for value in window:
            equity += value
            peak = max(peak, equity)
            drawdown = max(drawdown, peak - equity)
        drawdowns.append(drawdown / account * 100.0)
    by_day: dict[dt.date, float] = defaultdict(float)
    for close, net in close_net:
        by_day[close] += net
    med60 = statistics.median(rolls) if rolls else 0.0
    worst_day = abs(min(by_day.values())) / account * 100.0 if by_day else 0.0
    ordered_dd = sorted(drawdowns)
    wdd_p90 = ordered_dd[int(len(ordered_dd) * 0.9)] if ordered_dd else 0.0
    denominator = max(2.0, 2.0 * worst_day, wdd_p90)
    return {
        "trades": len(rows),
        "net": sum(nets),
        "med60_pct": med60,
        "worst_day_abs_pct": worst_day,
        "wdd_p90_pct": wdd_p90,
        "fund_score": med60 / denominator if denominator else 0.0,
        "fund_score_denominator": denominator,
    }


def analyze(
    timer_path: Path,
    tick_path: Path,
    *,
    native_reports: bool = False,
    timer_stream_path: Path | None = None,
) -> dict[str, Any]:
    timer_stats = tick_stats = None
    if native_reports:
        timer, timer_stats = load_native_report(timer_path)
        tick, tick_stats = load_native_report(tick_path)
    else:
        timer = load_closed(timer_path)
        tick = load_closed(tick_path)
    pairing = pair_trades(timer, tick)
    timer_metrics = economic_metrics(timer)
    tick_metrics = economic_metrics(tick)
    deltas: dict[str, dict[str, float | None]] = {}
    for key in ("trades", "net", "med60_pct", "worst_day_abs_pct", "wdd_p90_pct", "fund_score"):
        timer_value = float(timer_metrics[key])
        tick_value = float(tick_metrics[key])
        absolute = timer_value - tick_value
        relative = absolute / abs(tick_value) * 100.0 if tick_value else None
        deltas[key] = {"absolute": absolute, "relative_pct": relative}
    economic_bound = all(
        delta["relative_pct"] is not None and abs(float(delta["relative_pct"])) <= 10.0
        for delta in deltas.values()
    )
    timer_block: dict[str, Any] = {
        "path": str(timer_path),
        "sha256": sha256_file(timer_path),
        "kind": "native_mt5_report" if native_reports else "trade_stream",
    }
    tick_block: dict[str, Any] = {
        "path": str(tick_path),
        "sha256": sha256_file(tick_path),
        "kind": "native_mt5_report" if native_reports else "trade_stream",
    }
    if timer_stats is not None:
        timer_block["report_stats"] = timer_stats
    if tick_stats is not None:
        tick_block["report_stats"] = tick_stats
    stream_binding = None
    if timer_stream_path is not None:
        stream_rows = load_closed(timer_stream_path)
        report_identity = Counter(
            (int(row["entry_time"]), int(row["time"]), round(float(row["volume"]), 8))
            for row in timer
        )
        stream_identity = Counter(
            (int(row["entry_time"]), int(row["time"]), round(float(row["volume"]), 8))
            for row in stream_rows
        )
        stream_binding = {
            "path": str(timer_stream_path),
            "sha256": sha256_file(timer_stream_path),
            "trade_count": len(stream_rows),
            "native_report_trade_count": len(timer),
            "entry_exit_volume_identity_match": stream_identity == report_identity,
        }
    return {
        "schema_version": 3,
        "timer": timer_block,
        "tick": tick_block,
        "timer_stream_binding": stream_binding,
        "pairing": pairing,
        "economics": {"timer": timer_metrics, "tick": tick_metrics, "delta": deltas},
        "preregistered_checks": {
            "economic_components_within_10pct": economic_bound,
            "no_worse_single_day_loss": (
                timer_metrics["worst_day_abs_pct"] <= tick_metrics["worst_day_abs_pct"]
            ),
            "entry_identity": (
                pairing["different_entry"] == 0
                and pairing["extra_timer"] == 0
                and pairing["missing_timer_tick_only"] == 0
            ),
            "median_shift_at_most_1s": (
                pairing["exit_shift_seconds"]["median_abs"] is None
                or pairing["exit_shift_seconds"]["median_abs"] <= 1.0
            ),
        },
    }


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    if path.exists():
        raise FileExistsError(f"output already exists: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    try:
        with temp.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timer", required=True, type=Path)
    parser.add_argument("--tick", required=True, type=Path)
    parser.add_argument(
        "--native-reports",
        action="store_true",
        help="parse both inputs as native MT5 report.htm files",
    )
    parser.add_argument(
        "--timer-stream",
        type=Path,
        help="optional harvested timer JSONL to bind by entry/exit/volume identity",
    )
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = analyze(
        args.timer,
        args.tick,
        native_reports=args.native_reports,
        timer_stream_path=args.timer_stream,
    )
    if args.output:
        _write_json(args.output, result)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
