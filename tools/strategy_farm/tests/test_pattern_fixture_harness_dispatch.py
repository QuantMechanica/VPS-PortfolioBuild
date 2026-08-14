"""Coverage for the kind='harness' work-item route (task 50d5752c-daf2 R1).

Proves: (1) enqueue_pattern_fixture_harness writes a schema-valid work_items
row and deploys the repo bundle CSV into Common\\Files; (2)
_spawn_run_smoke_for_work_item routes a kind='harness' row through the
dedicated harness spawn path -- never through the QM5_<digits> EA-dir glob a
normal backtest needs, which a harness row's sentinel ea_id would fail; (3)
the harness spawn command stages its own .ex5, passes -SkipExpertDeploy and
-MinTrades 0, and never references custom_history_smoke_admission.py or
custom_history_gate.py (those gate modules are exercised unmodified, deep
inside run_smoke.ps1 -- this dispatcher never touches them directly).
"""
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


def _fake_running_process_identity(pid: int) -> dict:
    return {
        "pid": pid,
        "is_running": True,
        "creation_key": f"test-process:{pid}",
        "image_path": "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe",
        "started_at_epoch": 1_700_000_000.0,
    }


def _fake_job_binding(proc, capture_identity, **_kwargs) -> dict:
    identity = capture_identity(proc)
    return {**identity, "job_object_assigned": True, "job_object_mode": "KILL_ON_JOB_CLOSE"}


