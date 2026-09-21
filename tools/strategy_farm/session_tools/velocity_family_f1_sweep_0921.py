#!/usr/bin/env python3
"""Velocity family F1 sweep: QM5_13213 (Balke) multi-hour session-range breakout, 0 factory hours.

Pre-registration (grid, frozen mechanism, selection rule, null, control cell):
``docs/research/velocity/VELOCITY_FAMILY_F1_SESSION_RANGE_SWEEP_2026-09-21.md`` (committed before this ran).

Mechanism replicated from ``framework/EAs/QM5_13213_balke-gmt3-range-breakout/*.mq5``:
range = the N completed 60-min bars before the anchor; ATR(14) = simple 14-bar mean of the true range on the
same grid at shift 1; skip if W < 0.4*ATR or W > 2.5*ATR; buy stop at RH (SL RL) + sell stop at RL (SL RH),
OCO, no TP; trail SL to the min/max of the two last completed 60-min bars once open profit >= 1.0 * |entry-SL|;
flat at the session flat time (first tick at/after it), pending orders cancelled then; framework Friday close
21:00 server; framework news blackout (PRE30_POST30 high impact, strict symbol currencies) delays/blocks the
placement tick only.  Fills on the M1 bar touching the level, at the level, zero spread; a bar touching BOTH
edges scores a full loss at the stop (conservative).  Deterministic output (sorted keys, no timestamps).
"""
from __future__ import annotations

import argparse
import bisect
import calendar
import csv
import datetime as dt
import json
import random
import re
import statistics
import sys
from collections import defaultdict
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hcc_m1_reader_0921 import read_year  # noqa: E402

