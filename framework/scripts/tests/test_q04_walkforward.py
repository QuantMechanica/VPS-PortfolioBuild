"""Tests for framework/scripts/q04_walkforward.py."""

from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "q04_walkforward.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("q04_walkforward", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Q04CommissionFallbackTests(unittest.TestCase):
    """OWNER 2026-06-26: the EA-side flat fallback must grade at the realistic per-class rate
    (forex $5 / index $5.5 / commodity $0), not a blanket $7 that over-charged FX ~40%."""

    def test_per_class_fallback_rates(self) -> None:
        mod = _load_module()
        self.assertEqual(mod._ea_side_sim_commission_per_lot("EURUSD.DWX"), 5.0)
        self.assertEqual(mod._ea_side_sim_commission_per_lot("GBPJPY.DWX"), 5.0)
        self.assertEqual(mod._ea_side_sim_commission_per_lot("NDX.DWX"), 5.5)
        self.assertEqual(mod._ea_side_sim_commission_per_lot("XAUUSD.DWX"), 0.0)

    def test_unknown_symbol_falls_back_to_conservative_constant(self) -> None:
        mod = _load_module()
        # unknown symbol -> default class (forex) -> registry flat, still NOT the blanket $7
        self.assertEqual(mod._ea_side_sim_commission_per_lot("ZZZUSD.DWX"), 5.0)


