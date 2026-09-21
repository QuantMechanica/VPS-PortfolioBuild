#!/usr/bin/env python3
"""Track B family B4 prescreen: the Antigravity cross-symbol / multi-condition hypotheses (task 7636afc9) that survived their own
adversarial attack -- H-CS01, H-CS02, H-CS05, H-CS07, H-CS09, H-CS10, H-CS12 -- each with a pre-registered control arm, run in the
shared F2 conservative closed-bar execution engine (Fable, 2026-09-21, 0 factory hours).

Pre-registration: ``docs/research/ftmo_shadow/TRACK_B_EDGE_DISCOVERY_PROGRAMME_2026-09-21.md`` section "B4 pre-registration"
(committed before this ran); hypothesis text: ``docs/research/ftmo_shadow/agy_cross_symbol_hypotheses_7636afc9.md``.

Resolutions of the source text (recorded, not silently chosen): (1) entries are MARKET orders at the open of the first bar after
the last closed bar the rule reads (the source alternates between "10:15" and "10:30" for the same rule); (2) D1 ATR(14) =
mean of the previous 14 full server-day ranges (family-F4 helper), H1 ATR(14) = simple 14-bar mean of the H1 true range;
(3) H-CS02's breakeven trail is NOT modelled (engine has fixed stop/target/time exits) -- a documented deviation; (4) H-CS10
delays the entry to 09:00 ET on 08:30 release days instead of skipping (the source's mandatory blackout condition); (5) the
stop floor of each rule is applied as max(rule floor, 5 x round-trip spread) by the engine. Control arms: "noref" removes the
reference-symbol condition and trades the execution-symbol trigger alone; H-CS07 "fade" trades against the London drift (the
source's must-lose falsification); H-CS12 "self" replaces the oil impulse by the USDCAD's own 09:00-10:00 impulse.
"""
from __future__ import annotations
import argparse
import json
import sys
from collections import defaultdict
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from zoneinfo import ZoneInfo
sys.path.insert(0, str(Path(__file__).resolve().parent))
import velocity_family_f1_sweep_0921 as F1  # noqa: E402
import velocity_family_f2_cash_session_0921 as F2  # noqa: E402
import velocity_family_f4_b2_0921 as F4  # noqa: E402

REPO = Path("C:/QM/repo")
NY = ZoneInfo("America/New_York")
SEL, VAL = F1.SEL, F1.VAL
REGISTRATION = "docs/research/ftmo_shadow/TRACK_B_EDGE_DISCOVERY_PROGRAMME_2026-09-21.md"
SOURCE = "docs/research/ftmo_shadow/agy_cross_symbol_hypotheses_7636afc9.md"
F2.COST_PRIOR.setdefault("XAGUSD.DWX", (0.025, 0.010, 0.001, "prior: FTMO XAGUSD ~2.5 cents RT (reference only)"))
F2.COST_PRIOR.setdefault("USDJPY.DWX", (0.010, 0.005, 0.001, "prior: 1.0 pip RT"))
F2.COST_PRIOR.setdefault("USDCAD.DWX", (0.00015, 0.00007, 0.00001, "prior: 1.5 pip RT"))
F2.COST_PRIOR.setdefault("XTIUSD.DWX", (0.03, 0.01, 0.01, "prior: FTMO USOIL ~3 cents RT (reference only)"))
for _s in ("XAGUSD.DWX", "USDJPY.DWX", "EURUSD.DWX", "GBPUSD.DWX", "XAUUSD.DWX", "USDCAD.DWX", "XTIUSD.DWX"):
    F2.CASH.setdefault(_s, (NY, (9, 30), (16, 0)))

HYP = {
    "H-CS01": {"exec": "SP500.DWX", "refs": ["GDAXI.DWX"], "arms": ["ref", "noref"], "label": "DAX afternoon trend -> SP500 first-bar continuation"},
    "H-CS02": {"exec": "NDX.DWX", "refs": ["SP500.DWX"], "arms": ["ref", "noref"], "label": "SP500 IB break confirms NDX IB break"},
    "H-CS05": {"exec": "XAUUSD.DWX", "refs": ["XAGUSD.DWX"], "arms": ["ref", "noref"], "label": "silver lead confirms gold COMEX-open range break"},
    "H-CS07": {"exec": "XAUUSD.DWX", "refs": [], "arms": ["with", "fade"], "label": "London-fix drift continuation into COMEX"},
    "H-CS09": {"exec": "USDJPY.DWX", "refs": ["SP500.DWX"], "arms": ["ref", "noref"], "label": "SP500 IB impulse -> USDJPY momentum"},
    "H-CS10": {"exec": "EURUSD.DWX", "refs": ["GBPUSD.DWX"], "arms": ["ref", "noref"], "label": "GBPUSD-aligned London trend -> EURUSD NY continuation"},
    "H-CS12": {"exec": "USDCAD.DWX", "refs": ["XTIUSD.DWX"], "arms": ["ref", "self"], "label": "WTI 09:00-10:00 impulse -> USDCAD inverse"},
}
N_CELLS = sum(len(h["arms"]) for h in HYP.values())
CHANCE_BAR = round(0.05 / N_CELLS, 5)
SEL_RULE, VAL_RULE = F2.SEL_RULE, F2.VAL_RULE


