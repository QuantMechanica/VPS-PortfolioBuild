import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class BasketWorkItemsTests(unittest.TestCase):
    def test_p2_enqueue_uses_one_logical_basket_work_item(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_dir = repo_root / "framework" / "EAs" / "QM5_10717_demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            (ea_dir / "QM5_10717_demo.ex5").write_text("compiled", encoding="utf-8")
            manifest = {
                "logical_symbol": "FX8_BASKET_D1",
                "host_symbol": "EURUSD.DWX",
                "host_timeframe": "D1",
                "basket_symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
                "currencies": ["USD", "EUR", "GBP"],
            }
            (ea_dir / "basket_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / "QM5_10717_demo_FX8_BASKET_D1_D1_backtest.set"
            setfile.write_text("; basket setfile\n", encoding="utf-8")

            farmctl.init_db(root)
            db = root / "state" / "farm_state.sqlite"
            now = farmctl.utc_now()
            with sqlite3.connect(db) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks
                      (id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
                    VALUES
                      ('review-task', 'ea_review', 'done', NULL, 'QM5_10717', ?, ?, ?)
                    """,
                    (json.dumps({"ea_id": "QM5_10717", "verdict": {"verdict": "APPROVE_FOR_BACKTEST"}}), now, now),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                result = farmctl.enqueue_backtest(root, "review-task", "P2")
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertTrue(result["enqueued"])
            self.assertEqual(len(result["work_items_created"]), 1)
            created = result["work_items_created"][0]
            self.assertEqual(created["symbol"], "FX8_BASKET_D1")
            self.assertEqual(created["setfile_path"], str(setfile.resolve()))
            self.assertEqual(created["payload"]["host_symbol"], "EURUSD.DWX")
            self.assertEqual(created["payload"]["host_timeframe"], "D1")
            self.assertEqual(created["payload"]["portfolio_scope"], "basket")


if __name__ == "__main__":
    unittest.main()
