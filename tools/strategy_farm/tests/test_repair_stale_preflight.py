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

    def test_supersedes_duplicate_pending_q02_rows_for_same_setfile(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo = Path(tmp) / "repo"
            ea_dir = repo / "framework" / "EAs" / "QM5_9993_duplicate-q02"
            sets = ea_dir / "sets"
            sets.mkdir(parents=True)
            setfile = sets / "QM5_9993_duplicate-q02_EURUSD.DWX_D1_backtest.set"
            setfile.write_text("Symbol=EURUSD.DWX\n", encoding="utf-8")
            (ea_dir / "QM5_9993_duplicate-q02.ex5").write_bytes(b"compiled")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks
                      (id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
                    VALUES
                      ('parent-q02', 'backtest_p2', 'pending', NULL, 'QM5_9993', '{}', ?, ?)
                    """,
                    (now, now),
                )
                for item_id, parent_id, attempt_count, payload in [
                    (
                        "wi-parent",
                        "parent-q02",
                        1,
                        {"claimed_by_worker_pid": 12345, "terminal": "T4", "prior_failure": "summary_missing"},
                    ),
                    ("wi-orphan", None, 0, {"enqueued_by": "manual_retry"}),
                    ("wi-older-dup", None, 1, {"final_failure": "summary_missing"}),
                ]:
                    conn.execute(
                        """
                        INSERT INTO work_items
                          (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                           attempt_count, parent_task_id, evidence_path, claimed_by,
                           payload_json, created_at, updated_at)
                        VALUES
                          (?, 'backtest', 'Q02', 'QM5_9993', 'EURUSD.DWX', ?,
                           'pending', NULL, ?, ?, 'old.json', NULL, ?, ?, ?)
                        """,
                        (
                            item_id,
                            str(setfile),
                            attempt_count,
                            parent_id,
                            json.dumps(payload),
                            now,
                            now,
                        ),
                    )
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                       attempt_count, parent_task_id, evidence_path, claimed_by,
                       payload_json, created_at, updated_at)
                    VALUES
                      ('wi-done', 'backtest', 'Q02', 'QM5_9993', 'EURUSD.DWX', ?,
                       'done', 'INFRA_FAIL', 0, NULL, 'done.json', NULL, '{}', ?, ?)
                    """,
                    (str(setfile), now, now),
                )
                conn.commit()

            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.row_factory = sqlite3.Row
                fixes = repair.repair_duplicate_pending_q02_work_items(conn, ea_id_filter="QM5_9993")

            self.assertEqual(len(fixes), 1)
            self.assertEqual(fixes[0]["handler"], "R18_duplicate_pending_q02_work_item")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                rows = {
                    row[0]: row
                    for row in conn.execute(
                        """
                        SELECT id, status, verdict, evidence_path, payload_json
                        FROM work_items
                        ORDER BY id
                        """
                    ).fetchall()
                }
            self.assertEqual(rows["wi-parent"][1], "pending")
            self.assertIsNone(rows["wi-parent"][2])
            self.assertIsNone(rows["wi-parent"][3])
            survivor_payload = json.loads(rows["wi-parent"][4])
            self.assertNotIn("claimed_by_worker_pid", survivor_payload)
            self.assertNotIn("terminal", survivor_payload)
            self.assertNotIn("prior_failure", survivor_payload)
            self.assertEqual(survivor_payload["duplicate_repair_suppressed_count"], 2)
            self.assertEqual(rows["wi-orphan"][1:3], ("failed", "INVALID"))
            self.assertEqual(rows["wi-older-dup"][1:3], ("failed", "INVALID"))
            self.assertEqual(json.loads(rows["wi-orphan"][4])["superseded_by_work_item_id"], "wi-parent")
            self.assertEqual(rows["wi-done"][1:3], ("done", "INFRA_FAIL"))


if __name__ == "__main__":
    unittest.main()
