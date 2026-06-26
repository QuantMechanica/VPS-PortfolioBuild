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
            manifest = build_manifest(
                keys,
                account_risk_pct=2.5,
                common_dir=common_dir,
                magic_registry=magic_registry,
            )

        self.assertEqual(manifest["status"], STATUS)
        self.assertEqual(manifest["n_sleeves"], 2)
        self.assertAlmostEqual(sum(manifest["weights"].values()), 1.0)
        self.assertAlmostEqual(
            sum(sleeve["set_file_expectation"]["RISK_PERCENT"] for sleeve in manifest["sleeves"]),
            2.5,
        )

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

    def test_main_marks_dd_cap_violation_not_owner_ready(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "manifest.json"
            manifest = {
                "status": STATUS,
                "deployment_action": "NONE",
                "n_sleeves": 1,
                "kpis": {"max_drawdown_pct": 13.0},
            }
            with mock.patch.object(
                portfolio_manifest,
                "_selected_book",
                return_value=([(100, "EURUSD.DWX")], {(100, "EURUSD.DWX"): 1.0}, "basis"),
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
        self.assertEqual(written["book_source"], "q12-ready-all")

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
