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
        setfile_path: str = "dummy.set",
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
                  (?, 'backtest', ?, ?, ?, ?, ?, ?,
                   0, NULL, NULL, ?, ?, ?, ?)
                """,
                (
                    item_id,
                    phase,
                    ea_id,
                    symbol,
                    setfile_path,
                    status,
                    verdict,
                    claimed_by,
                    json.dumps(payload or {}),
                    now,
                    now,
                ),
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

    def test_payload_basket_q02_waits_for_memory_headroom_without_registry_hint(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(
                root,
                "basket-q02",
                "QM5_12751_EURUSD_EURAUD_COINTEGRATION_D1",
                phase="Q02",
                ea_id="QM5_12751",
                payload={
                    "portfolio_scope": "basket",
                    "basket_manifest": "C:/QM/repo/framework/EAs/QM5_12751_demo/basket_manifest.json",
                    "basket_symbol_count": 2,
                    "host_symbol": "EURUSD.DWX",
                },
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
                terminal_worker._multisymbol_ea_ids = lambda: frozenset()
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

    def test_payload_basket_q02_serializes_while_another_payload_basket_is_active(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(
                root,
                "active-basket",
                "QM5_12749_NZDUSD_AUDJPY_COINTEGRATION_D1",
                phase="Q02",
                status="active",
                claimed_by="T1",
                ea_id="QM5_12749",
                payload={
                    "portfolio_scope": "basket",
                    "basket_manifest": "C:/QM/repo/framework/EAs/QM5_12749_demo/basket_manifest.json",
                    "basket_symbol_count": 2,
                    "host_symbol": "NZDUSD.DWX",
                },
            )
            self._insert_work_item(
                root,
                "pending-basket",
                "QM5_12751_EURUSD_EURAUD_COINTEGRATION_D1",
                phase="Q02",
                ea_id="QM5_12751",
                payload={
                    "portfolio_scope": "basket",
                    "basket_manifest": "C:/QM/repo/framework/EAs/QM5_12751_demo/basket_manifest.json",
                    "basket_symbol_count": 2,
                    "host_symbol": "EURUSD.DWX",
                },
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
                terminal_worker._multisymbol_ea_ids = lambda: frozenset()
                terminal_worker._free_ram_gb = lambda: terminal_worker.MULTISYMBOL_RAM_MIN_FREE_GB + 1.0

                result = terminal_worker.claim_atomic(root, "T2")
            finally:
                terminal_worker._multisymbol_ea_ids = old_multisymbol_ea_ids
                terminal_worker._free_ram_gb = old_free_ram_gb

            self.assertTrue(result.get("claimed"))
            self.assertEqual(result["item"]["id"], "ordinary-q02")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                statuses = dict(conn.execute("SELECT id, status FROM work_items").fetchall())
            self.assertEqual(statuses["active-basket"], "active")
            self.assertEqual(statuses["pending-basket"], "pending")
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

    def test_q02_claim_skips_terminal_without_symbol_history_source(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(
                root,
                "wi-audusd-q02",
                "AUDUSD.DWX",
                phase="Q02",
                payload={"host_timeframe": "D1", "from_year": 2017, "to_year": 2026},
            )

            registry = {
                ("AUDUSD.DWX", "D1"): {
                    "first_year": 2017,
                    "last_year": 2026,
                    "source_terminals": "T1,T2,T3,T4,T5",
                }
            }
            old_registry = terminal_worker.farmctl._dwx_symbol_history_registry
            try:
                terminal_worker.farmctl._dwx_symbol_history_registry = lambda: registry
                skipped = terminal_worker.claim_atomic(root, "T7")
                claimed = terminal_worker.claim_atomic(root, "T3")
            finally:
                terminal_worker.farmctl._dwx_symbol_history_registry = old_registry

            self.assertFalse(skipped.get("claimed"))
            self.assertEqual(skipped.get("reason"), "no_pending_claimable")
            self.assertEqual(skipped["history_skipped"][0]["reason"], terminal_worker.TERMINAL_NO_SYMBOL_HISTORY_REASON)
            self.assertEqual(skipped["history_skipped"][0]["terminal"], "T7")
            self.assertTrue(claimed.get("claimed"))
            self.assertEqual(claimed["item"]["id"], "wi-audusd-q02")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute("SELECT status, claimed_by FROM work_items WHERE id='wi-audusd-q02'").fetchone()
            self.assertEqual(row, ("active", "T3"))

    def test_q03_claim_uses_setfile_period_for_terminal_history_source(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(
                root,
                "wi-audusd-q03",
                "AUDUSD.DWX",
                phase="Q03",
                setfile_path="QM5_9999_AUDUSD.DWX_D1_backtest.set",
            )

            registry = {
                ("AUDUSD.DWX", "D1"): {
                    "first_year": 2017,
                    "last_year": 2026,
                    "source_terminals": "T1,T2,T3,T4,T5",
                }
            }
            old_registry = terminal_worker.farmctl._dwx_symbol_history_registry
            try:
                terminal_worker.farmctl._dwx_symbol_history_registry = lambda: registry
                result = terminal_worker.claim_atomic(root, "T7")
            finally:
                terminal_worker.farmctl._dwx_symbol_history_registry = old_registry

            self.assertFalse(result.get("claimed"))
            self.assertEqual(result.get("reason"), "no_pending_claimable")
            self.assertEqual(result["history_skipped"][0]["item_id"], "wi-audusd-q03")
            self.assertEqual(result["history_skipped"][0]["period"], "D1")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                status = conn.execute("SELECT status FROM work_items WHERE id='wi-audusd-q03'").fetchone()[0]
            self.assertEqual(status, "pending")

    def test_basket_claim_requires_terminal_history_for_all_manifest_symbols(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            payload = {
                "portfolio_scope": "basket",
                "host_symbol": "AUDUSD.DWX",
                "host_timeframe": "D1",
                "logical_symbol": "QM5_12783_AUDUSD_AUDJPY_COINTEGRATION_D1",
                "basket_symbols": ["AUDUSD.DWX", "AUDJPY.DWX", "USDJPY.DWX"],
                "basket_symbol_count": 3,
            }
            self._insert_work_item(
                root,
                "wi-audusd-audjpy-q03",
                "QM5_12783_AUDUSD_AUDJPY_COINTEGRATION_D1",
                phase="Q03",
                payload=payload,
                ea_id="QM5_12783",
                setfile_path="QM5_12783_AUDUSD_AUDJPY_COINTEGRATION_D1_D1_backtest.set",
            )

            registry = {
                ("AUDUSD.DWX", "D1"): {
                    "first_year": 2017,
                    "last_year": 2026,
                    "source_terminals": "T3,T7",
                },
                ("AUDJPY.DWX", "D1"): {
                    "first_year": 2017,
                    "last_year": 2026,
                    "source_terminals": "T3",
                },
                ("USDJPY.DWX", "D1"): {
                    "first_year": 2017,
                    "last_year": 2026,
                    "source_terminals": "T3",
                },
            }
            old_registry = terminal_worker.farmctl._dwx_symbol_history_registry
            old_free_ram = terminal_worker._free_ram_gb
            try:
                terminal_worker.farmctl._dwx_symbol_history_registry = lambda: registry
                terminal_worker._free_ram_gb = lambda: 64.0
                skipped = terminal_worker.claim_atomic(root, "T7")
                claimed = terminal_worker.claim_atomic(root, "T3")
            finally:
                terminal_worker.farmctl._dwx_symbol_history_registry = old_registry
                terminal_worker._free_ram_gb = old_free_ram

            self.assertFalse(skipped.get("claimed"))
            self.assertEqual(skipped.get("reason"), "no_pending_claimable")
            self.assertEqual(skipped["history_skipped"][0]["reason"], terminal_worker.TERMINAL_NO_SYMBOL_HISTORY_REASON)
            self.assertEqual(skipped["history_skipped"][0]["symbol"], "AUDJPY.DWX")
            self.assertEqual(
                skipped["history_skipped"][0]["history_check_symbols"],
                ["AUDUSD.DWX", "AUDJPY.DWX", "USDJPY.DWX"],
            )
            self.assertTrue(claimed.get("claimed"))
            self.assertEqual(claimed["item"]["id"], "wi-audusd-audjpy-q03")

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
            self.assertEqual(result["launch_fault_count"], 1)
            self.assertEqual(result["launch_fault_defer_seconds"], terminal_worker.LAUNCH_FAULT_DEFER_SECONDS)
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
            self.assertEqual(payload["launch_fault_defer_seconds"], terminal_worker.LAUNCH_FAULT_DEFER_SECONDS)
            self.assertIn("launch_not_before_utc", payload)

    def test_fast_phase_runner_with_host_keyed_aggregate_finishes_item(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            report_root = root / "reports" / "wi-q05-basket"
            aggregate = report_root / "QM5_9999" / "Q05" / "EURGBP_DWX" / "aggregate.json"
            aggregate.parent.mkdir(parents=True)
            aggregate.write_text(
                json.dumps({
                    "phase": "Q05",
                    "verdict": "INVALID",
                    "reason": "invalid_summary:NO_HISTORY,BARS_ZERO",
                    "summary_path": str(report_root / "summary.json"),
                    "trades": 0,
                }),
                encoding="utf-8",
            )
            self._insert_work_item(
                root,
                "wi-q05-basket",
                "QM5_9999_EURGBP_EURAUD_COINTEGRATION_D1",
                phase="Q05",
                status="active",
                claimed_by="T4",
                payload={"report_root": str(report_root)},
            )

            old_pid_tree_exists = terminal_worker.farmctl._pid_tree_exists
            old_terminal_slot_running = terminal_worker._terminal_slot_running
            old_sleep = terminal_worker.time.sleep
            try:
                terminal_worker.farmctl._pid_tree_exists = lambda _pid: False
                terminal_worker._terminal_slot_running = lambda _root, _terminal: False
                terminal_worker.time.sleep = lambda _seconds: None

                result = terminal_worker._monitor_spawned_work_item(
                    root,
                    {
                        "id": "wi-q05-basket",
                        "phase": "Q05",
                        "ea_id": "QM5_9999",
                        "symbol": "QM5_9999_EURGBP_EURAUD_COINTEGRATION_D1",
                    },
                    "T4",
                    {"pid": 123456, "report_root": str(report_root)},
                    {"report_root": str(report_root)},
                    timeout_seconds=30,
                )
            finally:
                terminal_worker.farmctl._pid_tree_exists = old_pid_tree_exists
                terminal_worker._terminal_slot_running = old_terminal_slot_running
                terminal_worker.time.sleep = old_sleep

            self.assertEqual(result["status"], "done")
            self.assertEqual(result["verdict"], "INFRA_FAIL")
            self.assertIn("invalid_summary", result["reason"])
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, verdict, claimed_by, attempt_count, evidence_path, payload_json "
                    "FROM work_items WHERE id='wi-q05-basket'"
                ).fetchone()
            self.assertEqual(row[0], "done")
            self.assertEqual(row[1], "INFRA_FAIL")
            self.assertIsNone(row[2])
            self.assertEqual(row[3], 0)
            self.assertEqual(Path(row[4]), aggregate)
            payload = json.loads(row[5])
            self.assertEqual(payload["evidence_provenance"], "phase_runner")
            self.assertEqual(payload["run_smoke_exit_code"], 0)

    def test_parent_aggregate_preserves_all_infra_fail_verdict(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks(
                        id, kind, status, source_id, card_id, payload_json,
                        created_at, updated_at
                    )
                    VALUES (
                        'parent-q03', 'backtest_q03', 'pending', NULL,
                        'QM5_9998', ?, ?, ?
                    )
                    """,
                    (json.dumps({"ea_id": "QM5_9998", "phase": "Q03"}), now, now),
                )
                conn.execute(
                    """
                    INSERT INTO work_items(
                        id, kind, phase, ea_id, symbol, setfile_path, status,
                        verdict, attempt_count, parent_task_id, payload_json,
                        created_at, updated_at
                    )
                    VALUES (
                        'wi-infra', 'backtest', 'Q03', 'QM5_9998',
                        'QM5_9998_EURUSD_GBPUSD_COINTEGRATION_D1',
                        'dummy.set', 'done', 'INFRA_FAIL', 0,
                        'parent-q03', '{}', ?, ?
                    )
                    """,
                    (now, now),
                )
                conn.commit()

            result = terminal_worker._aggregate_finished_parent(root, "parent-q03")
            self.assertEqual(result["verdict"], "INFRA_FAIL")

            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, payload_json FROM tasks WHERE id='parent-q03'"
                ).fetchone()
            self.assertEqual(row[0], "done")
            classification = json.loads(row[1])["classification"]
            self.assertEqual(classification["verdict"], "INFRA_FAIL")
            self.assertEqual(classification["counts_by_verdict"]["INFRA_FAIL"], 1)

    def test_launch_fault_defer_seconds_backoff_caps(self) -> None:
        base = terminal_worker.LAUNCH_FAULT_DEFER_SECONDS
        cap = terminal_worker.LAUNCH_FAULT_DEFER_MAX_SECONDS

        self.assertEqual(terminal_worker._launch_fault_defer_seconds(0), base)
        self.assertEqual(terminal_worker._launch_fault_defer_seconds("1"), base * 2)
        self.assertEqual(terminal_worker._launch_fault_defer_seconds(3), base * 8)
        self.assertEqual(terminal_worker._launch_fault_defer_seconds(4), cap)
        self.assertEqual(terminal_worker._launch_fault_defer_seconds(99), cap)
        self.assertEqual(terminal_worker._launch_fault_defer_seconds("bad"), base)

    def test_repeated_launch_fault_persists_capped_backoff(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            self._insert_work_item(
                root,
                "wi-launch-fault-repeat",
                "EURAUD.DWX",
                phase="Q02",
                status="active",
                claimed_by="T4",
                payload={"launch_fault_count": 4},
            )

            result = terminal_worker._defer_launch_fault(
                root,
                "wi-launch-fault-repeat",
                "T4",
                {"pid": 123456},
                ran_seconds=0.1,
                child_tail="",
            )

            self.assertEqual(result["reason"], "launch_fault_deferred")
            self.assertEqual(result["launch_fault_count"], 5)
            self.assertEqual(result["launch_fault_defer_seconds"], terminal_worker.LAUNCH_FAULT_DEFER_MAX_SECONDS)
            self.assertIn("launch_not_before_utc", result)
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, verdict, claimed_by, attempt_count, payload_json FROM work_items WHERE id='wi-launch-fault-repeat'"
                ).fetchone()
            self.assertEqual(row[0], "pending")
            self.assertIsNone(row[1])
            self.assertIsNone(row[2])
            self.assertEqual(row[3], 0)
            payload = json.loads(row[4])
            self.assertEqual(payload["prior_failure"], "launch_fault")
            self.assertEqual(payload["launch_fault_count"], 5)
            self.assertEqual(payload["launch_fault_defer_seconds"], terminal_worker.LAUNCH_FAULT_DEFER_MAX_SECONDS)
            self.assertEqual(payload["last_launch_fault_terminal"], "T4")

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

    def test_finish_work_item_ignores_summary_run_tag_before_claim(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            claim_time = datetime.now(timezone.utc)
            old_run_time = claim_time - timedelta(minutes=5)
            old_run_tag = old_run_time.strftime("%Y%m%d_%H%M%S")
            report_root = root / "reports" / "wi-stale-summary"
            summary_path = report_root / "QM5_9999" / old_run_tag / "summary.json"
            summary_path.parent.mkdir(parents=True)
            summary_path.write_text(
                json.dumps({
                    "timestamp_utc": old_run_time.isoformat(),
                    "run_tag": old_run_tag,
                    "result": "PASS",
                    "model4_log_marker_detected": True,
                    "min_trades_required": 5,
                    "runs": [{"total_trades": 10}],
                }),
                encoding="utf-8",
            )
            os.utime(summary_path, (claim_time.timestamp(), claim_time.timestamp()))
            claim_iso = claim_time.isoformat().replace("+00:00", "Z")
            self._insert_work_item(
                root,
                "wi-stale-summary",
                "EURUSD.DWX",
                phase="Q02",
                status="active",
                claimed_by="T3",
                payload={
                    "report_root": str(report_root),
                    "pid": 123456,
                    "claimed_at_iso": claim_iso,
                    "started_at_iso": claim_iso,
                },
            )

            stopped: list[str] = []
            old_default_root = terminal_worker.farmctl.DEFAULT_ROOT
            old_stop_terminal_slot = terminal_worker.farmctl._stop_terminal_slot
            try:
                terminal_worker.farmctl.DEFAULT_ROOT = root
                terminal_worker.farmctl._stop_terminal_slot = lambda terminal: stopped.append(terminal) or True
                result = terminal_worker._finish_work_item(root, "wi-stale-summary", exit_code=0)
            finally:
                terminal_worker.farmctl.DEFAULT_ROOT = old_default_root
                terminal_worker.farmctl._stop_terminal_slot = old_stop_terminal_slot

            self.assertEqual(result["status"], "pending")
            self.assertEqual(stopped, ["T3"])
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, verdict, evidence_path, payload_json FROM work_items WHERE id='wi-stale-summary'"
                ).fetchone()
            self.assertEqual(row[0], "pending")
            self.assertIsNone(row[1])
            self.assertIsNone(row[2])
            self.assertEqual(json.loads(row[3])["prior_failure"], "summary_missing")

    def test_finish_work_item_accepts_summary_run_tag_after_claim(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            claim_time = datetime.now(timezone.utc)
            run_time = claim_time + timedelta(seconds=1)
            run_tag = run_time.strftime("%Y%m%d_%H%M%S")
            report_root = root / "reports" / "wi-fresh-summary"
            summary_path = report_root / "QM5_9999" / run_tag / "summary.json"
            summary_path.parent.mkdir(parents=True)
            summary_path.write_text(
                json.dumps({
                    "timestamp_utc": run_time.isoformat(),
                    "run_tag": run_tag,
                    "result": "PASS",
                    "model4_log_marker_detected": True,
                    "min_trades_required": 5,
                    "runs": [{"total_trades": 10}],
                }),
                encoding="utf-8",
            )
            claim_iso = claim_time.isoformat().replace("+00:00", "Z")
            self._insert_work_item(
                root,
                "wi-fresh-summary",
                "EURUSD.DWX",
                phase="Q02",
                status="active",
                claimed_by="T3",
                payload={
                    "report_root": str(report_root),
                    "pid": 123456,
                    "claimed_at_iso": claim_iso,
                    "started_at_iso": claim_iso,
                },
            )

            result = terminal_worker._finish_work_item(root, "wi-fresh-summary", exit_code=0)

            self.assertEqual(result["status"], "done")
            self.assertEqual(result["verdict"], "PASS")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, verdict, evidence_path FROM work_items WHERE id='wi-fresh-summary'"
                ).fetchone()
            self.assertEqual(row[0], "done")
            self.assertEqual(row[1], "PASS")
            self.assertEqual(Path(row[2]), summary_path)

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
            old_journal_bomb = terminal_worker._journal_bomb
            old_check_every = terminal_worker.LOG_BOMB_CHECK_EVERY_ITERS
            old_sleep = terminal_worker.time.sleep
            try:
                terminal_worker.farmctl._pid_tree_exists = lambda pid: int(pid) == 123456
                terminal_worker.farmctl._stop_pid_tree = lambda pid: stopped_children.append(int(pid)) or True
                terminal_worker._stop_terminal_slot_for_release = (
                    lambda _root, terminal: stopped_terminals.append(str(terminal)) or True
                )
                terminal_worker._journal_bomb = lambda _report_root, _sizes, _now_mono: (str(journal), 0.0, "test")
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
                terminal_worker._journal_bomb = old_journal_bomb
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

    def test_preflight_prefers_setfile_dir_when_sibling_versions_exist(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            repo = Path(tmp) / "repo"
            base_dir = repo / "framework" / "EAs" / "QM5_9997_sibling"
            v2_dir = repo / "framework" / "EAs" / "QM5_9997_sibling_v2"
            sets = v2_dir / "sets"
            sets.mkdir(parents=True)
            base_dir.mkdir(parents=True)
            (base_dir / "QM5_9997_sibling.ex5").write_bytes(b"compiled")
            (v2_dir / "QM5_9997_sibling_v2.ex5").write_bytes(b"compiled")
            setfile = sets / "QM5_9997_sibling_v2_XTIUSD.DWX_D1_backtest.set"
            setfile.write_text("Symbol=XTIUSD.DWX\n", encoding="utf-8")

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
                      ('wi-sibling-v2', 'backtest', 'Q02', 'QM5_9997', 'XTIUSD.DWX', ?,
                       'pending', NULL, 0, NULL, NULL, NULL, '{}', ?, ?)
                    """,
                    (str(setfile), now, now),
                )
                conn.commit()

            old_repo_root = terminal_worker.farmctl.REPO_ROOT
            try:
                terminal_worker.farmctl.REPO_ROOT = repo
                with sqlite3.connect(root / farmctl.DB_REL) as conn:
                    conn.row_factory = sqlite3.Row
                    row = conn.execute("SELECT * FROM work_items WHERE id='wi-sibling-v2'").fetchone()

                self.assertIsNone(terminal_worker._work_item_preflight_failure(row))
            finally:
                terminal_worker.farmctl.REPO_ROOT = old_repo_root

    def test_run_claimed_item_clears_stale_preflight_before_spawn(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            repo = Path(tmp) / "repo"
            ea_dir = repo / "framework" / "EAs" / "QM5_9996_stale-preflight"
            sets = ea_dir / "sets"
            sets.mkdir(parents=True)
            setfile = sets / "QM5_9996_stale-preflight_XTIUSD.DWX_D1_backtest.set"
            setfile.write_text("Symbol=XTIUSD.DWX\n", encoding="utf-8")
            (ea_dir / "QM5_9996_stale-preflight.ex5").write_bytes(b"compiled")
            old_evidence = root / "old" / "preflight_failure.json"
            old_evidence.parent.mkdir(parents=True)
            old_evidence.write_text("{}", encoding="utf-8")
            payload = {
                "preflight_failure": {"reason": "ea_dir_ambiguous", "detail": ["base", "v2"]},
                "preflight_failed_at": "2026-07-03T07:42:34Z",
                "verdict_reason": "ea_dir_ambiguous",
                "repair_handler": "R11_pending_unclaimable_work_item",
                "report_root": str(root / "old"),
                "pid": 123456789,
                "started_at_iso": "2026-07-03T07:42:34Z",
                "log_path": str(root / "old" / "run.log"),
            }

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
                      ('wi-stale-preflight', 'backtest', 'Q02', 'QM5_9996', 'XTIUSD.DWX', ?,
                       'active', NULL, 0, NULL, ?, 'T1', ?, ?, ?)
                    """,
                    (str(setfile), str(old_evidence), json.dumps(payload), now, now),
                )
                conn.commit()

            old_repo_root = terminal_worker.farmctl.REPO_ROOT
            old_spawn = terminal_worker.farmctl._spawn_work_item_runner
            old_pid_tree_exists = terminal_worker.farmctl._pid_tree_exists
            try:
                terminal_worker.farmctl.REPO_ROOT = repo
                terminal_worker.farmctl._pid_tree_exists = lambda _pid: (_ for _ in ()).throw(
                    AssertionError("stale preflight pid must be cleared before adoption")
                )

                def fake_spawn(_root: Path, item_row: sqlite3.Row, _terminal: str) -> dict[str, object]:
                    spawn_payload = json.loads(item_row["payload_json"])
                    for key in ("preflight_failure", "preflight_failed_at", "pid", "report_root", "log_path"):
                        self.assertNotIn(key, spawn_payload)
                    self.assertIsNone(item_row["evidence_path"])
                    self.assertEqual(spawn_payload["cleared_stale_preflight_reason"], "ea_dir_ambiguous")
                    return {
                        "spawned": False,
                        "pending_runner": True,
                        "reason": "test_pending_runner",
                        "log_path": str(root / "pending.log"),
                        "report_root": str(root / "pending"),
                    }

                terminal_worker.farmctl._spawn_work_item_runner = fake_spawn
                result = terminal_worker._run_claimed_item(root, {"id": "wi-stale-preflight"}, "T1", 30)
            finally:
                terminal_worker.farmctl.REPO_ROOT = old_repo_root
                terminal_worker.farmctl._spawn_work_item_runner = old_spawn
                terminal_worker.farmctl._pid_tree_exists = old_pid_tree_exists

            self.assertEqual(result["action"], "pending_runner")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT evidence_path, payload_json FROM work_items WHERE id='wi-stale-preflight'"
                ).fetchone()
            self.assertIsNone(row[0])
            updated_payload = json.loads(row[1])
            self.assertNotIn("preflight_failure", updated_payload)
            self.assertNotIn("pid", updated_payload)
            self.assertEqual(updated_payload["cleared_stale_preflight_reason"], "ea_dir_ambiguous")

    def test_preflight_resolves_absolute_setfile_outside_worker_repo_root(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            source_repo = Path(tmp) / "source_repo"
            stale_worker_repo = Path(tmp) / "stale_worker_repo"
            ea_dir = source_repo / "framework" / "EAs" / "QM5_9998_external-ea"
            sets = ea_dir / "sets"
            sets.mkdir(parents=True)
            stale_worker_repo.mkdir(parents=True)
            setfile = sets / "QM5_9998_external-ea_EURUSD.DWX_H1_backtest.set"
            setfile.write_text("Symbol=EURUSD.DWX\n", encoding="utf-8")
            (ea_dir / "QM5_9998_external-ea.ex5").write_bytes(b"compiled")

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
                      ('wi-external-setfile', 'backtest', 'Q04', 'QM5_9998', 'EURUSD.DWX', ?,
                       'pending', NULL, 0, NULL, NULL, NULL, '{}', ?, ?)
                    """,
                    (str(setfile), now, now),
                )
                conn.commit()

            old_repo_root = terminal_worker.farmctl.REPO_ROOT
            try:
                terminal_worker.farmctl.REPO_ROOT = stale_worker_repo
                with sqlite3.connect(root / farmctl.DB_REL) as conn:
                    conn.row_factory = sqlite3.Row
                    row = conn.execute(
                        "SELECT * FROM work_items WHERE id='wi-external-setfile'"
                    ).fetchone()

                self.assertIsNone(terminal_worker._work_item_preflight_failure(row))
            finally:
                terminal_worker.farmctl.REPO_ROOT = old_repo_root


if __name__ == "__main__":
    unittest.main()
