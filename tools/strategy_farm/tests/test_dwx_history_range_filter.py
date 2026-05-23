import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class DwxHistoryRangeFilterTests(unittest.TestCase):
    def test_p2_enqueue_adjusts_skips_and_leaves_valid_full_window(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_dir = repo_root / "framework" / "EAs" / "QM5_9999_demo"
            sets_dir = ea_dir / "sets"
            registry_dir = repo_root / "framework" / "registry"
            sets_dir.mkdir(parents=True)
            registry_dir.mkdir(parents=True)
            (ea_dir / "QM5_9999_demo.ex5").write_text("compiled", encoding="utf-8")

            (registry_dir / "dwx_symbol_matrix.csv").write_text(
                "\n".join([
                    "symbol,asset_class,canonical_name_verified",
                    "GDAXI.DWX,indices,true",
                    "UNKNOWN_SYM.DWX,indices,true",
                    "EURUSD.DWX,forex,true",
                    "",
                ]),
                encoding="utf-8",
            )
            (registry_dir / "dwx_symbol_history_ranges.csv").write_text(
                "\n".join([
                    "symbol,period,first_year,last_year,source_terminals",
                    'GDAXI.DWX,D1,2018,2026,"T1,T2,T3,T4,T5"',
                    'EURUSD.DWX,D1,2017,2026,"T1,T2,T3,T4,T5"',
                    "",
                ]),
                encoding="utf-8",
            )
            (registry_dir / "magic_numbers.csv").write_text(
                "\n".join([
                    "ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status",
                    "9999,demo,10,EURUSD.DWX,99990010,2026-05-18,test,active",
                    "9999,demo,20,GDAXI.DWX,99990020,2026-05-18,test,active",
                    "9999,demo,30,UNKNOWN_SYM.DWX,99990030,2026-05-18,test,active",
                    "",
                ]),
                encoding="utf-8",
            )

            seed_set = sets_dir / "QM5_9999_demo_EURUSD.DWX_D1_backtest.set"
            seed_set.write_text(
                "\n".join([
                    "; symbol:       EURUSD.DWX",
                    "; timeframe:    D1",
                    "; magic_slot:   10",
                    "qm_magic_slot_offset=10",
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
            created = {row["symbol"]: row for row in result["work_items_created"]}
            self.assertEqual(set(created), {"EURUSD.DWX", "GDAXI.DWX"})
            self.assertEqual(created["GDAXI.DWX"]["payload"]["from_year"], 2018)
            self.assertEqual(created["GDAXI.DWX"]["payload"]["to_year"], 2022)
            self.assertTrue(created["GDAXI.DWX"]["payload"]["history_adjusted"])
            self.assertEqual(created["EURUSD.DWX"]["payload"]["from_year"], 2017)
            self.assertEqual(created["EURUSD.DWX"]["payload"]["to_year"], 2022)
            self.assertNotIn("history_adjusted", created["EURUSD.DWX"]["payload"])

            self.assertEqual(len(result["work_items_skipped"]), 1)
            self.assertEqual(result["work_items_skipped"][0]["symbol"], "UNKNOWN_SYM.DWX")
            self.assertEqual(result["work_items_skipped"][0]["reason"], farmctl.P2_SYMBOL_NO_HISTORY_REASON)

            log_text = (root / "logs" / "p2_history_range_filter.log").read_text(encoding="utf-8")
            self.assertIn("adjusted GDAXI.DWX P2 from 2017-2022 to 2018-2022", log_text)
            self.assertIn("skipping UNKNOWN_SYM.DWX/D1 no history for 2017-2022", log_text)


if __name__ == "__main__":
    unittest.main()
