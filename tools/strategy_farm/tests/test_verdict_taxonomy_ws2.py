import sqlite3
import sys
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
from framework.scripts.q08_davey import aggregate as q08_aggregate  # noqa: E402


def _memory_work_items_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE work_items (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            phase TEXT NOT NULL,
            ea_id TEXT NOT NULL,
            symbol TEXT NOT NULL,
            setfile_path TEXT NOT NULL,
            status TEXT NOT NULL,
            verdict TEXT,
            attempt_count INTEGER NOT NULL DEFAULT 0,
            parent_task_id TEXT,
            evidence_path TEXT,
            claimed_by TEXT,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            event TEXT NOT NULL,
            detail_json TEXT NOT NULL
        )
        """
    )
    return conn


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

    def test_q08_invalid_gate_report_remains_infra_fail(self) -> None:
        verdict, reason = farmctl._derive_phase_runner_verdict(
            {
                "phase": "Q08",
                "verdict": "INVALID",
                "n_trades": 3,
                "sub_gates": [
                    {"name": "8.2_dsr_mc_fdr", "status": "INVALID", "detail": "insufficient_daily_returns"}
                ],
            },
            phase="Q08",
        )
        self.assertEqual(verdict, "INFRA_FAIL")
        self.assertEqual(reason, "phase_runner_invalid_report")

    def test_q08_soft_and_hard_verdicts_are_preserved(self) -> None:
        soft, soft_reason = farmctl._derive_phase_runner_verdict(
            {"phase": "Q08", "verdict": "FAIL_SOFT", "reason": "q08_soft_fail"},
            phase="Q08",
        )
        hard, hard_reason = farmctl._derive_phase_runner_verdict(
            {"phase": "Q08", "verdict": "FAIL_HARD", "reason": "q08_hard_fail"},
            phase="Q08",
        )
        self.assertEqual((soft, soft_reason), ("FAIL_SOFT", "q08_soft_fail"))
        self.assertEqual((hard, hard_reason), ("FAIL_HARD", "q08_hard_fail"))

    def test_q08_aggregate_classifies_soft_chopping_fail(self) -> None:
        verdict, classification = q08_aggregate._aggregate_verdict(
            [
                {
                    "name": "8.6_chopping_block",
                    "status": "FAIL",
                    "detail": "pf_after_top5pct_removal=0.950:floor=1.0",
                }
            ],
            trades=[{"net": 10.0}, {"net": -5.0}],
        )
        self.assertEqual(verdict, "FAIL_SOFT")
        self.assertEqual(classification["8.6_chopping_block"], "EDGE_SOFT")

    def test_q08_aggregate_classifies_hard_pbo_fail(self) -> None:
        verdict, classification = q08_aggregate._aggregate_verdict(
            [
                {
                    "name": "8.7_pbo",
                    "status": "FAIL",
                    "detail": "PBO=88.60%:max=40%:splits=20:overfit=18",
                }
            ],
            trades=[{"net": 10.0}, {"net": -5.0}],
        )
        self.assertEqual(verdict, "FAIL_HARD")
        self.assertEqual(classification["8.7_pbo"], "EDGE_HARD")

    def test_q08_seasonal_scattered_losing_months_is_soft(self) -> None:
        # 4 SCATTERED losing months (max consecutive run = 2) -> soft (OWNER "am Stück")
        verdict, classification = q08_aggregate._aggregate_verdict(
            [{"name": "8.4_seasonal", "status": "FAIL", "detail": "losing_months:[2, 6, 8, 9]"}],
            trades=[{"net": 10.0}, {"net": -5.0}],
        )
        self.assertEqual(verdict, "FAIL_SOFT")
        self.assertEqual(classification["8.4_seasonal"], "EDGE_SOFT")

    def test_q08_seasonal_consecutive_streak_is_hard(self) -> None:
        # 4 CONSECUTIVE losing months -> sustained drawdown -> hard
        verdict, classification = q08_aggregate._aggregate_verdict(
            [{"name": "8.4_seasonal", "status": "FAIL", "detail": "losing_months:[1, 2, 3, 4]"}],
            trades=[{"net": 10.0}, {"net": -5.0}],
        )
        self.assertEqual(verdict, "FAIL_HARD")
        self.assertEqual(classification["8.4_seasonal"], "EDGE_HARD")

    def test_q08_hard_fail_dominates_invalid_gate(self) -> None:
        # a definitive hard fail wins over a single non-evaluable (INVALID) gate
        verdict, _ = q08_aggregate._aggregate_verdict(
            [
                {"name": "8.7_pbo", "status": "FAIL", "detail": "PBO=88.60%:max=40%"},
                {"name": "8.10_regime_crisis", "status": "INVALID",
                 "detail": "regime_join_failed:classified=0:unclassified=46:n_trades=46"},
            ],
            trades=[{"net": 10.0}, {"net": -5.0}],
        )
        self.assertEqual(verdict, "FAIL_HARD")

    def test_q08_regime_join_incomplete_is_low_sample(self) -> None:
        # low-trade regime-join shortfall is a sample symptom, not a final fail
        verdict, classification = q08_aggregate._aggregate_verdict(
            [{"name": "8.10_regime_crisis", "status": "INVALID",
              "detail": "regime_join_incomplete:classified=1:unclassified=2:n_timestamped=3"}],
            trades=[{"net": 10.0}, {"net": -5.0}],
        )
        self.assertEqual(verdict, "FAIL_SOFT")
        self.assertEqual(classification["8.10_regime_crisis"], "LOW_SAMPLE")

    def test_q08_fail_soft_routes_to_q09_portfolio_when_trade_count_met(self) -> None:
        conn = _memory_work_items_conn()
        try:
            conn.execute(
                """
                INSERT INTO work_items(
                    id, kind, phase, ea_id, symbol, setfile_path, status,
                    verdict, attempt_count, parent_task_id, payload_json,
                    created_at, updated_at
                )
                VALUES (
                    'q08-soft', 'backtest', 'Q08', 'QM5_10692', 'NDX.DWX',
                    'dummy.set', 'done', 'FAIL_SOFT', 1, NULL, ?,
                    '2026-06-03T00:00:00Z', '2026-06-03T00:00:00Z'
                )
                """,
                ('{"q08_n_trades": 443}',),
            )
            result = {
                "q09_portfolio_promotions": [],
                "q09_portfolio_promotions_skipped": [],
            }
            changed = farmctl._promote_q08_soft_fails_to_q09_portfolio(conn, result)
            self.assertTrue(changed)
            row = conn.execute(
                "SELECT phase, status FROM work_items WHERE phase='Q09_PORTFOLIO'"
            ).fetchone()
            self.assertIsNotNone(row)
            self.assertEqual(row["status"], "pending")
        finally:
            conn.close()

    def test_q09_portfolio_pass_enters_portfolio_candidates(self) -> None:
        conn = _memory_work_items_conn()
        try:
            conn.execute(
                """
                INSERT INTO work_items(
                    id, kind, phase, ea_id, symbol, setfile_path, status,
                    verdict, attempt_count, parent_task_id, evidence_path,
                    payload_json, created_at, updated_at
                )
                VALUES (
                    'q09-pass', 'backtest', 'Q09_PORTFOLIO', 'QM5_10692',
                    'NDX.DWX', 'dummy.set', 'done', 'PASS_PORTFOLIO', 1,
                    NULL, 'D:/QM/reports/work_items/q09-pass/aggregate.json',
                    '{}', '2026-06-03T00:00:00Z', '2026-06-03T00:00:00Z'
                )
                """
            )
            result = {"q09_portfolio_admissions": []}
            changed = farmctl._admit_q09_portfolio_passes(conn, result)
            self.assertTrue(changed)
            row = conn.execute(
                "SELECT state, evidence_path FROM portfolio_candidates WHERE ea_id='QM5_10692'"
            ).fetchone()
            self.assertIsNotNone(row)
            self.assertEqual(row["state"], "Q12_REVIEW_READY")
        finally:
            conn.close()

    def test_invalid_missing_summary_remains_infra_fail(self) -> None:
        verdict, reason = farmctl._derive_phase_runner_verdict(
            {"phase": "Q05", "verdict": "INVALID", "reason": "summary_missing"},
            phase="Q05",
        )
        self.assertEqual(verdict, "INFRA_FAIL")
        self.assertEqual(reason, "summary_missing")


if __name__ == "__main__":
    unittest.main()
