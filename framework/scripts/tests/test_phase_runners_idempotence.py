from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "framework" / "scripts"
FIX = SCRIPTS / "tests" / "fixtures"


def _normalize_result(payload: dict) -> dict:
    cloned = json.loads(json.dumps(payload))
    cloned.pop("generated_at_utc", None)
    return cloned


class PhaseRunnersIdempotenceTests(unittest.TestCase):
    def _run(self, script: str, args: list[str], out_root: Path) -> dict:
        cmd = ["python", str(SCRIPTS / script), "--ea", "QM5_1001", "--out-prefix", str(out_root)] + args
        proc = subprocess.run(cmd, cwd=str(REPO), capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, msg=f"{script}\nstdout={proc.stdout}\nstderr={proc.stderr}")
        path = Path(proc.stdout.strip().splitlines()[-1])
        self.assertTrue(path.exists(), msg=f"missing result file for {script}: {path}")
        return json.loads(path.read_text(encoding="utf-8"))

    def test_idempotence_and_schema(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            cases = [
                ("p4_walk_forward.py", ["--walk-forward-csv", str(FIX / "p4_walk_forward.csv")]),
                ("p35_csr_runner.py", ["--baseline-csv", str(FIX / "p35_baseline.csv"), "--csr-results-csv", str(FIX / "p35_csr.csv")]),
                ("p5_stress_runner.py", ["--calibration-json", str(FIX / "p5_calibration_ready.json"), "--clean-metrics-json", str(FIX / "p5_clean_metrics.json"), "--stress-metrics-json", str(FIX / "p5_stress_metrics.json")]),
                ("p5c_crisis_slices.py", ["--slices-csv", str(FIX / "p5c_slices.csv")]),
                ("p6_multiseed.py", ["--seeds-csv", str(FIX / "p6_seeds.csv"), "--seeds", "42,17,99,7,2026"]),
                ("p7_statval.py", ["--sweep-pass-rows", str(FIX / "p7_sweep_pass_rows.csv"), "--multiseed-rows", str(FIX / "p7_multiseed_rows.csv")]),
            ]

            for script, args in cases:
                first = self._run(script, args, out)
                second = self._run(script, args, out)
                for payload in (first, second):
                    self.assertIn("phase", payload)
                    self.assertIn("ea_id", payload)
                    self.assertIn("verdict", payload)
                    self.assertIn("criterion", payload)
                    self.assertIn("evidence_path", payload)
                    self.assertIn("details", payload)
                self.assertEqual(_normalize_result(first), _normalize_result(second), msg=f"non-idempotent payload for {script}")


if __name__ == "__main__":
    unittest.main()