class Q04WalkForwardTests(unittest.TestCase):
    def test_stream_pf_cannot_override_losing_native_report(self) -> None:
        mod = _load_module()

        pf, trades, basis, reason = mod.guard_pf_net_against_report_summary(
            pf_net=6.207,
            trades=399,
            commission_basis="worst_case_dxz_ftmo_notional",
            report_pf=0.69,
            report_trades=434,
        )

        self.assertEqual(pf, 0.69)
        self.assertEqual(trades, 434)
        self.assertEqual(basis, "native_report_guard_fallback")
        self.assertIn("trade_count_mismatch", reason)
        self.assertIn("pf_contradicts_report", reason)

    def test_matching_stream_keeps_commission_model_pf(self) -> None:
        mod = _load_module()

        pf, trades, basis, reason = mod.guard_pf_net_against_report_summary(
            pf_net=1.12,
            trades=240,
            commission_basis="worst_case_dxz_ftmo_notional",
            report_pf=1.10,
            report_trades=240,
        )

        self.assertEqual(pf, 1.12)
        self.assertEqual(trades, 240)
        self.assertEqual(basis, "worst_case_dxz_ftmo_notional")
        self.assertIsNone(reason)

    def test_report_missing_summary_is_invalid_evidence(self) -> None:
        mod = _load_module()
        with tempfile.TemporaryDirectory() as tmp:
            summary = Path(tmp) / "summary.json"
            summary.write_text(
                """
                {
                  "result": "FAIL",
                  "reason_classes": ["REPORT_MISSING", "METATESTER_HUNG", "INCOMPLETE_RUNS"],
                  "runs": [{
                    "status": "FAIL",
                    "failure": "REPORT_MISSING",
                    "total_trades": 0
                  }]
                }
                """,
                encoding="utf-8",
            )

            reason = mod.summary_invalid_reason(summary)

        self.assertIsNotNone(reason)
        self.assertIn("REPORT_MISSING", reason)
        self.assertIn("INCOMPLETE_RUNS", reason)

    def test_pass_summary_ignores_failed_retry_attempts(self) -> None:
        mod = _load_module()
        with tempfile.TemporaryDirectory() as tmp:
            summary = Path(tmp) / "summary.json"
            summary.write_text(
                """
                {
                  "result": "PASS",
                  "reason_classes": ["OK"],
                  "runs": [
                    {
                      "status": "INVALID",
                      "failure": "NO_HISTORY",
                      "invalid_report_reasons": [
                        "EMPTY_EXPERT",
                        "EMPTY_SYMBOL",
                        "M0_1970_PERIOD",
                        "BARS_ZERO",
                        "HISTORY_CONTEXT_INVALID"
                      ],
                      "total_trades": 0
                    },
                    {
                      "status": "OK",
                      "total_trades": 34,
                      "profit_factor": 1.02,
                      "net_profit": 80.37
                    }
                  ]
                }
                """,
                encoding="utf-8",
            )

            reason = mod.summary_invalid_reason(summary)

        self.assertIsNone(reason)

    def test_run_fold_allows_worker_owned_terminal_and_logs_summary(self) -> None:
        mod = _load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            setfile = root / "QM5_1001_EURUSD.DWX_H1_backtest.set"
            setfile.write_text("InpFoo=1\n", encoding="utf-8")
            summary = root / "summary.json"
            summary.write_text("{}", encoding="utf-8")
            captured = {}

            def fake_run(args, **kwargs):
                captured["args"] = args
                kwargs["stdout"].write(f"run_smoke.summary={summary}\n")
                return subprocess.CompletedProcess(args, 1)

            with mock.patch.object(subprocess, "run", side_effect=fake_run):
                result = mod.run_fold_via_smoke(
                    ea_id=1001,
                    ea_expert=r"QM\QM5_1001_test",
                    symbol="EURUSD.DWX",
                    setfile=setfile,
                    fold={
                        "id": "F1",
                        "dev_start": "2017-01-01",
                        "dev_end": "2022-12-31",
                        "oos_start": "2023-01-01",
                        "oos_end": "2023-12-31",
                    },
                    report_root=root / "reports",
                    terminal="T6",
                    period="H1",
                    timeout_sec=60,
                )

            args = captured["args"]
            self.assertIn("-AllowRunningTerminal", args)
            self.assertIn("-AllowMissingRealTicksLogMarker", args)
            self.assertEqual(args[args.index("-FromDate") + 1], "2023.01.01")
            self.assertEqual(args[args.index("-ToDate") + 1], "2023.12.31")
            self.assertEqual(result["summary_path"], str(summary))
            self.assertTrue(Path(result["log_path"]).exists())

    def test_run_fold_passes_basket_manifest_tester_overrides(self) -> None:
        mod = _load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ea_dir = root / "framework" / "EAs" / "QM5_12533_test"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            setfile = sets_dir / "QM5_12533_test_LOGICAL_D1_backtest.set"
            setfile.write_text("InpFoo=1\n", encoding="utf-8")
            (ea_dir / "basket_manifest.json").write_text(
                '{"tester_currency":"JPY","tester_deposit":15000000}',
                encoding="utf-8",
            )
            summary = root / "summary.json"
            summary.write_text("{}", encoding="utf-8")
            captured = {}

            def fake_run(args, **kwargs):
                captured["args"] = args
                kwargs["stdout"].write(f"run_smoke.summary={summary}\n")
                return subprocess.CompletedProcess(args, 1)

            with mock.patch.object(subprocess, "run", side_effect=fake_run):
                mod.run_fold_via_smoke(
                    ea_id=12533,
                    ea_expert=r"QM\QM5_12533_test",
                    symbol="EURJPY.DWX",
                    setfile=setfile,
                    fold={
                        "id": "F1",
                        "dev_start": "2017-01-01",
                        "dev_end": "2022-12-31",
                        "oos_start": "2023-01-01",
                        "oos_end": "2023-12-31",
                    },
                    report_root=root / "reports",
                    terminal="T10",
                    period="D1",
                    timeout_sec=60,
                )

            args = captured["args"]
            self.assertEqual(args[args.index("-TesterCurrencyOverride") + 1], "JPY")
            self.assertEqual(args[args.index("-TesterDepositOverride") + 1], "15000000")

    def test_incomplete_fold_is_invalid_not_strategy_fail(self) -> None:
        mod = _load_module()
        verdict, reason = mod.aggregate_verdict([
            {"id": "F1", "exit_code": 1, "summary_path": None, "pf_net": None, "trades": 0},
            {"id": "F2", "exit_code": 1, "summary_path": None, "pf_net": None, "trades": 0},
            {"id": "F3", "exit_code": 1, "summary_path": None, "pf_net": None, "trades": 0},
        ])

        self.assertEqual(verdict, "INVALID")
        self.assertIn("incomplete_fold", reason)

    def test_invalid_fold_summary_is_invalid_not_strategy_fail(self) -> None:
        mod = _load_module()
        verdict, reason = mod.aggregate_verdict([
            {"id": "F1", "summary_path": "summary.json", "pf_net": 1.4, "trades": 11},
            {
                "id": "F2",
                "summary_path": "summary.json",
                "invalid_reason": "invalid_summary:REPORT_MISSING,INCOMPLETE_RUNS",
                "pf_net": None,
                "trades": 0,
            },
            {"id": "F3", "summary_path": "summary.json", "pf_net": 0.4, "trades": 16},
        ])

        self.assertEqual(verdict, "INVALID")
        self.assertIn("F2:invalid_summary", reason)

    def test_completed_low_pf_fold_remains_strategy_fail(self) -> None:
        mod = _load_module()
        verdict, reason = mod.aggregate_verdict([
            {"id": "F1", "exit_code": 1, "summary_path": "summary.json", "pf_net": 0.9, "trades": 20},
            {"id": "F2", "exit_code": 1, "summary_path": "summary.json", "pf_net": 1.2, "trades": 22},
            {"id": "F3", "exit_code": 1, "summary_path": "summary.json", "pf_net": 1.1, "trades": 18},
        ])

        self.assertEqual(verdict, "FAIL")
        self.assertIn("F1:pf_net=0.9", reason)

    def test_pass_soft_exits_successfully(self) -> None:
        mod = _load_module()
        verdict, reason = mod.aggregate_verdict([
            {"id": "F1", "summary_path": "summary.json", "pf_net": 0.91, "trades": 22},
            {"id": "F2", "summary_path": "summary.json", "pf_net": 1.12, "trades": 26},
            {"id": "F3", "summary_path": "summary.json", "pf_net": 74.31, "trades": 2},
        ])

        self.assertEqual(verdict, "PASS_SOFT")
        self.assertIn("soft:", reason)
        self.assertEqual(mod.exit_code_for_verdict(verdict), 0)

    def test_completed_zero_trade_fold_is_strategy_fail(self) -> None:
        mod = _load_module()
        verdict, reason = mod.aggregate_verdict([
            {"id": "F1", "exit_code": 1, "summary_path": "summary.json", "pf_net": None, "trades": 0},
            {"id": "F2", "exit_code": 1, "summary_path": "summary.json", "pf_net": 0.8, "trades": 12},
            {"id": "F3", "exit_code": 1, "summary_path": "summary.json", "pf_net": 1.1, "trades": 10},
        ])

        self.assertEqual(verdict, "FAIL")
        self.assertIn("F1:trades=0", reason)


