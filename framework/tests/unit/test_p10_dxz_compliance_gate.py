import tempfile
import unittest
from pathlib import Path

from framework.scripts.p10_dxz_compliance_gate import run_p10_dxz_compliance_gate


class P10DZXComplianceGateTests(unittest.TestCase):
    def test_passes_when_drawdowns_within_limits(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "reports"
            result = run_p10_dxz_compliance_gate(
                ea_id="QM5_1001",
                symbol="EURUSD.DWX",
                output_root=out,
                daily_drawdown_pct=4.2,
                total_drawdown_pct=18.7,
            )

            self.assertEqual(result["verdict"], "PASS")
            self.assertTrue(Path(result["evidence_path"]).exists())

    def test_fails_when_daily_limit_breached(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "reports"
            result = run_p10_dxz_compliance_gate(
                ea_id="QM5_1001",
                symbol="EURUSD.DWX",
                output_root=out,
                daily_drawdown_pct=5.6,
                total_drawdown_pct=19.0,
            )

            self.assertEqual(result["verdict"], "FAIL")
            self.assertIn("daily drawdown", result["criterion"].lower())

    def test_fails_when_total_limit_breached(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "reports"
            result = run_p10_dxz_compliance_gate(
                ea_id="QM5_1001",
                symbol="EURUSD.DWX",
                output_root=out,
                daily_drawdown_pct=4.5,
                total_drawdown_pct=20.1,
            )

            self.assertEqual(result["verdict"], "FAIL")
            self.assertIn("total drawdown", result["criterion"].lower())


if __name__ == "__main__":
    unittest.main()
