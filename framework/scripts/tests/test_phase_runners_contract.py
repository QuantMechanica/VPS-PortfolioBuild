from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
RUN_PHASE = REPO / "framework" / "scripts" / "run_phase.ps1"
FIXTURES = REPO / "framework" / "scripts" / "tests" / "fixtures"


class PhaseRunnerContractTests(unittest.TestCase):
    def _run_phase(self, phase: str, runner_args: list[str], out_root: Path) -> dict:
        args_list = "@(" + ",".join([f"'{a}'" for a in runner_args]) + ")"
        cmd = [
            "pwsh",
            "-NoProfile",
            "-Command",
            f"$a={args_list}; & '{RUN_PHASE}' -EAId QM5_1001 -Phase {phase} -OutRoot '{out_root}' -Symbols EURUSD.DWX -RunnerArgs $a",
        ]
        proc = subprocess.run(cmd, cwd=str(REPO), capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, msg=f"phase={phase}\nstdout={proc.stdout}\nstderr={proc.stderr}")
        token = phase.replace(".", "_")
        phase_dir = phase
        result_path = out_root / "QM5_1001" / phase_dir / f"{token}_QM5_1001_result.json"
        self.assertTrue(result_path.exists(), msg=f"missing {result_path}\nstdout={proc.stdout}\nstderr={proc.stderr}")
        data = json.loads(result_path.read_text(encoding="utf-8"))
        self.assertEqual(data["phase"], phase)
        self.assertEqual(data["ea_id"], "QM5_1001")
        self.assertIn("verdict", data)
        self.assertIn("criterion", data)
        self.assertIn("evidence_path", data)
        self.assertIn("details", data)
        return data

    def test_run_phase_contract_for_required_phase2b_runners(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out_root = Path(tmp)
            self._run_phase(
                "P5",
                [
                    "--calibration-json", str(FIXTURES / "p5_calibration_ready.json"),
                    "--clean-metrics-json", str(FIXTURES / "p5_clean_metrics.json"),
                    "--stress-metrics-json", str(FIXTURES / "p5_stress_metrics.json"),
                    "--full-history-from", "2017-01-01",
                    "--full-history-to", "2022-12-31",
                ],
                out_root,
            )
            self._run_phase(
                "P5c",
                [
                    "--slices-csv", str(FIXTURES / "p5c_slices.csv"),
                    "--clean-metrics-json", str(FIXTURES / "p5_clean_metrics.json"),
                ],
                out_root,
            )
            self._run_phase(
                "P6",
                [
                    "--seeds-csv", str(FIXTURES / "p6_seeds.csv"),
                    "--seeds", "42,17,99,7,2026",
                ],
                out_root,
            )
            self._run_phase(
                "P7",
                [
                    "--sweep-pass-rows", str(FIXTURES / "p7_sweep_pass_rows.csv"),
                    "--multiseed-rows", str(FIXTURES / "p7_multiseed_rows.csv"),
                ],
                out_root,
            )


if __name__ == "__main__":
    unittest.main()
