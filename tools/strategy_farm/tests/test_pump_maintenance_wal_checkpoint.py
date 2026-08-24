"""WAL checkpoint added to pump_maintenance (router task 05035f17, 2026-08-24).

pump_maintenance() previously relied entirely on SQLite's implicit PASSIVE
auto-checkpoint, which does not keep up with ~10 concurrent terminal_worker
readers -- the live farm_state.sqlite-wal was observed at 459MB. This adds an
explicit, non-blocking wal_checkpoint step and asserts it actually shrinks a
WAL file that has real content to reclaim.

Rollback: delete the _wal_checkpoint() call and its "wal_checkpoint" key from
pump_maintenance()'s return dict; nothing else depends on it.
"""
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class WalCheckpointTests(unittest.TestCase):
    def _make_wal_db(self, root: Path) -> sqlite3.Connection:
        """Return the writer connection still OPEN so the WAL isn't
        auto-truncated on close before the test can measure it (SQLite
        checkpoints on the last connection closing)."""
        db_path = root / "state" / "farm_state.sqlite"
        db_path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(str(db_path))
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)")
        # Enough rows/bytes to guarantee the WAL has real content to
        # checkpoint (sqlite's default auto-checkpoint threshold is ~1000
        # pages; write comfortably past that).
        conn.executemany(
            "INSERT INTO t (v) VALUES (?)",
            [(f"row-{i}-" + "x" * 200,) for i in range(3000)],
        )
        conn.commit()
        return conn

    def test_wal_checkpoint_reclaims_space_when_no_reader_holds_a_snapshot(self):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            writer = self._make_wal_db(root)
            db_path = root / "state" / "farm_state.sqlite"
            before = farmctl._wal_file_size(db_path)
            self.assertGreater(before, 0, "fixture must produce a non-trivial WAL")

            result = farmctl._wal_checkpoint(root)
            writer.close()

            self.assertIn("passive", result)
            self.assertIn("truncate", result)
            self.assertEqual(result["before_wal_bytes"], before)
            after = farmctl._wal_file_size(db_path)
            self.assertEqual(result["after_wal_bytes"], after)
            # With no other connection holding a read snapshot, TRUNCATE must
            # fully succeed (busy=False) and the WAL file should shrink.
            self.assertFalse(result["truncate"]["busy"])
            self.assertLess(after, before)
            self.assertEqual(result["reclaimed_bytes"], before - after)

    def test_wal_checkpoint_is_non_fatal_when_db_missing(self):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            result = farmctl._wal_checkpoint(root)
        self.assertEqual(result, {"skipped": "db_missing"})

    def test_wal_checkpoint_issues_only_pragma_statements(self):
        # pump_maintenance()'s own docstring contract: "does not dispatch,
        # promote, enqueue, or alter verdicts." The checkpoint call must not
        # regress that -- it only opens a bare sqlite3 connection and issues
        # read-only PRAGMA statements, never a work_items/DML statement.
        import inspect

        source = inspect.getsource(farmctl._wal_checkpoint)
        body = source.split('"""', 2)[-1]  # drop the docstring, keep only code
        self.assertNotIn("work_items", body)
        for verb in ("INSERT", "UPDATE", "DELETE"):
            self.assertNotIn(verb, body.upper())

    def test_pump_maintenance_return_includes_wal_checkpoint_key(self):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            result = farmctl.pump_maintenance(root)
        self.assertIn("wal_checkpoint", result)
        self.assertFalse(result["dispatch_performed"])
        self.assertFalse(result["verdicts_changed"])


if __name__ == "__main__":
    unittest.main()
