from __future__ import annotations

import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path

from framework.scripts.queue_init import ensure_schema


class QUA1577WorkerPoolTests(unittest.TestCase):
    def test_queue_init_creates_jobs_and_worker_heartbeat_schema(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = Path(tmpdir) / "mt5_queue.db"
            conn = sqlite3.connect(str(db_path))
            try:
                ensure_schema(conn)

                tables = {
                    row[0]
                    for row in conn.execute(
                        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('jobs','worker_heartbeat')"
                    ).fetchall()
                }
                self.assertEqual(tables, {"jobs", "worker_heartbeat"})

                idx_rows = conn.execute("PRAGMA index_list('jobs')").fetchall()
                idx_names = {str(row[1]) for row in idx_rows}
                self.assertIn("idx_jobs_status", idx_names)
                self.assertIn("idx_jobs_claimed_by", idx_names)
                self.assertIn("idx_jobs_dedup", idx_names)

                claimed_by_sql = conn.execute(
                    "SELECT sql FROM sqlite_master WHERE type='index' AND name='idx_jobs_claimed_by'"
                ).fetchone()[0]
                self.assertIn("WHERE claimed_by IS NOT NULL", claimed_by_sql)
            finally:
                conn.close()

    def test_mt5_worker_refuses_t6_with_required_log_and_exit_code(self) -> None:
        script_path = Path("framework/scripts/mt5_worker.py")
        proc = subprocess.run(
            [
                "python",
                str(script_path),
                "--terminal",
                "T6",
                "--sqlite",
                str(Path(".scratch") / "qua1577_test_refuse.db"),
                "--once",
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 2)
        stdout = proc.stdout or ""
        self.assertIn("[REFUSED] T6 is OFF LIMITS", stdout)
        self.assertIn('"reason": "terminal_out_of_policy"', stdout)


if __name__ == "__main__":
    unittest.main()
