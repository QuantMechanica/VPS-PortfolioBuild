from __future__ import annotations

import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm import farmctl


class SetfileCanonicalizationTests(unittest.TestCase):
    def test_stale_worktree_setfile_maps_to_canonical_repo_copy(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            canonical_eas = root / "repo" / "framework" / "EAs"
            ea_dir = canonical_eas / "QM5_9004_demo"
            set_dir = ea_dir / "sets"
            set_dir.mkdir(parents=True)
            setfile_name = "QM5_9004_demo_EURUSD.DWX_M15_backtest.set"
            canonical = set_dir / setfile_name
            canonical.write_text("qm_magic_slot_offset=0\n", encoding="utf-8")

            stale = (
                root
                / "worktrees"
                / "agent-a"
                / "framework"
                / "EAs"
                / "QM5_9004_demo"
                / "sets"
                / setfile_name
            )

            old_eas = farmctl.FRAMEWORK_EAS_DIR
            try:
                farmctl.FRAMEWORK_EAS_DIR = canonical_eas
                resolved = farmctl._canonical_setfile_path_for_work_item(
                    "QM5_9004", stale
                )
            finally:
                farmctl.FRAMEWORK_EAS_DIR = old_eas

            self.assertEqual(resolved, str(canonical))

    def test_non_worktree_or_missing_canonical_setfile_is_left_unchanged(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            canonical_eas = root / "repo" / "framework" / "EAs"
            canonical_eas.mkdir(parents=True)
            repo_setfile = (
                canonical_eas
                / "QM5_9004_demo"
                / "sets"
                / "QM5_9004_demo_EURUSD.DWX_M15_backtest.set"
            )
            missing_canonical_stale = (
                root
                / "worktrees"
                / "agent-a"
                / "framework"
                / "EAs"
                / "QM5_9004_demo"
                / "sets"
                / "QM5_9004_demo_USDJPY.DWX_M15_backtest.set"
            )

            old_eas = farmctl.FRAMEWORK_EAS_DIR
            try:
                farmctl.FRAMEWORK_EAS_DIR = canonical_eas
                self.assertIsNone(
                    farmctl._canonical_setfile_path_for_work_item("QM5_9004", repo_setfile)
                )
                self.assertIsNone(
                    farmctl._canonical_setfile_path_for_work_item(
                        "QM5_9004", missing_canonical_stale
                    )
                )
                self.assertIsNone(
                    farmctl._canonical_setfile_path_for_work_item(
                        "QM5_9005", missing_canonical_stale
                    )
                )
            finally:
                farmctl.FRAMEWORK_EAS_DIR = old_eas

    def test_dispatch_persists_spawn_effective_setfile_path(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            stale = str(Path(tmp) / "worktrees" / "agent-a" / "old.set")
            canonical = str(
                Path(tmp)
                / "repo"
                / "framework"
                / "EAs"
                / "QM5_9004_demo"
                / "sets"
                / "new.set"
            )
            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items(
                        id, kind, phase, ea_id, symbol, setfile_path, status,
                        attempt_count, payload_json, created_at, updated_at
                    )
                    VALUES (
                        'stale-q02', 'backtest', 'Q02', 'QM5_9004', 'EURUSD.DWX', ?,
                        'pending', 0, '{}', ?, ?
                    )
                    """,
                    (stale, now, now),
                )
                conn.commit()

            def fake_spawn(
                _root: Path, _row: sqlite3.Row, _terminal: str
            ) -> dict[str, object]:
                return {
                    "spawned": True,
                    "pid": 12345,
                    "log_path": str(root / "logs" / "fake.log"),
                    "report_root": str(root / "reports" / "stale-q02"),
                    "ea_dir_name": "QM5_9004_demo",
                    "setfile_path": canonical,
                    "setfile_path_canonicalized_from": stale,
                }

            old_terminals = farmctl.MT5_TERMINALS
            old_running = farmctl._running_mt5_terminals
            old_spawn = farmctl._spawn_work_item_runner
            try:
                farmctl.MT5_TERMINALS = ("T1",)
                farmctl._running_mt5_terminals = lambda: set()
                farmctl._spawn_work_item_runner = fake_spawn
                result = farmctl.dispatch_work_items(root, timeout_minutes=8)
            finally:
                farmctl.MT5_TERMINALS = old_terminals
                farmctl._running_mt5_terminals = old_running
                farmctl._spawn_work_item_runner = old_spawn

            self.assertEqual(result["actions"][0]["action"], "claimed")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT setfile_path, payload_json FROM work_items WHERE id='stale-q02'"
                ).fetchone()
            self.assertEqual(row[0], canonical)
            payload = json.loads(row[1])
            self.assertEqual(payload["setfile_path"], canonical)
            self.assertEqual(payload["setfile_path_canonicalized_from"], stale)


if __name__ == "__main__":
    unittest.main()
