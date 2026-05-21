from __future__ import annotations

import csv
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "framework" / "scripts" / "p8_news_driver.py"
MATRIX = REPO / "framework" / "scripts" / "tests" / "fixtures" / "p8_matrix.csv"


def write_report(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        """
<html><body><table>
<tr><th colspan="13"><b>Deals</b></th></tr>
<tr><td><b>Time</b></td><td><b>Deal</b></td><td><b>Symbol</b></td><td><b>Type</b></td><td><b>Direction</b></td><td><b>Volume</b></td><td><b>Price</b></td><td><b>Order</b></td><td><b>Commission</b></td><td><b>Swap</b></td><td><b>Profit</b></td><td><b>Balance</b></td><td><b>Comment</b></td></tr>
<tr><td>2026.05.01 14:20:00</td><td>1</td><td>EURUSD.DWX</td><td>buy</td><td>in</td><td>1.0</td><td>1.1</td><td>1</td><td>0.00</td><td>0.00</td><td>0.00</td><td>100000.00</td><td>entry</td></tr>
<tr><td>2026.05.01 15:20:00</td><td>2</td><td>EURUSD.DWX</td><td>sell</td><td>out</td><td>1.0</td><td>1.2</td><td>1</td><td>0.00</td><td>0.00</td><td>120.00</td><td>100120.00</td><td>exit</td></tr>
<tr><td>2026.05.03 14:20:00</td><td>3</td><td>EURUSD.DWX</td><td>buy</td><td>in</td><td>1.0</td><td>1.1</td><td>3</td><td>0.00</td><td>0.00</td><td>0.00</td><td>100120.00</td><td>entry</td></tr>
<tr><td>2026.05.03 15:20:00</td><td>4</td><td>EURUSD.DWX</td><td>sell</td><td>out</td><td>1.0</td><td>1.2</td><td>3</td><td>0.00</td><td>0.00</td><td>80.00</td><td>100200.00</td><td>exit</td></tr>
</table></body></html>
""",
        encoding="utf-8",
    )


class P8NewsDriverTests(unittest.TestCase):
    def test_legacy_trade_report_only_mode_is_not_hard_gate_proof(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            calendar = tmp_path / "news_calendar.csv"
            with calendar.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(
                    handle,
                    fieldnames=["timestamp_utc", "currency", "impact", "event", "actual", "forecast", "previous"],
                )
                writer.writeheader()
                writer.writerow(
                    {
                        "timestamp_utc": "2026-05-01T12:30:00Z",
                        "currency": "USD",
                        "impact": "high",
                        "event": "NFP",
                        "actual": "220K",
                        "forecast": "205K",
                        "previous": "200K",
                    }
                )
            out_root = tmp_path / "out"
            report = tmp_path / "report.htm"
            write_report(report)
            cmd = [
                "python",
                str(SCRIPT),
                "--ea",
                "QM5_1001",
                "--news-matrix",
                str(MATRIX),
                "--calendar-csv",
                str(calendar),
                "--out-prefix",
                str(out_root),
                "--mode",
                "all",
                "--trade-report",
                str(report),
                "--min-trades",
                "1",
            ]
            proc = subprocess.run(cmd, cwd=str(REPO), capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")
            result_path = Path(proc.stdout.strip().splitlines()[-1])
            self.assertTrue(result_path.exists(), msg=f"missing {result_path}")
            data = json.loads(result_path.read_text(encoding="utf-8"))
            self.assertEqual(data["verdict"], "WAITING_INPUT")
            self.assertIn("real MT5 news-mode reruns", data["criterion"])
            self.assertEqual(data["details"]["parameters"]["run_mt5"], False)
            self.assertIn("trade_reports_ignored_for_hard_gate", data["details"])


if __name__ == "__main__":
    unittest.main()
