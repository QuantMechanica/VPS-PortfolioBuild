import json
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
                       verdict, attempt_count, payload_json, created_at, updated_at)
                    VALUES
                      ('q02-pass', 'backtest', 'Q02', ?, ?, ?,
                       'done', 'PASS', 0, ?, ?, ?),
                      ('q04-infra', 'backtest', 'Q04', ?, ?, ?,
                       'done', 'INFRA_FAIL', 2, ?, ?, ?)
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
                       verdict, attempt_count, payload_json, created_at, updated_at)
                    VALUES
                      ('q02-old-pass', 'backtest', 'Q02', ?, ?, ?,
                       'done', 'PASS', 0, ?, ?, ?),
                      ('q02-new-pass', 'backtest', 'Q02', ?, ?, ?,
                       'done', 'PASS', 0, ?, ?, ?),
                      ('q04-infra', 'backtest', 'Q04', ?, ?, ?,
                       'done', 'INFRA_FAIL', 1, ?, ?, ?)
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
            try:
                farmctl.REPO_ROOT = repo_root
                farmctl.MT5_ROOT = mt5_root
                result = farmctl.pump(root)
            finally:
                farmctl.REPO_ROOT = old_repo_root
                farmctl.MT5_ROOT = old_mt5_root

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
            self.assertIn("--full-history-from", cmd)
            self.assertEqual(
                cmd[cmd.index("--full-history-from") + 1],
                farmctl.DWX_MULTI_SYMBOL_FULL_HISTORY_FROM,
            )
            self.assertNotIn("--setfile", cmd)


if __name__ == "__main__":
    unittest.main()
