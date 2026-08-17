import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


class TerminalWorkerAdoptionTests(unittest.TestCase):
    def test_direct_entrypoint_bootstraps_repo_root_without_pythonpath(self) -> None:
        worker = REPO / "tools" / "strategy_farm" / "terminal_worker.py"
        env = os.environ.copy()
        env.pop("PYTHONPATH", None)
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            result = subprocess.run(
                [sys.executable, str(worker), "--help"],
                cwd=tmp,
                env=env,
                capture_output=True,
                text=True,
                errors="replace",
                timeout=30,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--terminal", result.stdout)

    def test_q08_monitor_uses_phase_scaled_timeout(self) -> None:
        payload = {"timeout_min": 120, "host_timeframe": "M5"}
        expected_min = farmctl._active_timeout_min_for_work_item(
            "Q08", json.dumps(payload)
        )

        self.assertEqual(
            terminal_worker._monitor_timeout_seconds(
                payload, 90 * 60, phase="Q08"
            ),
            expected_min * 60,
        )

    def _insert_active_item(self, root: Path, *, payload: dict[str, object]) -> dict[str, object]:
        farmctl.init_db(root)
        now = farmctl.utc_now()
        db = root / farmctl.DB_REL
        with sqlite3.connect(db) as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   attempt_count, parent_task_id, evidence_path, claimed_by,
                   payload_json, created_at, updated_at)
                VALUES
                  ('wi-adopt', 'backtest', 'Q02', 'QM5_12533',
                   'QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1',
                   'dummy.set', 'active', NULL, 0, NULL, NULL, 'T1', ?, ?, ?)
                """,
                (json.dumps(payload), now, now),
            )
            conn.commit()
            conn.row_factory = sqlite3.Row
            row = conn.execute("SELECT * FROM work_items WHERE id='wi-adopt'").fetchone()
        return dict(row)

    def test_claim_atomic_adopts_live_child_when_worker_pid_is_gone(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            self._insert_active_item(
                root,
                payload={
                    "pid": 4321,
                    "claimed_by_worker_pid": 999999,
                    "report_root": str(root / "reports" / "wi-adopt"),
                    "log_path": str(root / "logs" / "wi-adopt.log"),
                },
            )

            old_pid_exists = farmctl._pid_exists
            old_pid_tree_exists = farmctl._pid_tree_exists
            old_stop_pid_tree = farmctl._stop_pid_tree
            old_stop_slot = terminal_worker._stop_terminal_slot_for_release
            try:
                farmctl._pid_exists = lambda pid: False
                farmctl._pid_tree_exists = lambda pid: int(pid) == 4321
                farmctl._stop_pid_tree = lambda _pid: self.fail("live child was stopped")
                terminal_worker._stop_terminal_slot_for_release = (
                    lambda _root, _terminal: self.fail("terminal was stopped")
                )

                result = terminal_worker.claim_atomic(root, "T1")
            finally:
                farmctl._pid_exists = old_pid_exists
                farmctl._pid_tree_exists = old_pid_tree_exists
                farmctl._stop_pid_tree = old_stop_pid_tree
                terminal_worker._stop_terminal_slot_for_release = old_stop_slot

            self.assertTrue(result["claimed"])
            self.assertTrue(result["adopt_existing"])
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, claimed_by, payload_json FROM work_items WHERE id='wi-adopt'"
                ).fetchone()
            self.assertEqual(row[0], "active")
            self.assertEqual(row[1], "T1")
            payload = json.loads(row[2])
            self.assertEqual(payload["pid"], 4321)
            self.assertEqual(payload["orphan_worker_pid"], 999999)
            self.assertEqual(payload["claimed_by_worker_pid"], os.getpid())
            self.assertEqual(payload["prior_failure"], "worker_process_missing_adopted_active_child")
            self.assertIn("orphan_child_adopted_at_iso", payload)

    def test_run_claimed_item_monitors_adopted_child_without_respawn(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            item = self._insert_active_item(
                root,
                payload={
                    "pid": 4321,
                    "claimed_by_worker_pid": os.getpid(),
                    "report_root": str(root / "reports" / "wi-adopt"),
                    "log_path": str(root / "logs" / "wi-adopt.log"),
                },
            )

            pid_checks = {"count": 0}

            def fake_pid_tree_exists(pid: object) -> bool:
                self.assertEqual(int(pid), 4321)
                pid_checks["count"] += 1
                return pid_checks["count"] == 1

            old_preflight = terminal_worker._work_item_preflight_failure
            old_pid_tree_exists = farmctl._pid_tree_exists
            old_spawn = farmctl._spawn_work_item_runner
            old_finish = terminal_worker._finish_work_item
            try:
                terminal_worker._work_item_preflight_failure = lambda _row: None
                farmctl._pid_tree_exists = fake_pid_tree_exists
                farmctl._spawn_work_item_runner = lambda *_args, **_kwargs: self.fail("spawned duplicate runner")
                terminal_worker._finish_work_item = (
                    lambda _root, item_id, exit_code: {
                        "finished": True,
                        "status": "done",
                        "verdict": "PASS",
                        "item_id": item_id,
                        "exit_code_seen": exit_code,
                    }
                )

                result = terminal_worker._run_claimed_item(root, item, "T1", 900)
            finally:
                terminal_worker._work_item_preflight_failure = old_preflight
                farmctl._pid_tree_exists = old_pid_tree_exists
                farmctl._spawn_work_item_runner = old_spawn
                terminal_worker._finish_work_item = old_finish

            self.assertEqual(result["action"], "finished")
            self.assertEqual(result["verdict"], "PASS")
            self.assertEqual(result["exit_code_seen"], 0)
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                payload = json.loads(
                    conn.execute("SELECT payload_json FROM work_items WHERE id='wi-adopt'").fetchone()[0]
                )
            self.assertIn("adopted_active_child_at_iso", payload)

    def test_adopted_child_preserves_original_timeout_budget(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            item = self._insert_active_item(
                root,
                payload={
                    "pid": 4321,
                    "claimed_by_worker_pid": os.getpid(),
                    "started_at_iso": (datetime.now(timezone.utc) - timedelta(minutes=20)).isoformat(),
                    "timeout_min": 1,
                    "report_root": str(root / "reports" / "wi-adopt"),
                    "log_path": str(root / "logs" / "wi-adopt.log"),
                },
            )

            stopped = {"pid": None}

            old_preflight = terminal_worker._work_item_preflight_failure
            old_pid_tree_exists = farmctl._pid_tree_exists
            old_stop_pid_tree = farmctl._stop_pid_tree
            old_finish = terminal_worker._finish_work_item
            try:
                terminal_worker._work_item_preflight_failure = lambda _row: None
                farmctl._pid_tree_exists = lambda pid: int(pid) == 4321
                farmctl._stop_pid_tree = lambda pid: stopped.update({"pid": int(pid)}) or True
                terminal_worker._finish_work_item = (
                    lambda _root, item_id, exit_code: {
                        "finished": True,
                        "status": "done",
                        "verdict": "INFRA_FAIL",
                        "item_id": item_id,
                        "exit_code_seen": exit_code,
                    }
                )

                result = terminal_worker._run_claimed_item(root, item, "T1", 900)
            finally:
                terminal_worker._work_item_preflight_failure = old_preflight
                farmctl._pid_tree_exists = old_pid_tree_exists
                farmctl._stop_pid_tree = old_stop_pid_tree
                terminal_worker._finish_work_item = old_finish

            self.assertEqual(result["action"], "finished")
            self.assertEqual(stopped["pid"], 4321)
            self.assertIsNone(result["exit_code_seen"])

    def test_adopted_monitor_deadline_never_below_inner_budget(self) -> None:
        # docs/ops/evidence/q02_summary_missing_90min_outer_watchdog_mismatch_2026-08-16.md:
        # the outer watchdog must bind to whatever inner budget this row was
        # actually spawned with, never fall back to the bare CLI default.
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            item = self._insert_active_item(
                root,
                payload={
                    "pid": 4321,
                    "claimed_by_worker_pid": os.getpid(),
                    "timeout_seconds": 7200,  # inner Q02-full budget, 120 minutes
                    "report_root": str(root / "reports" / "wi-adopt"),
                    "log_path": str(root / "logs" / "wi-adopt.log"),
                },
            )

            captured: dict[str, object] = {}

            def fake_monitor(_root, _item, _terminal, _spawn, _payload, timeout_seconds, *, adopted=False):
                captured["timeout_seconds"] = timeout_seconds
                captured["adopted"] = adopted
                return {"action": "finished", "item_id": _item["id"]}

            old_preflight = terminal_worker._work_item_preflight_failure
            old_pid_tree_exists = farmctl._pid_tree_exists
            old_monitor = terminal_worker._monitor_spawned_work_item
            try:
                terminal_worker._work_item_preflight_failure = lambda _row: None
                farmctl._pid_tree_exists = lambda pid: int(pid) == 4321
                terminal_worker._monitor_spawned_work_item = fake_monitor

                # CLI --timeout-minutes default (90 min) is below the 120-minute
                # inner budget this row was actually spawned with.
                cli_default_seconds = 90 * 60
                terminal_worker._run_claimed_item(root, item, "T1", cli_default_seconds)
            finally:
                terminal_worker._work_item_preflight_failure = old_preflight
                farmctl._pid_tree_exists = old_pid_tree_exists
                terminal_worker._monitor_spawned_work_item = old_monitor

            self.assertTrue(captured["adopted"])
            self.assertGreaterEqual(captured["timeout_seconds"], 7200)

    def test_fresh_spawn_monitor_deadline_never_below_inner_budget(self) -> None:
        # Same invariant as test_adopted_monitor_deadline_never_below_inner_budget,
        # exercised on the first-attempt (non-adopted) spawn path — this is the
        # branch the four confirmed UNCLASSIFIED/summary_missing rows actually hit.
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            item = self._insert_active_item(root, payload={})

            captured: dict[str, object] = {}

            def fake_monitor(_root, _item, _terminal, _spawn, _payload, timeout_seconds, *, adopted=False):
                captured["timeout_seconds"] = timeout_seconds
                captured["adopted"] = adopted
                return {"action": "finished", "item_id": _item["id"]}

            old_preflight = terminal_worker._work_item_preflight_failure
            old_calendar = farmctl._news_calendar_preflight
            old_staged = terminal_worker._prepare_staged_ex5
            old_gate = terminal_worker._custom_history_gate
            old_privatize = terminal_worker._privatize_custom_history_claim
            old_launch_slot = terminal_worker._acquire_launch_slot
            old_spawn_runner = farmctl._spawn_work_item_runner
            old_monitor = terminal_worker._monitor_spawned_work_item
            try:
                terminal_worker._work_item_preflight_failure = lambda _row: None
                farmctl._news_calendar_preflight = lambda **_kwargs: {"ok": True}
                terminal_worker._prepare_staged_ex5 = lambda _row, _terminal: {
                    "required_sha256": "a" * 64,
                    "source_path": "dummy.ex5",
                }
                terminal_worker._custom_history_gate = lambda _root, _terminal: {"required": False}
                terminal_worker._privatize_custom_history_claim = (
                    lambda _root, _row, _terminal, _gate: {"required": False}
                )
                terminal_worker._acquire_launch_slot = lambda _terminal: None
                farmctl._spawn_work_item_runner = lambda _root, _row, _terminal: {
                    "spawned": True,
                    "pid": 4321,
                    "log_path": str(root / "logs" / "wi-fresh.log"),
                    "report_root": str(root / "reports" / "wi-fresh"),
                    "ea_dir_name": "ea",
                    # farmctl._p2_full_timeout_seconds's Q02-full floor
                    # (P2_FULL_TIMEOUT_MIN_SECONDS = 7200, 120 minutes).
                    "timeout_seconds": 7200,
                }
                terminal_worker._monitor_spawned_work_item = fake_monitor

                # CLI --timeout-minutes default (90 min) is below the 120-minute
                # inner budget farmctl just computed for this dispatch.
                cli_default_seconds = 90 * 60
                terminal_worker._run_claimed_item(root, item, "T1", cli_default_seconds)
            finally:
                terminal_worker._work_item_preflight_failure = old_preflight
                farmctl._news_calendar_preflight = old_calendar
                terminal_worker._prepare_staged_ex5 = old_staged
                terminal_worker._custom_history_gate = old_gate
                terminal_worker._privatize_custom_history_claim = old_privatize
                terminal_worker._acquire_launch_slot = old_launch_slot
                farmctl._spawn_work_item_runner = old_spawn_runner
                terminal_worker._monitor_spawned_work_item = old_monitor

            self.assertFalse(captured["adopted"])
            self.assertGreaterEqual(captured["timeout_seconds"], 7200)


if __name__ == "__main__":
    unittest.main()
