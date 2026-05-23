from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path

from framework.scripts.mt5_queue_status import queue_status
from framework.scripts.queue_init import ensure_schema


class MT5QueueStatusTests(unittest.TestCase):
    def test_queue_status_reports_worker_pool_schema_and_heartbeat(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = Path(tmpdir) / "queue.db"
            conn = sqlite3.connect(str(db_path))
            try:
                ensure_schema(conn)
                conn.execute(
                    """
                    INSERT INTO jobs
                    (job_id,ea_id,version,symbol,period,year,phase,sub_gate_config_hash,setfile_path,status,enqueued_at,enqueued_by)
                    VALUES (?,?,?,?,?,?,?,?,?,?,strftime('%Y-%m-%dT%H:%M:%fZ','now'),?)
                    """,
                    ("job-1", "QM5_1001", "v1", "EURUSD.DWX", "H1", 2024, "P2", "cfg1", "a.set", "queued", "test"),
                )
                conn.execute(
                    """
                    INSERT INTO jobs
                    (job_id,ea_id,version,symbol,period,year,phase,sub_gate_config_hash,setfile_path,status,claimed_by,claimed_at,enqueued_at,enqueued_by)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,strftime('%Y-%m-%dT%H:%M:%fZ','now'),strftime('%Y-%m-%dT%H:%M:%fZ','now'),?)
                    """,
                    ("job-2", "QM5_1002", "v1", "GBPUSD.DWX", "H1", 2024, "P3", "cfg2", "b.set", "running", "T3", "test"),
                )
                conn.execute(
                    """
                    INSERT INTO worker_heartbeat
                    (terminal_id,pid,last_seen_utc,current_job_id,jobs_completed,last_error)
                    VALUES ('T3',1234,strftime('%Y-%m-%dT%H:%M:%fZ','now'),'job-2',7,'')
                    """,
                )
                conn.commit()
            finally:
                conn.close()

            payload = queue_status(db_path, limit=5)
            self.assertTrue(payload["db_exists"])
            self.assertEqual(payload["schema"], "worker_pool")
            self.assertEqual(payload["counts"]["queued"], 1)
            self.assertEqual(payload["counts"]["running"], 1)
            self.assertEqual(payload["queued_top"][0]["symbol"], "EURUSD.DWX")
            self.assertEqual(payload["dispatched_top"][0]["claimed_by"], "T3")
            self.assertEqual(payload["worker_heartbeat_top"][0]["terminal_id"], "T3")


if __name__ == "__main__":
    unittest.main()
