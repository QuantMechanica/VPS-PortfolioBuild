import json
import tempfile
import unittest
from pathlib import Path

from framework.scripts.p7_statval import run_p7_statval


class P7StatValRunnerTests(unittest.TestCase):
    def test_passes_when_all_hard_gates_pass(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "reports"
            result = run_p7_statval(
                ea_id="QM5_1001",
                symbol="EURUSD.DWX",
                output_root=out,
                trade_count=250,
                pbo_pct=3.5,
                dsr=0.21,
                mc_pvalue=0.03,
                fdr_q=0.08,
            )

            self.assertEqual(result["verdict"], "PASS")
            self.assertTrue(Path(result["evidence_path"]).exists())

    def test_fails_when_sample_size_below_threshold(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "reports"
            result = run_p7_statval(
                ea_id="QM5_1001",
                symbol="EURUSD.DWX",
                output_root=out,
                trade_count=120,
                pbo_pct=1.0,
                dsr=0.2,
                mc_pvalue=0.01,
                fdr_q=0.05,
            )

            self.assertEqual(result["verdict"], "FAIL")
            self.assertIn("T < 200", result["criterion"])


if __name__ == "__main__":
    unittest.main()
