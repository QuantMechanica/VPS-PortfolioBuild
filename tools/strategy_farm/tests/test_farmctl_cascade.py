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
    def test_multi_asset_card_scales_min_trades_from_basket_frequency(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            cards_dir = root / "artifacts" / "cards_approved"
            cards_dir.mkdir(parents=True)
            (cards_dir / "QM5_1056_moskowitz-tsmom-multiasset.md").write_text(
                """---
ea_id: QM5_1056
slug: moskowitz-tsmom-multiasset
concepts:
  - "[[concepts/multi-asset]]"
expected_trades_per_year_per_symbol: 12
---

Universe: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, XAUUSD, XTIUSD, NDX.DWX, GDAXI.DWX.
""",
                encoding="utf-8",
            )

            info = farmctl._effective_min_trades(root, "QM5_1056", None, None, 2024)

            self.assertEqual(info["expected_trades_per_year_card"], 12)
            self.assertEqual(info["card_universe_symbol_count"], 9)
            self.assertEqual(info["min_trade_scope"], "basket_scaled_from_card")
            self.assertEqual(info["expected_trades_per_year_per_symbol"], 1)
            self.assertEqual(info["effective_min_trades"], 1)

    def test_enqueue_cascade_distinguishes_setfiles_for_same_symbol(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            repo_root = root / "repo"
            ea_dir = repo_root / "framework" / "EAs" / "QM5_9999_demo"
            ea_dir.mkdir(parents=True)
            (ea_dir / "QM5_9999_demo.ex5").write_text("compiled", encoding="utf-8")
            sets_dir = root / "sets"
            sets_dir.mkdir()
            setfile_a = sets_dir / "a.set"
            setfile_b = sets_dir / "b.set"
            setfile_a.write_text("", encoding="utf-8")
            setfile_b.write_text("", encoding="utf-8")
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
                       ?, 'done',
                       'PASS', 0, '{}', ?, ?),
                      ('p5-b', 'backtest', 'P5', 'QM5_9999', 'EURUSD.DWX',
                       ?, 'done',
                       'PASS', 0, '{}', ?, ?),
                      ('p5b-a', 'backtest', 'P5b', 'QM5_9999', 'EURUSD.DWX',
                       ?, 'pending',
                       NULL, 0, '{}', ?, ?)
                    """,
                    (str(setfile_a), now, now, str(setfile_b), now, now, str(setfile_a), now, now),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                result = farmctl.enqueue_cascade_backtest_for_ea(root, "QM5_9999", "P5b")
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertTrue(result["enqueued"])
            self.assertEqual([row["symbol"] for row in result["created"]], ["EURUSD.DWX"])
            self.assertEqual(result["created"][0]["setfile_path"], str(setfile_b))
            with sqlite3.connect(db) as conn:
                rows = conn.execute(
                    "SELECT setfile_path, payload_json FROM work_items WHERE phase='P5b' ORDER BY setfile_path"
                ).fetchall()
            self.assertEqual([row[0] for row in rows], [
                str(setfile_a),
                str(setfile_b),
            ])
            payload = json.loads(rows[1][1])
            self.assertEqual(payload["promoted_from_work_item"], "p5-b")

    def test_enqueue_p5_skips_when_cache_history_below_required_oos_window(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            sets_dir = root / "sets"
            sets_dir.mkdir()
            setfile = sets_dir / "a.set"
            setfile.write_text("", encoding="utf-8")
            repo_root = root / "repo"
            ea_dir = repo_root / "framework" / "EAs" / "QM5_9999_demo"
            ea_sets = ea_dir / "sets"
            ea_sets.mkdir(parents=True)
            (ea_dir / "QM5_9999_demo.ex5").write_text("compiled", encoding="utf-8")
            (ea_sets / "QM5_9999_demo_EURUSD.DWX_D1_backtest.set").write_text("", encoding="utf-8")
            mt5_root = root / "mt5"
            hist_dir = mt5_root / "T1" / "Bases" / "Custom" / "history" / "EURUSD.DWX"
            hist_dir.mkdir(parents=True)
            for year in (2023, 2024):
                (hist_dir / f"{year}.hcc").write_text("", encoding="utf-8")
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
                      ('p4-pass', 'backtest', 'P4', 'QM5_9999', 'EURUSD.DWX',
                       ?, 'done', 'PASS', 0, '{}', ?, ?)
                    """,
                    (str(setfile), now, now),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            old_mt5_root = farmctl.MT5_ROOT
            farmctl.REPO_ROOT = repo_root
            farmctl.MT5_ROOT = mt5_root
            try:
                result = farmctl.enqueue_cascade_backtest_for_ea(root, "QM5_9999", "P5")
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.MT5_ROOT = old_mt5_root

            self.assertTrue(result["enqueued"])
            self.assertEqual(result["created"], [])
            self.assertEqual(result["skipped_count"], 1)
            self.assertEqual(result["skipped_cache_history_count"], 1)
            self.assertEqual(result["skipped"][0]["reason"], "cache_history_below_required_oos_window")
            self.assertEqual(result["skipped"][0]["verdict"], "INVALID")
            with sqlite3.connect(db) as conn:
                rows = conn.execute("SELECT id, phase FROM work_items WHERE phase='P5'").fetchall()
            self.assertEqual(rows, [])


if __name__ == "__main__":
    unittest.main()
