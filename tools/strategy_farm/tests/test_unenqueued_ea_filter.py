from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm import farmctl, health


class UnenqueuedEaFilterTests(unittest.TestCase):
    def test_reject_rework_reviews_are_not_p2_enqueue_candidates(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo = Path(tmp) / "repo"
            eas = repo / "framework" / "EAs"
            approved_dir = eas / "QM5_9001_approved"
            rejected_dir = eas / "QM5_9002_rework"
            approved_dir.mkdir(parents=True)
            rejected_dir.mkdir(parents=True)
            (approved_dir / "QM5_9001_approved.ex5").write_text("compiled", encoding="utf-8")
            (rejected_dir / "QM5_9002_rework.ex5").write_text("compiled", encoding="utf-8")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            with farmctl.connect(root) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks(id, kind, status, card_id, payload_json, created_at, updated_at)
                    VALUES
                      ('review-approved', 'ea_review', 'done', 'QM5_9001', ?, ?, ?),
                      ('review-rework', 'ea_review', 'done', 'QM5_9002', ?, ?, ?)
                    """,
                    (
                        json.dumps({"ea_id": "QM5_9001", "verdict": {"verdict": "APPROVE_FOR_BACKTEST"}}),
                        now,
                        now,
                        json.dumps({"ea_id": "QM5_9002", "verdict": {"verdict": "REJECT_REWORK"}}),
                        now,
                        now,
                    ),
                )
                conn.commit()

            old_farm_eas = farmctl.FRAMEWORK_EAS_DIR
            old_health_eas = health.FRAMEWORK_EAS_DIR
            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo
                farmctl.FRAMEWORK_EAS_DIR = eas
                health.FRAMEWORK_EAS_DIR = eas
                with farmctl.connect(root) as conn:
                    candidates = farmctl._detect_unenqueued_eas(conn)
                    check = health.chk_unenqueued_eas_count(conn)
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.FRAMEWORK_EAS_DIR = old_farm_eas
                health.FRAMEWORK_EAS_DIR = old_health_eas

            self.assertEqual([row["ea_id"] for row in candidates], ["QM5_9001"])
            self.assertEqual(check["value"], 1)
            self.assertIn("QM5_9001", check["detail"])
            self.assertNotIn("QM5_9002", check["detail"])

    def test_basket_with_only_legacy_leg_q02_rows_still_needs_logical_q02(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo = Path(tmp) / "repo"
            eas = repo / "framework" / "EAs"
            ea_dir = eas / "QM5_9003_fxpair"
            ea_dir.mkdir(parents=True)
            (ea_dir / "QM5_9003_fxpair.ex5").write_text("compiled", encoding="utf-8")
            (ea_dir / "basket_manifest.json").write_text(
                json.dumps({
                    "logical_symbol": "QM5_9003_EURJPY_GBPJPY_COINTEGRATION_D1",
                    "host_symbol": "EURJPY.DWX",
                    "host_timeframe": "D1",
                    "basket_symbols": ["EURJPY.DWX", "GBPJPY.DWX"],
                }),
                encoding="utf-8",
            )

            farmctl.init_db(root)
            now = farmctl.utc_now()
            with farmctl.connect(root) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks(id, kind, status, card_id, payload_json, created_at, updated_at)
                    VALUES
                      ('review-basket', 'ea_review', 'done', 'QM5_9003', ?, ?, ?),
                      ('old-per-leg-q02', 'backtest_q02', 'failed', 'QM5_9003', ?, ?, ?)
                    """,
                    (
                        json.dumps({"ea_id": "QM5_9003", "verdict": {"verdict": "APPROVE_FOR_BACKTEST"}}),
                        now,
                        now,
                        json.dumps({"ea_id": "QM5_9003", "symbols": ["EURJPY.DWX", "GBPJPY.DWX"]}),
                        now,
                        now,
                    ),
                )
                for symbol in ("EURJPY.DWX", "GBPJPY.DWX"):
                    conn.execute(
                        """
                        INSERT INTO work_items(
                            id, kind, phase, ea_id, symbol, setfile_path, status,
                            verdict, attempt_count, parent_task_id, evidence_path,
                            claimed_by, payload_json, created_at, updated_at
                        )
                        VALUES (?, 'backtest', 'Q02', 'QM5_9003', ?, ?, 'failed',
                                'INVALID', 99, 'old-per-leg-q02', NULL, NULL, '{}', ?, ?)
                        """,
                        (
                            f"legacy-{symbol}",
                            symbol,
                            str(ea_dir / "sets" / f"{symbol}.set"),
                            now,
                            now,
                        ),
                    )
                conn.commit()

            old_farm_eas = farmctl.FRAMEWORK_EAS_DIR
            old_health_eas = health.FRAMEWORK_EAS_DIR
            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo
                farmctl.FRAMEWORK_EAS_DIR = eas
                health.FRAMEWORK_EAS_DIR = eas
                with farmctl.connect(root) as conn:
                    candidates = farmctl._detect_unenqueued_eas(conn)
                    check = health.chk_unenqueued_eas_count(conn)
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.FRAMEWORK_EAS_DIR = old_farm_eas
                health.FRAMEWORK_EAS_DIR = old_health_eas

            self.assertEqual([row["ea_id"] for row in candidates], ["QM5_9003"])
            self.assertEqual(check["value"], 1)
            self.assertIn("QM5_9003", check["detail"])


if __name__ == "__main__":
    unittest.main()
