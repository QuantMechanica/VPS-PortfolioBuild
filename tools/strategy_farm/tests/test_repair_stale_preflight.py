import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import repair  # noqa: E402


class RepairStalePreflightTests(unittest.TestCase):
    def test_clears_pending_stale_preflight_when_artifacts_exist(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo = Path(tmp) / "repo"
            ea_dir = repo / "framework" / "EAs" / "QM5_9991_stale-preflight"
            sets = ea_dir / "sets"
            sets.mkdir(parents=True)
            setfile = sets / "QM5_9991_stale-preflight_EURUSD.DWX_D1_backtest.set"
            setfile.write_text("Symbol=EURUSD.DWX\n", encoding="utf-8")
            (ea_dir / "QM5_9991_stale-preflight.ex5").write_bytes(b"compiled")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            payload = {
                "preflight_failure": {
                    "reason": "ea_dir_missing",
                    "detail": "old-worktree/framework/EAs/QM5_9991_*",
                },
                "preflight_failed_at": "2026-07-03T07:42:34Z",
                "verdict_reason": "ea_dir_missing",
                "repair_handler": "R11_pending_unclaimable_work_item",
                "report_root": str(root / "old"),
                "pid": 123456789,
                "log_path": str(root / "old" / "run.log"),
                "portfolio_scope": "basket",
            }
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                       attempt_count, parent_task_id, evidence_path, claimed_by,
                       payload_json, created_at, updated_at)
                    VALUES
                      ('wi-stale-preflight', 'backtest', 'Q04', 'QM5_9991',
                       'QM5_9991_EURUSD_COINTEGRATION_D1', ?, 'pending', NULL,
                       0, NULL, ?, NULL, ?, ?, ?)
                    """,
                    (
                        str(setfile),
                        str(root / "old" / "preflight_failure.json"),
                        json.dumps(payload),
                        now,
                        now,
                    ),
                )
                conn.commit()

            old_repair_repo = repair.REPO_ROOT
            old_farm_repo = repair.farmctl.REPO_ROOT
            try:
                repair.REPO_ROOT = repo
                repair.farmctl.REPO_ROOT = repo
                with sqlite3.connect(root / farmctl.DB_REL) as conn:
                    conn.row_factory = sqlite3.Row
                    fixes = repair.repair_clear_stale_preflight_work_items(conn)
            finally:
                repair.REPO_ROOT = old_repair_repo
                repair.farmctl.REPO_ROOT = old_farm_repo

            self.assertEqual(len(fixes), 1)
            self.assertEqual(fixes[0]["handler"], "R17_clear_stale_preflight_work_item")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    """
                    SELECT status, verdict, evidence_path, payload_json
                    FROM work_items
                    WHERE id='wi-stale-preflight'
                    """
                ).fetchone()
            self.assertEqual(row[0], "pending")
            self.assertIsNone(row[1])
            self.assertIsNone(row[2])
            updated_payload = json.loads(row[3])
            self.assertNotIn("preflight_failure", updated_payload)
            self.assertNotIn("preflight_failed_at", updated_payload)
            self.assertNotIn("pid", updated_payload)
            self.assertEqual(updated_payload["portfolio_scope"], "basket")
            self.assertEqual(updated_payload["cleared_stale_preflight_reason"], "ea_dir_missing")

    def test_keeps_stale_preflight_when_artifacts_are_still_missing(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo = Path(tmp) / "repo"
            repo.mkdir(parents=True)
            missing_setfile = repo / "framework" / "EAs" / "QM5_9992_missing" / "sets" / "missing.set"

            farmctl.init_db(root)
            now = farmctl.utc_now()
            payload = {"preflight_failure": {"reason": "setfile_missing"}}
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                       attempt_count, parent_task_id, evidence_path, claimed_by,
                       payload_json, created_at, updated_at)
                    VALUES
                      ('wi-missing', 'backtest', 'Q04', 'QM5_9992', 'EURUSD.DWX', ?,
                       'pending', NULL, 0, NULL, 'old.json', NULL, ?, ?, ?)
                    """,
                    (str(missing_setfile), json.dumps(payload), now, now),
                )
                conn.commit()

            old_repair_repo = repair.REPO_ROOT
            old_farm_repo = repair.farmctl.REPO_ROOT
            try:
                repair.REPO_ROOT = repo
                repair.farmctl.REPO_ROOT = repo
                with sqlite3.connect(root / farmctl.DB_REL) as conn:
                    conn.row_factory = sqlite3.Row
                    fixes = repair.repair_clear_stale_preflight_work_items(conn)
            finally:
                repair.REPO_ROOT = old_repair_repo
                repair.farmctl.REPO_ROOT = old_farm_repo

            self.assertEqual(fixes, [])
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                payload_after = json.loads(
                    conn.execute("SELECT payload_json FROM work_items WHERE id='wi-missing'").fetchone()[0]
                )
            self.assertIn("preflight_failure", payload_after)


if __name__ == "__main__":
    unittest.main()
