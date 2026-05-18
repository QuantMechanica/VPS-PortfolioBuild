import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class CascadePromotionTests(unittest.TestCase):
    def test_enqueue_cascade_distinguishes_setfiles_for_same_symbol(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            db = root / "state" / "farm_state.sqlite"
            now = farmctl.utc_now()
            with sqlite3.connect(db) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       verdict, attempt_count, payload_json, created_at, updated_at)
                    VALUES
                      ('p5-a', 'backtest', 'P5', 'QM5_9999', 'EURUSD.DWX',
                       'C:/QM/repo/framework/EAs/QM5_9999/sets/a.set', 'done',
                       'PASS', 0, '{}', ?, ?),
                      ('p5-b', 'backtest', 'P5', 'QM5_9999', 'EURUSD.DWX',
                       'C:/QM/repo/framework/EAs/QM5_9999/sets/b.set', 'done',
                       'PASS', 0, '{}', ?, ?),
                      ('p5b-a', 'backtest', 'P5b', 'QM5_9999', 'EURUSD.DWX',
                       'C:/QM/repo/framework/EAs/QM5_9999/sets/a.set', 'pending',
                       NULL, 0, '{}', ?, ?)
                    """,
                    (now, now, now, now, now, now),
                )
                conn.commit()

            result = farmctl.enqueue_cascade_backtest_for_ea(root, "QM5_9999", "P5b")

            self.assertTrue(result["enqueued"])
            self.assertEqual([row["symbol"] for row in result["created"]], ["EURUSD.DWX"])
            self.assertEqual(result["created"][0]["setfile_path"], "C:/QM/repo/framework/EAs/QM5_9999/sets/b.set")
            with sqlite3.connect(db) as conn:
                rows = conn.execute(
                    "SELECT setfile_path, payload_json FROM work_items WHERE phase='P5b' ORDER BY setfile_path"
                ).fetchall()
            self.assertEqual([row[0] for row in rows], [
                "C:/QM/repo/framework/EAs/QM5_9999/sets/a.set",
                "C:/QM/repo/framework/EAs/QM5_9999/sets/b.set",
            ])
            payload = json.loads(rows[1][1])
            self.assertEqual(payload["promoted_from_work_item"], "p5-b")


if __name__ == "__main__":
    unittest.main()
