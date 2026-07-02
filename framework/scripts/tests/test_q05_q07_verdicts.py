"""Verdict semantics for Q05-Q07 stress runners."""

from __future__ import annotations

import json
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from pathlib import Path

from framework.scripts import q05_stress_medium as q05
from framework.scripts import q06_stress_harsh as q06
from framework.scripts import q07_multiseed as q07


class Q05Q07VerdictTests(unittest.TestCase):
    def test_q05_parser_preserves_zero_pf_and_zero_drawdown(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            summary = Path(tmp) / "summary.json"
            summary.write_text(
                json.dumps({
                    "runs": [{
                        "profit_factor": 0,
                        "drawdown": 0,
                        "total_trades": 0,
                    }]
                }),
                encoding="utf-8",
            )

            pf, dd_money, trades = q05._parse_pf_dd_trades(summary)

        self.assertEqual(pf, 0.0)
        self.assertEqual(dd_money, 0.0)
        self.assertEqual(trades, 0)

    def test_q05_invalid_report_summary_is_not_strategy_zero_trade(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            summary = Path(tmp) / "summary.json"
            summary.write_text(
                json.dumps({
                    "result": "FAIL",
                    "reason_classes": ["NO_HISTORY", "INCOMPLETE_RUNS"],
                    "runs": [{
                        "status": "INVALID",
                        "failure": "NO_HISTORY",
                        "invalid_report_reasons": [
                            "EMPTY_EXPERT",
                            "EMPTY_SYMBOL",
                            "M0_1970_PERIOD",
                            "BARS_ZERO",
                            "HISTORY_CONTEXT_INVALID",
                        ],
                        "profit_factor": 0,
                        "drawdown": 0,
                        "total_trades": 0,
                    }],
                }),
                encoding="utf-8",
            )

            reason = q05.summary_invalid_reason(summary)

        self.assertIsNotNone(reason)
        self.assertIn("NO_HISTORY", reason)
        self.assertIn("BARS_ZERO", reason)
        self.assertIn("RUN_STATUS_INVALID", reason)

    def test_q05_pass_summary_ignores_prior_invalid_retry_attempt(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            summary = Path(tmp) / "summary.json"
            summary.write_text(
                json.dumps({
                    "result": "PASS",
                    "reason_classes": ["OK"],
                    "runs": [
                        {
                            "status": "INVALID",
                            "failure": "NO_HISTORY",
                            "invalid_report_reasons": [
                                "EMPTY_EXPERT",
                                "EMPTY_SYMBOL",
                                "M0_1970_PERIOD",
                                "BARS_ZERO",
                                "HISTORY_CONTEXT_INVALID",
                            ],
                            "profit_factor": 0,
                            "drawdown": 0,
                            "total_trades": 0,
                        },
                        {
                            "status": "OK",
                            "profit_factor": 1.1,
                            "drawdown": 3246.79,
                            "total_trades": 1410,
                        },
                    ],
                }),
                encoding="utf-8",
            )

            reason = q05.summary_invalid_reason(summary)

        self.assertIsNone(reason)

    def test_q05_valid_report_htm_fallback_extracts_metrics(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / "run_01" / "report.htm"
            report.parent.mkdir()
            report.write_text(
                """
                <html><body><table>
                <tr><td>Expert:</td><td><b>QM5_10939_grimes-context-pb</b></td></tr>
                <tr><td>Symbol:</td><td><b>GBPUSD.DWX</b></td></tr>
                <tr><td>Period:</td><td><b>H4 (2017.01.01 - 2025.12.31)</b></td></tr>
                <tr><td>Bars:</td><td><b>12608</b></td></tr>
                <tr><td>Profit Factor:</td><td><b>1.58</b></td></tr>
                <tr><td>Equity Drawdown Maximal:</td><td><b>6 190.06 (5.31%)</b></td></tr>
                <tr><td>Total Trades:</td><td><b>92</b></td></tr>
                </table></body></html>
                """,
                encoding="utf-8",
            )

            metrics = q05._latest_report_metrics(Path(tmp))

        self.assertIsNotNone(metrics)
        self.assertEqual(metrics["pf"], 1.58)
        self.assertEqual(metrics["dd_money"], 6190.06)
        self.assertEqual(metrics["trades"], 92)

    def test_q05_latest_full_year_caps_smoke_window(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "summary.json").write_text(
                json.dumps({
                    "runs": [{
                        "profit_factor": 1.2,
                        "drawdown": 500.0,
                        "total_trades": 25,
                    }]
                }),
                encoding="utf-8",
            )
            calls = []

            def fake_run(args, **_kwargs):
                calls.append(args)
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with patch.object(q05.subprocess, "run", side_effect=fake_run):
                result = q05.run_stress_backtest(
                    ea_id=12712,
                    ea_expert="QM\\QM5_12712_demo",
                    symbol="EURGBP.DWX",
                    setfile=root / "demo.set",
                    terminal="T8",
                    period="D1",
                    report_root=root,
                    latest_full_year=2024,
                )

        cmd = calls[0]
        self.assertEqual(cmd[cmd.index("-Year") + 1], "2024")
        self.assertEqual(cmd[cmd.index("-ToDate") + 1], "2024.12.31")
        self.assertEqual(result["history_to"], "2024.12.31")

    def test_q05_subprocess_timeout_records_invalid_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            timeouts = []

            def fake_run(args, **kwargs):
                timeouts.append(kwargs["timeout"])
                raise q05.subprocess.TimeoutExpired(cmd=args, timeout=kwargs["timeout"])

            with patch.object(q05.subprocess, "run", side_effect=fake_run):
                result = q05.run_stress_backtest(
                    ea_id=12532,
                    ea_expert=r"QM\QM5_12532_demo",
                    symbol="AUDUSD.DWX",
                    setfile=root / "demo.set",
                    terminal="T6",
                    period="D1",
                    report_root=root,
                    timeout_sec=30,
                    logical_symbol="QM5_12532_AUDNZD_COINTEGRATION_D1",
                )

        self.assertEqual(timeouts, [150])
        self.assertEqual(result["verdict"], "INVALID")
        self.assertIn("timeout_expired", result["reason"])
        self.assertTrue(result["timed_out"])
        self.assertEqual(result["exit_code"], 124)
        self.assertEqual(result["symbol"], "QM5_12532_AUDNZD_COINTEGRATION_D1")

    def test_q05_default_timeout_leaves_worker_headroom(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "summary.json").write_text(
                json.dumps({
                    "runs": [{
                        "profit_factor": 1.2,
                        "drawdown": 500.0,
                        "total_trades": 25,
                    }]
                }),
                encoding="utf-8",
            )
            calls = []
            timeouts = []

            def fake_run(args, **kwargs):
                calls.append(args)
                timeouts.append(kwargs["timeout"])
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with patch.object(q05.subprocess, "run", side_effect=fake_run):
                result = q05.run_stress_backtest(
                    ea_id=12532,
                    ea_expert=r"QM\QM5_12532_demo",
                    symbol="AUDUSD.DWX",
                    setfile=root / "demo.set",
                    terminal="T4",
                    period="D1",
                    report_root=root,
                )

        cmd = calls[0]
        self.assertEqual(cmd[cmd.index("-TimeoutSeconds") + 1], "5400")
        self.assertEqual(timeouts, [5520])
        self.assertEqual(result["timeout_sec"], 5400)
        self.assertEqual(result["runner_timeout_sec"], 5520)

    def test_q05_retries_windows_launch_fault_before_grading(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            summary = root / "QM5_12778" / "20260702_010101" / "summary.json"
            calls = []
            timeouts = []

            def fake_run(args, **kwargs):
                calls.append(args)
                timeouts.append(kwargs["timeout"])
                if len(calls) == 1:
                    return SimpleNamespace(returncode=3221225794, stdout="", stderr="")
                summary.parent.mkdir(parents=True)
                summary.write_text(
                    json.dumps({
                        "runs": [{
                            "profit_factor": 1.2,
                            "drawdown": 500.0,
                            "total_trades": 25,
                        }]
                    }),
                    encoding="utf-8",
                )
                return SimpleNamespace(returncode=0, stdout=f"run_smoke.summary={summary}\n", stderr="")

            with patch.object(q05.subprocess, "run", side_effect=fake_run), \
                    patch("framework.scripts._phase_utils.time.sleep") as sleep_mock:
                result = q05.run_stress_backtest(
                    ea_id=12778,
                    ea_expert=r"QM\QM5_12778_demo",
                    symbol="GBPJPY.DWX",
                    setfile=root / "demo.set",
                    terminal="T8",
                    period="D1",
                    report_root=root,
                    timeout_sec=30,
                )

        self.assertEqual(len(calls), 2)
        self.assertEqual(timeouts, [150, 150])
        sleep_mock.assert_called_once()
        self.assertEqual(result["exit_code"], 0)
        self.assertEqual(result["verdict"], "PASS")
        self.assertEqual(result["summary_path"], str(summary))

    def test_q05_final_windows_launch_fault_is_not_summary_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            calls = []

            def fake_run(args, **_kwargs):
                calls.append(args)
                return SimpleNamespace(returncode=3221225794, stdout="", stderr="")

            with patch.object(q05.subprocess, "run", side_effect=fake_run), \
                    patch("framework.scripts._phase_utils.time.sleep"):
                result = q05.run_stress_backtest(
                    ea_id=12772,
                    ea_expert=r"QM\QM5_12772_demo",
                    symbol="GBPJPY.DWX",
                    setfile=root / "demo.set",
                    terminal="T5",
                    period="D1",
                    report_root=root,
                    timeout_sec=30,
                    logical_symbol="QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1",
                )

        self.assertEqual(len(calls), 2)
        self.assertEqual(result["verdict"], "INVALID")
        self.assertEqual(result["exit_code"], 3221225794)
        self.assertIn("launch_fault", result["reason"])
        self.assertIn("0xC0000142", result["reason"])
        self.assertNotEqual(result["reason"], "summary_missing")

    def test_q05_generates_stress_setfile_in_process(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            baseline = Path(tmp) / "QM5_12772_demo_D1_backtest.set"
            baseline.write_text(
                "; environment: backtest\n"
                "; set_version: s20260701-base\n"
                "; date: 2026-07-01\n"
                "PORTFOLIO_WEIGHT=1\n",
                encoding="utf-8",
            )

            with patch.object(q05.subprocess, "run", side_effect=AssertionError("spawned")):
                out_path = q05.gen_stress_setfile_for(baseline)
            text = out_path.read_text(encoding="utf-8")

        self.assertEqual(out_path.name, "QM5_12772_demo_D1_q05_stress_medium.set")
        self.assertIn("; environment: q05_stress_medium", text)
        self.assertIn("qm_stress_reject_probability=0.0000", text)

    def test_q06_generates_stress_setfile_in_process(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            baseline = Path(tmp) / "QM5_12781_demo_D1_backtest.set"
            baseline.write_text(
                "; environment: backtest\n"
                "PORTFOLIO_WEIGHT=1\n",
                encoding="utf-8",
            )

            with patch.object(q06.subprocess, "run", side_effect=AssertionError("spawned")):
                out_path = q06.gen_harsh_setfile_for(baseline)
            text = out_path.read_text(encoding="utf-8")

        self.assertEqual(out_path.name, "QM5_12781_demo_D1_q06_stress_harsh.set")
        self.assertIn("; environment: q06_stress_harsh", text)
        self.assertIn("qm_stress_reject_probability=0.1000", text)

    def test_q05_passes_basket_manifest_tester_overrides(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ea_dir = root / "QM5_12533_demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            setfile = sets_dir / "QM5_12533_demo_LOGICAL_D1_q05_stress_medium.set"
            setfile.write_text("RISK_FIXED=150000\n", encoding="utf-8")
            (ea_dir / "basket_manifest.json").write_text(
                json.dumps({"tester_currency": "JPY", "tester_deposit": 15000000}),
                encoding="utf-8",
            )
            (root / "summary.json").write_text(
                json.dumps({
                    "runs": [{
                        "profit_factor": 1.2,
                        "drawdown": 500.0,
                        "total_trades": 25,
                    }]
                }),
                encoding="utf-8",
            )
            calls = []

            def fake_run(args, **_kwargs):
                calls.append(args)
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with patch.object(q05.subprocess, "run", side_effect=fake_run):
                result = q05.run_stress_backtest(
                    ea_id=12533,
                    ea_expert=r"QM\QM5_12533_demo",
                    symbol="EURJPY.DWX",
                    setfile=setfile,
                    terminal="T8",
                    period="D1",
                    report_root=root,
                    logical_symbol="QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1",
                )

        cmd = calls[0]
        self.assertEqual(cmd[cmd.index("-TesterCurrencyOverride") + 1], "JPY")
        self.assertEqual(cmd[cmd.index("-TesterDepositOverride") + 1], "15000000")
        self.assertEqual(result["symbol"], "QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1")
        self.assertEqual(result["runner_symbol"], "EURJPY.DWX")

    def test_q06_passes_basket_overrides_and_infers_logical_symbol(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ea_dir = root / "QM5_12533_demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            setfile = sets_dir / "QM5_12533_demo_LOGICAL_D1_q06_stress_harsh.set"
            setfile.write_text("RISK_FIXED=150000\n", encoding="utf-8")
            (ea_dir / "basket_manifest.json").write_text(
                json.dumps({
                    "logical_symbol": "QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1",
                    "host_symbol": "EURJPY.DWX",
                    "basket_symbols": ["EURJPY.DWX", "GBPJPY.DWX"],
                    "tester_currency": "JPY",
                    "tester_deposit": 15000000,
                }),
                encoding="utf-8",
            )
            (root / "summary.json").write_text(
                json.dumps({
                    "runs": [{
                        "profit_factor": 1.2,
                        "drawdown": 500.0,
                        "total_trades": 25,
                    }]
                }),
                encoding="utf-8",
            )
            calls = []
            timeouts = []

            def fake_run(args, **kwargs):
                calls.append(args)
                timeouts.append(kwargs.get("timeout"))
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with patch.object(q06.subprocess, "run", side_effect=fake_run):
                result = q06.run_harsh_backtest(
                    ea_id=12533,
                    ea_expert=r"QM\QM5_12533_demo",
                    symbol="EURJPY.DWX",
                    setfile=setfile,
                    terminal="T8",
                    period="D1",
                    report_root=root,
                )

        cmd = calls[0]
        self.assertEqual(cmd[cmd.index("-TesterCurrencyOverride") + 1], "JPY")
        self.assertEqual(cmd[cmd.index("-TesterDepositOverride") + 1], "15000000")
        self.assertEqual(cmd[cmd.index("-TimeoutSeconds") + 1], "5400")
        self.assertEqual(timeouts, [5520])
        self.assertEqual(result["symbol"], "QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1")
        self.assertEqual(result["runner_symbol"], "EURJPY.DWX")
        self.assertEqual(result["timeout_sec"], 5400)
        self.assertEqual(result["runner_timeout_sec"], 5520)

    def test_q07_missing_summary_remains_invalid(self) -> None:
        verdict, reason, _metrics = q07.evaluate_seeds([
            {"seed": 42, "pf": None, "trades": 0, "summary_path": None},
            {"seed": 17, "pf": 1.2, "trades": 25, "summary_path": "summary.json"},
        ])

        self.assertEqual(verdict, "INVALID")
        self.assertIn("seeds_missing_summary", reason)

    def test_q07_report_path_counts_as_seed_evidence(self) -> None:
        verdict, reason, metrics = q07.evaluate_seeds([
            {"seed": 42, "pf": None, "trades": 0, "summary_path": None, "report_path": "report.htm"},
            {"seed": 17, "pf": 1.2, "trades": 25, "summary_path": "summary.json"},
        ])

        self.assertEqual(verdict, "FAIL")
        self.assertIn("seed_trades_below_floor", reason)
        self.assertEqual(metrics["per_seed_trades"][0], (42, 0))

    def test_q07_zero_trade_seed_is_strategy_fail(self) -> None:
        verdict, reason, metrics = q07.evaluate_seeds([
            {"seed": 42, "pf": None, "trades": 0, "summary_path": "summary.json"},
            {"seed": 17, "pf": 1.2, "trades": 25, "summary_path": "summary.json"},
        ])

        self.assertEqual(verdict, "FAIL")
        self.assertIn("seed_trades_below_floor", reason)
        self.assertEqual(metrics["per_seed_trades"][0], (42, 0))

    def test_q07_zero_trade_seed_with_runner_failure_is_invalid(self) -> None:
        verdict, reason, metrics = q07.evaluate_seeds([
            {"seed": 42, "pf": None, "trades": 0, "summary_path": "summary.json", "exit_code": 1},
            {"seed": 17, "pf": 1.2, "trades": 25, "summary_path": "summary.json", "exit_code": 0},
        ])

        self.assertEqual(verdict, "INVALID")
        self.assertIn("seeds_invalid_evidence", reason)
        self.assertEqual(metrics["per_seed_trades"][0], (42, 0))

    def test_q07_seed_timeout_records_invalid_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            setfile = root / "demo_seed42.set"
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            timeouts = []

            def fake_run(args, **kwargs):
                timeouts.append(kwargs["timeout"])
                raise q07.subprocess.TimeoutExpired(cmd=args, timeout=kwargs["timeout"])

            with patch.object(q07.subprocess, "run", side_effect=fake_run):
                result = q07._run_seed(
                    ea_id=12781,
                    ea_expert=r"QM\QM5_12781_demo",
                    symbol="USDJPY.DWX",
                    setfile=setfile,
                    seed=42,
                    terminal="T8",
                    report_root=root,
                    timeout_sec=30,
                    period="D1",
                )

        self.assertEqual(timeouts, [150])
        self.assertTrue(result["timed_out"])
        self.assertEqual(result["exit_code"], 124)
        self.assertEqual(result["timeout_sec"], 30)
        self.assertEqual(result["runner_timeout_sec"], 150)
        self.assertIn("timeout_expired", result["invalid_reason"])

        verdict, reason, metrics = q07.evaluate_seeds([
            result,
            {"seed": 17, "pf": 1.2, "trades": 25, "summary_path": "summary.json", "exit_code": 0},
        ])
        self.assertEqual(verdict, "INVALID")
        self.assertIn("seeds_invalid_evidence", reason)
        self.assertEqual(metrics["per_seed_trades"][0], (42, 0))

    def test_q07_seed_retries_windows_launch_fault_before_grading(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            setfile = root / "demo_seed42.set"
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            seed_summary = root / "QM5_12781" / "20260702_010101" / "summary.json"
            calls = []

            def fake_run(args, **_kwargs):
                calls.append(args)
                if len(calls) == 1:
                    return SimpleNamespace(returncode=3221225794, stdout="", stderr="")
                seed_summary.parent.mkdir(parents=True)
                seed_summary.write_text(
                    json.dumps({
                        "result": "PASS",
                        "runs": [{
                            "profit_factor": 1.07,
                            "drawdown": 2287.51,
                            "total_trades": 228,
                        }]
                    }),
                    encoding="utf-8",
                )
                return SimpleNamespace(returncode=0, stdout=f"run_smoke.summary={seed_summary}\n", stderr="")

            with patch.object(q07.subprocess, "run", side_effect=fake_run), \
                    patch("framework.scripts._phase_utils.time.sleep") as sleep_mock:
                result = q07._run_seed(
                    ea_id=12781,
                    ea_expert=r"QM\QM5_12781_demo",
                    symbol="USDJPY.DWX",
                    setfile=setfile,
                    seed=42,
                    terminal="T8",
                    report_root=root,
                    timeout_sec=30,
                    period="D1",
                )

        self.assertEqual(len(calls), 2)
        sleep_mock.assert_called_once()
        self.assertEqual(result["exit_code"], 0)
        self.assertEqual(result["summary_path"], str(seed_summary))
        self.assertEqual(result["pf"], 1.07)
        self.assertEqual(result["trades"], 228)

    def test_q07_seed_run_passes_basket_tester_overrides(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ea_dir = root / "QM5_12781_demo"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            setfile = sets_dir / "QM5_12781_demo_LOGICAL_D1_q06_stress_harsh_seed42.set"
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            (ea_dir / "basket_manifest.json").write_text(
                json.dumps({"tester_currency": "USD", "tester_deposit": 100000}),
                encoding="utf-8",
            )
            (root / "summary.json").write_text(
                json.dumps({
                    "result": "FAIL",
                    "reason_classes": ["NO_HISTORY", "INCOMPLETE_RUNS"],
                    "runs": [{
                        "status": "INVALID",
                        "failure": "NO_HISTORY",
                        "invalid_report_reasons": ["EMPTY_EXPERT", "EMPTY_SYMBOL", "M0_1970_PERIOD", "BARS_ZERO"],
                        "profit_factor": 0,
                        "drawdown": 0,
                        "total_trades": 0,
                    }]
                }),
                encoding="utf-8",
            )
            seed_summary = root / "QM5_12781" / "20260701_010101" / "summary.json"
            calls = []

            def fake_run(args, **_kwargs):
                calls.append(args)
                seed_summary.parent.mkdir(parents=True)
                seed_summary.write_text(
                    json.dumps({
                        "result": "PASS",
                        "runs": [{
                            "profit_factor": 1.07,
                            "drawdown": 2287.51,
                            "total_trades": 228,
                        }]
                    }),
                    encoding="utf-8",
                )
                return SimpleNamespace(returncode=0, stdout=f"run_smoke.summary={seed_summary}\n", stderr="")

            with patch.object(q07.subprocess, "run", side_effect=fake_run):
                result = q07._run_seed(
                    ea_id=12781,
                    ea_expert=r"QM\QM5_12781_demo",
                    symbol="USDJPY.DWX",
                    setfile=setfile,
                    seed=42,
                    terminal="T8",
                    report_root=root,
                    timeout_sec=2400,
                    period="D1",
                )

        cmd = calls[0]
        self.assertEqual(cmd[cmd.index("-TesterCurrencyOverride") + 1], "USD")
        self.assertEqual(cmd[cmd.index("-TesterDepositOverride") + 1], "100000")
        self.assertEqual(result["summary_path"], str(seed_summary))
        self.assertEqual(result["pf"], 1.07)
        self.assertEqual(result["trades"], 228)


if __name__ == "__main__":
    unittest.main()
