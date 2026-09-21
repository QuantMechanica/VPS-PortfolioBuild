#!/usr/bin/env python3
"""Track B family F2 prescreen: NY / index-cash-session hypotheses H-B1..H-B8 under a CONSERVATIVE closed-bar
execution model (Fable, 2026-09-21). Pre-registration (mechanics, fill model, pass rule, family bar):
``docs/research/ftmo_shadow/TRACK_B_EDGE_DISCOVERY_PROGRAMME_2026-09-21.md`` (committed before this ran).

Execution model (the H-V4 lesson): signals only on COMPLETED grid bars (M5/M15/H1 built from M1, NY-anchored); entries are
MARKET orders at the open of the bar after the signal bar, filled at open +/- (spread_rt + slip_rt)/2; stops are filled at the
WORSE of the stop level and the open of the first M1 bar that breaches it (gap-through charged in full) minus half spread+slip;
targets are limit fills only when the bar trades through the level by >= 1 tick; a bar touching stop and target scores the
stop; time exit at the first M1 bar at/after the flat time at that bar's open minus half spread+slip; framework Friday close
(21:00 server) caps every session; a scheduled high-impact release (PRE30/POST30, strict symbol currencies) inside the entry
minute skips the day (the EA's news blackout). No stop-entry orders anywhere. RISK_FIXED 1000; R = net / 1000; commission from
live_commission.json. Deterministic output (sorted keys, no timestamps). 0 factory hours. Reuses the family-F1 helpers.
"""
from __future__ import annotations
import argparse
import bisect
import datetime as dt
import json
import random
import statistics
import sys
from collections import defaultdict
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from zoneinfo import ZoneInfo
sys.path.insert(0, str(Path(__file__).resolve().parent))
import velocity_family_f1_sweep_0921 as F1  # noqa: E402

REPO = Path("C:/QM/repo")
NY = ZoneInfo("America/New_York")
BER = ZoneInfo("Europe/Berlin")
UTC = dt.timezone.utc
SEL, VAL, RISK = F1.SEL, F1.VAL, F1.RISK
REGISTRATION = "docs/research/ftmo_shadow/TRACK_B_EDGE_DISCOVERY_PROGRAMME_2026-09-21.md"

# per-symbol round-trip spread + slippage priors in PRICE units (recorded per cell; venue fidelity ticket 73434cab replaces them)
COST_PRIOR = {  # symbol: (spread_rt, slip_rt, tick, source)
    "NDX.DWX": (1.0, 0.5, 0.01, "prior: FTMO US100 ~0.5-1.0 pt spread"),
    "SP500.DWX": (0.4, 0.2, 0.01, "prior: FTMO US500 ~0.3-0.5 pt"),
    "WS30.DWX": (2.0, 1.0, 0.01, "prior: FTMO US30 ~1.5-2.5 pt"),
    "GDAXI.DWX": (1.0, 0.5, 0.01, "measured FTMO GER40 M1 harvest median ~0.9 pt (GER40_cash_FTMO_M1.jsonl)"),
    "UK100.DWX": (1.0, 0.5, 0.01, "prior"),
    "XAUUSD.DWX": (0.44, 0.10, 0.01, "measured FTMO XAUUSD M1 harvest median 44 points"),
    "EURUSD.DWX": (0.00010, 0.00005, 0.00001, "prior: 1.0 pip RT"),
    "GBPUSD.DWX": (0.00012, 0.00006, 0.00001, "prior: 1.2 pip RT"),
}
CASH = {  # symbol -> (tz, open (h,m), close (h,m))
    "NDX.DWX": (NY, (9, 30), (16, 0)), "SP500.DWX": (NY, (9, 30), (16, 0)), "WS30.DWX": (NY, (9, 30), (16, 0)),
    "GDAXI.DWX": (BER, (9, 0), (17, 30)),
}
HYPOTHESES = {
    "H-B1": {"symbols": ["NDX.DWX", "SP500.DWX", "WS30.DWX", "GDAXI.DWX"], "grid": 300},
    "H-B2": {"symbols": ["NDX.DWX", "SP500.DWX", "GDAXI.DWX"], "grid": 900},
    "H-B3": {"symbols": ["NDX.DWX", "SP500.DWX", "WS30.DWX"], "grid": 300},
    "H-B4": {"symbols": ["NDX.DWX", "SP500.DWX"], "grid": 300},
    "H-B5": {"symbols": ["NDX.DWX", "SP500.DWX", "GDAXI.DWX", "XAUUSD.DWX"], "grid": 900},
    "H-B6": {"symbols": ["NDX.DWX", "SP500.DWX", "WS30.DWX"], "grid": 300},
    "H-B7": {"symbols": ["XAUUSD.DWX"], "grid": 900},
    "H-B8": {"symbols": ["EURUSD.DWX", "GBPUSD.DWX"], "grid": 900},
}
SEL_RULE = {"n": 300, "E_R": 0.08, "PF": 1.15, "DD": 20.0, "density": 0.40, "chance": 0.002}
VAL_RULE = {"E_R": 0.0, "PF": 1.05, "R_per_bd_share": 0.5, "DD_year": 25.0}


