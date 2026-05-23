from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "framework" / "scripts"


def _write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload), encoding="utf-8")


class PhaseBacktestDriverTests(unittest.TestCase):
    def test_p5_stress_driver_emits_metrics_from_mock_summaries(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            clean = root / "clean_summary.json"
            stress = root / "stress_summary.json"
            cal = root / "cal.json"
            out = root / "out"
            _write_json(clean, {"runs": [{"status": "OK", "profit_factor": 1.40, "total_trades": 100}]})
            _write_json(stress, {"runs": [{"status": "OK", "profit_factor": 1.10, "total_trades": 50}]})
            _write_json(
                cal,
                {
                    "symbols": {
                        "EURUSD.DWX": {
                            "commission_cents_per_lot": 7,
                            "spread_points": {"p95": 25},
                        }
                    }
                },
            )
            cmd = [
                "python",
                str(SCRIPTS / "p5_stress_driver.py"),
                "--ea",
                "QM5_1001",
                "--symbol",
                "EURUSD.DWX",
                "--year",
                "2024",
                "--calibration-json",
                str(cal),
                "--out-prefix",
                str(out),
                "--mock-clean-summary",
                str(clean),
                "--mock-stress-summary",
                str(stress),
            ]
            proc = subprocess.run(cmd, cwd=str(REPO), capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")
            payload = json.loads(proc.stdout.strip().splitlines()[-1])
            clean_m = json.loads(Path(payload["clean_metrics_json"]).read_text(encoding="utf-8"))
            stress_m = json.loads(Path(payload["stress_metrics_json"]).read_text(encoding="utf-8"))
            self.assertEqual(clean_m["trade_count"], 100)
            self.assertEqual(stress_m["trade_count"], 50)

    def test_p5b_noise_driver_exposes_real_mt5_contract(self) -> None:
        proc = subprocess.run(
            ["python", str(SCRIPTS / "p5b_noise_driver.py"), "--help"],
            cwd=str(REPO),
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")
        self.assertIn("--calibration-json", proc.stdout)
        self.assertIn("--smoke-script", proc.stdout)
        self.assertNotIn("--paths", proc.stdout)

    def test_p6_multiseed_driver_copies_mock_seed_csv(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out = root / "out"
            src_csv = root / "src.csv"
            src_csv.write_text("seed,seed_pass,profit_factor,trade_count\n42,PASS,1.2,100\n", encoding="utf-8")
            cmd = [
                "python",
                str(SCRIPTS / "p6_multiseed_driver.py"),
                "--ea",
                "QM5_1001",
                "--symbol",
                "EURUSD.DWX",
                "--year",
                "2024",
                "--out-prefix",
                str(out),
                "--mock-seeds-csv",
                str(src_csv),
            ]
            proc = subprocess.run(cmd, cwd=str(REPO), capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")
            out_csv = Path(proc.stdout.strip().splitlines()[-1])
            self.assertTrue(out_csv.exists())
            self.assertIn("seed,seed_pass", out_csv.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
