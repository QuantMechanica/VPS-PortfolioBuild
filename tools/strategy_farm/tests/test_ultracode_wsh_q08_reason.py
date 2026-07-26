"""ULTRACODE WS-H: Q08 insufficient-trades reason preservation in the deriver.

Codex's four acceptance cases for H:
  1. top-level INFRA_FAIL + authenticated dominant insufficient-trades -> INVALID
  2. genuine infrastructure evidence -> stays INFRA_FAIL
  3. mixed / genuine-infra sub-gate evidence -> preserves the top-level verdict
  4. missing / unauthenticated sub-gate evidence -> preserves the top-level verdict
Plus: no unrelated-phase changes; ERROR/TIMEOUT top-levels behave the same for Q08.
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


def _q08_summary(verdict: str, n_trades, sub_gates, reason: str = "") -> dict:
    s = {"phase": "Q08", "verdict": verdict, "sub_gates": sub_gates}
    if n_trades is not None:
        s["n_trades"] = n_trades
    if reason:
        s["reason"] = reason
    return s


def _sg(name: str, status: str, detail: str) -> dict:
    return {"name": name, "status": status, "detail": detail}


class WSHAcceptanceTests(unittest.TestCase):
    def derive(self, summary: dict, phase: str = "Q08"):
        return farmctl._derive_phase_runner_verdict(summary, phase=phase)

    # --- Case 1: authenticated insufficient-trades -> INVALID -------------------
    def test_case1_infra_fail_plus_insufficient_trades_becomes_invalid(self) -> None:
        summary = _q08_summary("INFRA_FAIL", 3, [
            _sg("8.1_correlation", "PASS", "ok"),
            _sg("8.9_runs_test", "INVALID", "insufficient_trade_count:got=3:need>=30"),
        ])
        verdict, reason = self.derive(summary)
        self.assertEqual(verdict, "INVALID")
        self.assertIn("q08_insufficient_trades", reason)
        self.assertIn("8.9_runs_test", reason)

    def test_case1_status_insufficient_family(self) -> None:
        summary = _q08_summary("ERROR", 2, [
            _sg("8.2_dsr", "INSUFFICIENT_DAILY_RETURNS", "got=2"),
        ])
        verdict, _ = self.derive(summary)
        self.assertEqual(verdict, "INVALID")

    def test_case1_timeout_toplevel_also_reclassifies(self) -> None:
        summary = _q08_summary("TIMEOUT", 4, [
            _sg("8.8_edge_decay", "INVALID", "insufficient_month_coverage"),
        ])
        verdict, _ = self.derive(summary)
        self.assertEqual(verdict, "INVALID")

    # --- Case 2: genuine infrastructure stays INFRA_FAIL -----------------------
    def test_case2_genuine_infra_reason_stays_infra_fail(self) -> None:
        summary = _q08_summary("INFRA_FAIL", 3, [
            _sg("8.9_runs_test", "INVALID", "insufficient_trade_count"),
        ], reason="no_real_ticks")
        self.assertEqual(self.derive(summary), ("INFRA_FAIL", "no_real_ticks"))

    def test_case2_timeout_without_subgates_stays_infra_fail(self) -> None:
        summary = _q08_summary("TIMEOUT", None, None, reason="metatester_hung")
        verdict, _ = self.derive(summary)
        self.assertEqual(verdict, "INFRA_FAIL")

    # --- Case 3: mixed evidence preserves top-level ----------------------------
    def test_case3_real_mixed_example_stays_infra_fail(self) -> None:
        # Real shape of live row 39208380 (QM5_11124/SP500): a COMPUTED 8.4 FAIL plus
        # lineage-invalid + regime-join-failed alongside an insufficient signal.
        summary = _q08_summary("INFRA_FAIL", 41, [
            _sg("8.2_dsr_mc_fdr", "INVALID", "insufficient_daily_returns:got=41:need>=60"),
            _sg("8.4_seasonal", "FAIL", "losing_months:[1, 2, 3, 4]"),
            _sg("8.7_pbo", "INVALID", "pbo_refresh_lineage_invalid:scores_or_meta_stale"),
            _sg("8.10_regime_crisis", "INVALID", "regime_join_failed:classified=0"),
        ])
        verdict, _ = self.derive(summary)
        self.assertEqual(verdict, "INFRA_FAIL")

    def test_case3_computed_fail_alone_preserves(self) -> None:
        summary = _q08_summary("INFRA_FAIL", 3, [
            _sg("8.6_chopping", "FAIL", "pf_after_top5pct_removal=0.5"),
            _sg("8.9_runs_test", "INVALID", "insufficient_trade_count"),
        ])
        self.assertEqual(self.derive(summary)[0], "INFRA_FAIL")

    def test_case3_tooling_lineage_invalid_preserves(self) -> None:
        summary = _q08_summary("INFRA_FAIL", 3, [
            _sg("8.5_neighborhood", "INVALID", "neighborhood_evidence_lineage_invalid:x"),
            _sg("8.9_runs_test", "INVALID", "insufficient_trade_count"),
        ])
        self.assertEqual(self.derive(summary)[0], "INFRA_FAIL")

    # --- Case 4: missing / unauthenticated preserves top-level -----------------
    def test_case4_no_subgates_preserves(self) -> None:
        summary = _q08_summary("INFRA_FAIL", 3, None)
        self.assertEqual(self.derive(summary)[0], "INFRA_FAIL")

    def test_case4_zero_trades_is_infra_not_insufficient(self) -> None:
        summary = _q08_summary("INFRA_FAIL", 0, [
            _sg("8.9_runs_test", "INVALID", "insufficient_trade_count"),
        ])
        self.assertEqual(self.derive(summary)[0], "INFRA_FAIL")

    def test_case4_missing_ntrades_preserves(self) -> None:
        summary = _q08_summary("INFRA_FAIL", None, [
            _sg("8.9_runs_test", "INVALID", "insufficient_trade_count"),
        ])
        self.assertEqual(self.derive(summary)[0], "INFRA_FAIL")

    # --- Scope guards: no unrelated-phase / non-infra changes ------------------
    def test_non_q08_phase_never_reclassifies(self) -> None:
        summary = _q08_summary("INFRA_FAIL", 3, [
            _sg("8.9_runs_test", "INVALID", "insufficient_trade_count"),
        ])
        summary["phase"] = "Q05"
        self.assertEqual(farmctl._derive_phase_runner_verdict(summary, phase="Q05")[0], "INFRA_FAIL")

    def test_q08_non_infra_toplevel_unaffected(self) -> None:
        # A Q08 FAIL_HARD summary is not a top-level infra verdict -> WS-H must not touch it.
        summary = _q08_summary("FAIL_HARD", 3, [
            _sg("8.9_runs_test", "INVALID", "insufficient_trade_count"),
        ])
        self.assertEqual(self.derive(summary)[0], "FAIL_HARD")

    def test_helper_returns_empty_for_preserve_cases(self) -> None:
        self.assertEqual(farmctl._q08_insufficient_trades_reason(
            {"sub_gates": None, "n_trades": 3}), "")
        self.assertEqual(farmctl._q08_insufficient_trades_reason(
            {"sub_gates": [_sg("8.9", "INVALID", "insufficient_trade_count")], "n_trades": 0}), "")


if __name__ == "__main__":
    unittest.main()
