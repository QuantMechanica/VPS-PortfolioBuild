"""Read-only paired arithmetic over the 41470 review packet (task f6d932f4). No simulation."""
import hashlib, json, statistics as st, sys
from pathlib import Path

PACKET = Path(r"D:/QM/strategy_farm/artifacts/astra_41470_methodology_20260927/packet")
EXPECT = {"paired_rows.jsonl": "7eb8aa5619d5e42ee8fe63e5763456e21e733d2a7717f821e7f6a54b39ecf340",
          "reconciliation.json": "276ee5af56010b04023ca936dc468f0166ef5d505f5dc2edc9406ca43fe131da",
          "author_result.md": "c97f30f294d25691751c27e8c10b6a4e20975789f91b1d708dae701126ee8cf5",
          "method_excerpts.txt": "a750ae3912e09e8e8863b9d409c284709e32ec9b2d5c3c6d2313bc890adcee49",
          "kpi_contract.md": "721740cb78b28dc507975a16d0b51975ff0e2cb30e8a99f3f94ef6c9584a0810"}
hashes = {n: hashlib.sha256((PACKET / n).read_bytes()).hexdigest() for n in EXPECT}
assert hashes == EXPECT, hashes

rows = [json.loads(l) for l in (PACKET / "paired_rows.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
by = {(r["arm"], r["seed"]): r for r in rows}
seeds = sorted({r["seed"] for r in rows})
arms = sorted({r["arm"] for r in rows} - {"BASE"})
M = ["lcb", "p_ever", "p80_bd", "t80_bd", "p50_bd", "cond_p90_bd", "max_loss_all", "daily_loss_all", "censored"]

def summ(v):
    v = [x for x in v if x is not None]
    if not v:
        return None
    return {"mean": round(st.mean(v), 6), "min": round(min(v), 6), "max": round(max(v), 6),
            "sd": round(st.stdev(v), 6) if len(v) > 1 else None, "n": len(v)}

out = {"schema": "qm.task-f6d932f4.paired-check/v1", "packet_sha256": hashes, "rows": len(rows),
       "seeds": seeds, "windows": sorted({json.dumps({k: r["window"][k] for k in ("start", "end", "business_days")}) for r in rows}),
       "grid_bd": sorted({r["stats"]["grid_bd"] for r in rows}), "levels": {}, "deltas": {}}
for arm in ["BASE"] + arms:
    out["levels"][arm] = {cost: {m: summ([by[(arm, s)][cost].get(m) for s in seeds]) for m in M} for cost in ("normal", "stress")}
    out["levels"][arm]["book_risk_pct"] = by[(arm, seeds[0])]["book_risk_pct"]
    out["levels"][arm]["active_book_days"] = [by[(arm, s)]["window"]["active_book_days"] for s in seeds]
for arm in arms:
    d = {}
    for cost in ("normal", "stress"):
        d[cost] = {}
        for m in M:
            per = []
            for s in seeds:
                a, b = by[(arm, s)][cost].get(m), by[("BASE", s)][cost].get(m)
                per.append(None if a is None or b is None else round(a - b, 6))
            d[cost][m] = {"per_seed": per, **(summ(per) or {"mean": None})}
    out["deltas"][arm] = d
# CRN signature: spread of paired deltas vs spread of incumbent levels (normal P80, LCB)
out["crn_signature"] = {m: {"incumbent_level_sd": out["levels"]["BASE"]["normal"][m]["sd"],
                            "delta_sd_0.15625": out["deltas"]["D_41470_0.15625"]["normal"][m]["sd"],
                            "delta_sd_0.3125": out["deltas"]["D_41470_0.3125"]["normal"][m]["sd"]}
                        for m in ("p80_bd", "lcb", "p_ever")}
# goal state per arm (OWNER: P80 < 90 calendar days with payout-ever LCB >= .80)
out["goal_state"] = {}
for arm in ["BASE"] + arms:
    g = {}
    for cost in ("normal", "stress"):
        lcbs = [by[(arm, s)][cost]["lcb"] for s in seeds]
        p80 = [by[(arm, s)][cost]["p80_bd"] for s in seeds]
        if all(x < 0.80 for x in lcbs):
            g[cost] = "NOT_ACHIEVED (every seed LCB < .80)"
        elif all(x >= 0.80 for x in lcbs) and all(p is not None for p in p80):
            g[cost] = f"FINITE_DIAGNOSTIC_TARGET_MISS (point P80 {min(p80)}-{max(p80)} bd = ~{round(min(p80)*7/5)}-{round(max(p80)*7/5)} cd 5/7 mapping vs <90 cd)"
        else:
            g[cost] = "MIXED"
    out["goal_state"][arm] = g
json.dump(out, sys.stdout, indent=1)