# ----------------------------------------------------------------------------- time / data
def local_server(day: dt.date, hm, tz) -> int:
    return F1.server_from_local(dt.datetime(day.year, day.month, day.day, hm[0], hm[1], tzinfo=tz))


def idx_at(times, t):
    return bisect.bisect_left(times, t)


def bar_at(grid, t):
    return grid.get(t)


class Sym:
    """Per-symbol prepared data."""

    def __init__(self, symbol: str):
        self.symbol = symbol
        self.m1 = F1.load_m1(symbol)
        self.times = [r[0] for r in self.m1]
        self.g5 = F1.aggregate(self.m1, 300)
        self.g15 = F1.aggregate(self.m1, 900)
        self.g60 = F1.aggregate(self.m1, 3600)
        self.k60, self.atr60 = F1.sma_atr(self.g60)
        self.spread, self.slip, self.tick, self.cost_src = COST_PRIOR[symbol]
        self.half = (self.spread + self.slip) / 2.0
        tz, op, cl = CASH.get(symbol, (NY, (9, 30), (16, 0)))
        self.tz, self.open_hm, self.close_hm = tz, op, cl
        self.sessions = {}  # day -> dict(open_t, close_t, high, low, first_open, last_close)
        self.day_index = {}
        self._build_sessions()
        self.daily = self._daily_ranges()

    def _build_sessions(self):
        d = SEL[0] - dt.timedelta(days=40)
        while d <= VAL[1]:
            if d.weekday() < 5:
                ot, ct = local_server(d, self.open_hm, self.tz), local_server(d, self.close_hm, self.tz)
                i, j = idx_at(self.times, ot), idx_at(self.times, ct)
                if j - i >= 30:
                    seg = self.m1[i:j]
                    self.sessions[d] = {"open_t": ot, "close_t": ct, "high": max(b[2] for b in seg), "low": min(b[3] for b in seg),
                                        "first_open": seg[0][1], "last_close": seg[-1][4]}
            d += dt.timedelta(days=1)
        self.days = sorted(self.sessions)
        for n, dd in enumerate(self.days):
            self.day_index[dd] = n

    def _daily_ranges(self):
        """ATR-like: mean of the previous 14 cash-session ranges (excluding the day itself)."""
        out = {}
        rng = [self.sessions[d]["high"] - self.sessions[d]["low"] for d in self.days]
        for n, d in enumerate(self.days):
            if n >= 14:
                out[d] = sum(rng[n - 14:n]) / 14.0
        return out

    def prior_close(self, day):
        n = self.day_index.get(day)
        if n is None or n == 0:
            return None
        return self.sessions[self.days[n - 1]]["last_close"]

    def atr_h1(self, t):
        k = t - t % 3600 - 3600
        return self.atr60.get(k)

    def window(self, t0, t1):
        i, j = idx_at(self.times, t0), idx_at(self.times, t1)
        seg = self.m1[i:j]
        if not seg:
            return None
        return {"high": max(b[2] for b in seg), "low": min(b[3] for b in seg), "open": seg[0][1], "close": seg[-1][4], "n": len(seg)}


