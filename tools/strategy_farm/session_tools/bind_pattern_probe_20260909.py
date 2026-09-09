"""One-time pending-only completion of the fixture probe's EX5 bindings.

The immutable source was already declared at enqueue. This supplies the same
source to the worker's general verified-staging gate. No status/verdict changes.
"""
import json
from pathlib import Path
import sqlite3
from tools.strategy_farm import farmctl
from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock
from tools.strategy_farm.pattern_fixture_compile_probe import verify_probe, LABEL

ROOT = Path("D:/QM/strategy_farm")
ID = "b05e2e28-13d9-4e93-95a0-4c7e7b0510a3"
PROBE = Path("D:/QM/reports/pattern_permission_repair/20260909T120140Z_da3b526d")


def main():
    receipt = verify_probe(PROBE)
    with FactoryMutationLock(ROOT / "state/FACTORY_MUTATION.lock", owner="pattern-repair-probe-binding"):
        with sqlite3.connect(ROOT / "state/farm_state.sqlite", timeout=10) as conn:
            conn.row_factory = sqlite3.Row
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute("SELECT * FROM work_items WHERE id=?", (ID,)).fetchone()
            if row["status"] != "pending" or row["claimed_by"] is not None or row["verdict"] is not None:
                raise RuntimeError("probe is no longer pending/unclaimed; preserved")
            before = json.loads(row["payload_json"])
            if before["harness_ex5_sha256"] != receipt["ex5_sha256"] or Path(before["harness_source_dir"]) != PROBE / "MQL5":
                raise ValueError("declared probe changed")
            after = {**before, "staged_ex5_path": str(PROBE / "MQL5" / (LABEL+".ex5")),
                     "host_timeframe":before["harness_period"],
                     "staged_ex5_sha256":receipt["ex5_sha256"], "expected_ex5_sha256":receipt["ex5_sha256"]}
            conn.execute("UPDATE work_items SET payload_json=?,updated_at=? WHERE id=?", (json.dumps(after, sort_keys=True), farmctl.utc_now(), ID))
            conn.execute("INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
                         (farmctl.utc_now(), "work_item", ID, "fixture_probe_staging_binding_completed",
                          json.dumps({"decision":"CEO-DEC-PATTERN-REPAIR-20260909", "before":before, "after":after}, sort_keys=True)))
            conn.commit()
    print(json.dumps({"bound":ID, "ex5_sha256":receipt["ex5_sha256"]}))


if __name__ == "__main__":
    main()
