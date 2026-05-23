from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from framework.scripts import p3_param_sweep


class P3ParamSweepTests(unittest.TestCase):
    def test_build_param_grid_skips_missing_inputs(self) -> None:
        available = {"strategy_atr_period", "ssl1", "ssl_usd_cap"}
        axes = {
            "ssl_usd_cap": [1000, 2000],
            "strategy_atr_period": [10, 14],
            "ssl1": [1.5, 2.0],
        }
        grid = p3_param_sweep.build_param_grid(axes, available)
        self.assertEqual(len(grid), 8)
        self.assertEqual(grid[0]["ssl_usd_cap"], 1000)
        self.assertEqual(grid[0]["strategy_atr_period"], 10)
        self.assertEqual(grid[0]["ssl1"], 1.5)

    def test_write_temp_setfile_appends_overrides(self) -> None:
        with TemporaryDirectory() as tmp:
            src = Path(tmp) / "base.set"
            src.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            out_dir = Path(tmp) / "out"
            out = p3_param_sweep.write_temp_setfile(
                source=src,
                out_dir=out_dir,
                run_id="run001",
                overrides={"strategy_atr_period": 20, "ssl1": 2.5, "ssl_usd_cap": 3000},
            )
            text = out.read_text(encoding="utf-8")
            self.assertIn("strategy_atr_period=20", text)
            self.assertIn("ssl1=2.5", text)
            self.assertIn("ssl_usd_cap=3000", text)

    def test_load_completed_run_ids_reads_fail_and_pass(self) -> None:
        with TemporaryDirectory() as tmp:
            report = Path(tmp) / "report.csv"
            report.write_text(
                "ea_id,phase,symbol,period,run_id,verdict,params,summary_marker,stderr_tail\n"
                "1003,P3,AUDCHF.DWX,H1,AUDCHF.DWX_H1_001,FAIL,{},x,\n"
                "1003,P3,AUDCHF.DWX,H1,AUDCHF.DWX_H1_002,PASS,{},x,\n"
                "1003,P3,AUDCHF.DWX,H1,AUDCHF.DWX_H1_003,DRY,{},x,\n",
                encoding="utf-8",
            )
            got = p3_param_sweep.load_completed_run_ids(report)
            self.assertIn("AUDCHF.DWX_H1_001", got)
            self.assertIn("AUDCHF.DWX_H1_002", got)
            self.assertNotIn("AUDCHF.DWX_H1_003", got)

    @patch("framework.scripts.p3_param_sweep.save_dispatch_state")
    @patch("framework.scripts.p3_param_sweep.resolve_target_terminal")
    @patch("framework.scripts.p3_param_sweep.load_dispatch_state")
    def test_reserve_terminal_returns_selected_terminal(
        self,
        mock_load: unittest.mock.MagicMock,
        mock_resolve: unittest.mock.MagicMock,
        mock_save: unittest.mock.MagicMock,
    ) -> None:
        mock_load.return_value = {"dedup": {}, "running": {}}
        mock_resolve.return_value = {"status": "scheduled", "terminal": "T3"}
        got = p3_param_sweep.reserve_terminal(
            ea_id=1003,
            symbol="AUDCHF.DWX",
            period="H1",
            setfile=Path("C:/tmp/run.set"),
            state_path=Path("C:/tmp/dispatch_state.json"),
        )
        self.assertEqual(got, "T3")
        mock_save.assert_called_once()

    @patch("framework.scripts.p3_param_sweep.save_dispatch_state")
    @patch("framework.scripts.p3_param_sweep.resolve_target_terminal")
    @patch("framework.scripts.p3_param_sweep.load_dispatch_state")
    def test_reserve_terminal_returns_none_when_no_capacity(
        self,
        mock_load: unittest.mock.MagicMock,
        mock_resolve: unittest.mock.MagicMock,
        mock_save: unittest.mock.MagicMock,
    ) -> None:
        mock_load.return_value = {"dedup": {}, "running": {}}
        mock_resolve.return_value = {"status": "no_capacity", "terminal": None}
        got = p3_param_sweep.reserve_terminal(
            ea_id=1003,
            symbol="AUDCHF.DWX",
            period="H1",
            setfile=Path("C:/tmp/run.set"),
            state_path=Path("C:/tmp/dispatch_state.json"),
        )
        self.assertIsNone(got)
        mock_save.assert_called_once()

    @patch("framework.scripts.p3_param_sweep.save_dispatch_state")
    @patch("framework.scripts.p3_param_sweep.resolve_target_terminal")
    @patch("framework.scripts.p3_param_sweep.load_dispatch_state")
    def test_reserve_terminal_uses_canonical_qm5_ea_id_in_dispatch_key(
        self,
        mock_load: unittest.mock.MagicMock,
        mock_resolve: unittest.mock.MagicMock,
        mock_save: unittest.mock.MagicMock,
    ) -> None:
        mock_load.return_value = {"dedup": {}, "running": {}}
        mock_resolve.return_value = {"status": "scheduled", "terminal": "T1"}
        p3_param_sweep.reserve_terminal(
            ea_id=1003,
            symbol="AUDCHF.DWX",
            period="H1",
            setfile=Path("C:/tmp/run.set"),
            state_path=Path("C:/tmp/dispatch_state.json"),
        )
        called_job = mock_resolve.call_args.args[0]
        self.assertEqual(called_job["ea_id"], "QM5_1003")
        mock_save.assert_called_once()

    @patch("framework.scripts.p3_param_sweep.subprocess.Popen")
    def test_invoke_run_smoke_passes_p3_dispatch_identity(self, mock_popen: unittest.mock.MagicMock) -> None:
        p3_param_sweep.invoke_run_smoke(
            ea_id=1003,
            ea_expert="QM\\QM5_1003_davey_baseline_3bar",
            symbol="AUDCHF.DWX",
            year=2024,
            period="H1",
            run_id="AUDCHF.DWX_H1_001",
            setfile=Path("C:/tmp/run.set"),
            report_root=Path("D:/QM/reports/pipeline/QM5_1003/P3"),
            timeout_sec=1800,
            terminal="T1",
        )
        args = mock_popen.call_args.args[0]
        self.assertIn("-DispatchPhase", args)
        self.assertIn("P3", args)
        self.assertIn("-DispatchVersion", args)
        self.assertIn("p3_sweep", args)
        self.assertIn("-DispatchSubGateHash", args)
        self.assertIn("H1_AUDCHF.DWX_H1_001", args)


if __name__ == "__main__":
    unittest.main()
