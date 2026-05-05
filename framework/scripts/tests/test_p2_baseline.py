from __future__ import annotations

import unittest
from pathlib import Path
from unittest.mock import patch

from framework.scripts import p2_baseline


class P2BaselineTests(unittest.TestCase):
    @patch("framework.scripts.p2_baseline.subprocess.run")
    def test_invoke_run_smoke_does_not_force_allow_running_terminal_by_default(self, mock_run) -> None:
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = "ok"
        mock_run.return_value.stderr = ""

        p2_baseline.invoke_run_smoke(
            ea_id=1003,
            symbol="EURUSD.DWX",
            year=2024,
            terminal="any",
            period="H1",
            runs=2,
            expert="QM\\QM5_1003_davey_baseline_3bar",
            setfile=Path("C:/tmp/test.set"),
            report_root=Path("D:/QM/reports/pipeline/QM5_1003/P2"),
            min_trades=20,
            timeout_sec=1800,
        )

        arglist = mock_run.call_args.args[0]
        self.assertIn("-Terminal", arglist)
        self.assertIn("any", arglist)
        self.assertNotIn("-AllowRunningTerminal", arglist)

    @patch("framework.scripts.p2_baseline.subprocess.run")
    def test_invoke_run_smoke_timeout_scales_with_runs(self, mock_run) -> None:
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = "ok"
        mock_run.return_value.stderr = ""

        p2_baseline.invoke_run_smoke(
            ea_id=1004,
            symbol="AUDCAD.DWX",
            year=2024,
            terminal="any",
            period="H1",
            runs=2,
            expert="QM\\QM5_1004_davey_es_breakout",
            setfile=Path("C:/tmp/test.set"),
            report_root=Path("D:/QM/reports/pipeline/QM5_1004/P2"),
            min_trades=20,
            timeout_sec=120,
        )

        self.assertEqual(mock_run.call_args.kwargs["timeout"], 300)


if __name__ == "__main__":
    unittest.main()
