import csv
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from framework.scripts import q09_news_mode


class Q09NewsModeTests(unittest.TestCase):
    def test_fast_path_keeps_default_apply_semantics_without_backtest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            baseline = root / "QM5_1056_demo_NDX.DWX_H1_backtest.set"
            baseline.write_text("qm_news_temporal=OLD\n", encoding="utf-8")
            argv = self._argv(root, baseline, sweep=False)

            with mock.patch.object(sys, "argv", argv), mock.patch.object(
                    q09_news_mode.subprocess, "run",
                    side_effect=AssertionError("fast path must not run MT5")):
                exit_code = q09_news_mode.main()

            chosen = json.loads(
                (root / "QM5_1056" / "Q09" / "NDX_DWX" / "chosen_config.json")
                .read_text(encoding="utf-8")
            )

        self.assertEqual(exit_code, 0)
        self.assertEqual(chosen["reason"], "default_applied_no_sweep")
        self.assertEqual(chosen["chosen_temporal"], q09_news_mode.DEFAULT_TEMPORAL)

    def test_sweep_reads_fresh_matching_run_smoke_marker(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            baseline = root / "QM5_1056_demo_NDX.DWX_H1_backtest.set"
            baseline.write_text("qm_news_temporal=OLD\n", encoding="utf-8")
            summary = root / "QM5_1056" / "20260713_071015" / "summary.json"
            expert = r"QM\QM5_1056_demo"

            def fake_run(_args, **_kwargs):
                self._write_summary(summary, ea_id=1056, expert=expert,
                                    symbol="NDX.DWX", period="H1", terminal="T2",
                                    pf=1.23, trades=78)
                return SimpleNamespace(returncode=0,
                                       stdout=f"run_smoke.summary={summary}\n", stderr="")

            exit_code, row = self._run_one_mode(root, baseline, expert, fake_run)

        self.assertEqual(exit_code, 0)
        self.assertEqual(row["status"], "OK")
        self.assertEqual(row["pf"], "1.23")
        self.assertEqual(row["trades"], "78")

    def test_sweep_rejects_stale_matching_and_fresh_foreign_summaries(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            baseline = root / "QM5_1056_demo_NDX.DWX_H1_backtest.set"
            baseline.write_text("qm_news_temporal=OLD\n", encoding="utf-8")
            expert = r"QM\QM5_1056_demo"
            stale = root / "QM5_1056" / "20260101_000000" / "summary.json"
            self._write_summary(stale, ea_id=1056, expert=expert,
                                symbol="NDX.DWX", period="H1", terminal="T2",
                                pf=1.4, trades=90)
            os.utime(stale, (1, 1))

            def fake_run(_args, **_kwargs):
                foreign = root / "QM5_13138" / "20260713_063719" / "summary.json"
                self._write_summary(
                    foreign, ea_id=13138, expert=r"QM\QM5_13138_xau-m5-ema20",
                    symbol="XAUUSD.DWX", period="M5", terminal="T5",
                    pf=1.7, trades=80,
                )
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            exit_code, row = self._run_one_mode(root, baseline, expert, fake_run)

        self.assertEqual(exit_code, 0)
        self.assertEqual(row["status"], "NO_DATA")
        self.assertEqual(row["pf"], "")
        self.assertEqual(row["trades"], "0")

    def _run_one_mode(self, root, baseline, expert, fake_run):
        modes = [("QM_NEWS_TEMPORAL_OFF", "0_off")]
        with mock.patch.object(sys, "argv", self._argv(root, baseline, sweep=True)), \
             mock.patch.object(q09_news_mode, "ALL_TEMPORAL_MODES", modes), \
             mock.patch.object(q09_news_mode, "resolve_ea_expert_path", return_value=expert), \
             mock.patch.object(q09_news_mode.subprocess, "run", side_effect=fake_run):
            exit_code = q09_news_mode.main()
        matrix = root / "QM5_1056" / "Q09" / "NDX_DWX" / "matrix.csv"
        with matrix.open(encoding="utf-8", newline="") as handle:
            row = next(csv.DictReader(handle))
        return exit_code, row

    @staticmethod
    def _argv(root: Path, baseline: Path, *, sweep: bool) -> list[str]:
        argv = ["q09_news_mode.py", "--ea", "QM5_1056_demo",
                "--symbol", "NDX.DWX", "--baseline-setfile", str(baseline),
                "--report-root", str(root), "--terminal", "T2"]
        return argv + (["--sweep"] if sweep else [])

    @staticmethod
    def _write_summary(path: Path, *, ea_id: int, expert: str, symbol: str,
                       period: str, terminal: str, pf: float, trades: int) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({
            "ea_id": ea_id, "expert": expert, "symbol": symbol,
            "period": period, "terminal": terminal,
            "runs": [{"profit_factor": pf, "drawdown": 500.0,
                      "total_trades": trades}],
        }), encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
