import sys
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class VerdictTaxonomyWs2Tests(unittest.TestCase):
    def test_no_real_ticks_is_infra_fail(self) -> None:
        verdict, reason = farmctl._derive_verdict_from_summary(
            {
                "result": "PASS",
                "model4_log_marker_detected": False,
                "runs": [{"total_trades": 10}],
            },
            min_trades=5,
            phase="P2",
        )
        self.assertEqual(verdict, "INFRA_FAIL")
        self.assertEqual(reason, "G1_NO_REAL_TICKS")

    def test_losing_backtest_remains_strategy_fail(self) -> None:
        verdict, reason = farmctl._derive_verdict_from_summary(
            {"result": "FAIL", "reason_classes": ["DRAWDOWN_EXCEEDED"]},
            min_trades=5,
            phase="P2",
        )
        self.assertEqual(verdict, "FAIL")
        self.assertIn("DRAWDOWN_EXCEEDED", reason)

    def test_p8_proxy_evidence_is_infra_fail(self) -> None:
        verdict, reason = farmctl._derive_phase_runner_verdict(
            {
                "phase": "P8",
                "verdict": "MODE_SELECTED",
                "details": {"parameters": {"run_mt5": False}, "mt5_mode_metrics": {}},
            },
            phase="P8",
        )
        self.assertEqual(verdict, "INFRA_FAIL")
        self.assertIn("without_real_mt5", reason)


if __name__ == "__main__":
    unittest.main()
