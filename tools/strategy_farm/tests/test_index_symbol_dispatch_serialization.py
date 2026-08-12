import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class IndexSymbolDispatchSerializationTests(unittest.TestCase):
    def _dispatch_symbols(
        self, symbols: list[str], terminals: tuple[str, ...] = ("T1", "T2", "T3")
    ) -> tuple[list[tuple[str, str]], dict[str, object], dict[str, str]]:
        return self._dispatch_rows([("QM5_9999", symbol) for symbol in symbols], terminals)

    def _dispatch_rows(
        self,
        rows_spec: list[tuple[str, str]],
        terminals: tuple[str, ...] = ("T1", "T2", "T3"),
    ) -> tuple[list[tuple[str, str]], dict[str, object], dict[str, str]]:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            farmctl.init_db(root)
            now = farmctl.utc_now()
            db = root / "state" / "farm_state.sqlite"
            rows = [
                (f"wi-{index}", ea_id, symbol, now)
                for index, (ea_id, symbol) in enumerate(rows_spec, start=1)
            ]
            with sqlite3.connect(db) as conn:
                conn.executemany(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                       attempt_count, parent_task_id, evidence_path, claimed_by,
                       payload_json, created_at, updated_at)
                    VALUES
                      (?, 'backtest', 'P2', ?, ?, 'dummy.set', 'pending', NULL,
                       0, NULL, NULL, NULL, ?, ?, ?)
                    """,
                    [(item_id, ea_id, symbol, json.dumps({}), created_at, created_at) for item_id, ea_id, symbol, created_at in rows],
                )
                conn.commit()

            spawned: list[tuple[str, str]] = []

            def fake_spawn(_root: Path, item_row: sqlite3.Row, terminal: str) -> dict[str, object]:
                spawned.append((item_row["id"], terminal))
                return {
                    "spawned": True,
                    "pid": 9000 + len(spawned),
                    "process_creation_key": f"test:{9000 + len(spawned)}",
                    "log_path": str(root / "logs" / f"{item_row['id']}.log"),
                    "report_root": str(root / "reports" / item_row["id"]),
                    "ea_dir_name": "QM5_9999_demo",
                    "expected_trades_per_year_per_symbol": 1,
                    "smoke_year_count": 1,
                    "effective_min_trades": 1,
                }

            old_terminals = farmctl.MT5_TERMINALS
            old_running = farmctl._running_mt5_terminals
            old_spawn = farmctl._spawn_run_smoke_for_work_item
            try:
                farmctl.MT5_TERMINALS = terminals
                farmctl._running_mt5_terminals = lambda: set()
                farmctl._spawn_run_smoke_for_work_item = fake_spawn
                result = farmctl.dispatch_work_items(root, timeout_minutes=8)
            finally:
                farmctl.MT5_TERMINALS = old_terminals
                farmctl._running_mt5_terminals = old_running
                farmctl._spawn_run_smoke_for_work_item = old_spawn

            with sqlite3.connect(db) as conn:
                statuses = dict(conn.execute("SELECT id, status FROM work_items").fetchall())
            return spawned, result, statuses

    def test_dispatch_defers_duplicate_index_symbol(self) -> None:
        spawned, result, statuses = self._dispatch_symbols(["NDX.DWX", "NDX.DWX"])

        self.assertEqual([item_id for item_id, _terminal in spawned], ["wi-1"])
        self.assertIn(
            {
                "action": "deferred_symbol_lock",
                "reason": "symbol_already_active_on_other_terminal",
                "item_id": "wi-2",
                "ea_id": "QM5_9999",
                "symbol": "NDX.DWX",
                "active_symbol": "NDX.DWX",
            },
            result["actions"],
        )
        self.assertEqual(statuses["wi-1"], "active")
        self.assertEqual(statuses["wi-2"], "pending")

    def test_dispatch_allows_different_index_symbols_in_parallel(self) -> None:
        spawned, _result, statuses = self._dispatch_symbols(["NDX.DWX", "SP500.DWX", "GDAXI.DWX"])

        self.assertEqual([item_id for item_id, _terminal in spawned], ["wi-1", "wi-2", "wi-3"])
        self.assertEqual(statuses["wi-1"], "active")
        self.assertEqual(statuses["wi-2"], "active")
        self.assertEqual(statuses["wi-3"], "active")

    def test_dispatch_same_symbol_across_eas_runs_up_to_cap(self) -> None:
        # Variant-A relaxation (2026-08-12): different EAs on the same symbol
        # dispatch in parallel up to CLAIM_SYMBOL_ACTIVE_CAP; the overflow is
        # deferred with the dedicated cap action, not the duplicate lock.
        rows = [(f"QM5_80{i:02d}", "XAUUSD.DWX") for i in range(6)]
        spawned, result, statuses = self._dispatch_rows(
            rows, terminals=("T1", "T2", "T3", "T4", "T5", "T6")
        )

        self.assertEqual(len(spawned), farmctl.CLAIM_SYMBOL_ACTIVE_CAP)
        capped = [a for a in result["actions"] if a.get("action") == "deferred_symbol_cap"]
        self.assertEqual(len(capped), 6 - farmctl.CLAIM_SYMBOL_ACTIVE_CAP)
        for action in capped:
            self.assertEqual(action["reason"], "symbol_active_cap_reached")
            self.assertEqual(action["cap"], farmctl.CLAIM_SYMBOL_ACTIVE_CAP)
            self.assertEqual(action["active_count"], farmctl.CLAIM_SYMBOL_ACTIVE_CAP)
        self.assertEqual(
            sum(1 for status in statuses.values() if status == "active"),
            farmctl.CLAIM_SYMBOL_ACTIVE_CAP,
        )

    def test_dispatch_duplicate_ea_symbol_defers_below_cap(self) -> None:
        # Two rows of ONE (ea_id, symbol) — the literal 2026-05-18 crash shape —
        # stay serialized even though the symbol cap has headroom.
        rows = [("QM5_8000", "XAUUSD.DWX"), ("QM5_8000", "XAUUSD.DWX")]
        spawned, result, statuses = self._dispatch_rows(
            rows, terminals=("T1", "T2", "T3", "T4", "T5", "T6")
        )

        self.assertEqual([item_id for item_id, _terminal in spawned], ["wi-1"])
        self.assertIn(
            {
                "action": "deferred_symbol_lock",
                "reason": "symbol_already_active_on_other_terminal",
                "item_id": "wi-2",
                "ea_id": "QM5_8000",
                "symbol": "XAUUSD.DWX",
                "active_symbol": "XAUUSD.DWX",
            },
            result["actions"],
        )
        self.assertEqual(statuses["wi-1"], "active")
        self.assertEqual(statuses["wi-2"], "pending")

    def test_dispatch_defers_duplicate_forex_symbol(self) -> None:
        spawned, result, statuses = self._dispatch_symbols(["EURUSD.DWX", "EURUSD.DWX"])

        self.assertEqual([item_id for item_id, _terminal in spawned], ["wi-1"])
        self.assertIn(
            {
                "action": "deferred_symbol_lock",
                "reason": "symbol_already_active_on_other_terminal",
                "item_id": "wi-2",
                "ea_id": "QM5_9999",
                "symbol": "EURUSD.DWX",
                "active_symbol": "EURUSD.DWX",
            },
            result["actions"],
        )
        self.assertEqual(statuses["wi-1"], "active")
        self.assertEqual(statuses["wi-2"], "pending")

    def test_dispatch_worker_died_release_stops_terminal_slot(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            farmctl.init_db(root)
            now = farmctl.utc_now()
            payload = {
                "pid": 999999,
                "started_at_iso": "2026-05-19T00:00:00+00:00",
                "report_root": str(root / "reports" / "wi-dead"),
            }
            db = root / "state" / "farm_state.sqlite"
            with sqlite3.connect(db) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                       attempt_count, parent_task_id, evidence_path, claimed_by,
                       payload_json, created_at, updated_at)
                    VALUES
                      ('wi-dead', 'backtest', 'P2', 'QM5_9999', 'EURUSD.DWX', 'dummy.set',
                       'active', NULL, 0, NULL, NULL, 'T1', ?, ?, ?)
                    """,
                    (json.dumps(payload), now, now),
                )
                conn.commit()

            stopped: list[str] = []
            old_pid_exists = farmctl._pid_exists
            old_running = farmctl._running_mt5_terminals
            old_stop_terminal = farmctl._stop_terminal_slot
            old_terminals = farmctl.MT5_TERMINALS
            try:
                farmctl._pid_exists = lambda _pid: False
                farmctl._running_mt5_terminals = lambda: {"T1"}
                farmctl._stop_terminal_slot = lambda terminal: stopped.append(terminal) or True
                farmctl.MT5_TERMINALS = ()
                result = farmctl.dispatch_work_items(root, timeout_minutes=8)
            finally:
                farmctl._pid_exists = old_pid_exists
                farmctl._running_mt5_terminals = old_running
                farmctl._stop_terminal_slot = old_stop_terminal
                farmctl.MT5_TERMINALS = old_terminals

            self.assertIn("T1", stopped)
            self.assertIn(
                {
                    "action": "retry_worker_died",
                    "item_id": "wi-dead",
                    "terminal_released": "T1",
                    "attempt": 1,
                    "worker_pid": 999999,
                    "terminal_stopped": True,
                },
                result["actions"],
            )
            with sqlite3.connect(db) as conn:
                row = conn.execute("SELECT status, claimed_by, payload_json FROM work_items WHERE id='wi-dead'").fetchone()
            self.assertEqual(row[0], "pending")
            self.assertIsNone(row[1])
            updated = json.loads(row[2])
            self.assertEqual(updated["prior_failure"], "worker_died")
            self.assertTrue(updated["terminal_stopped_on_release"])

    def test_legacy_dispatch_tick_respects_running_mt5_slots(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            farmctl.init_db(root)
            now = farmctl.utc_now()
            db = root / "state" / "farm_state.sqlite"
            with sqlite3.connect(db) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks
                      (id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
                    VALUES
                      ('task-p2', 'backtest_p2', 'pending', NULL, 'QM5_9999',
                       ?, ?, ?)
                    """,
                    (json.dumps({"phase": "P2", "ea_id": "QM5_9999"}), now, now),
                )
                conn.commit()

            old_terminals = farmctl.MT5_TERMINALS
            old_running = farmctl._running_mt5_terminals
            old_popen = farmctl.subprocess.Popen
            try:
                farmctl.MT5_TERMINALS = ("T1",)
                farmctl._running_mt5_terminals = lambda: {"T1"}
                farmctl.subprocess.Popen = lambda *_args, **_kwargs: self.fail("legacy dispatch used busy T1")

                result = farmctl.dispatch_tick(root)
            finally:
                farmctl.MT5_TERMINALS = old_terminals
                farmctl._running_mt5_terminals = old_running
                farmctl.subprocess.Popen = old_popen

            self.assertEqual(result["busy_terminals"], ["T1"])
            self.assertEqual(result["free_terminals"], [])
            self.assertNotIn("started", [action.get("action") for action in result["actions"]])
            with sqlite3.connect(db) as conn:
                status = conn.execute("SELECT status FROM tasks WHERE id='task-p2'").fetchone()[0]
            self.assertEqual(status, "pending")


if __name__ == "__main__":
    unittest.main()
