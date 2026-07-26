"""ULTRACODE WS-A: recovery-class classifier — provenance + compare-and-swap safety."""
from __future__ import annotations

import gc
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import classify_recovery_pending as crp  # noqa: E402


class ClassifierFixture:
    def __init__(self) -> None:
        self._tmp = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.root = Path(self._tmp.name)
        farmctl.init_db(self.root)
        self.db = self.root / farmctl.DB_REL

    def close(self) -> None:
        gc.collect()  # finalize lingering sqlite connections before rmtree
        self._tmp.cleanup()

    def add(self, wid: str, enqueued_by: str, *, phase: str = "Q02",
            priority_track: bool = False, status: str = "pending", extra: dict | None = None) -> None:
        payload = {"enqueued_by": enqueued_by, "host_symbol": "EURUSD.DWX"}
        if priority_track:
            payload["priority_track"] = True
        if extra:
            payload.update(extra)
        c = sqlite3.connect(self.db)
        c.execute(
            "INSERT INTO work_items (id, kind, phase, ea_id, symbol, setfile_path, status, "
            "verdict, attempt_count, payload_json, created_at, updated_at) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (wid, "backtest", phase, f"QM5_{wid}", "EURUSD.DWX", f"{wid}.set", status, None, 0,
             json.dumps(payload, sort_keys=True), "t", "t"),
        )
        c.commit()
        c.close()

    def payload(self, wid: str) -> dict:
        c = sqlite3.connect(self.db)
        row = c.execute("SELECT payload_json FROM work_items WHERE id=?", (wid,)).fetchone()
        c.close()
        return json.loads(row[0])


class ClassifierTests(unittest.TestCase):
    def _fixture(self) -> ClassifierFixture:
        fx = ClassifierFixture()
        self.addCleanup(fx.close)
        fx.add("s1", "claude_sweep_enqueue_2026-06-10.stranded_infra_fail")
        fx.add("d1", "sweep_enqueue.deferred_promotion")
        fx.add("a1", "record_build_result.auto_q02")
        fx.add("n1", "claude_sweep_enqueue_2026-06-10.never_tested")   # excluded
        fx.add("prio", "sweep_enqueue.deferred_promotion", priority_track=True)  # skipped
        fx.add("q03", "record_build_result.auto_q02", phase="Q03")     # wrong phase
        fx.add("act", "record_build_result.auto_q02", status="active") # not pending
        return fx

    def test_lineage_selection_and_exclusions(self) -> None:
        fx = self._fixture()
        manifest = crp.build_manifest(fx.db, "batchX")
        ids = {e["id"] for e in manifest["entries"]}
        self.assertEqual(ids, {"s1", "d1", "a1"})           # never_tested/priority/q03/active excluded
        self.assertEqual(manifest["census_per_lineage"],
                         {"stranded_infra_fail": 1, "deferred_promotion": 1, "auto_q02": 1})
        self.assertEqual(manifest["skipped"].get("priority_track_skipped"), 1)

    def test_apply_tags_and_revert_restores_exactly(self) -> None:
        fx = self._fixture()
        before = {wid: fx.payload(wid) for wid in ("s1", "d1", "a1", "n1")}
        manifest = crp.build_manifest(fx.db, "batchX")
        res = crp.apply_manifest(fx.db, manifest, revert=False)
        self.assertEqual(res["changed"], 3)
        # Tagged rows now carry the marker; excluded row untouched.
        self.assertEqual(fx.payload("s1")["recovery_class"], "stranded_infra_fail")
        self.assertEqual(fx.payload("a1")["recovery_batch"], "batchX")
        self.assertNotIn("recovery_class", fx.payload("n1"))
        # Marker is claim-detectable.
        self.assertTrue(farmctl.is_recovery_payload(fx.payload("d1")))
        # Revert restores the EXACT pre-image payload.
        rev = crp.apply_manifest(fx.db, manifest, revert=True)
        self.assertEqual(rev["changed"], 3)
        for wid in ("s1", "d1", "a1"):
            self.assertEqual(fx.payload(wid), before[wid])

    def test_cas_refuses_when_payload_changed(self) -> None:
        fx = self._fixture()
        manifest = crp.build_manifest(fx.db, "batchX")
        # Mutate one target's payload AFTER the snapshot -> its pre-image hash no longer matches.
        c = sqlite3.connect(fx.db)
        p = fx.payload("s1")
        p["mutated"] = True
        c.execute("UPDATE work_items SET payload_json=? WHERE id=?",
                  (json.dumps(p, sort_keys=True), "s1"))
        c.commit()
        c.close()
        res = crp.apply_manifest(fx.db, manifest, revert=False)
        self.assertEqual(res["changed"], 2)               # s1 refused
        self.assertEqual(res["cas_mismatch_skipped"], 1)
        self.assertNotIn("recovery_class", fx.payload("s1"))  # untouched
        self.assertTrue(fx.payload("s1")["mutated"])

    def test_apply_idempotent_second_run_is_noop(self) -> None:
        fx = self._fixture()
        manifest = crp.build_manifest(fx.db, "batchX")
        crp.apply_manifest(fx.db, manifest, revert=False)
        # Second apply: pre-image no longer matches (rows now carry the marker) -> 0 changed.
        res2 = crp.apply_manifest(fx.db, manifest, revert=False)
        self.assertEqual(res2["changed"], 0)
        self.assertEqual(res2["cas_mismatch_skipped"], 3)


if __name__ == "__main__":
    unittest.main()
