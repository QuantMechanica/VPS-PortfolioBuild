#!/usr/bin/env python3
"""Track B family B2 prescreen (Fable, 2026-09-21): Antigravity top set H-AG1/H-AG2/H-AG4/H-AG5/H-AG6/H-AG8 (specs verbatim from
``docs/research/ftmo_shadow/agy_edge_generation_2caa90f8.md`` section 3) plus the B1-derived lineages H-B2r and H-B7r, pre-registered
in ``docs/research/ftmo_shadow/TRACK_B_EDGE_DISCOVERY_PROGRAMME_2026-09-21.md`` section 9, run in the shared F2 conservative
closed-bar execution engine (0 factory hours). 15 cells; family bar 0.05/15; H-B7r (post-hoc lineage) bar E[R] >= +0.12, PF >= 1.25,
chance <= 0.001. Documented simplifications: ATR(14, D1) = mean of the previous 14 cash-session (or 24 h server-day) ranges;
ATR(14, H1) = simple 14-bar mean of the H1 true range; "cash ATR" for FX = mean of the previous 14 server-day ranges.
"""
from __future__ import annotations
import argparse
import datetime as dt
import json
import sys
from collections import defaultdict
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from zoneinfo import ZoneInfo
sys.path.insert(0, str(Path(__file__).resolve().parent))
import velocity_family_f1_sweep_0921 as F1  # noqa: E402
import velocity_family_f2_cash_session_0921 as F2  # noqa: E402

REPO = Path("C:/QM/repo")
NY, BER = ZoneInfo("America/New_York"), ZoneInfo("Europe/Berlin")
SEL, VAL = F1.SEL, F1.VAL
REGISTRATION = "docs/research/ftmo_shadow/TRACK_B_EDGE_DISCOVERY_PROGRAMME_2026-09-21.md section 9"
F2.COST_PRIOR.setdefault("USDJPY.DWX", (0.010, 0.005, 0.001, "prior: 1.0 pip RT"))
for s in ("USDJPY.DWX", "EURUSD.DWX", "GBPUSD.DWX", "XAUUSD.DWX"):
    F2.CASH.setdefault(s, (NY, (9, 30), (16, 0)))
N_CELLS = 15
CELLS = {
    "H-AG1": ["NDX.DWX", "SP500.DWX"], "H-AG2": ["SP500.DWX", "NDX.DWX"], "H-AG4": ["WS30.DWX", "NDX.DWX"], "H-AG5": ["XAUUSD.DWX"],
    "H-AG6": ["USDJPY.DWX"], "H-AG8": ["GBPUSD.DWX", "EURUSD.DWX"], "H-B2r": ["NDX.DWX", "SP500.DWX", "GDAXI.DWX"], "H-B7r": ["XAUUSD.DWX"],
}
PEER = {"H-AG6": "SP500.DWX"}
STRICT = {"H-B7r": {"E_R": 0.12, "PF": 1.25, "chance": 0.001}}


def ls(day, hm, tz=NY):
    return F2.local_server(day, hm, tz)


def day_range_atr(sym, day):
    """mean of the previous 14 full server-day ranges (FX / XAU 'D1 ATR' proxy)."""
    if not hasattr(sym, "_dr"):
        sym._dr = {}
        days = sorted({dt.datetime.utcfromtimestamp(F1.utc_from_server(t)).date() for t in sym.times[::60]})
        days = [d for d in days if d.weekday() < 5]
        valid = []  # previous valid weekday ranges (weekend stubs excluded; a missing day is skipped, not zero)
        for d in days:
            if len(valid) >= 14:
                sym._dr[d] = sum(valid[-14:]) / 14.0
            t0 = ls(d, (17, 0)) - 86400  # server day = 17:00 NY prior day .. 17:00 NY
            w = sym.window(t0, t0 + 86400)
            if w and w["n"] >= 600:
                valid.append(w["high"] - w["low"])
    return sym._dr.get(day)


