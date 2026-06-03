"""Verdict semantics for Q05-Q07 stress runners."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from framework.scripts import q05_stress_medium as q05
from framework.scripts import q07_multiseed as q07


class Q05Q07VerdictTests(unittest.TestCase):
    def test_q05_parser_preserves_zero_pf_and_zero_drawdown(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            summary = Path(tmp) / "summary.json"
            summary.write_text(
                json.dumps({
                    "runs": [{
                        "profit_factor": 0,
                        "drawdown": 0,
                        "total_trades": 0,
                    }]
                }),
                encoding="utf-8",
            )

            pf, dd_money, trades = q05._parse_pf_dd_trades(summary)

        self.assertEqual(pf, 0.0)
        self.assertEqual(dd_money, 0.0)
        self.assertEqual(trades, 0)

    def test_q07_missing_summary_remains_invalid(self) -> None:
        verdict, reason, _metrics = q07.evaluate_seeds([
            {"seed": 42, "pf": None, "trades": 0, "summary_path": None},
            {"seed": 17, "pf": 1.2, "trades": 25, "summary_path": "summary.json"},
        ])

        self.assertEqual(verdict, "INVALID")
        self.assertIn("seeds_missing_summary", reason)

    def test_q07_zero_trade_seed_is_strategy_fail(self) -> None:
        verdict, reason, metrics = q07.evaluate_seeds([
            {"seed": 42, "pf": None, "trades": 0, "summary_path": "summary.json"},
            {"seed": 17, "pf": 1.2, "trades": 25, "summary_path": "summary.json"},
        ])

        self.assertEqual(verdict, "FAIL")
        self.assertIn("seed_trades_below_floor", reason)
        self.assertEqual(metrics["per_seed_trades"][0], (42, 0))


if __name__ == "__main__":
    unittest.main()
