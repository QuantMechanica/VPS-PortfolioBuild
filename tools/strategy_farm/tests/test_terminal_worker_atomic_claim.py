import json
import os
import sqlite3
import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


class TerminalWorkerAtomicClaimTests(unittest.TestCase):
    def _root(self) -> tempfile.TemporaryDirectory:
        return tempfile.TemporaryDirectory(ignore_cleanup_errors=True)

    def _insert_work_item(
        self,
        root: Path,
        item_id: str,
        symbol: str,
        *,
        phase: str = "P2",
        status: str = "pending",
        claimed_by: str | None = None,
        verdict: str | None = None,
        payload: dict[str, object] | None = None,
        ea_id: str = "QM5_9999",
    ) -> None:
        farmctl.init_db(root)
        now = farmctl.utc_now()
        with sqlite3.connect(root / farmctl.DB_REL) as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   attempt_count, parent_task_id, evidence_path, claimed_by,
                   payload_json, created_at, updated_at)
                VALUES
                  (?, 'backtest', ?, ?, ?, 'dummy.set', ?, ?,
                   0, NULL, NULL, ?, ?, ?, ?)
                """,
                (item_id, phase, ea_id, symbol, status, verdict, claimed_by, json.dumps(payload or {}), now, now),
            )
            conn.commit()

    def test_two_workers_race_claim_same_work_item_only_one_wins(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(root, "wi-1", "EURUSD.DWX", phase="P3")

            with ThreadPoolExecutor(max_workers=2) as executor:
                results = list(executor.map(lambda t: terminal_worker.claim_atomic(root, t), ["T1", "T2"]))

            claimed = [r for r in results if r.get("claimed")]
            self.assertEqual(len(claimed), 1)
            self.assertEqual(claimed[0]["item"]["id"], "wi-1")

            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                rows = conn.execute("SELECT status, claimed_by FROM work_items WHERE id='wi-1'").fetchall()
            self.assertEqual(rows[0][0], "active")
            self.assertIn(rows[0][1], {"T1", "T2"})

    def test_per_symbol_lock_is_respected(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(root, "active-1", "NDX.DWX", phase="P3", status="active", claimed_by="T1")
            self._insert_work_item(root, "pending-1", "NDX.DWX", phase="P3")
            self._insert_work_item(root, "pending-2", "SP500.DWX", phase="P3")

            result = terminal_worker.claim_atomic(root, "T2")

            self.assertTrue(result.get("claimed"))
            self.assertEqual(result["item"]["id"], "pending-2")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                statuses = dict(conn.execute("SELECT id, status FROM work_items").fetchall())
            self.assertEqual(statuses["pending-1"], "pending")
            self.assertEqual(statuses["pending-2"], "active")

    def test_q04_claim_limits_one_active_item_per_ea(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(
                root,
                "active-q04-ea-a",
                "NDX.DWX",
                phase="Q04",
                status="active",
                claimed_by="T1",
                ea_id="QM5_1001",
            )
            self._insert_work_item(
                root,
                "pending-q04-same-ea",
                "SP500.DWX",
                phase="Q04",
                ea_id="QM5_1001",
            )
            self._insert_work_item(
                root,
                "pending-q04-other-ea",
                "WS30.DWX",
                phase="Q04",
                ea_id="QM5_1002",
            )

            result = terminal_worker.claim_atomic(root, "T2")

            self.assertTrue(result.get("claimed"))
            self.assertEqual(result["item"]["id"], "pending-q04-other-ea")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                statuses = dict(conn.execute("SELECT id, status FROM work_items").fetchall())
            self.assertEqual(statuses["pending-q04-same-ea"], "pending")
            self.assertEqual(statuses["pending-q04-other-ea"], "active")

    def test_q02_logical_basket_claims_before_ordinary_winner_pool(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(
                root,
                "ordinary-pass",
                "EURUSD.DWX",
                phase="Q02",
                status="done",
                verdict="PASS",
                ea_id="QM5_1001",
            )
            self._insert_work_item(
                root,
                "ordinary-q02",
                "GBPUSD.DWX",
                phase="Q02",
                ea_id="QM5_1001",
            )
            self._insert_work_item(
                root,
                "basket-q02",
                "QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1",
                phase="Q02",
                ea_id="QM5_12533",
                payload={"portfolio_scope": "basket", "host_symbol": "EURJPY.DWX"},
            )

            old_free_ram_gb = terminal_worker._free_ram_gb
            try:
                terminal_worker._free_ram_gb = lambda: terminal_worker.MULTISYMBOL_RAM_MIN_FREE_GB + 1.0
                result = terminal_worker.claim_atomic(root, "T2")
            finally:
                terminal_worker._free_ram_gb = old_free_ram_gb

            self.assertTrue(result.get("claimed"))
            self.assertEqual(result["item"]["id"], "basket-q02")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                statuses = dict(conn.execute("SELECT id, status FROM work_items").fetchall())
            self.assertEqual(statuses["basket-q02"], "active")
            self.assertEqual(statuses["ordinary-q02"], "pending")

    def test_multisymbol_q02_waits_for_memory_headroom(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(
                root,
                "basket-q02",
                "QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1",
                phase="Q02",
                ea_id="QM5_12533",
                payload={"portfolio_scope": "basket", "host_symbol": "EURJPY.DWX"},
            )
            self._insert_work_item(
                root,
                "ordinary-q02",
                "GBPUSD.DWX",
                phase="Q02",
                ea_id="QM5_1001",
            )

            old_multisymbol_ea_ids = terminal_worker._multisymbol_ea_ids
            old_free_ram_gb = terminal_worker._free_ram_gb
            try:
                terminal_worker._multisymbol_ea_ids = lambda: frozenset({"QM5_12533"})
                terminal_worker._free_ram_gb = lambda: terminal_worker.MULTISYMBOL_RAM_MIN_FREE_GB - 0.5

                result = terminal_worker.claim_atomic(root, "T2")
            finally:
                terminal_worker._multisymbol_ea_ids = old_multisymbol_ea_ids
                terminal_worker._free_ram_gb = old_free_ram_gb

            self.assertTrue(result.get("claimed"))
            self.assertEqual(result["item"]["id"], "ordinary-q02")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                statuses = dict(conn.execute("SELECT id, status FROM work_items").fetchall())
            self.assertEqual(statuses["basket-q02"], "pending")
            self.assertEqual(statuses["ordinary-q02"], "active")

    def test_dwx_history_range_registry_is_respected_for_p2_claims(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(root, "wi-no-history", "UNKNOWN.DWX", payload={"period": "D1"})

            old_window = terminal_worker.farmctl._p2_history_window_for_symbol
            try:
                terminal_worker.farmctl._p2_history_window_for_symbol = lambda *args, **kwargs: {
                    "skip": True,
                    "reason": farmctl.P2_SYMBOL_NO_HISTORY_REASON,
                    "symbol": "UNKNOWN.DWX",
                    "period": "D1",
                }
                result = terminal_worker.claim_atomic(root, "T1")
            finally:
                terminal_worker.farmctl._p2_history_window_for_symbol = old_window

            self.assertFalse(result.get("claimed"))
            self.assertEqual(result.get("reason"), "no_pending_claimable")
            self.assertEqual(result["history_skipped"][0]["item_id"], "wi-no-history")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                status = conn.execute("SELECT status FROM work_items WHERE id='wi-no-history'").fetchone()[0]
            self.assertEqual(status, "pending")

    def test_stale_same_terminal_claim_is_released_before_next_claim(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(
                root,
                "stale-1",
                "EURUSD.DWX",
                phase="P3",
                status="active",
                claimed_by="T1",
                payload={"pid": 999999999},
            )

            old_pid_exists = terminal_worker.farmctl._pid_exists
            try:
                terminal_worker.farmctl._pid_exists = lambda _pid: False
                result = terminal_worker.claim_atomic(root, "T1")
            finally:
                terminal_worker.farmctl._pid_exists = old_pid_exists

            self.assertTrue(result.get("claimed"))
            self.assertEqual(result["item"]["id"], "stale-1")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute("SELECT status, claimed_by FROM work_items WHERE id='stale-1'").fetchone()
            self.assertEqual(row, ("active", "T1"))

    def test_live_worker_without_child_pid_keeps_terminal_busy(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(
                root,
                "launching-1",
                "EURUSD.DWX",
                phase="Q02",
                status="active",
                claimed_by="T4",
                payload={"claimed_by_worker_pid": 424242},
            )
            self._insert_work_item(root, "pending-1", "GBPUSD.DWX", phase="Q02")

            old_pid_exists = terminal_worker.farmctl._pid_exists
            try:
                terminal_worker.farmctl._pid_exists = lambda pid: int(pid) == 424242
                result = terminal_worker.claim_atomic(root, "T4")
            finally:
                terminal_worker.farmctl._pid_exists = old_pid_exists

            self.assertFalse(result.get("claimed"))
            self.assertEqual(result["reason"], "terminal_worker_busy")
            self.assertEqual(result["item_id"], "launching-1")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                statuses = dict(conn.execute("SELECT id, status FROM work_items").fetchall())
                claimed = dict(conn.execute("SELECT id, claimed_by FROM work_items").fetchall())
            self.assertEqual(statuses["launching-1"], "active")
            self.assertEqual(statuses["pending-1"], "pending")
            self.assertEqual(claimed["launching-1"], "T4")

    def test_claim_skips_launch_fault_cooldown_item(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            future = (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat()
            self._insert_work_item(
                root,
                "cooldown-1",
                "EURUSD.DWX",
                phase="Q02",
                payload={"launch_not_before_utc": future},
            )
            self._insert_work_item(root, "ready-1", "GBPUSD.DWX", phase="Q02")

            result = terminal_worker.claim_atomic(root, "T2")

            self.assertTrue(result.get("claimed"))
            self.assertEqual(result["item"]["id"], "ready-1")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                statuses = dict(conn.execute("SELECT id, status FROM work_items").fetchall())
            self.assertEqual(statuses["cooldown-1"], "pending")
            self.assertEqual(statuses["ready-1"], "active")

    def test_orphan_same_terminal_claim_adopts_live_child(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(
                root,
                "orphan-1",
                "EURUSD.DWX",
                phase="P3",
                status="active",
                claimed_by="T1",
                payload={"pid": 123456, "claimed_by_worker_pid": 654321},
            )

            stopped_children: list[int] = []
            old_pid_exists = terminal_worker.farmctl._pid_exists
            old_pid_tree_exists = terminal_worker.farmctl._pid_tree_exists
            old_stop_pid_tree = terminal_worker.farmctl._stop_pid_tree
            try:
                terminal_worker.farmctl._pid_exists = lambda pid: int(pid) != 654321
                terminal_worker.farmctl._pid_tree_exists = lambda _pid: True
                terminal_worker.farmctl._stop_pid_tree = lambda pid: stopped_children.append(int(pid)) or True
                result = terminal_worker.claim_atomic(root, "T1")
            finally:
                terminal_worker.farmctl._pid_exists = old_pid_exists
                terminal_worker.farmctl._pid_tree_exists = old_pid_tree_exists
                terminal_worker.farmctl._stop_pid_tree = old_stop_pid_tree

            self.assertTrue(result.get("claimed"))
            self.assertEqual(result["item"]["id"], "orphan-1")
            self.assertTrue(result.get("adopt_existing"))
            self.assertEqual(stopped_children, [])
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute("SELECT status, claimed_by, payload_json FROM work_items WHERE id='orphan-1'").fetchone()
            self.assertEqual(row[0], "active")
            self.assertEqual(row[1], "T1")
            payload = json.loads(row[2])
            self.assertEqual(payload["prior_failure"], "worker_process_missing_adopted_active_child")
            self.assertEqual(payload["orphan_worker_pid"], 654321)
            self.assertEqual(payload["claimed_by_worker_pid"], os.getpid())
            self.assertIn("orphan_child_adopted_at_iso", payload)

    def test_launch_fault_defers_without_incrementing_attempt_count(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            self._insert_work_item(
                root,
                "wi-launch-fault",
                "CADJPY.DWX",
                phase="Q02",
                status="active",
                claimed_by="T4",
                payload={},
            )

            old_spawn = terminal_worker.farmctl._spawn_work_item_runner
            old_pid_tree_exists = terminal_worker.farmctl._pid_tree_exists
            old_preflight = terminal_worker._work_item_preflight_failure
            old_acquire = terminal_worker._acquire_launch_slot
            old_sleep = terminal_worker.time.sleep
            try:
                terminal_worker.farmctl._spawn_work_item_runner = lambda _root, _row, _terminal: {
                    "spawned": True,
                    "pid": 123456,
                    "log_path": str(root / "runner.log"),
                    "report_root": str(root / "reports"),
                    "ea_dir_name": "QM5_9999",
                    "expected_trades_per_year_per_symbol": 10,
                    "smoke_year_count": 6,
                    "effective_min_trades": 5,
                    "phase_runner": "run_smoke.ps1",
                }
                terminal_worker.farmctl._pid_tree_exists = lambda _pid: False
                terminal_worker._work_item_preflight_failure = lambda _row: None
                terminal_worker._acquire_launch_slot = lambda _terminal: None
                terminal_worker.time.sleep = lambda _seconds: None

                result = terminal_worker._run_claimed_item(
                    root,
                    {"id": "wi-launch-fault"},
                    "T4",
                    timeout_seconds=30,
                )
            finally:
                terminal_worker.farmctl._spawn_work_item_runner = old_spawn
                terminal_worker.farmctl._pid_tree_exists = old_pid_tree_exists
                terminal_worker._work_item_preflight_failure = old_preflight
                terminal_worker._acquire_launch_slot = old_acquire
                terminal_worker.time.sleep = old_sleep

            self.assertEqual(result["reason"], "launch_fault_deferred")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, verdict, claimed_by, attempt_count, payload_json FROM work_items WHERE id='wi-launch-fault'"
                ).fetchone()
            self.assertEqual(row[0], "pending")
            self.assertIsNone(row[1])
            self.assertIsNone(row[2])
            self.assertEqual(row[3], 0)
            payload = json.loads(row[4])
            self.assertEqual(payload["prior_failure"], "launch_fault")
            self.assertEqual(payload["launch_fault_count"], 1)
            self.assertIn("launch_not_before_utc", payload)

    def test_summary_missing_release_stops_terminal_slot(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            report_root = root / "reports" / "wi-summary-missing"
            report_root.mkdir(parents=True)
            self._insert_work_item(
                root,
                "wi-summary-missing",
                "AUDUSD.DWX",
                phase="P2",
                status="active",
                claimed_by="T4",
                payload={"report_root": str(report_root), "pid": 424242},
            )

            stopped: list[str] = []
            old_default_root = terminal_worker.farmctl.DEFAULT_ROOT
            old_stop_terminal_slot = terminal_worker.farmctl._stop_terminal_slot
            try:
                terminal_worker.farmctl.DEFAULT_ROOT = root
                terminal_worker.farmctl._stop_terminal_slot = lambda terminal: stopped.append(terminal) or True
                result = terminal_worker._finish_work_item(root, "wi-summary-missing", exit_code=0)
            finally:
                terminal_worker.farmctl.DEFAULT_ROOT = old_default_root
                terminal_worker.farmctl._stop_terminal_slot = old_stop_terminal_slot

            self.assertEqual(result["status"], "pending")
            self.assertEqual(stopped, ["T4"])
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, claimed_by, payload_json FROM work_items WHERE id='wi-summary-missing'"
                ).fetchone()
            self.assertEqual(row[0], "pending")
            self.assertIsNone(row[1])
            payload = json.loads(row[2])
            self.assertEqual(payload["prior_failure"], "summary_missing")
            self.assertTrue(payload["terminal_stopped_on_release"])

    def test_monitor_waits_for_detached_terminal_summary(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            report_root = root / "reports" / "wi-detached"
            self._insert_work_item(
                root,
                "wi-detached",
                "EURJPY.DWX",
                phase="Q02",
                status="active",
                claimed_by="T7",
                payload={"report_root": str(report_root)},
            )

            summary_path = report_root / "QM5_9999" / "20260101_000000" / "summary.json"
            slot_checks = {"count": 0}

            def fake_terminal_slot_running(_root: Path, _terminal: str | None) -> bool:
                slot_checks["count"] += 1
                if slot_checks["count"] == 1:
                    return True
                summary_path.parent.mkdir(parents=True, exist_ok=True)
                summary_path.write_text(
                    json.dumps({
                        "result": "PASS",
                        "model4_log_marker_detected": True,
                        "min_trades_required": 5,
                        "runs": [{"total_trades": 10}],
                    }),
                    encoding="utf-8",
                )
                return False

            old_pid_tree_exists = terminal_worker.farmctl._pid_tree_exists
            old_terminal_slot_running = terminal_worker._terminal_slot_running
            old_sleep = terminal_worker.time.sleep
            try:
                terminal_worker.farmctl._pid_tree_exists = lambda _pid: False
                terminal_worker._terminal_slot_running = fake_terminal_slot_running
                terminal_worker.time.sleep = lambda _seconds: None

                result = terminal_worker._monitor_spawned_work_item(
                    root,
                    {"id": "wi-detached", "phase": "Q02"},
                    "T7",
                    {"pid": 123456, "report_root": str(report_root)},
                    {"report_root": str(report_root)},
                    timeout_seconds=30,
                )
            finally:
                terminal_worker.farmctl._pid_tree_exists = old_pid_tree_exists
                terminal_worker._terminal_slot_running = old_terminal_slot_running
                terminal_worker.time.sleep = old_sleep

            self.assertEqual(result["status"], "done")
            self.assertEqual(result["verdict"], "PASS")
            self.assertGreaterEqual(slot_checks["count"], 2)
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, verdict, evidence_path FROM work_items WHERE id='wi-detached'"
                ).fetchone()
            self.assertEqual(row[0], "done")
            self.assertEqual(row[1], "PASS")
            self.assertEqual(Path(row[2]), summary_path)

    def test_run_claimed_item_stops_child_when_claim_is_externally_released(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            self._insert_work_item(
                root,
                "wi-external-release",
                "CADCHF.DWX",
                phase="P2",
                status="active",
                claimed_by="T5",
                payload={},
            )

            stopped_children: list[int] = []
            stopped_terminals: list[str] = []
            old_spawn = terminal_worker.farmctl._spawn_work_item_runner
            old_pid_exists = terminal_worker.farmctl._pid_exists
            old_stop_pid_tree = terminal_worker.farmctl._stop_pid_tree
            old_default_root = terminal_worker.farmctl.DEFAULT_ROOT
            old_stop_terminal_slot = terminal_worker.farmctl._stop_terminal_slot
            old_preflight = terminal_worker._work_item_preflight_failure

            def fake_pid_exists(_pid: int) -> bool:
                with sqlite3.connect(root / farmctl.DB_REL) as conn:
                    conn.execute(
                        "UPDATE work_items SET status='pending', claimed_by=NULL WHERE id='wi-external-release'"
                    )
                    conn.commit()
                return True

            try:
                terminal_worker.farmctl._spawn_work_item_runner = lambda _root, _row, _terminal: {
                    "spawned": True,
                    "pid": 123456,
                    "log_path": str(root / "runner.log"),
                    "report_root": str(root / "reports"),
                    "ea_dir_name": "QM5_9999",
                    "expected_trades_per_year_per_symbol": 10,
                    "smoke_year_count": 6,
                    "effective_min_trades": 5,
                    "phase_runner": "run_smoke.ps1",
                }
                terminal_worker.farmctl._pid_exists = fake_pid_exists
                terminal_worker.farmctl._stop_pid_tree = lambda pid: stopped_children.append(int(pid)) or True
                terminal_worker.farmctl.DEFAULT_ROOT = root
                terminal_worker.farmctl._stop_terminal_slot = lambda terminal: stopped_terminals.append(terminal) or True
                terminal_worker._work_item_preflight_failure = lambda _row: None

                result = terminal_worker._run_claimed_item(
                    root,
                    {"id": "wi-external-release"},
                    "T5",
                    timeout_seconds=30,
                )
            finally:
                terminal_worker.farmctl._spawn_work_item_runner = old_spawn
                terminal_worker.farmctl._pid_exists = old_pid_exists
                terminal_worker.farmctl._stop_pid_tree = old_stop_pid_tree
                terminal_worker.farmctl.DEFAULT_ROOT = old_default_root
                terminal_worker.farmctl._stop_terminal_slot = old_stop_terminal_slot
                terminal_worker._work_item_preflight_failure = old_preflight

            self.assertEqual(result["action"], "external_release_observed")
            self.assertEqual(result["reason"], "status_changed")
            self.assertEqual(stopped_children, [123456])
            self.assertEqual(stopped_terminals, ["T5"])

    def test_log_bomb_kill_records_payload_and_evidence(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            report_root = root / "reports" / "wi-log-bomb"
            journal = report_root / "raw" / "run_01" / "20260101.log"
            journal.parent.mkdir(parents=True)
            journal.write_bytes(b"x" * 1024)
            self._insert_work_item(
                root,
                "wi-log-bomb",
                "QM5_9001_EUR_GBP_BASKET_D1",
                phase="Q02",
                status="active",
                claimed_by="T2",
                payload={"report_root": str(report_root), "pid": 123456},
                ea_id="QM5_9001",
            )

            stopped_children: list[int] = []
            stopped_terminals: list[str] = []
            old_pid_tree_exists = terminal_worker.farmctl._pid_tree_exists
            old_stop_pid_tree = terminal_worker.farmctl._stop_pid_tree
            old_stop_slot = terminal_worker._stop_terminal_slot_for_release
            old_find_journal = terminal_worker._find_oversized_journal
            old_check_every = terminal_worker.LOG_BOMB_CHECK_EVERY_ITERS
            old_sleep = terminal_worker.time.sleep
            try:
                terminal_worker.farmctl._pid_tree_exists = lambda pid: int(pid) == 123456
                terminal_worker.farmctl._stop_pid_tree = lambda pid: stopped_children.append(int(pid)) or True
                terminal_worker._stop_terminal_slot_for_release = (
                    lambda _root, terminal: stopped_terminals.append(str(terminal)) or True
                )
                terminal_worker._find_oversized_journal = lambda _report_root: str(journal)
                terminal_worker.LOG_BOMB_CHECK_EVERY_ITERS = 1
                terminal_worker.time.sleep = lambda _seconds: None

                result = terminal_worker._monitor_spawned_work_item(
                    root,
                    {"id": "wi-log-bomb", "ea_id": "QM5_9001", "symbol": "QM5_9001_EUR_GBP_BASKET_D1", "phase": "Q02"},
                    "T2",
                    {"pid": 123456, "report_root": str(report_root)},
                    {"report_root": str(report_root)},
                    timeout_seconds=30,
                )
            finally:
                terminal_worker.farmctl._pid_tree_exists = old_pid_tree_exists
                terminal_worker.farmctl._stop_pid_tree = old_stop_pid_tree
                terminal_worker._stop_terminal_slot_for_release = old_stop_slot
                terminal_worker._find_oversized_journal = old_find_journal
                terminal_worker.LOG_BOMB_CHECK_EVERY_ITERS = old_check_every
                terminal_worker.time.sleep = old_sleep

            self.assertEqual(result["action"], "log_bomb_killed")
            self.assertEqual(stopped_children, [123456])
            self.assertEqual(stopped_terminals, ["T2"])
            self.assertFalse(journal.exists())
            evidence_path = Path(result["evidence_path"])
            self.assertTrue(evidence_path.exists())
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            self.assertEqual(evidence["event"], "LOG_BOMB")
            self.assertEqual(evidence["terminal"], "T2")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, verdict, attempt_count, claimed_by, evidence_path, payload_json FROM work_items WHERE id='wi-log-bomb'"
                ).fetchone()
            self.assertEqual(row[0], "done")
            self.assertEqual(row[1], "INFRA_FAIL")
            self.assertEqual(row[2], 99)
            self.assertIsNone(row[3])
            self.assertEqual(Path(row[4]), evidence_path)
            payload = json.loads(row[5])
            self.assertIn("LOG_BOMB", payload["reason_classes"])
            self.assertEqual(payload["verdict_reason"], "LOG_BOMB")
            self.assertEqual(payload["final_failure"], "log_bomb")
            self.assertTrue(payload["terminal_stopped_on_release"])

    def test_run_claimed_item_preflight_blocks_missing_ex5_without_spawn(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            repo = Path(tmp) / "repo"
            ea_dir = repo / "framework" / "EAs" / "QM5_9999_missing-ex5"
            sets = ea_dir / "sets"
            sets.mkdir(parents=True)
            setfile = sets / "QM5_9999_missing-ex5_EURUSD.DWX_H1_backtest.set"
            setfile.write_text("Symbol=EURUSD.DWX\n", encoding="utf-8")
            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                       attempt_count, parent_task_id, evidence_path, claimed_by,
                       payload_json, created_at, updated_at)
                    VALUES
                      ('wi-missing-ex5', 'backtest', 'P2', 'QM5_9999', 'EURUSD.DWX', ?,
                       'active', NULL, 0, NULL, NULL, 'T1', '{}', ?, ?)
                    """,
                    (str(setfile), now, now),
                )
                conn.commit()

            old_repo_root = terminal_worker.farmctl.REPO_ROOT
            old_spawn = terminal_worker.farmctl._spawn_work_item_runner
            try:
                terminal_worker.farmctl.REPO_ROOT = repo
                terminal_worker.farmctl._spawn_work_item_runner = lambda *_args, **_kwargs: (_ for _ in ()).throw(
                    AssertionError("spawn must not be called")
                )
                result = terminal_worker._run_claimed_item(
                    root,
                    {"id": "wi-missing-ex5"},
                    "T1",
                    timeout_seconds=30,
                )
            finally:
                terminal_worker.farmctl.REPO_ROOT = old_repo_root
                terminal_worker.farmctl._spawn_work_item_runner = old_spawn

            self.assertEqual(result["action"], "preflight_failed")
            self.assertEqual(result["reason"], "ex5_missing")
            self.assertTrue(Path(result["evidence_path"]).exists())
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, verdict, claimed_by, evidence_path, payload_json FROM work_items WHERE id='wi-missing-ex5'"
                ).fetchone()
            self.assertEqual(row[0], "failed")
            self.assertEqual(row[1], "INFRA_FAIL")
            self.assertIsNone(row[2])
            self.assertTrue(Path(row[3]).exists())
            self.assertEqual(json.loads(row[4])["verdict_reason"], "ex5_missing")


if __name__ == "__main__":
    unittest.main()
