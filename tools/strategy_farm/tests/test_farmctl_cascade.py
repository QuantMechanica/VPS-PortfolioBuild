import json
import shutil
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class SymbolAliasTests(unittest.TestCase):
    def test_known_aliases_canonicalize_to_dwx(self) -> None:
        cases = {
            "GER40": "GDAXI.DWX", "DAX": "GDAXI.DWX",
            "USOIL": "XTIUSD.DWX", "WTI": "XTIUSD.DWX",
            "FTSE100": "UK100.DWX", "US500": "SP500.DWX",
            "US30": "WS30.DWX", "NAS100": "NDX.DWX", "USTEC": "NDX.DWX",
            "EURUSD": "EURUSD.DWX", "EURUSD.DWX": "EURUSD.DWX",  # passthrough
        }
        for raw, canon in cases.items():
            self.assertEqual(farmctl._normalise_card_symbol(raw), canon, raw)

    def test_card_universe_canonicalizes_alias_tickers(self) -> None:
        text = "Universe: GER40, USOIL, FTSE100, NAS100.\n"
        self.assertEqual(
            farmctl._card_universe_symbols(text),
            {"GDAXI.DWX", "XTIUSD.DWX", "UK100.DWX", "NDX.DWX"},
        )

    def test_no_canonical_equivalent_is_not_misrouted(self) -> None:
        # instruments we have no .DWX data for must NOT masquerade as another symbol
        self.assertEqual(farmctl._normalise_card_symbol("AUS200"), "AUS200.DWX")

    def test_build_div_rank_diversifier_first(self) -> None:
        # OWNER 2026-06-26: build sweep prioritizes NEW instruments; all-redundant cards last.
        redundant = "Universe: XAUUSD, SP500, NDX.\n"
        diversifying = "Universe: EURUSD, USDJPY.\n"
        mixed = "Universe: XAUUSD, EURUSD.\n"
        self.assertEqual(farmctl._card_build_div_rank(redundant), 1)
        self.assertEqual(farmctl._card_build_div_rank(diversifying), 0)
        self.assertEqual(farmctl._card_build_div_rank(mixed), 0)  # any new instrument -> build


