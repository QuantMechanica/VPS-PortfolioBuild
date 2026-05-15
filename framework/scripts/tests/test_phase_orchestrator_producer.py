from __future__ import annotations

import json
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from framework.scripts import phase_orchestrator as po


class PhaseOrchestratorProducerTests(unittest.TestCase):
    def test_launch_phase_p2_enqueues_queue_rows(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            queue_db = Path(tmp) / "mt5_queue.db"
            result = po.launch_phase("QM5_1003", "P2", dry_run=False, queue_sqlite=queue_db)
            self.assertEqual(result["status"], "enqueued")
            self.assertGreater(result["requested"], 0)
            self.assertGreater(result["inserted"], 0)
            self.assertEqual(result["invalid_setfile"], 0)
            self.assertEqual(len(result["inserted_ids"]), result["inserted"])

            dry = po.launch_phase("QM5_1003", "P2", dry_run=True, queue_sqlite=queue_db)
            self.assertEqual(dry["status"], "dry_run_enqueue")
            self.assertGreater(len(dry["symbols"]), 0)

            second = po.launch_phase("QM5_1003", "P2", dry_run=False, queue_sqlite=queue_db)
            self.assertEqual(second["status"], "enqueued")
            self.assertEqual(second["inserted"], 0)
            self.assertGreater(second["skipped_duplicate"], 0)

    @patch("framework.scripts.phase_orchestrator._verify_build_deployment_for_ea")
    def test_launch_phase_p2_is_blocked_when_verifier_fails(self, mock_verify: object) -> None:
        mock_verify.return_value = (False, "build_verify:GHOST_BUILD:rc=1", {"verdict": "GHOST_BUILD"})
        with tempfile.TemporaryDirectory() as tmp:
            queue_db = Path(tmp) / "mt5_queue.db"
            result = po.launch_phase("QM5_1003", "P2", dry_run=False, queue_sqlite=queue_db)
            self.assertEqual(result["status"], "blocked_ghost_build")
            self.assertIn("build_verify:GHOST_BUILD", result["reason"])
            self.assertEqual(result["verifier"]["verdict"], "GHOST_BUILD")

    def test_find_next_phase_uses_pipeline_pass_state(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            old_root = po.PIPELINE_ROOT
            po.PIPELINE_ROOT = Path(tmp)
            try:
                p1_dir = po.PIPELINE_ROOT / "QM5_1003" / "P1"
                p1_dir.mkdir(parents=True, exist_ok=True)
                payload = {"phase": "P1", "ea_id": "QM5_1003", "verdict": "PASS"}
                (p1_dir / "P1_QM5_1003_result.json").write_text(json.dumps(payload), encoding="utf-8")
                next_phase, state, _ = po.find_next_phase("QM5_1003")
                self.assertEqual(next_phase, "P2")
                self.assertIn("ADVANCING", state)
            finally:
                po.PIPELINE_ROOT = old_root

    def test_find_next_phase_prefers_dispatch_state_phase_progress(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            state_path = Path(tmp) / "dispatch_state.json"
            payload = {
                "phase_matrix_index": {
                    "QM5_1003_v1_P1": {"phase_verdict": "PASS"},
                    "QM5_1003_v1_P2": {"phase_verdict": "PASS"},
                }
            }
            state_path.write_text(json.dumps(payload), encoding="utf-8")
            next_phase, state, evidence = po.find_next_phase("QM5_1003", dispatch_state_path=state_path)
            self.assertEqual(next_phase, "P3")
            self.assertIn("ADVANCING", state)
            self.assertEqual(evidence.get("source"), "dispatch_state")

    def test_find_next_phase_blocks_on_dispatch_fail_phase(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            state_path = Path(tmp) / "dispatch_state.json"
            payload = {
                "phase_matrix_index": {
                    "QM5_1003_v1_P1": {"phase_verdict": "PASS"},
                    "QM5_1003_v1_P2": {"phase_verdict": "FAIL_PHASE_P2"},
                }
            }
            state_path.write_text(json.dumps(payload), encoding="utf-8")
            next_phase, state, evidence = po.find_next_phase("QM5_1003", dispatch_state_path=state_path)
            self.assertIsNone(next_phase)
            self.assertIn("BLOCKED at P2", state)
            self.assertIn("dispatch_state_path", evidence)

    def test_cli_execute_enqueues_jobs_into_worker_pool_schema(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out_root = Path(tmp) / "pipeline"
            db_path = Path(tmp) / "mt5_queue.db"
            old_root = po.PIPELINE_ROOT
            po.PIPELINE_ROOT = out_root
            try:
                p1_dir = out_root / "QM5_1003" / "P1"
                p1_dir.mkdir(parents=True, exist_ok=True)
                payload = {"phase": "P1", "ea_id": "QM5_1003", "verdict": "PASS"}
                (p1_dir / "P1_QM5_1003_result.json").write_text(json.dumps(payload), encoding="utf-8")

                cmd = [
                    "python",
                    str(po.REPO_ROOT / "framework" / "scripts" / "phase_orchestrator.py"),
                    "--ea",
                    "QM5_1003",
                    "--execute",
                    "--json",
                    "--pipeline-root",
                    str(out_root),
                    "--queue-sqlite",
                    str(db_path),
                ]
                proc = subprocess.run(cmd, cwd=str(po.REPO_ROOT), capture_output=True, text=True)
                self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")
                decisions = json.loads(proc.stdout)
                self.assertEqual(len(decisions), 1)
                self.assertEqual(decisions[0]["next_phase"], "P2")
                self.assertEqual(decisions[0]["launch"]["status"], "enqueued")

                con = sqlite3.connect(str(db_path))
                try:
                    table_exists = con.execute(
                        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='jobs'"
                    ).fetchone()[0]
                    self.assertEqual(table_exists, 1)
                    rows = con.execute(
                        "SELECT COUNT(*) FROM jobs WHERE ea_id='QM5_1003' AND phase='P2' AND status='queued'"
                    ).fetchone()[0]
                    self.assertGreater(rows, 0)
                finally:
                    con.close()
            finally:
                po.PIPELINE_ROOT = old_root

    def test_cli_execute_does_not_enqueue_when_dispatch_phase_blocked(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out_root = Path(tmp) / "pipeline"
            db_path = Path(tmp) / "mt5_queue.db"
            state_path = Path(tmp) / "dispatch_state.json"
            state_path.write_text(
                json.dumps(
                    {
                        "phase_matrix_index": {
                            "QM5_1003_v1_P1": {"phase_verdict": "PASS"},
                            "QM5_1003_v1_P2": {"phase_verdict": "FAIL_PHASE_P2"},
                        }
                    }
                ),
                encoding="utf-8",
            )
            cmd = [
                "python",
                str(po.REPO_ROOT / "framework" / "scripts" / "phase_orchestrator.py"),
                "--ea",
                "QM5_1003",
                "--execute",
                "--json",
                "--pipeline-root",
                str(out_root),
                "--dispatch-state",
                str(state_path),
                "--queue-sqlite",
                str(db_path),
            ]
            proc = subprocess.run(cmd, cwd=str(po.REPO_ROOT), capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")
            decisions = json.loads(proc.stdout)
            self.assertEqual(len(decisions), 1)
            self.assertIsNone(decisions[0]["next_phase"])
            self.assertIn("BLOCKED at P2", decisions[0]["state"])
            self.assertNotIn("launch", decisions[0])

            con = sqlite3.connect(str(db_path))
            try:
                table_exists = con.execute(
                    "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='jobs'"
                ).fetchone()[0]
                if table_exists:
                    rows = con.execute("SELECT COUNT(*) FROM jobs").fetchone()[0]
                    self.assertEqual(rows, 0)
            finally:
                con.close()


if __name__ == "__main__":
    unittest.main()
