import sys
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class P5PlusVerdictProfitCheckTests(unittest.TestCase):
    def _summary(self, *, trades: int, net_profit: float, max_drawdown_pct: float) -> dict:
        return {
            "result": "PASS",
            "model4_log_marker_detected": True,
            "runs": [
                {
                    "status": "OK",
                    "total_trades": trades,
                    "net_profit": net_profit,
                    "profit_factor": 1.2 if net_profit > 0 else 0.8,
                    "max_drawdown_pct": max_drawdown_pct,
                }
            ],
        }

    def test_p5plus_profit_and_dd_verdicts(self) -> None:
        cases = [
            {
                "name": "PASS case: profitable and dd below cap",
                "summary": self._summary(trades=10, net_profit=1250.0, max_drawdown_pct=12.0),
                "expected_verdict": "PASS",
                "expected_reason": "",
            },
            {
                "name": "STRATEGY_FAIL: unprofitable",
                "summary": self._summary(trades=10, net_profit=-1975.0, max_drawdown_pct=12.0),
                "expected_verdict": "FAIL",
                "expected_reason": "STRATEGY_UNPROFITABLE:unprofitable",
            },
            {
                "name": "DD_FAIL: drawdown exceeded",
                "summary": self._summary(trades=10, net_profit=1250.0, max_drawdown_pct=25.1),
                "expected_verdict": "FAIL",
                "expected_reason": "DD_EXCEEDED:dd_exceeded",
            },
        ]

        for case in cases:
            with self.subTest(case["name"]):
                verdict, reason = farmctl._derive_verdict_from_summary(
                    case["summary"],
                    min_trades=1,
                    phase="P5",
                )

                self.assertEqual(verdict, case["expected_verdict"])
                self.assertEqual(reason, case["expected_reason"])


if __name__ == "__main__":
    unittest.main()
