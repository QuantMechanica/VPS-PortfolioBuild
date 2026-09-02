#!/usr/bin/env python3
"""Build the non-live, unsigned 2026-09-06 OWNER-session roster scenario."""

import argparse, hashlib, json
from datetime import datetime, timezone
from pathlib import Path
from tools.strategy_farm import generate_live_deployment_pointer as pointer

REMOVE = {(10440,"NDX.DWX"),(13128,"NDX.DWX"),(11708,"EURUSD.DWX"),
          (11132,"SP500.DWX"),(10939,"GBPUSD.DWX"),(10513,"XAUUSD.DWX"),
          (1567,"EURUSD.DWX")}

def main() -> int:
    p=argparse.ArgumentParser(); p.add_argument("--source",required=True); p.add_argument("--out",required=True); p.add_argument("--pointer-out",required=True)
    a=p.parse_args(); source=Path(a.source); out=Path(a.out)
    doc=json.loads(source.read_text(encoding="utf-8-sig")); sleeves=[s for s in doc["sleeves"] if (int(s["ea_id"]),str(s["symbol"])) not in REMOVE]
    doc.update({"status":"DRAFT_OWNER_SESSION_SCENARIO_NOT_LIVE","n_sleeves":len(sleeves),
                "total_risk_pct":round(sum(float(s.get("risk_percent") or 0) for s in sleeves),4),
                "generated_at":datetime.now(timezone.utc).isoformat(),"generated_by":"Codex read-only OWNER-session preparation",
                "approved_by":None,"manual_approval_required":True,"deployment_action":"NONE",
                "autotrading_action":"NONE","sleeves":sleeves,
                "note":"Unsigned candidate only: CONTINUE 1556/10706; remove 13128 and 10440 pending requalification; prune five drag sleeves. OWNER must decide, deploy, and sign."})
    out.parent.mkdir(parents=True,exist_ok=True); out.write_text(json.dumps(doc,indent=2)+"\n",encoding="utf-8")
    pointer_args=argparse.Namespace(manifest=str(out),environment="T_Live/DXZ",expected_account="4000090541",
        expected_server="Darwinex-Live",expected_phase="DXZ_LIVE_CANDIDATE",deployment_epoch_utc="2026-09-06T00:00:00Z",
        written_at_utc=datetime.now(timezone.utc).isoformat(),signed=False,approved_by=None,approval_evidence=None,
        out=a.pointer_out,dry_run=True)
    draft_pointer=pointer.build_pointer(pointer_args); pointer_out=Path(a.pointer_out); pointer_out.parent.mkdir(parents=True,exist_ok=True)
    pointer_out.write_text(json.dumps({"dry_run":True,"planned_epoch_placeholder":True,"pointer":draft_pointer},indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"path":str(out),"sha256":hashlib.sha256(out.read_bytes()).hexdigest(),"sleeves":len(sleeves),"removed":sorted([f"{x}/{y}" for x,y in REMOVE]),"pointer_dry_run":str(pointer_out),"pointer_sha256":hashlib.sha256(pointer_out.read_bytes()).hexdigest()},indent=2)); return 0
if __name__=="__main__": raise SystemExit(main())