# ----------------------------------------------------------------------------- execution model
def simulate(sym: Sym, day, entry_t, direction, stop_px, target_px, flat_t, rates, kind_tag, fill_model="conservative"):
    """Market entry at the open of the first M1 bar at/after entry_t; returns a trade dict or a state string."""
    fri = F1.friday_close_epoch(entry_t)
    hard_end = min(flat_t, fri) if fri else flat_t
    if hard_end <= entry_t:
        return "friday_blocked"
    times, m1 = sym.times, sym.m1
    j = idx_at(times, entry_t)
    if j >= len(times) or times[j] >= hard_end:
        return "no_bars"
    if times[j] - entry_t > 900:
        return "gap_at_entry"
    half = 0.0 if fill_model == "v1" else sym.half
    o = m1[j][1]
    entry = o + direction * half
    stop_dist = abs(entry - stop_px)
    if stop_dist <= 0:
        return "bad_stop"
    lots, nl = F1.lot_and_notional(sym.symbol, entry, stop_dist, rates)
    cost = F1.commission_r(sym.symbol, lots, nl)
    jj = j
    exit_px = kind = exit_t = None
    while True:
        if jj >= len(times):
            exit_px, kind, exit_t = m1[jj - 1][4], "data_end", times[jj - 1]
            break
        t, bo, bh, bl, bc = m1[jj]
        if t >= hard_end:
            exit_px, kind, exit_t = bo - direction * half, ("friday_close" if fri and hard_end == fri else "flat"), t
            break
        if direction > 0:
            hit_stop = bl <= stop_px
            hit_tgt = target_px is not None and bh >= target_px + sym.tick
            if hit_stop:
                px = min(stop_px, bo) if fill_model != "v1" else stop_px
                exit_px, kind, exit_t = px - half, "stop", t
                break
            if hit_tgt:
                exit_px, kind, exit_t = target_px, "target", t
                break
        else:
            hit_stop = bh >= stop_px
            hit_tgt = target_px is not None and bl <= target_px - sym.tick
            if hit_stop:
                px = max(stop_px, bo) if fill_model != "v1" else stop_px
                exit_px, kind, exit_t = px + half, "stop", t
                break
            if hit_tgt:
                exit_px, kind, exit_t = target_px, "target", t
                break
        jj += 1
    gross = direction * (exit_px - entry) / stop_dist
    return {"day": day, "dir": direction, "entry": entry, "exit": exit_px, "gross_r": gross, "cost_r": cost, "net_r": gross - cost,
            "hold_min": (exit_t - times[j]) / 60.0, "exit_kind": kind, "w": stop_dist, "fill_t": times[j], "exit_t": exit_t, "tag": kind_tag}


def news_skip(news, ccys, entry_t):
    return F1.blackout_end(news, ccys, F1.utc_from_server(entry_t)) is not None


