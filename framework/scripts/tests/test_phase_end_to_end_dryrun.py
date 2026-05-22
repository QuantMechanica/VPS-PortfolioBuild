from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
RUN_PHASE = REPO / "framework" / "scripts" / "run_phase.ps1"
FIX = REPO / "framework" / "scripts" / "tests" / "fixtures"


def run_phase(phase: str, runner_args: list[str], out_root: Path) -> None:
    args_list = "@(" + ",".join([f"'{a}'" for a in runner_args]) + ")"
    cmd = [
        "pwsh",
        "-NoProfile",
        "-Command",
        f"$a={args_list}; & '{RUN_PHASE}' -EAId QM5_1001 -Phase {phase} -OutRoot '{out_root}' -Symbols EURUSD.DWX -RunnerArgs $a",
    ]
    proc = subprocess.run(cmd, cwd=str(REPO), capture_output=True, text=True)
    if proc.returncode != 0:
        raise AssertionError(f"phase={phase}\nstdout={proc.stdout}\nstderr={proc.stderr}")


class PhaseEndToEndDryRunTests(unittest.TestCase):
    def test_run_phase_to_aggregate_index(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            run_phase("P5", ["--calibration-json", str(FIX / "p5_calibration_ready.json"), "--clean-metrics-json", str(FIX / "p5_clean_metrics.json"), "--stress-metrics-json", str(FIX / "p5_stress_metrics.json")], out)
            run_phase("P6", ["--seeds-csv", str(FIX / "p6_seeds.csv"), "--seeds", "42,17,99,7,2026"], out)
            run_phase("P7", ["--sweep-pass-rows", str(FIX / "p7_sweep_pass_rows.csv"), "--multiseed-rows", str(FIX / "p7_multiseed_rows.csv")], out)

            index_path = out / "QM5_1001" / "index.json"
            self.assertTrue(index_path.exists(), msg=f"missing {index_path}")
            index = json.loads(index_path.read_text(encoding="utf-8"))
            self.assertEqual(index["ea_id"], "QM5_1001")
            self.assertEqual(index["final_verdict"], "READY")
            self.assertEqual(index["phase_blockers"], [])


if __name__ == "__main__":
    unittest.main()