def h_ag1(sym, day, s, news, ccys, rates, fill):
    """Cash-open OR fade: gap >= 0.40 D1-ATR; bar 3 (09:40-09:45) closes against the 09:30-09:45 drive; stop = 09:30-09:45 extreme +- 0.20 H1-ATR; target 50 % retrace or prior close; flat 11:30."""
    atr = sym.daily.get(day); pc = sym.prior_close(day)
    if atr is None or pc is None or atr <= 0:
        return "no_atr"
    ot = s["open_t"]
    first = sym.window(ot, ot + 900)
    b3 = F2.bar_at(sym.g5, ot + 600)
    if not first or b3 is None:
        return "no_bars"
    gap = first["open"] - pc
    if abs(gap) < 0.40 * atr:
        return "no_signal"
    drive = first["close"] - first["open"]
    d_drive = 1 if drive > 0 else -1 if drive < 0 else 0
    if d_drive == 0:
        return "no_signal"
    rng = b3[1] - b3[2]
    wick = (b3[1] - max(b3[0], b3[3])) if d_drive > 0 else (min(b3[0], b3[3]) - b3[2])
    reversal = (b3[3] - b3[0]) * d_drive < 0 or (rng > 0 and wick >= 0.5 * rng)
    if not reversal:
        return "no_signal"
    d = -d_drive
    h1 = sym.atr_h1(ot) or atr / 4.0
    ext = first["high"] if d < 0 else first["low"]
    stop = ext + 0.20 * h1 if d < 0 else ext - 0.20 * h1
    tgt = first["open"] + 0.5 * drive * (-1) if False else (first["close"] - 0.5 * drive)  # 50 % retracement of the drive
    entry_t = ot + 900
    if F2.news_skip(news, ccys, entry_t):
        return "news_blocked"
    return F2.simulate(sym, day, entry_t, d, stop, tgt, ls(day, (11, 30)), rates, "ag1", fill)


def h_ag2(sym, day, s, news, ccys, rates, fill):
    """Post-IB momentum: 10:00 or 10:15 M15 bar closes beyond the IB (09:30-10:00) by >= 0.10 D1-ATR with body >= 60 %; stop = IB midpoint; target 1.5 R; flat 15:45."""
    atr = sym.daily.get(day)
    if atr is None or atr <= 0:
        return "no_atr"
    ot = s["open_t"]
    ib = sym.window(ot, ot + 1800)
    if not ib:
        return "no_bars"
    mid = (ib["high"] + ib["low"]) / 2.0
    for k in (ot + 1800, ot + 2700):
        b = F2.bar_at(sym.g15, k)
        if b is None:
            continue
        rng = b[1] - b[2]
        if rng <= 0 or abs(b[3] - b[0]) < 0.6 * rng:
            continue
        if b[3] > ib["high"] + 0.10 * atr:
            d = 1
        elif b[3] < ib["low"] - 0.10 * atr:
            d = -1
        else:
            continue
        entry_t = k + 900
        ref = F2.bar_at(sym.g15, entry_t)
        if ref is None:
            return "no_bars"
        dist = abs(ref[0] - mid)
        if dist <= 0:
            return "bad_stop"
        if F2.news_skip(news, ccys, entry_t):
            return "news_blocked"
        return F2.simulate(sym, day, entry_t, d, mid, ref[0] + d * 1.5 * dist, ls(day, (15, 45)), rates, "ag2", fill)
    return "no_signal"


def h_ag4(sym, day, s, news, ccys, rates, fill):
    """Overnight range failure: 18:00 (prev) - 09:15 range; 09:30 M15 bar breaches by >= 15 pt (NDX: 0.10 D1-ATR), 09:45 bar closes back inside; enter 10:00 toward the midpoint; stop = trap extreme +- 20 pt (NDX: 0.15 D1-ATR); flat 12:30."""
    ot = s["open_t"]
    t0 = ls(day - dt.timedelta(days=1), (18, 0)); t1 = ls(day, (9, 15))
    on = sym.window(t0, t1)
    if not on or on["n"] < 200:
        return "no_range"
    b1, b2 = F2.bar_at(sym.g15, ot), F2.bar_at(sym.g15, ot + 900)
    if not (b1 and b2):
        return "no_bars"
    atr = sym.daily.get(day) or 0.0
    br = 15.0 if sym.symbol == "WS30.DWX" else 0.10 * atr
    pad = 20.0 if sym.symbol == "WS30.DWX" else 0.15 * atr
    if br <= 0:
        return "no_atr"
    if b1[1] >= on["high"] + br and on["low"] <= b2[3] <= on["high"]:
        d, ext = -1, max(b1[1], b2[1])
    elif b1[2] <= on["low"] - br and on["low"] <= b2[3] <= on["high"]:
        d, ext = 1, min(b1[2], b2[2])
    else:
        return "no_signal"
    stop = ext + pad if d < 0 else ext - pad
    tgt = (on["high"] + on["low"]) / 2.0
    entry_t = ot + 1800
    if F2.news_skip(news, ccys, entry_t):
        return "news_blocked"
    return F2.simulate(sym, day, entry_t, d, stop, tgt, ls(day, (12, 30)), rates, "ag4", fill)


