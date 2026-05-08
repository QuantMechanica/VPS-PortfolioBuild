from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "framework" / "scripts"
FIX = SCRIPTS / "tests" / "fixtures"


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


if __name__ == "__main__":
    unittest.main()
