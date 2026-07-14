import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))

from framework.scripts import gen_q10_baseline, q10_confirmation  # noqa: E402


class Q10ConfirmationTests(unittest.TestCase):
    def test_run_confirmation_invalid_when_summary_lacks_pf_or_dd(self) -> None:
        result = self._run_confirmation_with_summary({"runs": [{"total_trades": 42}]})

        self.assertEqual(result["verdict"], "INVALID")
        self.assertEqual(result["reason"], "missing_pf_or_dd_in_summary")

    def test_run_confirmation_fails_when_pf_below_floor(self) -> None:
        result = self._run_confirmation_with_summary(
            {"runs": [{"profit_factor": 0.99, "drawdown": 1000.0, "total_trades": 42}]}
        )

        self.assertEqual(result["verdict"], "FAIL")
        self.assertTrue(result["reason"].startswith("pf_below_floor:"))

    def test_run_confirmation_fails_when_drawdown_above_ceiling(self) -> None:
        result = self._run_confirmation_with_summary(
            {"runs": [{"profit_factor": 1.2, "drawdown": 16000.0, "total_trades": 42}]}
        )

        self.assertEqual(result["verdict"], "FAIL")
        self.assertTrue(result["reason"].startswith("dd_above_ceiling:"))
        self.assertEqual(result["dd_pct"], 16.0)

    def test_run_confirmation_passes_when_pf_and_drawdown_are_inside_bounds(self) -> None:
        result = self._run_confirmation_with_summary(
            {"runs": [{"profit_factor": 1.2, "drawdown": 1000.0, "total_trades": 42}]}
        )

        self.assertEqual(result["verdict"], "PASS")
        self.assertTrue(result["reason"].startswith("pf=1.200:dd_pct=1.00"))
        self.assertIsNotNone(result["report_htm"])

    def test_run_confirmation_rejects_stale_matching_summary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            report_root = Path(tmp)
            summary = report_root / "QM5_1056" / "20260101" / "summary.json"
            summary.parent.mkdir(parents=True)
            summary.write_text(
                json.dumps({
                    "ea_id": 1056,
                    "expert": "QM/QM5_1056_dummy/QM5_1056_dummy",
                    "symbol": "NDX.DWX",
                    "period": "H1",
                    "terminal": "T2",
                    "runs": [{
                        "profit_factor": 1.2,
                        "drawdown": 1000.0,
                        "total_trades": 42,
                    }],
                }),
                encoding="utf-8",
            )
            os.utime(summary, (1, 1))
            completed = subprocess.CompletedProcess(
                args=["pwsh.exe"], returncode=1, stdout="", stderr="",
            )

            with mock.patch.object(q10_confirmation.subprocess, "run", return_value=completed):
                result = q10_confirmation.run_confirmation(
                    ea_id=1056,
                    ea_expert="QM/QM5_1056_dummy/QM5_1056_dummy",
                    symbol="NDX.DWX",
                    setfile=report_root / "baseline.set",
                    terminal="T2",
                    period="H1",
                    report_root=report_root,
                    timeout_sec=1,
                )

        self.assertIsNone(result["summary_path"])
        self.assertEqual(result["reason"], "missing_pf_or_dd_in_summary")

    def test_run_confirmation_rejects_fresh_foreign_summary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            report_root = Path(tmp)
            foreign = report_root / "QM5_13138" / "20260713_063719" / "summary.json"

            def fake_run(_args, **_kwargs):
                foreign.parent.mkdir(parents=True)
                foreign.write_text(
                    json.dumps({
                        "ea_id": 13138,
                        "expert": r"QM\QM5_13138_xau-m5-ema20",
                        "symbol": "XAUUSD.DWX",
                        "period": "M5",
                        "terminal": "T5",
                        "runs": [{
                            "profit_factor": 1.7,
                            "drawdown": 400.0,
                            "total_trades": 80,
                        }],
                    }),
                    encoding="utf-8",
                )
                return subprocess.CompletedProcess(
                    args=["pwsh.exe"], returncode=1, stdout="", stderr="",
                )

            with mock.patch.object(q10_confirmation.subprocess, "run", side_effect=fake_run):
                result = q10_confirmation.run_confirmation(
                    ea_id=1056,
                    ea_expert="QM/QM5_1056_dummy/QM5_1056_dummy",
                    symbol="NDX.DWX",
                    setfile=report_root / "baseline.set",
                    terminal="T2",
                    period="H1",
                    report_root=report_root,
                    timeout_sec=1,
                )

        self.assertIsNone(result["summary_path"])
        self.assertEqual(result["reason"], "missing_pf_or_dd_in_summary")

    def test_find_report_rejects_report_older_than_confirmation_run(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report = root / "raw" / "run_01" / "report.htm"
            report.parent.mkdir(parents=True)
            report.write_text("<html></html>", encoding="utf-8")
            os.utime(report, (1, 1))
            started_at = time.time()
            summary = root / "summary.json"
            summary.write_text(
                json.dumps({
                    "runs": [{"report_canonical_path": str(report)}],
                }),
                encoding="utf-8",
            )

            selected = q10_confirmation._find_report_htm(
                summary,
                started_at=started_at,
            )

        self.assertIsNone(selected)

    def test_extract_per_trade_profits_from_synthetic_mt5_html(self) -> None:
        htm = """
        <html><body><table>
          <tr><td>2024.01.01</td><td>buy</td><td>in</td><td>0.00</td><td>1000.00</td></tr>
          <tr><td>2024.01.02</td><td>sell</td><td>out</td><td>12.34</td><td>1012.34</td></tr>
          <tr><td>2024.01.03</td><td>sell</td><td>out</td><td>-5.67</td><td>1006.67</td></tr>
        </table></body></html>
        """

        self.assertEqual(gen_q10_baseline.extract_per_trade_profits(htm), [12.34, -5.67])

    def test_write_baseline_uses_tmp_dir_and_expected_schema(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(gen_q10_baseline, "BASELINE_DIR", Path(tmp)):
                out_path = gen_q10_baseline.write_baseline(1056, "NDX.DWX", [10.0, -2.0, 4.0])

            payload = json.loads(out_path.read_text(encoding="utf-8"))

        self.assertEqual(out_path.name, "QM5_1056_NDX_DWX.json")
        self.assertEqual(payload["ea_id"], 1056)
        self.assertEqual(payload["symbol"], "NDX.DWX")
        self.assertEqual(payload["spec_version"], "Q10-2026-05-23")
        self.assertEqual(payload["n"], 3)
        self.assertEqual(payload["trades_sorted"], [-2.0, 4.0, 10.0])
        self.assertIn("hash", payload)

    def _run_confirmation_with_summary(self, summary: dict) -> dict:
        with tempfile.TemporaryDirectory() as tmp:
            report_root = Path(tmp)
            summary_dir = report_root / "QM5_1056" / "20260101"
            summary_path = summary_dir / "summary.json"
            report_path = summary_dir / "raw" / "run_01" / "report.htm"
            setfile = report_root / "baseline.set"
            setfile.write_text("", encoding="utf-8")

            def fake_run(_args, **_kwargs):
                payload = dict(summary)
                payload.setdefault("ea_id", 1056)
                payload.setdefault("expert", "QM/QM5_1056_dummy/QM5_1056_dummy")
                payload.setdefault("symbol", "NDX.DWX")
                payload.setdefault("period", "H1")
                payload.setdefault("terminal", "T2")
                runs = [dict(run) for run in payload.get("runs") or []]
                if runs:
                    report_path.parent.mkdir(parents=True)
                    report_path.write_text("<html></html>", encoding="utf-8")
                    runs[-1]["report_canonical_path"] = str(report_path)
                    payload["runs"] = runs
                summary_dir.mkdir(parents=True, exist_ok=True)
                summary_path.write_text(json.dumps(payload), encoding="utf-8")
                return subprocess.CompletedProcess(
                    args=["pwsh.exe"],
                    returncode=0,
                    stdout=f"run_smoke.summary={summary_path}\n",
                    stderr="",
                )

            with mock.patch.object(q10_confirmation.subprocess, "run", side_effect=fake_run) as run:
                result = q10_confirmation.run_confirmation(
                    ea_id=1056,
                    ea_expert="QM/QM5_1056_dummy/QM5_1056_dummy",
                    symbol="NDX.DWX",
                    setfile=setfile,
                    terminal="T2",
                    period="H1",
                    report_root=report_root,
                    timeout_sec=1,
                )

        run.assert_called_once()
        self.assertEqual(result["exit_code"], 0)
        self.assertEqual(result["summary_path"], str(summary_path))
        return result


if __name__ == "__main__":
    unittest.main()
