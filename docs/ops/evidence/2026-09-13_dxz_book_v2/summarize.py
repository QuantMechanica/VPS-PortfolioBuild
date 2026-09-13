#!/usr/bin/env python3
"""Print the tables needed for FIT_REPORT.md from an analytic preview manifest."""
from __future__ import annotations
import json, sys
from collections import defaultdict
from pathlib import Path

p = Path(sys.argv[1])
d = json.loads(p.read_text(encoding="utf-8"))
sl = d["sleeves"]
print("STATUS", d["status"], "n", len(sl), "window", d["comparison"]["window"])
print("sum weight", d["weighting"]["sum_risk_percent"], "ENB", d["enb_weighted"])
print()
print("| EA | symbol | magic | live | w% | PF | MaxDD% | trades | tr/yr | window |")
for s in sorted(sl, key=lambda x: -x["weight_risk_percent"]):
    f = s["standalone_full_stream"]
    print(f"| {s['ea_label']} | {s['symbol']} | {s['magic']} | {'LIVE' if s['already_live'] else 'NEW'} | "
          f"{s['weight_risk_percent']:.4f} | {f['profit_factor']} | {f['standalone_maxdd_pct_at_1pct_risk']} | "
          f"{f['n_trades']} | {f['trades_per_year']} | {f['first_day']}..{f['last_day']} |")
print()
sym = defaultdict(float); fam = defaultdict(float); ast = defaultdict(float)
conc = d["concentration_tail"]
for s in sl:
    sym[s["symbol"]] += s["weight_risk_percent"]
print("SYMBOL:", {k: round(v, 4) for k, v in sorted(sym.items(), key=lambda x: -x[1])})
for dim in ("symbol", "asset_class", "family", "session"):
    g = conc.get("groups", {}).get(dim) or conc.get(dim)
    if g:
        print(dim.upper(), json.dumps(g)[:600])
print()
print("CONC KEYS", sorted(conc))
print()
print("FLAGGED CORR:", json.dumps(d["correlation"]["flagged_ge_0.5"], indent=1))
print("MAX |r|", d["correlation"]["max_abs"])
top = sorted(((abs(v), k, v) for k, v in d["correlation"]["matrix"].items() if v is not None), reverse=True)[:8]
for a, k, v in top:
    print(f"  {k}  r={v:+.4f}  co_active_days={d['correlation']['co_active_days'][k]}")
print()
print("MARGINAL (delta sharpe, sorted):")
for k, v in sorted(d["marginal_contribution"].items(), key=lambda x: -(x[1]["delta_sharpe"] or -9)):
    print(f"  {k:22s} dSharpe={v['delta_sharpe']}  dMaxDD={v['delta_maxdd_pct']}")
print()
print("MIN-LOT RISK_PERCENT (0.01 lots on 100k):")
for s in sorted(sl, key=lambda x: x["ea_id"]):
    m = s["min_lot_risk_percent"]
    print(f"  {s['ea_id']}:{s['symbol']:14s} median={m['median_trade_hits_0.01_lots_at_pct']} "
          f"largest={m['largest_trade_hits_0.01_lots_at_pct']} smallest={m['smallest_trade_hits_0.01_lots_at_pct']} "
          f"vol(min/med/max)={s['standalone_full_stream']['volume_min']}/"
          f"{s['standalone_full_stream']['volume_median']}/{s['standalone_full_stream']['volume_max']}")
print()
print("OVERLAP LIVE:", d["overlap_with_live_book"])
print("DROPPED LIVE:", d["live_sleeves_dropped_by_v2"])
