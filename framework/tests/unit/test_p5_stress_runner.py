import json
import tempfile
import unittest
from pathlib import Path

from framework.scripts.p5_stress_runner import run_p5_stress


class P5StressRunnerTests(unittest.TestCase):
    def _write_json(self, path: Path, payload: dict) -> None:
        path.write_text(json.dumps(payload), encoding="utf-8")

    def test_measured_calibration_passes_when_thresholds_met(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            calibration_path = root / "calibration.json"
            self._write_json(
                calibration_path,
                {
                    "measurement_status": "MEASURED",
                    "symbols": {
                        "EURUSD.DWX": {
                            "commission_cents_per_lot": 250.0,
                            "latency_ms": {"avg": 20.0, "p95": 40.0},
                            "slippage_points": {"avg": 0.2, "p95": 0.5},
                            "spread_points": {"median": 2.0, "p95": 4.0},
                        }
                    },
                },
            )

            result = run_p5_stress(
                ea_id="QM5_1001",
                symbol="EURUSD.DWX",
                calibration_path=calibration_path,
                output_root=root / "reports",
                clean_pf=1.30,
                stress_pf=1.05,
                clean_trades=200,
                stress_trades=140,
                full_history_from="2017-01-01",
                full_history_to="2022-12-31",
            )

            self.assertEqual(result["verdict"], "PASS")
            self.assertIn("evidence_path", result)
            self.assertEqual(result["details"]["trade_retention_ratio"], 0.7)
            self.assertEqual(
                result["details"]["full_history_window"]["from"], "2017-01-01"
            )
            self.assertTrue(Path(result["evidence_path"]).exists())

    def test_pending_calibration_fails_readiness_gate(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            calibration_path = root / "calibration.json"
            self._write_json(
                calibration_path,
                {
                    "measurement_status": "PENDING",
                    "symbols": {"EURUSD.DWX": {}},
                },
            )

            result = run_p5_stress(
                ea_id="QM5_1001",
                symbol="EURUSD.DWX",
                calibration_path=calibration_path,
                output_root=root / "reports",
                clean_pf=1.25,
                stress_pf=1.20,
                clean_trades=120,
                stress_trades=100,
                full_history_from="",
                full_history_to="",
            )

            self.assertEqual(result["verdict"], "FAIL")
            self.assertIn("pending", result["criterion"].lower())


if __name__ == "__main__":
    unittest.main()
