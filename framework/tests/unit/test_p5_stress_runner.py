import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
RUNNER = REPO_ROOT / "framework" / "scripts" / "p5_stress_runner.py"
FIXTURES = REPO_ROOT / "framework" / "scripts" / "tests" / "fixtures"
PENDING_CALIBRATION = REPO_ROOT / "framework" / "calibrations" / "VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json"
READY_CALIBRATION = FIXTURES / "p5_calibration_ready.json"
CLEAN_METRICS = FIXTURES / "p5_clean_metrics.json"
STRESS_METRICS = FIXTURES / "p5_stress_metrics.json"


def run_runner(*, ea_id: str, calibration_json: Path, extra_args: list[str] | None = None) -> dict:
    with tempfile.TemporaryDirectory() as tmp_dir:
        out_prefix = Path(tmp_dir)
        cmd = [
            "python",
            str(RUNNER),
            "--ea",
            ea_id,
            "--calibration-json",
            str(calibration_json),
            "--clean-metrics-json",
            str(CLEAN_METRICS),
            "--stress-metrics-json",
            str(STRESS_METRICS),
            "--out-prefix",
            str(out_prefix),
        ]
        if extra_args:
            cmd.extend(extra_args)
        completed = subprocess.run(cmd, check=True, capture_output=True, text=True, cwd=REPO_ROOT)
        result_path = Path(completed.stdout.strip().splitlines()[-1])
        if not result_path.is_absolute():
            result_path = REPO_ROOT / result_path
        with result_path.open("r", encoding="utf-8") as handle:
            return json.load(handle)


class TestP5StressRunner(unittest.TestCase):
    def test_happy_path_pass_with_history_window(self) -> None:
        result = run_runner(
            ea_id="QM5_TEST_PASS",
            calibration_json=READY_CALIBRATION,
            extra_args=["--full-history-from", "2017-01-01", "--full-history-to", "2022-12-31"],
        )
        self.assertEqual(result["verdict"], "PASS")
        self.assertEqual(result["phase"], "P5")
        self.assertEqual(result["details"]["full_history_window"]["from"], "2017-01-01")
        self.assertEqual(result["details"]["full_history_window"]["to"], "2022-12-31")
        self.assertIn("delta", result["details"])
        self.assertIn("drawdown_pct", result["details"]["delta"])

    def test_edge_case_pending_calibration_fails(self) -> None:
        result = run_runner(ea_id="QM5_TEST_FAIL", calibration_json=PENDING_CALIBRATION)
        self.assertEqual(result["verdict"], "FAIL")
        self.assertIn("pending", result["criterion"].lower())
        self.assertFalse(result["details"]["calibration_ready"])


if __name__ == "__main__":
    unittest.main()
