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
    def test_dispatch_claims_only_one_index_symbol_per_tick(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            farmctl.init_db(root)
            now = farmctl.utc_now()
            db = root / "state" / "farm_state.sqlite"
            rows = [
                ("wi-ndx", "QM5_9999", "NDX.DWX", now),
                ("wi-gdaxi", "QM5_9999", "GDAXI.DWX", now),
                ("wi-eurusd", "QM5_9999", "EURUSD.DWX", now),
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
                farmctl.MT5_TERMINALS = ("T1", "T2", "T3")
                farmctl._running_mt5_terminals = lambda: set()
                farmctl._spawn_run_smoke_for_work_item = fake_spawn
                result = farmctl.dispatch_work_items(root, timeout_minutes=8)
            finally:
                farmctl.MT5_TERMINALS = old_terminals
                farmctl._running_mt5_terminals = old_running
                farmctl._spawn_run_smoke_for_work_item = old_spawn

            self.assertEqual([item_id for item_id, _terminal in spawned], ["wi-ndx", "wi-eurusd"])
            self.assertIn(
                {
                    "action": "deferred_index_symbol_lock",
                    "item_id": "wi-gdaxi",
                    "ea_id": "QM5_9999",
                    "symbol": "GDAXI.DWX",
                    "active_index_symbols": ["NDX.DWX"],
                },
                result["actions"],
            )

            with sqlite3.connect(db) as conn:
                statuses = dict(conn.execute("SELECT id, status FROM work_items").fetchall())
            self.assertEqual(statuses["wi-ndx"], "active")
            self.assertEqual(statuses["wi-eurusd"], "active")
            self.assertEqual(statuses["wi-gdaxi"], "pending")


if __name__ == "__main__":
    unittest.main()
