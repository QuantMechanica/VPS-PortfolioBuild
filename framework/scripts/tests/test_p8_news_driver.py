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


class P8NewsDriverTests(unittest.TestCase):
    def test_runs_all_profiles_and_writes_summary(self) -> None:
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
            ]
            proc = subprocess.run(cmd, cwd=str(REPO), capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")
            result_path = Path(proc.stdout.strip().splitlines()[-1])
            self.assertTrue(result_path.exists(), msg=f"missing {result_path}")
            data = json.loads(result_path.read_text(encoding="utf-8"))
            self.assertIn("mode_results", data["details"])
            self.assertIn("full", data["details"]["mode_results"])
            self.assertIn("custom", data["details"]["mode_results"])

            summary_csv = out_root / "QM5_1001" / "P8" / "P8_summary.csv"
            self.assertTrue(summary_csv.exists(), msg=f"missing {summary_csv}")


if __name__ == "__main__":
    unittest.main()
