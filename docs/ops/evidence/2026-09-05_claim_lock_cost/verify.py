"""Verify recorded replay evidence without contacting the running factory."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent
before = json.loads((root / "before_controlled.json").read_text())
indexed = json.loads((root / "after_controlled.json").read_text())
after = json.loads((root / "after_review.json").read_text())
assert before["claimed_item_id"] == after["claimed_item_id"]
assert before["result"]["preclaim_payload_sha256"] == after["result"]["preclaim_payload_sha256"]
assert before["snapshot_bytes"] == after["snapshot_bytes"] == 734773248
assert max(after["factory_lock_seconds"]) < 1
assert max(after["write_transaction_seconds"]) < 1
assert not any("earlier_derived" in row["sql"] for row in after["sql"])
plans = json.dumps(indexed["sql"])
assert "idx_work_items_census_earlier" in plans
assert "idx_work_items_census_active_program" in plans
result = {
    "result": "PASS", "snapshot_bytes": before["snapshot_bytes"],
    "before_shared_lock_seconds": before["factory_lock_seconds"],
    "index_only_shared_lock_seconds": indexed["factory_lock_seconds"],
    "after_shared_lock_seconds": after["factory_lock_seconds"],
    "before_write_transaction_seconds": before["write_transaction_seconds"],
    "after_write_transaction_seconds": after["write_transaction_seconds"],
    "same_selected_item_and_payload": True, "full_sort_outside_shared_lock": True,
    "sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
               for p in sorted(root.glob("*.json")) if p.name != "verification.json"},
}
(root / "verification.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
