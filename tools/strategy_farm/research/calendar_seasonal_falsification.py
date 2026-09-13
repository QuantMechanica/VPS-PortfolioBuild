#!/usr/bin/env python3
"""Cheap, deterministic Edge-Lab calendar/seasonal falsification on M5 exports.

This is research only: it reads existing T_Export CSVs and never invokes MT5.
Returns are gross BID-to-BID returns; spreads, slippage, and stops are absent.
"""

from __future__ import annotations

import argparse
import csv
import math
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from statistics import fmean, stdev


UTC = timezone.utc
DEFAULT_BARS = Path("D:/QM/mt5/T_Export/MQL5/Files")
DEFAULT_OUT = Path("docs/research/edge_lab/calendar_seasonal_falsification.csv")


@dataclass(frozen=True)
class Trial:
    thesis_id: str
    symbol: str
    event_utc: str
    signed_return_bp: float


class Bars:
    def __init__(self, path: Path):
        self.path = path
        self.rows: dict[int, tuple[float, float]] = {}
        with path.open("r", encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                self.rows[int(row["time"])] = (float(row["open"]), float(row["close"]))
        self.epochs = sorted(self.rows)
        self.days = sorted({datetime.fromtimestamp(e, UTC).date() for e in self.epochs})

    def open_at(self, day, hour: int, minute: int = 0):
        epoch = int(datetime(day.year, day.month, day.day, hour, minute, tzinfo=UTC).timestamp())
        row = self.rows.get(epoch)
        return None if row is None else row[0]

    def first_open(self, day):
        start = int(datetime(day.year, day.month, day.day, tzinfo=UTC).timestamp())
        for epoch in range(start, start + 24 * 3600, 300):
            row = self.rows.get(epoch)
            if row is not None:
                return row[0]
        return None


def signed_bp(a: float | None, b: float | None, direction: int) -> float | None:
    if a is None or b is None or a <= 0:
        return None
    return direction * 10_000.0 * (b / a - 1.0)


def add(trials, thesis, symbol, day, value):
    if value is not None and math.isfinite(value):
        trials.append(Trial(thesis, symbol, day.isoformat(), value))


def fixed_window(trials, thesis, symbol, bars, days, start_h, end_h, direction):
    for day in days:
        add(trials, thesis, symbol, day,
            signed_bp(bars.open_at(day, start_h), bars.open_at(day, end_h), direction))


def conditional_window(trials, thesis, symbol, bars, days, pre_h, pivot_h, end_h, fade):
    for day in days:
        a, p, z = bars.open_at(day, pre_h), bars.open_at(day, pivot_h), bars.open_at(day, end_h)
        if a is None or p is None or z is None or a == p:
            continue
        direction = 1 if p > a else -1
        if fade:
            direction *= -1
        add(trials, thesis, symbol, day, signed_bp(p, z, direction))


def generate(series: dict[str, Bars]) -> tuple[list[Trial], list[tuple[str, str, str]]]:
    trials: list[Trial] = []
    unavailable: list[tuple[str, str, str]] = []

    def need(thesis, symbol):
        b = series.get(symbol)
        if b is None:
            unavailable.append((thesis, symbol, "MISSING_M5_EXPORT"))
        return b

    # Month/quarter turn: positions start at 16:00 UTC on the final trading day.
    for thesis, symbol, direction, quarters_only in [
        ("CAL-01", "EURUSD.DWX", 1, False),
        ("CAL-02", "GBPUSD.DWX", 1, False),
        ("CAL-03", "USDJPY.DWX", -1, False),
        ("CAL-04", "XAUUSD.DWX", 1, False),
        ("CAL-07", "EURUSD.DWX", 1, True),
    ]:
        b = need(thesis, symbol)
        if not b:
            continue
        for left, right in zip(b.days, b.days[1:]):
            if left.month == right.month or (quarters_only and left.month not in (3, 6, 9, 12)):
                continue
            add(trials, thesis, symbol, left,
                signed_bp(b.open_at(left, 16), b.open_at(right, 16), direction))

    # Named monthly seasonal windows: first through sixth trading-day open.
    for thesis, month in [("CAL-05", 1), ("CAL-06", 8)]:
        b = need(thesis, "XAUUSD.DWX")
        if not b:
            continue
        years = sorted({d.year for d in b.days})
        for year in years:
            ds = [d for d in b.days if d.year == year and d.month == month]
            if len(ds) >= 6:
                add(trials, thesis, "XAUUSD.DWX", ds[0],
                    signed_bp(b.first_open(ds[0]), b.first_open(ds[5]), 1))

    # Time-of-day continuation / reversal windows, UTC by construction.
    for thesis, symbol, pre_h, pivot_h, end_h, fade in [
        ("CAL-08", "GBPUSD.DWX", 7, 8, 12, False),
        ("CAL-09", "USDJPY.DWX", 0, 1, 3, True),
        ("CAL-10", "EURUSD.DWX", 15, 16, 17, True),
        ("CAL-11", "XAUUSD.DWX", 14, 15, 16, True),
    ]:
        b = need(thesis, symbol)
        if b:
            conditional_window(trials, thesis, symbol, b, b.days, pre_h, pivot_h, end_h, fade)

    # Friday late-session direction fading during the final four UTC hours.
    b = need("CAL-12", "EURUSD.DWX")
    if b:
        conditional_window(trials, "CAL-12", "EURUSD.DWX", b,
                           [d for d in b.days if d.weekday() == 4], 12, 16, 20, True)

    # These are deliberately emitted as data gaps rather than silently substituted.
    need("CAL-13", "NDX.DWX")
    need("CAL-14", "SP500.DWX")
    need("CAL-15", "XTIUSD.DWX")
    return trials, unavailable


def stats(values: list[float]):
    n = len(values)
    mean = fmean(values) if values else float("nan")
    sd = stdev(values) if n > 1 else float("nan")
    t = mean / (sd / math.sqrt(n)) if n > 1 and sd > 0 else float("nan")
    win = sum(v > 0 for v in values) / n if n else float("nan")
    return n, mean, t, win


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bars-dir", type=Path, default=DEFAULT_BARS)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    symbols = ["EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "XAUUSD.DWX",
               "NDX.DWX", "SP500.DWX", "XTIUSD.DWX"]
    series = {s: Bars(args.bars_dir / f"{s}_M5.csv") for s in symbols
              if (args.bars_dir / f"{s}_M5.csv").is_file()}
    trials, unavailable = generate(series)
    rows = []
    keys = sorted({(t.thesis_id, t.symbol) for t in trials})
    for thesis, symbol in keys:
        own = [t for t in trials if t.thesis_id == thesis and t.symbol == symbol]
        scopes = {
            "ALL": own,
            "IS_2017_2022": [t for t in own if int(t.event_utc[:4]) <= 2022],
            "OOS_2023_2026": [t for t in own if int(t.event_utc[:4]) >= 2023],
        }
        all_n, all_mean, all_t, _ = stats([t.signed_return_bp for t in own])
        is_mean = stats([t.signed_return_bp for t in scopes["IS_2017_2022"]])[1]
        oos_mean = stats([t.signed_return_bp for t in scopes["OOS_2023_2026"]])[1]
        if all_n < 20:
            verdict = "UNDERPOWERED"
        elif is_mean > 0 and oos_mean > 0 and all_t >= 1.0:
            verdict = "PAPER_SURVIVES"
        else:
            verdict = "PAPER_REFUTED"
        for scope, selected in scopes.items():
            n, mean, tstat, win = stats([t.signed_return_bp for t in selected])
            rows.append([thesis, symbol, scope, n, mean, tstat, win, verdict])
    for thesis, symbol, reason in unavailable:
        rows.append([thesis, symbol, "ALL", 0, "", "", "", reason])
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["thesis_id", "symbol", "scope", "n", "mean_signed_bp",
                         "t_stat", "positive_rate", "paper_verdict"])
        for row in rows:
            writer.writerow([f"{v:.8f}" if isinstance(v, float) and math.isfinite(v) else v
                             for v in row])
    print(f"RESULT rows={len(rows)} trials={len(trials)} out={args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
