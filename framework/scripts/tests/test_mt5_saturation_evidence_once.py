from __future__ import annotations

import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

from framework.scripts.mt5_saturation_evidence_once import main
from framework.scripts.mt5_saturation_scheduler import ensure_schema
from framework.scripts.pipeline_dispatcher import save_dispatch_state


class MT5SaturationEvidenceOnceTests(unittest.TestCase):
    def test_writes_before_tick_after_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            db_path = root / "queue.db"
            state_path = root / "dispatch_state.json"
            out_path = root / "evidence.json"

            conn = sqlite3.connect(str(db_path))
            try:
                ensure_schema(conn)
                conn.execute(
                    """
                    INSERT INTO mt5_job_queue
                    (ea_id,version,phase,symbol,sub_gate_config_hash,setfile_path,target_terminal,priority,status)
                    VALUES (?,?,?,?,?,?,?,?,?)
                    """,
                    (
                        "QM5_1001",
                        "v1",
                        "P2",
                        "EURUSD.DWX",
                        "cfg001",
                        "framework/EAs/QM5_1001_example/sets/QM5_1001_example_EURUSD.DWX_H1_backtest.set",
                        "any",
                        10,
                        "queued",
                    ),
                )
                conn.commit()
            finally:
                conn.close()

            save_dispatch_state({"running": {"T1": 0, "T2": 0, "T3": 0, "T4": 0, "T5": 0}}, state_path)

            import sys

            argv_prev = sys.argv[:]
            try:
                sys.argv = [
                    "mt5_saturation_evidence_once.py",
                    "--sqlite",
                    str(db_path),
                    "--dispatch-state",
                    str(state_path),
                    "--out",
                    str(out_path),
                ]
                rc = main()
            finally:
                sys.argv = argv_prev

            self.assertEqual(rc, 0)
            self.assertTrue(out_path.exists())
            payload = json.loads(out_path.read_text(encoding="utf-8"))
            self.assertIn("before", payload)
            self.assertIn("tick", payload)
            self.assertIn("after", payload)
            self.assertEqual(payload["tick"]["status"], "ok")
            self.assertEqual(payload["tick"]["scheduled"], 1)


if __name__ == "__main__":
    unittest.main()
