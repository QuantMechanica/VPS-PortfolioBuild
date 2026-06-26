import datetime as dt
import json
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio import portfolio_manifest  # noqa: E402
from portfolio.portfolio_manifest import STATUS, STATUS_DD_CAP_FAILED, build_manifest  # noqa: E402


class PortfolioManifestTests(unittest.TestCase):
    def test_weights_risk_split_magic_and_status_are_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = common_dir / "QM" / "q08_trades"
            stream_dir.mkdir(parents=True)
            magic_registry = common_dir / "magic_numbers.csv"

            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", start, [10.0, -2.0, 3.0])
            self._write_stream(stream_dir / "100_GBPUSD_DWX.jsonl", start, [5.0, 1.0, -1.0])
            self._write_magic_registry(
                magic_registry,
                [(101, "EURUSD.DWX", 3), (100, "GBPUSD.DWX", 7)],
            )

            keys = [(101, "EURUSD.DWX"), (100, "GBPUSD.DWX")]
            # account_risk_pct=1.0 with 2 sleeves keeps each per-trade risk under the 1% cap
            # (max weight < 1.0, so weight*1.0 < 1.0) — the split still sums to account_risk_pct.
            manifest = build_manifest(
                keys,
                account_risk_pct=1.0,
                common_dir=common_dir,
                magic_registry=magic_registry,
            )

        self.assertEqual(manifest["status"], STATUS)
        self.assertEqual(manifest["n_sleeves"], 2)
        self.assertAlmostEqual(sum(manifest["weights"].values()), 1.0)
        self.assertAlmostEqual(
            sum(sleeve["set_file_expectation"]["RISK_PERCENT"] for sleeve in manifest["sleeves"]),
            1.0,
        )
        for sleeve in manifest["sleeves"]:
            self.assertLessEqual(sleeve["set_file_expectation"]["RISK_PERCENT"], 1.0)

        slots = [sleeve["slot"] for sleeve in manifest["sleeves"]]
        self.assertEqual(slots, [0, 1])
        self.assertEqual(len(slots), len(set(slots)))
        expected_slots = {"100:GBPUSD.DWX": 7, "101:EURUSD.DWX": 3}
        for sleeve in manifest["sleeves"]:
            label = f"{sleeve['ea_id']}:{sleeve['symbol']}"
            expected_slot = expected_slots[label]
            self.assertEqual(sleeve["magic_number"], sleeve["ea_id"] * 10000 + expected_slot)
            self.assertEqual(sleeve["set_file_expectation"]["ENV"], "live")
            self.assertEqual(sleeve["set_file_expectation"]["RISK_FIXED"], 0.0)
            self.assertEqual(
                sleeve["set_file_expectation"]["qm_magic_slot_offset"],
                expected_slot,
            )
        self.assertIn("sharpe", manifest["kpis"])
        self.assertIn("max_drawdown_pct", manifest["kpis"])

    def test_empty_book_returns_empty_manifest(self) -> None:
        manifest = build_manifest([], account_risk_pct=2.0)

        self.assertEqual(manifest["status"], STATUS)
        self.assertEqual(manifest["n_sleeves"], 0)
        self.assertEqual(manifest["sleeves"], [])
        self.assertEqual(manifest["weights"], {})
        self.assertEqual(manifest["kpis"]["n_sleeves"], 0)

    def test_missing_magic_registry_row_rejects_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = common_dir / "QM" / "q08_trades"
            stream_dir.mkdir(parents=True)
            magic_registry = common_dir / "magic_numbers.csv"

            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            self._write_stream(stream_dir / "100_EURUSD_DWX.jsonl", start, [1.0, 2.0])
            self._write_magic_registry(magic_registry, [(100, "GBPUSD.DWX", 0)])

            with self.assertRaisesRegex(ValueError, "no active magic registry row"):
                build_manifest(
                    [(100, "EURUSD.DWX")],
                    common_dir=common_dir,
                    magic_registry=magic_registry,
                )

    def test_selected_book_uses_risk_parity_weighting(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            candidates_db = common_dir / "farm_state.sqlite"

            with mock.patch.object(
                portfolio_manifest,
                "read_candidates",
                return_value=[(100, "EURUSD.DWX")],
            ), mock.patch.object(
                portfolio_manifest,
                "assemble_portfolio",
                return_value={
                    "selected_keys": ["100:EURUSD.DWX"],
                    "weights": {"100:EURUSD.DWX": 1.0},
                    "basis": "candidates",
                },
            ) as assemble:
                keys, weights, basis = portfolio_manifest._selected_book(
                    common_dir=common_dir,
                    candidates_db=candidates_db,
                    all_streams=False,
                    max_dd_pct=6.0,
                    starting_capital=10_000.0,
                )

        self.assertEqual(keys, [(100, "EURUSD.DWX")])
        self.assertEqual(weights, {(100, "EURUSD.DWX"): 1.0})
        self.assertEqual(basis, "candidates")
        self.assertEqual(assemble.call_args.kwargs["weighting"], "inverse_vol")

    def test_q12_ready_all_book_source_uses_all_candidates_with_risk_parity(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            candidates_db = common_dir / "farm_state.sqlite"
            ready_keys = [(10440, "NDX.DWX"), (10692, "NDX.DWX")]
            ready_weights = {
                (10440, "NDX.DWX"): 0.4,
                (10692, "NDX.DWX"): 0.6,
            }

            with mock.patch.object(
                portfolio_manifest,
                "read_candidates",
                return_value=ready_keys,
            ) as read_candidates, mock.patch.object(
                portfolio_manifest,
                "inverse_vol_weights",
                return_value=ready_weights,
            ) as inverse_vol_weights, mock.patch.object(
                portfolio_manifest,
                "assemble_portfolio",
            ) as assemble:
                keys, weights, basis = portfolio_manifest._selected_book(
                    common_dir=common_dir,
                    candidates_db=candidates_db,
                    all_streams=False,
                    book_source="q12-ready-all",
                    max_dd_pct=6.0,
                    starting_capital=10_000.0,
                )

        self.assertEqual(keys, ready_keys)
        self.assertEqual(weights, ready_weights)
        self.assertEqual(basis, "portfolio_candidates.Q12_REVIEW_READY_all")
        read_candidates.assert_called_once_with(candidates_db)
        inverse_vol_weights.assert_called_once_with(ready_keys, common_dir)
        assemble.assert_not_called()

    def test_q12_ready_all_rejects_all_streams(self) -> None:
        with self.assertRaisesRegex(ValueError, "--all-streams cannot be combined"):
            portfolio_manifest.main(["--all-streams", "--book-source", "q12-ready-all"])

    def test_main_de_levers_book_to_fit_dd_cap(self) -> None:
        # D3 (deploy-cap memo, 2026-06-26): an over-cap book is de-levered to fit, NOT
        # rejected and NOT shrunk by dropping sleeves. observed DD 12% with a 6% cap -> 0.5x.
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "manifest.json"
            manifest = {
                "status": STATUS,
                "deployment_action": "NONE",
                "account_risk_pct": 2.0,
                "n_sleeves": 1,
                "kpis": {"max_drawdown_pct": 12.0},
                "sleeves": [
                    {"ea_id": 100, "risk_percent": 2.0,
                     "set_file_expectation": {"RISK_PERCENT": 2.0}}
                ],
            }
            with mock.patch.object(
                portfolio_manifest,
                "_selected_book",
                return_value=([(100, "EURUSD.DWX")], {(100, "EURUSD.DWX"): 1.0}, "basis"),
            ), mock.patch.object(
                portfolio_manifest,
                "build_manifest",
                return_value=manifest,
            ), mock.patch.object(
                portfolio_manifest,
                "mc_build_artifact",
                side_effect=RuntimeError("no streams in test"),  # force observed-DD fallback
            ):
                rc = portfolio_manifest.main(
                    ["--out", str(out), "--max-dd-pct", "6.0", "--book-source", "q12-ready-all"]
                )

            written = json.loads(out.read_text(encoding="utf-8"))

        self.assertEqual(rc, 0)
        self.assertTrue(written["cap_met"])
        self.assertEqual(written["status"], STATUS)  # de-levered -> still owner-ready
        self.assertEqual(written["dd_basis_for_cap"], "observed")
        self.assertIn("de_levered_to_cap", written)
        self.assertAlmostEqual(written["de_levered_to_cap"]["leverage_scale"], 0.5, places=3)
        self.assertAlmostEqual(written["account_risk_pct"], 1.0, places=3)
        self.assertAlmostEqual(written["sleeves"][0]["risk_percent"], 1.0, places=3)
        self.assertAlmostEqual(
            written["sleeves"][0]["set_file_expectation"]["RISK_PERCENT"], 1.0, places=3
        )

    def test_main_rejects_only_when_no_drawdown_available(self) -> None:
        # The cap can only fail (DRAFT_REJECTED_DD_CAP) when there is NO drawdown to size on
        # (empty book / missing KPI). With a DD present the book is always de-levered to fit.
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "manifest.json"
            manifest = {
                "status": STATUS,
                "deployment_action": "NONE",
                "account_risk_pct": 2.0,
                "n_sleeves": 0,
                "kpis": {},
                "sleeves": [],
            }
            with mock.patch.object(
                portfolio_manifest,
                "_selected_book",
                return_value=([], {}, "basis"),
            ), mock.patch.object(
                portfolio_manifest,
                "build_manifest",
                return_value=manifest,
            ):
                rc = portfolio_manifest.main(
                    ["--out", str(out), "--max-dd-pct", "6.0", "--book-source", "q12-ready-all"]
                )

            written = json.loads(out.read_text(encoding="utf-8"))

        self.assertEqual(rc, 0)
        self.assertEqual(written["status"], STATUS_DD_CAP_FAILED)
        self.assertFalse(written["cap_met"])

    def test_risk_percent_capped_at_1pct_per_trade(self) -> None:
        # Hard Rule (OWNER 2026-06-26): never risk >1% per trade. A heavy sleeve at high
        # account_risk_pct must still be capped at 1% RISK_PERCENT.
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            (common_dir / "farm_state.sqlite").touch()
            with mock.patch.object(portfolio_manifest, "load_streams", return_value={}), \
                 mock.patch.object(portfolio_manifest, "load_model", return_value=mock.MagicMock(
                     degraded=False, degraded_symbols=set())), \
                 mock.patch.object(portfolio_manifest, "portfolio_metrics", return_value={"max_drawdown_pct": 1.0}), \
                 mock.patch.object(portfolio_manifest, "_load_magic_registry", return_value={}), \
                 mock.patch.object(portfolio_manifest, "_resolve_magic", return_value={"magic": 1, "symbol_slot": 0}), \
                 mock.patch.object(portfolio_manifest, "describe_model", return_value={}):
                m = portfolio_manifest.build_manifest(
                    [(100, "EURUSD.DWX"), (200, "GBPUSD.DWX")],
                    weights={(100, "EURUSD.DWX"): 0.9, (200, "GBPUSD.DWX"): 0.1},
                    account_risk_pct=4.0,  # 0.9*4=3.6% would violate without the cap
                    common_dir=common_dir,
                )
            for s in m["sleeves"]:
                self.assertLessEqual(s["risk_percent"], 1.0, s)
                self.assertLessEqual(s["set_file_expectation"]["RISK_PERCENT"], 1.0)

    def test_mc_p95_takes_conservative_max_across_methods(self) -> None:
        art = {
            "block_bootstrap": {"max_drawdown_pct": {"p95": 8.0}},
            "trade_order_shuffle": {"max_drawdown_pct": {"p95": 11.0}},
        }
        self.assertEqual(portfolio_manifest._mc_p95_max_drawdown_pct(art), 11.0)
        self.assertIsNone(portfolio_manifest._mc_p95_max_drawdown_pct({}))

    def test_apply_leverage_scale_scales_risk_keeps_weights(self) -> None:
        manifest = {
            "account_risk_pct": 2.0,
            "weights": {"100:EURUSD.DWX": 0.5},
            "sleeves": [
                {"risk_percent": 1.0, "weight": 0.5,
                 "set_file_expectation": {"RISK_PERCENT": 1.0, "PORTFOLIO_WEIGHT": 0.5}}
            ],
        }
        portfolio_manifest.apply_leverage_scale(manifest, 0.5)
        self.assertAlmostEqual(manifest["account_risk_pct"], 1.0, places=6)
        self.assertAlmostEqual(manifest["sleeves"][0]["risk_percent"], 0.5, places=6)
        self.assertAlmostEqual(
            manifest["sleeves"][0]["set_file_expectation"]["RISK_PERCENT"], 0.5, places=6
        )
        # relative weights are leverage-invariant
        self.assertEqual(manifest["sleeves"][0]["weight"], 0.5)
        self.assertEqual(manifest["sleeves"][0]["set_file_expectation"]["PORTFOLIO_WEIGHT"], 0.5)
        with self.assertRaises(ValueError):
            portfolio_manifest.apply_leverage_scale(manifest, 0.0)

    def _write_stream(
        self,
        path: Path,
        start: dt.datetime,
        daily_pnl: list[float],
    ) -> None:
        with path.open("w", encoding="utf-8") as fh:
            for offset, net in enumerate(daily_pnl):
                row = {
                    "event": "TRADE_CLOSED",
                    "time": int((start + dt.timedelta(days=offset)).timestamp()),
                    "net": net,
                    "profit": net,
                    "swap": 0.0,
                    "commission": 0.0,
                    "volume": 0.0,
                    "notional": 0.0,
                }
                fh.write(json.dumps(row, sort_keys=True) + "\n")

    def _write_magic_registry(
        self,
        path: Path,
        rows: list[tuple[int, str, int]],
    ) -> None:
        with path.open("w", encoding="utf-8") as fh:
            fh.write("ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status\n")
            for ea_id, symbol, slot in rows:
                fh.write(
                    f"{ea_id},test-ea,{slot},{symbol},{ea_id * 10000 + slot},"
                    "2026-06-26,Test,active\n"
                )


if __name__ == "__main__":
    unittest.main()
