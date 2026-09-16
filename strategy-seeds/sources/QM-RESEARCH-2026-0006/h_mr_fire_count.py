#!/usr/bin/env python3
"""Deterministic H-MR pilot fire count — Dukascopy USATECHIDXUSD ticks -> H1.

Motivation-only computed output for QM-RESEARCH-2026-0005 (H-MR). Counts how
often the preregistered failed-breakout mean-reversion pattern fires on an
NDX-class index CFD and what the midpoint-target outcome shape looks like on
the discovery window 2018-2020. NOT farm .DWX data, NOT proof of edge.

Data layout (read-only):
    <root>/<YYYY>/<MM>/<DD>/<HH>h_ticks.bi5      (LZMA, 20-byte records, BE)
Record: int32 ms-offset-in-hour, int32 ask*1000, int32 bid*1000,
        float32 askVol, float32 bidVol.  Price proxy: tick mid = (ask+bid)/2000.

Session/parameter defaults are EXACTLY the preregistered card defaults:
    session_start_hour_utc=13, opening_range_bars=3, entry window hours 16..17,
    breakout_buffer_atr=0.025, ema_period=20, atr_period=14,
    atr_stop_mult=1.0, min_target_r=0.5, time_stop_bars=6,
    flatten_hour_utc=20, friday_cutoff_hour_utc=17, shock_atr_mult=3.0.
(Pilot-measured on this feed: cash-open bar range p50 ~2.0x ATR14 and
reward/risk p50 ~0.7, hence shock floor 3.0 and min-R floor 0.5.)

Execution model (closed-bar, deterministic):
    signal on closed H1 bar -> enter at the OPEN (mid) of the next H1 bar.
    long : signal low  < ORL - buf*ATR  AND ORL < close < ORH AND close < EMA
    short: signal high > ORH + buf*ATR  AND ORL < close < ORH AND close > EMA
    stop = signal extreme +/- atr_stop_mult*ATR ; TP = (ORH+ORL)/2
    entry eligibility: reward >= min_target_r * risk (measured at entry open)
    one entry per day (earliest signal); shock day skipped; Friday only hour 16
    bar may signal; no entry when the entry bar's hour >= flatten hour.
    Exit scan on subsequent bars in priority order: stop first (conservative),
    then TP; time stop after `time_stop_bars` full bars at that bar's close;
    flatten at the close of any bar with hour >= flatten_hour_utc.
ATR(14): simple mean of True Range over the 14 previously CLOSED bars.
EMA(20): seeded with the SMA of the first 20 closed bars of the series, then
    standard recursive EMA. Both documented in the output JSON.
"""

from __future__ import annotations

import calendar
import datetime as dt
import json
import lzma
import os
import sys
from pathlib import Path

import numpy as np

ROOT = Path(os.environ.get("HMR_TICK_ROOT", r"D:/QM/data/dukascopy/USATECHIDXUSD"))
_years_env = os.environ.get("HMR_YEARS")
YEARS = tuple(int(y) for y in _years_env.split(",")) if _years_env else (2018, 2019, 2020)
OUT = Path(os.environ.get(
    "HMR_OUT",
    str(Path(__file__).resolve().parent / "h_mr_fire_count.json"),
))

P = dict(
    session_start_hour_utc=13,
    opening_range_bars=3,
    session_end_hour_utc=17,
    breakout_buffer_atr=0.025,
    ema_period=20,
    atr_period=14,
    atr_stop_mult=1.0,
    min_target_r=0.5,
    time_stop_bars=6,
    flatten_hour_utc=20,
    friday_cutoff_hour_utc=17,
    shock_atr_mult=3.0,
)


def load_year_bars(year: int) -> list[tuple[int, float, float, float, float]]:
    """-> sorted list of (hour_epoch, open, high, low, close) mids for the year."""
    bars = []
    year_dir = ROOT / str(year)
    if not year_dir.is_dir():
        return bars
    rec = np.dtype([("ms", ">i4"), ("ask", ">i4"), ("bid", ">i4"),
                    ("av", ">f4"), ("bv", ">f4")])
    for month_dir in sorted(year_dir.iterdir()):
        if not month_dir.is_dir():
            continue
        for day_dir in sorted(month_dir.iterdir()):
            if not day_dir.is_dir():
                continue
            for hour_file in sorted(day_dir.glob("*h_ticks.bi5")):
                try:
                    hour = int(hour_file.name[:2])
                    y, m, d = int(year), int(month_dir.name), int(day_dir.name)
                    epoch = calendar.timegm((y, m, d, hour, 0, 0))
                    raw = lzma.decompress(hour_file.read_bytes())
                except Exception:
                    continue
                arr = np.frombuffer(raw, dtype=rec)
                if arr.size == 0:
                    continue
                mids = (arr["ask"].astype(np.float64) + arr["bid"].astype(np.float64)) / 2000.0
                bars.append((epoch, float(mids[0]), float(mids.max()),
                             float(mids.min()), float(mids[-1])))
    bars.sort(key=lambda b: b[0])
    return bars


