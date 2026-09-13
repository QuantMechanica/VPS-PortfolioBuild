#!/usr/bin/env python3
"""Reproduce the 26 DXZ-qualified (EA, symbol) pairs and dump pool.json. READ-ONLY."""
from __future__ import annotations
import json, sys
from pathlib import Path

sys.path.insert(0, r"C:\QM\repo")
from tools.strategy_farm import rebaseline_census, gate_manifest
from tools.strategy_farm.phase_ids import ACTIVE_GATE_MANIFEST

DB = "D:/QM/strategy_farm/state/farm_state.sqlite"
terminal = ACTIVE_GATE_MANIFEST.terminal_requalification_gate
print("terminal gate:", terminal)

con = rebaseline_census.open_ro(DB)
pairs = rebaseline_census.build_pairs(con, limit=None)
qual = []
for (ea_id, symbol), record in pairs.items():
    s = rebaseline_census.summarise_pair(record)
    if s["highest_contiguous_valid_gate"] == terminal:
        qual.append((ea_id, symbol, s))
qual.sort(key=lambda x: (int(str(x[0]).replace("QM5_", "")), x[1]))
print("qualified:", len(qual))

rows = []
for ea_id, symbol, s in qual:
    # every work_item row for this pair whose phase resolves to the terminal gate
    cur = con.execute(
        "SELECT id, phase, status, verdict, evidence_path, setfile_path, created_at, updated_at,"
        " ex5_sha256, setfile_sha256, gate_contract_version, payload_json"
        " FROM work_items WHERE ea_id=? AND symbol=? ORDER BY updated_at",
        (ea_id, symbol),
    )
    allrows = [dict(r) for r in cur]
    term_rows = [
        r for r in allrows
        if rebaseline_census.canonical_gate(r["phase"], r["gate_contract_version"]) == terminal
    ]
    q10 = "Q10"
    def pick(rs):
        pas = [r for r in rs if (r["verdict"] or "") in rebaseline_census.PASS_ECON
               and (r["status"] or "").lower() == "done"]
        return pas[-1] if pas else (rs[-1] if rs else None)
    term = pick(term_rows)
    payload = {}
    if term and term.get("payload_json"):
        try:
            payload = json.loads(term["payload_json"])
        except Exception:
            payload = {}
    rows.append({
        "ea_id": ea_id,
        "symbol": symbol,
        "highest_contiguous_valid_gate": s["highest_contiguous_valid_gate"],
        "disposition": s.get("disposition"),
        "terminal_gate": terminal,
        "terminal_work_item_id": term["id"] if term else None,
        "terminal_phase": term["phase"] if term else None,
        "terminal_status": term["status"] if term else None,
        "terminal_verdict": term["verdict"] if term else None,
        "terminal_evidence_path": term["evidence_path"] if term else None,
        "terminal_setfile_path": term["setfile_path"] if term else None,
        "terminal_updated_at": term["updated_at"] if term else None,
        "terminal_ex5_sha256": term["ex5_sha256"] if term else None,
        "terminal_setfile_sha256": term["setfile_sha256"] if term else None,
        "terminal_payload_keys": sorted(payload)[:60],
        "terminal_payload": {k: v for k, v in payload.items() if not isinstance(v, (dict, list))},
        "n_terminal_rows": len(term_rows),
        "all_terminal_verdicts": sorted({(r["verdict"] or "") for r in term_rows}),
    })

out = {
    "schema": "qm.dxz_book_v2_pool/v1",
    "generated_utc": __import__("datetime").datetime.now(__import__("datetime").UTC).isoformat(),
    "db": DB,
    "terminal_requalification_gate": terminal,
    "gate_contract_version": rebaseline_census.ACTIVE_GATE_CONTRACT_VERSION,
    "qualified_pairs": len(rows),
    "pairs": rows,
}
dest = Path(r"D:\QM\reports\portfolio\dxz_v2_20260913\pool.json")
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(json.dumps(out, indent=2, sort_keys=True, default=str) + "\n", encoding="utf-8")
print("wrote", dest)
for r in rows:
    print(r["ea_id"], r["symbol"], r["terminal_verdict"], r["terminal_work_item_id"], r["terminal_evidence_path"])
