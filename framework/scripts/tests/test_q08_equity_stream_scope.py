import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from framework.scripts.q08_davey import aggregate, common


class EquityStreamPersistenceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        repo = Path(__file__).resolve().parents[3]
        cls.source = (repo / "framework/include/QM/QM_EquityStream.mqh").read_text(
            encoding="utf-8"
        )

    def test_payload_declares_account_scope(self) -> None:
        self.assertIn(r'{\"scope\":\"account\"', self.source)

    def test_live_state_namespace_and_tester_isolation_are_explicit(self) -> None:
        self.assertIn("AccountInfoInteger(ACCOUNT_LOGIN)", self.source)
        self.assertIn("g_qm_logger_ea_id", self.source)
        restore = self.source.split("bool QM_EquityStreamRestoreBaseline", 1)[1]
        restore = restore.split("bool QM_EquityStreamPersistBaseline", 1)[0]
        persist = self.source.split("bool QM_EquityStreamPersistBaseline", 1)[1]
        persist = persist.split("int QM_EquityStreamDayKey", 1)[0]
        self.assertLess(
            restore.index("MQLInfoInteger(MQL_TESTER) != 0"),
            restore.index("GlobalVariableCheck(key_name)"),
        )
        self.assertLess(
            persist.index("MQLInfoInteger(MQL_TESTER) != 0"),
            persist.index("GlobalVariableSet(equity_name, baseline)"),
        )

    def test_persistence_is_equity_first_key_last_and_validated(self) -> None:
        persist = self.source.split("bool QM_EquityStreamPersistBaseline", 1)[1]
        persist = persist.split("int QM_EquityStreamDayKey", 1)[0]
        self.assertLess(
            persist.index("GlobalVariableSet(equity_name, baseline)"),
            persist.index("GlobalVariableSet(key_name, (double)period_key)"),
        )
        self.assertIn("!MathIsValidNumber(baseline) || baseline <= 0.0", persist)
        self.assertIn("GlobalVariablesFlush();", persist)

    def test_restore_and_failure_events_are_literal_and_current_key_gated(self) -> None:
        self.assertIn('"EQUITY_STREAM_STATE_RESTORED"', self.source)
        self.assertIn('"EQUITY_STREAM_STATE_STALE_IGNORED"', self.source)
        self.assertIn('"EQUITY_STREAM_STATE_PERSIST_FAILED"', self.source)
        self.assertIn("saved_key == current_key", self.source)
        self.assertIn("MathIsValidNumber(saved_equity) && saved_equity > 0.0", self.source)


class EquityStreamScopeTests(unittest.TestCase):
    @staticmethod
    def _write_log(root: Path, rows: list[dict]) -> Path:
        path = root / "QM5_1234_ea-1234.log"
        path.write_text(
            "\n".join(json.dumps(row, separators=(",", ":")) for row in rows) + "\n",
            encoding="utf-8",
        )
        return path

    def test_symbol_filter_normalizes_legacy_scope_and_last_write_dedupes_without_sum(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            log_path = self._write_log(
                Path(tmp),
                [
                    {
                        "event": "EQUITY_SNAPSHOT",
                        "symbol": "EURUSD.DWX",
                        "payload": {
                            "day_key": 20260719,
                            "equity": 100_010.0,
                            "day_pnl": 10.0,
                            "symbol": "EURUSD.DWX",
                        },
                    },
                    {
                        "event": "EQUITY_SNAPSHOT",
                        "symbol": "XAUUSD.DWX",
                        "payload": {
                            "scope": "account",
                            "day_key": 20260719,
                            "equity": 500_000.0,
                            "day_pnl": 400_000.0,
                            "symbol": "XAUUSD.DWX",
                        },
                    },
                    {
                        "event": "EQUITY_SNAPSHOT",
                        "symbol": "EURUSD.DWX",
                        "payload": {
                            "scope": "account",
                            "day_key": 20260719,
                            "equity": 100_015.0,
                            "day_pnl": 15.0,
                            "symbol": "EURUSD.DWX",
                        },
                    },
                ],
            )

            filtered = common.load_equity_stream(log_path, symbol="EURUSD.DWX")
            all_symbols = common.load_equity_stream(log_path)

        self.assertEqual(len(filtered), 1)
        self.assertEqual(filtered[0]["scope"], "account")
        self.assertEqual(filtered[0]["equity"], 100_015.0)
        self.assertEqual(filtered[0]["day_pnl"], 15.0)
        self.assertNotEqual(filtered[0]["equity"], 100_010.0 + 500_000.0 + 100_015.0)
        self.assertEqual(
            {row["symbol"]: row["equity"] for row in all_symbols},
            {"EURUSD.DWX": 100_015.0, "XAUUSD.DWX": 500_000.0},
        )

    def test_string_payload_uses_envelope_symbol_and_filter_is_exact(self) -> None:
        payload = json.dumps({"day_key": 20260719, "equity": 100_005.0, "day_pnl": 5.0})
        with tempfile.TemporaryDirectory() as tmp:
            log_path = self._write_log(
                Path(tmp),
                [{"event": "EQUITY_SNAPSHOT", "symbol": "EURUSD.DWX", "payload": payload}],
            )
            exact = common.load_equity_stream(log_path, symbol="EURUSD.DWX")
            wrong_case = common.load_equity_stream(log_path, symbol="eurusd.dwx")

        self.assertEqual(len(exact), 1)
        self.assertEqual(exact[0]["scope"], "account")
        self.assertEqual(exact[0]["symbol"], "EURUSD.DWX")
        self.assertEqual(wrong_case, [])

    def test_aggregate_reads_basket_equity_with_physical_host_symbol(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            setfile = root / "basket_backtest.set"
            setfile.write_text("; host_symbol: GBPJPY.DWX\n", encoding="utf-8")
            log_path = root / "unused.log"

            with patch.object(aggregate.common, "load_trades_from_log", return_value=[{}]), \
                 patch.object(
                     aggregate.common,
                     "load_equity_stream",
                     side_effect=RuntimeError("stop_after_equity_symbol_capture"),
                 ) as loader:
                with self.assertRaisesRegex(RuntimeError, "stop_after_equity_symbol_capture"):
                    aggregate.run_all(
                        1234,
                        "GBPJPY_AUDJPY_BASKET",
                        log_path,
                        baseline_setfile=setfile,
                    )

        loader.assert_called_once_with(log_path, symbol="GBPJPY.DWX")


if __name__ == "__main__":
    unittest.main()