class Q04LowFreqTests(unittest.TestCase):
    """DL-076 low-freq pooled rescue."""

    @staticmethod
    def _fold(fid, trades, nets, completed=True):
        return {"id": fid, "summary_path": "summary.json" if completed else None,
                "trades": trades, "oos_nets": nets}

    def test_eligibility_low_vs_high_frequency(self):
        mod = _load_module()
        # 3 folds, 9 trades total = 3/yr → eligible (< 15/yr)
        low = [self._fold("F1", 3, [1, 1, -1]), self._fold("F2", 3, [1, 1, -1]),
               self._fold("F3", 3, [1, 1, -1])]
        self.assertTrue(mod.is_lowfreq_eligible(low))
        # 60 trades total = 20/yr → NOT eligible (strict gate stays)
        high = [self._fold("F1", 20, [1] * 20), self._fold("F2", 20, [1] * 20),
                self._fold("F3", 20, [1] * 20)]
        self.assertFalse(mod.is_lowfreq_eligible(high))
        # an incomplete fold is never reclassified as low-freq
        incomplete = [self._fold("F1", 3, [1]), self._fold("F2", 0, [], completed=False),
                      self._fold("F3", 3, [1])]
        self.assertFalse(mod.is_lowfreq_eligible(incomplete))

    def test_pooled_pass_when_thin_years_pool_to_real_edge(self):
        mod = _load_module()
        # each year thin & one losing year (strict FAIL), but pooled is clearly profitable.
        # OWNER 2026-06-26 floor = 5/yr * 3 OOS years = 15 pooled trades; this pools to 16.
        folds = [self._fold("F1", 6, [3, 3, 3, -1, -1, 1]),  # +8
                 self._fold("F2", 5, [-1, -1, 2, 1, 1]),      # +2, a weak year
                 self._fold("F3", 5, [2, 2, 2, -1, -1])]      # +4
        verdict, reason = mod.aggregate_verdict_lowfreq(folds)
        self.assertEqual(verdict, "PASS_LOWFREQ")
        self.assertIn("pool:pf_net=", reason)

    def test_single_year_wonder_fails(self):
        mod = _load_module()
        # all the edge is in one year; other two had zero trades → robustness guard fails.
        # 16 pooled trades clears the 15-trade (5/yr) floor so the active-years guard bites.
        folds = [self._fold("F1", 16, [5] * 12 + [-1] * 4),
                 self._fold("F2", 0, []),
                 self._fold("F3", 0, [])]
        verdict, reason = mod.aggregate_verdict_lowfreq(folds)
        self.assertEqual(verdict, "FAIL")
        self.assertIn("single_year_wonder", reason)

    def test_insufficient_pooled_trades_is_invalid(self):
        mod = _load_module()
        # 6 pooled < 15 (5/yr * 3 OOS years) → INVALID, never a free pass
        folds = [self._fold("F1", 2, [1, 1]), self._fold("F2", 2, [1, -1]),
                 self._fold("F3", 2, [1, 1])]
        verdict, reason = mod.aggregate_verdict_lowfreq(folds)
        self.assertEqual(verdict, "INVALID")
        self.assertIn("insufficient_pooled_trades", reason)

    def test_below_oos_rate_floor_is_invalid(self):
        mod = _load_module()
        # 4/yr sustained (12 pooled) used to PASS_LOWFREQ; OWNER's 5/yr OOS bar now rejects it.
        folds = [self._fold("F1", 4, [2, 2, -1, 1]),
                 self._fold("F2", 4, [2, 2, -1, 1]),
                 self._fold("F3", 4, [2, 2, -1, 1])]  # 12 pooled < 15 → INVALID
        verdict, reason = mod.aggregate_verdict_lowfreq(folds)
        self.assertEqual(verdict, "INVALID")
        self.assertIn("insufficient_pooled_trades", reason)

    def test_pooled_below_floor_fails(self):
        mod = _load_module()
        # enough trades (16 >= 15), active in >=2 years, but pooled is a net loser → FAIL.
        folds = [self._fold("F1", 6, [1, 1, -3, -3, 1, 1]),
                 self._fold("F2", 6, [1, 1, -3, -3, 1, 1]),
                 self._fold("F3", 4, [1, 1, -3, -3])]
        verdict, reason = mod.aggregate_verdict_lowfreq(folds)
        self.assertEqual(verdict, "FAIL")
        self.assertIn("below_floor", reason)


if __name__ == "__main__":
    unittest.main()