# ----------------------------------------------------------------------------- hypotheses
def h_b1(sym, day, s, news, ccys, rates, fill):
    """Cash-open mean reversion: fade a gap that the first three M5 bars fail to extend."""
    atr = sym.daily.get(day); pc = sym.prior_close(day)
    if atr is None or pc is None or atr <= 0:
        return "no_atr"
    ot = s["open_t"]
    b1, b2, b3 = bar_at(sym.g5, ot), bar_at(sym.g5, ot + 300), bar_at(sym.g5, ot + 600)
    if not (b1 and b2 and b3):
        return "no_bars"
    gap = b1[0] - pc
    if abs(gap) < 0.35 * atr:
        return "no_signal"
    if not (b1[2] <= b3[3] <= b1[1]):
        return "no_signal"  # bar 3 did not close back inside bar 1
    d = -1 if gap > 0 else 1
    ext = max(b1[1], b2[1], b3[1]) if d < 0 else min(b1[2], b2[2], b3[2])
    entry_ref = bar_at(sym.g5, ot + 900)
    if entry_ref is None:
        return "no_bars"
    if d < 0 and ext - entry_ref[0] < 0.4 * atr:
        ext = entry_ref[0] + 0.4 * atr
    if d > 0 and entry_ref[0] - ext < 0.4 * atr:
        ext = entry_ref[0] - 0.4 * atr
    entry_t = ot + 900
    if news_skip(news, ccys, entry_t):
        return "news_blocked"
    return simulate(sym, day, entry_t, d, ext, pc, local_server(day, (11, 30), NY) if sym.tz is NY else local_server(day, (11, 0), BER), rates, "b1", fill)


def h_b2(sym, day, s, news, ccys, rates, fill):
    """Post-open continuation: two same-direction strong 15-min bars, second beyond the first's extreme."""
    ot = s["open_t"]
    b1, b2 = bar_at(sym.g15, ot), bar_at(sym.g15, ot + 900)
    if not (b1 and b2):
        return "no_bars"
    def body_ok(b):
        r = b[1] - b[2]
        return r > 0 and abs(b[3] - b[0]) >= 0.6 * r
    up = b1[3] > b1[0] and b2[3] > b2[0] and b2[3] > b1[1]
    dn = b1[3] < b1[0] and b2[3] < b2[0] and b2[3] < b1[2]
    if not (body_ok(b1) and body_ok(b2) and (up or dn)):
        return "no_signal"
    d = 1 if up else -1
    stop = b1[2] if d > 0 else b1[1]
    entry_t = ot + 1800
    ref = bar_at(sym.g15, entry_t)
    if ref is None:
        return "no_bars"
    dist = abs(ref[0] - stop)
    if dist <= 0:
        return "bad_stop"
    tgt = ref[0] + d * 1.5 * dist
    if news_skip(news, ccys, entry_t):
        return "news_blocked"
    flat = local_server(day, (15, 45), NY) if sym.tz is NY else local_server(day, (17, 15), BER)
    return simulate(sym, day, entry_t, d, stop, tgt, flat, rates, "b2", fill)


def h_b3(sym, day, s, news, ccys, rates, fill):
    """Opening-range failure: close outside the 30-min OR then close back inside -> fade toward the OR midpoint."""
    ot = s["open_t"]
    orw = sym.window(ot, ot + 1800)
    if not orw:
        return "no_bars"
    orh, orl = orw["high"], orw["low"]
    mid = (orh + orl) / 2.0
    t = ot + 1800
    end = local_server(day, (12, 0), NY)
    prev_out = None
    while t + 300 <= end:
        b = bar_at(sym.g5, t)
        if b is None:
            t += 300; continue
        if prev_out is None:
            if b[3] > orh:
                prev_out = ("up", b[1])
            elif b[3] < orl:
                prev_out = ("dn", b[2])
        else:
            if orl <= b[3] <= orh:
                d = -1 if prev_out[0] == "up" else 1
                ext = max(prev_out[1], b[1]) if d < 0 else min(prev_out[1], b[2])
                entry_t = t + 300
                if news_skip(news, ccys, entry_t):
                    return "news_blocked"
                return simulate(sym, day, entry_t, d, ext, mid, end, rates, "b3", fill)
            else:
                prev_out = (prev_out[0], max(prev_out[1], b[1]) if prev_out[0] == "up" else min(prev_out[1], b[2]))
        t += 300
    return "no_signal"


