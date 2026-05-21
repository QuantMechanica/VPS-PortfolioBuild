import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class P2P3ProfitFilterTests(unittest.TestCase):
    def _write_summary(self, path: Path, net_profit: float) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps({
                "result": "PASS",
                "model4_log_marker_detected": True,
                "runs": [
                    {"status": "PASS", "total_trades": 10, "net_profit": net_profit},
                ],
            }),
            encoding="utf-8",
        )

    def test_p2_to_p3_only_promotes_profitable_symbols(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_dir = repo_root / "framework" / "EAs" / "QM5_9999_demo"
            ea_sets = ea_dir / "sets"
            ea_sets.mkdir(parents=True)
            (ea_dir / "QM5_9999_demo.ex5").write_text("compiled", encoding="utf-8")
            profit_set = ea_sets / "QM5_9999_demo_NDX.DWX_D1_backtest.set"
            loss_set = ea_sets / "QM5_9999_demo_EURUSD.DWX_D1_backtest.set"
            profit_set.write_text("", encoding="utf-8")
            loss_set.write_text("", encoding="utf-8")

            profit_summary = root / "reports" / "profit" / "summary.json"
            loss_summary = root / "reports" / "loss" / "summary.json"
            self._write_summary(profit_summary, 100.0)
            self._write_summary(loss_summary, -50.0)

            farmctl.init_db(root)
            db = root / "state" / "farm_state.sqlite"
            now = farmctl.utc_now()
            p2_payload = {
                "ea_id": "QM5_9999",
                "classification": {
                    "verdict": "PASS",
                    "surviving_symbols": ["NDX.DWX", "EURUSD.DWX"],
                },
            }
            with sqlite3.connect(db) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks
                      (id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
                    VALUES
                      ('p2-task', 'backtest_p2', 'done', NULL, NULL, ?, ?, ?)
                    """,
                    (json.dumps(p2_payload), now, now),
                )
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       verdict, attempt_count, parent_task_id, evidence_path,
                       payload_json, created_at, updated_at)
                    VALUES
                      ('p2-profit', 'backtest', 'P2', 'QM5_9999', 'NDX.DWX',
                       ?, 'done', 'PASS', 0, 'p2-task', ?, '{}', ?, ?),
                      ('p2-loss', 'backtest', 'P2', 'QM5_9999', 'EURUSD.DWX',
                       ?, 'done', 'PASS', 0, 'p2-task', ?, '{}', ?, ?)
                    """,
                    (
                        str(profit_set), str(profit_summary), now, now,
                        str(loss_set), str(loss_summary), now, now,
                    ),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            farmctl.REPO_ROOT = repo_root
            try:
                result = farmctl.enqueue_backtest(root, "p2-task", "P3")
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertTrue(result["enqueued"])
            self.assertEqual(
                [(row["symbol"], Path(row["setfile_path"]).name) for row in result["work_items_created"]],
                [("NDX.DWX", profit_set.name)],
            )
            self.assertEqual(len(result["work_items_skipped"]), 1)
            self.assertEqual(result["work_items_skipped"][0]["symbol"], "EURUSD.DWX")
            self.assertEqual(result["work_items_skipped"][0]["reason"], farmctl.P2_UNPROFITABLE_SYMBOL_REASON)
            self.assertEqual(result["work_items_skipped"][0]["p2_net_profit"], -50.0)

            with sqlite3.connect(db) as conn:
                rows = conn.execute("SELECT phase, symbol FROM work_items WHERE phase='P3'").fetchall()
            self.assertEqual(rows, [("P3", "NDX.DWX")])


if __name__ == "__main__":
    unittest.main()
