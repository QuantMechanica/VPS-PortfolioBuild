"""Read-only fact gathering for the R2_capped FTMO Demo recomposition package.

Writes ONLY into this evidence folder. No MT5, no DB write, no git.
"""
from __future__ import annotations
import csv
import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path

REPO = Path(r"C:\QM\repo")
sys.path.insert(0, str(REPO))
OUT = REPO / "docs/ops/evidence/2026-09-18_ftmo_demo_recompose_R2"
DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
TERM = Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850")
W38 = Path(r"D:\QM\reports\book_evolution\2026-W38\ftmo")
ROSTER_V2B = Path(r"D:\QM\reports\portfolio\dxz_v2_20260913\roster_v2b.json")
PROBE = REPO / "docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/ftmo_symbol_probe.json"
ALIASES = REPO / "framework/registry/execution_symbol_aliases_v1.json"
MAGICS = REPO / "framework/registry/magic_numbers.csv"

R2 = [(13213, "USDJPY"), (10706, "GBPUSD"), (10700, "XAUUSD"), (11660, "NDX"),
      (11422, "USDCAD"), (10145, "XAUUSD"), (20266, "XTIUSD"), (12710, "XTIUSD")]


def sha(p) -> str:
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main() -> None:
    conn = sqlite3.connect(DB.resolve().as_uri() + "?mode=ro", uri=True)

    probe = json.loads(PROBE.read_text(encoding="utf-8"))
    ticks = set(probe["ticks_dir"]["symbols"])
    hist = set(probe["history_dir"]["symbols"])
    logs = probe["logs"]["probe_name_occurrences"]
    alias_doc = json.loads(ALIASES.read_text(encoding="utf-8"))
    ftmo_alias = {}
    alias_account = None
    for v in alias_doc["venues"]:
        if v["venue_id"] == "FTMO_TRIAL":
            alias_account = v["account_id"]
            ftmo_alias = {s["logical_symbol"]: s["raw_symbol"] for s in v["symbols"]}

    from tools.strategy_farm.ftmo import demo_cycle as dc
    prof = TERM / "MQL5/Profiles/Charts/Default"
    experts = TERM / "MQL5/Experts/QM_FTMO"
    current = dc.parse_chart_profile(prof, experts)
    current_hash = dc.roster_hash(current)

    chart_raw = []
    for c in sorted(prof.glob("chart*.chr")):
        t = dc._read_chart_text(c)
        row = {"chart": c.name, "symbol": None, "period": None, "expert": None,
               "slot_offset": None, "risk_pct": None, "sha256": sha(c),
               "bytes": c.stat().st_size}
        in_exp = False
        for line in t.splitlines():
            s = line.strip()
            if s.startswith("symbol=") and row["symbol"] is None:
                row["symbol"] = s.split("=", 1)[1]
            elif s.startswith("period=") and row["period"] is None:
                row["period"] = s.split("=", 1)[1]
            elif s == "<expert>":
                in_exp = True
            elif in_exp and s.startswith("name=") and row["expert"] is None:
                row["expert"] = s.split("=", 1)[1]
            elif s.startswith("qm_magic_slot_offset="):
                row["slot_offset"] = s.split("=", 1)[1]
            elif s.startswith("RISK_PERCENT="):
                row["risk_pct"] = s.split("=", 1)[1]
        chart_raw.append(row)

    v2b = {}
    if ROSTER_V2B.is_file():
        for s in json.loads(ROSTER_V2B.read_text(encoding="utf-8"))["sleeves"]:
            v2b[(s["ea_id"], s["symbol"])] = s

    snap = json.loads((W38 / "snapshot_r2/manifest.json").read_text(encoding="utf-8"))
    snap_streams = {r["key"]: r for r in snap["streams"]["records"]}

    reg = {}
    with MAGICS.open(encoding="utf-8-sig", newline="") as fh:
        for r in csv.DictReader(fh):
            reg[(int(r["ea_id"]), r["symbol"])] = r

    sleeves = []
    for ea, sym in R2:
        logical = sym + ".DWX"
        rec = {"ea_id": ea, "factory_symbol": logical, "base_symbol": sym}

        row = conn.execute(
            "SELECT id,setfile_path,evidence_path,setfile_sha256,updated_at FROM work_items "
            "WHERE ea_id=? AND symbol=? AND phase='Q10_NEWS' AND status='done' "
            "AND verdict='CONFIG_LOCKED' ORDER BY updated_at DESC LIMIT 1",
            ("QM5_%d" % ea, logical)).fetchone()
        if row is None:
            rec["seal"] = {"status": "MISSING"}
        else:
            wid, setp, evp, dbsha, upd = row
            seal_path = Path(evp)
            seal = json.loads(seal_path.read_text(encoding="utf-8"))
            ident = seal.get("identities", {})
            srcp = Path(setp)
            tf = re.search(r"_((?:M|H)\d+|D1|W1|MN1)(?:_|\.)", srcp.name)
            rec["seal"] = {
                "work_item_id": wid, "updated_at": upd,
                "seal_path": str(seal_path), "seal_sha256": sha(seal_path),
                "seal_schema": seal.get("schema_version"), "verdict": seal.get("verdict"),
                "source_setfile": str(srcp), "source_exists": srcp.is_file(),
                "source_sha256_actual": sha(srcp) if srcp.is_file() else None,
                "source_sha256_seal": ident.get("baseline_setfile_sha256"),
                "source_sha256_db": dbsha,
                "seal_ex5_sha256": ident.get("ex5_sha256"),
                "timeframe": tf.group(1) if tf else None,
                "chosen_news_config": seal.get("chosen_config"),
                "status": "OK",
            }

        bins = []
        for d in sorted((REPO / "framework/EAs").glob("QM5_%d_*" % ea)):
            bins += sorted(d.glob("QM5_%d_*.ex5" % ea))
        rec["binaries"] = [{"path": str(b), "sha256": sha(b), "bytes": b.stat().st_size}
                           for b in bins]

        q08 = conn.execute(
            "SELECT id,phase,verdict,ex5_sha256,setfile_path,setfile_sha256,updated_at "
            "FROM work_items WHERE ea_id=? AND symbol=? AND phase LIKE 'Q08%' "
            "AND status='done' AND verdict='PASS' ORDER BY updated_at DESC LIMIT 1",
            ("QM5_%d" % ea, logical)).fetchone()
        rec["q08"] = (None if q08 is None else
                      {"work_item_id": q08[0], "phase": q08[1], "verdict": q08[2],
                       "ex5_sha256": q08[3], "setfile_path": q08[4],
                       "setfile_sha256": q08[5], "updated_at": q08[6]})

        rec["w38_stream"] = snap_streams.get("%d:%s" % (ea, logical))
        sp = W38 / "snapshot_r2/streams/QM/q08_trades" / ("%d_%s_DWX.jsonl" % (ea, sym))
        magics, n = set(), 0
        if sp.is_file():
            for line in sp.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    n += 1
                    try:
                        magics.add(json.loads(line).get("magic"))
                    except json.JSONDecodeError:
                        pass
        rec["stream_observed"] = {"path": str(sp), "exists": sp.is_file(), "trades": n,
                                  "magics": sorted(m for m in magics if m is not None),
                                  "sha256": sha(sp) if sp.is_file() else None}

        r = reg.get((ea, logical))
        rec["magic_registry"] = (None if r is None else
                                 {"symbol_slot": int(r["symbol_slot"]),
                                  "magic": int(r["magic"]), "status": r["status"],
                                  "ea_slug": r["ea_slug"]})
        rec["roster_v2b"] = v2b.get((ea, logical))

        venue = ftmo_alias.get(logical)
        guess = venue or sym
        ev = []
        if venue:
            ev.append("execution_symbol_aliases_v1.json FTMO_TRIAL (account %s)" % alias_account)
        if guess in ticks:
            ev.append("bases/FTMO-Demo/ticks")
        if guess in hist:
            ev.append("bases/FTMO-Demo/history")
        if guess in logs:
            ev.append("terminal logs x%d" % logs[guess])
        attached = [c for c in chart_raw if c["symbol"] == guess]
        if attached:
            ev.append("currently attached chart " + ",".join(c["chart"] for c in attached))
        rec["venue"] = {"venue_symbol": guess, "from_alias_registry": bool(venue),
                        "in_ticks": guess in ticks, "in_history": guess in hist,
                        "log_hits": logs.get(guess, 0), "evidence": ev,
                        "verified": bool(guess in ticks and guess in hist)}
        sleeves.append(rec)

    out = {
        "schema": "qm.ftmo-demo-recompose-facts/v1",
        "roster_label": "R2_capped",
        "risk_percent_per_sleeve": 0.3125,
        "book_risk_percent": 2.5,
        "account": {"login": 1514536732, "server": "FTMO-Demo",
                    "variant": "STANDARD_2STEP_100K_FREE_TRIAL",
                    "governor_ea": 13206, "terminal": str(TERM)},
        "alias_registry_account_id": alias_account,
        "current_profile": {"roster_hash": current_hash, "sleeves": current,
                            "charts": chart_raw},
        "target_sleeves": sleeves,
    }
    (OUT / "facts.json").write_text(json.dumps(out, indent=2, default=str) + "\n",
                                    encoding="utf-8")
    print(json.dumps({"sleeves": len(sleeves), "out": str(OUT / "facts.json")}))


if __name__ == "__main__":
    main()