def h_b4(sym, day, s, news, ccys, rates, fill):
    """Intraday pullback continuation on a qualified trend day (10:30 ET beyond the OR by 0.5 OR width)."""
    ot = s["open_t"]
    orw = sym.window(ot, ot + 1800)
    if not orw:
        return "no_bars"
    orh, orl = orw["high"], orw["low"]; w = orh - orl
    if w <= 0:
        return "no_signal"
    q = bar_at(sym.g5, ot + 3300)  # 10:25-10:30 bar
    if q is None:
        return "no_bars"
    if q[3] > orh + 0.5 * w:
        d = 1
    elif q[3] < orl - 0.5 * w:
        d = -1
    else:
        return "no_signal"
    end = local_server(day, (15, 45), NY)
    keys = [k for k in range(ot, ot + 3600, 300)]
    closes = [bar_at(sym.g5, k)[3] for k in keys if bar_at(sym.g5, k)]
    t = ot + 3600
    touched = None
    while t + 300 <= end:
        b = bar_at(sym.g5, t)
        if b is None:
            t += 300; continue
        closes.append(b[3])
        if len(closes) < 20:
            t += 300; continue
        sma = sum(closes[-20:]) / 20.0
        if touched is None:
            if (d > 0 and b[2] <= sma) or (d < 0 and b[1] >= sma):
                touched = b[2] if d > 0 else b[1]
        else:
            touched = min(touched, b[2]) if d > 0 else max(touched, b[1])
            if (d > 0 and b[3] > sma) or (d < 0 and b[3] < sma):
                entry_t = t + 300
                ref = bar_at(sym.g5, entry_t)
                if ref is None:
                    return "no_bars"
                dist = abs(ref[0] - touched)
                if dist <= 0:
                    return "bad_stop"
                if news_skip(news, ccys, entry_t):
                    return "news_blocked"
                return simulate(sym, day, entry_t, d, touched, ref[0] + d * 2.0 * dist, end, rates, "b4", fill)
        t += 300
    return "no_signal"


def h_b5(sym, day, s, news, ccys, rates, fill):
    """Volatility-compression release: 10:00-11:30 ET range <= 0.35 x median of the last 10 days' same window."""
    n = sym.day_index.get(day)
    if n is None or n < 10:
        return "no_atr"
    def win(dd):
        return sym.window(local_server(dd, (10, 0), NY), local_server(dd, (11, 30), NY))
    cur = win(day)
    if not cur:
        return "no_bars"
    hist = [win(sym.days[k]) for k in range(n - 10, n)]
    hist = [h["high"] - h["low"] for h in hist if h]
    if len(hist) < 8:
        return "no_atr"
    med = statistics.median(hist)
    rng = cur["high"] - cur["low"]
    if rng <= 0 or rng > 0.35 * med:
        return "no_signal"
    t = local_server(day, (11, 30), NY)
    end = local_server(day, (15, 45), NY)
    while t + 900 <= end:
        b = bar_at(sym.g15, t)
        if b is None:
            t += 900; continue
        if b[3] > cur["high"] or b[3] < cur["low"]:
            d = 1 if b[3] > cur["high"] else -1
            stop = cur["low"] if d > 0 else cur["high"]
            entry_t = t + 900
            ref = bar_at(sym.g15, entry_t)
            if ref is None:
                return "no_bars"
            if news_skip(news, ccys, entry_t):
                return "news_blocked"
            return simulate(sym, day, entry_t, d, stop, ref[0] + d * 1.5 * rng, end, rates, "b5", fill)
        t += 900
    return "no_signal"