def h_ag5(sym, day, s, news, ccys, rates, fill):
    """COMEX pit-open sweep MR: 03:00-08:15 range; an 08:20-08:55 M5 bar trades >= 1 USD outside and closes back inside with wick >= 50 %; release days (news blackout at 08:30) skipped; stop = sweep extreme +- 1.5 USD; target London midpoint (cap 2 R); flat 11:00."""
    r0, r1 = ls(day, (3, 0)), ls(day, (8, 15))
    w = sym.window(r0, r1)
    if not w or w["n"] < 200:
        return "no_range"
    if F2.news_skip(news, ccys, ls(day, (8, 30))):
        return "news_blocked"
    mid = (w["high"] + w["low"]) / 2.0
    t = ls(day, (8, 20))
    end = ls(day, (8, 55))
    while t + 300 <= end + 300:
        b = F2.bar_at(sym.g5, t)
        if b is None:
            t += 300; continue
        rng = b[1] - b[2]
        if rng > 0 and b[1] >= w["high"] + 1.0 and w["low"] <= b[3] <= w["high"] and (b[1] - max(b[0], b[3])) >= 0.5 * rng:
            d, ext = -1, b[1]
        elif rng > 0 and b[2] <= w["low"] - 1.0 and w["low"] <= b[3] <= w["high"] and (min(b[0], b[3]) - b[2]) >= 0.5 * rng:
            d, ext = 1, b[2]
        else:
            t += 300; continue
        entry_t = t + 300
        ref = F2.bar_at(sym.g5, entry_t)
        if ref is None:
            return "no_bars"
        stop = ext + 1.5 if d < 0 else ext - 1.5
        dist = abs(ref[0] - stop)
        tgt_mid = mid
        tgt = ref[0] + d * min(abs(tgt_mid - ref[0]), 2.0 * dist)
        if (d > 0 and tgt <= ref[0]) or (d < 0 and tgt >= ref[0]):
            return "no_signal"
        return F2.simulate(sym, day, entry_t, d, stop, tgt, ls(day, (11, 0)), rates, "ag5", fill)
    return "no_signal"


def h_ag6(sym, day, s, news, ccys, rates, fill, peer=None):
    """Equity -> USDJPY transmission: at 10:00 ET both SP500 and USDJPY 09:30-10:00 moves same sign, combined |moves| >= 0.40 D1-ATR (each in own units: USDJPY move >= 0.20 USDJPY D1-ATR and SP500 move >= 0.20 SP500 D1-ATR); enter USDJPY in that direction; stop = opposite extreme of the USDJPY 09:30-10:00 range; target 1.5 R; flat 15:30."""
    if peer is None:
        return "no_peer"
    ot = ls(day, (9, 30))
    wj = sym.window(ot, ot + 1800); wp = peer.window(ot, ot + 1800)
    if not wj or not wp:
        return "no_bars"
    aj = day_range_atr(sym, day); ap = peer.daily.get(day)
    if not aj or not ap:
        return "no_atr"
    mj, mp = wj["close"] - wj["open"], wp["close"] - wp["open"]
    if mj == 0 or mp == 0 or (mj > 0) != (mp > 0):
        return "no_signal"
    if abs(mj) < 0.20 * aj or abs(mp) < 0.20 * ap:
        return "no_signal"
    d = 1 if mj > 0 else -1
    stop = wj["low"] if d > 0 else wj["high"]
    entry_t = ot + 1800
    ref = F2.bar_at(sym.g15, entry_t)
    if ref is None:
        return "no_bars"
    dist = abs(ref[0] - stop)
    if dist <= 0:
        return "bad_stop"
    if F2.news_skip(news, ccys, entry_t):
        return "news_blocked"
    return F2.simulate(sym, day, entry_t, d, stop, ref[0] + d * 1.5 * dist, ls(day, (15, 30)), rates, "ag6", fill)