class Q02SymbolMatrixGateTests(unittest.TestCase):
    def test_auto_q02_skips_non_matrix_dwx_alias_setfiles(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            registry_dir = repo_root / "framework" / "registry"
            registry_dir.mkdir(parents=True)
            (registry_dir / "dwx_symbol_matrix.csv").write_text(
                "\n".join([
                    "symbol,asset_class,canonical_name_verified",
                    "GDAXI.DWX,indices,true",
                    "",
                ]),
                encoding="utf-8",
            )
            farmctl.init_db(root)

            old_repo_root = farmctl.REPO_ROOT
            old_deferred = farmctl.Q02_DEFERRED_SYMBOLS_FILE
            try:
                farmctl.REPO_ROOT = repo_root
                farmctl.Q02_DEFERRED_SYMBOLS_FILE = root / "state" / "q02_deferred_symbols.json"
                sets_dir = repo_root / "framework" / "EAs" / "QM5_9996_demo" / "sets"
                result = farmctl._auto_enqueue_q02_for_build(root, {
                    "ea_id": "QM5_9996",
                    "task_id": "build-task",
                    "setfiles_generated": [
                        str(sets_dir / "QM5_9996_demo_GER40.DWX_D1_backtest.set"),
                        str(sets_dir / "QM5_9996_demo_GDAXI.DWX_D1_backtest.set"),
                    ],
                })
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.Q02_DEFERRED_SYMBOLS_FILE = old_deferred

            self.assertEqual([row["symbol"] for row in result["enqueued"]], ["GDAXI.DWX"])
            self.assertIn(
                {"setfile": "QM5_9996_demo_GER40.DWX_D1_backtest.set",
                 "symbol": "GER40.DWX",
                 "reason": "symbol_not_in_dwx_matrix"},
                result["skipped"],
            )
            with sqlite3.connect(root / "state" / "farm_state.sqlite") as conn:
                rows = conn.execute("SELECT symbol FROM work_items").fetchall()
            self.assertEqual(rows, [("GDAXI.DWX",)])

    def test_logical_basket_symbol_is_allowed_when_requested(self) -> None:
        for symbol in ("QM5_13098_XCU_XAU_RSPREAD_D1", "FX8_BASKET_D1"):
            with self.subTest(symbol=symbol):
                self.assertIsNone(
                    farmctl._q02_symbol_skip_reason(
                        symbol,
                        allow_logical_basket=True,
                    )
                )
                self.assertEqual(
                    farmctl._q02_symbol_skip_reason(symbol),
                    "non_dwx_symbol",
                )
        self.assertEqual(
            farmctl._q02_symbol_skip_reason(
                "EURUSD",
                allow_logical_basket=True,
            ),
            "non_dwx_symbol",
        )


class CascadePromotionTests(unittest.TestCase):
    def test_min_trades_floor_is_flat_rate_not_card_coupled(self) -> None:
        # OWNER 2026-06-26: the Q02 floor is a flat 5 trades/yr * window-years, decoupled
        # from the card's declared frequency. The card-derived fields still compute (kept
        # for diagnostics/priority), but effective_min_trades no longer scales from them.
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

            # card-derived diagnostics unchanged
            self.assertEqual(info["expected_trades_per_year_card"], 12)
            self.assertEqual(info["card_universe_symbol_count"], 9)
            self.assertEqual(info["min_trade_scope"], "basket_scaled_from_card")
            self.assertEqual(info["expected_trades_per_year_per_symbol"], 1)
            # floor is now flat 5/yr * 1 window-year = 5 (was card-coupled = 1)
            self.assertEqual(info["effective_min_trades"], 5)

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

    def test_enqueue_q05_checks_basket_manifest_symbols_not_logical_symbol(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            mt5_root = Path(tmp) / "mt5"
            ea_id = "QM5_9998"
            ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_basket-demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            (ea_dir / f"{ea_dir.name}.ex5").write_text("compiled", encoding="utf-8")
            logical = "QM5_9998_EURGBP_EURAUD_COINTEGRATION_D1"
            manifest = {
                "logical_symbol": logical,
                "host_symbol": "EURGBP.DWX",
                "host_timeframe": "D1",
                "basket_symbols": ["EURGBP.DWX", "EURAUD.DWX"],
                "tester_currency": "JPY",
                "tester_deposit": 15000000,
            }
            manifest_path = ea_dir / "basket_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / f"{ea_dir.name}_{logical}_D1_backtest.set"
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            for symbol in ("EURGBP.DWX", "EURAUD.DWX"):
                hist_dir = mt5_root / "T1" / "Bases" / "Custom" / "history" / symbol
                hist_dir.mkdir(parents=True)
                for year in (2023, 2024):
                    (hist_dir / f"{year}.hcc").write_text("", encoding="utf-8")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       verdict, attempt_count, payload_json, created_at, updated_at)
                    VALUES
                      ('q04-pass', 'backtest', 'Q04', ?, ?, ?,
                       'done', 'PASS', 0, ?, ?, ?)
                    """,
                    (
                        ea_id,
                        logical,
                        str(setfile),
                        json.dumps({
                            "basket_manifest": str(manifest_path),
                            "basket_symbol_count": 2,
                            "host_symbol": "EURGBP.DWX",
                            "host_timeframe": "D1",
                            "logical_symbol": logical,
                            "portfolio_scope": "basket",
                            "q04_latest_full_year": 2024,
                        }),
                        now,
                        now,
                    ),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            old_mt5_root = farmctl.MT5_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                farmctl.MT5_ROOT = mt5_root
                result = farmctl.enqueue_cascade_backtest_for_ea(root, ea_id, "Q05")
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.MT5_ROOT = old_mt5_root

            self.assertTrue(result["enqueued"])
            self.assertEqual(result["skipped"], [])
            self.assertEqual(len(result["created"]), 1)
            self.assertEqual(result["created"][0]["symbol"], logical)
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT symbol, payload_json FROM work_items WHERE phase='Q05'"
                ).fetchone()
            self.assertEqual(row[0], logical)
            payload = json.loads(row[1])
            self.assertEqual(payload["host_symbol"], "EURGBP.DWX")
            self.assertEqual(payload["portfolio_scope"], "basket")
            self.assertEqual(payload["q04_latest_full_year"], 2024)
            self.assertEqual(payload["timeout_min"], farmctl.PHASE_ACTIVE_TIMEOUT_MIN["Q05"])
            self.assertEqual(payload["tester_currency"], "JPY")
            self.assertEqual(payload["tester_deposit"], 15000000)
            self.assertEqual(payload["full_history_from"], farmctl.DWX_MULTI_SYMBOL_FULL_HISTORY_FROM)

    def test_q04_promotion_clamps_basket_latest_year_from_cache(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            repo_root = Path(tmp) / "repo"
            mt5_root = Path(tmp) / "mt5"
            ea_id = "QM5_9996"
            ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_basket-demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            logical = "QM5_9996_USDCHF_EURGBP_COINTEGRATION_D1"
            manifest = {
                "logical_symbol": logical,
                "host_symbol": "USDCHF.DWX",
                "host_timeframe": "D1",
                "basket_symbols": ["USDCHF.DWX", "EURGBP.DWX"],
            }
            manifest_path = ea_dir / "basket_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / f"{ea_dir.name}_{logical}_D1_backtest.set"
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            for symbol in ("USDCHF.DWX", "EURGBP.DWX"):
                hist_dir = mt5_root / "T1" / "Bases" / "Custom" / "history" / symbol
                hist_dir.mkdir(parents=True)
                for year in (2023, 2024):
                    (hist_dir / f"{year}.hcc").write_text("", encoding="utf-8")

            old_repo_root = farmctl.REPO_ROOT
            old_mt5_root = farmctl.MT5_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                farmctl.MT5_ROOT = mt5_root
                parent = {
                    "ea_id": ea_id,
                    "symbol": logical,
                    "setfile_path": str(setfile),
                    "payload_json": json.dumps({
                        "basket_manifest": str(manifest_path),
                        "basket_symbols": ["USDCHF.DWX", "EURGBP.DWX"],
                        "host_symbol": "USDCHF.DWX",
                        "host_timeframe": "D1",
                        "logical_symbol": logical,
                        "portfolio_scope": "basket",
                    }),
                }
                payload = farmctl._promotion_payload_with_basket_context(parent, {})
                changed = farmctl._apply_q04_latest_full_year_from_history(parent, payload)
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.MT5_ROOT = old_mt5_root

            self.assertTrue(changed)
            self.assertEqual(payload["q04_latest_full_year"], 2024)
            self.assertEqual(payload["q04_history_clamp_source"], "mt5_cache")
            self.assertEqual(payload["q04_history_checked_symbols"], ["USDCHF.DWX", "EURGBP.DWX"])

    def test_enqueue_q04_requeues_existing_basket_probe_from_q02_pass(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            mt5_root = Path(tmp) / "mt5"
            ea_id = "QM5_9995"
            ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_basket-demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            (ea_dir / f"{ea_dir.name}.ex5").write_text("compiled", encoding="utf-8")
            logical = "QM5_9995_USDJPY_USDCAD_COINTEGRATION_D1"
            manifest = {
                "logical_symbol": logical,
                "host_symbol": "USDJPY.DWX",
                "host_timeframe": "D1",
                "basket_symbols": ["USDJPY.DWX", "USDCAD.DWX"],
            }
            manifest_path = ea_dir / "basket_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / f"{ea_dir.name}_{logical}_D1_backtest.set"
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            for symbol in ("USDJPY.DWX", "USDCAD.DWX"):
                hist_dir = mt5_root / "T1" / "Bases" / "Custom" / "history" / symbol
                hist_dir.mkdir(parents=True)
                for year in (2023, 2024):
                    (hist_dir / f"{year}.hcc").write_text("", encoding="utf-8")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       verdict, attempt_count, evidence_path, payload_json, created_at, updated_at)
                    VALUES
                      ('q02-pass', 'backtest', 'Q02', ?, ?, ?,
                       'done', 'PASS', 0, NULL, ?, ?, ?),
                      ('q04-infra', 'backtest', 'Q04', ?, ?, ?,
                       'done', 'INFRA_FAIL', 2, ?, ?, ?, ?)
                    """,
                    (
                        ea_id,
                        logical,
                        str(setfile),
                        json.dumps({
                            "basket_manifest": str(manifest_path),
                            "host_symbol": "USDJPY.DWX",
                            "host_timeframe": "D1",
                            "logical_symbol": logical,
                            "portfolio_scope": "basket",
                        }),
                        now,
                        now,
                        ea_id,
                        logical,
                        str(setfile),
                        farmctl._evidence_unavailable_sentinel("test_fixture"),
                        json.dumps({"prior_failure": "runner_invalid"}),
                        now,
                        now,
                    ),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            old_mt5_root = farmctl.MT5_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                farmctl.MT5_ROOT = mt5_root
                result = farmctl.enqueue_cascade_backtest_for_ea(root, ea_id, "Q04")
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.MT5_ROOT = old_mt5_root

            self.assertTrue(result["enqueued"])
            self.assertEqual(result["created"], [])
            self.assertEqual(result["requeued"], [{"id": "q04-infra", "symbol": logical}])
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                rows = conn.execute(
                    "SELECT id, phase, status, verdict, attempt_count, payload_json "
                    "FROM work_items WHERE phase='Q04'"
                ).fetchall()
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0][0], "q04-infra")
            self.assertEqual(rows[0][2], "pending")
            self.assertIsNone(rows[0][3])
            self.assertEqual(rows[0][4], 0)
            payload = json.loads(rows[0][5])
            self.assertTrue(payload["q04_default_probe"])
            self.assertEqual(payload["q04_latest_full_year"], 2024)
            self.assertEqual(payload["q04_history_checked_symbols"], ["USDJPY.DWX", "USDCAD.DWX"])
            self.assertEqual(payload["promoted_from_phase"], "Q02")

    def test_enqueue_q04_requeue_prefers_latest_q02_pass(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            mt5_root = Path(tmp) / "mt5"
            ea_id = "QM5_9994"
            ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_basket-demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            (ea_dir / f"{ea_dir.name}.ex5").write_text("compiled", encoding="utf-8")
            logical = "QM5_9994_AUD_NZD_CAD_COINTEG_D1"
            manifest = {
                "logical_symbol": logical,
                "host_symbol": "AUDUSD.DWX",
                "host_timeframe": "D1",
                "basket_symbols": ["AUDUSD.DWX", "NZDUSD.DWX", "USDCAD.DWX"],
            }
            manifest_path = ea_dir / "basket_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / f"{ea_dir.name}_{logical}_D1_backtest.set"
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")

            farmctl.init_db(root)
            older = "2026-06-30T03:46:42+00:00"
            newer = "2026-07-01T13:30:54+00:00"
            q02_payload = json.dumps({
                "basket_manifest": str(manifest_path),
                "host_symbol": "AUDUSD.DWX",
                "host_timeframe": "D1",
                "logical_symbol": logical,
                "portfolio_scope": "basket",
                "q04_latest_full_year": 2024,
            })
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       verdict, attempt_count, evidence_path, payload_json, created_at, updated_at)
                    VALUES
                      ('q02-old-pass', 'backtest', 'Q02', ?, ?, ?,
                       'done', 'PASS', 0, NULL, ?, ?, ?),
                      ('q02-new-pass', 'backtest', 'Q02', ?, ?, ?,
                       'done', 'PASS', 0, NULL, ?, ?, ?),
                      ('q04-infra', 'backtest', 'Q04', ?, ?, ?,
                       'done', 'INFRA_FAIL', 1, ?, ?, ?, ?)
                    """,
                    (
                        ea_id,
                        logical,
                        str(setfile),
                        q02_payload,
                        older,
                        older,
                        ea_id,
                        logical,
                        str(setfile),
                        q02_payload,
                        newer,
                        newer,
                        ea_id,
                        logical,
                        str(setfile),
                        farmctl._evidence_unavailable_sentinel("test_fixture"),
                        json.dumps({"prior_failure": "runner_invalid"}),
                        older,
                        older,
                    ),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            old_mt5_root = farmctl.MT5_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                farmctl.MT5_ROOT = mt5_root
                result = farmctl.enqueue_cascade_backtest_for_ea(root, ea_id, "Q04")
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.MT5_ROOT = old_mt5_root

            self.assertTrue(result["enqueued"])
            self.assertEqual(result["requeued"], [{"id": "q04-infra", "symbol": logical}])
            self.assertEqual(result["skipped"][0]["reason"], "already_pending_or_active")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, verdict, payload_json FROM work_items WHERE id='q04-infra'"
                ).fetchone()
            self.assertEqual(row[0], "pending")
            self.assertIsNone(row[1])
            payload = json.loads(row[2])
            self.assertEqual(payload["promoted_from_work_item"], "q02-new-pass")
            self.assertEqual(payload["q04_latest_full_year"], 2024)

    def test_enqueue_q05_accepts_q04_soft_pass_verdicts(self) -> None:
        for verdict in ("PASS_SOFT", "PASS_LOWFREQ"):
            with self.subTest(verdict=verdict):
                with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
                    root = Path(tmp) / "farm"
                    repo_root = Path(tmp) / "repo"
                    mt5_root = Path(tmp) / "mt5"
                    ea_id = "QM5_9997"
                    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_basket-demo"
                    sets_dir = ea_dir / "sets"
                    sets_dir.mkdir(parents=True)
                    (ea_dir / f"{ea_dir.name}.ex5").write_text("compiled", encoding="utf-8")
                    logical = "QM5_9997_GBPJPY_AUDJPY_COINTEGRATION_D1"
                    manifest = {
                        "logical_symbol": logical,
                        "host_symbol": "GBPJPY.DWX",
                        "host_timeframe": "D1",
                        "basket_symbols": ["GBPJPY.DWX", "AUDJPY.DWX", "USDJPY.DWX"],
                    }
                    manifest_path = ea_dir / "basket_manifest.json"
                    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
                    setfile = sets_dir / f"{ea_dir.name}_{logical}_D1_backtest.set"
                    setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
                    for symbol in ("GBPJPY.DWX", "AUDJPY.DWX", "USDJPY.DWX"):
                        hist_dir = mt5_root / "T1" / "Bases" / "Custom" / "history" / symbol
                        hist_dir.mkdir(parents=True)
                        for year in (2023, 2024, 2025):
                            (hist_dir / f"{year}.hcc").write_text("", encoding="utf-8")

                    farmctl.init_db(root)
                    now = farmctl.utc_now()
                    with sqlite3.connect(root / farmctl.DB_REL) as conn:
                        conn.execute(
                            """
                            INSERT INTO work_items
                              (id, kind, phase, ea_id, symbol, setfile_path, status,
                               verdict, attempt_count, payload_json, created_at, updated_at)
                            VALUES
                              ('q04-passish', 'backtest', 'Q04', ?, ?, ?,
                               'done', ?, 0, ?, ?, ?)
                            """,
                            (
                                ea_id,
                                logical,
                                str(setfile),
                                verdict,
                                json.dumps({
                                    "basket_manifest": str(manifest_path),
                                    "host_symbol": "GBPJPY.DWX",
                                    "host_timeframe": "D1",
                                    "logical_symbol": logical,
                                    "portfolio_scope": "basket",
                                }),
                                now,
                                now,
                            ),
                        )
                        conn.commit()

                    old_repo_root = farmctl.REPO_ROOT
                    old_mt5_root = farmctl.MT5_ROOT
                    try:
                        farmctl.REPO_ROOT = repo_root
                        farmctl.MT5_ROOT = mt5_root
                        result = farmctl.enqueue_cascade_backtest_for_ea(root, ea_id, "Q05")
                    finally:
                        farmctl.REPO_ROOT = old_repo_root
                        farmctl.MT5_ROOT = old_mt5_root

                    self.assertTrue(result["enqueued"])
                    self.assertEqual(result["skipped"], [])
                    self.assertEqual(len(result["created"]), 1)
                    self.assertEqual(result["created"][0]["symbol"], logical)

    def test_enqueue_q05_clamps_latest_year_from_cache_when_q04_payload_lacks_it(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            mt5_root = Path(tmp) / "mt5"
            ea_id = "QM5_9994"
            ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_basket-demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            (ea_dir / f"{ea_dir.name}.ex5").write_text("compiled", encoding="utf-8")
            logical = "QM5_9994_GBPJPY_AUDJPY_COINTEGRATION_D1"
            manifest = {
                "logical_symbol": logical,
                "host_symbol": "GBPJPY.DWX",
                "host_timeframe": "D1",
                "basket_symbols": ["GBPJPY.DWX", "AUDJPY.DWX", "USDJPY.DWX"],
            }
            manifest_path = ea_dir / "basket_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / f"{ea_dir.name}_{logical}_D1_backtest.set"
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            for symbol in manifest["basket_symbols"]:
                hist_dir = mt5_root / "T1" / "Bases" / "Custom" / "history" / symbol
                hist_dir.mkdir(parents=True)
                for year in (2023, 2024):
                    (hist_dir / f"{year}.hcc").write_text("", encoding="utf-8")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       verdict, attempt_count, payload_json, created_at, updated_at)
                    VALUES
                      ('q04-passish', 'backtest', 'Q04', ?, ?, ?,
                       'done', 'PASS_SOFT', 0, ?, ?, ?)
                    """,
                    (
                        ea_id,
                        logical,
                        str(setfile),
                        json.dumps({
                            "basket_manifest": str(manifest_path),
                            "host_symbol": "GBPJPY.DWX",
                            "host_timeframe": "D1",
                            "logical_symbol": logical,
                            "portfolio_scope": "basket",
                        }),
                        now,
                        now,
                    ),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            old_mt5_root = farmctl.MT5_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                farmctl.MT5_ROOT = mt5_root
                result = farmctl.enqueue_cascade_backtest_for_ea(root, ea_id, "Q05")
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.MT5_ROOT = old_mt5_root

            self.assertTrue(result["enqueued"])
            self.assertEqual(len(result["created"]), 1)
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT payload_json FROM work_items WHERE phase='Q05'"
                ).fetchone()
            payload = json.loads(row[0])
            self.assertEqual(payload["q04_latest_full_year"], 2024)
            self.assertEqual(payload["q04_history_clamp_source"], "mt5_cache")
            self.assertEqual(payload["q04_history_checked_symbols"], manifest["basket_symbols"])
            self.assertEqual(payload["timeout_min"], farmctl.PHASE_ACTIVE_TIMEOUT_MIN["Q05"])
            self.assertEqual(payload["full_history_from"], farmctl.DWX_MULTI_SYMBOL_FULL_HISTORY_FROM)

    def test_pump_q04_to_q05_promotion_clamps_latest_year_from_cache(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            mt5_root = Path(tmp) / "mt5"
            ea_id = "QM5_9993"
            ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_basket-demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            logical = "QM5_9993_GBPJPY_AUDJPY_COINTEGRATION_D1"
            manifest = {
                "logical_symbol": logical,
                "host_symbol": "GBPJPY.DWX",
                "host_timeframe": "D1",
                "basket_symbols": ["GBPJPY.DWX", "AUDJPY.DWX", "USDJPY.DWX"],
            }
            manifest_path = ea_dir / "basket_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / f"{ea_dir.name}_{logical}_D1_backtest.set"
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            for symbol in manifest["basket_symbols"]:
                hist_dir = mt5_root / "T1" / "Bases" / "Custom" / "history" / symbol
                hist_dir.mkdir(parents=True)
                for year in (2023, 2024):
                    (hist_dir / f"{year}.hcc").write_text("", encoding="utf-8")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       verdict, attempt_count, payload_json, created_at, updated_at)
                    VALUES
                      ('q04-passish', 'backtest', 'Q04', ?, ?, ?,
                       'done', 'PASS_SOFT', 0, ?, ?, ?)
                    """,
                    (
                        ea_id,
                        logical,
                        str(setfile),
                        json.dumps({
                            "basket_manifest": str(manifest_path),
                            "host_symbol": "GBPJPY.DWX",
                            "host_timeframe": "D1",
                            "logical_symbol": logical,
                            "portfolio_scope": "basket",
                        }),
                        now,
                        now,
                    ),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            old_mt5_root = farmctl.MT5_ROOT
            # P5_CALIBRATION_JSON is bound to REPO_ROOT at import time, so
            # patching REPO_ROOT alone does not redirect it: the pump's P5
            # autostub appends this synthetic basket to the real, COMMITTED
            # framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json
            # and leaves the tree dirty, which blocks runtime-activation
            # decision minting.
            old_calibration = farmctl.P5_CALIBRATION_JSON
            try:
                farmctl.REPO_ROOT = repo_root
                farmctl.MT5_ROOT = mt5_root
                farmctl.P5_CALIBRATION_JSON = (
                    repo_root / "framework" / "calibrations"
                    / "VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json"
                )
                result = farmctl.pump(root)
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.MT5_ROOT = old_mt5_root
                farmctl.P5_CALIBRATION_JSON = old_calibration

            self.assertEqual(len(result["cascade_promotions"]), 1)
            self.assertEqual(result["cascade_promotions"][0]["to_phase"], "Q05")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT payload_json FROM work_items WHERE phase='Q05'"
                ).fetchone()
            payload = json.loads(row[0])
            self.assertEqual(payload["q04_latest_full_year"], 2024)
            self.assertEqual(payload["q04_history_clamp_source"], "mt5_cache")
            self.assertEqual(payload["timeout_min"], farmctl.PHASE_ACTIVE_TIMEOUT_MIN["Q05"])
            self.assertEqual(payload["full_history_from"], farmctl.DWX_MULTI_SYMBOL_FULL_HISTORY_FROM)

    def test_q05_runner_cmd_receives_latest_full_year_cap(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            report_root = root / "reports"
            setfile = root / "QM5_9998_demo_EURGBP.DWX_D1_backtest.set"
            setfile.write_text("", encoding="utf-8")
            conn = sqlite3.connect(":memory:")
            conn.row_factory = sqlite3.Row
            conn.execute(
                """
                CREATE TABLE work_items(
                    phase TEXT, ea_id TEXT, symbol TEXT, setfile_path TEXT, payload_json TEXT
                )
                """
            )
            conn.execute(
                "INSERT INTO work_items VALUES(?,?,?,?,?)",
                (
                    "Q05",
                    "QM5_9998",
                    "QM5_9998_EURGBP_EURAUD_COINTEGRATION_D1",
                    str(setfile),
                    json.dumps({
                        "basket_symbol_count": 2,
                        "host_symbol": "EURGBP.DWX",
                        "host_timeframe": "D1",
                        "portfolio_scope": "basket",
                        "q04_latest_full_year": 2024,
                    }),
                ),
            )
            row = conn.execute("SELECT * FROM work_items").fetchone()

            cmd = farmctl._phase_runner_cmd_for_work_item(root, row, report_root, "T8")

            self.assertIsNotNone(cmd)
            self.assertIn("--latest-full-year", cmd)
            self.assertEqual(cmd[cmd.index("--latest-full-year") + 1], "2024")
            self.assertIn("--full-history-from", cmd)
            self.assertEqual(
                cmd[cmd.index("--full-history-from") + 1],
                farmctl.DWX_MULTI_SYMBOL_FULL_HISTORY_FROM,
            )
            self.assertIn("--baseline-setfile", cmd)
            self.assertIn("--logical-symbol", cmd)
            self.assertEqual(cmd[cmd.index("--logical-symbol") + 1], "QM5_9998_EURGBP_EURAUD_COINTEGRATION_D1")
            self.assertNotIn("--setfile", cmd)

    def test_q06_runner_cmd_keeps_basket_logical_symbol(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            report_root = root / "reports"
            setfile = root / "QM5_9998_demo_USDJPY.DWX_D1_backtest.set"
            setfile.write_text("", encoding="utf-8")
            conn = sqlite3.connect(":memory:")
            conn.row_factory = sqlite3.Row
            conn.execute(
                """
                CREATE TABLE work_items(
                    phase TEXT, ea_id TEXT, symbol TEXT, setfile_path TEXT, payload_json TEXT
                )
                """
            )
            logical = "QM5_9998_USDJPY_AUDJPY_COINTEGRATION_D1"
            conn.execute(
                "INSERT INTO work_items VALUES(?,?,?,?,?)",
                (
                    "Q06",
                    "QM5_9998",
                    logical,
                    str(setfile),
                    json.dumps({
                        "basket_symbol_count": 2,
                        "host_symbol": "USDJPY.DWX",
                        "host_timeframe": "D1",
                        "portfolio_scope": "basket",
                        "q04_latest_full_year": 2024,
                    }),
                ),
            )
            row = conn.execute("SELECT * FROM work_items").fetchone()

            cmd = farmctl._phase_runner_cmd_for_work_item(root, row, report_root, "T8")

            self.assertIsNotNone(cmd)
            self.assertIn("q06_stress_harsh.py", " ".join(cmd))
            self.assertEqual(cmd[cmd.index("--symbol") + 1], "USDJPY.DWX")
            self.assertIn("--logical-symbol", cmd)
            self.assertEqual(cmd[cmd.index("--logical-symbol") + 1], logical)
            self.assertIn("--latest-full-year", cmd)
            self.assertEqual(cmd[cmd.index("--latest-full-year") + 1], "2024")
            self.assertIn("--full-history-from", cmd)
            self.assertEqual(
                cmd[cmd.index("--full-history-from") + 1],
                farmctl.DWX_MULTI_SYMBOL_FULL_HISTORY_FROM,
            )
            self.assertNotIn("--setfile", cmd)

    def test_q07_runner_cmd_keeps_basket_logical_symbol(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            report_root = root / "reports"
            setfile = root / "QM5_9998_demo_USDJPY.DWX_D1_backtest.set"
            setfile.write_text("", encoding="utf-8")
            conn = sqlite3.connect(":memory:")
            conn.row_factory = sqlite3.Row
            conn.execute(
                """
                CREATE TABLE work_items(
                    phase TEXT, ea_id TEXT, symbol TEXT, setfile_path TEXT, payload_json TEXT
                )
                """
            )
            logical = "QM5_9998_USDJPY_AUDJPY_COINTEGRATION_D1"
            conn.execute(
                "INSERT INTO work_items VALUES(?,?,?,?,?)",
                (
                    "Q07",
                    "QM5_9998",
                    logical,
                    str(setfile),
                    json.dumps({
                        "basket_symbol_count": 2,
                        "host_symbol": "USDJPY.DWX",
                        "host_timeframe": "D1",
                        "portfolio_scope": "basket",
                        "q04_latest_full_year": 2024,
                        "q07_seed_timeout_sec": 5400,
                        "append_only_rerun_lineage_work_items": [
                            "prior-q07",
                            "older-q07",
                        ],
                        "expected_current_ex5_sha256": "a" * 64,
                        "expected_mq5_sha256": "b" * 64,
                    }),
                ),
            )
            row = conn.execute("SELECT * FROM work_items").fetchone()

            cmd = farmctl._phase_runner_cmd_for_work_item(root, row, report_root, "T8")

            self.assertIsNotNone(cmd)
            self.assertIn("q07_multiseed.py", " ".join(cmd))
            self.assertEqual(cmd[cmd.index("--symbol") + 1], "USDJPY.DWX")
            self.assertIn("--logical-symbol", cmd)
            self.assertEqual(cmd[cmd.index("--logical-symbol") + 1], logical)
            self.assertIn("--latest-full-year", cmd)
            self.assertEqual(cmd[cmd.index("--latest-full-year") + 1], "2024")
            self.assertIn("--timeout-sec", cmd)
            self.assertEqual(cmd[cmd.index("--timeout-sec") + 1], "5400")
            reuse_indexes = [
                i for i, value in enumerate(cmd) if value == "--reuse-report-root"
            ]
            self.assertEqual(len(reuse_indexes), 2)
            self.assertEqual(
                [Path(cmd[i + 1]).name for i in reuse_indexes],
                ["prior-q07", "older-q07"],
            )
            self.assertEqual(
                cmd[cmd.index("--expected-ex5-sha256") + 1], "a" * 64
            )
            self.assertEqual(
                cmd[cmd.index("--expected-mq5-sha256") + 1], "b" * 64
            )
            self.assertIn("--full-history-from", cmd)
            self.assertEqual(
                cmd[cmd.index("--full-history-from") + 1],
                farmctl.DWX_MULTI_SYMBOL_FULL_HISTORY_FROM,
            )
            self.assertNotIn("--setfile", cmd)

    def test_q08_runner_cmd_forwards_baseline_setfile_and_neighborhood_cap(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            report_root = root / "reports"
            setfile = root / "QM5_13117_demo_EURGBP.DWX_D1_backtest.set"
            setfile.write_text("", encoding="utf-8")
            conn = sqlite3.connect(":memory:")
            conn.row_factory = sqlite3.Row
            conn.execute(
                """
                CREATE TABLE work_items(
                    phase TEXT, ea_id TEXT, symbol TEXT, setfile_path TEXT, payload_json TEXT
                )
                """
            )
            conn.execute(
                "INSERT INTO work_items VALUES(?,?,?,?,?)",
                ("Q08", "QM5_13117", "EURGBP.DWX", str(setfile), "{}"),
            )
            row = conn.execute("SELECT * FROM work_items").fetchone()

            cmd = farmctl._phase_runner_cmd_for_work_item(root, row, report_root, "T8")

            self.assertIsNotNone(cmd)
            self.assertEqual(Path(cmd[1]).name, "aggregate.py")
            self.assertEqual(cmd[cmd.index("--ea-id") + 1], "13117")
            self.assertEqual(cmd[cmd.index("--baseline-setfile") + 1], str(setfile))
            self.assertEqual(
                cmd[cmd.index("--neighborhood-max-params") + 1],
                str(farmctl.Q08_NEIGHBORHOOD_MAX_PARAMS),
            )
            self.assertEqual(cmd[cmd.index("--terminal") + 1], "T8")
            self.assertNotIn("--setfile", cmd)


class AppendOnlyCascadeRerunTests(unittest.TestCase):
    def test_q02_exact_rerun_is_append_only_guarded_and_idempotent(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_id = "QM5_9990"
            ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            mq5 = ea_dir / f"{ea_dir.name}.mq5"
            ex5 = ea_dir / f"{ea_dir.name}.ex5"
            setfile = sets_dir / f"{ea_dir.name}_EURUSD.DWX_H1_backtest.set"
            mq5.write_text("// source\n", encoding="utf-8")
            ex5.write_bytes(b"compiled")
            setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
            evidence = Path(tmp) / "historical-summary.json"
            evidence.write_text("{}\n", encoding="utf-8")

            source_payload = {
                "from_year": 2017,
                "to_year": 2022,
                "requested_from_year": 2017,
                "requested_to_year": 2022,
                "expected_symbol": "EURUSD.DWX",
                "expected_period": "H1",
                "expected_expert": f"QM\\{ea_dir.name}",
                "expected_mq5_sha256": farmctl._sha256_file(mq5),
                "expected_ex5_sha256": farmctl._sha256_file(ex5),
                "expected_setfile_sha256": farmctl._sha256_file(setfile),
                "pid": 1234,
                "terminal": "T3",
                "verdict_reason": "ACTIVE_TIMEOUT",
                "cold_cache_retry_attempt": 3,
                "avoid_terminals": ["T1", "T2"],
            }
            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       verdict, attempt_count, evidence_path, payload_json,
                       created_at, updated_at)
                    VALUES
                      ('q02-historical', 'backtest', 'Q02', ?, 'EURUSD.DWX', ?,
                       'done', 'INFRA_FAIL', 0, ?, ?, ?, ?)
                    """,
                    (
                        ea_id,
                        str(setfile),
                        str(evidence),
                        json.dumps(source_payload, sort_keys=True),
                        now,
                        now,
                    ),
                )
                conn.commit()
                before = conn.execute(
                    "SELECT status, verdict, evidence_path, payload_json, updated_at "
                    "FROM work_items WHERE id='q02-historical'"
                ).fetchone()

            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                result = farmctl.enqueue_cascade_backtest_for_ea(
                    root,
                    ea_id,
                    "Q02",
                    predecessor_work_item_id="q02-historical",
                    append_only_rerun_of="q02-historical",
                    rerun_reason="approved exact-row infrastructure canary",
                )
                repeat = farmctl.enqueue_cascade_backtest_for_ea(
                    root,
                    ea_id,
                    "Q02",
                    predecessor_work_item_id="q02-historical",
                    append_only_rerun_of="q02-historical",
                    rerun_reason="approved exact-row infrastructure canary",
                )
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertTrue(result["enqueued"])
            self.assertEqual(len(result["created"]), 1)
            self.assertFalse(repeat["enqueued"])
            self.assertEqual(
                repeat["skipped"][0]["reason"], "append_only_rerun_already_exists"
            )
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                after = conn.execute(
                    "SELECT status, verdict, evidence_path, payload_json, updated_at "
                    "FROM work_items WHERE id='q02-historical'"
                ).fetchone()
                rerun = conn.execute(
                    "SELECT status, verdict, evidence_path, payload_json FROM work_items "
                    "WHERE id=?",
                    (result["created"][0]["id"],),
                ).fetchone()
                phase_count = conn.execute(
                    "SELECT COUNT(*) FROM work_items WHERE phase='Q02'"
                ).fetchone()[0]
            self.assertEqual(after, before)
            self.assertEqual(phase_count, 2)
            self.assertEqual(rerun[0:3], ("pending", None, None))
            payload = json.loads(rerun[3])
            self.assertTrue(payload["append_only_rerun"])
            self.assertTrue(payload["historical_work_item_preserved"])
            self.assertEqual(
                payload["append_only_rerun_of_work_item"], "q02-historical"
            )
            self.assertEqual(payload["risk_fixed"], 1000.0)
            self.assertEqual(payload["risk_percent"], 0.0)
            for runtime_key in (
                "pid",
                "terminal",
                "verdict_reason",
                "cold_cache_retry_attempt",
                "avoid_terminals",
            ):
                self.assertNotIn(runtime_key, payload)

    def test_q02_exact_rerun_keeps_basket_row_and_host_identities_distinct(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_id = "QM5_9992"
            ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_basket-demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            mq5 = ea_dir / f"{ea_dir.name}.mq5"
            ex5 = ea_dir / f"{ea_dir.name}.ex5"
            logical = "QM5_9992_EURUSD_AUDJPY_COINTEGRATION_D1"
            host = "EURUSD.DWX"
            setfile = sets_dir / f"{ea_dir.name}_{logical}_D1_backtest.set"
            mq5.write_text("// source\n", encoding="utf-8")
            ex5.write_bytes(b"compiled")
            setfile.write_text(
                "RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8"
            )
            evidence = Path(tmp) / "basket-summary.json"
            evidence.write_text("{}\n", encoding="utf-8")
            source_payload = {
                "basket_manifest": str(ea_dir / "basket_manifest.json"),
                "basket_symbol_count": 2,
                "basket_symbols": [host, "AUDJPY.DWX"],
                "host_symbol": host,
                "host_timeframe": "D1",
                "logical_symbol": logical,
                "portfolio_scope": "basket",
                "expected_symbol": host,
                "expected_period": "D1",
                "expected_expert": f"QM\\{ea_dir.name}",
                "expected_mq5_sha256": farmctl._sha256_file(mq5),
                "expected_ex5_sha256": farmctl._sha256_file(ex5),
                "expected_setfile_sha256": farmctl._sha256_file(setfile),
            }
            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       verdict, attempt_count, evidence_path, payload_json,
                       created_at, updated_at)
                    VALUES
                      ('q02-basket-infra', 'backtest', 'Q02', ?, ?, ?,
                       'failed', 'INFRA_FAIL', 3, ?, ?, ?, ?)
                    """,
                    (
                        ea_id,
                        logical,
                        str(setfile),
                        str(evidence),
                        json.dumps(source_payload, sort_keys=True),
                        now,
                        now,
                    ),
                )
                conn.commit()

            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                result = farmctl.enqueue_cascade_backtest_for_ea(
                    root,
                    ea_id,
                    "Q02",
                    predecessor_work_item_id="q02-basket-infra",
                    append_only_rerun_of="q02-basket-infra",
                    rerun_reason="basket host-history infrastructure retry",
                    expected_current_ex5_sha256=farmctl._sha256_file(ex5),
                )
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertTrue(result["enqueued"])
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT symbol, payload_json FROM work_items WHERE id=?",
                    (result["created"][0]["id"],),
                ).fetchone()
            self.assertEqual(row[0], logical)
            payload = json.loads(row[1])
            self.assertEqual(payload["logical_symbol"], logical)
            self.assertEqual(payload["host_symbol"], host)
            self.assertEqual(payload["expected_symbol"], host)
            self.assertEqual(payload["expected_period"], "D1")

    def test_exact_rerun_creates_one_row_and_preserves_historical_verdict(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_id = "QM5_9991"
            ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            (ea_dir / f"{ea_dir.name}.mq5").write_text("// source\n", encoding="utf-8")
            ex5 = ea_dir / f"{ea_dir.name}.ex5"
            ex5.write_bytes(b"compiled")
            current_ex5_sha256 = farmctl._sha256_file(ex5)
            setfile = sets_dir / f"{ea_dir.name}_EURUSD.DWX_H1_backtest.set"
            setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")

            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       verdict, attempt_count, evidence_path, payload_json, created_at, updated_at)
                    VALUES
                      ('q05-source', 'backtest', 'Q05', ?, 'EURUSD.DWX', ?,
                       'done', 'PASS', 0, 'q05-evidence.json', ?, ?, ?),
                      ('q06-historical', 'backtest', 'Q06', ?, 'EURUSD.DWX', ?,
                       'done', 'PASS', 0, 'q06-evidence.json', ?, ?, ?)
                    """,
                    (
                        ea_id,
                        str(setfile),
                        json.dumps({"verdict_reason": "q05-pass"}, sort_keys=True),
                        now,
                        now,
                        ea_id,
                        str(setfile),
                        json.dumps({"verdict_reason": "historical-stress-pass"}, sort_keys=True),
                        now,
                        now,
                    ),
                )
                conn.commit()
                before = conn.execute(
                    "SELECT status, verdict, evidence_path, payload_json, updated_at "
                    "FROM work_items WHERE id='q06-historical'"
                ).fetchone()

            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                result = farmctl.enqueue_cascade_backtest_for_ea(
                    root,
                    ea_id,
                    "Q06",
                    predecessor_work_item_id="q05-source",
                    append_only_rerun_of="q06-historical",
                    rerun_reason="authenticated stress wiring repair",
                    expected_current_ex5_sha256=current_ex5_sha256,
                )
                repeat = farmctl.enqueue_cascade_backtest_for_ea(
                    root,
                    ea_id,
                    "Q06",
                    predecessor_work_item_id="q05-source",
                    append_only_rerun_of="q06-historical",
                    rerun_reason="authenticated stress wiring repair",
                    expected_current_ex5_sha256=current_ex5_sha256,
                )
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertTrue(result["enqueued"])
            self.assertEqual(result["requeued"], [])
            self.assertEqual(len(result["created"]), 1)
            self.assertEqual(
                result["created"][0]["rerun_of_work_item_id"], "q06-historical"
            )
            self.assertEqual(repeat["created"], [])
            self.assertEqual(
                repeat["skipped"][0]["reason"], "append_only_rerun_already_exists"
            )

            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                after = conn.execute(
                    "SELECT status, verdict, evidence_path, payload_json, updated_at "
                    "FROM work_items WHERE id='q06-historical'"
                ).fetchone()
                rerun = conn.execute(
                    "SELECT status, verdict, evidence_path, payload_json FROM work_items "
                    "WHERE id=?",
                    (result["created"][0]["id"],),
                ).fetchone()
                phase_count = conn.execute(
                    "SELECT COUNT(*) FROM work_items WHERE phase='Q06'"
                ).fetchone()[0]
            self.assertEqual(after, before)
            self.assertEqual(phase_count, 2)
            self.assertEqual(rerun[0:3], ("pending", None, None))
            payload = json.loads(rerun[3])
            self.assertTrue(payload["append_only_rerun"])
            self.assertTrue(payload["historical_work_item_preserved"])
            self.assertEqual(
                payload["append_only_rerun_of_work_item"], "q06-historical"
            )
            self.assertEqual(
                payload["append_only_rerun_lineage_work_items"],
                ["q06-historical"],
            )
            self.assertEqual(payload["promoted_from_work_item"], "q05-source")