def ls(day, hm):
    return F2.local_server(day, hm, NY)


def m15(sym, t):
    return F2.bar_at(sym.g15, t)


def sgn(x):
    return 1 if x > 0 else (-1 if x < 0 else 0)


def body_share(b):
    r = b[1] - b[2]
    return abs(b[3] - b[0]) / r if r > 0 else 0.0


def sma15(sym, t_end, n=20):
    closes = []
    for k in range(1, n + 1):
        b = m15(sym, t_end - 900 * k)
        if b is None:
            return None
        closes.append(b[3])
    return sum(closes) / n


def go(ex, day, entry_t, d, dist, rr, flat_t, news, ccys, rates, tag, fill):
    ref_bar = m15(ex, entry_t)
    if ref_bar is None:
        return "no_bars"
    o = ref_bar[0]
    if F2.news_skip(news, ccys, entry_t):
        return "news_blocked"
    return F2.simulate(ex, day, entry_t, d, o - d * dist, o + d * rr * dist, flat_t, rates, tag, fill)


# ----------------------------------------------------------------------------- hypotheses
def cs01(ex, refs, arm, day, news, ccys, rates, fill):
    t0930, t0945 = ls(day, (9, 30)), ls(day, (9, 45))
    b = m15(ex, t0930)
    if b is None:
        return "no_bars"
    atr_ex = F4.day_range_atr(ex, day)
    if not atr_ex:
        return "no_atr"
    d = sgn(b[3] - b[0])
    if d == 0 or body_share(b) < 0.40:
        return "no_signal"
    if arm == "ref":
        gd = refs["GDAXI.DWX"]
        w = gd.window(ls(day, (7, 0)), ls(day, (9, 15)))
        atr_gd = F4.day_range_atr(gd, day)
        if not w or w["n"] < 100 or not atr_gd:
            return "no_ref_data"
        delta = w["close"] - w["open"]
        if abs(delta) < 0.30 * atr_gd:
            return "ref_no_trend"
        sma = sma15(gd, ls(day, (9, 15)))
        if sma is None:
            return "no_ref_data"
        if sgn(w["close"] - sma) != sgn(delta):
            return "ref_no_trend"
        if sgn(delta) != d:
            return "ref_disagree"
    ref_bar = m15(ex, t0945)
    if ref_bar is None:
        return "no_bars"
    ext = b[2] if d > 0 else b[1]
    dist = max(abs(ref_bar[0] - ext), 0.40 * atr_ex, 8.0)
    return go(ex, day, t0945, d, dist, 1.75, ls(day, (15, 45)), news, ccys, rates, f"cs01_{arm}", fill)


def cs02(ex, refs, arm, day, news, ccys, rates, fill):
    t0930, t1000, t1015 = ls(day, (9, 30)), ls(day, (10, 0)), ls(day, (10, 15))
    ib = ex.window(t0930, t1000)
    b = m15(ex, t1000)
    if not ib or ib["n"] < 20 or b is None:
        return "no_bars"
    atr_ex = F4.day_range_atr(ex, day)
    if not atr_ex:
        return "no_atr"
    if b[3] > ib["high"] and body_share(b) >= 0.50:
        d = 1
    elif b[3] < ib["low"] and body_share(b) >= 0.50:
        d = -1
    else:
        return "no_signal"
    if arm == "ref":
        sp = refs["SP500.DWX"]
        ibs, bs, atr_sp = sp.window(t0930, t1000), m15(sp, t1000), F4.day_range_atr(sp, day)
        if not ibs or ibs["n"] < 20 or bs is None or not atr_sp:
            return "no_ref_data"
        if d > 0 and not bs[3] > ibs["high"] + 0.05 * atr_sp:
            return "ref_unconfirmed"
        if d < 0 and not bs[3] < ibs["low"] - 0.05 * atr_sp:
            return "ref_unconfirmed"
    ref_bar = m15(ex, t1015)
    if ref_bar is None:
        return "no_bars"
    mid = (ib["high"] + ib["low"]) / 2.0
    dist = max(abs(ref_bar[0] - mid), 0.35 * atr_ex)
    return go(ex, day, t1015, d, dist, 1.75, ls(day, (15, 45)), news, ccys, rates, f"cs02_{arm}", fill)


