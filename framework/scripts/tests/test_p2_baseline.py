from __future__ import annotations

import unittest

from framework.scripts.p2_baseline import derive_verdict


class P2BaselineGateTests(unittest.TestCase):
    def _summary(self, *, pf: float = 1.35, dd_raw: str = "123.45 (11.20%)", trades: int = 250) -> dict:
        run = {
            "profit_factor": pf,
            "drawdown_raw": dd_raw,
            "total_trades": trades,
        }
        return {
            "result": "PASS",
            "model4_log_marker_detected": True,
            "runs": [run, run.copy()],
            "report_dir": "D:/QM/reports/pipeline/QM5_1001/P2/mock",
        }

    def test_pass_when_pf_and_dd_gates_satisfied(self) -> None:
        verdict, reason, _ = derive_verdict(self._summary(), min_trades=200)
        self.assertEqual(verdict, "PASS")
        self.assertEqual(reason, "")

    def test_fail_when_profit_factor_below_gate(self) -> None:
        verdict, reason, _ = derive_verdict(self._summary(pf=1.29), min_trades=200)
        self.assertEqual(verdict, "FAIL")
        self.assertIn("pf_below_gate", reason)

    def test_fail_when_drawdown_above_gate(self) -> None:
        verdict, reason, _ = derive_verdict(self._summary(dd_raw="100.00 (12.01%)"), min_trades=200)
        self.assertEqual(verdict, "FAIL")
        self.assertIn("dd_above_gate", reason)

    def test_invalid_when_drawdown_percent_missing(self) -> None:
        verdict, reason, _ = derive_verdict(self._summary(dd_raw="100.00"), min_trades=200)
        self.assertEqual(verdict, "INVALID")
        self.assertEqual(reason, "drawdown_pct_missing")


if __name__ == "__main__":
    unittest.main()
