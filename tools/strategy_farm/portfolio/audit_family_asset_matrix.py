#!/usr/bin/env python3
"""Round 8 section 5.1: does any strategy family pass reproducibly on one asset class?

The QM5_215xx family passed on gold and silver and failed on NDX, WS30 and SP500 on the
same day.  If that pattern recurs across families, the cross-market validation the
production doctrine asks for is not "the same strategy on any symbol" but "the same
strategy across an asset class", and that is a different instruction to generation.

Family is taken from the EA directory slug (framework/EAs/QM5_<id>_<family>-<rest>),
because that is where the provenance actually lives; the numeric id block is not a
family.  Asset class is assigned from the symbol.

Read-only.  Prints the matrix and writes a JSON artifact.
"""
from __future__ import annotations

import datetime as dt
import json
import re
import sqlite3
from collections import defaultdict
from pathlib import Path

EAS = Path(r"C:\QM\repo\framework\EAs")
DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
OUT = Path(r"C:\QM\repo\artifacts\audit_family_asset_matrix_20260819.json")

# Robustness gates only: Q02/Q03 are economics and data, not robustness.
GATES = ("Q04", "Q05", "Q06", "Q07", "Q08")
OK = {"PASS", "PASS_SOFT", "PASS_LOWFREQ", "MULTI_SEED_PASS"}

ASSET = {
    "XAUUSD": "metal", "XAGUSD": "metal",
    "XTIUSD": "energy", "XNGUSD": "energy", "XBRUSD": "energy",
    "GDAXI": "index", "NDX": "index", "SP500": "index", "WS30": "index",
    "UK100": "index", "JP225": "index", "STOXX50": "index",
}


def asset_class(symbol: str) -> str:
    bare = str(symbol).upper().replace(".DWX", "")
    if bare in ASSET:
        return ASSET[bare]
    if re.fullmatch(r"[A-Z]{6}", bare):
        return "fx"
    return "other"


def family_map() -> dict[str, str]:
    out = {}
    for d in EAS.iterdir():
        if not d.is_dir():
            continue
        parts = d.name.split("_", 2)
        if len(parts) < 3:
            continue
        slug = parts[2]
        out[f"{parts[0]}_{parts[1]}"] = slug.split("-")[0]
    return out


def main() -> int:
    fam = family_map()
    con = sqlite3.connect(DB, uri=True, timeout=30)
    con.row_factory = sqlite3.Row
    # Latest verdict per (ea, symbol, phase).
    latest = {}
    for r in con.execute("select ea_id,symbol,phase,verdict from work_items "
                         "where status in ('done','failed') order by updated_at"):
        latest[(r["ea_id"], str(r["symbol"]).upper(), r["phase"])] = str(r["verdict"] or "")
    con.close()

    # Per (family, asset class): how many pairs reached a robustness gate, how many passed.
    cell = defaultdict(lambda: {"reached": 0, "passed": 0, "pairs": set()})
    for (ea, sym, phase), verdict in latest.items():
        if phase not in GATES:
            continue
        f = fam.get(ea)
        if not f:
            continue
        a = asset_class(sym)
        c = cell[(f, a)]
        c["reached"] += 1
        c["pairs"].add(f"{ea}:{sym}")
        if verdict in OK:
            c["passed"] += 1

    # A family only says something if it has enough runs on more than one class.
    by_family = defaultdict(dict)
    for (f, a), c in cell.items():
        by_family[f][a] = {"reached": c["reached"], "passed": c["passed"],
                           "rate": round(c["passed"] / c["reached"], 3) if c["reached"] else None,
                           "pairs": len(c["pairs"])}

    MIN_RUNS = 8
    split = []
    for f, classes in by_family.items():
        usable = {a: v for a, v in classes.items() if v["reached"] >= MIN_RUNS}
        if len(usable) < 2:
            continue
        best = max(usable.items(), key=lambda kv: kv[1]["rate"])
        worst = min(usable.items(), key=lambda kv: kv[1]["rate"])
        gap = best[1]["rate"] - worst[1]["rate"]
        split.append({"family": f, "best_class": best[0], "best_rate": best[1]["rate"],
                      "best_runs": best[1]["reached"], "worst_class": worst[0],
                      "worst_rate": worst[1]["rate"], "worst_runs": worst[1]["reached"],
                      "gap": round(gap, 3), "classes": usable})
    split.sort(key=lambda r: -r["gap"])

    print(f"families with >={MIN_RUNS} robustness-gate runs on two or more asset "
          f"classes: {len(split)}")
    print()
    print(f"{'family':18} {'best class':10} {'rate':>6} {'n':>4}   "
          f"{'worst class':11} {'rate':>6} {'n':>4}   {'gap':>6}")
    for r in split[:20]:
        print(f"{r['family']:18} {r['best_class']:10} {r['best_rate']:6.2f} {r['best_runs']:4}   "
              f"{r['worst_class']:11} {r['worst_rate']:6.2f} {r['worst_runs']:4}   {r['gap']:6.2f}")

    payload = {
        "schema": "qm.family-asset-matrix/v1",
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "gates": list(GATES),
        "pass_verdicts": sorted(OK),
        "min_runs_per_cell": MIN_RUNS,
        "families_with_split": split,
        "matrix": {f: c for f, c in by_family.items()},
    }
    OUT.write_text(json.dumps(payload, indent=2, sort_keys=True, default=str), encoding="utf-8")
    print(f"\nartifact: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
