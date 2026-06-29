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
            }
            manifest_path = ea_dir / "basket_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            setfile = sets_dir / f"{ea_dir.name}_{logical}_D1_backtest.set"
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            for symbol in ("EURGBP.DWX", "EURAUD.DWX"):
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
                        "host_symbol": "EURGBP.DWX",
                        "host_timeframe": "D1",
                        "q04_latest_full_year": 2024,
                    }),
                ),
            )
            row = conn.execute("SELECT * FROM work_items").fetchone()

            cmd = farmctl._phase_runner_cmd_for_work_item(root, row, report_root, "T8")

            self.assertIsNotNone(cmd)
            self.assertIn("--latest-full-year", cmd)
            self.assertEqual(cmd[cmd.index("--latest-full-year") + 1], "2024")
            self.assertIn("--baseline-setfile", cmd)
            self.assertNotIn("--setfile", cmd)


if __name__ == "__main__":
    unittest.main()
