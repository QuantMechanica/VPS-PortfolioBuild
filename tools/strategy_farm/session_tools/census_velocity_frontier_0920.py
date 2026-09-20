#!/usr/bin/env python3
"""Velocity frontier over every measured OPT_CENSUS cell (0 factory hours).

Each DL-089 census cell is one (program, cell_key/arm, year) tester run whose
summary.json carries net_profit / total_trades / profit_factor / drawdown at
RISK_FIXED 1000 (1 %/trade on 100k). Aggregating the annual cells per
configuration gives trades/bd, E[R] and R/bd for thousands of measured
parameter/filter variants of the pool EAs. Read-only; writes one JSON.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import re
import sqlite3
import sys
from collections import defaultdict

DB = "D:/QM/strategy_farm/state/farm_state.sqlite"
OUT = "C:/QM/repo/docs/ops/evidence/2026-09-20_velocity_book/census_velocity_frontier.json"
RISK = 1000.0


def bdays(a: str, b: str) -> int:
    d0 = dt.datetime.strptime(a, "%Y.%m.%d").date()
    d1 = dt.datetime.strptime(b, "%Y.%m.%d").date()
    return sum(1 for k in range((d1 - d0).days + 1) if (d0 + dt.timedelta(k)).weekday() < 5)


def main() -> int:
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    rows = con.execute(
        "SELECT ea_id, symbol, setfile_path, payload_json, evidence_path FROM work_items "
        "WHERE phase='OPT_CENSUS' AND verdict='MEASURED'"
    ).fetchall()
    cells = defaultdict(lambda: {"years": {}, "ea": "", "symbol": "", "tf": "", "setfile": ""})
    missing = 0
    for ea, sym, sp, pj, ep in rows:
        try:
            p = json.loads(pj or "{}")
        except json.JSONDecodeError:
            continue
        s_path = ep if ep and ep.endswith("summary.json") else os.path.join(os.path.dirname(ep or ""), "summary.json")
        try:
            s = json.load(open(s_path, encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            missing += 1
            continue
        run = (s.get("runs") or [{}])[0]
        if not run.get("from_date") or not run.get("to_date"):
            missing += 1
            continue
        ck = p.get("cell_key") or ""
        key = (p.get("program_id") or "", p.get("arm") or re.sub(r":20\d\d:", ":", ck) or os.path.basename(sp or ""))
        c = cells[key]
        c["ea"], c["symbol"], c["setfile"] = ea, sym, os.path.basename(sp or "")
        m = re.search(r"_(M1|M5|M15|M30|H1|H4|D1|W1)_", sp or "")
        c["tf"] = m.group(1) if m else (p.get("host_timeframe") or "")
        c["arm"] = p.get("arm")
        year = str(p.get("year") or p.get("test_year") or run["from_date"][:4])
        c["years"][year] = {
            "trades": run.get("total_trades") or 0,
            "net": run.get("net_profit") or 0.0,
            "pf": run.get("profit_factor"),
            "dd": run.get("drawdown") or 0.0,
            "bd": bdays(run["from_date"], run["to_date"]),
        }
    out = []
    for (program, cell_key), c in cells.items():
        ys = c["years"]
        if not ys:
            continue
        trades = sum(y["trades"] for y in ys.values())
        net = sum(y["net"] for y in ys.values())
        bd = sum(y["bd"] for y in ys.values())
        if bd <= 0 or trades <= 0:
            continue
        pos_years = sum(1 for y in ys.values() if y["net"] > 0)
        worst_dd = max(y["dd"] for y in ys.values())
        out.append({
            "program": program, "cell_key": cell_key, "arm": c["arm"], "ea": c["ea"], "symbol": c["symbol"], "tf": c["tf"],
            "setfile": c["setfile"], "years": len(ys), "pos_years": pos_years, "trades": trades,
            "density": round(trades / bd, 3), "eR": round(net / (trades * RISK), 4), "R_bd": round(net / (bd * RISK), 4),
            "net": round(net, 2), "worst_year_dd_R": round(worst_dd / RISK, 1), "bd": bd,
        })
    out.sort(key=lambda x: -x["R_bd"])
    json.dump({"schema": "qm.census-velocity-frontier/v1", "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(timespec="seconds"),
               "measured_rows": len(rows), "summary_missing": missing, "configurations": len(out), "rows": out},
              open(OUT, "w", encoding="utf-8"), indent=1)
    print(f"measured rows {len(rows)}, summaries missing {missing}, configurations {len(out)}")
    progs = defaultdict(list)
    for o in out:
        progs[o["program"]].append(o)
    print(f'{"program":<44}{"cfgs":>5}{"best R/bd":>10}{"dens":>6}{"E[R]":>7}{"yrs":>4}{"pos":>4}{"trades":>7}  best cell')
    for prog, lst in sorted(progs.items(), key=lambda kv: -max(x["R_bd"] for x in kv[1])):
        full = [x for x in lst if x["years"] >= 3] or lst
        b = max(full, key=lambda x: x["R_bd"])
        base = next((x for x in lst if x["cell_key"] == "baseline"), None)
        bl = f'{base["R_bd"]:.3f}' if base else "  n/a"
        print(f'{prog[:44]:<44}{len(lst):>5}{b["R_bd"]:>10.3f}{b["density"]:>6.2f}{b["eR"]:>7.3f}{b["years"]:>4}{b["pos_years"]:>4}{b["trades"]:>7}  base={bl} {b["cell_key"][:28]}')
    print("== top 25 configurations with >=3 years ==")
    for o in [x for x in out if x["years"] >= 3][:25]:
        print(f'{o["ea"]:<10}{o["symbol"]:<12}{o["tf"]:<4} R/bd={o["R_bd"]:.3f} dens={o["density"]:.2f} E[R]={o["eR"]:.3f} yrs={o["years"]} pos={o["pos_years"]} dd={o["worst_year_dd_R"]}R  {o["cell_key"][:50]}')
    return 0


if __name__ == "__main__":
    sys.exit(main())
