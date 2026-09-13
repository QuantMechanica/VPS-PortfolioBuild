#!/usr/bin/env python3
"""Burn-in variant: NEW sleeves at min-lot RISK_PERCENT, the 6 live overlaps at v2 target."""
from __future__ import annotations
import json, sys
from pathlib import Path

p = Path(sys.argv[1] if len(sys.argv) > 1
         else r"D:\QM\reports\portfolio\dxz_v2_20260913\build\analytic_preview_manifest_B18.json")
d = json.loads(p.read_text(encoding="utf-8"))
rows, s_new, s_live = [], 0.0, 0.0
for s in sorted(d["sleeves"], key=lambda x: (not x["already_live"], x["ea_id"])):
    m = s["min_lot_risk_percent"]
    if s["already_live"]:
        r = round(s["weight_risk_percent"], 4)
        basis = "V2_TARGET_WEIGHT"
        s_live += r
    else:
        r = m["median_trade_hits_0.01_lots_at_pct"]
        basis = "MIN_LOT_MEDIAN_TRADE"
        s_new += r
    rows.append({"ea_id": s["ea_id"], "ea_label": s["ea_label"], "symbol": s["symbol"],
                 "magic": s["magic"], "already_live": s["already_live"],
                 "burn_in_risk_percent": r, "basis": basis,
                 "v2_target_risk_percent": round(s["weight_risk_percent"], 4),
                 "min_lot_median_pct": m["median_trade_hits_0.01_lots_at_pct"],
                 "min_lot_largest_pct": m["largest_trade_hits_0.01_lots_at_pct"]})
out = {
    "schema": "qm.dxz-book-v2-burnin-variant/v1",
    "source_manifest": str(p),
    "note": ("Streams are at RISK_FIXED $1000 on 100k = 1.0 %/trade (framework/registry/"
             "tester_defaults.json). Lots scale linearly with RISK_PERCENT, so the value at which "
             "a trade of backtest volume V quantizes to 0.01 lots is 0.01/V %. MIN_LOT_MEDIAN_TRADE "
             "puts the MEDIAN trade on 0.01 lots; trades smaller than the median then quantize below "
             "volume_min and QM_RiskSizerQuantizeLots (QM_RiskSizer.mqh:210) returns 0.0 -> no trade. "
             "MIN_LOT_LARGEST_TRADE is the upper bound at which EVERY trade is still >= 0.01 lots."),
    "sum_new_sleeves_pct": round(s_new, 4),
    "sum_live_sleeves_pct": round(s_live, 4),
    "sum_total_pct": round(s_new + s_live, 4),
    "sum_all_min_lot_largest_basis_pct": round(
        sum(r["min_lot_largest_pct"] for r in rows if not r["already_live"]) + s_live, 4),
    "sleeves": rows,
}
dest = p.parent / "burnin_variant.json"
dest.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n", encoding="utf-8")
for r in rows:
    print(f"{r['ea_id']:6d} {r['symbol']:14s} {'LIVE' if r['already_live'] else 'NEW ':4s} "
          f"burn_in={r['burn_in_risk_percent']:.4f}  v2_target={r['v2_target_risk_percent']:.4f}  {r['basis']}")
print(f"\nnew={out['sum_new_sleeves_pct']}  live={out['sum_live_sleeves_pct']}  "
      f"TOTAL={out['sum_total_pct']}  (all-trades-min-lot basis: {out['sum_all_min_lot_largest_basis_pct']})")
print("->", dest)
