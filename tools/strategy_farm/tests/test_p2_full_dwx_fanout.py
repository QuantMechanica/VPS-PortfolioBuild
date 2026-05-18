import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class P2FullDwxFanoutTests(unittest.TestCase):
    def test_p2_enqueue_uses_full_dwx_matrix_not_card_universe_only(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_dir = repo_root / "framework" / "EAs" / "QM5_9999_demo"
            sets_dir = ea_dir / "sets"
            registry_dir = repo_root / "framework" / "registry"
            cards_dir = root / "artifacts" / "cards_approved"
            sets_dir.mkdir(parents=True)
            registry_dir.mkdir(parents=True)
            cards_dir.mkdir(parents=True)

            (registry_dir / "dwx_symbol_matrix.csv").write_text(
                "\n".join([
                    "symbol,asset_class,canonical_name_verified",
                    "EURUSD.DWX,forex,true",
                    "NDX.DWX,indices,true",
                    "SP500.DWX,indices,true",
                    "",
                ]),
                encoding="utf-8",
            )
            (registry_dir / "magic_numbers.csv").write_text(
                "\n".join([
                    "ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status",
                    "9999,demo,14,EURUSD.DWX,99990014,2026-05-18,test,active",
                    "9999,demo,22,NDX.DWX,99990022,2026-05-18,test,active",
                    "9999,demo,28,SP500.DWX,99990028,2026-05-18,test,active",
                    "",
                ]),
                encoding="utf-8",
            )
            (cards_dir / "QM5_9999_demo.md").write_text(
                """---
ea_id: QM5_9999
slug: demo
---

Universe: EURUSD.DWX
""",
                encoding="utf-8",
            )

            seed_set = sets_dir / "QM5_9999_demo_EURUSD.DWX_D1_backtest.set"
            seed_set.write_text(
                "\n".join([
                    "; symbol:       EURUSD.DWX",
                    "; timeframe:    D1",
                    "; magic_slot:   14",
                    "qm_magic_slot_offset=14",
                    "StrategyParam=7",
                    "",
                ]),
                encoding="utf-8",
            )

            farmctl.init_db(root)
            db = root / "state" / "farm_state.sqlite"
            now = farmctl.utc_now()
            review_payload = {
                "ea_id": "QM5_9999",
                "verdict": {"verdict": "APPROVE_FOR_BACKTEST"},
            }
            with sqlite3.connect(db) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks
                      (id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
                    VALUES
                      ('review-task', 'ea_review', 'done', NULL, 'QM5_9999', ?, ?, ?)
                    """,
                    (json.dumps(review_payload), now, now),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                result = farmctl.enqueue_backtest(root, "review-task", "P2")
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertTrue(result["enqueued"])
            self.assertEqual(
                [row["symbol"] for row in result["work_items_created"]],
                ["EURUSD.DWX", "NDX.DWX", "SP500.DWX"],
            )
            self.assertTrue((sets_dir / "QM5_9999_demo_NDX.DWX_D1_backtest.set").exists())
            self.assertTrue((sets_dir / "QM5_9999_demo_SP500.DWX_D1_backtest.set").exists())
            self.assertIn(
                "qm_magic_slot_offset=28",
                (sets_dir / "QM5_9999_demo_SP500.DWX_D1_backtest.set").read_text(encoding="utf-8"),
            )

            with sqlite3.connect(db) as conn:
                rows = conn.execute(
                    "SELECT phase, symbol FROM work_items ORDER BY symbol"
                ).fetchall()
            self.assertEqual(
                rows,
                [("P2", "EURUSD.DWX"), ("P2", "NDX.DWX"), ("P2", "SP500.DWX")],
            )


if __name__ == "__main__":
    unittest.main()
