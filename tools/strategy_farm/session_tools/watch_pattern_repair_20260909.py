"""Finite native acceptance watcher. No DB writes, claims, kills or gate edits."""
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parents[3]
OUT = Path("D:/QM/reports/pattern_permission_repair/20260909T120140Z_da3b526d")
DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
ID = "b05e2e28-13d9-4e93-95a0-4c7e7b0510a3"
TESTS = [
    "framework/scripts/tests/test_pattern_permission_contract.py",
    "framework/scripts/tests/test_pattern_fixture_coverage.py",
    "framework/scripts/tests/test_collect_pattern_fixture_harness_results.py",
    "framework/scripts/tests/test_pattern_warmup_audit.py",
    "tools/strategy_farm/tests/test_pattern_permission_framework_wiring.py",
    "tools/strategy_farm/tests/test_pattern_fixture_harness_dispatch.py",
    "tools/strategy_farm/tests/test_pattern_fixture_repair_integration.py",
    "tools/strategy_farm/tests/test_pattern_repair_semantics.py",
    "tools/strategy_farm/tests/test_opt_census.py",
    "tools/strategy_farm/tests/test_opt_census_select.py",
    "tools/strategy_farm/tests/test_opt_census_pruning.py",
    "tools/strategy_farm/tests/test_dl089_prescreen.py",
    "tools/strategy_farm/tests/test_dl089_prescreen_retro.py",
    "tools/strategy_farm/tests/test_pattern_fire_count.py",
    "tools/strategy_farm/tests/test_tester_memory_admission.py",
    "tools/strategy_farm/tests/test_tester_memory_ledger.py",
    "tools/strategy_farm/tests/test_tester_memory_per_ea_expectations.py",
]
PIN_PATHS = TESTS + ["framework/include/QM/QM_PatternPermission.mqh",
    "framework/scripts/collect_pattern_fixture_harness_results.py",
    "framework/tests/fixtures/pattern_permission/_bundle/pattern_fixtures.csv",
    "tools/strategy_farm/research/pattern_fire_count.py", "tools/strategy_farm/dl089_prescreen.py",
    "tools/strategy_farm/dl089_prescreen_retro.py", "tools/strategy_farm/farmctl.py", "tools/strategy_farm/terminal_worker.py"]
PIN_PATHS += ["tools/strategy_farm/opt_census.py", "tools/strategy_farm/opt_census_select.py",
              "tools/strategy_farm/opt_census_pruning.py", "framework/scripts/run_smoke.ps1"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    started = time.monotonic()
    pins = {p:sha(REPO / p) for p in PIN_PATHS}
    result = {"schema":"qm.pattern-repair-acceptance/v1", "harness_work_item_id":ID,
              "started_at_utc":dt.datetime.now(dt.timezone.utc).isoformat(), "source_pins":pins,
              "economic_strategy_reruns":0, "live_changes":0}
    previous = None
    while time.monotonic()-started < 3600:
        if any(sha(REPO / p) != value for p,value in pins.items()):
            result["status"] = "SOURCE_DRIFT_STOP"
            break
        with sqlite3.connect(DB.as_uri()+"?mode=ro",uri=True,timeout=5) as db:
            db.row_factory = sqlite3.Row
            row = dict(db.execute("SELECT status,verdict,evidence_path,payload_json FROM work_items WHERE id=?",(ID,)).fetchone())
        state = (row["status"], row["verdict"])
        if state != previous:
            print(json.dumps({"at_utc":dt.datetime.now(dt.timezone.utc).isoformat(),"harness_state":state}),flush=True)
            previous = state
        if row["status"] not in ("pending","active"):
            result["harness"] = {**row, "payload":json.loads(row.pop("payload_json"))}
            result["status"] = "NATIVE_ACCEPTANCE_FAILED"
            if state == ("done","HARNESS_OK"):
                source = Path(row["evidence_path"])
                shutil.copyfile(source, OUT / "native_pattern_fixture_results.csv")
                receipt = source.with_suffix(".receipt.json")
                if receipt.is_file():
                    shutil.copyfile(receipt, OUT / "native_pattern_fixture_results.receipt.json")
                command = [sys.executable,"-m","pytest","-q","-p","no:cacheprovider",*TESTS]
                with (OUT / "acceptance_pytest.log").open("x",encoding="utf-8") as log:
                    proc = subprocess.run(command,cwd=REPO,stdout=log,stderr=subprocess.STDOUT,
                                          env={**os.environ,"PYTHONDONTWRITEBYTECODE":"1"},
                                          creationflags=subprocess.CREATE_NO_WINDOW,timeout=300)
                result.update(status="PASS" if proc.returncode == 0 else "REGRESSION_FAILED",
                              pytest_returncode=proc.returncode,pytest_command=command,
                              native_results_sha256=sha(OUT / "native_pattern_fixture_results.csv"))
            break
        time.sleep(15)
    else:
        result["status"] = "WAITING_NATIVE_RESOURCE_WINDOW"
    result["finished_at_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    with (OUT / "acceptance.json").open("x",encoding="utf-8") as fh:
        json.dump(result,fh,indent=2)
    print(json.dumps({"acceptance":result["status"],"path":str(OUT / "acceptance.json")}),flush=True)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-item-id", default=ID)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    if not args.out.resolve().is_relative_to(OUT.resolve()):
        parser.error("watcher output must remain in this repair artifact directory")
    ID, OUT = args.work_item_id, args.out.resolve()
    OUT.mkdir(parents=True, exist_ok=True)
    main()
