#!/usr/bin/env python3
"""Deterministic H-PY2L pilot fire count — Dukascopy USATECHIDXUSD ticks -> H1.

Motivation-only computed output for QM-RESEARCH-2026-0008 (TAIL_RISK Family A:
bounded positive pyramiding tightened to TWO levels, session-flat). Variant
lineage of QM-RESEARCH-2026-0007 (parent): the post-pilot L3 root-cause
analysis (../QM-RESEARCH-2026-0007/ANALYSIS.md, ANALYSIS_NOT_PREREGISTERED)
proved the 3-level contract degenerates to 2 levels inside the FTMO
session-flat envelope (the level-3 fill is structurally barred by the
add-fill-into-flatten rule combined with the entry clock), so this card
TIGHTENS the Family A bounds — max_levels 3 -> 2, progression 1.0/0.75/0.5 ->
1.0/0.75 (aggregate cap 2.25 -> 1.75 legs) — and removes the level-3
machinery. Nothing is widened. Counts how often the preregistered cash-session
two-level pyramid fires on an NDX-class index CFD and the basket outcome shape
(level-2 reach, giveback-stop rate, expectancy) on the discovery window
2018-2020. NOT farm .DWX data, NOT proof of edge.

Data layout (read-only):
    <root>/<YYYY>/<MM>/<DD>/<HH>h_ticks.bi5      (LZMA, 20-byte records, BE)
Record: int32 ms-offset-in-hour, int32 ask*1000, int32 bid*1000,
        float32 askVol, float32 bidVol.  Price proxy: tick mid = (ask+bid)/2000.

Session/parameter defaults are EXACTLY the preregistered card defaults
(only the two level-3 parameters are gone vs the 0007 card):
    session_start_hour_utc=13, breakout_window_bars=3, entry hours 16..17,
    breakout_buffer_atr=0.0, ema_period=20, atr_period=14,
    atr_stop_mult=1.0 (L1 reference stop),
    add2_trigger_atr=1.0,
    level2_size_mult=0.75,
    be_buffer_atr=0.05, trail_atr_mult=1.0,
    giveback_frac=0.5, basket_adverse_bound_pct=0.5, risk_per_trade_pct=0.25,
    time_stop_bars=6, flatten_hour_utc=20, friday_cutoff_hour_utc=17,
    shock_atr_mult=3.0.
(Pilot-measured on this feed: the 13:00 session bar's range sits at a median
~2.8x ATR(14), so the shock floor defaults to 3.0 to skip only extreme shock
days; at 2.0 more than half of all sessions are filtered.)

R convention: 1R = risk_per_trade_pct (0.25%) of equity on the L1 reference
stop. Equity is held fixed (no compounding). The hard adverse bound 0.5% equity
= -2R. Aggregate basket <= 1.75 L1 legs by construction.

Execution model (closed-bar, deterministic) — identical to the 0007 pilot:
    base signal on closed H1 bar -> base entry at the OPEN (mid) of the next bar.
    long : close > ORH + buf*ATR AND close > EMA(20); short mirrored.
    OR = first breakout_window_bars session bars (hours 13,14,15); signal bars
    have hour in [start+orb, session_end]; one basket per symbol per day.
    adds evaluated on bar CLOSE, filled at the NEXT bar open (never into the
    flatten-hour bar); one add per bar maximum; no adds on Friday after cutoff:
      L2 when (close-entry) >= add2_trigger_atr*ATR AND the bar prints a new
         favourable extreme vs every bar since the base entry (incl. entry bar).
    No third level exists.
    basket stop (long form; short mirrored), ratcheted - never widens:
      before L2: L1 reference stop = entry - atr_stop_mult*ATR;
      after L2 : max(previous stop, blended breakeven of L1+L2 + be_buffer_atr
                 *ATR, highest close since L2 - trail_atr_mult*ATR).
    intrabar exit priority on each bar after entry:
      1. flatten   : bar hour >= flatten_hour_utc -> exit ALL at bar OPEN;
      2. stop      : low <= basket stop (long) -> exit ALL at stop price;
      then, at bar CLOSE, in order:
      3. adverse bound : basket open P&L <= -basket_adverse_bound_pct equity
                        (=-2R) -> exit ALL at close;
      4. giveback stop : peak open basket P&L > 0 and open P&L
                        <= giveback_frac * peak -> exit ALL at close;
      5. time stop     : time_stop_bars full bars held -> exit ALL at close.
    peak open basket P&L (in R) is updated with each bar close before the
    giveback test, so a bar making a new peak cannot give back against itself.
    No spread/slippage/commission on fills (mid prices) - a declared confounder,
    identical to the H-MR/H-PY pilot convention.
ATR(14): simple mean of True Range over the 14 previously CLOSED bars.
EMA(20): seeded with the SMA of the first 20 closed bars of the series, then
standard recursive EMA. Both documented in the output JSON.

Consistency check (documented, not a new result): the 0007 pilot never filled
level 3, so the two-level realized path is identical by construction — this
runner must reproduce h_py_pilot.json totals exactly (185 baskets, 22 L2,
exit mix 73 stop / 37 giveback / 75 flatten). The script verifies that at the
end and records the comparison in the output JSON.
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

ROOT = Path(os.environ.get("HPY_TICK_ROOT", r"D:/QM/data/dukascopy/USATECHIDXUSD"))
_years_env = os.environ.get("HPY_YEARS")
YEARS = tuple(int(y) for y in _years_env.split(",")) if _years_env else (2018, 2019, 2020)
OUT = Path(os.environ.get(
    "HPY2L_OUT",
    str(Path(__file__).resolve().parent / "h_py2l_pilot.json"),
))

P = dict(
    session_start_hour_utc=13,
    breakout_window_bars=3,
    session_end_hour_utc=17,
    breakout_buffer_atr=0.0,
    ema_period=20,
    atr_period=14,
    atr_stop_mult=1.0,
    add2_trigger_atr=1.0,
    level2_size_mult=0.75,
    be_buffer_atr=0.05,
    trail_atr_mult=1.0,
    giveback_frac=0.5,
    basket_adverse_bound_pct=0.5,
    risk_per_trade_pct=0.25,
    time_stop_bars=6,
    flatten_hour_utc=20,
    friday_cutoff_hour_utc=17,
    shock_atr_mult=3.0,
)

BOUNDS_R = P["basket_adverse_bound_pct"] / P["risk_per_trade_pct"]  # -2R at defaults


def load_year(year: int):
    """-> (bars, spread_pips) with bars sorted list of (hour_epoch,o,h,l,c) mids."""
    bars = []
    spreads = []
    year_dir = ROOT / str(year)
    if not year_dir.is_dir():
        return bars, spreads
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
                ask = arr["ask"].astype(np.float64) / 1000.0
                bid = arr["bid"].astype(np.float64) / 1000.0
                mids = (ask + bid) / 2.0
                spreads.append(float(np.median(ask - bid)))
                bars.append((epoch, float(mids[0]), float(mids.max()),
                             float(mids.min()), float(mids[-1])))
    bars.sort(key=lambda b: b[0])
    return bars, spreads


def atr_at(closes, highs, lows, idx, period):
    if idx < period:
        return 0.0
    total = 0.0
    for j in range(idx - period, idx):
        pc = closes[j - 1]
        tr = max(highs[j] - lows[j], abs(highs[j] - pc), abs(lows[j] - pc))
        total += tr
    return total / period


def ema_series(closes, period):
    out = [0.0] * len(closes)
    if len(closes) < period:
        return out
    seed = sum(closes[:period]) / period
    k = 2.0 / (period + 1)
    out[period - 1] = seed
    for i in range(period, len(closes)):
        out[i] = closes[i] * k + out[i - 1] * (1 - k)
    return out


def weekday(epoch):
    return dt.datetime.fromtimestamp(epoch, dt.timezone.utc).weekday()  # Mon=0


def run_year(year):
    bars, spreads = load_year(year)
    n = len(bars)
    epoch = [b[0] for b in bars]
    opens = [b[1] for b in bars]
    highs = [b[2] for b in bars]
    lows = [b[3] for b in bars]
    closes = [b[4] for b in bars]
    hours = [((e % 86400) // 3600) for e in epoch]
    ema = ema_series(closes, P["ema_period"])

    start = P["session_start_hour_utc"]
    orb = P["breakout_window_bars"]
    buf = P["breakout_buffer_atr"]
    atrp = P["atr_period"]
    stopm = P["atr_stop_mult"]
    a2 = P["add2_trigger_atr"]
    s2 = P["level2_size_mult"]
    bebuf = P["be_buffer_atr"]
    trailm = P["trail_atr_mult"]
    gb = P["giveback_frac"]
    tsb = P["time_stop_bars"]
    flat = P["flatten_hour_utc"]
    fri_cut = P["friday_cutoff_hour_utc"]
    shockm = P["shock_atr_mult"]
    send = P["session_end_hour_utc"]

    stats = dict(
        h1_bars=n,
        days_evaluated=0,
        days_shock_skipped=0,
        days_without_range=0,
        signals_long=0,
        signals_short=0,
        baskets=0,
        l2_fills=0,
        l3_fills=0,  # kept at 0 by construction: the two-level card has no L3
        exits_stop=0,
        exits_adverse_bound=0,
        exits_giveback=0,
        exits_time_stop=0,
        exits_flatten=0,
        exits_series_end=0,
        giveback_before_l2=0,
        r_sum=0.0,
        win_r_sum=0.0,
        loss_r_sum=0.0,
        peak_r_sum=0.0,
        peak_r_max=0.0,
        active_days=0,
        first_bar_range_atr=[] if year == YEARS[0] else None,
    )
    months = {}
    days_with_signal = set()

    i = 0
    while i < n:
        if hours[i] != start:
            i += 1
            continue
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

        a0 = atr_at(closes, highs, lows, or_idx[0], atrp)
        fb_range_atr = ((highs[or_idx[0]] - lows[or_idx[0]]) / a0) if a0 > 0 else None
        if year == YEARS[0] and fb_range_atr is not None:
            stats["first_bar_range_atr"].append(round(fb_range_atr, 3))
        if a0 > 0 and (highs[or_idx[0]] - lows[or_idx[0]]) > shockm * a0:
            stats["days_shock_skipped"] += 1
            i = max(j, i + 1)
            continue
        stats["days_evaluated"] += 1

        w0 = start + orb
        traded = False
        for s in block:
            if traded:
                break
            hs = hours[s]
            if hs < w0 or hs > send:
                continue
            if weekday(epoch[s]) == 4 and hs >= fri_cut:
                continue
            a_sig = atr_at(closes, highs, lows, s, atrp)
            if a_sig <= 0.0:
                continue
            e = ema[s]
            long_sig = closes[s] > orh + buf * a_sig and closes[s] > e
            short_sig = closes[s] < orl - buf * a_sig and closes[s] < e
            if not (long_sig or short_sig):
                continue
            days_with_signal.add(epoch[s] // 86400)
            if long_sig:
                stats["signals_long"] += 1
            else:
                stats["signals_short"] += 1
            b = s + 1
            if b >= n or hours[b] >= flat:
                continue
            entry1 = opens[b]
            stop1 = entry1 - stopm * a_sig if long_sig else entry1 + stopm * a_sig
            stop_dist = abs(entry1 - stop1)
            if stop_dist <= 0.0:
                continue
            traded = True
            stats["baskets"] += 1

            legs = [(1.0, entry1)]
            basket_stop = stop1
            peak_close = closes[b]
            peak_r = 0.0
            extreme_since_entry = highs[b] if long_sig else lows[b]
            pending_add = 0  # only 2 exists
            exit_r = None
            reason = None
            held = 0
            t = b
            while t < n:
                # pending add fills at this bar's open (never into the flatten bar)
                if pending_add and hours[t] < flat:
                    px = opens[t]
                    legs.append((s2, px))
                    stats["l2_fills"] += 1
                    pending_add = 0
                if hours[t] >= flat:
                    unr = sum(m * ((opens[t] - px) if long_sig else (px - opens[t]))
                              for m, px in legs) / stop_dist
                    exit_r = unr
                    reason = "flatten"
                    break
                # intrabar stop (conservative, before close-based rules)
                hit_stop = (lows[t] <= basket_stop) if long_sig else (highs[t] >= basket_stop)
                if hit_stop:
                    r = sum(m * ((basket_stop - px) if long_sig else (px - basket_stop))
                            for m, px in legs) / stop_dist
                    exit_r = r
                    reason = "stop"
                    break
                # close-based state updates
                held += 1
                move_close = (closes[t] - entry1) if long_sig else (entry1 - closes[t])
                basket_r = sum(m * ((closes[t] - px) if long_sig else (px - closes[t]))
                               for m, px in legs) / stop_dist
                if basket_r > peak_r:
                    peak_r = basket_r
                # never-widening trailing stop ratchet (only meaningful once L2 filled)
                if len(legs) >= 2:
                    if long_sig:
                        peak_close = max(peak_close, closes[t])
                        wsum = sum(m * px for m, px in legs)
                        wsize = sum(m for m, _ in legs)
                        be = wsum / wsize + bebuf * a_sig
                        trail = peak_close - trailm * a_sig
                        basket_stop = max(basket_stop, be, trail)
                    else:
                        peak_close = min(peak_close, closes[t])
                        wsum = sum(m * px for m, px in legs)
                        wsize = sum(m for m, _ in legs)
                        be = wsum / wsize - bebuf * a_sig
                        trail = peak_close + trailm * a_sig
                        basket_stop = min(basket_stop, be, trail)
                # close-based exits in priority order
                if basket_r <= -BOUNDS_R:
                    exit_r = basket_r
                    reason = "adverse_bound"
                    break
                if peak_r > 0.0 and basket_r <= gb * peak_r:
                    exit_r = basket_r
                    reason = "giveback"
                    break
                if held >= tsb:
                    exit_r = basket_r
                    reason = "time_stop"
                    break
                # add trigger (evaluated on close; fill next bar); no third level
                if len(legs) == 1:
                    ext = highs[t] if long_sig else lows[t]
                    new_ext = (ext > extreme_since_entry) if long_sig else (ext < extreme_since_entry)
                    extreme_since_entry = max(extreme_since_entry, ext) if long_sig else min(extreme_since_entry, ext)
                    if move_close >= a2 * a_sig and new_ext:
                        pending_add = 2
                t += 1
            if exit_r is None:
                exit_r = 0.0
                reason = "series_end"
            stats["r_sum"] += exit_r
            if exit_r > 0:
                stats["win_r_sum"] += exit_r
            elif exit_r < 0:
                stats["loss_r_sum"] += exit_r
            stats["peak_r_sum"] += peak_r
            stats["peak_r_max"] = max(stats["peak_r_max"], peak_r)
            if reason == "giveback" and len(legs) == 1:
                stats["giveback_before_l2"] += 1
            key = {"stop": "exits_stop", "adverse_bound": "exits_adverse_bound",
                   "giveback": "exits_giveback", "time_stop": "exits_time_stop",
                   "flatten": "exits_flatten"}.get(reason)
            if key:
                stats[key] += 1
            else:
                stats["exits_series_end"] += 1
            bdt = dt.datetime.fromtimestamp(epoch[b], dt.timezone.utc)
            mk = f"{bdt.year}-{bdt.month:02d}"
            months[mk] = months.get(mk, 0) + 1
        i = max(j, i + 1)

    stats["active_days"] = len(days_with_signal)
    if stats["first_bar_range_atr"] is None:
        stats.pop("first_bar_range_atr")
    stats["months"] = months
    stats["_spreads"] = spreads
    return stats


def main():
    per_year = {}
    agg = dict(days_evaluated=0, days_shock_skipped=0, days_without_range=0,
               signals_long=0, signals_short=0, baskets=0, l2_fills=0, l3_fills=0,
               exits_stop=0, exits_adverse_bound=0, exits_giveback=0,
               exits_time_stop=0, exits_flatten=0, exits_series_end=0,
               giveback_before_l2=0, r_sum=0.0, win_r_sum=0.0, loss_r_sum=0.0,
               peak_r_sum=0.0, peak_r_max=0.0,
               active_days=0)
    months_all = {}
    fb_ranges = []
    spreads_all = []
    for year in YEARS:
        st = run_year(year)
        spreads_all.extend(st.pop("_spreads"))
        fbr = st.pop("first_bar_range_atr", None)
        if fbr:
            fb_ranges.extend(fbr)
        per_year[str(year)] = {k: v for k, v in st.items() if k != "months"}
        for k in agg:
            agg[k] += st[k]
        for mk, mv in st["months"].items():
            months_all[mk] = months_all.get(mk, 0) + 1
        print(f"[{year}] days={st['days_evaluated']} baskets={st['baskets']} "
              f"l2={st['l2_fills']} r_sum={st['r_sum']:.2f}",
              flush=True)

    baskets = agg["baskets"]
    gross_win = agg["win_r_sum"]
    gross_loss = -agg["loss_r_sum"]

    # Consistency check vs the parent pilot: the two-level realized path must
    # be identical (the parent never filled L3). Parent figures are read from
    # the sealed 0007 computed output.
    parent_path = Path(__file__).resolve().parent / ".." / "QM-RESEARCH-2026-0007" / "h_py_pilot.json"
    consistency = None
    if parent_path.is_file():
        parent = json.loads(parent_path.read_text(encoding="utf-8"))
        pt = parent["totals"]
        checks = {
            "baskets": (agg["baskets"], pt["baskets"]),
            "l2_fills": (agg["l2_fills"], pt["l2_fills"]),
            "exits_stop": (agg["exits_stop"], pt["exits_stop"]),
            "exits_giveback": (agg["exits_giveback"], pt["exits_giveback"]),
            "exits_flatten": (agg["exits_flatten"], pt["exits_flatten"]),
            "r_sum": (round(agg["r_sum"], 6), round(pt["r_sum"], 6)),
        }
        consistency = {
            "parent": "QM-RESEARCH-2026-0007/h_py_pilot.json",
            "checks": {k: dict(two_level=v[0], parent_three_level=v[1], match=v[0] == v[1])
                       for k, v in checks.items()},
            "all_match": all(v[0] == v[1] for v in checks.values()),
            "note": ("Expected a priori: the parent's L3 leg never filled, so the "
                     "tightened two-level path is identical by construction. This "
                     "is a regression check on the variant runner, not a new result."),
        }

    result = {
        "schema": "qm.computed-output/h-py2l-pilot/v1",
        "generated_by": Path(__file__).name,
        "data_root": str(ROOT),
        "data_note": ("Dukascopy USATECHIDXUSD tick feed (NDX-class index CFD, "
                      "NOT the farm .DWX NDX series). Pilot motivation only."),
        "parameters": P,
        "bounds_r_at_defaults": -BOUNDS_R,
        "atr_definition": "simple mean of True Range over the 14 previously closed bars",
        "ema_definition": ("SMA seed over the first 20 closed bars of the series, "
                           "then standard recursive EMA"),
        "execution_model": ("closed-bar signals, next-bar-open fills (mids), stop-first "
                            "intrabar priority, close-based giveback/adverse/time exits, "
                            "one basket per symbol per day; TWO levels maximum"),
        "cost_model": "NONE (mid-price fills; no spread/slippage/commission) - declared confounder",
        "period": "2018-2020 discovery window (in-sample for the research lane)",
        "lineage": {
            "research_id": "QM-RESEARCH-2026-0008",
            "parent": "QM-RESEARCH-2026-0007",
            "delta": ("Family A bounds tightened, never widened: max_levels 3->2, "
                      "progression [1.0,0.75,0.5]->[1.0,0.75] (aggregate cap 2.25->1.75 "
                      "legs); add3_trigger_atr and level3_size_mult removed; all other "
                      "rules identical to the frozen 0007 card."),
        },
        "measured_context": {
            "tick_median_spread": round(float(np.median(spreads_all)), 5) if spreads_all else None,
            "first_session_bar_range_atr_p50": (round(float(np.median(fb_ranges)), 3)
                                                if fb_ranges else None),
        },
        "parent_consistency_check": consistency,
        "per_year": per_year,
        "totals": {
            **agg,
            "baskets_per_month_avg": round(baskets / max(1, len(months_all)), 3),
            "active_days_per_month_avg": round(agg["active_days"] / max(1, len(months_all)), 3),
            "l2_reach_rate": round(agg["l2_fills"] / baskets, 4) if baskets else None,
            "l3_reach_rate": 0.0,
            "giveback_before_l2_rate": round(agg["giveback_before_l2"] / baskets, 4) if baskets else None,
            "expectancy_r": round(agg["r_sum"] / baskets, 4) if baskets else None,
            "avg_peak_open_r": round(agg["peak_r_sum"] / baskets, 4) if baskets else None,
            "max_peak_open_r": round(agg["peak_r_max"], 4),
            "profit_factor_r": (round(gross_win / gross_loss, 4) if gross_loss > 0 else None),
            "months_covered": len(months_all),
        },
        "months": dict(sorted(months_all.items())),
        "label": "PILOT_MOTIVATION_NOT_PROOF",
    }
    OUT.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result["totals"], indent=2, sort_keys=True))
    if consistency is not None and not consistency["all_match"]:
        print("CONSISTENCY_CHECK_FAILED", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
