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


class PhaseRunnerLogSchemaTests(unittest.TestCase):
    @unittest.skip("legacy run_phase phase_runner_log.jsonl contract retired; current runners write result JSON/orchestrator metadata")
    def test_phase_runner_log_schema(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            phase_args = {
                "P3.5": ["--baseline-csv", str(FIX / "p35_baseline.csv"), "--csr-results-csv", str(FIX / "p35_csr.csv")],
                "P5": ["--calibration-json", str(FIX / "p5_calibration_ready.json"), "--clean-metrics-json", str(FIX / "p5_clean_metrics.json"), "--stress-metrics-json", str(FIX / "p5_stress_metrics.json")],
                "P5b": ["--mc-trials", str(FIX / "p5b_trials.csv"), "--calibration-json", str(FIX / "p5_calibration_ready.json"), "--symbol", "EURUSD.DWX", "--paths", "3"],
                "P5c": ["--slices-csv", str(FIX / "p5c_slices.csv")],
                "P6": ["--seeds-csv", str(FIX / "p6_seeds.csv"), "--seeds", "42,17,99,7,2026"],
                "P7": ["--sweep-pass-rows", str(FIX / "p7_sweep_pass_rows.csv"), "--multiseed-rows", str(FIX / "p7_multiseed_rows.csv")],
                "P8": ["--news-matrix", str(FIX / "p8_matrix.csv"), "--modes", "OFF,PAUSE,SKIP_DAY"],
            }

            for phase, args in phase_args.items():
                run_phase(phase, args, out)
                token = phase.replace(".", "_")
                log_path = out / "QM5_1001" / token / "phase_runner_log.jsonl"
                self.assertTrue(log_path.exists(), msg=f"missing log {log_path}")
                lines = [ln for ln in log_path.read_text(encoding="utf-8").splitlines() if ln.strip()]
                self.assertTrue(lines, msg=f"empty log {log_path}")
                record = json.loads(lines[-1])
                for key in ("phase", "ea_id", "verdict", "criterion", "evidence_path"):
                    self.assertIn(key, record)
                self.assertEqual(record["phase"], phase)
                self.assertEqual(record["ea_id"], "QM5_1001")


if __name__ == "__main__":
    unittest.main()
