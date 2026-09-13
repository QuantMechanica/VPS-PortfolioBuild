#!/usr/bin/env python3
"""Scan available q08 stream sources for the 26 qualified pairs. READ-ONLY."""
from __future__ import annotations
import json, os, datetime as dt
from pathlib import Path

pool = json.loads(Path(r"D:\QM\reports\portfolio\dxz_v2_20260913\pool.json").read_text(encoding="utf-8"))
pairs = [(int(str(p["ea_id"]).replace("QM5_", "")), p["symbol"]) for p in pool["pairs"]]

ROOTS = {
    "sleeve_streams": Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades"),
    "dxz_final_20260719": Path(r"D:\QM\reports\portfolio\dxz_final_20260719\QM\q08_trades"),
    "dxz25_preview_20260718": Path(r"D:\QM\reports\portfolio\dxz25_preview_20260718\QM\q08_trades"),
    "common_files": Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades"),
}

print(f"{'pair':28s} " + " ".join(f"{k:22s}" for k in ROOTS))
missing = []
for ea, sym in pairs:
    name = f"{ea}_{sym.replace('.', '_')}.jsonl"
    cells = []
    found = False
    for k, root in ROOTS.items():
        p = root / name
        if p.is_file():
            st = p.stat()
            n = sum(1 for line in p.open(encoding="utf-8") if '"TRADE_CLOSED"' in line)
            cells.append(f"{n:5d}tr {dt.datetime.fromtimestamp(st.st_mtime):%Y-%m-%d}")
            found = True
        else:
            cells.append("-".ljust(22))
    if not found:
        missing.append((ea, sym))
    print(f"{ea}:{sym:20s} " + " ".join(c.ljust(22) for c in cells))
print()
print("no stream anywhere:", missing)
