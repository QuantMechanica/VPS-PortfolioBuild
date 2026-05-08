import json
import tempfile
import unittest
from pathlib import Path

from framework.scripts.build_vps_slippage_latency_calibration_v2 import build_calibration, main


class BuildVpsCalibrationV2Tests(unittest.TestCase):
    def test_builds_calibration_and_writes_structured_log(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            input_path = root / "measured.json"
            output_path = root / "VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json"
            log_path = root / "phase_runner_log.jsonl"

            measured = {
                "measurement_status": "MEASURED",
                "measurement_method": "quote_drift_proxy_plus_broker_commission_schedule",
                "measured_at_server_time": "2026.04.27 16:25:44",
                "source_terminal": "T1",
                "broker_server": "Darwinex-Live",
                "symbol_source": "EURUSD",
                "symbol_key": "EURUSD.DWX",
                "sampling": {
                    "samples": 800,
                    "ping_samples_used": 800,
                    "spread_samples_used": 800,
                    "slippage_proxy_samples_used": 800,
                },
                "metrics": {
                    "commission_cents_per_lot": 250.0,
                    "latency_ms": {"avg": 33.219, "p95": 33.219},
                    "slippage_points": {"avg": 0.04, "p95": 0.0},
                    "spread_points": {"median": 3.0, "p95": 4.0},
                },
            }
            input_path.write_text(json.dumps(measured), encoding="utf-8")

            import sys

            old_argv = sys.argv
            try:
                sys.argv = [
                    "build_vps_slippage_latency_calibration_v2.py",
                    "--ea",
                    "QM5_1003",
                    "--input-json",
                    str(input_path),
                    "--output-json",
                    str(output_path),
                    "--log-jsonl",
                    str(log_path),
                ]
                rc = main()
            finally:
                sys.argv = old_argv

            self.assertEqual(rc, 0)
            payload = json.loads(output_path.read_text(encoding="utf-8"))
            self.assertEqual(payload["measurement_status"], "MEASURED")
            self.assertIn("EURUSD.DWX", payload["symbols"])

            log_record = json.loads(log_path.read_text(encoding="utf-8").strip())
            self.assertEqual(log_record["phase"], "P5")
            self.assertEqual(log_record["ea_id"], "QM5_1003")
            self.assertEqual(log_record["verdict"], "PASS")
            self.assertEqual(log_record["criterion"], "vps_calibration_json_v2")
            self.assertEqual(log_record["evidence_path"], output_path.as_posix())

    def test_missing_required_field_raises(self) -> None:
        measured = {
            "measurement_status": "MEASURED",
            "measurement_method": "m",
            "measured_at_server_time": "2026.04.27 16:25:44",
            "source_terminal": "T1",
            "broker_server": "Darwinex-Live",
            "symbol_source": "EURUSD",
            "sampling": {"samples": 1, "ping_samples_used": 1, "spread_samples_used": 1, "slippage_proxy_samples_used": 1},
            "metrics": {"commission_cents_per_lot": 1, "latency_ms": {}, "slippage_points": {}, "spread_points": {}},
        }
        with self.assertRaises(ValueError):
            build_calibration(measured, "evidence.json")


if __name__ == "__main__":
    unittest.main()
