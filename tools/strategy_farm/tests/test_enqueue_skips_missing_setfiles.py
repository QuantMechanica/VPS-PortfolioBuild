import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class MissingSetfileEnqueueTests(unittest.TestCase):
    def test_enqueue_cascade_skips_missing_setfile_path(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            repo_root = root / "repo"
            ea_dir = repo_root / "framework" / "EAs" / "QM5_9999_demo"
            ea_dir.mkdir(parents=True)
            (ea_dir / "QM5_9999_demo.ex5").write_text("compiled", encoding="utf-8")
            missing_setfile = root / "sets" / "missing_grid_036.set"
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
                      ('p4-missing-grid', 'backtest', 'P4', 'QM5_9999', 'EURUSD.DWX',
                       ?, 'done', 'PASS', 0, '{}', ?, ?)
                    """,
                    (str(missing_setfile), now, now),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                result = farmctl.enqueue_cascade_backtest_for_ea(root, "QM5_9999", "P5")
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertTrue(result["enqueued"])
            self.assertEqual(result["created"], [])
            self.assertEqual(result["requeued"], [])
            self.assertEqual(result["skipped_count"], 1)
            self.assertEqual(result["skipped_missing_setfiles_count"], 1)
            self.assertEqual(result["skipped"][0]["reason"], "missing_setfile")
            self.assertEqual(result["skipped"][0]["setfile_path"], str(missing_setfile))
            with sqlite3.connect(db) as conn:
                rows = conn.execute(
                    "SELECT id, phase FROM work_items WHERE phase='P5'"
                ).fetchall()
            self.assertEqual(rows, [])


if __name__ == "__main__":
    unittest.main()