class Q06SoftStackingTests(unittest.TestCase):
    """OWNER Option A 2026-08-21: Q06 PASS_SOFT probation + anti-stacking at Q08."""

    def _insert(self, conn, *, wid, phase, ea_id, symbol, verdict, payload,
                status="done", evidence_path=None):
        now = farmctl.utc_now()
        conn.execute(
            """
            INSERT INTO work_items
              (id, kind, phase, ea_id, symbol, setfile_path, status,
               verdict, attempt_count, evidence_path, payload_json,
               created_at, updated_at)
            VALUES (?, 'backtest', ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?)
            """,
            (wid, phase, ea_id, symbol, "s.set", status, verdict,
             evidence_path, json.dumps(payload), now, now),
        )

    def test_cost_cushion_edge_soft_detection(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            farmctl.init_db(root)
            with farmctl.connect(root) as conn:
                self._insert(conn, wid="soft", phase="Q08", ea_id="QM5_1",
                             symbol="XAUUSD.DWX", verdict="FAIL_SOFT",
                             payload={"q08_verdict_classification":
                                      {"8.1": "PASS", "cost_cushion": "EDGE_SOFT"}})
                self._insert(conn, wid="clean", phase="Q08", ea_id="QM5_2",
                             symbol="XAUUSD.DWX", verdict="PASS",
                             payload={"q08_verdict_classification":
                                      {"8.1": "PASS", "cost_cushion": "PASS"}})
                self._insert(conn, wid="toplevel", phase="Q08", ea_id="QM5_3",
                             symbol="XAUUSD.DWX", verdict="FAIL_SOFT",
                             payload={"cost_cushion_tier": "EDGE_SOFT"})
                conn.commit()
                rows = {r["id"]: r for r in conn.execute(
                    "SELECT * FROM work_items WHERE phase='Q08'")}
            self.assertTrue(farmctl._q08_cost_cushion_edge_soft(rows["soft"]))
            self.assertFalse(farmctl._q08_cost_cushion_edge_soft(rows["clean"]))
            self.assertTrue(farmctl._q08_cost_cushion_edge_soft(rows["toplevel"]))

    def test_q06_soft_probation_present(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            farmctl.init_db(root)
            with farmctl.connect(root) as conn:
                self._insert(conn, wid="q6soft", phase="Q06", ea_id="QM5_1",
                             symbol="XAUUSD.DWX", verdict="PASS_SOFT",
                             payload={"verdict_reason":
                                      "pass_soft_band:pf=0.970:dd_pct=12.40:probation:q06_soft"})
                self._insert(conn, wid="q6pass", phase="Q06", ea_id="QM5_2",
                             symbol="XAUUSD.DWX", verdict="PASS",
                             payload={"verdict_reason": "pf=1.300:dd_pct=8.10:stress=HARSH"})
                self._insert(conn, wid="q6marker", phase="Q06", ea_id="QM5_3",
                             symbol="XAUUSD.DWX", verdict="FAIL",
                             payload={"verdict_reason": "probation:q06_soft"})
                conn.commit()
                self.assertTrue(
                    farmctl._q06_soft_probation_present(conn, "QM5_1", "XAUUSD.DWX"))
                self.assertFalse(
                    farmctl._q06_soft_probation_present(conn, "QM5_2", "XAUUSD.DWX"))
                self.assertTrue(
                    farmctl._q06_soft_probation_present(conn, "QM5_3", "XAUUSD.DWX"))
                # No Q06 row at all -> absent.
                self.assertFalse(
                    farmctl._q06_soft_probation_present(conn, "QM5_9", "XAUUSD.DWX"))

    def _promote_result(self):
        return {"q09_portfolio_promotions": [],
                "q09_portfolio_promotions_skipped": [],
                "q09_portfolio_admissions": []}

    def test_promote_blocks_soft_stacking_as_terminal_fail(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            farmctl.init_db(root)
            evidence = Path(tmp) / "aggregate.json"
            evidence.write_text('{"verdict": "FAIL_SOFT"}', encoding="utf-8")
            with farmctl.connect(root) as conn:
                # (ea1) stacks: Q06 PASS_SOFT + Q08 FAIL_SOFT thin cost cushion.
                self._insert(conn, wid="e1q6", phase="Q06", ea_id="QM5_1",
                             symbol="XAUUSD.DWX", verdict="PASS_SOFT",
                             payload={"verdict_reason": "probation:q06_soft"})
                self._insert(conn, wid="e1q8", phase="Q08", ea_id="QM5_1",
                             symbol="XAUUSD.DWX", verdict="FAIL_SOFT",
                             evidence_path=str(evidence),
                             payload={"q08_verdict_classification":
                                      {"cost_cushion": "EDGE_SOFT"}})
                # (ea2) control: same Q08 thin cushion but Q06 was a clean PASS.
                self._insert(conn, wid="e2q6", phase="Q06", ea_id="QM5_2",
                             symbol="XAUUSD.DWX", verdict="PASS",
                             payload={"verdict_reason": "stress=HARSH"})
                self._insert(conn, wid="e2q8", phase="Q08", ea_id="QM5_2",
                             symbol="XAUUSD.DWX", verdict="FAIL_SOFT",
                             evidence_path=str(evidence),
                             payload={"q08_verdict_classification":
                                      {"cost_cushion": "EDGE_SOFT"},
                                      "q08_trade_count": 300})
                conn.commit()
                result = self._promote_result()
                farmctl._promote_q08_soft_fails_to_q09_portfolio(conn, result)
                conn.commit()
                q09 = [dict(r) for r in conn.execute(
                    "SELECT ea_id, status, verdict, payload_json FROM work_items "
                    "WHERE phase=?", (farmctl._NEWS_PORTFOLIO_PHASE,))]

            def _reason(row):
                return json.loads(row["payload_json"] or "{}").get("verdict_reason")

            ea1 = [r for r in q09 if r["ea_id"] == "QM5_1"]
            ea2 = [r for r in q09 if r["ea_id"] == "QM5_2"]
            # ea1: anti-stacking fired -> exactly one terminal FAIL row, no rescue row.
            self.assertEqual(len(ea1), 1)
            self.assertEqual((ea1[0]["status"], ea1[0]["verdict"]), ("done", "FAIL"))
            self.assertEqual(
                _reason(ea1[0]), "soft_stacking_forbidden:q06_soft+q08_edge_soft")
            # ea2 (no Q06 probation): promoted through the normal path, NEVER soft-stacked.
            self.assertEqual(len(ea2), 1)
            self.assertNotEqual(
                _reason(ea2[0]), "soft_stacking_forbidden:q06_soft+q08_edge_soft")
            self.assertNotEqual(
                (ea2[0]["status"], ea2[0]["verdict"]), ("done", "FAIL"))


class DefectBlockExclusionTests(unittest.TestCase):
    """Task 5343f90a: the build-decision promotion pumps read the raw work_items
    table with no BLOCKED exclusion. A pre-block PASS row from a 2026-08-16
    defect-blocked EA must not be re-promoted by default; a named override opts
    the tainted rows back in. Clean (non-cohort) EAs are always unaffected.
    """

    COHORT_EA = "QM5_10648"           # host_slot_magic_conflation
    COHORT_EA_2 = "QM5_10649"         # host_slot_magic_conflation
    PRE_BLOCK = "2026-08-15T00:00:00+00:00"

    def _insert(self, conn, *, wid, phase, ea_id, symbol, verdict, setfile_path,
                updated_at, status="done", evidence_path=None, payload=None):
        conn.execute(
            """
            INSERT INTO work_items
              (id, kind, phase, ea_id, symbol, setfile_path, status,
               verdict, attempt_count, evidence_path, payload_json,
               created_at, updated_at)
            VALUES (?, 'backtest', ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?)
            """,
            (wid, phase, ea_id, symbol, setfile_path, status, verdict,
             evidence_path, json.dumps(payload or {}), updated_at, updated_at),
        )

    # ---- Site 4: Q08 -> Q09_PORTFOLIO feeder (direct) --------------------

    def _promote_result(self):
        return {"q09_portfolio_promotions": [],
                "q09_portfolio_promotions_skipped": []}

    def test_q08_to_q09_portfolio_excludes_cohort_by_default_and_override_includes(self) -> None:
        for include, expect_cohort in ((False, False), (True, True)):
            with self.subTest(include=include):
                with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
                    root = Path(tmp) / "farm"
                    farmctl.init_db(root)
                    evidence = Path(tmp) / "aggregate.json"
                    evidence.write_text('{"q08_trade_count": 300}', encoding="utf-8")
                    with farmctl.connect(root) as conn:
                        self._insert(conn, wid="cohort", phase="Q08",
                                     ea_id=self.COHORT_EA, symbol="XAUUSD.DWX",
                                     verdict="PASS", setfile_path="s.set",
                                     updated_at=self.PRE_BLOCK,
                                     evidence_path=str(evidence),
                                     payload={"q08_trade_count": 300})
                        self._insert(conn, wid="clean", phase="Q08",
                                     ea_id="QM5_2", symbol="XAUUSD.DWX",
                                     verdict="PASS", setfile_path="s.set",
                                     updated_at=self.PRE_BLOCK,
                                     evidence_path=str(evidence),
                                     payload={"q08_trade_count": 300})
                        conn.commit()
                        result = self._promote_result()
                        farmctl._promote_q08_soft_fails_to_q09_portfolio(
                            conn, result,
                            include_defect_blocked_evidence=include,
                        )
                        conn.commit()
                        q09_eas = {r[0] for r in conn.execute(
                            "SELECT DISTINCT ea_id FROM work_items WHERE phase=?",
                            (farmctl._NEWS_PORTFOLIO_PHASE,),
                        )}
                    # The clean EA always advances; the cohort EA only under override.
                    self.assertIn("QM5_2", q09_eas)
                    self.assertEqual(self.COHORT_EA in q09_eas, expect_cohort)

    # ---- Sites 1 & 3: cascade Q03->Q04 and Q02->Q04 probe (full pump) -----

    def _pump_q04_eas(self, include_defect_blocked_evidence: bool) -> set[str]:
        tmp = tempfile.mkdtemp()
        self.addCleanup(lambda: __import__("shutil").rmtree(tmp, ignore_errors=True))
        root = Path(tmp) / "farm"
        repo_root = Path(tmp) / "repo"
        sets_dir = Path(tmp) / "sets"
        sets_dir.mkdir(parents=True)

        def _set(name: str) -> str:
            p = sets_dir / name
            p.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            return str(p)

        farmctl.init_db(root)
        with farmctl.connect(root) as conn:
            # Cohort EA A: pre-block Q03 PASS -> cascade Q03->Q04 (site 1).
            self._insert(conn, wid="a-q03", phase="Q03", ea_id=self.COHORT_EA,
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=_set("a.set"), updated_at=self.PRE_BLOCK)
            # Cohort EA B: pre-block Q02 PASS -> Q04 early probe (site 3).
            self._insert(conn, wid="b-q02", phase="Q02", ea_id=self.COHORT_EA_2,
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=_set("b.set"), updated_at=self.PRE_BLOCK)
            # Clean control EAs (never in the cohort): both must promote.
            self._insert(conn, wid="c-q03", phase="Q03", ea_id="QM5_9992",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=_set("c.set"), updated_at=self.PRE_BLOCK)
            self._insert(conn, wid="d-q02", phase="Q02", ea_id="QM5_9991",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=_set("d.set"), updated_at=self.PRE_BLOCK)
            conn.commit()

        old_repo_root = farmctl.REPO_ROOT
        # Same import-time binding as the pump helper above: without this the
        # committed VPS slippage/latency calibration picks up this test's EAs.
        old_calibration = farmctl.P5_CALIBRATION_JSON
        try:
            farmctl.REPO_ROOT = repo_root
            farmctl.P5_CALIBRATION_JSON = (
                repo_root / "framework" / "calibrations"
                / "VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json"
            )
            farmctl.pump(
                root,
                include_defect_blocked_evidence=include_defect_blocked_evidence,
            )
        finally:
            farmctl.REPO_ROOT = old_repo_root
            farmctl.P5_CALIBRATION_JSON = old_calibration

        with farmctl.connect(root) as conn:
            return {r[0] for r in conn.execute(
                "SELECT DISTINCT ea_id FROM work_items WHERE phase='Q04'")}

    def test_pump_excludes_cohort_q03_and_q02_pass_by_default(self) -> None:
        q04_eas = self._pump_q04_eas(include_defect_blocked_evidence=False)
        # Clean EAs promote to Q04; the two cohort EAs do not.
        self.assertIn("QM5_9992", q04_eas)   # cascade Q03->Q04
        self.assertIn("QM5_9991", q04_eas)   # Q02->Q04 probe
        self.assertNotIn(self.COHORT_EA, q04_eas)
        self.assertNotIn(self.COHORT_EA_2, q04_eas)

    def test_pump_includes_cohort_under_named_override(self) -> None:
        q04_eas = self._pump_q04_eas(include_defect_blocked_evidence=True)
        self.assertIn(self.COHORT_EA, q04_eas)
        self.assertIn(self.COHORT_EA_2, q04_eas)

    # ---- Site 2: Q02/P2 -> Q03/P3 promoter query core --------------------

    def test_q02_to_q03_base_query_excludes_cohort_pre_block_rows(self) -> None:
        # The site-2 promoter's base query, with the shared default-on exclusion
        # clause applied, must drop the cohort's pre-block Q02 PASS and keep the
        # clean EA. (End-to-end promotion additionally gates on ea_metrics profit;
        # this proves the row is filtered before that gate is ever reached.)
        conn = sqlite3.connect(":memory:")
        conn.execute(
            "CREATE TABLE work_items (id TEXT, ea_id TEXT, phase TEXT, "
            "status TEXT, verdict TEXT, setfile_path TEXT, updated_at TEXT)"
        )
        conn.executemany(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?)",
            [
                ("cohort", self.COHORT_EA, "Q02", "done", "PASS", "s.set", self.PRE_BLOCK),
                ("clean", "QM5_9990", "Q02", "done", "PASS", "s.set", self.PRE_BLOCK),
            ],
        )
        base = (
            "SELECT w.id FROM work_items w "
            "WHERE w.status='done' AND w.verdict='PASS' AND w.phase in ('Q02','P2')"
        )
        excl = farmctl._defect_block_exclusion_clause(False)
        default_ids = [r[0] for r in conn.execute(base + excl + " ORDER BY w.id")]
        self.assertEqual(default_ids, ["clean"])
        override_ids = [
            r[0] for r in conn.execute(
                base + farmctl._defect_block_exclusion_clause(True) + " ORDER BY w.id")
        ]
        self.assertEqual(override_ids, ["clean", "cohort"])


class MeasurementSiblingCascadeTests(unittest.TestCase):
    """OQ-SIBLING-CASCADE-20260903: a DL-089 ``_opt`` measurement sibling is an
    instrument, not a candidate.  Its card authorizes no live or pipeline
    verdict and the matrix service seeds exactly one Q02 PREREQUISITE row per
    sibling to unlock the OPT_CENSUS cells.  The pump promoters used to fan that
    Q02 PASS into the normal gate chain (69 beyond-Q02 rows across 20 sibling
    EAs on the live DB, one as far as Q10_NEWS).

    The dangerous half of this containment is RECOGNITION, so most of what is
    asserted below is the negative case: an ordinary EA -- including a
    zero-trade ``_v2`` rework card, which legitimately carries ``parent_ea_id``
    and MUST run the full pipeline -- keeps promoting exactly as before.
    """

    SCHEMA = farmctl.DL089_Q02_PREREQUISITE_SCHEMA
    SENTENCE = farmctl.DL089_MEASUREMENT_CARD_SENTENCE
    STAMP = "2026-09-01T00:00:00+00:00"

    def setUp(self) -> None:
        # File-keyed cache: temp paths never repeat, but an entry left by
        # another test's identically-named file must not leak in.
        farmctl._MEASUREMENT_SIBLING_CARD_CACHE.clear()
        self.addCleanup(farmctl._MEASUREMENT_SIBLING_CARD_CACHE.clear)
        self.tmp = Path(self._mkdtemp())
        # Both recognizer roots default to real locations that hold the LIVE
        # sibling population (the checkout's cards_approved and
        # D:\QM\strategy_farm\artifacts\opt_census). Point them at empty temp
        # dirs so every case below states its own sibling population.
        self._patch(farmctl, "REPO_ROOT", self.tmp / "empty_repo")
        self._patch(
            farmctl, "DL089_MATRIX_ARTIFACT_ROOT", self.tmp / "empty_opt_census"
        )

    def _mkdtemp(self) -> str:
        path = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, path, ignore_errors=True)
        return path

    def _patch(self, module, name: str, value) -> None:
        old = getattr(module, name)
        setattr(module, name, value)
        self.addCleanup(setattr, module, name, old)

    # ---- fixtures --------------------------------------------------------

    def _insert(self, conn, *, wid, phase, ea_id, symbol, verdict, setfile_path,
                status="done", payload=None, evidence_path=None,
                updated_at=None):
        # payload_json is NOT NULL in the schema, so "" is the emptiest a real
        # row can be; a str payload is stored verbatim to allow malformed JSON.
        if payload is None:
            payload = "{}"
        stamp = updated_at or self.STAMP
        conn.execute(
            """
            INSERT INTO work_items
              (id, kind, phase, ea_id, symbol, setfile_path, status,
               verdict, attempt_count, payload_json, evidence_path,
               created_at, updated_at)
            VALUES (?, 'backtest', ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?)
            """,
            (wid, phase, ea_id, symbol, setfile_path, status, verdict,
             payload if isinstance(payload, str) else json.dumps(payload),
             evidence_path, stamp, stamp),
        )

    def _write_card(self, cards_dir: Path, ea_id: str, *, parent_ea_id=None,
                    sentence: bool = False, wrap: bool = False) -> Path:
        cards_dir.mkdir(parents=True, exist_ok=True)
        lines = ["---", f"ea_id: {ea_id}", "type: strategy"]
        if parent_ea_id:
            lines.append(f"parent_ea_id: {parent_ea_id}")
        lines += ["g0_status: APPROVED", "---", "", f"# {ea_id}", ""]
        if sentence:
            if wrap:
                # 41321/41322 shape: the sentence is hard-wrapped mid-phrase.
                head, tail = self.SENTENCE.split(" ", 3)[:3], self.SENTENCE.split(" ", 3)[3]
                lines += [" ".join(head), tail + "."]
            else:
                lines.append(self.SENTENCE + ".")
        else:
            lines.append("An ordinary rework of its parent; runs the full pipeline.")
        path = cards_dir / f"{ea_id}_demo.md"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return path

    def _write_registration(self, program: str, measurement_ea_id, *,
                            raw: str | None = None) -> Path:
        program_dir = farmctl.DL089_MATRIX_ARTIFACT_ROOT / program
        program_dir.mkdir(parents=True, exist_ok=True)
        path = program_dir / farmctl.DL089_MATRIX_REGISTRATION_FILENAME
        if raw is None:
            raw = json.dumps({
                "schema": "qm.dl089-matrix-registration-receipt/v1",
                "subject_ea_id": "QM5_10145",
                "measurement_ea_id": measurement_ea_id,
            })
        path.write_text(raw, encoding="utf-8")
        return path

    def _farm(self):
        """A fresh initialised farm root plus a set-file factory."""
        base = Path(self._mkdtemp())
        root = base / "farm"
        sets_dir = base / "sets"
        sets_dir.mkdir(parents=True)

        def make_set(name: str) -> str:
            path = sets_dir / name
            path.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            return str(path)

        farmctl.init_db(root)
        return root, make_set

    def _run_pump(self, seed) -> dict:
        root, make_set = self._farm()
        with farmctl.connect(root) as conn:
            seed(conn, root, make_set)
            conn.commit()
        # P5_CALIBRATION_JSON is bound to REPO_ROOT at import time, so patching
        # REPO_ROOT alone does not redirect it: the pump's P5 autostub would
        # append these synthetic EA/symbol pairs to the real, committed
        # framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json and
        # leave the tree dirty, which in turn blocks runtime-activation minting.
        self._patch(
            farmctl,
            "P5_CALIBRATION_JSON",
            farmctl.REPO_ROOT / "framework" / "calibrations"
            / "VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json",
        )
        result = farmctl.pump(root)
        with farmctl.connect(root) as conn:
            pending = [
                (r["ea_id"], r["phase"])
                for r in conn.execute(
                    "SELECT ea_id, phase FROM work_items WHERE status='pending'"
                )
            ]
        return {"result": result, "pending": pending, "root": root}

    # ---- P1: recognition must not misfire on the generic lineage field ----

    def test_ordinary_card_with_parent_ea_id_alone_is_still_promoted(self) -> None:
        # THE false-positive trap.  decisions/DL-062 and
        # processes/zero_trade_v2_build_pipeline.md give every zero-trade `_v2`
        # rework card a `parent_ea_id` pointing at the original; those cards
        # inherit APPROVED and MUST run the full pipeline.  Recognizing them
        # would bar an ordinary EA from every gate with no FAIL and no verdict,
        # and this exclusion takes no override.
        def seed(conn, root, make_set):
            cards = root / "artifacts" / "cards_approved"
            self._write_card(cards, "QM5_1056_v2", parent_ea_id=None)
            self._write_card(cards, "QM5_9995", parent_ea_id="QM5_1056")
            self._insert(conn, wid="rework", phase="Q02", ea_id="QM5_9995",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=make_set("rework.set"))

        run = self._run_pump(seed)
        self.assertIn(("QM5_9995", "Q04"), run["pending"])
        self.assertEqual(
            run["result"]["measurement_sibling_resolution"]["ea_ids"], []
        )

    def test_sentence_without_parent_ea_id_is_not_a_sibling(self) -> None:
        # The conjunction has to hold from both sides: a card that merely
        # quotes the sentence (a policy note, a copied paragraph) is not a
        # measurement carrier either.
        cards = self.tmp / "cards" / "artifacts" / "cards_approved"
        self._write_card(cards, "QM5_9996", parent_ea_id=None, sentence=True)
        found, failures, present = farmctl._measurement_sibling_card_ea_ids_in(cards)
        self.assertEqual((set(found), failures, present), (set(), [], True))

    def test_card_needs_both_markers_including_a_wrapped_sentence(self) -> None:
        cards = self.tmp / "cards" / "artifacts" / "cards_approved"
        self._write_card(cards, "QM5_41323", parent_ea_id="QM5_11660", sentence=True)
        # 41321/41322 wrap the sentence mid-phrase; a raw substring test finds
        # only half the live sibling cards.
        self._write_card(cards, "QM5_41321", parent_ea_id="QM5_13013",
                         sentence=True, wrap=True)
        self._write_card(cards, "QM5_9995", parent_ea_id="QM5_1056")
        found, failures, present = farmctl._measurement_sibling_card_ea_ids_in(cards)
        self.assertEqual(set(found), {"QM5_41323", "QM5_41321"})
        self.assertEqual((failures, present), ([], True))

    def test_card_scan_reacts_to_an_in_place_card_edit(self) -> None:
        # NTFS does not bump a directory's mtime when a file body changes, so a
        # directory-mtime cache would pin the sibling set for the process life.
        cards = self.tmp / "edit" / "artifacts" / "cards_approved"
        self._write_card(cards, "QM5_41324", parent_ea_id="QM5_21501")
        self.assertEqual(
            farmctl._measurement_sibling_card_ea_ids_in(cards)[0], frozenset()
        )
        self._write_card(cards, "QM5_41324", parent_ea_id="QM5_21501", sentence=True)
        self.assertEqual(
            farmctl._measurement_sibling_card_ea_ids_in(cards)[0],
            frozenset({"QM5_41324"}),
        )

    # ---- the three contract recognizers ----------------------------------

    def test_seeded_q02_sibling_is_held_and_ordinary_one_promotes(self) -> None:
        def seed(conn, root, make_set):
            # The exact row dl089_matrix_service._seed_q02 writes.
            self._insert(conn, wid="sib-q02", phase="Q02", ea_id="QM5_41301",
                         symbol="XAUUSD.DWX", verdict="PASS",
                         setfile_path=make_set("sib.set"),
                         payload={"schema": self.SCHEMA,
                                  "subject_ea_id": "QM5_10145"})
            self._insert(conn, wid="ord-q02", phase="Q02", ea_id="QM5_9991",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=make_set("ord.set"))

        run = self._run_pump(seed)
        self.assertIn(("QM5_9991", "Q04"), run["pending"])
        self.assertEqual(
            [row for row in run["pending"]
             if row[0] == "QM5_41301" and row[1] != "Q02"],
            [],
            "a seeded measurement sibling must gain no successor gate row",
        )

    def test_matrix_registration_recognizes_a_sibling_with_no_seed_or_card(self) -> None:
        # QM5_41097's shape: its Q02 predates the matrix service (no seed
        # schema) and it has no approved card, so the registration receipt is
        # the only recognizer that covers it. Both receipt schemas count -- the
        # field is the contract, not the schema literal.
        self._write_registration(
            "DL089_QM5_13213_USDJPY_DWX_2019_2025",
            "QM5_41097",
            raw=json.dumps({
                "schema": "qm.dl089-legacy-matrix-registration/v1",
                "subject_ea_id": "QM5_13213",
                "measurement_ea_id": "QM5_41097",
            }),
        )

        def seed(conn, root, make_set):
            self._insert(conn, wid="sib-q02", phase="Q02", ea_id="QM5_41097",
                         symbol="USDJPY.DWX", verdict="PASS",
                         setfile_path=make_set("sib.set"))
            self._insert(conn, wid="ord-q02", phase="Q02", ea_id="QM5_9994",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=make_set("ord.set"))

        run = self._run_pump(seed)
        self.assertIn(("QM5_9994", "Q04"), run["pending"])
        self.assertNotIn(("QM5_41097", "Q04"), run["pending"])
        self.assertEqual(
            run["result"]["measurement_sibling_resolution"]["ea_ids"], ["QM5_41097"]
        )

    def test_sibling_q03_pass_does_not_cascade_to_q04(self) -> None:
        # A Q03..Q09 row carries no schema of its own; it is recognized through
        # its EA, which is how the live QM5_41303 chain escaped.
        def seed(conn, root, make_set):
            self._insert(conn, wid="sib-q02", phase="Q02", ea_id="QM5_41303",
                         symbol="XTIUSD.DWX", verdict="PASS",
                         setfile_path=make_set("sib.set"),
                         payload={"schema": self.SCHEMA})
            self._insert(conn, wid="sib-q03", phase="Q03", ea_id="QM5_41303",
                         symbol="XTIUSD.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q03.set"))
            self._insert(conn, wid="ord-q03", phase="Q03", ea_id="QM5_9992",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=make_set("ord_q03.set"))

        pending = self._run_pump(seed)["pending"]
        self.assertIn(("QM5_9992", "Q04"), pending)
        self.assertNotIn(("QM5_41303", "Q04"), pending)
        self.assertNotIn(("QM5_41303", "Q05"), pending)

    # ---- P2: the hold record must mean what it says -----------------------

    def test_hold_record_reports_only_rows_without_a_successor(self) -> None:
        # Without the promoters' own NOT EXISTS successor condition this pass
        # reported 51 rows on the live DB where 3 were genuinely withheld: 48
        # of them had already been promoted and merely still matched the
        # source-side predicate.
        def seed(conn, root, make_set):
            promoted_set = make_set("already.set")
            self._insert(conn, wid="done-q02", phase="Q02", ea_id="QM5_41302",
                         symbol="XAUUSD.DWX", verdict="PASS",
                         setfile_path=promoted_set,
                         # ablated_at keeps the round-3 pump_ablation_random
                         # edge inert here so this case stays a test of the
                         # cascade/probe NOT-EXISTS successor condition; the
                         # ablation edges have their own test below.
                         payload={"schema": self.SCHEMA, "ablated_at": self.STAMP})
            # Its Q03 and Q04 successors already exist: nothing is withheld.
            self._insert(conn, wid="done-q03", phase="Q03", ea_id="QM5_41302",
                         symbol="XAUUSD.DWX", verdict=None, status="pending",
                         setfile_path=promoted_set)
            self._insert(conn, wid="done-q04", phase="Q04", ea_id="QM5_41302",
                         symbol="XAUUSD.DWX", verdict=None, status="pending",
                         setfile_path=promoted_set)
            self._insert(conn, wid="open-q02", phase="Q02", ea_id="QM5_41305",
                         symbol="XTIUSD.DWX", verdict="PASS",
                         setfile_path=make_set("open.set"),
                         payload={"schema": self.SCHEMA, "ablated_at": self.STAMP})

        result = self._run_pump(seed)["result"]
        holds = [
            entry for entry in result["cascade_promotions_skipped"]
            if entry.get("reason") == farmctl.DL089_MEASUREMENT_SIBLING_SKIP_REASON
        ]
        self.assertEqual(
            sorted((h["ea_id"], h["from_phase"], h["to_phase"]) for h in holds),
            [("QM5_41305", "Q02", "Q03"), ("QM5_41305", "Q02", "Q04")],
        )
        self.assertEqual(result["measurement_sibling_promotions_withheld"], 2)

    def test_hold_record_is_empty_when_no_sibling_exists(self) -> None:
        def seed(conn, root, make_set):
            self._insert(conn, wid="ord-q02", phase="Q02", ea_id="QM5_9997",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=make_set("ord.set"))

        result = self._run_pump(seed)["result"]
        self.assertEqual(result["measurement_sibling_promotions_withheld"], 0)
        self.assertEqual(
            [e for e in result["cascade_promotions_skipped"]
             if e.get("reason") == farmctl.DL089_MEASUREMENT_SIBLING_SKIP_REASON],
            [],
        )

    # ---- P3: the rest of the minting perimeter ----------------------------

    def test_ablation_spawners_skip_a_measurement_sibling(self) -> None:
        # Both spawners mint REAL backtests (3-8 random, 50 grid) against an
        # instrument.  Their only exclusion was the defect cohort, so all 21
        # sibling Q02 PASS rows and 13 sibling Q03 PASS rows on the live farm
        # still satisfied their predicates.
        def seed(conn, root, make_set):
            self._insert(conn, wid="sib-q02", phase="Q02", ea_id="QM5_41306",
                         symbol="WS30.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q02.set"),
                         payload={"schema": self.SCHEMA})
            self._insert(conn, wid="sib-q03", phase="Q03", ea_id="QM5_41306",
                         symbol="WS30.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q03.set"))
            self._insert(conn, wid="sib-q04", phase="Q04", ea_id="QM5_41306",
                         symbol="WS30.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q04.set"))
            # Control: an ordinary EA with the identical row shape must still
            # reach both spawners, otherwise this test would pass on a pump
            # that spawns nothing at all.
            self._insert(conn, wid="ord-q02", phase="Q02", ea_id="QM5_9998",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=make_set("ord_q02.set"))
            self._insert(conn, wid="ord-q03", phase="Q03", ea_id="QM5_9998",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=make_set("ord_q03.set"))
            self._insert(conn, wid="ord-q04", phase="Q04", ea_id="QM5_9998",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=make_set("ord_q04.set"))

        result = self._run_pump(seed)["result"]
        children = result["ablation_children"]
        self.assertEqual(
            [c for c in children if c.get("ea_id") == "QM5_41306"],
            [],
            "no spawner may select a measurement sibling",
        )
        # The ordinary EA did reach the spawners (its report may be an error
        # report -- there is no EA source tree in a temp farm -- but selection
        # is what this asserts).
        self.assertTrue([c for c in children if c.get("ea_id") == "QM5_9998"])

    def test_q08_portfolio_and_news_backfill_skip_a_sibling(self) -> None:
        root, make_set = self._farm()
        evidence = Path(self._mkdtemp()) / "aggregate.json"
        evidence.write_text('{"verdict": "PASS"}', encoding="utf-8")
        with farmctl.connect(root) as conn:
            self._insert(conn, wid="sib-q02", phase="Q02", ea_id="QM5_41161",
                         symbol="GBPUSD.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q02.set"),
                         payload={"schema": self.SCHEMA})
            self._insert(conn, wid="sib-q08", phase="Q08", ea_id="QM5_41161",
                         symbol="GBPUSD.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q08.set"),
                         evidence_path=str(evidence))
            conn.commit()
            siblings = farmctl._measurement_sibling_ea_ids(conn, root)
            self.assertEqual(sorted(siblings.ea_ids), ["QM5_41161"])

            def blank() -> dict:
                # The portfolio promoter appends into these lists without
                # setdefault, so a caller must supply them (see
                # DefectBlockExclusionTests._promote_result).
                return {
                    "q09_portfolio_promotions": [],
                    "q09_portfolio_promotions_skipped": [],
                    "q09_portfolio_admissions": [],
                }

            held = blank()
            self.assertEqual(
                farmctl._promote_q08_soft_fails_to_q09_portfolio(
                    conn, held, measurement_siblings=siblings
                ),
                0,
            )
            self.assertEqual(
                farmctl._promote_paired_q09_portfolio_passes_to_news(
                    conn, held, measurement_siblings=siblings
                ),
                0,
            )
            self.assertEqual(held.get("q09_portfolio_promotions", []), [])
            self.assertEqual(held.get("q09_paired_news_promotions", []), [])

            # Control on the SAME row: with an empty sibling set both promoters
            # mint, which is what makes the assertions above discriminating.
            empty = farmctl.MeasurementSiblingSet(())
            minted = blank()
            self.assertEqual(
                farmctl._promote_q08_soft_fails_to_q09_portfolio(
                    conn, minted, measurement_siblings=empty
                ),
                1,
            )
            self.assertEqual(
                farmctl._promote_paired_q09_portfolio_passes_to_news(
                    conn, minted, measurement_siblings=empty
                ),
                1,
            )

    def test_parent_progression_skips_a_sibling_and_passes_an_ordinary_ea(self) -> None:
        # The task-driven minting path: the pump's SQL exclusions never see it,
        # and it produced 12 of the 69 live beyond-Q02 sibling rows.
        root, make_set = self._farm()
        with farmctl.connect(root) as conn:
            self._insert(conn, wid="sib-q02", phase="Q02", ea_id="QM5_41161",
                         symbol="GBPUSD.DWX", verdict="PASS",
                         setfile_path=make_set("s.set"),
                         payload={"schema": self.SCHEMA})
            conn.execute(
                "INSERT INTO tasks (id, kind, status, payload_json,"
                " created_at, updated_at) VALUES (?,?,?,?,?,?)",
                ("q03-parent", "backtest_q03", "done",
                 json.dumps({"ea_id": "QM5_9989"}), self.STAMP, self.STAMP),
            )
            conn.commit()

        sibling = {
            "progression": {"next_phase": "Q03"},
            "parent_payload": {"ea_id": "QM5_41161"},
            "parent_task_id": "parent-1",
        }
        farmctl._auto_enqueue_parent_progression(root, sibling)
        self.assertEqual(
            sibling.get("auto_next"),
            {
                "phase": "Q03",
                "status": "skipped",
                "reason": farmctl.DL089_MEASUREMENT_SIBLING_SKIP_REASON,
            },
        )

        # An ordinary EA runs past the guard into the normal existing-task
        # branch.  Seeding that task keeps the assertion on the guard rather
        # than on enqueue_backtest's own scope policy.
        ordinary = {
            "progression": {"next_phase": "Q03"},
            "parent_payload": {"ea_id": "QM5_9989"},
            "parent_task_id": "parent-2",
        }
        farmctl._auto_enqueue_parent_progression(root, ordinary)
        self.assertEqual(
            ordinary.get("auto_next"),
            {"phase": "Q03", "task_id": "q03-parent", "status": "existing"},
        )

    def test_news_expansion_author_holds_a_sibling(self) -> None:
        root, make_set = self._farm()
        siblings = farmctl.MeasurementSiblingSet(("QM5_41161",))
        captured: list = []

        def fake_requests(connection, *, news_phases):
            captured.append(tuple(news_phases))
            return [
                {"id": "sib-news", "ea_id": "QM5_41161", "symbol": "GBPUSD.DWX",
                 "setfile_path": "s.set", "phase": farmctl._NEWS_PHASE,
                 "payload_json": "{}", "aggregate_path": None,
                 "aggregate_sha256": None, "contract_version": None,
                 "status": "done", "verdict": "REVIEW_REQUIRED",
                 "created_at": self.STAMP, "updated_at": self.STAMP},
            ]

        self._patch(farmctl.news_gate_service, "expansion_requests", fake_requests)
        report = farmctl.author_news_expansion_continuations(
            root, limit=5, apply=False, measurement_siblings=siblings
        )
        self.assertTrue(captured, "expansion_requests was not consulted")
        self.assertEqual(report.get("created", []), [])
        self.assertEqual(
            [s.get("reason") for s in report.get("skipped", [])],
            [farmctl.DL089_MEASUREMENT_SIBLING_SKIP_REASON],
        )

    # ---- P4: a blind recognizer must fail closed, loudly ------------------

    def test_a_broken_recognizer_is_a_failure_not_an_empty_set(self) -> None:
        # A DB without work_items: the seeded-Q02 recognizer cannot run.  The
        # old code swallowed this per recognizer, so a total resolution failure
        # was byte-identical to "no siblings exist".
        blind = sqlite3.connect(":memory:")
        self.addCleanup(blind.close)
        resolved = farmctl._measurement_sibling_ea_ids(blind)
        self.assertTrue(resolved.degraded)
        self.assertEqual(
            [f["reason"] for f in resolved.failures],
            # The census-consistency backstop cannot run on this DB either, and
            # says so rather than treating the empty set as a clean answer.
            ["q02_prerequisite_schema_query_failed", "census_consistency_probe_failed"],
        )
        self.assertIsNone(
            farmctl._measurement_sibling_guard(resolved, {}, site="unit")
        )

    def test_malformed_registration_receipt_degrades_and_withholds(self) -> None:
        self._write_registration("DL089_broken", None, raw="{not json")

        def seed(conn, root, make_set):
            self._insert(conn, wid="ord-q02", phase="Q02", ea_id="QM5_9993",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=make_set("ord.set"))

        run = self._run_pump(seed)
        report = run["result"]["measurement_sibling_resolution"]
        self.assertEqual(report["status"], "degraded")
        self.assertEqual(
            [f["reason"] for f in report["failures"]],
            ["matrix_registration_file_malformed"],
        )
        # Fail CLOSED: with a possibly-short set, no site mints this cycle.
        self.assertNotIn(("QM5_9993", "Q04"), run["pending"])
        blocked = {
            entry["site"] for entry in run["result"]["measurement_sibling_guard_blocks"]
        }
        self.assertEqual(
            blocked,
            {
                "pump_cascade",
                "pump_q04_early_probe",
                "pump_q08_portfolio_promoter",
                "pump_q08_news_backfill",
                "pump_ablation_random",
                "pump_ablation_grid",
                "p2_pass_promoter",
            },
        )
        for entry in run["result"]["measurement_sibling_guard_blocks"]:
            self.assertEqual(
                entry["reason"], farmctl.DL089_MEASUREMENT_SIBLING_DEGRADED_REASON
            )
        # The hold record must not claim "0 withheld" against a possibly-short
        # set, and must say so on the list an operator actually reads.
        self.assertEqual(run["result"]["measurement_sibling_promotions_withheld"], 0)
        self.assertIn(
            {
                "site": "measurement_sibling_hold_record",
                "reason": farmctl.DL089_MEASUREMENT_SIBLING_DEGRADED_REASON,
                "failures": [
                    {
                        "recognizer": "matrix_registration",
                        "reason": "matrix_registration_file_malformed",
                        "detail": failure["detail"],
                    }
                    for failure in report["failures"]
                ],
            },
            run["result"]["cascade_promotions_skipped"],
        )

    def test_empty_set_on_a_census_farm_is_degraded(self) -> None:
        # Every recognizer blind at once looks exactly like "no siblings
        # exist".  A farm that demonstrably runs a census and resolves to zero
        # siblings is therefore treated as a failure, not as a clean answer.
        root, make_set = self._farm()
        with farmctl.connect(root) as conn:
            self._insert(conn, wid="cell", phase=farmctl.OPT_CENSUS_PHASE,
                         ea_id="QM5_41304", symbol="XAGUSD.DWX",
                         verdict=farmctl.MEASURED_VERDICT,
                         setfile_path=make_set("cell.set"))
            conn.commit()
            resolved = farmctl._measurement_sibling_ea_ids(conn, root)
        self.assertTrue(resolved.degraded)
        self.assertEqual(
            [f["reason"] for f in resolved.failures],
            ["measurement_sibling_set_empty_despite_census_rows"],
        )

    def test_probe_fails_closed_and_defers_the_progression(self) -> None:
        root, make_set = self._farm()
        self._write_registration("DL089_broken", None, raw="{not json")
        payload = {
            "progression": {"next_phase": "Q03"},
            "parent_payload": {"ea_id": "QM5_9987"},
            "parent_task_id": "parent-3",
        }
        farmctl._auto_enqueue_parent_progression(root, payload)
        self.assertEqual(
            payload["auto_next"]["reason"],
            farmctl.DL089_MEASUREMENT_SIBLING_DEGRADED_REASON,
        )
        self.assertEqual(payload["auto_next"]["status"], "deferred")

    # ---- shape of the pieces ---------------------------------------------

    def test_resolution_is_a_timed_pump_stage(self) -> None:
        # It used to sit before the budget early-return and outside
        # cycle_budget.run: unbudgeted and invisible, in a function whose own
        # comments document the cascade starving on budget exhaustion.
        def seed(conn, root, make_set):
            self._insert(conn, wid="ord-q02", phase="Q02", ea_id="QM5_9986",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=make_set("ord.set"))

        stages = self._run_pump(seed)["result"]["stage_timings"]["stages"]
        named = [s for s in stages if s["name"] == "measurement_sibling_resolution"]
        self.assertEqual(len(named), 1)
        self.assertFalse(named[0]["skipped"])

    def test_probe_agrees_with_the_set_recognizer(self) -> None:
        root, make_set = self._farm()
        self._write_registration("DL089_QM5_13213", "QM5_41097")
        cards = root / "artifacts" / "cards_approved"
        self._write_card(cards, "QM5_41323", parent_ea_id="QM5_11660", sentence=True)
        self._write_card(cards, "QM5_9995", parent_ea_id="QM5_1056")
        with farmctl.connect(root) as conn:
            self._insert(conn, wid="seeded", phase="Q02", ea_id="QM5_41301",
                         symbol="XAUUSD.DWX", verdict="PASS",
                         setfile_path=make_set("s.set"),
                         payload={"schema": self.SCHEMA})
            self._insert(conn, wid="plain", phase="Q02", ea_id="QM5_9988",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=make_set("p.set"))
            conn.commit()
            by_set = farmctl._measurement_sibling_ea_ids(conn, root)
            self.assertEqual(
                sorted(by_set.ea_ids),
                ["QM5_41097", "QM5_41301", "QM5_41323"],
            )
            for ea_id in ("QM5_41301", "QM5_41097", "QM5_41323",
                          "QM5_9995", "QM5_9988", "", "not-an-ea"):
                with self.subTest(ea_id=ea_id):
                    probe = farmctl._measurement_sibling_probe(ea_id, conn, root)
                    self.assertFalse(probe.degraded)
                    self.assertEqual(probe.holds(ea_id), by_set.holds(ea_id))

    def test_exclusion_keeps_rows_whose_ea_id_is_null(self) -> None:
        # `NOT (ea IN (...))` is NULL for a NULL ea_id and a NULL WHERE term
        # drops the row, so the naive negation would silently eat unnamed rows
        # instead of keeping them. COALESCE is what makes it safe.
        conn = sqlite3.connect(":memory:")
        self.addCleanup(conn.close)
        conn.execute("CREATE TABLE work_items (id TEXT, ea_id TEXT)")
        conn.executemany(
            "INSERT INTO work_items VALUES (?,?)",
            [("unnamed", None), ("ordinary", "QM5_9995"), ("sibling", "QM5_41301")],
        )
        siblings = farmctl.MeasurementSiblingSet(("QM5_41301",))
        clause = farmctl._measurement_sibling_exclusion_clause(siblings)
        kept = [
            row[0] for row in conn.execute(
                "SELECT w.id FROM work_items w WHERE 1=1" + clause + " ORDER BY w.id"
            )
        ]
        self.assertEqual(kept, ["ordinary", "unnamed"])

    def test_exclusion_vanishes_when_the_set_is_empty(self) -> None:
        # An empty `IN ()` list is a SQLite syntax error; the clause must be "".
        self.assertEqual(
            farmctl._measurement_sibling_exclusion_clause(
                farmctl.MeasurementSiblingSet(())
            ),
            "",
        )

    def test_set_rejects_ids_that_are_not_ea_ids(self) -> None:
        # Everything downstream interpolates these into SQL as literals, so the
        # QM5_<digits> filter is a containment boundary, not cosmetics.
        siblings = farmctl.MeasurementSiblingSet(
            ("QM5_41301", "QM5_41301'); DROP TABLE work_items; --", "", "QM5_x")
        )
        self.assertEqual(sorted(siblings.ea_ids), ["QM5_41301"])

    # ---- round 3: the terminal-worker Q10_NEWS -> successor auto-enqueue ----

    def test_auto_enqueue_q10_holds_a_sibling_and_passes_an_ordinary_ea(self) -> None:
        # terminal_worker calls auto_enqueue_q10_after_q09_result on EVERY
        # _NEWS_PHASE CONFIG_LOCKED finish -- the one automatic forward path the
        # pump's SQL exclusions cannot see.  A sibling that reached _NEWS_PHASE
        # (QM5_41161 did on the live DB) must be held before its successor mint.
        root, make_set = self._farm()
        news = farmctl._NEWS_PHASE
        with farmctl.connect(root) as conn:
            # recognizer 1 fires on the seeded Q02 prerequisite row.
            self._insert(conn, wid="sib-q02", phase="Q02", ea_id="QM5_41161",
                         symbol="GBPUSD.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q02.set"),
                         payload={"schema": self.SCHEMA})
            self._insert(conn, wid="sib-news", phase=news, ea_id="QM5_41161",
                         symbol="GBPUSD.DWX", verdict="CONFIG_LOCKED",
                         setfile_path=make_set("sib_news.set"))
            self._insert(conn, wid="ord-news", phase=news, ea_id="QM5_9994",
                         symbol="EURUSD.DWX", verdict="CONFIG_LOCKED",
                         setfile_path=make_set("ord_news.set"))
            conn.commit()

        # Stub the mint so the ordinary control does not run the full Q10->Q11
        # enqueue machinery; the sentinel proves the guard passed it through.
        sentinel = {"enqueued": True, "reason": "sentinel_reached_enqueue"}
        self._patch(farmctl, "enqueue_cascade_backtest_for_ea",
                    lambda *a, **k: dict(sentinel))

        held = farmctl.auto_enqueue_q10_after_q09_result(
            root, q09_news_work_item_id="sib-news"
        )
        self.assertEqual(
            held,
            {"enqueued": False,
             "reason": farmctl.DL089_MEASUREMENT_SIBLING_SKIP_REASON},
        )
        ordinary = farmctl.auto_enqueue_q10_after_q09_result(
            root, q09_news_work_item_id="ord-news"
        )
        self.assertEqual(ordinary, sentinel)

    def test_auto_enqueue_q10_defers_on_a_blind_recognizer(self) -> None:
        # A blind recognizer must FAIL CLOSED: defer the successor mint with a
        # machine reason, never cascade against a possibly-short sibling set.
        root, make_set = self._farm()
        self._write_registration("DL089_broken", None, raw="{not json")
        news = farmctl._NEWS_PHASE
        with farmctl.connect(root) as conn:
            self._insert(conn, wid="sib-news", phase=news, ea_id="QM5_9992",
                         symbol="EURUSD.DWX", verdict="CONFIG_LOCKED",
                         setfile_path=make_set("sib_news.set"))
            conn.commit()
        self._patch(farmctl, "enqueue_cascade_backtest_for_ea",
                    lambda *a, **k: {"enqueued": True, "reason": "should_not_reach"})
        out = farmctl.auto_enqueue_q10_after_q09_result(
            root, q09_news_work_item_id="sib-news"
        )
        self.assertFalse(out["enqueued"])
        self.assertEqual(
            out["reason"], farmctl.DL089_MEASUREMENT_SIBLING_DEGRADED_REASON
        )

    # ---- round 3: the visibility pass covers ablation + q10 edges ----------

    def test_hold_record_covers_ablation_and_q10_edges(self) -> None:
        # pump_ablation_random, pump_ablation_grid and the Q10_NEWS auto-enqueue
        # are REAL minting paths, so a withheld sibling must be visible on each.
        news = farmctl._NEWS_PHASE

        def seed(conn, root, make_set):
            self._insert(conn, wid="sib-q02", phase="Q02", ea_id="QM5_41306",
                         symbol="WS30.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q02.set"),
                         payload={"schema": self.SCHEMA})
            # Q03 PASS + a surviving Q04 default probe -> a grid candidate.
            self._insert(conn, wid="sib-q03", phase="Q03", ea_id="QM5_41306",
                         symbol="WS30.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q03.set"))
            self._insert(conn, wid="sib-q04", phase="Q04", ea_id="QM5_41306",
                         symbol="WS30.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q04.set"))
            # _NEWS_PHASE CONFIG_LOCKED with no successor -> the q10 edge.
            self._insert(conn, wid="sib-news", phase=news, ea_id="QM5_41306",
                         symbol="WS30.DWX", verdict="CONFIG_LOCKED",
                         setfile_path=make_set("sib_news.set"))

        result = self._run_pump(seed)["result"]
        holds = [
            e for e in result["cascade_promotions_skipped"]
            if e.get("reason") == farmctl.DL089_MEASUREMENT_SIBLING_SKIP_REASON
        ]
        promoters = {h["promoter"] for h in holds}
        self.assertIn("pump_ablation_random", promoters)
        self.assertIn("pump_ablation_grid", promoters)
        self.assertIn("q10_news_auto_enqueue", promoters)
        # the q10 edge reports the _NEWS_PHASE row, keyed to its successor.
        q10 = [h for h in holds if h["promoter"] == "q10_news_auto_enqueue"]
        self.assertEqual(len(q10), 1)
        self.assertEqual(q10[0]["from_phase"], news)
        self.assertEqual(q10[0]["ea_id"], "QM5_41306")

    def test_grid_edge_skips_a_sibling_whose_q04_probe_has_not_survived(self) -> None:
        # The grid only spawns after the DL-074 Q04 default probe survives, so a
        # Q03 PASS with no Q04 PASS is NOT a grid candidate and must not be
        # reported as withheld-by-filter (it would over-count the hold).
        def seed(conn, root, make_set):
            self._insert(conn, wid="sib-q02", phase="Q02", ea_id="QM5_41307",
                         symbol="WS30.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q02.set"),
                         payload={"schema": self.SCHEMA})
            self._insert(conn, wid="sib-q03", phase="Q03", ea_id="QM5_41307",
                         symbol="WS30.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q03.set"))
            # no Q04 PASS row -> grid EXISTS clause is unsatisfied.

        result = self._run_pump(seed)["result"]
        grid = [
            e for e in result["cascade_promotions_skipped"]
            if e.get("promoter") == "pump_ablation_grid"
        ]
        self.assertEqual(grid, [])

    # ---- round 3: the manual stopgap hold, counted read-only ---------------

    def test_manual_chain_hold_is_counted_read_only(self) -> None:
        def seed(conn, root, make_set):
            # a recognized sibling so the pass is not degraded.
            self._insert(conn, wid="sib-q02", phase="Q02", ea_id="QM5_41306",
                         symbol="WS30.DWX", verdict="PASS",
                         setfile_path=make_set("sib_q02.set"),
                         payload={"schema": self.SCHEMA})
            for wid in ("parked-1", "parked-2"):
                self._insert(conn, wid=wid, phase="Q04", ea_id="QM5_41306",
                             symbol="WS30.DWX", verdict=None, status="pending",
                             setfile_path=make_set(wid + ".set"))
                conn.execute(
                    "INSERT INTO work_item_holds"
                    "(work_item_id, hold_code, reason, active, created_at,"
                    " updated_at) VALUES (?,?,?,1,?,?)",
                    (wid, farmctl.SIBLING_MEASUREMENT_ONLY_CHAIN_HOLD,
                     "measurement-only chain parked by hand",
                     self.STAMP, self.STAMP),
                )
            # a RELEASED hold (active=0) must not be counted.
            self._insert(conn, wid="released", phase="Q04", ea_id="QM5_41306",
                         symbol="WS30.DWX", verdict=None, status="pending",
                         setfile_path=make_set("released.set"))
            conn.execute(
                "INSERT INTO work_item_holds"
                "(work_item_id, hold_code, reason, active, created_at,"
                " updated_at) VALUES (?,?,?,0,?,?)",
                ("released", farmctl.SIBLING_MEASUREMENT_ONLY_CHAIN_HOLD,
                 "released", self.STAMP, self.STAMP),
            )

        run = self._run_pump(seed)
        report = run["result"]["measurement_sibling_manual_hold"]
        self.assertEqual(
            report["hold_code"], farmctl.SIBLING_MEASUREMENT_ONLY_CHAIN_HOLD
        )
        self.assertEqual(report["pending_rows_parked"], 2)
        self.assertEqual(report["active_holds"], 2)
        self.assertEqual(
            report["placed_at"],
            farmctl.SIBLING_MEASUREMENT_ONLY_CHAIN_HOLD_PLACED_AT,
        )
        # strictly read-only: the governed holds are untouched by the pass.
        with farmctl.connect(run["root"]) as conn:
            still_active = conn.execute(
                "SELECT COUNT(*) FROM work_item_holds"
                " WHERE hold_code=? AND active=1",
                (farmctl.SIBLING_MEASUREMENT_ONLY_CHAIN_HOLD,),
            ).fetchone()[0]
        self.assertEqual(still_active, 2)

    # ---- round 3: the hold record is a budgeted, timed pump stage ----------

    def test_hold_record_is_a_budgeted_timed_stage(self) -> None:
        # It must appear in stage_timings and carry its budget, so it cannot
        # silently starve the Q08 soft-fail promoter / news backfill after it.
        def seed(conn, root, make_set):
            self._insert(conn, wid="ord-q02", phase="Q02", ea_id="QM5_9986",
                         symbol="EURUSD.DWX", verdict="PASS",
                         setfile_path=make_set("ord.set"))

        stages = self._run_pump(seed)["result"]["stage_timings"]["stages"]
        named = [s for s in stages if s["name"] == "measurement_sibling_hold_record"]
        self.assertEqual(len(named), 1)
        self.assertFalse(named[0]["skipped"])
        self.assertEqual(
            named[0]["budget_seconds"],
            farmctl.PUMP_MEASUREMENT_SIBLING_HOLD_BUDGET_SECONDS,
        )


if __name__ == "__main__":
    unittest.main()