def h_ag8(sym, day, s, news, ccys, rates, fill):
    """WMR fix pre-hedge: move 08:00->10:15 ET >= 0.35 D1-ATR; 10:15-10:25 two M5 closes in that direction; enter 10:30; stop = opposite extreme of 10:00-10:30; target 1.2 R; flat 11:05."""
    a = day_range_atr(sym, day)
    if not a:
        return "no_atr"
    c0 = F2.bar_at(sym.g5, ls(day, (8, 0)) - 300); c1 = F2.bar_at(sym.g5, ls(day, (10, 15)) - 300)
    if not (c0 and c1):
        return "no_bars"
    move = c1[3] - c0[3]
    if abs(move) < 0.35 * a:
        return "no_signal"
    d = 1 if move > 0 else -1
    b1, b2 = F2.bar_at(sym.g5, ls(day, (10, 15))), F2.bar_at(sym.g5, ls(day, (10, 20)))
    if not (b1 and b2):
        return "no_bars"
    if not ((b1[3] - b1[0]) * d > 0 and (b2[3] - b2[0]) * d > 0):
        return "no_signal"
    w = sym.window(ls(day, (10, 0)), ls(day, (10, 30)))
    if not w:
        return "no_bars"
    stop = w["low"] if d > 0 else w["high"]
    entry_t = ls(day, (10, 30))
    ref = F2.bar_at(sym.g5, entry_t)
    if ref is None:
        return "no_bars"
    dist = abs(ref[0] - stop)
    if dist <= 0:
        return "bad_stop"
    if F2.news_skip(news, ccys, entry_t):
        return "news_blocked"
    return F2.simulate(sym, day, entry_t, d, stop, ref[0] + d * 1.2 * dist, ls(day, (11, 5)), rates, "ag8", fill)


def h_b2r(sym, day, s, news, ccys, rates, fill):
    """Post-open continuation, relaxed: bodies >= 40 %, bar-2 close beyond bar-1 extreme; stop = max(bar-1 extreme, 0.3 x cash ATR); target 1.5 R; flat 15:45 (GDAXI 17:15 CET)."""
    atr = sym.daily.get(day)
    if atr is None or atr <= 0:
        return "no_atr"
    ot = s["open_t"]
    b1, b2 = F2.bar_at(sym.g15, ot), F2.bar_at(sym.g15, ot + 900)
    if not (b1 and b2):
        return "no_bars"
    def body_ok(b):
        r = b[1] - b[2]
        return r > 0 and abs(b[3] - b[0]) >= 0.4 * r
    up = b1[3] > b1[0] and b2[3] > b2[0] and b2[3] > b1[1]
    dn = b1[3] < b1[0] and b2[3] < b2[0] and b2[3] < b1[2]
    if not (body_ok(b1) and body_ok(b2) and (up or dn)):
        return "no_signal"
    d = 1 if up else -1
    entry_t = ot + 1800
    ref = F2.bar_at(sym.g15, entry_t)
    if ref is None:
        return "no_bars"
    stop = b1[2] if d > 0 else b1[1]
    if abs(ref[0] - stop) < 0.3 * atr:
        stop = ref[0] - d * 0.3 * atr
    dist = abs(ref[0] - stop)
    if F2.news_skip(news, ccys, entry_t):
        return "news_blocked"
    flat = ls(day, (15, 45)) if sym.tz is NY else ls(day, (17, 15), BER)
    return F2.simulate(sym, day, entry_t, d, stop, ref[0] + d * 1.5 * dist, flat, rates, "b2r", fill)


def h_b7r(sym, day, s, news, ccys, rates, fill):
    """XAU COMEX-open drift REVERSAL (post-hoc lineage of B1 H-B7): same signal, opposite direction; stop 1.0 H1-ATR; target 1.0 R; flat 13:30."""
    t0800, t0930, t0945 = ls(day, (8, 0)), ls(day, (9, 30)), ls(day, (9, 45))
    c0 = F2.bar_at(sym.g15, t0800 - 900); c1 = F2.bar_at(sym.g15, t0930 - 900); b = F2.bar_at(sym.g15, t0930)
    if not (c0 and c1 and b):
        return "no_bars"
    atr = sym.atr_h1(t0930)
    if atr is None or atr <= 0:
        return "no_atr"
    drift = c1[3] - c0[3]
    if abs(drift) < 0.5 * atr:
        return "no_signal"
    dd = 1 if drift > 0 else -1
    with_drift = (b[3] - b[0]) * dd > 0
    d = -(dd if with_drift else -dd)
    ref = F2.bar_at(sym.g15, t0945)
    if ref is None:
        return "no_bars"
    if F2.news_skip(news, ccys, t0945):
        return "news_blocked"
    return F2.simulate(sym, day, t0945, d, ref[0] - d * atr, ref[0] + d * atr, ls(day, (13, 30)), rates, "b7r", fill)


