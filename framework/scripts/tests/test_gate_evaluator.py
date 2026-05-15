from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from framework.scripts.gate_evaluator import (
    evaluate,
    infer_ea_slug,
    run_rollforward_scripts,
)


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
          escalation_issue_id TEXT,
          source_issue_id TEXT,
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
         status, verdict, invalidation_reason, result_path, retry_count, escalation_issue_id, source_issue_id, enqueued_at, enqueued_by, finished_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
            str(kw.get("escalation_issue_id", "")),
            str(kw.get("source_issue_id", "")),
            "2026-05-15T00:00:00Z",
            "phase_orchestrator",
            "2026-05-15T00:10:00Z",
        ),
    )
    conn.commit()


class GateEvaluatorTests(unittest.TestCase):
    def test_legacy_schema_without_optional_columns_is_supported(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "mt5_queue.db"
            conn = sqlite3.connect(str(db))
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
            conn.execute(
                """
                INSERT INTO jobs
                (job_id, ea_id, version, symbol, period, year, phase, sub_gate_config_hash, setfile_path,
                 status, verdict, invalidation_reason, result_path, retry_count, enqueued_at, enqueued_by, finished_at)
                VALUES
                ('legacy-1','QM5_1003','baseline','EURUSD.DWX','H1',2024,'P2','cfg001','C:/tmp/x.set',
                 'done','INVALID','REPORT_MISSING','D:/QM/reports/pipeline/x/summary.json',0,
                 '2026-05-15T00:00:00Z','phase_orchestrator','2026-05-15T00:10:00Z')
                """
            )
            conn.commit()
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
                zero_trades_template_path=Path(td) / "missing_template.md",
                dry_run=True,
            )
            self.assertEqual(res.processed, 1)
            self.assertEqual(res.requeued_count, 1)

    def test_infer_ea_slug_from_setfile_path(self) -> None:
        slug = infer_ea_slug(
            setfile_path=r"C:\QM\repo\framework\EAs\QM5_1003_davey_baseline_3bar\sets\QM5_1003_XAUUSD.DWX_H1_backtest.set",
            ea_id="1003",
        )
        self.assertEqual(slug, "QM5_1003_davey_baseline_3bar")

    @patch("subprocess.run")
    def test_run_rollforward_uses_deploy_eapath(self, mock_run: object) -> None:
        class _R:
            returncode = 0
            stdout = ""
            stderr = ""

        mock_run.return_value = _R()
        ok, reason = run_rollforward_scripts(
            ea_id="1003",
            setfile_path=r"C:\QM\repo\framework\EAs\QM5_1003_davey_baseline_3bar\sets\QM5_1003_XAUUSD.DWX_H1_backtest.set",
            symbol="XAUUSD.DWX",
            period="H1",
            next_phase="P3",
            dry_run=False,
        )
        self.assertTrue(ok)
        self.assertEqual(reason, "")
        self.assertGreaterEqual(len(mock_run.call_args_list), 2)
        deploy_cmd = mock_run.call_args_list[1][0][0]
        self.assertIn("-EaPath", deploy_cmd)
        self.assertIn(r"C:\QM\repo\framework\EAs\QM5_1003_davey_baseline_3bar\QM5_1003_davey_baseline_3bar.ex5", deploy_cmd)

    def test_done_row_with_missing_verdict_is_requeued(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "mt5_queue.db"
            conn = sqlite3.connect(str(db))
            _create_jobs_table(conn)
            _insert_job(
                conn,
                job_id="job-missing-verdict",
                verdict="",
                invalidation_reason="",
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
                zero_trades_template_path=Path(td) / "missing_template.md",
                dry_run=False,
            )
            self.assertEqual(res.requeued_count, 1)
            conn2 = sqlite3.connect(str(db))
            row = conn2.execute(
                "SELECT status, retry_count, verdict, invalidation_reason FROM jobs WHERE job_id='job-missing-verdict'"
            ).fetchone()
            conn2.close()
            assert row is not None
            self.assertEqual(row[0], "queued")
            self.assertEqual(row[1], 1)
            self.assertIsNone(row[2])
            self.assertIsNone(row[3])

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
                zero_trades_template_path=Path(td) / "missing_template.md",
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

    @patch("framework.scripts.gate_evaluator.run_build_deployment_verifier")
    @patch("framework.scripts.gate_evaluator.reopen_issue_and_comment")
    def test_p0_pass_is_blocked_when_build_verifier_fails(self, mock_reopen: object, mock_verify: object) -> None:
        mock_verify.return_value = (False, "build_verify:GHOST_BUILD:rc=1", {"verdict": "GHOST_BUILD"})
        mock_reopen.return_value = True
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "mt5_queue.db"
            conn = sqlite3.connect(str(db))
            _create_jobs_table(conn)
            _insert_job(conn, job_id="job-p0-ghost", verdict="PASS", phase="P0", source_issue_id="QUA-1000")
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
                zero_trades_template_path=Path(td) / "missing_template.md",
                dry_run=False,
            )
            self.assertEqual(res.pass_gate_failed_count, 1)

            conn2 = sqlite3.connect(str(db))
            row = conn2.execute(
                "SELECT status, verdict, invalidation_reason FROM jobs WHERE job_id='job-p0-ghost'"
            ).fetchone()
            queued = conn2.execute("SELECT COUNT(*) FROM jobs WHERE status='queued'").fetchone()
            conn2.close()
            assert row is not None and queued is not None
            self.assertEqual(row[0], "invalid")
            self.assertEqual(row[1], "GHOST_BUILD")
            self.assertIn("build_verify:GHOST_BUILD", row[2])
            self.assertEqual(queued[0], 0)
            mock_reopen.assert_called_once()

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
                zero_trades_template_path=Path(td) / "missing_template.md",
                dry_run=False,
            )
            self.assertEqual(res.requeued_count, 1)

            conn2 = sqlite3.connect(str(db))
            row = conn2.execute(
                "SELECT status, retry_count, verdict, invalidation_reason, verdict_processed_at FROM jobs WHERE job_id='job-retry'"
            ).fetchone()
            conn2.close()
            assert row is not None
            self.assertEqual(row[0], "queued")
            self.assertEqual(row[1], 2)
            self.assertIsNone(row[2])
            self.assertIsNone(row[3])
            self.assertIsNone(row[4])

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
                zero_trades_template_path=Path(td) / "missing_template.md",
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
                zero_trades_template_path=Path(td) / "missing_template.md",
                dry_run=False,
            )
            self.assertEqual(res.pass_gate_failed_count, 1)
            conn2 = sqlite3.connect(str(db))
            row = conn2.execute("SELECT status, verdict FROM jobs WHERE job_id='job-pass-bad'").fetchone()
            conn2.close()
            assert row is not None
            self.assertEqual(row[0], "invalid")
            self.assertEqual(row[1], "INVALID")

    @patch("urllib.request.urlopen")
    def test_zero_trades_uses_template_when_available(self, mock_urlopen: object) -> None:
        class _Resp:
            def __enter__(self) -> "_Resp":
                return self

            def __exit__(self, exc_type: object, exc: object, tb: object) -> bool:
                return False

            def read(self) -> bytes:
                return b'{"id":"ISSUE-1"}'

        mock_urlopen.return_value = _Resp()
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "mt5_queue.db"
            template = Path(td) / "zero_trades_dispatch_template.md"
            template.write_text("ZT {ea_id} {phase} {symbol} {source_job_id}", encoding="utf-8")
            conn = sqlite3.connect(str(db))
            _create_jobs_table(conn)
            _insert_job(
                conn,
                job_id="job-zt-template",
                verdict="FAIL",
                invalidation_reason="run_smoke_fail:MIN_TRADES_NOT_MET",
                retry_count=0,
                phase="P2",
            )
            conn.close()

            _ = evaluate(
                sqlite_path=db,
                max_retries=3,
                limit=50,
                paperclip_base="http://127.0.0.1:3100",
                company_id="cid",
                project_id="pid",
                parent_issue_id=None,
                tester_defaults_path=Path(td) / "tester_defaults.json",
                zero_trades_template_path=template,
                dry_run=False,
            )

            call_args = mock_urlopen.call_args
            self.assertIsNotNone(call_args)
            req = call_args[0][0]
            payload = req.data.decode("utf-8")
            self.assertIn("ZT QM5_1003 P2 EURUSD.DWX job-zt-template", payload)

    @patch("framework.scripts.gate_evaluator.create_zero_trades_issue")
    def test_zero_trades_skips_duplicate_issue_when_escalation_present(self, mock_create: object) -> None:
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "mt5_queue.db"
            conn = sqlite3.connect(str(db))
            _create_jobs_table(conn)
            _insert_job(
                conn,
                job_id="job-zt-existing",
                verdict="FAIL",
                invalidation_reason="run_smoke_fail:MIN_TRADES_NOT_MET",
                escalation_issue_id="QUA-1234",
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
                zero_trades_template_path=Path(td) / "missing_template.md",
                dry_run=False,
            )
            self.assertEqual(res.blocked_strategy_count, 1)
            mock_create.assert_not_called()

            conn2 = sqlite3.connect(str(db))
            row = conn2.execute(
                "SELECT status, escalation_issue_id FROM jobs WHERE job_id='job-zt-existing'"
            ).fetchone()
            conn2.close()
            assert row is not None
            self.assertEqual(row[0], "blocked_strategy")
            self.assertEqual(row[1], "QUA-1234")

    def test_infra_fail_marks_failed_terminal_at_retry_cap(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "mt5_queue.db"
            conn = sqlite3.connect(str(db))
            _create_jobs_table(conn)
            _insert_job(
                conn,
                job_id="job-retry-cap",
                verdict="INVALID",
                invalidation_reason="REPORT_MISSING",
                retry_count=2,
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
                zero_trades_template_path=Path(td) / "missing_template.md",
                dry_run=False,
            )
            self.assertEqual(res.failed_terminal_count, 1)
            conn2 = sqlite3.connect(str(db))
            row = conn2.execute(
                "SELECT status, retry_count, verdict_processed_at FROM jobs WHERE job_id='job-retry-cap'"
            ).fetchone()
            conn2.close()
            assert row is not None
            self.assertEqual(row[0], "failed_terminal")
            self.assertEqual(row[1], 3)
            self.assertTrue(bool(row[2]))

    def test_pass_row_marks_failed_terminal_when_rollforward_fails(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "mt5_queue.db"
            summary = Path(td) / "summary.json"
            summary.write_text('{"trade_count": 5}', encoding="utf-8")
            defaults = Path(td) / "tester_defaults.json"
            defaults.write_text('{"anti_theater_gates":{"min_trade_count":1}}', encoding="utf-8")
            conn = sqlite3.connect(str(db))
            _create_jobs_table(conn)
            _insert_job(conn, job_id="job-roll-fail", verdict="PASS", phase="P2", result_path=str(summary))
            conn.close()

            with patch("framework.scripts.gate_evaluator.run_rollforward_scripts", return_value=(False, "deploy_failed")):
                res = evaluate(
                    sqlite_path=db,
                    max_retries=3,
                    limit=50,
                    paperclip_base="http://127.0.0.1:3100",
                    company_id="cid",
                    project_id="pid",
                    parent_issue_id=None,
                    tester_defaults_path=defaults,
                    zero_trades_template_path=Path(td) / "missing_template.md",
                    dry_run=False,
                )
            self.assertEqual(res.rollforward_failed_count, 1)
            conn2 = sqlite3.connect(str(db))
            row = conn2.execute(
                "SELECT status, invalidation_reason FROM jobs WHERE job_id='job-roll-fail'"
            ).fetchone()
            cnt = conn2.execute("SELECT COUNT(*) FROM jobs").fetchone()
            conn2.close()
            assert row is not None and cnt is not None
            self.assertEqual(row[0], "failed_terminal")
            self.assertEqual(row[1], "deploy_failed")
            self.assertEqual(cnt[0], 1)

    def test_dry_run_does_not_mutate_rows(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "mt5_queue.db"
            summary = Path(td) / "summary.json"
            summary.write_text('{"trade_count": 5}', encoding="utf-8")
            defaults = Path(td) / "tester_defaults.json"
            defaults.write_text('{"anti_theater_gates":{"min_trade_count":1}}', encoding="utf-8")
            conn = sqlite3.connect(str(db))
            _create_jobs_table(conn)
            _insert_job(conn, job_id="job-dry", verdict="PASS", phase="P2", result_path=str(summary))
            before = conn.execute(
                "SELECT status, verdict, retry_count FROM jobs WHERE job_id='job-dry'"
            ).fetchone()
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
                    zero_trades_template_path=Path(td) / "missing_template.md",
                    dry_run=True,
                )
            self.assertEqual(res.processed, 1)

            conn2 = sqlite3.connect(str(db))
            after = conn2.execute(
                "SELECT status, verdict, retry_count FROM jobs WHERE job_id='job-dry'"
            ).fetchone()
            cols = [str(r[1]) for r in conn2.execute("PRAGMA table_info(jobs)").fetchall()]
            count = conn2.execute("SELECT COUNT(*) FROM jobs").fetchone()
            conn2.close()
            self.assertEqual(before, after)
            self.assertNotIn("verdict_processed_at", cols)
            assert count is not None
            self.assertEqual(count[0], 1)


if __name__ == "__main__":
    unittest.main()
