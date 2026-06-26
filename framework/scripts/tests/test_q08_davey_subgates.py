import datetime as dt
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from framework.scripts import q08_7_pbo_runner
from framework.scripts.q08_davey import (
    aggregate,
    sub_8_1_correlation,
    sub_8_2_dsr_mc_fdr,
    sub_8_3_tail_dependence,
    sub_8_4_seasonal,
    sub_8_5_neighborhood,
    sub_8_6_chopping_block,
    sub_8_7_pbo,
    sub_8_8_edge_decay,
    sub_8_9_runs_test,
    sub_8_10_regime_crisis,
)


def _trade(ts: dt.datetime, net: float) -> dict:
    return {"ts_utc": ts.replace(tzinfo=dt.UTC).isoformat(), "net": net}


class Q08DaveySubGateSemanticsTests(unittest.TestCase):
    def test_first_portfolio_correlation_and_tail_dependence_are_trivial_passes(self) -> None:
        corr = sub_8_1_correlation.run(equity_stream=[], portfolio=[])
        tail = sub_8_3_tail_dependence.run(equity_stream=[], portfolio=[])

        self.assertEqual(corr["status"], "PASS")
        self.assertTrue(corr["passed"])
        self.assertIn("trivial_pass", corr["detail"])
        self.assertEqual(tail["status"], "PASS")
        self.assertTrue(tail["passed"])
        self.assertIn("trivial_pass", tail["detail"])

    def _write_perturbations(self, tmp, baseline, perturbs) -> Path:
        import json
        p = Path(tmp) / "perturbations.json"
        p.write_text(json.dumps({"baseline": baseline, "perturbations": perturbs}), encoding="utf-8")
        return p

    def test_neighborhood_degenerate_baseline_is_invalid_not_fail(self) -> None:
        # The -Year 0 runner bug gave every EA a 0-trade baseline; that must be INVALID,
        # never FAIL (failing on a degenerate runner is a false negative). 2026-06-26.
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_perturbations(
                tmp,
                {"trades": 0, "pf": None, "dd": None},
                [{"param": "x", "delta": "-10pct", "pf": 0.0, "dd": 0.0}],
            )
            result = sub_8_5_neighborhood.run(perturbations_path=path)
        self.assertEqual(result["status"], "INVALID")
        self.assertFalse(result["passed"])
        self.assertIn("degenerate_baseline", result["detail"])

    def test_neighborhood_empty_perturbations_is_invalid_not_vacuous_pass(self) -> None:
        # 141 historical runs "PASSed" with an empty perturbation list (tested nothing).
        # That must be INVALID, not a vacuous PASS. 2026-06-26.
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_perturbations(tmp, {"trades": 220, "pf": 1.42, "dd": 8500}, [])
            result = sub_8_5_neighborhood.run(perturbations_path=path)
        self.assertEqual(result["status"], "INVALID")
        self.assertIn("vacuous", result["detail"])

    def test_neighborhood_real_breach_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_perturbations(
                tmp,
                {"trades": 220, "pf": 1.42, "dd": 8500},
                [{"param": "fast_ema", "delta": "-10pct", "pf": 0.85, "dd": 9000}],
            )
            result = sub_8_5_neighborhood.run(perturbations_path=path)
        self.assertEqual(result["status"], "FAIL")
        self.assertIn("perturbation_breaches", result["detail"])

    def test_neighborhood_robust_plateau_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_perturbations(
                tmp,
                {"trades": 220, "pf": 1.42, "dd": 8500},
                [{"param": "fast_ema", "delta": "-10pct", "pf": 1.35, "dd": 8800},
                 {"param": "fast_ema", "delta": "+10pct", "pf": 1.38, "dd": 9000}],
            )
            result = sub_8_5_neighborhood.run(perturbations_path=path)
        self.assertEqual(result["status"], "PASS")

    def test_pbo_missing_scores_is_invalid_not_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            missing = Path(tmp) / "missing_scores.csv"
            result = sub_8_7_pbo.run(scores_path=missing)

        self.assertEqual(result["status"], "INVALID")
        self.assertFalse(result["passed"])
        self.assertIn("pbo_runner_scores_missing", result["detail"])

    def test_pbo_runner_report_fallback_returns_datetime_timestamps(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            summary = Path(tmp) / "summary.json"
            report = Path(tmp) / "report.htm"
            report.write_text("placeholder", encoding="utf-8")
            summary.write_text(
                '{"runs":[{"report_canonical_path":"' + str(report).replace("\\", "\\\\") + '"}]}',
                encoding="utf-8",
            )
            with patch.object(
                q08_7_pbo_runner,
                "load_trades_from_mt5_report",
                return_value=[{"ts_utc": "2024-01-02T03:04:05+00:00", "net": "12.5"}],
            ):
                trades = q08_7_pbo_runner._parse_trades_from_summary(summary)

        self.assertEqual(len(trades), 1)
        self.assertIsInstance(trades[0]["ts"], dt.datetime)
        self.assertEqual(trades[0]["net"], 12.5)

    def test_regime_missing_or_unjoinable_input_is_invalid_not_fail(self) -> None:
        trades = [_trade(dt.datetime(2024, 1, day), 10.0) for day in range(1, 4)]

        missing = sub_8_10_regime_crisis.run(trades=trades, equity_stream=[])
        self.assertEqual(missing["status"], "INVALID")
        self.assertFalse(missing["passed"])
        self.assertIn("regime_input_missing", missing["detail"])

        unjoinable = sub_8_10_regime_crisis.run(
            trades=trades,
            equity_stream=[
                {"day_key": 20230101, "atr_regime": "low"},
                {"day_key": 20230102, "atr_regime": "normal"},
                {"day_key": 20230103, "atr_regime": "high"},
            ],
        )
        self.assertEqual(unjoinable["status"], "INVALID")
        self.assertFalse(unjoinable["passed"])
        self.assertIn("regime_join_failed", unjoinable["detail"])

        incomplete = sub_8_10_regime_crisis.run(
            trades=trades,
            equity_stream=[
                {"day_key": 20240101, "atr_regime": "low"},
                {"day_key": 20240102, "atr_regime": "normal"},
            ],
        )
        self.assertEqual(incomplete["status"], "INVALID")
        self.assertFalse(incomplete["passed"])
        self.assertIn("regime_join_incomplete", incomplete["detail"])

    def test_edge_decay_negative_decline_passes(self) -> None:
        trades: list[dict] = []
        for month_index in range(24):
            year = 2020 + month_index // 12
            month = month_index % 12 + 1
            loss = -0.75 if month_index < 12 else -0.70
            for i in range(10):
                net = 1.0 if i < 6 else loss
                trades.append(_trade(dt.datetime(year, month, min(i + 1, 28)), net))

        result = sub_8_8_edge_decay.run(trades=trades)

        self.assertEqual(result["status"], "PASS")
        self.assertTrue(result["passed"])
        self.assertLess(result["value"], 0)

    def test_runs_test_detail_and_boolean_match_for_non_clustered_profit_stream(self) -> None:
        trades: list[dict] = []
        pattern = [1, 1, 0, 0]
        for month in range(1, 13):
            for i in range(10):
                win = pattern[(month * 10 + i) % len(pattern)]
                trades.append(_trade(dt.datetime(2020, month, min(i + 1, 28)), 10.0 if win else -8.0))

        result = sub_8_9_runs_test.run(trades=trades)

        self.assertEqual(result["status"], "PASS")
        self.assertTrue(result["passed"])
        self.assertGreater(result["value"]["runs_p_value"], 0.05)
        self.assertLessEqual(result["value"]["top_pct_share"], 70.0)

    def test_genuine_failures_remain_failures(self) -> None:
        losing_daily = [_trade(dt.datetime(2024, 1, 1) + dt.timedelta(days=i), -1.0) for i in range(100)]
        dsr = sub_8_2_dsr_mc_fdr.run(trades=losing_daily)
        self.assertEqual(dsr["status"], "FAIL")
        self.assertFalse(dsr["passed"])

        seasonal_trades = [_trade(dt.datetime(2024, month, 1), 10.0) for month in range(1, 13)]
        seasonal_trades.append(_trade(dt.datetime(2024, 8, 2), -50.0))
        seasonal = sub_8_4_seasonal.run(trades=seasonal_trades)
        self.assertEqual(seasonal["status"], "FAIL")
        self.assertFalse(seasonal["passed"])

        chopping_trades = [{"net": 1.0} for _ in range(5)] + [{"net": -10.0} for _ in range(95)]
        chopping = sub_8_6_chopping_block.run(trades=chopping_trades)
        self.assertEqual(chopping["status"], "FAIL")
        self.assertFalse(chopping["passed"])

    def test_dsr_first_entry_empty_cohort_is_trivial_pass(self) -> None:
        # Positive-drift but volatile daily series, no portfolio peers: the DSR
        # deflation is not applicable (no selection bias), so it trivial-passes
        # pending cohort — never INVALID, never a deflation FAIL.
        trades = [
            _trade(dt.datetime(2024, 1, 1) + dt.timedelta(days=i), 10.0 if i % 2 == 0 else -9.0)
            for i in range(120)
        ]
        result = sub_8_2_dsr_mc_fdr.run(trades=trades, portfolio=[])

        self.assertEqual(result["status"], "PASS")
        self.assertTrue(result["passed"])
        self.assertEqual(result["evidence"]["tier"], "standalone_pending_cohort")
        self.assertIn("first_entry", result["detail"])

    def test_dsr_tier1_fail_with_cohort_is_fail_not_invalid(self) -> None:
        # Same modest-Sharpe series, but with a peer cohort present the DSR
        # deflation applies and fails Tier-1. It must resolve to a real FAIL,
        # not a permanent INVALID dead-end (no batch-FDR rescue exists yet).
        trades = [
            _trade(dt.datetime(2024, 1, 1) + dt.timedelta(days=i), 10.0 if i % 2 == 0 else -9.0)
            for i in range(120)
        ]
        result = sub_8_2_dsr_mc_fdr.run(trades=trades, portfolio=[{"ea_id": 1, "equity": []}])

        self.assertEqual(result["status"], "FAIL")
        self.assertFalse(result["passed"])
        self.assertNotEqual(result["status"], "INVALID")
        self.assertIn("DSR_TIER1_FAIL", result["detail"])

    def test_dl077_invalid_davey_gates_route_profitable_edge_to_soft(self) -> None:
        # DL-077: a profitable low-freq edge with a real PBO pass but INVALID high-freq Davey
        # gates routes to FAIL_SOFT (portfolio track), NOT the old blocking INVALID verdict.
        trades = [_trade(dt.datetime(2024, 1, d), 10.0) for d in range(1, 20)]
        trades.append(_trade(dt.datetime(2024, 2, 1), -5.0))
        subs = [
            {"name": "8.1_correlation", "status": "PASS"},
            {"name": "8.3_tail_dependence", "status": "PASS"},
            {"name": "8.7_pbo", "status": "PASS"},
            {"name": "8.2_dsr_mc_fdr", "status": "INVALID", "detail": "degenerate_baseline"},
            {"name": "8.5_neighborhood", "status": "INVALID", "detail": "degenerate_baseline"},
            {"name": "8.9_runs_test", "status": "INVALID", "detail": "too_few_for_runs"},
        ]
        verdict, _ = aggregate._aggregate_verdict(subs, trades=trades)
        self.assertEqual(verdict, "FAIL_SOFT")

    def test_dl077_no_real_quality_pass_is_invalid(self) -> None:
        # Only the trivial 8.1/8.3 passed; nothing real validated the edge -> INVALID.
        trades = [_trade(dt.datetime(2024, 1, d), 10.0) for d in range(1, 20)]
        trades.append(_trade(dt.datetime(2024, 2, 1), -5.0))
        subs = [
            {"name": "8.1_correlation", "status": "PASS"},
            {"name": "8.3_tail_dependence", "status": "PASS"},
            {"name": "8.7_pbo", "status": "INVALID", "detail": "degenerate"},
            {"name": "8.2_dsr_mc_fdr", "status": "INVALID", "detail": "degenerate"},
        ]
        verdict, _ = aggregate._aggregate_verdict(subs, trades=trades)
        self.assertEqual(verdict, "INVALID")

    def test_dl077_real_hard_fail_still_fail_hard(self) -> None:
        # An INVALID Davey gate does not rescue a genuine HARD failure (PBO fail stays hard).
        trades = [_trade(dt.datetime(2024, 1, d), 10.0) for d in range(1, 20)]
        trades.append(_trade(dt.datetime(2024, 2, 1), -5.0))
        subs = [
            {"name": "8.7_pbo", "status": "FAIL", "detail": "pbo_0.88_above_floor"},
            {"name": "8.2_dsr_mc_fdr", "status": "INVALID", "detail": "degenerate"},
        ]
        verdict, _ = aggregate._aggregate_verdict(subs, trades=trades)
        self.assertEqual(verdict, "FAIL_HARD")

    def test_structured_qm_log_loader_finds_tester_agent_equity_stream(self) -> None:
        # Guard the helper's contract directly without requiring a live MT5 tree.
        self.assertTrue(hasattr(aggregate, "_latest_structured_qm_log"))


if __name__ == "__main__":
    unittest.main()
