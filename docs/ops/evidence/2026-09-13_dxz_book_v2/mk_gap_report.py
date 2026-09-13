#!/usr/bin/env python3
"""Emit stream_gaps.json: the 10 qualified pairs with no usable sealed stream, with the
exact reason and the recoverable evidence still on disk."""
from __future__ import annotations
import glob, hashlib, json
from pathlib import Path

BASE = Path(r"D:\QM\reports\portfolio\dxz_v2_20260913")
bundle = json.loads((BASE / "streams" / "bundle_manifest.json").read_text(encoding="utf-8"))


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


gaps = []
for r in bundle["results"]:
    if r.get("outcome") == "bound":
        continue
    rec = {
        "ea_id": r["ea_id"], "symbol": r["symbol"], "status": "STREAM_MISSING",
        "reason": r.get("reason"), "detail": r.get("detail"),
        "q14_verdict": r.get("q14_verdict"), "q14_work_item_id": r.get("q14_work_item_id"),
        "q14_evidence_path": r.get("q14_evidence_path"),
        "q08_work_item_id": r.get("q08_work_item_id"),
        "seal_content_sha256": r.get("seal_content_sha256"),
        "recorded_sealed_path": r.get("recorded_path"),
        "recorded_sealed_path_exists": bool(r.get("recorded_path")) and Path(str(r.get("recorded_path"))).is_file(),
    }
    wid = r.get("q08_work_item_id")
    if wid:
        for p in glob.glob(rf"D:\QM\reports\work_items\{wid}\**\aggregate.json", recursive=True):
            d = json.loads(Path(p).read_text(encoding="utf-8"))
            ps = d.get("portfolio_stream")
            if not isinstance(ps, dict):
                continue
            rep = ps.get("source_report_path")
            rec["q08_aggregate"] = p
            rec["recoverable_mt5_report"] = rep
            rec["recoverable_mt5_report_exists"] = bool(rep) and Path(rep).is_file()
            rec["recoverable_mt5_report_sha256_matches_seal_record"] = (
                bool(rep) and Path(rep).is_file() and sha(rep) == ps.get("source_report_sha256"))
            rec["q08_n_trades"] = ps.get("n")
            rec["q08_summary_json"] = ps.get("source_summary_path")
            rec["source_setfile"] = ps.get("source_setfile_path")
            break
    gaps.append(rec)

out = {
    "schema": "qm.dxz-book-v2-stream-gaps/v1",
    "generated_from": str(BASE / "streams" / "bundle_manifest.json"),
    "n_qualified_pairs": len(bundle["results"]),
    "n_bound": bundle["bound_count"],
    "n_missing": len(gaps),
    "remediation": (
        "For 9 of 10 the Q08 baseline MT5 report.htm still exists and still hashes to the value "
        "recorded in the Q08 aggregate portfolio_stream block; only the JSONL copy at "
        "D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/ was never persisted or was removed. "
        "Cheapest recovery is an append-only Q08 re-run per pair (farmctl enqueue-backtest "
        "--append-only-rerun-of <id>) which re-emits the Common\\Files stream and re-seals it; a "
        "report.htm -> JSONL reconstruction is NOT equivalent (no mae_acct, no notional, no "
        "entry_time, and it would not reproduce the pinned content_sha256). QM5_20266:XTIUSD.DWX "
        "has no Q08 evidence directory at all and needs a full Q08 re-run."),
    "gaps": gaps,
}
dest = BASE / "stream_gaps.json"
dest.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n", encoding="utf-8")
for g in gaps:
    print(g["ea_id"], g["symbol"], g["reason"], "report_ok=", g.get("recoverable_mt5_report_sha256_matches_seal_record"))
print("->", dest)