HFUN = {"H-AG1": h_ag1, "H-AG2": h_ag2, "H-AG4": h_ag4, "H-AG5": h_ag5, "H-AG6": h_ag6, "H-AG8": h_ag8, "H-B2r": h_b2r, "H-B7r": h_b7r}


def run_symbol(args):
    symbol, hyps, news, conv, fill, peer_symbol = args
    try:
        sym = F2.Sym(symbol)
    except FileNotFoundError as exc:
        return symbol, {"error": f"no_m1_history: {exc}"}
    peer = None
    if peer_symbol:
        try:
            peer = F2.Sym(peer_symbol)
        except FileNotFoundError:
            peer = None
    ccys = F1.symbol_news_currencies(symbol)
    out = {"structural_validation": F1.structural_check(sym.m1), "news_currencies": ccys, "cost_prior": dict(zip(("spread_rt", "slip_rt", "tick", "source"), F2.COST_PRIOR[symbol])), "cells": {}}
    for h in hyps:
        fn = HFUN[h]
        trades, states = [], defaultdict(int)
        days = sym.days if h not in ("H-AG5", "H-AG6", "H-AG8", "H-B7r") else sorted({dt.datetime.utcfromtimestamp(F1.utc_from_server(t)).date() for t in sym.times[::60] if 0 <= dt.datetime.utcfromtimestamp(F1.utc_from_server(t)).weekday() < 5})
        for day in days:
            if day < SEL[0] or day > VAL[1]:
                continue
            s = sym.sessions.get(day) or {"open_t": ls(day, (9, 30))}
            rates = F1.usd_conversion(conv, s["open_t"])
            res = fn(sym, day, s, news, ccys, rates, fill, peer) if h == "H-AG6" else fn(sym, day, s, news, ccys, rates, fill)
            if isinstance(res, dict):
                trades.append(res); states["trade"] += 1
            else:
                states[res] += 1
        seq_sel = [(t["day"].isoformat(), round(t["net_r"], 6)) for t in trades if SEL[0] <= t["day"] <= SEL[1]]
        seq_val = [(t["day"].isoformat(), round(t["net_r"], 6)) for t in trades if VAL[0] <= t["day"] <= VAL[1]]
        s_stats, v_stats = F1.period_stats(trades, *SEL), F1.period_stats(trades, *VAL)
        p = F2.bootstrap_pass_prob(seq_sel, "SEL")
        pv = F2.bootstrap_pass_prob(seq_val, "VAL", seed=20260922) if p is not None else None
        rule = dict(F2.SEL_RULE, chance=0.05 / N_CELLS); rule.update(STRICT.get(h, {}))
        sel_ok = (s_stats["trades"] >= rule["n"] and s_stats.get("E_R", -9) >= rule["E_R"] and (s_stats.get("PF") or 0) >= rule["PF"]
                  and s_stats.get("worst_year_DD_R", 99) <= rule["DD"] and s_stats.get("density_per_bd", 0) >= rule["density"]
                  and p is not None and p <= rule["chance"])
        val_ok = (v_stats["trades"] > 0 and v_stats.get("E_R", -9) > F2.VAL_RULE["E_R"] and (v_stats.get("PF") or 0) >= F2.VAL_RULE["PF"]
                  and s_stats.get("R_per_bd", 0) > 0 and v_stats.get("R_per_bd", -9) >= F2.VAL_RULE["R_per_bd_share"] * s_stats.get("R_per_bd", 0)
                  and F2.val_year_dd_ok(trades))
        out["cells"][h] = {"hypothesis": h, "symbol": symbol, "fill_model": fill, "rule": rule, "day_states": dict(sorted(states.items())),
                           "selection": s_stats, "validation": v_stats, "chance_pass_prob_SEL": p, "chance_pass_prob_VAL": pv,
                           "passes_SEL_rule": bool(sel_ok), "passes_VAL_confirmation": bool(sel_ok and val_ok),
                           "state": ("WORTH_MT5_TEST" if (sel_ok and val_ok) else ("CLEAR_REJECT" if s_stats["trades"] >= 50 else "UNKNOWN")),
                           "sequence_sel": seq_sel, "sequence_val": seq_val}
    return symbol, out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hypotheses", default="ALL")
    ap.add_argument("--fill-model", default="conservative", choices=["conservative", "v1"])
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--out", default=str(REPO / "docs/research/ftmo_shadow/velocity_family_f4_b2_0921.json"))
    a = ap.parse_args()
    hyps = list(CELLS) if a.hypotheses == "ALL" else a.hypotheses.split(",")
    per_symbol = defaultdict(list)
    for h in hyps:
        for s in CELLS[h]:
            per_symbol[s].append(h)
    news = F1.load_news()
    conv = {}
    for pair in F1.USD_PAIRS:
        g = F1.aggregate(F1.load_m1(pair), 3600)
        keys = sorted(g)
        conv[pair] = (keys, [g[k][3] for k in keys])
    jobs = [(s, hs, news, conv, a.fill_model, PEER.get("H-AG6") if "H-AG6" in hs else None) for s, hs in sorted(per_symbol.items())]
    results = {}
    if a.workers > 1 and len(jobs) > 1:
        with ProcessPoolExecutor(max_workers=a.workers) as ex:
            for sym, res in ex.map(run_symbol, jobs):
                results[sym] = res; print(f"done {sym}", file=sys.stderr)
    else:
        for job in jobs:
            sym, res = run_symbol(job); results[sym] = res; print(f"done {sym}", file=sys.stderr)
    cells, survivors, null_sum, n_cells = {}, [], 0.0, 0
    for sym, res in sorted(results.items()):
        if "error" in res:
            continue
        for h, cell in res["cells"].items():
            cells[f"{h}|{sym}"] = {k: v for k, v in cell.items() if not k.startswith("sequence")}
            if cell["selection"]["trades"] > 0:
                n_cells += 1
            if cell["chance_pass_prob_SEL"] is not None:
                null_sum += cell["chance_pass_prob_SEL"]
            if cell["passes_VAL_confirmation"]:
                survivors.append({"cell": f"{h}|{sym}", "SEL": cell["selection"], "VAL": cell["validation"], "chance_pass_prob_SEL": cell["chance_pass_prob_SEL"], "chance_pass_prob_VAL": cell["chance_pass_prob_VAL"]})
    out = {"schema": "qm.velocity-family-f4-b2/v1", "registration": REGISTRATION, "script": "tools/strategy_farm/session_tools/velocity_family_f4_b2_0921.py",
           "engine": "velocity_family_f2_cash_session_0921.py (conservative closed-bar fills, min stop 5 x spread)", "fill_model": a.fill_model,
           "cost_priors": {s: dict(zip(("spread_rt", "slip_rt", "tick", "source"), F2.COST_PRIOR[s])) for s in per_symbol},
           "selection_period": [SEL[0].isoformat(), SEL[1].isoformat()], "validation_period": [VAL[0].isoformat(), VAL[1].isoformat()],
           "selection_rule": dict(F2.SEL_RULE, chance=round(0.05 / N_CELLS, 5)), "strict_rules": STRICT, "validation_rule": F2.VAL_RULE,
           "null": {"cells_evaluated": n_cells, "expected_false_SEL_survivors": round(null_sum, 4), "family_bonferroni_bar": round(0.05 / N_CELLS, 5)},
           "observed": {"cells_passing_SEL_rule": sum(1 for c in cells.values() if c["passes_SEL_rule"]), "survivors_after_VAL": len(survivors)},
           "cells": cells, "survivors": survivors,
           "sequences": {f"{h}|{s}": {"sel": r["cells"][h]["sequence_sel"], "val": r["cells"][h]["sequence_val"]} for s, r in results.items() if "cells" in r for h in r["cells"]}}
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_text(json.dumps(out, indent=1, sort_keys=True, default=str) + "\n", encoding="utf-8")
    print(json.dumps({"cells": n_cells, "SEL_pass": out["observed"]["cells_passing_SEL_rule"], "survivors": len(survivors), "expected_false": round(null_sum, 4), "out": a.out}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
