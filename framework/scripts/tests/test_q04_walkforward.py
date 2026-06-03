"""Tests for framework/scripts/q04_walkforward.py."""

from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "q04_walkforward.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("q04_walkforward", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Q04WalkForwardTests(unittest.TestCase):
    def test_run_fold_allows_worker_owned_terminal_and_logs_summary(self) -> None:
        mod = _load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            setfile = root / "QM5_1001_EURUSD.DWX_H1_backtest.set"
            setfile.write_text("InpFoo=1\n", encoding="utf-8")
            summary = root / "summary.json"
            summary.write_text("{}", encoding="utf-8")
            captured = {}

            def fake_run(args, **kwargs):
                captured["args"] = args
                kwargs["stdout"].write(f"run_smoke.summary={summary}\n")
                return subprocess.CompletedProcess(args, 1)

            with mock.patch.object(subprocess, "run", side_effect=fake_run):
                result = mod.run_fold_via_smoke(
                    ea_id=1001,
                    ea_expert=r"QM\QM5_1001_test",
                    symbol="EURUSD.DWX",
                    setfile=setfile,
                    fold={
                        "id": "F1",
                        "dev_start": "2017-01-01",
                        "dev_end": "2022-12-31",
                        "oos_start": "2023-01-01",
                        "oos_end": "2023-12-31",
                    },
                    report_root=root / "reports",
                    terminal="T6",
                    period="H1",
                    timeout_sec=60,
                )

            args = captured["args"]
            self.assertIn("-AllowRunningTerminal", args)
            self.assertIn("-AllowMissingRealTicksLogMarker", args)
            self.assertEqual(args[args.index("-FromDate") + 1], "2023.01.01")
            self.assertEqual(args[args.index("-ToDate") + 1], "2023.12.31")
            self.assertEqual(result["summary_path"], str(summary))
            self.assertTrue(Path(result["log_path"]).exists())

    def test_incomplete_fold_is_invalid_not_strategy_fail(self) -> None:
        mod = _load_module()
        verdict, reason = mod.aggregate_verdict([
            {"id": "F1", "exit_code": 1, "summary_path": None, "pf_net": None, "trades": 0},
            {"id": "F2", "exit_code": 1, "summary_path": None, "pf_net": None, "trades": 0},
            {"id": "F3", "exit_code": 1, "summary_path": None, "pf_net": None, "trades": 0},
        ])

        self.assertEqual(verdict, "INVALID")
        self.assertIn("incomplete_fold", reason)

    def test_completed_low_pf_fold_remains_strategy_fail(self) -> None:
        mod = _load_module()
        verdict, reason = mod.aggregate_verdict([
            {"id": "F1", "exit_code": 1, "summary_path": "summary.json", "pf_net": 0.9, "trades": 20},
            {"id": "F2", "exit_code": 1, "summary_path": "summary.json", "pf_net": 1.2, "trades": 22},
            {"id": "F3", "exit_code": 1, "summary_path": "summary.json", "pf_net": 1.1, "trades": 18},
        ])

        self.assertEqual(verdict, "FAIL")
        self.assertIn("F1:pf_net=0.9", reason)

    def test_completed_zero_trade_fold_is_strategy_fail(self) -> None:
        mod = _load_module()
        verdict, reason = mod.aggregate_verdict([
            {"id": "F1", "exit_code": 1, "summary_path": "summary.json", "pf_net": None, "trades": 0},
            {"id": "F2", "exit_code": 1, "summary_path": "summary.json", "pf_net": 0.8, "trades": 12},
            {"id": "F3", "exit_code": 1, "summary_path": "summary.json", "pf_net": 1.1, "trades": 10},
        ])

        self.assertEqual(verdict, "FAIL")
        self.assertIn("F1:trades=0", reason)


if __name__ == "__main__":
    unittest.main()
