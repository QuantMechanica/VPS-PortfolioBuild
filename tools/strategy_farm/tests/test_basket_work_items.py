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
            self._insert_active_basket_q02(
                root,
                item_id="wi-basket-expired",
                age_minutes=farmctl.BASKET_Q02_ACTIVE_TIMEOUT_MIN + 10,
            )
            old_stop_pid = farmctl._stop_pid
            old_stop_terminal_slot = farmctl._stop_terminal_slot
            try:
                farmctl._stop_pid = lambda _pid: False
                farmctl._stop_terminal_slot = lambda _terminal: False
                with farmctl.connect(root) as conn:
                    flagged = farmctl._detect_active_age_timeout(conn)
                    row = conn.execute(
                        "SELECT status, verdict, payload_json FROM work_items WHERE id='wi-basket-expired'"
                    ).fetchone()
            finally:
                farmctl._stop_pid = old_stop_pid
                farmctl._stop_terminal_slot = old_stop_terminal_slot

            self.assertEqual(len(flagged), 1)
            self.assertEqual(flagged[0]["timeout_min"], farmctl.BASKET_Q02_ACTIVE_TIMEOUT_MIN)
            self.assertEqual(row[0], "failed")
            self.assertEqual(row[1], "FAIL")
            self.assertEqual(json.loads(row[2])["verdict_reason"], "ACTIVE_TIMEOUT")

    def test_payload_timeout_extends_phase_active_timeout(self) -> None:
        payload = json.dumps({"timeout_min": 120})

        self.assertEqual(farmctl._active_timeout_min_for_work_item("Q08", payload), 120)

    def test_work_items_view_normalizes_numeric_ea_filter(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                       attempt_count, parent_task_id, evidence_path, claimed_by,
                       payload_json, created_at, updated_at)
                    VALUES
                      ('wi-12978', 'backtest', 'Q02', 'QM5_12978',
                       'QM5_12978_GBPUSD_USDCAD_COINTEGRATION_D1',
                       'basket.set', 'active', NULL, 0, NULL, NULL, 'T2', '{}', ?, ?)
                    """,
                    (now, now),
                )
                conn.commit()

            numeric = farmctl.work_items_view(root, ea_filter="12978")
            prefixed = farmctl.work_items_view(root, ea_filter="QM5_12978")

            self.assertEqual(numeric["count"], 1)
            self.assertEqual(prefixed["count"], 1)
            self.assertEqual(numeric["items"][0]["id"], "wi-12978")
            self.assertEqual(numeric["summary"], {"Q02_active": 1})

    def test_phase_runner_uses_artifact_repo_when_worker_checkout_is_stale(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            source_repo = (Path(tmp) / "source_repo").resolve()
            stale_worker_repo = (Path(tmp) / "stale_worker_repo").resolve()
            ea_dir = source_repo / "framework" / "EAs" / "QM5_12712_demo"
            sets_dir = ea_dir / "sets"
            scripts_dir = source_repo / "framework" / "scripts"
            sets_dir.mkdir(parents=True)
            scripts_dir.mkdir(parents=True)
            stale_worker_repo.mkdir(parents=True)
            (scripts_dir / "q06_stress_harsh.py").write_text("# runner\n", encoding="utf-8")
            setfile = sets_dir / "QM5_12712_demo_QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1_D1_backtest.set"
            setfile.write_text("; basket setfile\n", encoding="utf-8")
            manifest = {
                "logical_symbol": "QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1",
                "host_symbol": "EURGBP.DWX",
                "host_timeframe": "D1",
                "basket_symbols": ["EURGBP.DWX", "EURAUD.DWX"],
            }
            manifest_path = ea_dir / "basket_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            payload = {
                "basket_manifest": str(manifest_path),
                "logical_symbol": manifest["logical_symbol"],
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
                      ('wi-q06-stale-worker', 'backtest', 'Q06', 'QM5_12712',
                       'QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1', ?,
                       'pending', NULL, 0, NULL, NULL, NULL, ?, ?, ?)
                    """,
                    (str(setfile), json.dumps(payload), now, now),
                )
                conn.commit()
                conn.row_factory = sqlite3.Row
                row = conn.execute("SELECT * FROM work_items WHERE id='wi-q06-stale-worker'").fetchone()

            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = stale_worker_repo
                cmd = farmctl._phase_runner_cmd_for_work_item(root, row, root / "reports", "T6")
                self.assertEqual(farmctl._work_item_artifact_repo_root(row), source_repo)
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertIsNotNone(cmd)
            self.assertEqual(Path(cmd[1]), scripts_dir / "q06_stress_harsh.py")
            self.assertIn("--baseline-setfile", cmd)
            self.assertEqual(cmd[cmd.index("--baseline-setfile") + 1], str(setfile))
            self.assertIn("--logical-symbol", cmd)
            self.assertIn("QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1", cmd)

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
                "tester_currency": "USD",
                "tester_deposit": 100000,
                "basket_symbols": ["XAUUSD.DWX", "XAGUSD.DWX", "EURUSD.DWX"],
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
                    "symbols": ["XAUUSD.DWX", "XAGUSD.DWX"],
                    "risk_mode": {
                        "RISK_FIXED": 1000,
                        "RISK_PERCENT": 0,
                        "PORTFOLIO_WEIGHT": 1,
                    },
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
            self.assertEqual(payload["basket_symbol_count"], 3)
            self.assertEqual(payload["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX", "EURUSD.DWX"])
            self.assertEqual(payload["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
            self.assertEqual(payload["portfolio_scope"], "basket")
            self.assertEqual(payload["tester_currency"], "USD")
            self.assertEqual(payload["tester_deposit"], 100000)
            self.assertEqual(payload["risk_fixed"], 1000)
            self.assertEqual(payload["risk_percent"], 0)
            self.assertEqual(payload["portfolio_weight"], 1)
            self.assertEqual(payload["risk_mode"], "RISK_FIXED")
            self.assertEqual(payload["timeout_min"], farmctl.BASKET_Q02_ACTIVE_TIMEOUT_MIN)

    def test_basket_context_survives_phase_promotion_payload(self) -> None:
        parent = {
            "payload_json": json.dumps({
                "basket_manifest": "C:/QM/repo/framework/EAs/QM5_12712_demo/basket_manifest.json",
                "basket_symbol_count": 2,
                "host_symbol": "EURGBP.DWX",
                "host_timeframe": "D1",
                "logical_symbol": "QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1",
                "portfolio_scope": "basket",
                "tester_currency": "USD",
                "tester_deposit": 100000,
                "risk_fixed": 1000,
                "risk_percent": 0,
                "portfolio_weight": 1,
                "risk_mode": "RISK_FIXED",
                "traded_symbols": ["EURGBP.DWX", "EURAUD.DWX"],
                "conversion_symbols": ["EURUSD.DWX", "AUDUSD.DWX"],
                "scan_ranking": {"rank_positive_hedge": 12},
            }),
        }

        payload = farmctl._promotion_payload_with_basket_context(
            parent,
            {
                "promoted_from_phase": "Q02",
                "promoted_from_work_item": "wi-parent",
                "promotion_source": "pump_q04_early_probe",
            },
        )

        self.assertEqual(payload["promoted_from_phase"], "Q02")
        self.assertEqual(payload["promoted_from_work_item"], "wi-parent")
        self.assertEqual(payload["promotion_source"], "pump_q04_early_probe")
        self.assertEqual(payload["host_symbol"], "EURGBP.DWX")
        self.assertEqual(payload["host_timeframe"], "D1")
        self.assertEqual(payload["logical_symbol"], "QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1")
        self.assertEqual(payload["basket_symbol_count"], 2)
        self.assertEqual(payload["portfolio_scope"], "basket")
        self.assertEqual(payload["tester_currency"], "USD")
        self.assertEqual(payload["tester_deposit"], 100000)
        self.assertEqual(payload["risk_fixed"], 1000)
        self.assertEqual(payload["risk_percent"], 0)
        self.assertEqual(payload["portfolio_weight"], 1)
        self.assertEqual(payload["risk_mode"], "RISK_FIXED")
        self.assertEqual(payload["traded_symbols"], ["EURGBP.DWX", "EURAUD.DWX"])
        self.assertEqual(payload["conversion_symbols"], ["EURUSD.DWX", "AUDUSD.DWX"])
        self.assertEqual(payload["scan_ranking"], {"rank_positive_hedge": 12})

    def test_q02_dispatch_falls_back_to_basket_manifest_host_symbol(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_id = "QM5_12723"
            ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            logical = "QM5_12723_NZDUSD_EURJPY_COINTEGRATION_D1"
            manifest = {
                "logical_symbol": logical,
                "host_symbol": "NZDUSD.DWX",
                "host_timeframe": "D1",
                "basket_symbols": ["NZDUSD.DWX", "EURJPY.DWX"],
            }
            (ea_dir / "basket_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / f"{ea_dir.name}_{logical}_D1_backtest.set"
            setfile.write_text("; basket setfile\n", encoding="utf-8")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                       attempt_count, parent_task_id, evidence_path, claimed_by,
                       payload_json, created_at, updated_at)
                    VALUES
                      ('wi-q02-basket-fallback', 'backtest', 'Q02', ?, ?, ?,
                       'pending', NULL, 0, NULL, NULL, NULL, '{}', ?, ?)
                    """,
                    (ea_id, logical, str(setfile.resolve()), now, now),
                )
                conn.commit()

            spawned_cmds: list[list[str]] = []

            class FakeProc:
                pid = 12723

                def __init__(self, cmd, **_kwargs):
                    spawned_cmds.append([str(part) for part in cmd])

            old_repo_root = farmctl.REPO_ROOT
            old_popen = farmctl.subprocess.Popen
            old_compile_gate_check = farmctl._compile_gate_check
            try:
                farmctl.REPO_ROOT = repo_root
                farmctl.subprocess.Popen = FakeProc
                farmctl._compile_gate_check = lambda _ea_dir_name: {
                    "allowed": True,
                    "verdict": "COMPILED_CACHED",
                    "source": "test",
                }
                with farmctl.connect(root) as conn:
                    row = conn.execute(
                        "SELECT * FROM work_items WHERE id='wi-q02-basket-fallback'"
                    ).fetchone()
                result = farmctl._spawn_run_smoke_for_work_item(root, row, "T1")
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.subprocess.Popen = old_popen
                farmctl._compile_gate_check = old_compile_gate_check

            self.assertTrue(result["spawned"])
            self.assertEqual(result["logical_symbol"], logical)
            self.assertEqual(result["runner_symbol"], "NZDUSD.DWX")
            self.assertEqual(len(spawned_cmds), 1)
            cmd = spawned_cmds[0]
            self.assertEqual(cmd[cmd.index("-Symbol") + 1], "NZDUSD.DWX")
            self.assertEqual(cmd[cmd.index("-Period") + 1], "D1")
            self.assertEqual(cmd[cmd.index("-SetFile") + 1], str(setfile.resolve()))

    def test_q02_basket_dispatch_honors_manifest_q02_window(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_id = "QM5_12888"
            ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            (ea_dir / f"{ea_id}_demo.ex5").write_text("compiled\n", encoding="utf-8")
            logical = "FX8_DEMO_BASKET_H1"
            manifest = {
                "logical_symbol": logical,
                "host_symbol": "EURUSD.DWX",
                "host_timeframe": "H1",
                "basket_symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
                "q02_from_date": "2023.01.01",
                "q02_to_date": "2023.12.31",
            }
            (ea_dir / "basket_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / f"{ea_dir.name}_{logical}_H1_backtest.set"
            setfile.write_text("; basket setfile\n", encoding="utf-8")

            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                loaded_manifest = farmctl._load_basket_manifest(ea_id)
                payload = farmctl._basket_q02_payload(loaded_manifest or {})
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertEqual(payload["from_date"], "2023.01.01")
            self.assertEqual(payload["to_date"], "2023.12.31")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                       attempt_count, parent_task_id, evidence_path, claimed_by,
                       payload_json, created_at, updated_at)
                    VALUES
                      ('wi-q02-basket-window', 'backtest', 'Q02', ?, ?, ?,
                       'pending', NULL, 0, NULL, NULL, NULL, ?, ?, ?)
                    """,
                    (ea_id, logical, str(setfile.resolve()), json.dumps(payload), now, now),
                )
                conn.commit()

            spawned_cmds: list[list[str]] = []

            class FakeProc:
                pid = 12888

                def __init__(self, cmd, **_kwargs):
                    spawned_cmds.append([str(part) for part in cmd])

            old_popen = farmctl.subprocess.Popen
            old_compile_gate_check = farmctl._compile_gate_check
            try:
                farmctl.REPO_ROOT = repo_root
                farmctl.subprocess.Popen = FakeProc
                farmctl._compile_gate_check = lambda _ea_dir_name: {
                    "allowed": True,
                    "verdict": "COMPILED_CACHED",
                    "source": "test",
                }
                with farmctl.connect(root) as conn:
                    row = conn.execute(
                        "SELECT * FROM work_items WHERE id='wi-q02-basket-window'"
                    ).fetchone()
                result = farmctl._spawn_run_smoke_for_work_item(root, row, "T2")
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.subprocess.Popen = old_popen
                farmctl._compile_gate_check = old_compile_gate_check

            self.assertTrue(result["spawned"])
            self.assertEqual(result["runner_symbol"], "EURUSD.DWX")
            self.assertEqual(result["from_date"], "2023.01.01")
            self.assertEqual(result["to_date"], "2023.12.31")
            self.assertEqual(result["smoke_year_count"], 1)
            self.assertEqual(result["effective_min_trades"], 5)
            self.assertEqual(len(spawned_cmds), 1)
            cmd = spawned_cmds[0]
            self.assertEqual(cmd[cmd.index("-FromDate") + 1], "2023.01.01")
            self.assertEqual(cmd[cmd.index("-ToDate") + 1], "2023.12.31")
            self.assertEqual(cmd[cmd.index("-MinTrades") + 1], "5")

    def test_q03_basket_dispatch_preserves_promoted_date_window(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_id = "QM5_12776"
            ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            (ea_dir / f"{ea_id}_demo.ex5").write_text("compiled\n", encoding="utf-8")
            logical = "QM5_12776_AUDUSD_GBPJPY_COINTEGRATION_D1"
            manifest = {
                "logical_symbol": logical,
                "host_symbol": "AUDUSD.DWX",
                "host_timeframe": "D1",
                "tester_currency": "USD",
                "basket_symbols": ["AUDUSD.DWX", "GBPJPY.DWX"],
            }
            manifest_path = ea_dir / "basket_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / f"{ea_dir.name}_{logical}_D1_backtest.set"
            setfile.write_text("; basket setfile\n", encoding="utf-8")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            payload = {
                "basket_manifest": str(manifest_path),
                "basket_symbol_count": 2,
                "host_symbol": "AUDUSD.DWX",
                "host_timeframe": "D1",
                "logical_symbol": logical,
                "portfolio_scope": "basket",
                "tester_currency": "USD",
                "from_date": "2018.07.02",
                "to_date": "2024.12.31",
                "smoke_year_count": 7,
            }
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                       attempt_count, parent_task_id, evidence_path, claimed_by,
                       payload_json, created_at, updated_at)
                    VALUES
                      ('wi-q03-basket-window', 'backtest', 'Q03', ?, ?, ?,
                       'pending', NULL, 0, NULL, NULL, NULL, ?, ?, ?)
                    """,
                    (ea_id, logical, str(setfile.resolve()), json.dumps(payload), now, now),
                )
                conn.commit()

            spawned_cmds: list[list[str]] = []

            class FakeProc:
                pid = 12776

                def __init__(self, cmd, **_kwargs):
                    spawned_cmds.append([str(part) for part in cmd])

            old_repo_root = farmctl.REPO_ROOT
            old_popen = farmctl.subprocess.Popen
            try:
                farmctl.REPO_ROOT = repo_root
                farmctl.subprocess.Popen = FakeProc
                with farmctl.connect(root) as conn:
                    row = conn.execute(
                        "SELECT * FROM work_items WHERE id='wi-q03-basket-window'"
                    ).fetchone()
                result = farmctl._spawn_run_smoke_for_work_item(root, row, "T4")
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.subprocess.Popen = old_popen

            self.assertTrue(result["spawned"])
            self.assertEqual(result["logical_symbol"], logical)
            self.assertEqual(result["runner_symbol"], "AUDUSD.DWX")
            self.assertEqual(result["from_date"], "2018.07.02")
            self.assertEqual(result["to_date"], "2024.12.31")
            self.assertEqual(result["smoke_year_count"], 7)
            self.assertEqual(result["effective_min_trades"], 35)
            self.assertEqual(len(spawned_cmds), 1)
            cmd = spawned_cmds[0]
            self.assertEqual(cmd[cmd.index("-Symbol") + 1], "AUDUSD.DWX")
            self.assertEqual(cmd[cmd.index("-Period") + 1], "D1")
            self.assertEqual(cmd[cmd.index("-FromDate") + 1], "2018.07.02")
            self.assertEqual(cmd[cmd.index("-ToDate") + 1], "2024.12.31")
            self.assertEqual(cmd[cmd.index("-TesterCurrencyOverride") + 1], "USD")
            self.assertEqual(cmd[cmd.index("-MinTrades") + 1], "35")

    def test_single_symbol_dispatch_ignores_promoted_dates_without_basket_scope(self) -> None:
        self.assertEqual(
            farmctl._basket_payload_date_window({
                "from_date": "2018.07.02",
                "to_date": "2024.12.31",
            }),
            (None, None),
        )

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
                "tester_currency": "JPY",
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
            self.assertEqual(payload["tester_currency"], "JPY")

    def test_embedded_build_result_materializes_and_records(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_dir = repo_root / "framework" / "EAs" / "QM5_12760_demo"
            ea_dir.mkdir(parents=True)
            mq5 = ea_dir / "QM5_12760_demo.mq5"
            ex5 = ea_dir / "QM5_12760_demo.ex5"
            mq5.write_text("// source\n", encoding="utf-8")
            ex5.write_text("compiled\n", encoding="utf-8")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            build_result = {
                "task_id": "build-task",
                "ea_id": "QM5_12760",
                "mq5_path": str(mq5),
                "ex5_path": str(ex5),
                "compile_succeeded": True,
                "build_check_passed": True,
                "smoke_result": "deferred_p2_smoke",
                "setfiles_generated": [],
            }
            payload = {
                "ea_id": "QM5_12760",
                "codex_result": build_result,
                "pre_review_not_reviewable_reason": "missing_build_result",
            }
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks
                      (id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
                    VALUES
                      ('build-task', 'build_ea', 'pending', NULL, 'QM5_12760', ?, ?, ?)
                    """,
                    (json.dumps(payload), now, now),
                )
                conn.commit()

            result_path = farmctl._materialize_embedded_build_result(root, "build-task", payload)
            self.assertEqual(result_path, root / "artifacts" / "builds" / "build-task.json")
            self.assertTrue(result_path.exists())

            old_validate = farmctl._validate_ea_spec_md
            old_auto_q02 = farmctl._auto_enqueue_q02_for_build
            try:
                farmctl._validate_ea_spec_md = lambda _result, _root: {
                    "ok": True,
                    "failures": [],
                    "ea_dir": str(ea_dir),
                }
                farmctl._auto_enqueue_q02_for_build = lambda _root, _result: {
                    "enqueued": [],
                    "skipped": [],
                    "reason": "missing_ea_id_or_setfiles",
                }
                recorded = farmctl.record_build_result(root, "build-task", str(result_path))
            finally:
                farmctl._validate_ea_spec_md = old_validate
                farmctl._auto_enqueue_q02_for_build = old_auto_q02

            self.assertTrue(recorded["recorded"])
            self.assertEqual(recorded["new_status"], "done")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.row_factory = sqlite3.Row
                row = conn.execute("SELECT * FROM tasks WHERE id='build-task'").fetchone()
            stored = json.loads(row["payload_json"])
            self.assertEqual(row["status"], "done")
            self.assertEqual(
                Path(stored["build_result_path"]).resolve(),
                result_path.resolve(),
            )
            ready, reason = farmctl._pre_review_ready(root, row)
            self.assertTrue(ready)
            self.assertEqual(reason, "")


if __name__ == "__main__":
    unittest.main()
