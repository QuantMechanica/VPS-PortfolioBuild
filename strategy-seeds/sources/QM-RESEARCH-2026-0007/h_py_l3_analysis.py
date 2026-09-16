#!/usr/bin/env python3
"""ANALYSIS_NOT_PREREGISTERED — L3-reach root-cause instrumentation for H-PY.

Post-pilot diagnostic for QM-RESEARCH-2026-0007 (frozen; NOT part of the
preregistration and NOT a design change). The preregistered pilot runner
(h_py_pilot.py) recorded level-3 reach 0/185; this script replays the EXACT
same preregistered rules on the SAME read-only in-sample window
(Dukascopy USATECHIDXUSD ticks -> H1, 2018-2020, zero-cost mids) and records,
per basket:

  * peak favourable excursion from base entry in ATR units, close-based and
    extreme-based (peak_close_move_atr, peak_extreme_move_atr);
  * which exit fired first (stop / giveback / flatten / time_stop) and, for
    giveback exits, the effective retracement from peak in ATR and in R;
  * margin_to_add3 = peak_close_move_atr - add3_trigger_atr(2.0): how far each
    basket's best CLOSE got from the level-3 trigger (negative = never close);
  * for the 22 L2-filled baskets: the post-L2 corridor (post-L2 peak close in
    ATR, the giveback-stop price vs the trail-stop price per bar, and which
    bound sat tighter);
  * counterfactual replays (each clearly labelled COUNTERFACTUAL, each a single
    rule disabled, NOTHING optimised): no-giveback, no-trail-ratchet,
    no-flatten, no-time-stop, and shock-skip-disabled day coverage. These
    attribute the binding constraint; they are not proposals.

Nothing here touches 2021-2024 (frozen holdout) and nothing here modifies the
frozen preregistration. Output: h_py_l3_analysis.json next to this script.
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
    "HPY_L3_OUT",
    str(Path(__file__).resolve().parent / "h_py_l3_analysis.json"),
))

# EXACTLY the preregistered card defaults (mirrors h_py_pilot.py).
P = dict(
    session_start_hour_utc=13,
    breakout_window_bars=3,
    session_end_hour_utc=17,
    breakout_buffer_atr=0.0,
    ema_period=20,
    atr_period=14,
    atr_stop_mult=1.0,
    add2_trigger_atr=1.0,
    add3_trigger_atr=2.0,
    level2_size_mult=0.75,
    level3_size_mult=0.5,
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

BOUNDS_R = P["basket_adverse_bound_pct"] / P["risk_per_trade_pct"]  # -2R

# Counterfactual toggles: each is a SINGLE rule removed from the base spec.
TOGGLES = ("no_giveback", "no_trail", "no_flatten", "no_time_stop", "shock_off")


def load_year(year: int):
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
    return dt.datetime.fromtimestamp(epoch, dt.timezone.utc).weekday()


def simulate_year(year, toggle=None, preloaded=None):
    """Replay the preregistered rules with one rule optionally disabled.

    Returns (stats, basket_records, shock_day_records).
    """
    bars = preloaded if preloaded is not None else load_year(year)[0]
    n = len(bars)
    epoch = [b[0] for b in bars]
    opens = [b[1] for b in bars]
    highs = [b[2] for b in bars]
    lows = [b[3] for b in bars]
    closes = [b[4] for b in bars]
    hours = [((e % 86400) // 3600) for e in epoch]
    ema = ema_series(closes, P["ema_period"])

    no_giveback = toggle == "no_giveback"
    no_trail = toggle == "no_trail"
    no_flatten = toggle == "no_flatten"
    no_time_stop = toggle == "no_time_stop"
    shock_off = toggle == "shock_off"

    start = P["session_start_hour_utc"]
    orb = P["breakout_window_bars"]
    buf = P["breakout_buffer_atr"]
    atrp = P["atr_period"]
    stopm = P["atr_stop_mult"]
    a2 = P["add2_trigger_atr"]
    a3 = P["add3_trigger_atr"]
    s2 = P["level2_size_mult"]
    s3 = P["level3_size_mult"]
    bebuf = P["be_buffer_atr"]
    trailm = P["trail_atr_mult"]
    gb = P["giveback_frac"]
    tsb = P["time_stop_bars"]
    flat = P["flatten_hour_utc"]
    fri_cut = P["friday_cutoff_hour_utc"]
    shockm = P["shock_atr_mult"]
    send = P["session_end_hour_utc"]

    stats = dict(days_evaluated=0, days_shock_skipped=0, days_without_range=0,
                 signals_long=0, signals_short=0, baskets=0, l2_fills=0, l3_fills=0,
                 exits_stop=0, exits_adverse_bound=0, exits_giveback=0,
                 exits_time_stop=0, exits_flatten=0, exits_series_end=0,
                 giveback_before_l2=0, r_sum=0.0)
    basket_records = []
    shock_records = []

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
        is_shock = a0 > 0 and (highs[or_idx[0]] - lows[or_idx[0]]) > shockm * a0
        if is_shock and not shock_off:
            stats["days_shock_skipped"] += 1
            i = max(j, i + 1)
            continue
        stats["days_evaluated"] += 1

        # Shock-day diagnostic (runs only under the shock_off toggle AND as a
        # pure excursion measurement): would signals have fired, and how far
        # could the first signal of the day have run (no exit rules)?
        if is_shock and shock_off:
            w0 = start + orb
            sig_seen = None
            for s in block:
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
                if long_sig or short_sig:
                    sig_seen = (s, "long" if long_sig else "short", a_sig)
                    break
            rec = dict(date=dt.datetime.fromtimestamp(epoch[i], dt.timezone.utc).date().isoformat(),
                       first_bar_range_atr=round(fb_range_atr, 3) if fb_range_atr else None,
                       signal=None)
            if sig_seen:
                s, direction, a_sig = sig_seen
                b = s + 1
                peak_close = 0.0
                peak_ext = 0.0
                if b < n:
                    for t in range(b, min(j, n)):
                        if hours[t] >= flat:
                            break
                        fav_c = (closes[t] - opens[b]) if direction == "long" else (opens[b] - closes[t])
                        ext = highs[t] if direction == "long" else lows[t]
                        fav_e = (ext - opens[b]) if direction == "long" else (opens[b] - ext)
                        peak_close = max(peak_close, fav_c / a_sig)
                        peak_ext = max(peak_ext, fav_e / a_sig)
                rec["signal"] = direction
                rec["peak_close_move_atr_no_exits"] = round(peak_close, 3)
                rec["peak_extreme_move_atr_no_exits"] = round(peak_ext, 3)
            shock_records.append(rec)

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

            dstr = dt.datetime.fromtimestamp(epoch[b], dt.timezone.utc)
            rec = dict(
                basket_id=f"{dstr.date().isoformat()}_{'L' if long_sig else 'S'}",
                year=year, direction="long" if long_sig else "short",
                entry_hour_utc=int(hours[b]), a_sig=round(a_sig, 5),
                max_bars_to_flatten=int(flat - hours[b]),
                l2_filled=False, l3_filled=False,
                exit_reason=None, exit_r=None, bars_held=0,
                peak_close_move_atr=0.0, peak_extreme_move_atr=0.0,
                margin_to_add3=None,
                giveback_peak_r=None, giveback_retrace_atr=None,
                post_l2=None,
            )

            legs = [(1.0, entry1)]
            basket_stop = stop1
            peak_close = closes[b]
            peak_r = 0.0
            extreme_since_entry = highs[b] if long_sig else lows[b]
            l2_fill_bar = None
            extreme_since_l2 = None
            pending_add = 0
            exit_r = None
            reason = None
            held = 0
            post_l2 = None
            t = b
            while t < n:
                if pending_add and hours[t] < flat:
                    px = opens[t]
                    legs.append((s2 if pending_add == 2 else s3, px))
                    if pending_add == 2:
                        stats["l2_fills"] += 1
                        rec["l2_filled"] = True
                        l2_fill_bar = t
                        extreme_since_l2 = highs[t] if long_sig else lows[t]
                        wsum = sum(m * px for m, px in legs)
                        wsize = sum(m for m, _ in legs)
                        be_price = (wsum / wsize +
                                    (bebuf * a_sig if long_sig else -bebuf * a_sig))
                        post_l2 = dict(
                            l2_fill_hour=int(hours[t]),
                            l2_fill_move_atr=round(abs(px - entry1) / a_sig, 3),
                            blended_be_move_atr=round(abs(be_price - entry1) / a_sig, 3),
                            bars_to_flatten_after_l2=int(flat - hours[t]),
                            peak_close_move_atr=0.0, peak_extreme_move_atr=0.0,
                            margin_to_add3=None,
                            stop_tighter="unknown",
                            corridor=[],
                        )
                    else:
                        stats["l3_fills"] += 1
                        rec["l3_filled"] = True
                    pending_add = 0
                if hours[t] >= flat and not no_flatten:
                    unr = sum(m * ((opens[t] - px) if long_sig else (px - opens[t]))
                              for m, px in legs) / stop_dist
                    exit_r = unr
                    reason = "flatten"
                    break
                hit_stop = (lows[t] <= basket_stop) if long_sig else (highs[t] >= basket_stop)
                if hit_stop:
                    r = sum(m * ((basket_stop - px) if long_sig else (px - basket_stop))
                            for m, px in legs) / stop_dist
                    exit_r = r
                    reason = "stop"
                    break
                held += 1
                move_close = (closes[t] - entry1) if long_sig else (entry1 - closes[t])
                fav_close = move_close / a_sig
                ext = highs[t] if long_sig else lows[t]
                fav_ext = ((ext - entry1) if long_sig else (entry1 - ext)) / a_sig
                if fav_close > rec["peak_close_move_atr"]:
                    rec["peak_close_move_atr"] = fav_close
                if fav_ext > rec["peak_extreme_move_atr"]:
                    rec["peak_extreme_move_atr"] = fav_ext
                if post_l2 is not None:
                    if fav_close > post_l2["peak_close_move_atr"]:
                        post_l2["peak_close_move_atr"] = fav_close
                    if fav_ext > post_l2["peak_extreme_move_atr"]:
                        post_l2["peak_extreme_move_atr"] = fav_ext
                basket_r = sum(m * ((closes[t] - px) if long_sig else (px - closes[t]))
                               for m, px in legs) / stop_dist
                if basket_r > peak_r:
                    peak_r = basket_r
                if len(legs) >= 2:
                    if long_sig:
                        peak_close = max(peak_close, closes[t])
                        wsum = sum(m * px for m, px in legs)
                        wsize = sum(m for m, _ in legs)
                        be = wsum / wsize + bebuf * a_sig
                        trail = peak_close - (0.0 if no_trail else trailm * a_sig)
                        basket_stop = max(basket_stop, be, trail)
                    else:
                        peak_close = min(peak_close, closes[t])
                        wsum = sum(m * px for m, px in legs)
                        wsize = sum(m for m, _ in legs)
                        be = wsum / wsize - bebuf * a_sig
                        trail = peak_close + (0.0 if no_trail else trailm * a_sig)
                        basket_stop = min(basket_stop, be, trail)
                    if post_l2 is not None and len(post_l2["corridor"]) < 8:
                        # giveback-stop level vs trail-stop level, base-move ATR
                        gb_level_r = gb * peak_r
                        if len(legs) == 2:
                            # basket_r = (1+s2)*move_atr - s2*l2move_atr, l2move~a2
                            gb_move_atr = (gb_level_r + s2 * a2) / (1.0 + s2)
                            stop_move_atr = abs(basket_stop - entry1) / a_sig
                            post_l2["corridor"].append(dict(
                                bar=int(hours[t]),
                                close_move_atr=round(fav_close, 3),
                                giveback_level_move_atr=round(gb_move_atr, 3),
                                trail_stop_move_atr=round(stop_move_atr, 3),
                                which_tighter=("giveback" if gb_move_atr > stop_move_atr
                                               else "trail"),
                            ))
                if basket_r <= -BOUNDS_R:
                    exit_r = basket_r
                    reason = "adverse_bound"
                    break
                if (not no_giveback) and peak_r > 0.0 and basket_r <= gb * peak_r:
                    exit_r = basket_r
                    reason = "giveback"
                    rec["giveback_peak_r"] = round(peak_r, 4)
                    # effective close retrace from peak, in ATR and R
                    rec["giveback_retrace_atr"] = round(
                        (rec["peak_close_move_atr"] - fav_close), 4)
                    break
                if held >= tsb and not no_time_stop:
                    exit_r = basket_r
                    reason = "time_stop"
                    break
                ext = highs[t] if long_sig else lows[t]
                if len(legs) == 1:
                    new_ext = (ext > extreme_since_entry) if long_sig else (ext < extreme_since_entry)
                    extreme_since_entry = max(extreme_since_entry, ext) if long_sig else min(extreme_since_entry, ext)
                    if move_close >= a2 * a_sig and new_ext:
                        pending_add = 2
                elif len(legs) == 2 and l2_fill_bar is not None and t > l2_fill_bar:
                    base = extreme_since_l2 if extreme_since_l2 is not None else ext
                    new_ext2 = (ext > base) if long_sig else (ext < base)
                    extreme_since_l2 = max(base, ext) if long_sig else min(base, ext)
                    if move_close >= a3 * a_sig and new_ext2:
                        pending_add = 3
                t += 1
            if exit_r is None:
                exit_r = 0.0
                reason = "series_end"
            stats["r_sum"] += exit_r
            rec["exit_reason"] = reason
            rec["exit_r"] = round(exit_r, 4)
            rec["bars_held"] = held
            rec["margin_to_add3"] = round(rec["peak_close_move_atr"] - a3, 4)
            if post_l2 is not None:
                post_l2["peak_close_move_atr"] = round(post_l2["peak_close_move_atr"], 4)
                post_l2["peak_extreme_move_atr"] = round(post_l2["peak_extreme_move_atr"], 4)
                post_l2["margin_to_add3"] = round(post_l2["peak_close_move_atr"] - a3, 4)
                if post_l2["corridor"]:
                    tighter = [c["which_tighter"] for c in post_l2["corridor"]]
                    post_l2["stop_tighter"] = ("giveback" if tighter.count("giveback") >= len(tighter) / 2
                                               else "trail")
                rec["post_l2"] = post_l2
            if reason == "giveback" and len(legs) == 1:
                stats["giveback_before_l2"] += 1
            key = {"stop": "exits_stop", "adverse_bound": "exits_adverse_bound",
                   "giveback": "exits_giveback", "time_stop": "exits_time_stop",
                   "flatten": "exits_flatten"}.get(reason)
            if key:
                stats[key] += 1
            else:
                stats["exits_series_end"] += 1
            rec["legs"] = len(legs)
            basket_records.append(rec)
        i = max(j, i + 1)

    return stats, basket_records, shock_records


def pct(values, q):
    if not values:
        return None
    return round(float(np.percentile(np.asarray(values, dtype=float), q)), 4)


def summarize(records):
    n = len(records)
    l2 = [r for r in records if r["l2_filled"]]
    out = dict(
        n=n,
        l2_filled=len(l2),
        l3_filled=sum(1 for r in records if r["l3_filled"]),
        exit_reasons={},
        margin_to_add3_all=pct([r["margin_to_add3"] for r in records], 50),
        margin_to_add3_p90=pct([r["margin_to_add3"] for r in records], 90),
        margin_to_add3_max=round(max(r["margin_to_add3"] for r in records), 4),
        share_peak_close_ge_1atr=round(sum(1 for r in records if r["peak_close_move_atr"] >= 1.0) / n, 4),
        share_peak_close_ge_1p5atr=round(sum(1 for r in records if r["peak_close_move_atr"] >= 1.5) / n, 4),
        share_peak_close_ge_2atr=round(sum(1 for r in records if r["peak_close_move_atr"] >= 2.0) / n, 4),
        share_peak_extreme_ge_2atr=round(sum(1 for r in records if r["peak_extreme_move_atr"] >= 2.0) / n, 4),
        entry_hours={},
        giveback_exits=0,
        giveback_pre_l2=0,
        giveback_retrace_atr_median=None,
    )
    for r in records:
        out["exit_reasons"][r["exit_reason"]] = out["exit_reasons"].get(r["exit_reason"], 0) + 1
        out["entry_hours"][r["entry_hour_utc"]] = out["entry_hours"].get(r["entry_hour_utc"], 0) + 1
    gbs = [r for r in records if r["exit_reason"] == "giveback"]
    out["giveback_exits"] = len(gbs)
    out["giveback_pre_l2"] = sum(1 for r in gbs if not r["l2_filled"])
    if gbs:
        out["giveback_retrace_atr_median"] = pct([r["giveback_retrace_atr"] for r in gbs if r["giveback_retrace_atr"] is not None], 50)
    if l2:
        out["l2_baskets"] = dict(
            count=len(l2),
            exit_reasons={},
            post_l2_margin_to_add3_median=pct([r["post_l2"]["margin_to_add3"] for r in l2 if r["post_l2"]], 50),
            post_l2_margin_to_add3_max=round(max(r["post_l2"]["margin_to_add3"] for r in l2 if r["post_l2"]), 4),
            post_l2_stop_tighter={},
            bars_to_flatten_after_l2={},
        )
        for r in l2:
            pl = r["post_l2"]
            er = out["l2_baskets"]["exit_reasons"]
            er[r["exit_reason"]] = er.get(r["exit_reason"], 0) + 1
            tt = out["l2_baskets"]["post_l2_stop_tighter"]
            tt[pl["stop_tighter"]] = tt.get(pl["stop_tighter"], 0) + 1
            bf = out["l2_baskets"]["bars_to_flatten_after_l2"]
            bf[pl["bars_to_flatten_after_l2"]] = bf.get(pl["bars_to_flatten_after_l2"], 0) + 1
    return out


def main():
    results = {}
    all_records = {}
    shock_records = []
    preloaded_years = {year: load_year(year)[0] for year in YEARS}
    for toggle in [None] + list(TOGGLES):
        key = toggle or "BASE_PREREGISTERED"
        agg = dict(baskets=0, l2_fills=0, l3_fills=0)
        records = []
        for year in YEARS:
            st, recs, shk = simulate_year(year, toggle, preloaded=preloaded_years[year])
            for k in agg:
                agg[k] += st[k]
            records.extend(recs)
            if toggle == "shock_off":
                shock_records.extend(shk)
        results[key] = dict(**agg, **summarize(records))
        all_records[key] = records

    base = results["BASE_PREREGISTERED"]

    # Sanity: the base replay must reproduce the preregistered pilot totals.
    expected = dict(baskets=185, l2_fills=22, l3_fills=0)
    sanity = {k: dict(replayed=base[k], preregistered=v, match=base[k] == v)
              for k, v in expected.items()}

    # Counterfactual L3 reach table.
    cf = {}
    for toggle in TOGGLES:
        r = results[toggle]
        cf[toggle] = dict(l3_fills=r["l3_fills"], l2_fills=r["l2_fills"],
                          baskets=r["baskets"],
                          exit_reasons=r["exit_reasons"])

    # Shock-day potential.
    shock_potential = None
    if shock_records:
        sig = [r for r in shock_records if r["signal"]]
        shock_potential = dict(
            shock_days=len(shock_records),
            shock_days_with_signal=len(sig),
            peak_close_ge_2atr_signals=sum(1 for r in sig if r.get("peak_close_move_atr_no_exits", 0) >= 2.0),
            peak_close_move_atr_p50=pct([r.get("peak_close_move_atr_no_exits", 0) for r in sig], 50) if sig else None,
            peak_close_move_atr_p90=pct([r.get("peak_close_move_atr_no_exits", 0) for r in sig], 90) if sig else None,
            records=shock_records,
        )

    payload = {
        "schema": "qm.computed-output/h-py-l3-analysis/v1",
        "generated_by": Path(__file__).name,
        "label": "ANALYSIS_NOT_PREREGISTERED",
        "data_root": str(ROOT),
        "period": "2018-2020 discovery window (in-sample for the research lane)",
        "data_note": ("Dukascopy USATECHIDXUSD tick feed (NDX-class index CFD proxy), "
                      "read-only; NOT farm .DWX data; zero-cost mids (declared confounder, "
                      "identical to the pilot convention)."),
        "parameters": P,
        "sanity_replay_vs_preregistered_pilot": sanity,
        "base": base,
        "counterfactuals_single_rule_disabled": cf,
        "shock_day_potential": shock_potential,
        "basket_records": all_records["BASE_PREREGISTERED"],
        "analysis_questions": {
            "binding_constraint": ("see ANALYSIS.md: compare base exit_reasons, l2_baskets.post_l2_stop_tighter, "
                                   "margin_to_add3 distribution and the counterfactual L3 reach"),
            "classification": "see ANALYSIS.md (a/b/c)",
        },
    }
    OUT.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"sanity": sanity, "base_l3": base["l3_filled"],
                      "cf": {k: v["l3_fills"] for k, v in cf.items()},
                      "shock": shock_potential and shock_potential["peak_close_ge_2atr_signals"]},
                     indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
