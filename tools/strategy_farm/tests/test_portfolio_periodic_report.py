import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio import portfolio_periodic_report  # noqa: E402

# Use the exact book_build_guard module object portfolio_periodic_report bound
# at import time (it picks a dotted vs. bare import depending on __package__),
# so BookBuildRefused/GuardResult instances constructed here are recognized by
# the module-under-test's `except book_build_guard.BookBuildRefused` clause.
book_build_guard = portfolio_periodic_report.book_build_guard


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
                    guard=lambda *_args: None,
                )

        self.assertEqual(report["basis"], "q08_fail_soft_robust_pool")
        self.assertEqual(
            report["certification_scope"],
            "exploratory_q08_fail_soft_robust_pool",
        )
        self.assertFalse(report["deployment_eligible"])
        self.assertIn("Q12 deployment manifests", report["deployment_note"])
        self.assertEqual(report["concentration_tail"]["status"], "UNKNOWN")
        self.assertFalse(report["concentration_tail"]["builder_eligible"])

    def test_report_defaults_to_canonical_tester_capital(self) -> None:
        self.assertEqual(portfolio_periodic_report.DEFAULT_STARTING_CAPITAL, 100_000.0)

    def test_main_handles_book_build_refused_gracefully(self) -> None:
        # Router task 05035f17 (2026-08-24): QM_StrategyFarm_PortfolioReport
        # failed every scheduled run because a correct, fail-closed guard
        # refusal (not enough qualified pairs yet) propagated as an unhandled
        # exception instead of the graceful non-"ok" status report this script
        # already prints for every other incomplete-report case. main() must
        # exit 0 and print an informative line, not raise.
        refusal = book_build_guard.BookBuildRefused(
            book_build_guard.GuardResult(
                allowed=False,
                qualified_pairs=0,
                distinct_eas=0,
                strategy_families=0,
                order_artifact=None,
                reasons=["qualified_pairs_below_minimum: 0 < 25"],
            )
        )
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(
                portfolio_periodic_report, "build_report", side_effect=refusal
            ):
                with mock.patch.object(sys, "argv", ["portfolio_periodic_report.py"]):
                    exit_code = portfolio_periodic_report.main(
                        ["--out-dir", str(Path(tmp) / "out")]
                    )
        self.assertEqual(exit_code, 0)
        # No report files should be written on a refusal -- there is nothing
        # to write.
        self.assertFalse((Path(tmp) / "out" / "portfolio_latest.json").exists())


if __name__ == "__main__":
    unittest.main()
