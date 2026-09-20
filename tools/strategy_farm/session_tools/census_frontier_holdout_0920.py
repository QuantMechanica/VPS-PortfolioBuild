#!/usr/bin/env python3
"""Holdout check of the census velocity frontier (0 factory hours).

For every programme: select the configuration by R/bd on the selection years
(default 2019-2022), then report its R/bd on the validation years (2023-2025)
next to the baseline arm's validation R/bd. Answers the selection-bias question
before any census arm is proposed as a Velocity challenger.
"""
from __future__ import annotations

import json
import sys
from collections import defaultdict

FRONTIER = "C:/QM/repo/docs/ops/evidence/2026-09-20_velocity_book/census_velocity_frontier.json"
DB = "D:/QM/strategy_farm/state/farm_state.sqlite"
OUT = "C:/QM/repo/docs/ops/evidence/2026-09-20_velocity_book/census_frontier_holdout.json"
SEL = {"2019", "2020", "2021", "2022"}
VAL = {"2023", "2024", "2025"}
RISK = 1000.0


def main() -> int:
    # Re-read the per-year cells from the DB (the frontier JSON keeps only aggregates).
    import datetime as dt
    import os
    import re
    import sqlite3

    def bdays(a, b):
        d0 = dt.datetime.strptime(a, "%Y.%m.%d").date(); d1 = dt.datetime.strptime(b, "%Y.%m.%d").date()
        return sum(1 for k in range((d1 - d0).days + 1) if (d0 + dt.timedelta(k)).weekday() < 5)

    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    cells = defaultdict(lambda: defaultdict(dict))  # program -> arm -> year -> (net, trades, bd)
    for ea, sym, sp, pj, ep in con.execute("SELECT ea_id, symbol, setfile_path, payload_json, evidence_path FROM work_items WHERE phase='OPT_CENSUS' AND verdict='MEASURED'"):
        try:
            p = json.loads(pj or "{}")
            s_path = ep if ep.endswith("summary.json") else os.path.join(os.path.dirname(ep), "summary.json")
            run = (json.load(open(s_path, encoding="utf-8")).get("runs") or [{}])[0]
            year = str(p.get("year") or run["from_date"][:4])
            arm = p.get("arm") or re.sub(r":20\d\d:", ":", p.get("cell_key") or "")
            cells[p.get("program_id") or ""][arm][year] = (run.get("net_profit") or 0.0, run.get("total_trades") or 0, bdays(run["from_date"], run["to_date"]))
        except Exception:
            continue

    def rbd(years):
        net = sum(v[0] for v in years.values()); bd = sum(v[2] for v in years.values()); tr = sum(v[1] for v in years.values())
        return (net / (bd * RISK) if bd else float("nan")), tr, bd

    rows = []
    for prog, arms in cells.items():
        scored = []
        for arm, ys in arms.items():
            sel = {y: v for y, v in ys.items() if y in SEL}; val = {y: v for y, v in ys.items() if y in VAL}
            if len(sel) < 3 or len(val) < 2:
                continue
            scored.append((arm, rbd(sel), rbd(val)))
        if not scored:
            continue
        scored.sort(key=lambda t: -t[1][0])
        best = scored[0]
        base = next((t for t in scored if t[0] == "baseline"), None)
        top5_val = sum(t[2][0] for t in scored[:5]) / min(5, len(scored))
        rows.append({"program": prog, "arms": len(scored), "best_arm": best[0], "best_sel_R_bd": round(best[1][0], 4), "best_val_R_bd": round(best[2][0], 4),
                     "best_val_trades": best[2][1], "top5_val_R_bd_mean": round(top5_val, 4),
                     "baseline_sel_R_bd": round(base[1][0], 4) if base else None, "baseline_val_R_bd": round(base[2][0], 4) if base else None})
    rows.sort(key=lambda r: -r["best_val_R_bd"])
    json.dump({"schema": "qm.census-frontier-holdout/v1", "selection_years": sorted(SEL), "validation_years": sorted(VAL), "rows": rows}, open(OUT, "w", encoding="utf-8"), indent=1)
    print(f'{"program":<44}{"arms":>5}{"sel best":>9}{"VAL best":>9}{"top5 VAL":>9}{"base sel":>9}{"base VAL":>9}  best arm')
    for r in rows:
        bs = f'{r["baseline_sel_R_bd"]:.3f}' if r["baseline_sel_R_bd"] is not None else "  n/a"
        bv = f'{r["baseline_val_R_bd"]:.3f}' if r["baseline_val_R_bd"] is not None else "  n/a"
        print(f'{r["program"][:44]:<44}{r["arms"]:>5}{r["best_sel_R_bd"]:>9.3f}{r["best_val_R_bd"]:>9.3f}{r["top5_val_R_bd_mean"]:>9.3f}{bs:>9}{bv:>9}  {r["best_arm"][:30]}')
    return 0


if __name__ == "__main__":
    sys.exit(main())
