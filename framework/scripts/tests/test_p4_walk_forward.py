from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

import sys


REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "framework" / "scripts"
FIX = SCRIPTS / "tests" / "fixtures"
sys.path.insert(0, str(SCRIPTS))

from p4_walk_forward import _write_walk_forward_csv_from_manifest  # noqa: E402


class P4WalkForwardRunnerTests(unittest.TestCase):
    def test_p4_walk_forward_passes_with_valid_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            cmd = [
                "python",
                str(SCRIPTS / "p4_walk_forward.py"),
                "--ea",
                "QM5_1001",
                "--walk-forward-csv",
                str(FIX / "p4_walk_forward.csv"),
                "--out-prefix",
                str(out),
            ]
            proc = subprocess.run(cmd, cwd=str(REPO), capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")

            result_path = Path(proc.stdout.strip().splitlines()[-1])
            self.assertTrue(result_path.exists(), msg=f"missing result json: {result_path}")

            payload = json.loads(result_path.read_text(encoding="utf-8"))
            self.assertEqual(payload["phase"], "P4")
            self.assertEqual(payload["ea_id"], "QM5_1001")
            self.assertEqual(payload["verdict"], "PASS")
            self.assertIn("details", payload)
            report_csv = out / "QM5_1001" / "P4" / "report.csv"
            self.assertTrue(report_csv.exists(), msg=f"missing report csv: {report_csv}")

    def test_manifest_fold_summary_accepts_run_smoke_result_field(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            summary = root / "fold_summary.json"
            summary.write_text(json.dumps({"result": "PASS", "reason": "OK"}), encoding="utf-8")
            out_dir = root / "out"
            out_dir.mkdir()

            walk_forward_csv = _write_walk_forward_csv_from_manifest(
                {
                    "fold_results": [
                        {
                            "fold_id": "F1",
                            "regime": "UNCLASSIFIED",
                            "dev_start": "2017-01-01",
                            "dev_end": "2022-12-25",
                            "oos_start": "2023-01-01",
                            "oos_end": "2023-06-30",
                            "summary_path": str(summary),
                        }
                    ]
                },
                out_dir,
            )

            text = walk_forward_csv.read_text(encoding="utf-8")
            self.assertIn("true,PASS", text)

    def test_real_fold_summaries_must_meet_p8_oos_floor(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rows = []
            windows = [
                ("2022-12-25", "2023-01-01", "2023-06-30"),
                ("2023-06-24", "2023-07-01", "2023-12-31"),
                ("2023-12-25", "2024-01-01", "2024-06-30"),
                ("2024-06-24", "2024-07-01", "2024-12-31"),
                ("2024-12-25", "2025-01-01", "2025-06-30"),
                ("2025-06-24", "2025-07-01", "2025-12-31"),
            ]
            for i in range(6):
                summary = root / f"fold_{i}.json"
                summary.write_text(
                    json.dumps(
                        {
                            "result": "PASS",
                            "runs": [
                                {
                                    "status": "OK",
                                    "total_trades": 2,
                                    "net_profit": 100.0,
                                    "drawdown_raw": "100.00 (1.00%)",
                                }
                            ],
                        }
                    ),
                    encoding="utf-8",
                )
                dev_end, oos_start, oos_end = windows[i]
                rows.append(
                    {
                        "fold_id": f"F{i + 1}",
                        "regime": "UNCLASSIFIED",
                        "dev_start": "2017-01-01",
                        "dev_end": dev_end,
                        "oos_start": oos_start,
                        "oos_end": oos_end,
                        "oos_clean": "true",
                        "verdict": "PASS",
                        "summary_path": str(summary),
                    }
                )
            csv_path = root / "wf.csv"
            with csv_path.open("w", encoding="utf-8", newline="") as handle:
                import csv

                writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
                writer.writeheader()
                writer.writerows(rows)

            proc = subprocess.run(
                [
                    "python",
                    str(SCRIPTS / "p4_walk_forward.py"),
                    "--ea",
                    "QM5_1001",
                    "--walk-forward-csv",
                    str(csv_path),
                    "--out-prefix",
                    str(root / "out"),
                ],
                cwd=str(REPO),
                capture_output=True,
                text=True,
            )
            self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")
            payload = json.loads(Path(proc.stdout.strip().splitlines()[-1]).read_text(encoding="utf-8"))
            self.assertEqual(payload["verdict"], "FAIL")
            self.assertIn("OOS trades 12 below P8 objective minimum 30", payload["details"]["issues"])


if __name__ == "__main__":
    unittest.main()
