from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

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


if __name__ == "__main__":
    unittest.main()
