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

    def test_queue_init_schema_columns_match_contract(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = Path(tmpdir) / "mt5_queue.db"
            conn = sqlite3.connect(str(db_path))
            try:
                ensure_schema(conn)
                jobs_cols = [row[1] for row in conn.execute("PRAGMA table_info('jobs')").fetchall()]
                heartbeat_cols = [row[1] for row in conn.execute("PRAGMA table_info('worker_heartbeat')").fetchall()]
            finally:
                conn.close()

            self.assertEqual(
                jobs_cols,
                [
                    "job_id",
                    "ea_id",
                    "version",
                    "symbol",
                    "period",
                    "year",
                    "phase",
                    "sub_gate_config_hash",
                    "setfile_path",
                    "status",
                    "verdict",
                    "invalidation_reason",
                    "claimed_by",
                    "claimed_at",
                    "started_at",
                    "finished_at",
                    "result_path",
                    "retry_count",
                    "enqueued_at",
                    "enqueued_by",
                ],
            )
            self.assertEqual(
                heartbeat_cols,
                [
                    "terminal_id",
                    "pid",
                    "last_seen_utc",
                    "current_job_id",
                    "jobs_completed",
                    "last_error",
                ],
            )

    def test_mt5_worker_refuses_non_factory_terminal_with_required_log_and_exit_code(self) -> None:
        script_path = Path("framework/scripts/mt5_worker.py")
        proc = subprocess.run(
            [
                "python",
                str(script_path),
                "--terminal",
                "T_Live",
                "--sqlite",
                str(Path(".scratch") / "qua1577_test_refuse.db"),
                "--once",
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 2)
        stdout = proc.stdout or ""
        self.assertIn("[REFUSED] terminal is outside factory scope", stdout)
        self.assertIn('"reason": "terminal_out_of_policy"', stdout)

    def test_mt5_worker_once_claims_and_writes_failed_result(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            db_path = root / "mt5_queue.db"
            mt5_root = root / "mt5"
            t1 = mt5_root / "T1"
            (t1 / "MQL5" / "Profiles" / "Tester" / "Groups").mkdir(parents=True, exist_ok=True)
            (t1 / "MQL5" / "Experts" / "QM").mkdir(parents=True, exist_ok=True)
            (t1 / "terminal64.exe").write_text("", encoding="utf-8")
            ((t1 / "MQL5" / "Profiles" / "Tester" / "Groups") / "dummy.txt").write_text("ok", encoding="utf-8")
            ((t1 / "MQL5" / "Experts" / "QM") / "QM5_1003.ex5").write_text("", encoding="utf-8")

            conn = sqlite3.connect(str(db_path))
            try:
                ensure_schema(conn)
                conn.execute(
                    """
                    INSERT INTO jobs(
                      job_id,ea_id,version,symbol,period,year,phase,sub_gate_config_hash,setfile_path,
                      status,enqueued_at,enqueued_by
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,strftime('%Y-%m-%dT%H:%M:%fZ','now'),?)
                    """,
                    (
                        "job-1",
                        "QM5_1003",
                        "v1",
                        "EURUSD.DWX",
                        "H1",
                        2024,
                        "P2",
                        "k1",
                        str(root / "missing.set"),
                        "queued",
                        "manual",
                    ),
                )
                conn.commit()
            finally:
                conn.close()

            proc = subprocess.run(
                [
                    "python",
                    "framework/scripts/mt5_worker.py",
                    "--terminal",
                    "T1",
                    "--sqlite",
                    str(db_path),
                    "--mt5-root",
                    str(mt5_root),
                    "--once",
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(proc.returncode, 0)
            self.assertIn('"status": "failed"', proc.stdout)
            self.assertIn('"job_id": "job-1"', proc.stdout)

            conn = sqlite3.connect(str(db_path))
            try:
                row = conn.execute(
                    "SELECT status,claimed_by,verdict,invalidation_reason FROM jobs WHERE job_id='job-1'"
                ).fetchone()
            finally:
                conn.close()
            self.assertEqual(row[0], "failed")
            self.assertEqual(row[1], "T1")
            self.assertEqual(row[2], "INVALID")
            self.assertIn("deploy_missing:", str(row[3]))

    def test_mt5_worker_once_claims_oldest_queued_row_only(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            db_path = root / "mt5_queue.db"
            mt5_root = root / "mt5"
            t1 = mt5_root / "T1"
            (t1 / "MQL5" / "Profiles" / "Tester" / "Groups").mkdir(parents=True, exist_ok=True)
            (t1 / "MQL5" / "Experts" / "QM").mkdir(parents=True, exist_ok=True)
            (t1 / "terminal64.exe").write_text("", encoding="utf-8")
            ((t1 / "MQL5" / "Profiles" / "Tester" / "Groups") / "dummy.txt").write_text("ok", encoding="utf-8")
            ((t1 / "MQL5" / "Experts" / "QM") / "QM5_1003.ex5").write_text("", encoding="utf-8")

            conn = sqlite3.connect(str(db_path))
            try:
                ensure_schema(conn)
                conn.execute(
                    """
                    INSERT INTO jobs(
                      job_id,ea_id,version,symbol,period,year,phase,sub_gate_config_hash,setfile_path,
                      status,enqueued_at,enqueued_by
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
                    """,
                    (
                        "job-oldest",
                        "QM5_1003",
                        "v1",
                        "EURUSD.DWX",
                        "H1",
                        2024,
                        "P2",
                        "k-oldest",
                        str(root / "missing_oldest.set"),
                        "queued",
                        "2026-01-01T00:00:00Z",
                        "manual",
                    ),
                )
                conn.execute(
                    """
                    INSERT INTO jobs(
                      job_id,ea_id,version,symbol,period,year,phase,sub_gate_config_hash,setfile_path,
                      status,enqueued_at,enqueued_by
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
                    """,
                    (
                        "job-newer",
                        "QM5_1003",
                        "v1",
                        "GBPUSD.DWX",
                        "H1",
                        2024,
                        "P2",
                        "k-newer",
                        str(root / "missing_newer.set"),
                        "queued",
                        "2026-01-01T00:00:01Z",
                        "manual",
                    ),
                )
                conn.commit()
            finally:
                conn.close()

            proc = subprocess.run(
                [
                    "python",
                    "framework/scripts/mt5_worker.py",
                    "--terminal",
                    "T1",
                    "--sqlite",
                    str(db_path),
                    "--mt5-root",
                    str(mt5_root),
                    "--once",
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(proc.returncode, 0)
            self.assertIn('"job_id": "job-oldest"', proc.stdout)

            conn = sqlite3.connect(str(db_path))
            try:
                oldest = conn.execute(
                    "SELECT status,claimed_by,verdict FROM jobs WHERE job_id='job-oldest'"
                ).fetchone()
                newer = conn.execute(
                    "SELECT status,claimed_by,verdict FROM jobs WHERE job_id='job-newer'"
                ).fetchone()
            finally:
                conn.close()
            self.assertEqual(oldest[0], "failed")
            self.assertEqual(oldest[1], "T1")
            self.assertEqual(oldest[2], "INVALID")
            self.assertEqual(newer[0], "queued")
            self.assertIsNone(newer[1])
            self.assertIsNone(newer[2])


if __name__ == "__main__":
    unittest.main()