class PatternFixtureHarnessDispatchTests(unittest.TestCase):
    def setUp(self) -> None:
        old_binding = farmctl.bind_spawned_process_to_kill_job
        old_get_identity = farmctl._capture_spawned_process_identity
        self.addCleanup(setattr, farmctl, "bind_spawned_process_to_kill_job", old_binding)
        self.addCleanup(setattr, farmctl, "_capture_spawned_process_identity", old_get_identity)
        farmctl.bind_spawned_process_to_kill_job = _fake_job_binding
        farmctl._capture_spawned_process_identity = _fake_running_process_identity

    def test_enqueue_writes_schema_valid_harness_row(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            farmctl.init_db(root)
            fake_appdata = Path(tmp) / "appdata"
            source_dir = Path(tmp) / "fixture_src"
            source_dir.mkdir(parents=True)
            (source_dir / f"{farmctl.HARNESS_PP_FIXTURE_EA_LABEL}.ex5").write_text("compiled\n")
            repo_bundle = (
                Path(tmp) / "repo" / "framework" / "tests" / "fixtures"
                / "pattern_permission" / "_bundle" / "pattern_fixtures.csv"
            )
            repo_bundle.parent.mkdir(parents=True)
            repo_bundle.write_text("fixture_id,predicate\n", encoding="utf-8")

            old_source_dir = farmctl.HARNESS_PP_FIXTURE_SOURCE_DIR
            old_repo_root = farmctl.REPO_ROOT
            old_common_files_root = farmctl.COMMON_FILES_ROOT
            try:
                farmctl.HARNESS_PP_FIXTURE_SOURCE_DIR = source_dir
                farmctl.REPO_ROOT = Path(tmp) / "repo"
                farmctl.COMMON_FILES_ROOT = fake_appdata / "MetaQuotes" / "Terminal" / "Common" / "Files"

                result = farmctl.enqueue_pattern_fixture_harness(root, symbol="EURUSD.DWX")
            finally:
                farmctl.HARNESS_PP_FIXTURE_SOURCE_DIR = old_source_dir
                farmctl.REPO_ROOT = old_repo_root
                farmctl.COMMON_FILES_ROOT = old_common_files_root

            self.assertTrue(result["enqueued"])
            deployed_bundle = fake_appdata / "MetaQuotes" / "Terminal" / "Common" / "Files" / "QM" / "pattern_fixtures.csv"
            self.assertTrue(deployed_bundle.is_file())
            self.assertEqual(deployed_bundle.read_text(encoding="utf-8"), "fixture_id,predicate\n")

            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.row_factory = sqlite3.Row
                row = conn.execute(
                    "SELECT * FROM work_items WHERE id=?", (result["work_item_id"],)
                ).fetchone()
            self.assertIsNotNone(row)
            self.assertEqual(row["kind"], "harness")
            self.assertEqual(row["phase"], farmctl.HARNESS_PP_FIXTURE_PHASE)
            self.assertEqual(row["status"], "pending")
            self.assertEqual(row["symbol"], "EURUSD.DWX")
            payload = json.loads(row["payload_json"])
            self.assertEqual(payload["harness_type"], "pattern_permission_fixture")

    def test_spawn_run_smoke_routes_harness_kind_to_dedicated_path(self) -> None:
        """A kind='harness' row must never reach the QM5_<digits> EA-dir glob
        a normal backtest needs -- this row's sentinel ea_id would fail that
        regex, so reaching it would be a crash, not a silent fallback."""
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            source_dir = Path(tmp) / "fixture_src"
            source_dir.mkdir(parents=True)
            harness_label = "QM_pattern_permission_fixture_runner"
            (source_dir / f"{harness_label}.ex5").write_bytes(b"compiled-binary")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            payload = {
                "harness_type": "pattern_permission_fixture",
                "harness_ea_label": harness_label,
                "harness_source_dir": str(source_dir),
                "harness_period": "D1",
                "harness_year": 2024,
                "from_date": "2024.01.02",
                "to_date": "2024.01.10",
                "harness_timeout_seconds": 600,
            }
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                       attempt_count, parent_task_id, evidence_path, claimed_by,
                       payload_json, created_at, updated_at)
                    VALUES
                      ('wi-harness-1', 'harness', ?, 'QM_PP_FIXTURE_HARNESS', 'EURUSD.DWX',
                       '', 'pending', NULL, 0, NULL, NULL, NULL, ?, ?, ?)
                    """,
                    (farmctl.HARNESS_PP_FIXTURE_PHASE, json.dumps(payload), now, now),
                )
                conn.commit()

            spawned_cmds: list[list[str]] = []

            class FakeProc:
                pid = 424242

                def __init__(self, cmd, **_kwargs):
                    spawned_cmds.append([str(part) for part in cmd])

            old_repo_root = farmctl.REPO_ROOT
            old_popen = farmctl.subprocess.Popen
            try:
                farmctl.REPO_ROOT = Path(tmp) / "repo"
                farmctl.subprocess.Popen = FakeProc
                with farmctl.connect(root) as conn:
                    row = conn.execute("SELECT * FROM work_items WHERE id='wi-harness-1'").fetchone()
                result = farmctl._spawn_run_smoke_for_work_item(root, row, "T9")
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.subprocess.Popen = old_popen

            self.assertTrue(result["spawned"], result)
            self.assertEqual(len(spawned_cmds), 1)
            cmd = spawned_cmds[0]

            deployed_ex5 = Path(r"D:\QM\mt5") / "T9" / "MQL5" / "Experts" / "QM" / f"{harness_label}.ex5"
            self.assertTrue(deployed_ex5.is_file(), "harness .ex5 must be staged into the terminal Experts dir")
            deployed_ex5.unlink()  # test cleanup: this path lives outside tmp

            self.assertEqual(cmd[cmd.index("-Expert") + 1], f"QM\\{harness_label}")
            self.assertEqual(cmd[cmd.index("-Symbol") + 1], "EURUSD.DWX")
            self.assertEqual(cmd[cmd.index("-MinTrades") + 1], "0")
            self.assertEqual(cmd[cmd.index("-Model") + 1], "4")
            self.assertEqual(cmd[cmd.index("-Runs") + 1], "1")
            self.assertIn("-SkipExpertDeploy", cmd)
            self.assertIn("-AllowMissingRealTicksLogMarker", cmd)
            # No compile-gate / evidence-identity SHA machinery reserved for
            # real strategy EAs, and no reference to either gate module the
            # ticket forbids weakening.
            joined = " ".join(cmd)
            self.assertNotIn("custom_history_gate", joined)
            self.assertNotIn("custom_history_smoke_admission", joined)


if __name__ == "__main__":
    unittest.main()
