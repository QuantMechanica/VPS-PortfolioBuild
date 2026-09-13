#!/usr/bin/env python3
"""For each qualified pair, list the Q10 (and Q08) chain rows + their evidence dirs. READ-ONLY."""
from __future__ import annotations
import json, sys
from pathlib import Path
sys.path.insert(0, r"C:\QM\repo")
from tools.strategy_farm import rebaseline_census

pool = json.loads(Path(r"D:\QM\reports\portfolio\dxz_v2_20260913\pool.json").read_text(encoding="utf-8"))
con = rebaseline_census.open_ro("D:/QM/strategy_farm/state/farm_state.sqlite")

for p in pool["pairs"]:
    ea, sym = p["ea_id"], p["symbol"]
    rows = [dict(r) for r in con.execute(
        "SELECT id, phase, status, verdict, evidence_path, setfile_path, updated_at, gate_contract_version,"
        " data_window_start, data_window_end FROM work_items WHERE ea_id=? AND symbol=? ORDER BY updated_at",
        (ea, sym))]
    for want in ("Q10", "Q08"):
        sel = [r for r in rows
               if rebaseline_census.canonical_gate(r["phase"], r["gate_contract_version"]) == want
               and (r["verdict"] or "") in rebaseline_census.PASS_ECON
               and (r["status"] or "").lower() == "done"]
        if sel:
            r = sel[-1]
            print(f"{ea}:{sym} {want} {r['phase']} {r['verdict']} {r['updated_at']} {r['data_window_start']}..{r['data_window_end']}")
            print(f"    id={r['id']}")
            print(f"    ev={r['evidence_path']}")
        else:
            print(f"{ea}:{sym} {want} NONE")
