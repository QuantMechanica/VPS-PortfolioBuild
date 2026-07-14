"""Rank FTMO strategy candidates by return density versus conservative daily MAE.

The Q08 trade stream stores each trade's lifetime MAE. Summing that MAE across
all trades spanning a CE(S)T day deliberately assumes their worst excursions
occur together. The resulting daily-risk figure is conservative and is useful
for prescreening; it is not a replacement for per-bar equity reconstruction.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path
from typing import Iterable

try:
    from .ftmo_phase1_mae import Q08, ftmo_calendar_day, q08_round_trip_values
except ImportError:  # direct script execution
    from ftmo_phase1_mae import Q08, ftmo_calendar_day, q08_round_trip_values


def _number(value: object) -> float | None:
    try:
        result = float(value)
    except (TypeError, ValueError):
        return None
    return result if math.isfinite(result) else None


def load_closed_trades(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            try:
                row = json.loads(line)
            except (json.JSONDecodeError, TypeError):
                continue
            if row.get("event") not in (None, "TRADE_CLOSED"):
                continue
            net = _number(row.get("net"))
            close_time = _number(row.get("time"))
            entry_time = _number(row.get("entry_time"))
            mae_acct = _number(row.get("mae_acct"))
            if None in (net, close_time, entry_time, mae_acct):
                continue
            corrected_net, corrected_mae = q08_round_trip_values(row)
            rows.append(
                {
                    "net": corrected_net,
                    "time": close_time,
                    "entry_time": entry_time,
                    "mae_acct": corrected_mae,
                }
            )
    return rows


def analyze_rows(
    rows: Iterable[dict],
    *,
    ea_id: int,
    symbol: str,
    internal_daily_limit: float = 4_000.0,
) -> dict:
    trades = list(rows)
    if not trades:
        raise ValueError(f"no fresh closed trades for {ea_id}/{symbol}")

    profits = [float(row["net"]) for row in trades if float(row["net"]) > 0.0]
    losses = [float(row["net"]) for row in trades if float(row["net"]) < 0.0]
    gross_profit = sum(profits)
    gross_loss = abs(sum(losses))
    total_net = sum(float(row["net"]) for row in trades)

    first_entry = min(float(row["entry_time"]) for row in trades)
    last_close = max(float(row["time"]) for row in trades)
    span_days = max(1.0, (last_close - first_entry) / 86_400.0)
    years = span_days / 365.2425

    daily_mae: defaultdict[object, float] = defaultdict(float)
    hold_hours: list[float] = []
    for row in trades:
        entry = float(row["entry_time"])
        close = float(row["time"])
        hold_hours.append(max(0.0, close - entry) / 3_600.0)
        day = ftmo_calendar_day(entry)
        close_day = ftmo_calendar_day(close)
        while day <= close_day:
            daily_mae[day] += float(row["mae_acct"])
            day += dt.timedelta(days=1)

    worst_daily_mae = abs(min(daily_mae.values(), default=0.0))
    daily_scale_cap = (
        internal_daily_limit / worst_daily_mae if worst_daily_mae > 0.0 else 0.0
    )
    annual_net = total_net / years
    return {
        "ea_id": ea_id,
        "symbol": symbol,
        "trades": len(trades),
        "span_years": round(years, 4),
        "trades_per_year": round(len(trades) / years, 2),
        "profit_factor": round(gross_profit / gross_loss, 4) if gross_loss else None,
        "total_net_base": round(total_net, 2),
        "annual_net_base": round(annual_net, 2),
        "worst_conservative_daily_mae_base": round(worst_daily_mae, 2),
        "annual_net_per_daily_mae": round(annual_net / worst_daily_mae, 4)
        if worst_daily_mae
        else None,
        "scale_at_internal_daily_limit": round(daily_scale_cap, 4),
        "annual_net_at_internal_daily_limit": round(annual_net * daily_scale_cap, 2),
        "median_hold_hours": round(statistics.median(hold_hours), 2),
        "max_hold_hours": round(max(hold_hours), 2),
        "method": "lifetime_mae_plus_entry_commission_summed_on_each_spanned_cest_day",
    }


def parse_candidate(value: str) -> tuple[int, str]:
    try:
        ea_raw, symbol = value.split(":", 1)
        ea_id = int(ea_raw.removeprefix("QM5_"))
    except (ValueError, AttributeError) as exc:
        raise argparse.ArgumentTypeError("candidate must be EA_ID:SYMBOL.DWX") from exc
    return ea_id, symbol


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", action="append", type=parse_candidate, required=True)
    parser.add_argument("--q08-dir", type=Path, default=Q08)
    parser.add_argument("--internal-daily-limit", type=float, default=4_000.0)
    parser.add_argument("--csv", type=Path)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()

    results = []
    for ea_id, symbol in args.candidate:
        stream = args.q08_dir / f"{ea_id}_{symbol.replace('.', '_')}.jsonl"
        results.append(
            analyze_rows(
                load_closed_trades(stream),
                ea_id=ea_id,
                symbol=symbol,
                internal_daily_limit=args.internal_daily_limit,
            )
        )
    results.sort(
        key=lambda row: row["annual_net_per_daily_mae"]
        if row["annual_net_per_daily_mae"] is not None
        else float("-inf"),
        reverse=True,
    )

    if args.csv:
        args.csv.parent.mkdir(parents=True, exist_ok=True)
        with args.csv.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(results[0]))
            writer.writeheader()
            writer.writerows(results)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