def cs05(ex, refs, arm, day, news, ccys, rates, fill):
    t0300, t0800, t0815, t0830 = ls(day, (3, 0)), ls(day, (8, 0)), ls(day, (8, 15)), ls(day, (8, 30))
    rg, b = ex.window(t0300, t0800), m15(ex, t0815)
    if not rg or rg["n"] < 200 or b is None:
        return "no_bars"
    atr_h = ex.atr_h1(t0830)
    if not atr_h:
        return "no_atr"
    if b[3] > rg["high"]:
        d = 1
    elif b[3] < rg["low"]:
        d = -1
    else:
        return "no_signal"
    if arm == "ref":
        ag = refs["XAGUSD.DWX"]
        rga, ba, atr_ag = ag.window(t0300, t0800), m15(ag, t0815), ag.atr_h1(t0830)
        if not rga or rga["n"] < 200 or ba is None or not atr_ag:
            return "no_ref_data"
        if d > 0 and not ba[3] > rga["high"] + 0.20 * atr_ag:
            return "ref_unconfirmed"
        if d < 0 and not ba[3] < rga["low"] - 0.20 * atr_ag:
            return "ref_unconfirmed"
    dist = max(0.75 * atr_h, 6.0)
    return go(ex, day, t0830, d, dist, 1.5, ls(day, (13, 30)), news, ccys, rates, f"cs05_{arm}", fill)


def cs07(ex, refs, arm, day, news, ccys, rates, fill):
    t0300, t0945, t1000, t1015 = ls(day, (3, 0)), ls(day, (9, 45)), ls(day, (10, 0)), ls(day, (10, 15))
    w, b = ex.window(t0300, t1000), m15(ex, t1000)
    if not w or w["n"] < 300 or b is None:
        return "no_bars"
    atr_d, atr_h = F4.day_range_atr(ex, day), ex.atr_h1(t1015)
    if not atr_d or not atr_h:
        return "no_atr"
    delta = w["close"] - w["open"]
    if abs(delta) < 0.60 * atr_d:
        return "no_signal"
    d0 = sgn(delta)
    if sgn(b[3] - b[0]) != d0:
        return "no_signal"
    rw = ex.window(t0945, t1015)
    if not rw:
        return "no_bars"
    d = d0 if arm == "with" else -d0
    dist = max(0.60 * atr_h, rw["high"] - rw["low"], 8.0)
    return go(ex, day, t1015, d, dist, 1.5, ls(day, (13, 30)), news, ccys, rates, f"cs07_{arm}", fill)


def cs09(ex, refs, arm, day, news, ccys, rates, fill):
    t0930, t0945, t1000 = ls(day, (9, 30)), ls(day, (9, 45)), ls(day, (10, 0))
    b = m15(ex, t0945)
    if b is None:
        return "no_bars"
    atr_h = ex.atr_h1(t1000)
    if not atr_h:
        return "no_atr"
    d = sgn(b[3] - b[0])
    if d == 0:
        return "no_signal"
    if arm == "ref":
        sp = refs["SP500.DWX"]
        ib, bs, atr_sp = sp.window(t0930, t1000), m15(sp, t0945), F4.day_range_atr(sp, day)
        if not ib or ib["n"] < 20 or bs is None or not atr_sp:
            return "no_ref_data"
        delta = ib["close"] - ib["open"]
        if abs(delta) < 0.25 * atr_sp or body_share(bs) < 0.50:
            return "ref_no_impulse"
        if sgn(delta) != d:
            return "ref_disagree"
    dist = max(0.60 * atr_h, 0.22)
    return go(ex, day, t1000, d, dist, 1.5, ls(day, (15, 45)), news, ccys, rates, f"cs09_{arm}", fill)


