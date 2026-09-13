#!/usr/bin/env python3
"""For each refused pair, locate the Q08 portfolio_stream block and check whether the
pinned source report.htm / summary.json still exist with their pinned hashes. READ-ONLY."""
from __future__ import annotations
import glob, hashlib, json, sys
from pathlib import Path
sys.path.insert(0, r"C:\QM\repo")
from tools.strategy_farm import assemble_stream_bundle as asb

REFUSED = [
    ("QM5_10145", "XAUUSD.DWX"), ("QM5_10403", "XAUUSD.DWX"), ("QM5_10513", "XAUUSD.DWX"),
    ("QM5_11660", "NDX.DWX"), ("QM5_12849", "XTIUSD.DWX"), ("QM5_12855", "XTIUSD.DWX"),
    ("QM5_20266", "XTIUSD.DWX"), ("QM5_21501", "USDJPY.DWX"), ("QM5_21507", "XAUUSD.DWX"),
    ("QM5_9641", "WS30.DWX"),
]

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()

con = asb.open_ro(Path(r"D:\QM\strategy_farm\state\farm_state.sqlite"))
for ea, sym in REFUSED:
    rows = [dict(r) for r in con.execute(
        "SELECT id, phase, status, verdict, updated_at FROM work_items"
        " WHERE ea_id=? AND symbol=? AND phase LIKE 'Q08%' AND lower(status)='done'"
        " ORDER BY updated_at DESC", (ea, sym))]
    print(f"=== {ea}:{sym}  ({len(rows)} Q08 done rows)")
    for r in rows[:4]:
        found = glob.glob(rf"D:\QM\reports\work_items\{r['id']}\**\aggregate.json", recursive=True)
        for p in found:
            try:
                d = json.load(open(p, encoding="utf-8"))
            except Exception as e:
                print("   parse fail", p, e); continue
            ps = d.get("portfolio_stream")
            if not isinstance(ps, dict):
                continue
            rep = ps.get("source_report_path")
            ok = None
            if rep and Path(rep).is_file():
                ok = (sha(rep) == ps.get("source_report_sha256"))
            print(f"   wi={r['id']} verdict={r['verdict']} n={ps.get('n')} "
                  f"ex5={str(ps.get('source_ex5_sha256'))[:12]} sealed={str(ps.get('content_sha256'))[:12]}")
            print(f"      sealed_path_exists={Path(str(ps.get('path'))).is_file()}  report_exists={bool(rep) and Path(rep).is_file()} report_sha_ok={ok}")
            print(f"      report={rep}")
