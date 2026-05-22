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


if __name__ == "__main__":
    unittest.main()