def cs10(ex, refs, arm, day, news, ccys, rates, fill):
    t0300, t0815 = ls(day, (3, 0)), ls(day, (8, 15))
    w, atr_d = ex.window(t0300, t0815), F4.day_range_atr(ex, day)
    if not w or w["n"] < 200:
        return "no_bars"
    if not atr_d:
        return "no_atr"
    delta = w["close"] - w["open"]
    if abs(delta) < 0.35 * atr_d:
        return "no_signal"
    d = sgn(delta)
    if arm == "ref":
        gb = refs["GBPUSD.DWX"]
        wg, atr_g = gb.window(t0300, t0815), F4.day_range_atr(gb, day)
        if not wg or wg["n"] < 200 or not atr_g:
            return "no_ref_data"
        dg = wg["close"] - wg["open"]
        if abs(dg) < 0.35 * atr_g:
            return "ref_no_trend"
        if sgn(dg) != d:
            return "ref_disagree"
    for entry_t in (ls(day, (8, 30)), ls(day, (9, 0))):
        rw = ex.window(t0815, entry_t)
        if not rw:
            return "no_bars"
        retr = (w["close"] - rw["low"]) if d > 0 else (rw["high"] - w["close"])
        if retr > 0.382 * abs(delta):
            return "retraced"
        if F2.news_skip(news, ccys, entry_t):
            continue  # 08:30 release day: delay to 09:00 (source condition)
        atr_h = ex.atr_h1(entry_t)
        if not atr_h:
            return "no_atr"
        dist = max(0.65 * atr_h, 0.0020)
        return go(ex, day, entry_t, d, dist, 1.5, ls(day, (16, 0)), news, ccys, rates, f"cs10_{arm}", fill)
    return "news_blocked"


def cs12(ex, refs, arm, day, news, ccys, rates, fill):
    t0900, t1000 = ls(day, (9, 0)), ls(day, (10, 0))
    atr_c = ex.atr_h1(t1000)
    if not atr_c:
        return "no_atr"
    if arm == "ref":
        oil = refs["XTIUSD.DWX"]
        w, atr_o = oil.window(t0900, t1000), oil.atr_h1(t1000)
        if not w or w["n"] < 40 or not atr_o:
            return "no_ref_data"
        delta = w["close"] - w["open"]
        if abs(delta) < 0.50 * atr_o:
            return "no_signal"
        d = -sgn(delta)
    else:
        w = ex.window(t0900, t1000)
        if not w or w["n"] < 40:
            return "no_bars"
        delta = w["close"] - w["open"]
        if abs(delta) < 0.50 * atr_c:
            return "no_signal"
        d = sgn(delta)
    dist = max(0.65 * atr_c, 0.0020)
    return go(ex, day, t1000, d, dist, 1.5, ls(day, (16, 0)), news, ccys, rates, f"cs12_{arm}", fill)


HFUN = {"H-CS01": cs01, "H-CS02": cs02, "H-CS05": cs05, "H-CS07": cs07, "H-CS09": cs09, "H-CS10": cs10, "H-CS12": cs12}


