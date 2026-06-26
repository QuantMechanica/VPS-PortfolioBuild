import json
import os
import sqlite3
import sys
import tempfile
import unittest
import datetime as dt
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class BasketWorkItemsTests(unittest.TestCase):
    def _insert_active_basket_q02(self, root: Path, *, item_id: str, age_minutes: int) -> None:
        farmctl.init_db(root)
        updated = (
            dt.datetime.now(dt.UTC).replace(microsecond=0)
            - dt.timedelta(minutes=age_minutes)
        ).isoformat()
        payload = {
            "portfolio_scope": "basket",
            "logical_symbol": "QM5_9001_EUR_GBP_BASKET_D1",
            "pid": None,
        }
        with sqlite3.connect(root / farmctl.DB_REL) as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   attempt_count, parent_task_id, evidence_path, claimed_by,
                   payload_json, created_at, updated_at)
                VALUES
                  (?, 'backtest', 'Q02', 'QM5_9001', 'QM5_9001_EUR_GBP_BASKET_D1',
                   'basket.set', 'active', NULL, 0, NULL, NULL, 'T5', ?, ?, ?)
                """,
                (item_id, json.dumps(payload), updated, updated),
            )
            conn.commit()

    def test_basket_q02_active_timeout_uses_longer_window(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            self._insert_active_basket_q02(root, item_id="wi-basket-60m", age_minutes=60)
            with farmctl.connect(root) as conn:
                flagged = farmctl._detect_active_age_timeout(conn)
                status = conn.execute(
                    "SELECT status FROM work_items WHERE id='wi-basket-60m'"
                ).fetchone()[0]
            self.assertEqual(flagged, [])
            self.assertEqual(status, "active")

    def test_basket_q02_active_timeout_still_reaps_after_basket_window(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            self._insert_active_basket_q02(root, item_id="wi-basket-130m", age_minutes=130)
            old_stop_pid = farmctl._stop_pid
            old_stop_terminal_slot = farmctl._stop_terminal_slot
            try:
                farmctl._stop_pid = lambda _pid: False
                farmctl._stop_terminal_slot = lambda _terminal: False
                with farmctl.connect(root) as conn:
                    flagged = farmctl._detect_active_age_timeout(conn)
                    row = conn.execute(
                        "SELECT status, verdict, payload_json FROM work_items WHERE id='wi-basket-130m'"
                    ).fetchone()
            finally:
                farmctl._stop_pid = old_stop_pid
                farmctl._stop_terminal_slot = old_stop_terminal_slot

            self.assertEqual(len(flagged), 1)
            self.assertEqual(flagged[0]["timeout_min"], farmctl.BASKET_Q02_ACTIVE_TIMEOUT_MIN)
            self.assertEqual(row[0], "failed")
            self.assertEqual(row[1], "FAIL")
            self.assertEqual(json.loads(row[2])["verdict_reason"], "ACTIVE_TIMEOUT")

    def test_p2_enqueue_uses_one_logical_basket_work_item(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_dir = repo_root / "framework" / "EAs" / "QM5_10717_demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            (ea_dir / "QM5_10717_demo.ex5").write_text("compiled", encoding="utf-8")
            manifest = {
                "logical_symbol": "FX8_BASKET_D1",
                "host_symbol": "EURUSD.DWX",
                "host_timeframe": "D1",
                "basket_symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
                "currencies": ["USD", "EUR", "GBP"],
            }
            (ea_dir / "basket_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / "QM5_10717_demo_FX8_BASKET_D1_D1_backtest.set"
            setfile.write_text("; basket setfile\n", encoding="utf-8")

            farmctl.init_db(root)
            db = root / "state" / "farm_state.sqlite"
            now = farmctl.utc_now()
            with sqlite3.connect(db) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks
                      (id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
                    VALUES
                      ('review-task', 'ea_review', 'done', NULL, 'QM5_10717', ?, ?, ?)
                    """,
                    (json.dumps({"ea_id": "QM5_10717", "verdict": {"verdict": "APPROVE_FOR_BACKTEST"}}), now, now),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            old_agent = os.environ.get("QM_AGENT_ID")
            try:
                farmctl.REPO_ROOT = repo_root
                os.environ["QM_AGENT_ID"] = "controller"
                result = farmctl.enqueue_backtest(root, "review-task", "P2")
            finally:
                farmctl.REPO_ROOT = old_repo_root
                if old_agent is None:
                    os.environ.pop("QM_AGENT_ID", None)
                else:
                    os.environ["QM_AGENT_ID"] = old_agent

            self.assertTrue(result["enqueued"])
            self.assertEqual(len(result["work_items_created"]), 1)
            created = result["work_items_created"][0]
            self.assertEqual(created["symbol"], "FX8_BASKET_D1")
            self.assertEqual(created["setfile_path"], str(setfile.resolve()))
            self.assertEqual(created["payload"]["host_symbol"], "EURUSD.DWX")
            self.assertEqual(created["payload"]["host_timeframe"], "D1")
            self.assertEqual(created["payload"]["portfolio_scope"], "basket")

    def test_record_build_auto_q02_enqueues_logical_basket_setfile(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_dir = repo_root / "framework" / "EAs" / "QM5_12577_cme-xauxag-ratio"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            manifest = {
                "logical_symbol": "QM5_12577_XAU_XAG_RATIO_D1",
                "host_symbol": "XAUUSD.DWX",
                "host_timeframe": "D1",
                "basket_symbols": ["XAUUSD.DWX", "XAGUSD.DWX"],
            }
            (ea_dir / "basket_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / (
                "QM5_12577_cme-xauxag-ratio_"
                "QM5_12577_XAU_XAG_RATIO_D1_D1_backtest.set"
            )
            setfile.write_text("; basket setfile\n", encoding="utf-8")

            farmctl.init_db(root)
            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                result = farmctl._auto_enqueue_q02_for_build(root, {
                    "task_id": "build-task",
                    "ea_id": "QM5_12577",
                    "setfiles_generated": [str(setfile)],
                })
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertEqual(result["skipped"], [])
            self.assertEqual(len(result["enqueued"]), 1)
            self.assertEqual(result["enqueued"][0]["symbol"], "QM5_12577_XAU_XAG_RATIO_D1")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT symbol, setfile_path, payload_json FROM work_items"
                ).fetchone()
            self.assertEqual(row[0], "QM5_12577_XAU_XAG_RATIO_D1")
            self.assertEqual(row[1], str(setfile))
            payload = json.loads(row[2])
            self.assertEqual(payload["host_symbol"], "XAUUSD.DWX")
            self.assertEqual(payload["host_timeframe"], "D1")
            self.assertEqual(payload["basket_symbol_count"], 2)
            self.assertEqual(payload["portfolio_scope"], "basket")

    def test_record_build_auto_q02_skips_basket_leg_setfiles(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_dir = repo_root / "framework" / "EAs" / "QM5_12533_edgelab-eurjpy-gbpjpy-cointegration"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            manifest = {
                "logical_symbol": "QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1",
                "host_symbol": "EURJPY.DWX",
                "host_timeframe": "D1",
                "basket_symbols": ["EURJPY.DWX", "GBPJPY.DWX"],
            }
            (ea_dir / "basket_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            logical_setfile = sets_dir / (
                "QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_"
                "QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set"
            )
            leg_a = sets_dir / "QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_EURJPY.DWX_D1_backtest.set"
            leg_b = sets_dir / "QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_GBPJPY.DWX_D1_backtest.set"
            for setfile in (logical_setfile, leg_a, leg_b):
                setfile.write_text("; setfile\n", encoding="utf-8")

            farmctl.init_db(root)
            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                result = farmctl._auto_enqueue_q02_for_build(root, {
                    "task_id": "build-task",
                    "ea_id": "QM5_12533",
                    "setfiles_generated": [str(leg_a), str(leg_b), str(logical_setfile)],
                })
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertEqual(len(result["enqueued"]), 1)
            self.assertEqual(result["enqueued"][0]["symbol"], "QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1")
            self.assertEqual(
                [item["reason"] for item in result["skipped"]],
                [
                    "basket_manifest_logical_setfile_preferred",
                    "basket_manifest_logical_setfile_preferred",
                ],
            )
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                rows = conn.execute(
                    "SELECT symbol, setfile_path, payload_json FROM work_items ORDER BY created_at"
                ).fetchall()
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0][0], "QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1")
            self.assertEqual(rows[0][1], str(logical_setfile))
            payload = json.loads(rows[0][2])
            self.assertEqual(payload["host_symbol"], "EURJPY.DWX")
            self.assertEqual(payload["portfolio_scope"], "basket")


if __name__ == "__main__":
    unittest.main()
