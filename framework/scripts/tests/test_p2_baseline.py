from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
import json
from unittest.mock import patch

from framework.scripts import p2_baseline


class P2BaselineTests(unittest.TestCase):
    @patch("framework.scripts.p2_baseline.subprocess.Popen")
    def test_invoke_run_smoke_does_not_force_allow_running_terminal_by_default(self, mock_popen) -> None:
        mock_proc = mock_popen.return_value
        mock_proc.poll.side_effect = [0]
        mock_proc.communicate.return_value = ("ok", "")
        mock_proc.returncode = 0

        p2_baseline.invoke_run_smoke(
            ea_id=1003,
            symbol="EURUSD.DWX",
            year=2024,
            terminal="any",
            period="H1",
            runs=2,
            expert="QM\\QM5_1003_davey_baseline_3bar",
            setfile=Path("C:/tmp/test.set"),
            report_root=Path("D:/QM/reports/pipeline/QM5_1003/P2"),
            min_trades=20,
            timeout_sec=1800,
        )

        arglist = mock_popen.call_args.args[0]
        self.assertIn("-Terminal", arglist)
        self.assertIn("any", arglist)
        self.assertNotIn("-AllowRunningTerminal", arglist)

    @patch("framework.scripts.p2_baseline.subprocess.Popen")
    def test_invoke_run_smoke_emits_periodic_running_heartbeat(self, mock_popen) -> None:
        mock_proc = mock_popen.return_value
        mock_proc.poll.side_effect = [None, None, 0]
        mock_proc.communicate.return_value = ("ok", "")
        mock_proc.returncode = 0

        with patch("framework.scripts.p2_baseline.time.monotonic", side_effect=[0.0, 2.0, 3.0, 3.5]):
            with patch("framework.scripts.p2_baseline.time.sleep"):
                with patch("framework.scripts.p2_baseline.safe_print") as mock_print:
                    p2_baseline.invoke_run_smoke(
                        ea_id=1004,
                        symbol="AUDCAD.DWX",
                        year=2024,
                        terminal="any",
                        period="H1",
                        runs=2,
                        expert="QM\\QM5_1004_davey_es_breakout",
                        setfile=Path("C:/tmp/test.set"),
                        report_root=Path("D:/QM/reports/pipeline/QM5_1004/P2"),
                        min_trades=20,
                        timeout_sec=120,
                        heartbeat_interval_sec=1,
                    )

        self.assertTrue(any("[RUNNING] AUDCAD.DWX (any)" in c.args[0] for c in mock_print.call_args_list))

    def test_ensure_expert_binary_deploys_to_all_terminals(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            ea_dir = root / "framework" / "EAs" / "QM5_1004_davey_es_breakout"
            ea_dir.mkdir(parents=True)
            src_ex5 = ea_dir / "QM5_1004_davey_es_breakout.ex5"
            src_ex5.write_bytes(b"ex5-bytes")

            t1 = root / "mt5" / "T1"
            t2 = root / "mt5" / "T2"
            for t in (t1, t2):
                (t / "MQL5" / "Experts" / "QM").mkdir(parents=True)

            p2_baseline.ensure_expert_binary_deployed(
                ea_dir=ea_dir,
                terminal_roots=[t1, t2],
            )

            self.assertEqual((t1 / "MQL5" / "Experts" / "QM" / "QM5_1004_davey_es_breakout.ex5").read_bytes(), b"ex5-bytes")
            self.assertEqual((t2 / "MQL5" / "Experts" / "QM" / "QM5_1004_davey_es_breakout.ex5").read_bytes(), b"ex5-bytes")

    def test_ensure_expert_binary_deployed_raises_when_source_missing(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            ea_dir = root / "framework" / "EAs" / "QM5_1004_davey_es_breakout"
            ea_dir.mkdir(parents=True)
            t1 = root / "mt5" / "T1"
            (t1 / "MQL5" / "Experts" / "QM").mkdir(parents=True)

            with self.assertRaises(SystemExit):
                p2_baseline.ensure_expert_binary_deployed(
                    ea_dir=ea_dir,
                    terminal_roots=[t1],
                )

    def test_ensure_magic_registry_contains_ea_raises_when_missing(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            reg = root / "framework" / "registry"
            reg.mkdir(parents=True)
            (reg / "magic_numbers.csv").write_text(
                "ea_id,ea_slug,symbol,status,symbol_slot,magic\n"
                "1001,QM5_1001_framework_smoke,EURUSD.DWX,active,0,10010000\n",
                encoding="utf-8",
            )
            with patch.object(p2_baseline, "REGISTRY_DIR", reg):
                with self.assertRaises(SystemExit):
                    p2_baseline.ensure_magic_registry_contains_ea(1004)

    def test_ensure_framework_registry_deployed_copies_csvs(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            reg = root / "framework" / "registry"
            reg.mkdir(parents=True)
            (reg / "magic_numbers.csv").write_text("h1\nv1\n", encoding="utf-8")
            (reg / "ea_id_registry.csv").write_text("h2\nv2\n", encoding="utf-8")
            t1 = root / "mt5" / "T1"
            t1.mkdir(parents=True)
            with patch.object(p2_baseline, "REGISTRY_DIR", reg):
                p2_baseline.ensure_framework_registry_deployed([t1])
            self.assertTrue((t1 / "MQL5" / "Files" / "registry" / "magic_numbers.csv").exists())
            self.assertTrue((t1 / "MQL5" / "Files" / "registry" / "ea_id_registry.csv").exists())

    def test_find_fallback_summary_path_matches_symbol_and_year(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            report_root = root / "QM5_1004" / "P2"
            run_dir = report_root / "QM5_1004" / "20260506_100000"
            run_dir.mkdir(parents=True)
            summary_path = run_dir / "summary.json"
            summary_path.write_text(json.dumps({
                "symbol": "AUDCAD.DWX",
                "year": 2024,
                "terminal": "T2",
            }), encoding="utf-8")

            found = p2_baseline.find_fallback_summary_path(
                report_root,
                ea_id=1004,
                symbol="AUDCAD.DWX",
                year=2024,
                terminal="any",
            )
            self.assertEqual(found, summary_path)

    @patch("framework.scripts.p2_baseline.invoke_run_smoke")
    @patch("framework.scripts.p2_baseline.setfile_for")
    def test_run_one_symbol_retries_once_on_no_summary_json(self, mock_setfile_for, mock_invoke_run_smoke) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            ea_dir = root / "framework" / "EAs" / "QM5_1004_davey_es_breakout"
            ea_dir.mkdir(parents=True)
            report_root_phase = root / "reports" / "QM5_1004" / "P2"
            report_csv = report_root_phase / "report.csv"

            sf = ea_dir / "sets" / "x.set"
            sf.parent.mkdir(parents=True)
            sf.write_text("ok", encoding="utf-8")
            mock_setfile_for.return_value = sf

            # no summary marker in stdout/stderr => first attempt retries, second invalid
            mock_invoke_run_smoke.return_value = (1, "stdout-without-summary", "")
            verdict = p2_baseline.run_one_symbol(
                ea_id=1004,
                ea_dir=ea_dir,
                ea_label="QM5_1004",
                symbol="AUDCAD.DWX",
                year=2024,
                period="H1",
                runs=2,
                terminal="any",
                report_root_phase=report_root_phase,
                report_csv=report_csv,
                min_trades=20,
                timeout_sec=120,
                dry_run=False,
            )
            self.assertEqual(verdict, "INVALID")
            self.assertEqual(mock_invoke_run_smoke.call_count, 2)

    def test_infer_warmup_bars_prefers_max_warmup(self) -> None:
        warmup = p2_baseline.infer_warmup_bars(
            {"training_lookback": "252", "max_warmup": "90"},
            {"training_lookback": 300, "max_warmup": 120},
        )
        self.assertEqual(warmup, 90)

    def test_infer_warmup_bars_falls_back_to_training_lookback(self) -> None:
        warmup = p2_baseline.infer_warmup_bars(
            {"training_lookback": "252"},
            {},
        )
        self.assertEqual(warmup, 252)

    def test_derive_window_dates_default_half_year_when_no_warmup(self) -> None:
        start, end = p2_baseline.derive_window_dates(2024, "H1", 0)
        self.assertEqual(start, "2024-07-01")
        self.assertEqual(end, "2024-12-31")

    def test_derive_window_dates_extends_for_d1_warmup(self) -> None:
        start, end = p2_baseline.derive_window_dates(2024, "D1", 252)
        self.assertEqual(start, "2023-04-24")
        self.assertEqual(end, "2024-12-31")

    def test_derive_verdict_g1_fail_is_invalid_regardless_of_trades(self) -> None:
        # QUA-765: model4_log_marker_detected=False must yield INVALID, not PASS.
        summary = {
            "result": "PASS",
            "model4_log_marker_detected": False,
            "reason_classes": ["NO_REAL_TICKS_MARKER"],
            "runs": [{"total_trades": 50}],
            "report_dir": "/tmp/report",
        }
        verdict, reason, _ = p2_baseline.derive_verdict(summary, min_trades=20)
        self.assertEqual(verdict, "INVALID")
        self.assertEqual(reason, "G1_NO_REAL_TICKS")

    def test_derive_verdict_pass_requires_g1_marker(self) -> None:
        summary = {
            "result": "PASS",
            "model4_log_marker_detected": True,
            "reason_classes": ["OK"],
            "runs": [{"total_trades": 50}],
            "report_dir": "/tmp/report",
        }
        verdict, reason, _ = p2_baseline.derive_verdict(summary, min_trades=20)
        self.assertEqual(verdict, "PASS")
        self.assertEqual(reason, "")


if __name__ == "__main__":
    unittest.main()
