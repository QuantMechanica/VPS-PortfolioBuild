import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class CascadeRealPhaseRunnerTests(unittest.TestCase):
    def _insert_work_item(self, root: Path, *, item_id: str, phase: str) -> None:
        farmctl.init_db(root)
        db = root / "state" / "farm_state.sqlite"
        now = farmctl.utc_now()
        with sqlite3.connect(db) as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   attempt_count, parent_task_id, evidence_path, claimed_by,
                   payload_json, created_at, updated_at)
                VALUES
                  (?, 'backtest', ?, 'QM5_9999', 'EURUSD.DWX', 'dummy.set', 'pending', NULL,
                   0, NULL, NULL, NULL, '{}', ?, ?)
                """,
                (item_id, phase, now, now),
            )
            conn.commit()

    def test_p4_dispatch_spawns_walk_forward_not_run_smoke(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            self._insert_work_item(root, item_id="wi-p4", phase="P4")
            spawned_cmds: list[list[str]] = []

            class FakeProc:
                pid = 4242

                def __init__(self, cmd, **_kwargs):
                    spawned_cmds.append([str(part) for part in cmd])

            old_popen = farmctl.subprocess.Popen
            old_terminals = farmctl.MT5_TERMINALS
            old_running = farmctl._running_mt5_terminals
            try:
                farmctl.subprocess.Popen = FakeProc
                farmctl.MT5_TERMINALS = ("T1",)
                farmctl._running_mt5_terminals = lambda: set()
                result = farmctl.dispatch_work_items(root, timeout_minutes=8)
            finally:
                farmctl.subprocess.Popen = old_popen
                farmctl.MT5_TERMINALS = old_terminals
                farmctl._running_mt5_terminals = old_running

            self.assertEqual(len(spawned_cmds), 1)
            joined = " ".join(spawned_cmds[0])
            self.assertIn("p4_walk_forward.py", joined)
            self.assertNotIn("run_smoke.ps1", joined)
            self.assertEqual(result["actions"][0]["phase_runner"].replace("\\", "/").split("/")[-1], "p4_walk_forward.py")

    def test_missing_p6_runner_marks_pending_runner(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            self._insert_work_item(root, item_id="wi-p6", phase="P6")
            old_scripts = dict(farmctl.PHASE_RUNNER_SCRIPTS)
            old_terminals = farmctl.MT5_TERMINALS
            old_running = farmctl._running_mt5_terminals
            try:
                farmctl.PHASE_RUNNER_SCRIPTS["P6"] = "missing_p6_runner.py"
                farmctl.MT5_TERMINALS = ("T1",)
                farmctl._running_mt5_terminals = lambda: set()
                result = farmctl.dispatch_work_items(root, timeout_minutes=8)
            finally:
                farmctl.PHASE_RUNNER_SCRIPTS.clear()
                farmctl.PHASE_RUNNER_SCRIPTS.update(old_scripts)
                farmctl.MT5_TERMINALS = old_terminals
                farmctl._running_mt5_terminals = old_running

            db = root / "state" / "farm_state.sqlite"
            with sqlite3.connect(db) as conn:
                row = conn.execute("SELECT status, verdict, payload_json FROM work_items WHERE id='wi-p6'").fetchone()
            self.assertEqual(row[0], "done")
            self.assertEqual(row[1], "PENDING_RUNNER")
            self.assertIn("pending_runner", [action["action"] for action in result["actions"]])
            self.assertIn("phase runner not implemented yet", json.loads(row[2])["verdict_reason"])

    def test_p4_success_summary_derives_pass(self) -> None:
        verdict, reason = farmctl._derive_verdict_from_summary(
            {
                "phase": "P4",
                "wf_folds_completed": 6,
                "oos_total_trades": 47,
                "oos_sharpe": 0.73,
                "oos_max_dd_pct": 14.2,
                "oos_net_profit": 3142.50,
                "verdict": "PASS",
                "reason": "wf_oos_gates_met",
            },
            phase="P4",
        )

        self.assertEqual(verdict, "PASS")
        self.assertEqual(reason, "wf_oos_gates_met")

    def test_p4_failed_gates_derives_fail_reason(self) -> None:
        verdict, reason = farmctl._derive_verdict_from_summary(
            {
                "phase": "P4",
                "wf_folds_completed": 4,
                "oos_total_trades": 47,
                "verdict": "FAIL",
                "reason": "wf_folds_below_6",
            },
            phase="P4",
        )

        self.assertEqual(verdict, "FAIL")
        self.assertEqual(reason, "wf_folds_below_6")


if __name__ == "__main__":
    unittest.main()
