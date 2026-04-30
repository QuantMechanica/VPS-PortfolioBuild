from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
RUNNER = REPO_ROOT / "framework" / "scripts" / "p5b_calibrated_noise.py"
TRIALS_FIXTURE = REPO_ROOT / "framework" / "scripts" / "tests" / "fixtures" / "p5b_trials.csv"
CALIBRATION_FIXTURE = REPO_ROOT / "framework" / "calibrations" / "VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json"


def _run_runner(tmp_path: Path, extra_args: list[str]) -> dict:
    args = [
        sys.executable,
        str(RUNNER),
        "--ea",
        "QM5_1001",
        "--out-prefix",
        str(tmp_path),
        *extra_args,
    ]
    completed = subprocess.run(
        args,
        cwd=str(REPO_ROOT),
        check=True,
        capture_output=True,
        text=True,
    )
    result_path = Path(completed.stdout.strip().splitlines()[-1])
    return json.loads(result_path.read_text(encoding="utf-8"))


class TestP5bCalibratedNoise(unittest.TestCase):
    def test_proxy_yellow_with_fixture_trials(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = _run_runner(
                Path(tmp),
                [
                    "--mc-trials",
                    str(TRIALS_FIXTURE),
                    "--calibration-json",
                    str(CALIBRATION_FIXTURE),
                    "--paths",
                    "10",
                ],
            )

        self.assertEqual(result["phase"], "P5b")
        self.assertEqual(result["verdict"], "YELLOW")
        self.assertAlmostEqual(result["details"]["strict_compliance_pct"], 0.6, places=6)
        self.assertAlmostEqual(result["details"]["proxy_compliance_pct"], 0.9, places=6)
        self.assertEqual(len(result["details"]["trial_outcomes"]), 10)
        self.assertEqual(result["details"]["trial_outcomes"][0]["breach_count"], 0)

    def test_fails_when_path_risk_feature_breaches_floor(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            trials = tmp_path / "trials.csv"
            calibration = tmp_path / "calibration.json"

            trials.write_text(
                "trial,breach_count,reject_rate,remaining_cushion_pct,recovery_fraction\n"
                "1,0,0.0005,0.11,0.15\n"
                "2,0,0.0004,0.12,0.16\n",
                encoding="utf-8",
            )
            calibration.write_text(
                json.dumps(
                    {
                        "measurement_status": "MEASURED",
                        "symbols": {
                            "EURUSD.DWX": {
                                "min_remaining_cushion_pct": 0.10,
                                "recovery_fraction_limit": 0.20,
                            }
                        },
                    }
                ),
                encoding="utf-8",
            )

            result = _run_runner(
                tmp_path,
                [
                    "--trials-csv",
                    str(trials),
                    "--calibration-json",
                    str(calibration),
                    "--symbol",
                    "EURUSD.DWX",
                    "--paths",
                    "2",
                ],
            )

        self.assertEqual(result["verdict"], "FAIL")
        self.assertTrue(result["details"]["reject_rate_floor_breached"])

    def test_fails_when_required_calibration_keys_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            trials = tmp_path / "trials.csv"
            calibration = tmp_path / "calibration.json"

            trials.write_text("trial,breach_count\n1,0\n2,0\n", encoding="utf-8")
            calibration.write_text(json.dumps({"measurement_status": "MEASURED"}), encoding="utf-8")

            result = _run_runner(
                tmp_path,
                [
                    "--trials-csv",
                    str(trials),
                    "--calibration-json",
                    str(calibration),
                    "--paths",
                    "2",
                ],
            )

        self.assertEqual(result["verdict"], "FAIL")
        self.assertIn("symbols", result["details"]["calibration_missing_keys"])

    def test_idempotent_except_timestamp(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            first = _run_runner(
                tmp_path,
                [
                    "--mc-trials",
                    str(TRIALS_FIXTURE),
                    "--calibration-json",
                    str(CALIBRATION_FIXTURE),
                    "--paths",
                    "10",
                ],
            )
            second = _run_runner(
                tmp_path,
                [
                    "--mc-trials",
                    str(TRIALS_FIXTURE),
                    "--calibration-json",
                    str(CALIBRATION_FIXTURE),
                    "--paths",
                    "10",
                ],
            )

        first.pop("generated_at_utc", None)
        second.pop("generated_at_utc", None)
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()