RISK = 1000.0
REPO = Path("C:/QM/repo")
COMMISSION = json.load(open(REPO / "framework/registry/live_commission.json", encoding="utf-8"))
NEWS_CSV = Path("D:/QM/data/news_calendar/news_calendar_2015_2025.csv")
CONTROL_REPORT = Path("D:/QM/reports/work_items/652e0768-ae51-45e4-a2cb-cd1e7c43afa7/QM5_41484/20260920_203244/raw/run_01/report.htm")
NY = ZoneInfo("America/New_York")
LON = ZoneInfo("Europe/London")
UTC = dt.timezone.utc
SEL = (dt.date(2018, 7, 2), dt.date(2022, 12, 31))
VAL = (dt.date(2023, 1, 1), dt.date(2025, 12, 31))
YEARS = range(2018, 2026)
MIN_MULT, MAX_MULT, TRAIL_TRIGGER = 0.4, 2.5, 1.0
FRIDAY_CLOSE_HOUR_SERVER = 21
STRICT_CCY = {"USD", "EUR", "GBP", "JPY", "AUD", "NZD", "CAD", "CHF", "CNY", "CNH", "HKD", "SGD", "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "TRY", "ZAR", "MXN", "BRL", "INR", "KRW"}

FX = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURAUD", "EURCAD", "EURCHF",
      "EURGBP", "EURJPY", "EURNZD", "EURUSD", "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCAD",
      "NZDCHF", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"]
METALS = ["XAUUSD", "XAGUSD"]
INDICES = ["GDAXI", "JPN225", "NDX", "SP500", "UK100", "WS30"]
ALL_SYMBOLS = [s + ".DWX" for s in FX + METALS + INDICES]
USD_PAIRS = ["EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX", "NZDUSD.DWX", "USDJPY.DWX", "USDCHF.DWX", "USDCAD.DWX"]
# USD value of one point per lot for non-FX symbols: (value, currency, source)
POINT_VALUE = {
    "XAUUSD": (100.0, "USD", "contract 100 oz"), "XAGUSD": (5000.0, "USD", "contract 5000 oz"),
    "NDX": (1.0, "USD", "registry custom_tv=1.0"), "WS30": (0.1, "USD", "registry custom_tv=0.1"),
    "GDAXI": (1.0, "EUR", "registry custom_tv=1.17 USD = 1 EUR/point"), "UK100": (1.0, "GBP", "registry custom_tv=1.35 USD = 1 GBP/point"),
    "SP500": (1.0, "USD", "ASSUMED 1.0 USD/point (no registry point value) - cost only"),
    "JPN225": (1.0, "USD", "ASSUMED 1.0 USD/point (no registry point value) - cost only"),
}
INDEX_NEWS_CCY = {"NDX": "USD", "SP500": "USD", "WS30": "USD", "GDAXI": "EUR", "UK100": "GBP", "JPN225": "JPY"}
ANCHORS = {
    "A": {"kind": "gmt3", "anchor_hour": 6, "flat_hour": 18, "grid_offset": 0, "label": "06:00 GMT+3-equivalent (13213 window end), flat 18:00 GMT+3-equivalent"},
    "B": {"kind": "tz", "tz": "Europe/London", "anchor": (8, 0), "flat": (16, 0), "grid_offset": 0, "label": "08:00 Europe/London cash open, flat 16:00 London"},
    "C": {"kind": "tz", "tz": "America/New_York", "anchor": (8, 30), "flat": (16, 0), "grid_offset": 1800, "label": "08:30 America/New_York, flat 16:00 New York (grid shifted 30 min)"},
}
N_HOURS = (2, 3, 4)


# ----------------------------------------------------------------------------- time
def ny_offset(utc_epoch: int) -> int:
    return int(dt.datetime.fromtimestamp(utc_epoch, UTC).astimezone(NY).utcoffset().total_seconds())


def server_from_utc(utc_epoch: int) -> int:
    return utc_epoch + ny_offset(utc_epoch) + 7 * 3600


def utc_from_server(s: int) -> int:
    for off in (-18000, -14400):
        u = s - 7 * 3600 - off
        if ny_offset(u) == off:
            return u
    return s - 7 * 3600 + 18000


def server_from_local(local: dt.datetime) -> int:
    return server_from_utc(calendar.timegm(local.astimezone(UTC).timetuple()))


def gmt3_anchor_server(day: dt.date, hour: int) -> int:
    utc = calendar.timegm(dt.datetime(day.year, day.month, day.day, hour).timetuple()) - 3 * 3600
    return server_from_utc(utc)


# ----------------------------------------------------------------------------- data
def load_m1(symbol: str, years=YEARS):
    bars = []
    for y in years:
        try:
            bars.extend(read_year(symbol, y))
        except FileNotFoundError:
            continue
    bars.sort(key=lambda r: r[0])
    out, last = [], None
    for r in bars:
        if r[0] != last:
            out.append((r[0], r[1], r[2], r[3], r[4]))
            last = r[0]
    return out


def structural_check(m1) -> dict:
    bad = 0
    for _, o, h, l, c in m1:
        if not (l <= o <= h and l <= c <= h and l > 0):
            bad += 1
    return {"m1_bars": len(m1), "monotonic_unique_time": True, "ohlc_violations": bad}


def aggregate(m1, period: int, offset: int = 0):
    agg = {}
    for t, o, h, l, c in m1:
        k = (t - offset) - (t - offset) % period + offset
        a = agg.get(k)
        if a is None:
            agg[k] = [o, h, l, c]
        else:
            a[1] = max(a[1], h)
            a[2] = min(a[2], l)
            a[3] = c
    return agg


def sma_atr(grid: dict, n: int = 14):
    """MT5 iATR semantics: simple n-bar mean of TR (TR uses the previous bar close); value keyed by bar start."""
    keys = sorted(grid)
    trs, atr, prev_c = [], {}, None
    for k in keys:
        o, h, l, c = grid[k]
        tr = h - l if prev_c is None else max(h - l, abs(h - prev_c), abs(l - prev_c))
        prev_c = c
        trs.append(tr)
        if len(trs) >= n:
            atr[k] = sum(trs[-n:]) / n
    return keys, atr


def load_news():
    ev = defaultdict(list)  # currency -> sorted utc epochs (high impact)
    with open(NEWS_CSV, encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            if str(row.get("impact", "")).strip().lower() != "high":
                continue
            ccy = str(row.get("currency", "")).strip().upper()
            try:
                t = calendar.timegm(dt.datetime.strptime(row["datetime"], "%Y-%m-%d %H:%M:%S").timetuple())
            except ValueError:
                continue
            ev[ccy].append(t)
    return {c: sorted(v) for c, v in ev.items()}


def symbol_news_currencies(symbol: str):
    s = symbol.split(".")[0]
    if s in INDEX_NEWS_CCY:
        return [INDEX_NEWS_CCY[s]]
    out = []
    for c in (s[:3], s[3:6]):
        if c in STRICT_CCY and c not in out:
            out.append(c)
    return out


def blackout_end(news, ccys, utc_t: int, pre=1800, post=1800):
    """If utc_t is inside a +/-30 min high-impact window of the symbol's currencies, return the epoch when the
    (chained) blackout ends, else None."""
    t = utc_t
    moved = True
    guard = 0
    while moved and guard < 20:
        moved = False
        guard += 1
        for c in ccys:
            arr = news.get(c) or []
            i = bisect.bisect_left(arr, t - post)
            while i < len(arr) and arr[i] <= t + pre:
                end = arr[i] + post + 1
                if end > t:
                    t = end
                    moved = True
                i += 1
    return None if t == utc_t else t


# ----------------------------------------------------------------------------- cost
def usd_conversion(conv, key: int):
    """Closes of the USD pairs at/before a server epoch -> usd_per(ccy)."""
    out = {"USD": 1.0}
    for pair, (keys, closes) in conv.items():
        i = bisect.bisect_right(keys, key) - 1
        if i < 0:
            continue
        px = closes[i]
        base, quote = pair[:3], pair[3:6]
        if quote == "USD":
            out[base] = px
        else:
            out[quote] = 1.0 / px
    return out


def lot_and_notional(symbol: str, price: float, w: float, rates):
    """lots for RISK per range width W and USD notional per lot."""
    s = symbol.split(".")[0]
    if s in POINT_VALUE:
        v, ccy, _ = POINT_VALUE[s]
        v_usd = v * rates.get(ccy, 1.0)
        return RISK / (w * v_usd), v_usd * price
    base, quote = s[:3], s[3:6]
    if quote == "USD":
        v_usd, nl = 100000.0, 100000.0 * price
    elif base == "USD":
        v_usd, nl = 100000.0 / price, 100000.0
    else:
        v_usd = 100000.0 * rates.get(quote, float("nan"))
        nl = 100000.0 * rates.get(base, float("nan"))
    return RISK / (w * v_usd), nl


def commission_r(symbol: str, lots: float, notional_per_lot: float) -> float:
    cls = COMMISSION["symbol_class"].get(symbol, COMMISSION["default_class"])
    m = COMMISSION["classes"][cls]
    c = max(m["pct_rate_rt"] * lots * notional_per_lot, m["flat_per_lot_rt"] * lots)
    return c / RISK if c == c else float("nan")


# ----------------------------------------------------------------------------- simulation
def day_list(anchor_spec, first: dt.date, last: dt.date):
    """Calendar days in the anchor's economic zone (Mon-Fri)."""
    d = first
    while d <= last:
        if d.weekday() < 5:
            yield d
        d += dt.timedelta(days=1)


def anchor_times(anchor_spec, day: dt.date):
    if anchor_spec["kind"] == "gmt3":
        return gmt3_anchor_server(day, anchor_spec["anchor_hour"]), gmt3_anchor_server(day, anchor_spec["flat_hour"])
    tz = ZoneInfo(anchor_spec["tz"])
    a = server_from_local(dt.datetime(day.year, day.month, day.day, *anchor_spec["anchor"], tzinfo=tz))
    f = server_from_local(dt.datetime(day.year, day.month, day.day, *anchor_spec["flat"], tzinfo=tz))
    return a, f


def friday_close_epoch(server_t: int):
    """Server epoch of the framework Friday close for the server-date of server_t, or None if not Friday."""
    d = dt.datetime.fromtimestamp(server_t, UTC)
    if d.weekday() != 4:
        return None
    return calendar.timegm(dt.datetime(d.year, d.month, d.day, FRIDAY_CLOSE_HOUR_SERVER).timetuple())


def simulate_cell(symbol, m1, times, grid, gkeys, atr, offset, anchor_spec, n_hours, news, ccys, conv):
    """One cell -> list of trades + day-state counters."""
    trades, states = [], defaultdict(int)
    first, last = SEL[0] - dt.timedelta(days=3), VAL[1]
    nbars = len(times)
    for day in day_list(anchor_spec, first, last):
        anchor, flat = anchor_times(anchor_spec, day)
        fri = friday_close_epoch(anchor)
        hard_end = min(flat, fri) if fri else flat
        if hard_end <= anchor:
            states["friday_blocked"] += 1
            continue
        rng = [grid.get(anchor - 3600 * k) for k in range(1, n_hours + 1)]
        if any(b is None for b in rng):
            states["no_range"] += 1
            continue
        rh = max(b[1] for b in rng)
        rl = min(b[2] for b in rng)
        w = rh - rl
        a = atr.get(anchor - 3600)
        if a is None or w <= 0 or a <= 0:
            states["no_atr"] += 1
            continue
        if w < MIN_MULT * a or w > MAX_MULT * a:
            states["atr_filtered"] += 1
            continue
        placement = anchor
        be = blackout_end(news, ccys, utc_from_server(anchor))
        if be is not None:
            placement = server_from_utc(be)
            if placement >= anchor + 3600:
                states["news_blocked"] += 1
                continue
            states["news_delayed"] += 1
        j = bisect.bisect_left(times, placement)
        if j >= nbars or times[j] >= hard_end:
            states["no_bars"] += 1
            continue
        # order validity at the placement tick (MT5 rejects a buy stop at/below the market and a sell stop
        # at/above it; 13213 does not retry): a side whose level the market has already passed is not placed.
        p_open = m1[j][1]
        buy_ok, sell_ok = p_open < rh, p_open > rl
        if not (buy_ok or sell_ok):
            states["orders_invalid_at_placement"] += 1
            continue
        if not (buy_ok and sell_ok):
            states["one_side_only"] += 1
        # pending phase
        d = 0
        entry = None
        while j < nbars and times[j] < hard_end:
            _, o, h, l, c = m1[j]
            hit_hi, hit_lo = (h >= rh) and buy_ok, (l <= rl) and sell_ok
            if hit_hi and hit_lo:
                d, entry, both = (1, rh, True)
                break
            if hit_hi:
                d, entry, both = (1, rh, False)
                break
            if hit_lo:
                d, entry, both = (-1, rl, False)
                break
            j += 1
        if entry is None:
            states["no_fill"] += 1
            continue
        fill_t = times[j]
        rates = usd_conversion(conv, anchor)
        lots, nl = lot_and_notional(symbol, entry, w, rates)
        cost = commission_r(symbol, lots, nl)
        if both:
            trades.append({"day": day, "dir": d, "entry": entry, "exit": entry - d * w, "gross_r": -1.0, "cost_r": cost,
                           "net_r": -1.0 - cost, "hold_min": 0.0, "exit_kind": "both_edges_same_bar", "w": w})
            states["trade"] += 1
            continue
        sl = rl if d > 0 else rh
        jj = j + 1
        exit_px, kind, exit_t = None, None, None
        while True:
            if jj >= nbars:
                exit_px, kind, exit_t = m1[jj - 1][4], "data_end", times[jj - 1]
                break
            t, o, h, l, c = m1[jj]
            if t >= hard_end:
                if t - hard_end > 3600 * 6:  # gap (holiday early close): final pre-flat closed bar
                    exit_px, kind, exit_t = m1[jj - 1][4], "flat_gap_prev_close", times[jj - 1]
                else:
                    exit_px, kind, exit_t = o, ("friday_close" if fri and hard_end == fri else "flat"), t
                break
            if d > 0 and l <= sl:
                exit_px, kind, exit_t = sl, ("stop" if sl <= rl else "trail_stop"), t
                break
            if d < 0 and h >= sl:
                exit_px, kind, exit_t = sl, ("stop" if sl >= rh else "trail_stop"), t
                break
            # trailing (evaluated on the bar close; two last completed grid bars before this bar)
            moved = (c - entry) * d
            risk = abs(entry - sl)
            if risk > 0 and moved >= TRAIL_TRIGGER * risk:
                g = (t - offset) - (t - offset) % 3600 + offset
                b1, b2 = grid.get(g - 3600), grid.get(g - 7200)
                if b1 and b2:
                    cand = min(b1[2], b2[2]) if d > 0 else max(b1[1], b2[1])
                    if d > 0 and cand > sl and cand < c:
                        sl = cand
                    elif d < 0 and cand < sl and cand > c:
                        sl = cand
            jj += 1
        gross = d * (exit_px - entry) / w
        trades.append({"day": day, "dir": d, "entry": entry, "exit": exit_px, "gross_r": gross, "cost_r": cost,
                       "net_r": gross - cost, "hold_min": (exit_t - fill_t) / 60.0, "exit_kind": kind, "w": w,
                       "fill_t": fill_t, "exit_t": exit_t})
        states["trade"] += 1
    return trades, dict(states)


def bdays(a: dt.date, b: dt.date) -> int:
    return sum(1 for k in range((b - a).days + 1) if (a + dt.timedelta(k)).weekday() < 5)


def worst_year_dd(seq):
    worst = peak = eq = 0.0
    year = None
    for d, r in seq:
        if d.year != year:
            year, peak, eq = d.year, 0.0, 0.0
        eq += r
        peak = max(peak, eq)
        worst = max(worst, peak - eq)
    return worst


def period_stats(trades, a: dt.date, b: dt.date):
    sel = [(t["day"], t["net_r"]) for t in trades if a <= t["day"] <= b]
    n = len(sel)
    bd = bdays(a, b)
    if n == 0:
        return {"trades": 0, "business_days": bd}
    net = sum(r for _, r in sel)
    gw = sum(r for _, r in sel if r > 0)
    gl = -sum(r for _, r in sel if r < 0)
    per_year = defaultdict(float)
    per_year_n = defaultdict(int)
    for d, r in sel:
        per_year[str(d.year)] += r
        per_year_n[str(d.year)] += 1
    holds = [t["hold_min"] for t in trades if a <= t["day"] <= b and t["hold_min"] > 0]
    kinds = defaultdict(int)
    for t in trades:
        if a <= t["day"] <= b:
            kinds[t["exit_kind"]] += 1
    return {"trades": n, "business_days": bd, "wins": sum(1 for _, r in sel if r > 0), "net_R": round(net, 3),
            "E_R": round(net / n, 4), "PF": round(gw / gl, 3) if gl > 0 else None, "density_per_bd": round(n / bd, 4),
            "R_per_bd": round(net / bd, 4), "worst_year_DD_R": round(worst_year_dd(sel), 2),
            "gross_E_R": round(sum(t["gross_r"] for t in trades if a <= t["day"] <= b) / n, 4),
            "cost_R_median": round(statistics.median([t["cost_r"] for t in trades if a <= t["day"] <= b]), 4),
            "hold_min_median": round(statistics.median(holds), 1) if holds else None,
            "net_R_per_year": {y: round(v, 2) for y, v in sorted(per_year.items())},
            "trades_per_year": dict(sorted(per_year_n.items())), "exit_kinds": dict(sorted(kinds.items()))}


def run_symbol(args):
    symbol, news, conv = args
    m1 = load_m1(symbol)
    if not m1:
        return symbol, {"error": "no_m1_history"}
    times = [r[0] for r in m1]
    ccys = symbol_news_currencies(symbol)
    grids = {}
    for off in (0, 1800):
        g = aggregate(m1, 3600, off)
        gkeys, atr = sma_atr(g)
        grids[off] = (g, gkeys, atr)
    out = {"structural_validation": structural_check(m1), "news_currencies": ccys, "cells": {}, "sequences": {}, "sequences_val": {}}
    for ak, spec in ANCHORS.items():
        g, gkeys, atr = grids[spec["grid_offset"]]
        for n in N_HOURS:
            trades, states = simulate_cell(symbol, m1, times, g, gkeys, atr, spec["grid_offset"], spec, n, news, ccys, conv)
            key = f"{ak}{n}"
            out["cells"][key] = {"anchor": ak, "n_hours": n, "day_states": states,
                                 "selection": period_stats(trades, *SEL), "validation": period_stats(trades, *VAL)}
            out["sequences"][key] = [(t["day"].isoformat(), round(t["net_r"], 6)) for t in trades if SEL[0] <= t["day"] <= SEL[1]]
            out["sequences_val"][key] = [(t["day"].isoformat(), round(t["net_r"], 6)) for t in trades if VAL[0] <= t["day"] <= VAL[1]]
            if symbol == "USDJPY.DWX" and key == "A3":
                out["control_trades"] = [{"day": t["day"].isoformat(), "dir": t["dir"], "net_r": round(t["net_r"], 5),
                                          "gross_r": round(t["gross_r"], 5), "hold_min": round(t["hold_min"], 1), "exit_kind": t["exit_kind"],
                                          "fill_t": t.get("fill_t"), "exit_t": t.get("exit_t")}
                                         for t in trades if SEL[0] <= t["day"] <= SEL[1]]
    return symbol, out


# ----------------------------------------------------------------------------- null + control
def bootstrap_pass_prob(seq, block=20, n_boot=200, seed=20260921, rule="SEL"):
    """Centred circular block bootstrap of a net-R sequence: P(resample meets the SEL rule) or, with
    rule="VAL", P(resample meets the VAL confirmation E[R] > 0 and PF >= 1.05). Independent periods, so the
    joint chance probability of a survivor is the product."""
    if rule == "SEL" and len(seq) < 300:
        return None
    if rule == "VAL" and len(seq) < 30:
        return None
    dates = [dt.date.fromisoformat(d) for d, _ in seq]
    r = [v for _, v in seq]
    mu = sum(r) / len(r)
    c = [v - mu for v in r]
    n = len(c)
    rng = random.Random(seed)
    passes = 0
    for _ in range(n_boot):
        res = []
        while len(res) < n:
            s = rng.randrange(n)
            res.extend(c[(s + k) % n] for k in range(block))
        res = res[:n]
        e = sum(res) / n
        gw = sum(v for v in res if v > 0)
        gl = -sum(v for v in res if v < 0)
        pf = gw / gl if gl > 0 else float("inf")
        dd = worst_year_dd(list(zip(dates, res)))
        if rule == "SEL":
            if e >= 0.05 and pf >= 1.10 and dd <= 25.0:
                passes += 1
        else:
            if e > 0 and pf >= 1.05:
                passes += 1
    return passes / n_boot


def parse_control_report(path: Path):
    raw = path.read_bytes()
    txt = raw.decode("utf-16") if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else raw.decode("utf-8", "replace")
    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", txt, flags=re.S)
    deals = []
    for r in rows:
        cells = [re.sub(r"<[^>]+>", "", c).strip() for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, flags=re.S)]
        if len(cells) == 13 and re.match(r"\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}", cells[0]) and cells[4] in ("in", "out"):
            num = lambda s: float(re.sub(r"[^\d.\-]", "", s) or 0)
            deals.append({"t": dt.datetime.strptime(cells[0], "%Y.%m.%d %H:%M:%S"), "type": cells[3], "dirn": cells[4],
                          "price": num(cells[6]), "comm": num(cells[8]), "profit": num(cells[10]), "comment": cells[12]})
    trades, cur = [], None
    for d in deals:
        if d["dirn"] == "in":
            cur = d
        elif cur is not None:
            net = d["profit"] + d["comm"] + cur["comm"]
            trades.append({"day": cur["t"].date(), "dir": 1 if cur["type"] == "buy" else -1, "net_r": net / RISK,
                           "hold_min": (d["t"] - cur["t"]).total_seconds() / 60.0, "fill_t": cur["t"], "exit_t": d["t"], "comment": d["comment"]})
            cur = None
    return trades


def compare_control(sim_trades, rep_trades):
    def stats(tr):
        n = len(tr)
        net = sum(t["net_r"] for t in tr)
        gw = sum(t["net_r"] for t in tr if t["net_r"] > 0)
        gl = -sum(t["net_r"] for t in tr if t["net_r"] < 0)
        return {"trades": n, "net_R": round(net, 2), "E_R": round(net / n, 4) if n else None,
                "PF": round(gw / gl, 3) if gl else None, "hold_min_median": round(statistics.median([t["hold_min"] for t in tr]), 1) if tr else None,
                "trades_per_year": dict(sorted((str(y), sum(1 for t in tr if (t["day"] if isinstance(t["day"], dt.date) else dt.date.fromisoformat(t["day"])).year == y)) for y in range(2018, 2023)))}
    sim_days = {dt.date.fromisoformat(t["day"]): t for t in sim_trades}
    rep_days = {t["day"]: t for t in rep_trades}
    common = sorted(set(sim_days) & set(rep_days))
    same_dir = sum(1 for d in common if sim_days[d]["dir"] == rep_days[d]["dir"])
    r_diff = [sim_days[d]["net_r"] - rep_days[d]["net_r"] for d in common if sim_days[d]["dir"] == rep_days[d]["dir"]]
    sim_only = sorted(set(sim_days) - set(rep_days))
    rep_only = sorted(set(rep_days) - set(sim_days))
    return {"simulation": stats([{**t, "day": t["day"]} for t in sim_trades]), "tester_report": stats(rep_trades),
            "days_common": len(common), "days_sim_only": len(sim_only), "days_report_only": len(rep_only),
            "same_direction_on_common_days": same_dir,
            "net_R_diff_on_common_same_dir_days": {"mean": round(sum(r_diff) / len(r_diff), 4) if r_diff else None,
                                                   "median": round(statistics.median(r_diff), 4) if r_diff else None,
                                                   "p10": round(sorted(r_diff)[int(0.1 * len(r_diff))], 4) if r_diff else None,
                                                   "p90": round(sorted(r_diff)[int(0.9 * len(r_diff))], 4) if r_diff else None},
            "sim_only_days": [{"day": d.isoformat(), "net_r": round(sim_days[d]["net_r"], 3), "exit_kind": sim_days[d]["exit_kind"], "fill_t": sim_days[d].get("fill_t")} for d in sim_only],
            "report_only_days": [{"day": d.isoformat(), "net_r": round(rep_days[d]["net_r"], 3), "comment": rep_days[d].get("comment")} for d in rep_only],
            "sim_only_net_R_sum": round(sum(sim_days[d]["net_r"] for d in sim_only), 3),
            "direction_mismatch_days": [{"day": d.isoformat(), "sim": round(sim_days[d]["net_r"], 3), "rep": round(rep_days[d]["net_r"], 3)} for d in common if sim_days[d]["dir"] != rep_days[d]["dir"]],
            "sim_only_by_year": {str(y): sum(1 for d in sim_only if d.year == y) for y in range(2018, 2023)},
            "report_only_by_year": {str(y): sum(1 for d in rep_only if d.year == y) for y in range(2018, 2023)}}


# ----------------------------------------------------------------------------- main
def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--symbols", default="ALL")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--out", default=str(REPO / "docs/ops/evidence/2026-09-20_velocity_book/velocity_family_f1_sweep_0921.json"))
    ap.add_argument("--control-only", action="store_true")
    a = ap.parse_args()
    symbols = ["USDJPY.DWX"] if a.control_only else (ALL_SYMBOLS if a.symbols == "ALL" else a.symbols.split(","))
    news = load_news()
    conv = {}
    for pair in USD_PAIRS:
        g = aggregate(load_m1(pair), 3600)
        keys = sorted(g)
        conv[pair] = (keys, [g[k][3] for k in keys])
    print(f"news currencies loaded: {len(news)}; conversion pairs: {len(conv)}", file=sys.stderr)
    results = {}
    if a.workers > 1 and len(symbols) > 1:
        with ProcessPoolExecutor(max_workers=a.workers) as ex:
            for sym, res in ex.map(run_symbol, [(s, news, conv) for s in symbols]):
                results[sym] = res
                print(f"done {sym}", file=sys.stderr)
    else:
        for s in symbols:
            sym, res = run_symbol((s, news, conv))
            results[sym] = res
            print(f"done {sym}", file=sys.stderr)
    # control
    control = None
    if "USDJPY.DWX" in results and "control_trades" in results["USDJPY.DWX"]:
        rep = parse_control_report(CONTROL_REPORT) if CONTROL_REPORT.exists() else []
        control = compare_control(results["USDJPY.DWX"]["control_trades"], rep)
        control["reference_q02"] = {"work_item": "652e0768", "total_trades": 888, "net_profit_usd": 46636.78, "profit_factor": 1.12,
                                    "E_R_after_commission": round(46636.78 / 888 / RISK, 4)}
    # cells table + survivors + null
    cells, survivors, null_sum, pos_cells, eligible, null_joint = {}, [], 0.0, 0, 0, 0.0
    for sym, res in sorted(results.items()):
        if "error" in res:
            continue
        for key, cell in res["cells"].items():
            s, v = cell["selection"], cell["validation"]
            p = bootstrap_pass_prob(res["sequences"][key]) if s["trades"] >= 300 else None
            pv = bootstrap_pass_prob(res["sequences_val"][key], rule="VAL", seed=20260922) if p is not None else None
            pj = round(p * pv, 4) if (p is not None and pv is not None) else None
            rec = {"symbol": sym, "cell": key, "anchor": cell["anchor"], "n_hours": cell["n_hours"], "selection": s, "validation": v,
                   "chance_pass_prob_SEL": p, "chance_pass_prob_VAL": pv, "chance_pass_prob_joint": pj, "day_states": cell["day_states"]}
            cells[f"{sym}|{key}"] = rec
            if s["trades"] > 0:
                pos_cells += 1 if s["E_R"] > 0 else 0
            if p is not None:
                null_sum += p
                eligible += 1
                if pj is not None:
                    null_joint += pj
            sel_ok = s["trades"] >= 300 and s["E_R"] >= 0.05 and (s["PF"] or 0) >= 1.10 and s["worst_year_DD_R"] <= 25.0
            val_ok = v["trades"] > 0 and v["E_R"] > 0 and (v["PF"] or 0) >= 1.05
            rec["passes_SEL_rule"] = sel_ok
            rec["passes_VAL_confirmation"] = bool(sel_ok and val_ok)
            if sel_ok:
                nb = []
                for m in N_HOURS:
                    if m != cell["n_hours"]:
                        c2 = res["cells"].get(f"{cell['anchor']}{m}")
                        nb.append(bool(c2 and c2["selection"]["trades"] > 0 and c2["selection"]["E_R"] > 0))
                rec["family_consistent"] = all(nb)
                if val_ok:
                    survivors.append({"symbol": sym, "cell": key, "family_consistent": all(nb), "SEL": s, "VAL": v,
                                      "chance_pass_prob_SEL": p, "chance_pass_prob_VAL": pv, "chance_pass_prob_joint": pj})
    n_cells = sum(1 for c in cells.values() if c["selection"]["trades"] > 0)
    out = {
        "schema": "qm.velocity-family-f1-sweep/v1",
        "registration": "docs/research/velocity/VELOCITY_FAMILY_F1_SESSION_RANGE_SWEEP_2026-09-21.md",
        "script": "tools/strategy_farm/session_tools/velocity_family_f1_sweep_0921.py",
        "reader": "tools/strategy_farm/session_tools/hcc_m1_reader_0921.py",
        "mechanism": "QM5_13213 Balke session-range breakout, replicated (see module docstring)",
        "anchors": {k: v["label"] for k, v in ANCHORS.items()}, "n_hours": list(N_HOURS),
        "selection_period": [SEL[0].isoformat(), SEL[1].isoformat()], "validation_period": [VAL[0].isoformat(), VAL[1].isoformat()],
        "risk_fixed": RISK, "commission_model": COMMISSION["model"], "commission_classes": COMMISSION["classes"],
        "point_values": {k: {"value": v[0], "currency": v[1], "source": v[2]} for k, v in POINT_VALUE.items()},
        "spread_model": "zero (.DWX custom history carries no spread; XAUUSD FTMO-venue spread sensitivity: see H-V2 prescreen)",
        "fill_model": "M1 bar touching the level fills at the level; both edges in one bar = full loss at the stop; trailing evaluated on M1 closes",
        "news_model": "PRE30_POST30 high-impact (news_calendar_2015_2025.csv, UTC) on the strict symbol currencies; delays/blocks the placement tick only",
        "selection_rule": {"SEL": "n>=300, E[R]>=+0.05R net, PF>=1.10, worst-year DD<=25R", "VAL": "E[R]>0, PF>=1.05 (confirmation only)",
                           "family_consistency": "neighbouring N cells of the same symbol/anchor have SEL E[R]>0"},
        "null": {"method": "centred circular block bootstrap (block 20 trades, 200 resamples, seed 20260921) of each cell's SEL net-R sequence; P(meets SEL rule)",
                 "cells_evaluated": n_cells, "cells_with_n_ge_300": eligible, "fraction_cells_SEL_E_R_positive": round(pos_cells / n_cells, 4) if n_cells else None,
                 "expected_false_SEL_survivors": round(null_sum, 3),
                 "expected_false_survivors_after_VAL": round(null_joint, 3),
                 "caveat": "cells of one symbol share days and ranges (neighbouring N, overlapping anchors) and are not independent; the sums are per-cell expectations, not a family-level test"},
        "observed": {"cells_passing_SEL_rule": sum(1 for c in cells.values() if c.get("passes_SEL_rule")),
                     "survivors_after_VAL_confirmation": len(survivors),
                     "survivors_family_consistent": sum(1 for s in survivors if s["family_consistent"])},
        "survivors": sorted(survivors, key=lambda s: (s["symbol"], s["cell"])),
        "control_cell": control,
        "symbols": {sym: {"structural_validation": res.get("structural_validation"), "news_currencies": res.get("news_currencies"),
                          "validation_label": ("harvest_validated" if sym in ("EURUSD.DWX", "GBPUSD.DWX") else
                                               "structural_validation_only" if sym.split(".")[0] in INDICES else "same_reader_same_format"),
                          "error": res.get("error")} for sym, res in sorted(results.items())},
        "cells": dict(sorted(cells.items())),
    }
    Path(a.out).write_text(json.dumps(out, indent=1, sort_keys=True, default=str) + "\n", encoding="utf-8", newline="\n")
    if control:
        print("CONTROL USDJPY A3:", json.dumps({k: control[k] for k in ("simulation", "tester_report", "days_common", "days_sim_only", "days_report_only", "same_direction_on_common_days", "net_R_diff_on_common_same_dir_days")}, indent=None))
    print(f"cells {n_cells}, SEL-rule passes {out['observed']['cells_passing_SEL_rule']}, survivors {len(survivors)}, "
          f"expected false SEL {out['null']['expected_false_SEL_survivors']}, expected false after VAL {out['null']['expected_false_survivors_after_VAL']}, "
          f"frac positive {out['null']['fraction_cells_SEL_E_R_positive']}")
    print(f'{"symbol":<12}{"cell":<5}{"SEL n":>6}{"/bd":>6}{"E[R]":>8}{"PF":>7}{"DD":>7}{"R/bd":>8} | {"VAL n":>6}{"E[R]":>8}{"PF":>7}{"DD":>7}')
    for k, c in sorted(cells.items(), key=lambda kv: -(kv[1]["selection"].get("E_R") or -9)):
        s, v = c["selection"], c["validation"]
        if s["trades"] == 0:
            continue
        print(f'{c["symbol"]:<12}{c["cell"]:<5}{s["trades"]:>6}{s["density_per_bd"]:>6.2f}{s["E_R"]:>8.3f}{s["PF"] or 0:>7.2f}{s["worst_year_DD_R"]:>7.1f}{s["R_per_bd"]:>8.3f} | '
              f'{v.get("trades", 0):>6}{(v.get("E_R") if v.get("trades") else 0) or 0:>8.3f}{(v.get("PF") if v.get("trades") else 0) or 0:>7.2f}{(v.get("worst_year_DD_R") if v.get("trades") else 0) or 0:>7.1f}'
              + ("  SURVIVOR" if c.get("passes_VAL_confirmation") else ("  sel-pass" if c.get("passes_SEL_rule") else "")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
