#!/usr/bin/env python3
"""Evaluate the CURRENT LIVE 24-sleeve book under the same SP-C3 policy, to test whether
CONCENTRATION_CAP_BREACH is a property of the proposal or of the 9.75 %-vs-2.5 %-budget
scale mismatch. READ-ONLY."""
from __future__ import annotations
import json, sys
from pathlib import Path
sys.path.insert(0, r"C:\QM\repo")
from tools.strategy_farm.portfolio import concentration_tail
from tools.strategy_farm.portfolio.portfolio_common import load_streams, to_daily_pnl

REPO = Path(r"C:\QM\repo")
INC = Path(r"D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json")
ROOT = Path(r"D:\QM\reports\portfolio\dxz_v2_20260913\streams_build_A")

doc = json.loads(INC.read_text(encoding="utf-8"))
keys = sorted((int(s["ea_id"]), s["symbol"]) for s in doc["sleeves"])
w = {(int(s["ea_id"]), s["symbol"]): float(s["risk_percent"]) for s in doc["sleeves"]}
streams = load_streams(ROOT, candidates=keys)
daily = {k: to_daily_pnl(streams[k]) for k in keys}
start = max(min(daily[k]) for k in keys)
end = min(max(daily[k]) for k in keys)
days = sorted({d for k in keys for d in daily[k] if start <= d <= end})
matrix = [[float(daily[k].get(d, 0.0)) for k in keys] for d in days]
res = concentration_tail.evaluate(
    keys=keys, weights=w, dates=days, matrix=matrix, streams=streams,
    starting_capital=100_000.0, repo_root=REPO)
print("incumbent sum risk:", round(sum(w.values()), 4))
print("concentration_reject:", json.dumps(res.get("concentration_reject"), indent=1))
print("builder_eligible:", res.get("builder_eligible"))
out = Path(r"D:\QM\reports\portfolio\dxz_v2_20260913\build\incumbent_concentration_control.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(res, indent=2, sort_keys=True, default=str) + "\n", encoding="utf-8")
print("->", out)
