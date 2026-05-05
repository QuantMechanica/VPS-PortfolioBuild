from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
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

    def test_ensure_expert_binary_deploys_to_all_terminals(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            ea_dir = root / "framework" / "EAs" / "QM5_1004_davey_es_breakout"
            ea_dir.mkdir(parents=True)
            src_ex5 = ea_dir / "QM5_1004_davey_es_breakout.ex5"
            src_ex5.write_bytes(b"ex5-bytes")

            t1 = root / "mt5" / "T1"
            t2 = root / "mt5" / "T2"
            for t in (t1, t2):
                (t / "MQL5" / "Experts" / "QM").mkdir(parents=True)

            p2_baseline.ensure_expert_binary_deployed(
                ea_dir=ea_dir,
                terminal_roots=[t1, t2],
            )

            self.assertEqual((t1 / "MQL5" / "Experts" / "QM" / "QM5_1004_davey_es_breakout.ex5").read_bytes(), b"ex5-bytes")
            self.assertEqual((t2 / "MQL5" / "Experts" / "QM" / "QM5_1004_davey_es_breakout.ex5").read_bytes(), b"ex5-bytes")

    def test_ensure_expert_binary_deployed_raises_when_source_missing(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            ea_dir = root / "framework" / "EAs" / "QM5_1004_davey_es_breakout"
            ea_dir.mkdir(parents=True)
            t1 = root / "mt5" / "T1"
            (t1 / "MQL5" / "Experts" / "QM").mkdir(parents=True)

            with self.assertRaises(SystemExit):
                p2_baseline.ensure_expert_binary_deployed(
                    ea_dir=ea_dir,
                    terminal_roots=[t1],
                )


if __name__ == "__main__":
    unittest.main()