def h_b6(sym, day, s, news, ccys, rates, fill):
    """Time-of-day reversal: strong 09:30-10:00 move, 10:00-10:15 fails to extend -> fade at 10:15."""
    atr = sym.daily.get(day)
    if atr is None or atr <= 0:
        return "no_atr"
    ot = s["open_t"]
    first = sym.window(ot, ot + 1800)
    if not first:
        return "no_bars"
    move = first["close"] - first["open"]
    if abs(move) < 0.6 * atr:
        return "no_signal"
    d_move = 1 if move > 0 else -1
    ext = first["high"] if d_move > 0 else first["low"]
    nxt = sym.window(ot + 1800, ot + 2700)
    if not nxt:
        return "no_bars"
    if (d_move > 0 and nxt["high"] > ext) or (d_move < 0 and nxt["low"] < ext):
        return "no_signal"
    d = -d_move
    stop = max(ext, nxt["high"]) if d < 0 else min(ext, nxt["low"])
    tgt = first["open"] + 0.5 * move
    entry_t = ot + 2700
    if news_skip(news, ccys, entry_t):
        return "news_blocked"
    return simulate(sym, day, entry_t, d, stop, tgt, local_server(day, (12, 30), NY), rates, "b6", fill)


def h_b7(sym, day, s, news, ccys, rates, fill):
    """XAUUSD overnight-to-cash transition at the COMEX open."""
    t0800, t0930, t0945 = local_server(day, (8, 0), NY), local_server(day, (9, 30), NY), local_server(day, (9, 45), NY)
    c0 = bar_at(sym.g15, t0800 - 900); c1 = bar_at(sym.g15, t0930 - 900); b = bar_at(sym.g15, t0930)
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
    d = dd if with_drift else -dd
    ref = bar_at(sym.g15, t0945)
    if ref is None:
        return "no_bars"
    stop = ref[0] - d * atr
    tgt = ref[0] + d * atr
    if news_skip(news, ccys, t0945):
        return "news_blocked"
    return simulate(sym, day, t0945, d, stop, tgt, local_server(day, (13, 30), NY), rates, "b7", fill)


def h_b8(sym, day, s, news, ccys, rates, fill):
    """FX London-NY overlap continuation of the London-session move."""
    t03, t12, t13, t1315 = (local_server(day, hm, NY) for hm in ((3, 0), (12, 0), (13, 0), (13, 15)))
    c03, c12 = bar_at(sym.g15, t03 - 900), bar_at(sym.g15, t12 - 900)
    if not (c03 and c12):
        return "no_bars"
    n = sym.day_index.get(day)
    if n is None or n < 14:
        return "no_atr"
    atr = sum(sym.sessions[sym.days[k]]["high"] - sym.sessions[sym.days[k]]["low"] for k in range(n - 14, n)) / 14.0
    move = c12[3] - c03[3]
    if atr <= 0 or abs(move) < 0.6 * atr:
        return "no_signal"
    d = 1 if move > 0 else -1
    w = sym.window(t12, t13)
    if not w:
        return "no_bars"
    retr = (c12[3] - w["low"]) if d > 0 else (w["high"] - c12[3])
    if retr > 0.38 * abs(move):
        return "no_signal"
    stop = w["low"] if d > 0 else w["high"]
    ref = bar_at(sym.g15, t1315)
    if ref is None:
        return "no_bars"
    dist = abs(ref[0] - stop)
    if dist <= 0:
        return "bad_stop"
    if news_skip(news, ccys, t1315):
        return "news_blocked"
    return simulate(sym, day, t1315, d, stop, ref[0] + d * dist, local_server(day, (16, 30), NY), rates, "b8", fill)


HFUN = {"H-B1": h_b1, "H-B2": h_b2, "H-B3": h_b3, "H-B4": h_b4, "H-B5": h_b5, "H-B6": h_b6, "H-B7": h_b7, "H-B8": h_b8}


# ----------------------------------------------------------------------------- statistics
def bootstrap_pass_prob(seq, rule, block=20, n_boot=200, seed=20260921):
    if len(seq) < (300 if rule == "SEL" else 30):
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
            s0 = rng.randrange(n)
            res.extend(c[(s0 + k) % n] for k in range(block))
        res = res[:n]
        e = sum(res) / n
        gw = sum(v for v in res if v > 0); gl = -sum(v for v in res if v < 0)
        pf = gw / gl if gl > 0 else float("inf")
        dd = F1.worst_year_dd(list(zip(dates, res)))
        if rule == "SEL":
            passes += 1 if (e >= SEL_RULE["E_R"] and pf >= SEL_RULE["PF"] and dd <= SEL_RULE["DD"]) else 0
        else:
            passes += 1 if (e > VAL_RULE["E_R"] and pf >= VAL_RULE["PF"]) else 0
    return passes / n_boot


