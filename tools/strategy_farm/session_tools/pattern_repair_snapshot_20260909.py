"""Read-only factory snapshot; writes a new repair evidence artifact, not gates."""
import argparse
from collections import Counter
import datetime as dt
import hashlib
import json
from pathlib import Path
import sqlite3

DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
ARTIFACTS = Path("D:/QM/strategy_farm/artifacts/opt_census")
HARNESS = "b05e2e28-13d9-4e93-95a0-4c7e7b0510a3"
FOLLOWUP = "4ae5bebd-f670-4228-a524-b4a735c34c53"
READJUDICATION = "ccd5acb4-af10-51ce-8b64-8953a6cb2a4b"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot():
    programs = []
    with sqlite3.connect(DB.as_uri()+"?mode=ro", uri=True, timeout=10) as db:
        db.row_factory = sqlite3.Row
        db.execute("BEGIN")
        rows = db.execute("SELECT id,ea_id,symbol,status,verdict,evidence_path,payload_json FROM work_items WHERE phase='Q12'").fetchall()
        for row in rows:
            payload = json.loads(row["payload_json"] or "{}")
            declaration = payload.get("pattern_filter_sweep") or {}
            program = declaration.get("program_id")
            if not program:
                continue
            ledger_path = ARTIFACTS / program / "ledger.json"
            if not ledger_path.is_file():
                continue
            ledger_raw = ledger_path.read_bytes()
            ledger = json.loads(ledger_raw)
            if ledger.get("q12_work_item_id") != row["id"]:
                continue  # not the owning request (e.g. legacy duplicate)
            counts, corrected_counts = Counter(), Counter()
            skipped_ids, affected_measured = [], []
            for cell in ledger.get("cells", []):
                wi = db.execute("SELECT id,status,verdict FROM work_items WHERE id=?", (cell["work_item_id"],)).fetchone()
                hold = db.execute("SELECT hold_code FROM work_item_holds WHERE work_item_id=? AND active=1", (cell["work_item_id"],)).fetchone()
                disposition = "NOT_MATERIALIZED" if wi is None else wi["verdict"] or wi["status"]
                if hold and hold["hold_code"] == "PRESCREEN_SKIPPED":
                    disposition = "PRESCREEN_HELD_UNMEASURED"
                counts[disposition] += 1
                if disposition in {"PRESCREEN_HELD_UNMEASURED", "SKIPPED_PRESCREEN"}:
                    skipped_ids.append(cell["work_item_id"])
                if cell.get("predicate_id") in (33, 34):
                    corrected_counts[disposition] += 1
                    if disposition == "MEASURED":
                        affected_measured.append(cell["work_item_id"])
            q12_evidence = Path(row["evidence_path"]) if row["evidence_path"] else None
            programs.append({"subject_ea_id":row["ea_id"], "measurement_ea_id":ledger["ea_id"],
                "symbol":row["symbol"], "program_id":program, "q12_owner":row["id"],
                "q12_status":row["status"], "historical_verdict":row["verdict"],
                "ledger_path":str(ledger_path), "ledger_sha256_at_snapshot":hashlib.sha256(ledger_raw).hexdigest(),
                "ledger_changed_during_read":ledger_raw != ledger_path.read_bytes(),
                "q12_evidence_path":str(q12_evidence) if q12_evidence else None,
                "q12_evidence_sha256":sha(q12_evidence) if q12_evidence and q12_evidence.is_file() else None,
                "annual_dispositions":dict(counts), "pattern_33_34_dispositions":dict(corrected_counts),
                "prescreen_unmeasured_count":len(skipped_ids), "wrong_pattern_measured_count":len(affected_measured),
                "recovery_status":"SEPARATE_NATIVE_LINEAGE_REQUIRED",
                "reuse_without_frozen_include_closure_proof":False,
                **({"prescreen_unmeasured_ids":skipped_ids, "wrong_pattern_measured_ids":affected_measured}
                   if row["ea_id"] in ("QM5_13213", "QM5_21501") else {})})
        harness = dict(db.execute("SELECT * FROM work_items WHERE id=?", (HARNESS,)).fetchone())
        harness["payload"] = json.loads(harness.pop("payload_json"))
        followup = dict(db.execute("SELECT * FROM work_items WHERE id=?", (FOLLOWUP,)).fetchone())
        followup["payload"] = json.loads(followup.pop("payload_json"))
        adjudication = dict(db.execute("SELECT * FROM work_items WHERE id=?", (READJUDICATION,)).fetchone())
        adjudication["payload"] = json.loads(adjudication.pop("payload_json"))
        from tools.strategy_farm import opt_census
        native_trust = {}
        for wid in (HARNESS, FOLLOWUP, READJUDICATION):
            try:
                opt_census._harness_pass(db, wid)
                native_trust[wid] = {"state":"ACCEPTED"}
            except opt_census.CensusError as exc:
                native_trust[wid] = {"state":"NOT_ACCEPTED", "reason":str(exc)}
        active = [dict(r) for r in db.execute("SELECT phase,count(*) AS count FROM work_items WHERE status='active' GROUP BY phase")]
    priority = {"QM5_13213":0, "QM5_10706":1, "QM5_11422":2, "QM5_41221":3, "QM5_41219":4, "QM5_21501":5}
    programs.sort(key=lambda p:(priority.get(p["subject_ea_id"], 99),p["program_id"]))
    return {"schema":"qm.pattern-repair-impact/v1", "created_at_utc":dt.datetime.now(dt.timezone.utc).isoformat(),
            "decision":"CEO-DEC-PATTERN-REPAIR-20260909", "database_opened_read_only":True,
            "selection_policy":"original R2DD +5% / 2-of-3-year quorum; measured activity floor unchanged",
            "native_harness":harness, "native_followup":followup, "native_readjudication":adjudication,
            "native_gate_trust":native_trust,
            "active_factory_phases":active,
            "program_count":len(programs), "programs":programs,
            "economic_reruns_enqueued_by_this_repair":0,
            "historic_verdicts_overwritten":0, "strategy_binaries_overwritten":0}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    result = snapshot()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("x", encoding="utf-8") as fh:
        json.dump(result, fh, indent=2)
    print(json.dumps({"path":str(args.out), "program_count":result["program_count"],
                     "harness_status":result["native_harness"]["status"],
                     "harness_verdict":result["native_harness"]["verdict"]}, indent=2))
