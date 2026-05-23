from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path

from framework.scripts.mt5_queue_enqueue import enqueue_jobs


class MT5QueueEnqueueTests(unittest.TestCase):
    def test_enqueue_jobs_inserts_queued_rows(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = Path(tmpdir) / "queue.db"
            summary = enqueue_jobs(
                db_path,
                [
                    {
                        "ea_id": "QM5_1001",
                        "version": "v1",
                        "phase": "P2",
                        "symbol": "EURUSD.DWX",
                        "sub_gate_config_hash": "cfg001",
                        "setfile_path": "framework/EAs/QM5_1001_example/sets/QM5_1001_example_EURUSD.DWX_H1_backtest.set",
                        "target_terminal": "any",
                        "priority": 10,
                    }
                ],
            )

            self.assertEqual(summary["status"], "ok")
            self.assertEqual(summary["inserted"], 1)
            self.assertEqual(len(summary["inserted_ids"]), 1)

            conn = sqlite3.connect(str(db_path))
            try:
                row = conn.execute(
                    "SELECT ea_id,phase,symbol,status,priority FROM mt5_job_queue WHERE id=?",
                    (summary["inserted_ids"][0],),
                ).fetchone()
            finally:
                conn.close()

            self.assertEqual(row[0], "QM5_1001")
            self.assertEqual(row[1], "P2")
            self.assertEqual(row[2], "EURUSD.DWX")
            self.assertEqual(row[3], "queued")
            self.assertEqual(row[4], 10)

    def test_enqueue_jobs_rejects_invalid_symbol_and_inserts_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = Path(tmpdir) / "queue.db"
            with self.assertRaises(Exception):
                enqueue_jobs(
                    db_path,
                    [
                        {
                            "ea_id": "QM5_1001",
                            "version": "v1",
                            "phase": "P2",
                            "symbol": "EURUSD",
                            "sub_gate_config_hash": "cfg001",
                            "setfile_path": "framework/EAs/QM5_1001_example/sets/QM5_1001_example_EURUSD.DWX_H1_backtest.set",
                            "target_terminal": "any",
                            "priority": 10,
                        }
                    ],
                )

            conn = sqlite3.connect(str(db_path))
            try:
                count = conn.execute("SELECT COUNT(*) FROM mt5_job_queue").fetchone()[0]
            finally:
                conn.close()
            self.assertEqual(count, 0)


if __name__ == "__main__":
    unittest.main()