def val_year_dd_ok(trades):
    by = defaultdict(list)
    for t in trades:
        if VAL[0] <= t["day"] <= VAL[1]:
            by[t["day"].year].append((t["day"], t["net_r"]))
    return all(F1.worst_year_dd(sorted(v)) <= VAL_RULE["DD_year"] for v in by.values()) if by else False


def run_symbol(args):
    symbol, hyps, news, conv, fill = args
    try:
        sym = Sym(symbol)
    except FileNotFoundError as exc:
        return symbol, {"error": f"no_m1_history: {exc}"}
    if not sym.m1:
        return symbol, {"error": "no_m1_history"}
    ccys = F1.symbol_news_currencies(symbol)
    out = {"structural_validation": F1.structural_check(sym.m1), "news_currencies": ccys, "cost_prior": {"spread_rt": sym.spread, "slip_rt": sym.slip, "tick": sym.tick, "source": sym.cost_src}, "cells": {}}
    for h in hyps:
        fn = HFUN[h]
        trades, states = [], defaultdict(int)
        for day in sym.days:
            if day < SEL[0] or day > VAL[1]:
                continue
            s = sym.sessions[day]
            rates = F1.usd_conversion(conv, s["open_t"])
            res = fn(sym, day, s, news, ccys, rates, fill)
            if isinstance(res, dict):
                trades.append(res); states["trade"] += 1
            else:
                states[res] += 1
        seq_sel = [(t["day"].isoformat(), round(t["net_r"], 6)) for t in trades if SEL[0] <= t["day"] <= SEL[1]]
        seq_val = [(t["day"].isoformat(), round(t["net_r"], 6)) for t in trades if VAL[0] <= t["day"] <= VAL[1]]
        s_stats, v_stats = F1.period_stats(trades, *SEL), F1.period_stats(trades, *VAL)
        p = bootstrap_pass_prob(seq_sel, "SEL")
        pv = bootstrap_pass_prob(seq_val, "VAL", seed=20260922) if p is not None else None
        sel_ok = (s_stats["trades"] >= SEL_RULE["n"] and s_stats.get("E_R", -9) >= SEL_RULE["E_R"] and (s_stats.get("PF") or 0) >= SEL_RULE["PF"]
                  and s_stats.get("worst_year_DD_R", 99) <= SEL_RULE["DD"] and s_stats.get("density_per_bd", 0) >= SEL_RULE["density"]
                  and p is not None and p <= SEL_RULE["chance"])
        val_ok = (v_stats["trades"] > 0 and v_stats.get("E_R", -9) > VAL_RULE["E_R"] and (v_stats.get("PF") or 0) >= VAL_RULE["PF"]
                  and s_stats.get("R_per_bd", 0) > 0 and v_stats.get("R_per_bd", -9) >= VAL_RULE["R_per_bd_share"] * s_stats.get("R_per_bd", 0)
                  and val_year_dd_ok(trades))
        out["cells"][h] = {"hypothesis": h, "symbol": symbol, "fill_model": fill, "day_states": dict(sorted(states.items())),
                           "selection": s_stats, "validation": v_stats, "chance_pass_prob_SEL": p, "chance_pass_prob_VAL": pv,
                           "passes_SEL_rule": bool(sel_ok), "passes_VAL_confirmation": bool(sel_ok and val_ok),
                           "state": ("WORTH_MT5_TEST" if (sel_ok and val_ok) else ("CLEAR_REJECT" if s_stats["trades"] >= 50 else "UNKNOWN")),
                           "sequence_sel": seq_sel, "sequence_val": seq_val}
    return symbol, out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hypotheses", default="ALL")
    ap.add_argument("--symbols", default="ALL")
    ap.add_argument("--fill-model", default="conservative", choices=["conservative", "v1"])
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--out", default=str(REPO / "docs/research/ftmo_shadow/velocity_family_f2_cash_session_0921.json"))
    a = ap.parse_args()
    hyps = list(HYPOTHESES) if a.hypotheses == "ALL" else a.hypotheses.split(",")
    per_symbol = defaultdict(list)
    for h in hyps:
        for s in HYPOTHESES[h]["symbols"]:
            if a.symbols == "ALL" or s in a.symbols.split(","):
                per_symbol[s].append(h)
    news = F1.load_news()
    conv = {}
    for pair in F1.USD_PAIRS:
        g = F1.aggregate(F1.load_m1(pair), 3600)
        keys = sorted(g)
        conv[pair] = (keys, [g[k][3] for k in keys])
    print(f"symbols {len(per_symbol)}; news currencies {len(news)}; conversion pairs {len(conv)}", file=sys.stderr)
    jobs = [(s, hs, news, conv, a.fill_model) for s, hs in sorted(per_symbol.items())]
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
            key = f"{h}|{sym}"
            cells[key] = {k: v for k, v in cell.items() if not k.startswith("sequence")}
            if cell["selection"]["trades"] > 0:
                n_cells += 1
            if cell["chance_pass_prob_SEL"] is not None:
                null_sum += cell["chance_pass_prob_SEL"]
            if cell["passes_VAL_confirmation"]:
                survivors.append({"hypothesis": h, "symbol": sym, "SEL": cell["selection"], "VAL": cell["validation"],
                                  "chance_pass_prob_SEL": cell["chance_pass_prob_SEL"], "chance_pass_prob_VAL": cell["chance_pass_prob_VAL"]})
    out = {"schema": "qm.velocity-family-f2-cash-session/v1", "registration": REGISTRATION,
           "script": "tools/strategy_farm/session_tools/velocity_family_f2_cash_session_0921.py",
           "reader": "tools/strategy_farm/session_tools/hcc_m1_reader_0921.py", "fill_model": a.fill_model,
           "execution_model": "closed-bar signals; market entry at next bar open +/- (spread+slip)/2; stop at worse of level and breaching bar open; target limit through by 1 tick; stop wins ties; flat at first bar at/after flat time; Friday 21:00 server cap; news blackout skips the day",
           "cost_priors": {s: {"spread_rt": v[0], "slip_rt": v[1], "tick": v[2], "source": v[3]} for s, v in COST_PRIOR.items()},
           "selection_period": [SEL[0].isoformat(), SEL[1].isoformat()], "validation_period": [VAL[0].isoformat(), VAL[1].isoformat()],
           "selection_rule": SEL_RULE, "validation_rule": VAL_RULE, "risk_fixed": RISK,
           "null": {"method": "centred circular block bootstrap (20 trades, 200 resamples) per cell; P(meets SEL rule by chance)", "cells_evaluated": n_cells,
                    "expected_false_SEL_survivors": round(null_sum, 4), "family_bonferroni_bar": SEL_RULE["chance"]},
           "observed": {"cells_passing_SEL_rule": sum(1 for c in cells.values() if c["passes_SEL_rule"]), "survivors_after_VAL": len(survivors)},
           "cells": cells, "survivors": survivors,
           "per_symbol": {s: {k: v for k, v in r.items() if k != "cells"} for s, r in results.items()},
           "sequences": {f"{h}|{s}": {"sel": r["cells"][h]["sequence_sel"], "val": r["cells"][h]["sequence_val"]} for s, r in results.items() if "cells" in r for h in r["cells"]}}
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_text(json.dumps(out, indent=1, sort_keys=True, default=str) + "\n", encoding="utf-8")
    print(json.dumps({"cells": n_cells, "SEL_pass": out["observed"]["cells_passing_SEL_rule"], "survivors": len(survivors), "expected_false": round(null_sum, 4), "out": a.out}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