# ----------------------------------------------------------------------------- driver
def run_symbol(args):
    symbol, jobs, news, conv, fill, ref_symbols = args
    try:
        ex = F2.Sym(symbol)
    except FileNotFoundError as exc:
        return symbol, {"error": f"no_m1_history: {exc}"}
    refs = {}
    for rs in ref_symbols:
        try:
            refs[rs] = F2.Sym(rs)
        except FileNotFoundError as exc:
            return symbol, {"error": f"no_reference_history {rs}: {exc}"}
    ccys = F1.symbol_news_currencies(symbol)
    out = {"structural_validation": F1.structural_check(ex.m1), "news_currencies": ccys,
           "cost_prior": dict(zip(("spread_rt", "slip_rt", "tick", "source"), F2.COST_PRIOR[symbol])), "cells": {}}
    for hyp, arm in jobs:
        fn = HFUN[hyp]
        trades, states = [], defaultdict(int)
        for day in ex.days:
            if day < SEL[0] or day > VAL[1]:
                continue
            rates = F1.usd_conversion(conv, ex.sessions[day]["open_t"])
            res = fn(ex, refs, arm, day, news, ccys, rates, fill)
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
                  and p is not None and p <= CHANCE_BAR)
        val_ok = (v_stats["trades"] > 0 and v_stats.get("E_R", -9) > VAL_RULE["E_R"] and (v_stats.get("PF") or 0) >= VAL_RULE["PF"]
                  and s_stats.get("R_per_bd", 0) > 0 and v_stats.get("R_per_bd", -9) >= VAL_RULE["R_per_bd_share"] * s_stats.get("R_per_bd", 0)
                  and F2.val_year_dd_ok(trades))
        kinds = defaultdict(int)
        for t in trades:
            kinds[t["exit_kind"]] += 1
        out["cells"][f"{hyp}|{arm}"] = {"hypothesis": hyp, "arm": arm, "symbol": symbol, "references": HYP[hyp]["refs"], "label": HYP[hyp]["label"],
                                        "fill_model": fill, "day_states": dict(sorted(states.items())), "exit_kinds": dict(sorted(kinds.items())),
                                        "selection": s_stats, "validation": v_stats, "chance_pass_prob_SEL": p, "chance_pass_prob_VAL": pv,
                                        "passes_SEL_rule": bool(sel_ok), "passes_VAL_confirmation": bool(sel_ok and val_ok),
                                        "state": ("WORTH_MT5_TEST" if (sel_ok and val_ok) else ("CLEAR_REJECT" if s_stats["trades"] >= 50 else "UNKNOWN")),
                                        "sequence_sel": seq_sel, "sequence_val": seq_val}
    return symbol, out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hypotheses", default="ALL")
    ap.add_argument("--fill-model", default="conservative", choices=["conservative", "v1"])
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--out", default=str(REPO / "docs/research/ftmo_shadow/velocity_family_f6_cross_symbol_0921.json"))
    a = ap.parse_args()
    hyps = list(HYP) if a.hypotheses == "ALL" else a.hypotheses.split(",")
    per_symbol, refs_of = defaultdict(list), defaultdict(set)
    for h in hyps:
        for arm in HYP[h]["arms"]:
            per_symbol[HYP[h]["exec"]].append((h, arm))
        refs_of[HYP[h]["exec"]].update(HYP[h]["refs"])
    news = F1.load_news()
    conv = {}
    for pair in F1.USD_PAIRS:
        g = F1.aggregate(F1.load_m1(pair), 3600)
        keys = sorted(g)
        conv[pair] = (keys, [g[k][3] for k in keys])
    jobs = [(s, cells, news, conv, a.fill_model, sorted(refs_of[s])) for s, cells in sorted(per_symbol.items())]
    print(f"exec symbols {len(jobs)}; cells {sum(len(c) for _, c, *_ in jobs)}; chance bar {CHANCE_BAR}", file=sys.stderr)
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
    out = {"schema": "qm.velocity-family-f6-cross-symbol/v1", "registration": REGISTRATION, "source": SOURCE, "programme": "Track B family B4 (cross-symbol, Antigravity 7636afc9)",
           "script": "tools/strategy_farm/session_tools/velocity_family_f6_cross_symbol_0921.py", "engine": "velocity_family_f2_cash_session_0921.py (conservative closed-bar fills)",
           "resolutions": ["entry = market at the open of the first bar after the last closed bar the rule reads", "D1 ATR(14) = mean of previous 14 full server-day ranges (F4 helper); H1 ATR(14) = simple 14-bar mean",
                           "H-CS02 breakeven trail not modelled", "H-CS10 delays to 09:00 ET on 08:30 release days", "engine stop floor 5 x round-trip spread applies on top of each rule floor"],
           "controls": {"noref": "execution-symbol trigger alone", "H-CS07 fade": "against the London drift (must lose)", "H-CS12 self": "USDCAD own 09:00-10:00 impulse instead of oil"},
           "fill_model": a.fill_model, "cost_priors": {s: dict(zip(("spread_rt", "slip_rt", "tick", "source"), F2.COST_PRIOR[s])) for s in sorted(set(per_symbol) | set().union(*refs_of.values()))},
           "selection_period": [SEL[0].isoformat(), SEL[1].isoformat()], "validation_period": [VAL[0].isoformat(), VAL[1].isoformat()],
           "selection_rule": dict(SEL_RULE, chance=CHANCE_BAR), "validation_rule": VAL_RULE, "risk_fixed": F1.RISK,
           "null": {"cells_evaluated": n_cells, "expected_false_SEL_survivors": round(null_sum, 4), "family_bonferroni_bar": CHANCE_BAR},
           "observed": {"cells_passing_SEL_rule": sum(1 for c in cells.values() if c["passes_SEL_rule"]), "survivors_after_VAL": len(survivors)},
           "cells": cells, "survivors": survivors, "errors": {s: r["error"] for s, r in results.items() if "error" in r},
           "sequences": {f"{k}|{s}": {"sel": r["cells"][k]["sequence_sel"], "val": r["cells"][k]["sequence_val"]} for s, r in results.items() if "cells" in r for k in r["cells"]}}
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_text(json.dumps(out, indent=1, sort_keys=True, default=str) + "\n", encoding="utf-8")
    print(json.dumps({"cells": n_cells, "SEL_pass": out["observed"]["cells_passing_SEL_rule"], "survivors": len(survivors), "expected_false": round(null_sum, 4), "errors": out["errors"], "out": a.out}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
