import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio import portfolio_periodic_report  # noqa: E402


class PortfolioPeriodicReportTests(unittest.TestCase):
    def test_report_declares_robust_pool_not_deployment_eligible(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(
                portfolio_periodic_report,
                "robust_pairs",
                return_value=[],
            ):
                report = portfolio_periodic_report.build_report(
                    common_dir=Path(tmp),
                    candidates_db=Path(tmp) / "farm_state.sqlite",
                    generated_at="2026-06-26T00:00:00+00:00",
                )

        self.assertEqual(report["basis"], "q08_fail_soft_robust_pool")
        self.assertEqual(
            report["certification_scope"],
            "exploratory_q08_fail_soft_robust_pool",
        )
        self.assertFalse(report["deployment_eligible"])
        self.assertIn("Q12 deployment manifests", report["deployment_note"])

    def test_report_defaults_to_canonical_tester_capital(self) -> None:
        self.assertEqual(portfolio_periodic_report.DEFAULT_STARTING_CAPITAL, 100_000.0)


if __name__ == "__main__":
    unittest.main()
