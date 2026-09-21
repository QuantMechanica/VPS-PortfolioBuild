#!/usr/bin/env python3
"""Track B family B3 prescreen: the Codex intake break-and-retest hypotheses BR1/BR2/BR3 with their paired controls
(Fable, 2026-09-21), run in the shared F2 conservative closed-bar execution engine (0 factory hours).

Pre-registration: ``docs/research/ftmo_intake/2026-09-21_br_nnfx/PLAN.md`` (Codex, cherry-picked ed3eef5a0d) section
"Three new Break & Retest hypotheses" + Track B programme doc section 10. Rules implemented verbatim where the PLAN states
them; two documented deviations: (1) ATR(14) is the simple 14-bar mean of the M5 true range (family-F1 convention,
MT5 iATR semantics), not Wilder smoothing; (2) "actual bid/ask" is the F2 per-symbol cost prior (spread + slippage
round trip) recorded per cell. Arms: BR1 retest with cross-index peer confirmation vs control without peer; BR2 retest
after a compressed overnight range vs control without the compression filter; BR3 retest package vs control that enters
at the next open after the breakout with a 1 ATR stop and 1.5 R target. One entry per symbol per day; no re-arm.
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
NY, LON = ZoneInfo("America/New_York"), ZoneInfo("Europe/London")
SEL, VAL = F1.SEL, F1.VAL
REGISTRATION = "docs/research/ftmo_intake/2026-09-21_br_nnfx/PLAN.md"
F2.COST_PRIOR.setdefault("XAGUSD.DWX", (0.025, 0.010, 0.001, "prior: FTMO XAGUSD ~2.5 cents RT"))
F2.COST_PRIOR.setdefault("USDJPY.DWX", (0.010, 0.005, 0.001, "prior: 1.0 pip RT"))
F2.CASH.setdefault("XAGUSD.DWX", (NY, (9, 30), (16, 0)))
F2.CASH.setdefault("USDJPY.DWX", (NY, (9, 30), (16, 0)))
F2.CASH.setdefault("EURUSD.DWX", (NY, (9, 30), (16, 0)))
F2.CASH.setdefault("GBPUSD.DWX", (NY, (9, 30), (16, 0)))
F2.CASH.setdefault("XAUUSD.DWX", (NY, (9, 30), (16, 0)))

BR = {
    "BR1": {"symbols": ["NDX.DWX", "SP500.DWX", "WS30.DWX"], "range": (NY, (9, 30), (9, 45)), "entry": (NY, (9, 45), (11, 30)), "flat": (NY, (15, 45)),
            "peer": {"NDX.DWX": "SP500.DWX", "WS30.DWX": "SP500.DWX", "SP500.DWX": "NDX.DWX"}, "arms": ["retest_peer", "retest_nopeer"]},
    "BR2": {"symbols": ["EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX"], "range": (LON, (0, 0), (7, 0)), "entry": (LON, (8, 0), (10, 30)), "flat": (LON, (12, 0)),
            "arms": ["retest_compressed", "retest_any"]},
    "BR3": {"symbols": ["XAUUSD.DWX", "XAGUSD.DWX"], "range": (LON, (8, 0), (12, 0)), "entry": (NY, (8, 0), (11, 0)), "flat": (NY, (13, 0)),
            "arms": ["retest", "direct_breakout"]},
}
SEL_RULE, VAL_RULE = F2.SEL_RULE, F2.VAL_RULE


def atr5(sym: F2.Sym):
    if not hasattr(sym, "atr5"):
        _, sym.atr5 = F1.sma_atr(sym.g5)
    return sym.atr5


def range_window(sym, day, spec):
    tz, a, b = spec
    t0, t1 = F2.local_server(day, a, tz), F2.local_server(day, b, tz)
    w = sym.window(t0, t1)
    return (t0, t1, w) if w and w["n"] >= max(3, (t1 - t0) // 60 // 4) else (t0, t1, None)


def peer_outside(peer_sym, day, t_close, direction, spec):
    """Peer must have a completed M5 close outside its own OR in the same direction at/before t_close."""
    t0, t1, w = range_window(peer_sym, day, spec)
    if not w:
        return False
    t = t1
    while t + 300 <= t_close:
        b = F2.bar_at(peer_sym.g5, t)
        if b and ((direction > 0 and b[3] > w["high"]) or (direction < 0 and b[3] < w["low"])):
            return True
        t += 300
    return False


def run_cell(sym, hyp, arm, day, news, ccys, rates, peers, fill):
    spec = BR[hyp]
    rt0, rt1, rw = range_window(sym, day, spec["range"])
    if not rw:
        return "no_range"
    etz, ea, eb = spec["entry"]
    e0, e1 = F2.local_server(day, ea, etz), F2.local_server(day, eb, etz)
    flat = F2.local_server(day, spec["flat"][1], spec["flat"][0])
    if e0 < rt1:
        e0 = rt1
    if arm == "retest_compressed":
        n = sym.day_index.get(day)
        if n is None or n < 20:
            return "no_history"
        hist = []
        for k in range(n - 20, n):
            _, _, hw = range_window(sym, sym.days[k], spec["range"])
            if hw:
                hist.append(hw["high"] - hw["low"])
        if len(hist) < 15:
            return "no_history"
        hist.sort()
        med = hist[len(hist) // 2]
        if rw["high"] - rw["low"] > med:
            return "not_compressed"
    atr_map = atr5(sym)
    hi, lo = rw["high"], rw["low"]
    t = e0
    armed = None  # (direction, level, atr, breakout_t)
    while t + 300 <= e1 or (armed and t + 300 <= e1 + 6 * 300):
        b = F2.bar_at(sym.g5, t)
        if b is None:
            t += 300
            continue
        prev = F2.bar_at(sym.g5, t - 300)
        a = atr_map.get(t - 300)
        if a is None or a <= 0:
            t += 300
            continue
        if armed is None:
            if t + 300 > e1:
                break
            if prev and b[3] > hi + 0.10 * a and prev[3] <= hi + 0.10 * a:
                armed = (1, hi, a, t)
            elif prev and b[3] < lo - 0.10 * a and prev[3] >= lo - 0.10 * a:
                armed = (-1, lo, a, t)
            if armed and arm == "direct_breakout":
                d, lvl, a0, _ = armed
                entry_t = t + 300
                ref = F2.bar_at(sym.g5, entry_t)
                if ref is None or entry_t >= e1 + 300:
                    return "no_bars"
                if F2.news_skip(news, ccys, entry_t):
                    return "news_blocked"
                return F2.simulate(sym, day, entry_t, d, ref[0] - d * a0, ref[0] + d * 1.5 * a0, flat, rates, f"{hyp}_{arm}", fill)
            t += 300
            continue
        d, lvl, a0, bt = armed
        if t > bt + 6 * 300:
            return "retest_expired"
        # invalidation: a close more than 0.25 ATR through the wrong side
        if (d > 0 and b[3] < lvl - 0.25 * a0) or (d < 0 and b[3] > lvl + 0.25 * a0):
            return "invalidated"
        touch = (d > 0 and b[2] <= lvl + 0.10 * a0 and b[2] >= lvl - 0.25 * a0 and b[3] > lvl and b[3] > b[0]) or \
                (d < 0 and b[1] >= lvl - 0.10 * a0 and b[1] <= lvl + 0.25 * a0 and b[3] < lvl and b[3] < b[0])
        if touch and t > bt:
            if arm == "retest_peer":
                p = peers.get(sym.symbol)
                if p is None or not peer_outside(p, day, t + 300, d, spec["range"]):
                    return "peer_unconfirmed"
            entry_t = t + 300
            ref = F2.bar_at(sym.g5, entry_t)
            if ref is None:
                return "no_bars"
            if entry_t > e1 + 300:
                return "window_expired"
            if abs(ref[0] - b[3]) > 0.50 * a0:
                return "entry_too_far"
            ext = b[2] if d > 0 else b[1]
            stop = ext - d * 0.10 * a0
            dist = abs(ref[0] - stop)
            if dist < 0.50 * a0:
                stop = ref[0] - d * 0.50 * a0
                dist = 0.50 * a0
            if dist > 1.50 * a0:
                return "stop_too_wide"
            if (d > 0 and ref[0] <= stop) or (d < 0 and ref[0] >= stop):
                return "stop_crossed"
            if F2.news_skip(news, ccys, entry_t):
                return "news_blocked"
            tr = F2.simulate(sym, day, entry_t, d, stop, ref[0] + d * 1.5 * dist, flat, rates, f"{hyp}_{arm}", fill)
            if isinstance(tr, dict):
                # exit on the first completed M5 close back through the broken level (next open), if earlier than the engine exit
                tt = entry_t
                while tt < tr["exit_t"]:
                    bb = F2.bar_at(sym.g5, tt)
                    if bb and ((d > 0 and bb[3] < lvl) or (d < 0 and bb[3] > lvl)):
                        nxt = F2.idx_at(sym.times, tt + 300)
                        if nxt < len(sym.times) and sym.times[nxt] < tr["exit_t"]:
                            px = sym.m1[nxt][1] - d * sym.half
                            gross = d * (px - tr["entry"]) / tr["w"]
                            tr.update({"exit": px, "gross_r": gross, "net_r": gross - tr["cost_r"], "exit_kind": "level_reclaim", "exit_t": sym.times[nxt],
                                       "hold_min": (sym.times[nxt] - tr["fill_t"]) / 60.0})
                        break
                    tt += 300
            return tr
        t += 300
    return "no_signal" if armed is None else "retest_expired"


def run_symbol(args):
    symbol, jobs, news, conv, fill, peer_symbols = args
    try:
        sym = F2.Sym(symbol)
    except FileNotFoundError as exc:
        return symbol, {"error": f"no_m1_history: {exc}"}
    peers = {}
    for ps in peer_symbols:
        try:
            peers[symbol] = F2.Sym(ps) if ps else None
        except FileNotFoundError:
            peers[symbol] = None
    ccys = F1.symbol_news_currencies(symbol)
    out = {"structural_validation": F1.structural_check(sym.m1), "news_currencies": ccys, "cost_prior": dict(zip(("spread_rt", "slip_rt", "tick", "source"), F2.COST_PRIOR[symbol])), "cells": {}}
    for hyp, arm in jobs:
        trades, states = [], defaultdict(int)
        for day in sym.days:
            if day < SEL[0] or day > VAL[1]:
                continue
            rates = F1.usd_conversion(conv, sym.sessions[day]["open_t"])
            res = run_cell(sym, hyp, arm, day, news, ccys, rates, peers, fill)
            if isinstance(res, dict):
                trades.append(res); states["trade"] += 1
            else:
                states[res] += 1
        seq_sel = [(t["day"].isoformat(), round(t["net_r"], 6)) for t in trades if SEL[0] <= t["day"] <= SEL[1]]
        seq_val = [(t["day"].isoformat(), round(t["net_r"], 6)) for t in trades if VAL[0] <= t["day"] <= VAL[1]]
        s_stats, v_stats = F1.period_stats(trades, *SEL), F1.period_stats(trades, *VAL)
        p = F2.bootstrap_pass_prob(seq_sel, "SEL")
        pv = F2.bootstrap_pass_prob(seq_val, "VAL", seed=20260922) if p is not None else None
        sel_ok = (s_stats["trades"] >= SEL_RULE["n"] and s_stats.get("E_R", -9) >= SEL_RULE["E_R"] and (s_stats.get("PF") or 0) >= SEL_RULE["PF"]
                  and s_stats.get("worst_year_DD_R", 99) <= SEL_RULE["DD"] and s_stats.get("density_per_bd", 0) >= SEL_RULE["density"]
                  and p is not None and p <= 0.05 / 16)
        val_ok = (v_stats["trades"] > 0 and v_stats.get("E_R", -9) > VAL_RULE["E_R"] and (v_stats.get("PF") or 0) >= VAL_RULE["PF"]
                  and s_stats.get("R_per_bd", 0) > 0 and v_stats.get("R_per_bd", -9) >= VAL_RULE["R_per_bd_share"] * s_stats.get("R_per_bd", 0)
                  and F2.val_year_dd_ok(trades))
        out["cells"][f"{hyp}|{arm}"] = {"hypothesis": hyp, "arm": arm, "symbol": symbol, "fill_model": fill, "day_states": dict(sorted(states.items())),
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
    ap.add_argument("--out", default=str(REPO / "docs/research/ftmo_intake/2026-09-21_br_nnfx/results/velocity_family_f3_break_retest_0921.json"))
    a = ap.parse_args()
    hyps = list(BR) if a.hypotheses == "ALL" else a.hypotheses.split(",")
    per_symbol, peer_of = defaultdict(list), {}
    for h in hyps:
        for s in BR[h]["symbols"]:
            for arm in BR[h]["arms"]:
                per_symbol[s].append((h, arm))
            if "peer" in BR[h]:
                peer_of[s] = BR[h]["peer"].get(s)
    news = F1.load_news()
    conv = {}
    for pair in F1.USD_PAIRS:
        g = F1.aggregate(F1.load_m1(pair), 3600)
        keys = sorted(g)
        conv[pair] = (keys, [g[k][3] for k in keys])
    jobs = [(s, cells, news, conv, a.fill_model, [peer_of.get(s)] if peer_of.get(s) else []) for s, cells in sorted(per_symbol.items())]
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
        for key, cell in res["cells"].items():
            cells[f"{key}|{sym}"] = {k: v for k, v in cell.items() if not k.startswith("sequence")}
            if cell["selection"]["trades"] > 0:
                n_cells += 1
            if cell["chance_pass_prob_SEL"] is not None:
                null_sum += cell["chance_pass_prob_SEL"]
            if cell["passes_VAL_confirmation"]:
                survivors.append({"cell": f"{key}|{sym}", "SEL": cell["selection"], "VAL": cell["validation"]})
    out = {"schema": "qm.velocity-family-f3-break-retest/v1", "registration": REGISTRATION, "programme": "FTMO_BR_NNFX_20260921 / Track B family B3",
           "script": "tools/strategy_farm/session_tools/velocity_family_f3_break_retest_0921.py", "engine": "velocity_family_f2_cash_session_0921.py (conservative closed-bar fills)",
           "deviations": ["ATR(14) = simple 14-bar mean of the M5 true range (MT5 iATR semantics), not Wilder", "bid/ask = per-symbol cost prior (spread + slippage round trip)"],
           "fill_model": a.fill_model, "cost_priors": {s: dict(zip(("spread_rt", "slip_rt", "tick", "source"), F2.COST_PRIOR[s])) for s in per_symbol},
           "selection_period": [SEL[0].isoformat(), SEL[1].isoformat()], "validation_period": [VAL[0].isoformat(), VAL[1].isoformat()],
           "selection_rule": dict(SEL_RULE, chance=round(0.05 / 16, 5)), "validation_rule": VAL_RULE,
           "null": {"cells_evaluated": n_cells, "expected_false_SEL_survivors": round(null_sum, 4), "family_bonferroni_bar": round(0.05 / 16, 5)},
           "observed": {"cells_passing_SEL_rule": sum(1 for c in cells.values() if c["passes_SEL_rule"]), "survivors_after_VAL": len(survivors)},
           "cells": cells, "survivors": survivors,
           "sequences": {f"{k}|{s}": {"sel": r["cells"][k]["sequence_sel"], "val": r["cells"][k]["sequence_val"]} for s, r in results.items() if "cells" in r for k in r["cells"]}}
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_text(json.dumps(out, indent=1, sort_keys=True, default=str) + "\n", encoding="utf-8")
    print(json.dumps({"cells": n_cells, "SEL_pass": out["observed"]["cells_passing_SEL_rule"], "survivors": len(survivors), "expected_false": round(null_sum, 4), "out": a.out}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
