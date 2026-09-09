"""Append-only adjudication of an actually successful native fixture run.

The source row falsely failed because the new reader expected the file label
in run_smoke's numeric ea_label field. Validate the real expert identity and
append a transparent readjudication; never rewrite or claim another MT5 run.
"""
import hashlib
import json
from pathlib import Path
import shutil
import sqlite3
import uuid

from framework.scripts import collect_pattern_fixture_harness_results as collector
from tools.strategy_farm import farmctl, opt_census
from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock

ROOT = Path("D:/QM/strategy_farm")
SOURCE_ID = "4ae5bebd-f670-4228-a524-b4a735c34c53"
OUT = Path("D:/QM/reports/pattern_permission_repair/20260909T120140Z_da3b526d/readjudication")
ID = str(uuid.uuid5(uuid.NAMESPACE_URL, "qm:pattern-fixture-readjudication:20260909:" + SOURCE_ID))


def digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True).encode()).hexdigest()


def main():
    with FactoryMutationLock(ROOT / "state/FACTORY_MUTATION.lock", owner="pattern-fixture-readjudication-20260909"):
        with sqlite3.connect(ROOT / "state/farm_state.sqlite",timeout=10) as db:
            db.row_factory = sqlite3.Row
            db.execute("BEGIN IMMEDIATE")
            old = dict(db.execute("SELECT * FROM work_items WHERE id=?",(SOURCE_ID,)).fetchone())
            before = digest(old)
            payload = json.loads(old["payload_json"])
            if (old["kind"] != "harness" or old["phase"] != farmctl.HARNESS_PP_FIXTURE_PHASE
                    or old["status"] != "done" or old["verdict"] != "HARNESS_FAIL"
                    or old["claimed_by"] is not None
                    or payload.get("harness_verdict_reason") != "collection_error:InvalidResultsError('fixture smoke failed or execution binding changed')"):
                raise ValueError("not the exact false-negative fixture adjudication")
            summary = collector.validate_smoke_summary(Path(payload["report_root"]),payload)
            bundle = Path(payload["bundle_csv_path"])
            csv_path = Path(payload["harness_collection"]["dest_csv"])
            rows = collector.validate_results(csv_path,bundle)
            collection = payload["harness_collection"]
            if (hashlib.sha256(bundle.read_bytes()).hexdigest() != payload["bundle_csv_sha256"]
                    or hashlib.sha256(csv_path.read_bytes()).hexdigest() != collection["results_sha256"]
                    or len(rows) != 535):
                raise ValueError("native fixture evidence changed")
            existing = db.execute("SELECT id FROM work_items WHERE id=?",(ID,)).fetchone()
            if existing:
                opt_census._harness_pass(db,ID)
                db.rollback()
                print(json.dumps({"already_adjudicated":ID}))
                return
            OUT.mkdir(parents=True,exist_ok=False)
            immutable_csv = OUT / "native_pattern_fixture_results.csv"
            shutil.copyfile(csv_path,immutable_csv)
            now = farmctl.utc_now()
            receipt = {"schema":"qm.pattern-fixture-readjudication/v1", "decision":"CEO-DEC-PATTERN-REPAIR-20260909",
                       "source_work_item_id":SOURCE_ID, "source_row_sha256":before, "new_work_item_id":ID,
                       "native_execution_work_item_id":SOURCE_ID, "native_execution_repeated":False,
                       "method":"corrected numeric-label / executable-identity reader; no performance criteria changed",
                       "summary":summary, "native_fixture_count":len(rows), "results_sha256":collection["results_sha256"],
                       "collector_sha256":hashlib.sha256(Path(collector.__file__).read_bytes()).hexdigest(),
                       "created_at_utc":now}
            keep = ("harness_type","harness_ea_label","harness_source_dir","harness_ex5_sha256",
                    "harness_period","harness_year","host_timeframe","from_date","to_date","bundle_csv_path",
                    "bundle_csv_sha256","results_csv_path","report_root","compile_probe_receipt",
                    "expected_ex5_sha256","staged_ex5_path","staged_ex5_sha256")
            new_payload = {k:payload[k] for k in keep}
            new_payload.update(harness_reconciliation=receipt,
                harness_collection={**collection,"dest_csv":str(immutable_csv),"smoke_summary":summary},
                harness_verdict_reason="native_evidence_readjudicated_no_rerun")
            db.execute("""INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,gate_contract_version)
                VALUES(?,?,?,?,?,'','done','HARNESS_OK',0,?,?,NULL,?,?,?,?)""",
                (ID,"harness",farmctl.HARNESS_PP_FIXTURE_PHASE,farmctl.HARNESS_PP_FIXTURE_EA_ID,
                 old["symbol"],SOURCE_ID,str(immutable_csv),json.dumps(new_payload,sort_keys=True),now,now,old["gate_contract_version"]))
            opt_census._harness_pass(db,ID)
            if digest(dict(db.execute("SELECT * FROM work_items WHERE id=?",(SOURCE_ID,)).fetchone())) != before:
                raise ValueError("source row mutation detected")
            with (OUT / "receipt.json").open("x",encoding="utf-8") as fh:
                json.dump(receipt,fh,indent=2)
            db.execute("INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
                       (now,"work_item",ID,"native_fixture_readjudication",json.dumps(receipt,sort_keys=True)))
            db.commit()
            print(json.dumps({"adjudicated":ID,"source_row_unchanged":True,"native_rerun":False,"native_fixture_count":len(rows),"summary":summary},indent=2))


if __name__ == "__main__":
    main()
