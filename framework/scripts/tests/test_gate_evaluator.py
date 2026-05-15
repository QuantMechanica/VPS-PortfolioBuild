from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from framework.scripts.gate_evaluator import evaluate


def _create_jobs_table(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE jobs (
          job_id TEXT PRIMARY KEY,
          ea_id TEXT NOT NULL,
          version TEXT NOT NULL,
          symbol TEXT NOT NULL,
          period TEXT NOT NULL,
          year INTEGER NOT NULL,
          phase TEXT NOT NULL,
          sub_gate_config_hash TEXT NOT NULL,
          setfile_path TEXT NOT NULL,
          status TEXT NOT NULL,
          verdict TEXT,
          invalidation_reason TEXT,
          claimed_by TEXT,
          claimed_at TEXT,
          started_at TEXT,
          finished_at TEXT,
          result_path TEXT,
          retry_count INTEGER NOT NULL DEFAULT 0,
          enqueued_at TEXT NOT NULL,
          enqueued_by TEXT NOT NULL
        )
        """
    )
    conn.commit()


def _insert_job(conn: sqlite3.Connection, **kw: object) -> None:
    conn.execute(
        """
        INSERT INTO jobs
        (job_id, ea_id, version, symbol, period, year, phase, sub_gate_config_hash, setfile_path,
         status, verdict, invalidation_reason, result_path, retry_count, enqueued_at, enqueued_by, finished_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            kw["job_id"],
            "QM5_1003",
            "baseline",
            "EURUSD.DWX",
            "H1",
            2024,
            kw.get("phase", "P2"),
            "cfg001",
            "C:/tmp/x.set",
            kw.get("status", "done"),
            kw.get("verdict", "PASS"),
            kw.get("invalidation_reason", ""),
            str(kw.get("result_path", "D:/QM/reports/pipeline/x/summary.json")),
            kw.get("retry_count", 0),
            "2026-05-15T00:00:00Z",
            "phase_orchestrator",
            "2026-05-15T00:10:00Z",
        ),
    )
    conn.commit()


class GateEvaluatorTests(unittest.TestCase):
    def test_pass_row_enqueues_next_phase_job(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "mt5_queue.db"
            summary = Path(td) / "summary.json"
            summary.write_text('{"trade_count": 5}', encoding="utf-8")
            defaults = Path(td) / "tester_defaults.json"
            defaults.write_text('{"anti_theater_gates":{"min_trade_count":1}}', encoding="utf-8")
            conn = sqlite3.connect(str(db))
            _create_jobs_table(conn)
            _insert_job(conn, job_id="job-pass", verdict="PASS", phase="P2", result_path=str(summary))
            conn.close()

            with patch("framework.scripts.gate_evaluator.run_rollforward_scripts", return_value=(True, "")):
                res = evaluate(
                    sqlite_path=db,
                    max_retries=3,
                    limit=50,
                    paperclip_base="http://127.0.0.1:3100",
                    company_id="cid",
                    project_id="pid",
                    parent_issue_id=None,
                    tester_defaults_path=defaults,
                    dry_run=False,
                )
            self.assertEqual(res.pass_count, 1)

            conn2 = sqlite3.connect(str(db))
            rows = conn2.execute("SELECT job_id, phase, status FROM jobs ORDER BY job_id").fetchall()
            src = conn2.execute("SELECT verdict_processed_at FROM jobs WHERE job_id='job-pass'").fetchone()
            conn2.close()
            self.assertEqual(len(rows), 2)
            self.assertEqual(rows[1][1], "P3")
            self.assertEqual(rows[1][2], "queued")
            self.assertTrue(bool(src and src[0]))

    def test_infra_fail_requeues_before_retry_cap(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "mt5_queue.db"
            conn = sqlite3.connect(str(db))
            _create_jobs_table(conn)
            _insert_job(
                conn,
                job_id="job-retry",
                verdict="INVALID",
                invalidation_reason="no_summary_json:rc=1",
                retry_count=1,
                phase="P2",
            )
            conn.close()

            res = evaluate(
                sqlite_path=db,
                max_retries=3,
                limit=50,
                paperclip_base="http://127.0.0.1:3100",
                company_id="cid",
                project_id="pid",
                parent_issue_id=None,
                tester_defaults_path=Path(td) / "tester_defaults.json",
                dry_run=False,
            )
            self.assertEqual(res.requeued_count, 1)

            conn2 = sqlite3.connect(str(db))
            row = conn2.execute(
                "SELECT status, retry_count, verdict, invalidation_reason FROM jobs WHERE job_id='job-retry'"
            ).fetchone()
            conn2.close()
            assert row is not None
            self.assertEqual(row[0], "queued")
            self.assertEqual(row[1], 2)
            self.assertIsNone(row[2])
            self.assertIsNone(row[3])

    @patch("framework.scripts.gate_evaluator.create_zero_trades_issue")
    def test_min_trades_fail_blocks_and_escalates(self, mock_issue: object) -> None:
        mock_issue.return_value = "QUA-9999"
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "mt5_queue.db"
            conn = sqlite3.connect(str(db))
            _create_jobs_table(conn)
            _insert_job(
                conn,
                job_id="job-zt",
                verdict="FAIL",
                invalidation_reason="run_smoke_fail:MIN_TRADES_NOT_MET",
                retry_count=0,
                phase="P2",
            )
            conn.close()

            res = evaluate(
                sqlite_path=db,
                max_retries=3,
                limit=50,
                paperclip_base="http://127.0.0.1:3100",
                company_id="cid",
                project_id="pid",
                parent_issue_id=None,
                tester_defaults_path=Path(td) / "tester_defaults.json",
                dry_run=False,
            )
            self.assertEqual(res.blocked_strategy_count, 1)

            conn2 = sqlite3.connect(str(db))
            row = conn2.execute(
                "SELECT status, escalation_issue_id, verdict_processed_at FROM jobs WHERE job_id='job-zt'"
            ).fetchone()
            conn2.close()
            assert row is not None
            self.assertEqual(row[0], "blocked_strategy")
            self.assertEqual(row[1], "QUA-9999")
            self.assertTrue(bool(row[2]))

    def test_pass_row_becomes_invalid_when_trade_count_missing(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "mt5_queue.db"
            summary = Path(td) / "summary.json"
            summary.write_text('{"profit_factor": 1.2}', encoding="utf-8")
            defaults = Path(td) / "tester_defaults.json"
            defaults.write_text('{"anti_theater_gates":{"min_trade_count":1}}', encoding="utf-8")
            conn = sqlite3.connect(str(db))
            _create_jobs_table(conn)
            _insert_job(conn, job_id="job-pass-bad", verdict="PASS", phase="P2", result_path=str(summary))
            conn.close()

            res = evaluate(
                sqlite_path=db,
                max_retries=3,
                limit=50,
                paperclip_base="http://127.0.0.1:3100",
                company_id="cid",
                project_id="pid",
                parent_issue_id=None,
                tester_defaults_path=defaults,
                dry_run=False,
            )
            self.assertEqual(res.pass_gate_failed_count, 1)
            conn2 = sqlite3.connect(str(db))
            row = conn2.execute("SELECT status, verdict FROM jobs WHERE job_id='job-pass-bad'").fetchone()
            conn2.close()
            assert row is not None
            self.assertEqual(row[0], "invalid")
            self.assertEqual(row[1], "INVALID")


if __name__ == "__main__":
    unittest.main()
