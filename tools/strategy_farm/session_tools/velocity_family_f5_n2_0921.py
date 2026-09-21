#!/usr/bin/env python3
"""Track C family C1 prescreen (Fable, 2026-09-21): the NNFX-inspired N2 experiment pre-registered by Antigravity in
``docs/research/ftmo_intake/2026-09-21_br_nnfx/results/N-GAPS.md`` section 5 — McGinley(14) baseline + SSL(10) trigger + WAE
volume gate on H1 closed bars, paired arms H1_SESSION_FLAT (entries at hourly opens 09:00-16:00 London, flat 17:00 London) vs
H1_ALL_HOURS (24 h, held across days, financing charged), 4 symbols x 2 arms = 8 cells, 0 factory hours.

Execution: H1 closed-bar signals (evaluated at the next hourly open), market entry at the next M1 open +/- (spread+slip)/2, initial
stop 1.5 x ATR(14,H1)[1] from fill, TP1 at 1.0 x ATR for 50 % of the position (limit through by one tick), residual stop to entry
after TP1, runner exit at the next open after a closed H1 bar with the opposite SSL state; stops filled at the worse of level and
breaching M1 open; max 1 open position per symbol, max 2 entries per symbol per calendar day; framework news blackout skips an entry
hour; Friday 21:00 server close caps the all-hours arm. Financing (all-hours arm only) = the 2026-09-18 financing_lib variant ``fin``
(nights x rate) charged per trade in USD at RISK_FIXED 1000 sizing. R = net / 1000 (two legs summed). Same SEL/VAL split and pass
rule as families B1-B3 (family bar 0.05/8). Deviation: ATR(14,H1) = simple 14-bar mean of the H1 true range (MT5 iATR semantics).
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
LON = ZoneInfo("Europe/London")
SEL, VAL, RISK = F1.SEL, F1.VAL, F1.RISK
REGISTRATION = "docs/research/ftmo_intake/2026-09-21_br_nnfx/results/N-GAPS.md section 5 (N2)"
FIN_LIB = Path(r"D:/QM/reports/book_evolution/2026-W38/ftmo/fable_alt_rosters_20260918/swap")
SYMBOLS = ["EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "XAUUSD.DWX"]
ARMS = ["H1_SESSION_FLAT", "H1_ALL_HOURS"]
N_CELLS = 8
F2.COST_PRIOR.setdefault("USDJPY.DWX", (0.010, 0.005, 0.001, "prior: 1.0 pip RT"))
POINT = {"EURUSD.DWX": 0.00001, "GBPUSD.DWX": 0.00001, "USDJPY.DWX": 0.001, "XAUUSD.DWX": 0.01}


def load_fin():
    sys.path.insert(0, str(FIN_LIB))
    import financing_lib as F  # noqa: E402
    return F


def indicators(g60keys, g60):
    """McGinley(14), SSL(10) state, WAE momentum/threshold, ATR(14) keyed by H1 bar start; all from CLOSED bars."""
    closes = [g60[k][3] for k in g60keys]
    highs = [g60[k][1] for k in g60keys]
    lows = [g60[k][2] for k in g60keys]
    n = len(closes)
    md = [None] * n
    for i in range(n):
        if i == 0:
            md[i] = closes[i]
        else:
            prev = md[i - 1]
            ratio = closes[i] / prev if prev else 1.0
            md[i] = prev + (closes[i] - prev) / (14.0 * (ratio ** 4)) if ratio > 0 else prev
    ssl = [0] * n
    for i in range(n):
        if i >= 9:
            hs = sum(highs[i - 9:i + 1]) / 10.0
            ls_ = sum(lows[i - 9:i + 1]) / 10.0
            ssl[i] = 1 if closes[i] > hs else (-1 if closes[i] < ls_ else ssl[i - 1])
    def ema(vals, p):
        out = [None] * len(vals); k = 2.0 / (p + 1)
        for i, v in enumerate(vals):
            out[i] = v if i == 0 else out[i - 1] + k * (v - out[i - 1])
        return out
    e12, e26 = ema(closes, 12), ema(closes, 26)
    macd = [a - b for a, b in zip(e12, e26)]
    mom = [None] * n; thr = [None] * n
    for i in range(n):
        if i >= 20:
            win = closes[i - 19:i + 1]
            m = sum(win) / 20.0
            sd = (sum((x - m) ** 2 for x in win) / 20.0) ** 0.5
            expl = abs((m + 2 * sd) - (m - 2 * sd))
            thr[i] = expl
            if i >= 1:
                mom[i] = (macd[i] - macd[i - 1]) * 150.0
    _, atr = F1.sma_atr(g60)
    return {"md": md, "ssl": ssl, "mom": mom, "thr": thr, "atr": atr, "closes": closes, "keys": g60keys}


def simulate_n2(sym, day, entry_t, d, atr, arm, ind, idx_by_key, news, ccys, rates, fin):
    """Two-leg trade with TP1 50 % at 1 ATR, BE on the runner, SSL-flip exit, conservative fills."""
    fri = F1.friday_close_epoch(entry_t)
    flat = F2.local_server(day, (17, 0), LON) if arm == "H1_SESSION_FLAT" else None
    hard_end = min([t for t in (flat, fri) if t]) if (flat or fri) else None
    times, m1 = sym.times, sym.m1
    j = F2.idx_at(times, entry_t)
    if j >= len(times) or (hard_end and times[j] >= hard_end):
        return "no_bars"
    if times[j] - entry_t > 900:
        return "gap_at_entry"
    half = sym.half
    entry = m1[j][1] + d * half
    stop_dist = 1.5 * atr
    if stop_dist < F2.MIN_STOP_SPREADS * sym.spread:
        return "stop_too_tight"
    stop = entry - d * stop_dist
    tp1 = entry + d * 1.0 * atr
    lots, nl = F1.lot_and_notional(sym.symbol, entry, stop_dist, rates)
    cost = F1.commission_r(sym.symbol, lots, nl)
    jj = j
    leg1_done = False
    exit_px = kind = exit_t = None
    # runner exit on SSL flip: check at each H1 bar boundary (closed bar) -> exit at the next M1 open
    while True:
        if jj >= len(times):
            exit_px, kind, exit_t = m1[jj - 1][4], "data_end", times[jj - 1]; break
        t, bo, bh, bl, bc = m1[jj]
        if hard_end and t >= hard_end:
            exit_px, kind, exit_t = bo - d * half, ("friday_close" if fri and hard_end == fri else "flat"), t; break
        if t % 3600 == 0 and t > entry_t:
            k = t - 3600  # the H1 bar that just closed
            i = idx_by_key.get(k)
            if i is not None and ind["ssl"][i] == -d:
                exit_px, kind, exit_t = bo - d * half, "ssl_flip", t; break
        if d > 0:
            if bl <= stop:
                exit_px, kind, exit_t = min(stop, bo) - half, ("stop" if not leg1_done else "be_stop"), t; break
            if not leg1_done and bh >= tp1 + sym.tick:
                leg1_done = True; stop = entry
        else:
            if bh >= stop:
                exit_px, kind, exit_t = max(stop, bo) + half, ("stop" if not leg1_done else "be_stop"), t; break
            if not leg1_done and bl <= tp1 - sym.tick:
                leg1_done = True; stop = entry
        jj += 1
    r_leg1 = 0.5 * (d * (tp1 - entry) / stop_dist) if leg1_done else 0.0
    r_leg2 = (0.5 if leg1_done else 1.0) * (d * (exit_px - entry) / stop_dist)
    gross = r_leg1 + r_leg2
    fin_r = 0.0
    if arm == "H1_ALL_HOURS" and fin is not None:
        row = {"entry_time": times[j], "time": exit_t, "side": "BUY" if d > 0 else "SELL", "volume": lots, "net": 0.0, "entry_price": entry, "exit_price": exit_px}
        try:
            f = fin.finance_trade(row, sym.symbol, "fin")
            fin_r = float(f.get("financing_usd") or 0.0) / RISK
        except Exception:
            fin_r = 0.0
    return {"day": day, "dir": d, "entry": entry, "exit": exit_px, "gross_r": gross, "cost_r": cost - fin_r, "net_r": gross - cost + fin_r,
            "hold_min": (exit_t - times[j]) / 60.0, "exit_kind": kind, "w": stop_dist, "fill_t": times[j], "exit_t": exit_t, "tp1": leg1_done}


def run_symbol(args):
    symbol, news, conv, fin_enabled = args
    try:
        sym = F2.Sym(symbol)
    except FileNotFoundError as exc:
        return symbol, {"error": f"no_m1_history: {exc}"}
    fin = load_fin() if fin_enabled else None
    ccys = F1.symbol_news_currencies(symbol)
    keys = sorted(sym.g60)
    ind = indicators(keys, sym.g60)
    idx_by_key = {k: i for i, k in enumerate(keys)}
    out = {"structural_validation": F1.structural_check(sym.m1), "news_currencies": ccys, "cost_prior": dict(zip(("spread_rt", "slip_rt", "tick", "source"), F2.COST_PRIOR[symbol])), "cells": {}}
    for arm in ARMS:
        trades, states = [], defaultdict(int)
        open_until = 0
        entries_day = defaultdict(int)
        for i, k in enumerate(keys):
            if i < 150:
                continue
            bar_open = k + 3600  # the hourly open after the closed bar k
            day_lon = dt.datetime.fromtimestamp(F1.utc_from_server(bar_open), dt.timezone.utc).astimezone(LON)
            day = day_lon.date()
            if day < SEL[0] or day > VAL[1] or day.weekday() >= 5:
                continue
            if arm == "H1_SESSION_FLAT" and not (9 <= day_lon.hour <= 16):
                states["outside_window"] += 1; continue
            if bar_open < open_until:
                states["position_open"] += 1; continue
            if entries_day[day] >= 2:
                states["day_cap"] += 1; continue
            md, ssl, mom, thr, atr = ind["md"][i], ind["ssl"][i], ind["mom"][i], ind["thr"][i], ind["atr"].get(k)
            c = ind["closes"][i]
            if md is None or mom is None or thr is None or atr is None or atr <= 0:
                states["warmup"] += 1; continue
            prev_ssl = ind["ssl"][i - 1]
            if ssl == 0 or ssl == prev_ssl:
                states["no_signal"] += 1; continue  # trigger = transition into alignment on the closed bar
            d = ssl
            if (d > 0 and not (c > md)) or (d < 0 and not (c < md)):
                states["baseline_misaligned"] += 1; continue
            if abs(c - md) > 1.0 * atr:
                states["proximity_fail"] += 1; continue
            deadzone = 150.0 * POINT[symbol]
            if abs(mom) <= max(thr, deadzone):
                states["wae_gate"] += 1; continue
            if F2.news_skip(news, ccys, bar_open):
                states["news_blocked"] += 1; continue
            rates = F1.usd_conversion(conv, bar_open)
            res = simulate_n2(sym, day, bar_open, d, atr, arm, ind, idx_by_key, news, ccys, rates, fin)
            if isinstance(res, dict):
                trades.append(res); states["trade"] += 1; entries_day[day] += 1; open_until = res["exit_t"]
            else:
                states[res] += 1
        seq_sel = [(t["day"].isoformat(), round(t["net_r"], 6)) for t in trades if SEL[0] <= t["day"] <= SEL[1]]
        seq_val = [(t["day"].isoformat(), round(t["net_r"], 6)) for t in trades if VAL[0] <= t["day"] <= VAL[1]]
        s_stats, v_stats = F1.period_stats(trades, *SEL), F1.period_stats(trades, *VAL)
        p = F2.bootstrap_pass_prob(seq_sel, "SEL")
        pv = F2.bootstrap_pass_prob(seq_val, "VAL", seed=20260922) if p is not None else None
        rule = dict(F2.SEL_RULE, chance=0.05 / N_CELLS)
        sel_ok = (s_stats["trades"] >= rule["n"] and s_stats.get("E_R", -9) >= rule["E_R"] and (s_stats.get("PF") or 0) >= rule["PF"]
                  and s_stats.get("worst_year_DD_R", 99) <= rule["DD"] and s_stats.get("density_per_bd", 0) >= rule["density"]
                  and p is not None and p <= rule["chance"])
        val_ok = (v_stats["trades"] > 0 and v_stats.get("E_R", -9) > F2.VAL_RULE["E_R"] and (v_stats.get("PF") or 0) >= F2.VAL_RULE["PF"]
                  and s_stats.get("R_per_bd", 0) > 0 and v_stats.get("R_per_bd", -9) >= F2.VAL_RULE["R_per_bd_share"] * s_stats.get("R_per_bd", 0)
                  and F2.val_year_dd_ok(trades))
        out["cells"][arm] = {"arm": arm, "symbol": symbol, "day_states": dict(sorted(states.items())), "tp1_share": round(sum(1 for t in trades if t["tp1"]) / len(trades), 3) if trades else None,
                             "selection": s_stats, "validation": v_stats, "chance_pass_prob_SEL": p, "chance_pass_prob_VAL": pv,
                             "passes_SEL_rule": bool(sel_ok), "passes_VAL_confirmation": bool(sel_ok and val_ok),
                             "state": ("WORTH_MT5_TEST" if (sel_ok and val_ok) else ("CLEAR_REJECT" if s_stats["trades"] >= 50 else "UNKNOWN")),
                             "sequence_sel": seq_sel, "sequence_val": seq_val}
    return symbol, out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--symbols", default="ALL")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--no-financing", action="store_true")
    ap.add_argument("--out", default=str(REPO / "docs/research/ftmo_intake/2026-09-21_br_nnfx/results/velocity_family_f5_n2_0921.json"))
    a = ap.parse_args()
    symbols = SYMBOLS if a.symbols == "ALL" else a.symbols.split(",")
    news = F1.load_news()
    conv = {}
    for pair in F1.USD_PAIRS:
        g = F1.aggregate(F1.load_m1(pair), 3600)
        keys = sorted(g)
        conv[pair] = (keys, [g[k][3] for k in keys])
    jobs = [(s, news, conv, not a.no_financing) for s in symbols]
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
        for arm, cell in res["cells"].items():
            cells[f"N2|{arm}|{sym}"] = {k: v for k, v in cell.items() if not k.startswith("sequence")}
            if cell["selection"]["trades"] > 0:
                n_cells += 1
            if cell["chance_pass_prob_SEL"] is not None:
                null_sum += cell["chance_pass_prob_SEL"]
            if cell["passes_VAL_confirmation"]:
                survivors.append({"cell": f"N2|{arm}|{sym}", "SEL": cell["selection"], "VAL": cell["validation"]})
    out = {"schema": "qm.velocity-family-f5-n2/v1", "registration": REGISTRATION, "programme": "FTMO_BR_NNFX_20260921 N2 / Track C family C1",
           "script": "tools/strategy_farm/session_tools/velocity_family_f5_n2_0921.py", "engine": "F2 conservative closed-bar fills; two-leg TP1/BE runner; SSL-flip exit",
           "financing": "H1_ALL_HOURS arm charged with financing_lib variant fin (2026-09-18 rate table); session-flat arm 0 by construction",
           "cost_priors": {s: dict(zip(("spread_rt", "slip_rt", "tick", "source"), F2.COST_PRIOR[s])) for s in symbols},
           "selection_period": [SEL[0].isoformat(), SEL[1].isoformat()], "validation_period": [VAL[0].isoformat(), VAL[1].isoformat()],
           "selection_rule": dict(F2.SEL_RULE, chance=round(0.05 / N_CELLS, 5)), "validation_rule": F2.VAL_RULE,
           "null": {"cells_evaluated": n_cells, "expected_false_SEL_survivors": round(null_sum, 4), "family_bonferroni_bar": round(0.05 / N_CELLS, 5)},
           "observed": {"cells_passing_SEL_rule": sum(1 for c in cells.values() if c["passes_SEL_rule"]), "survivors_after_VAL": len(survivors)},
           "cells": cells, "survivors": survivors,
           "sequences": {f"N2|{arm}|{s}": {"sel": r["cells"][arm]["sequence_sel"], "val": r["cells"][arm]["sequence_val"]} for s, r in results.items() if "cells" in r for arm in r["cells"]}}
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_text(json.dumps(out, indent=1, sort_keys=True, default=str) + "\n", encoding="utf-8")
    print(json.dumps({"cells": n_cells, "SEL_pass": out["observed"]["cells_passing_SEL_rule"], "survivors": len(survivors), "expected_false": round(null_sum, 4), "out": a.out}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