def atr_at(closes: list[float], highs: list[float], lows: list[float], idx: int, period: int) -> float:
    """ATR (simple mean of TR) over the `period` bars strictly before idx."""
    if idx < period:
        return 0.0
    total = 0.0
    for j in range(idx - period, idx):
        pc = closes[j - 1]
        tr = max(highs[j] - lows[j], abs(highs[j] - pc), abs(lows[j] - pc))
        total += tr
    return total / period


def ema_series(closes: list[float], period: int) -> list[float]:
    """EMA with SMA seed over the first `period` closes; index-aligned."""
    out = [0.0] * len(closes)
    if len(closes) < period:
        return out
    seed = sum(closes[:period]) / period
    k = 2.0 / (period + 1)
    out[period - 1] = seed
    for i in range(period, len(closes)):
        out[i] = closes[i] * k + out[i - 1] * (1 - k)
    return out


def weekday(epoch: int) -> int:
    return dt.datetime.fromtimestamp(epoch, dt.timezone.utc).weekday()  # Mon=0


def run_year(year: int) -> dict:
    bars = load_year_bars(year)
    n = len(bars)
    epoch = [b[0] for b in bars]
    opens = [b[1] for b in bars]
    highs = [b[2] for b in bars]
    lows = [b[3] for b in bars]
    closes = [b[4] for b in bars]
    hours = [((e % 86400) // 3600) for e in epoch]
    ema = ema_series(closes, P["ema_period"])

    start = P["session_start_hour_utc"]
    orb = P["opening_range_bars"]
    buf = P["breakout_buffer_atr"]
    atrp = P["atr_period"]
    stopm = P["atr_stop_mult"]
    minr = P["min_target_r"]
    tsb = P["time_stop_bars"]
    flat = P["flatten_hour_utc"]
    fri_cut = P["friday_cutoff_hour_utc"]
    shockm = P["shock_atr_mult"]

    stats = dict(
        h1_bars=n,
        days_evaluated=0,
        days_shock_skipped=0,
        days_without_range=0,
        signals_long=0,
        signals_short=0,
        taken=0,
        wins=0,
        losses=0,
        time_stops=0,
        flattens=0,
        ineligible=0,
        r_sum=0.0,
        active_days=0,
    )
    months: dict[str, int] = {}
    days_with_signal: set[int] = set()

    i = 0
    while i < n:
        if hours[i] != start:
            i += 1
            continue
        # session day block: consecutive bars starting at the session start hour
        j = i
        block = []
        while j < n and hours[j] >= start and (j == i or hours[j] == hours[j - 1] + 1):
            block.append(j)
            j += 1
        if len(block) < orb or j >= n:
            stats["days_without_range"] += 1
            i = max(j, i + 1)
            continue
        or_idx = block[:orb]
        orh = max(highs[k] for k in or_idx)
        orl = min(lows[k] for k in or_idx)
        mid = 0.5 * (orh + orl)

        # shock filter on the first session bar, ATR at its own close
        a0 = atr_at(closes, highs, lows, or_idx[0], atrp)
        if a0 > 0.0 and (highs[or_idx[0]] - lows[or_idx[0]]) > shockm * a0:
            stats["days_shock_skipped"] += 1
            i = max(j, i + 1)
            continue
        stats["days_evaluated"] += 1

        # entry window: closed bars with hour in [start+orb, session_end]
        w0 = start + orb
        traded = False
        for s in block:
            if traded:
                break
            hs = hours[s]
            if hs < w0 or hs > P["session_end_hour_utc"]:
                continue
            if weekday(epoch[s]) == 4 and hs >= fri_cut:
                continue
            a = atr_at(closes, highs, lows, s, atrp)
            if a <= 0.0:
                continue
            e = ema[s]
            long_sig = lows[s] < orl - buf * a and orl < closes[s] < orh and closes[s] < e
            short_sig = highs[s] > orh + buf * a and orl < closes[s] < orh and closes[s] > e
            if not (long_sig or short_sig):
                continue
            days_with_signal.add(epoch[s] // 86400)
            if long_sig:
                stats["signals_long"] += 1
            else:
                stats["signals_short"] += 1
            # entry at next bar open
            b = s + 1
            if b >= n or hours[b] >= flat:
                continue
            entry = opens[b]
            if long_sig:
                stop = lows[s] - stopm * a
                risk = entry - stop
                reward = mid - entry
            else:
                stop = highs[s] + stopm * a
                risk = stop - entry
                reward = entry - mid
            if risk <= 0.0 or reward < minr * risk:
                stats["ineligible"] += 1
                continue
            stats["taken"] += 1
            traded = True
            # outcome scan
            exit_r = None
            reason = None
            held = 0
            t = b
            while t < n:
                if hours[t] >= flat:
                    # mandatory flat at the OPEN of the flatten-hour bar
                    exit_r = ((opens[t] - entry) if long_sig else (entry - opens[t])) / risk
                    reason = "flatten"
                    break
                if long_sig:
                    if lows[t] <= stop:
                        exit_r = -1.0
                        reason = "stop"
                        break
                    if highs[t] >= mid:
                        exit_r = reward / risk
                        reason = "target"
                        break
                else:
                    if highs[t] >= stop:
                        exit_r = -1.0
                        reason = "stop"
                        break
                    if lows[t] <= mid:
                        exit_r = reward / risk
                        reason = "target"
                        break
                held += 1
                if held >= tsb:
                    exit_r = ((closes[t] - entry) if long_sig else (entry - closes[t])) / risk
                    reason = "time_stop"
                    break
                t += 1
            if exit_r is None:
                exit_r = 0.0
                reason = "series_end"
            stats["r_sum"] += exit_r
            if reason == "target":
                stats["wins"] += 1
            elif reason == "stop":
                stats["losses"] += 1
            elif reason == "time_stop":
                stats["time_stops"] += 1
            elif reason == "flatten":
                stats["flattens"] += 1
            bdt = dt.datetime.fromtimestamp(epoch[b], dt.timezone.utc)
            key = f"{bdt.year}-{bdt.month:02d}"
            months[key] = months.get(key, 0) + 1
        i = max(j, i + 1)

    stats["active_days"] = len(days_with_signal)
    stats["months"] = months
    return stats


def main() -> int:
    per_year = {}
    agg = dict(
        days_evaluated=0, days_shock_skipped=0, days_without_range=0,
        signals_long=0, signals_short=0, taken=0, wins=0, losses=0,
        time_stops=0, flattens=0, ineligible=0, r_sum=0.0, active_days=0,
    )
    months_all: dict[str, int] = {}
    for year in YEARS:
        st = run_year(year)
        per_year[str(year)] = st
        for k in agg:
            agg[k] += st[k]
        for mk, mv in st["months"].items():
            months_all[mk] = months_all.get(mk, 0) + mv
        print(f"[{year}] bars={st['h1_bars']} days={st['days_evaluated']} "
              f"taken={st['taken']} wins={st['wins']} losses={st['losses']}",
              flush=True)

    taken = agg["taken"]
    gross_win = agg["r_sum"] + agg["losses"]  # r_sum = sum(R); losses are -1 each
    gross_loss = agg["losses"]
    result = {
        "schema": "qm.computed-output/h-mr-fire-count/v1",
        "generated_by": Path(__file__).name,
        "data_root": str(ROOT),
        "data_note": ("Dukascopy USATECHIDXUSD tick feed (NDX-class index CFD, "
                      "NOT the farm .DWX NDX series). Pilot motivation only."),
        "parameters": P,
        "atr_definition": "simple mean of True Range over the 14 previously closed bars",
        "ema_definition": ("SMA seed over the first 20 closed bars of the series, "
                           "then standard recursive EMA"),
        "execution_model": ("closed-bar signal, next-bar-open entry (mid), stop-first "
                            "conservative same-bar priority, one entry per day"),
        "period": "2018-2020 discovery window (in-sample for the research lane)",
        "per_year": {y: {k: v for k, v in per_year[y].items() if k != "months"} for y in per_year},
        "totals": {
            **{k: agg[k] for k in agg},
            "trades_per_month_avg": round(taken / max(1, len(months_all)), 3),
            "hit_rate": round(agg["wins"] / taken, 4) if taken else None,
            "avg_r": round(agg["r_sum"] / taken, 4) if taken else None,
            "expectancy_r": round(agg["r_sum"] / taken, 4) if taken else None,
            "profit_factor_r": round(gross_win / gross_loss, 4) if gross_loss else None,
            "months_covered": len(months_all),
        },
        "months": dict(sorted(months_all.items())),
        "label": "PILOT_MOTIVATION_NOT_PROOF",
    }
    OUT.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result["totals"], indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
