from __future__ import annotations

import csv
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "framework" / "scripts"


def _run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=str(REPO), capture_output=True, text=True)


class PhaseInputGeneratorTests(unittest.TestCase):
    def test_p5_calibration_extractor_writes_requested_symbol(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source.json"
            source.write_text(
                json.dumps(
                    {
                        "measurement_status": "MEASURED",
                        "symbols": {
                            "EURUSD.DWX": {
                                "commission_cents_per_lot": 700,
                                "latency_ms": {"avg": 40, "p95": 90},
                                "slippage_points": {"avg": 0.7, "p95": 1.8},
                                "spread_points": {"median": 10, "p95": 18},
                            }
                        },
                    }
                ),
                encoding="utf-8",
            )
            out = root / "out"
            proc = _run(
                [
                    "python",
                    str(SCRIPTS / "p5_calibration_extractor.py"),
                    "--ea",
                    "QM5_1001",
                    "--symbols",
                    "NDX.DWX",
                    "--source-calibration",
                    str(source),
                    "--out-prefix",
                    str(out),
                ]
            )
            self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")
            payload = json.loads((out / "QM5_1001" / "P4" / "calibration.json").read_text(encoding="utf-8"))
            self.assertIn("NDX.DWX", payload["symbols"])
            self.assertEqual(payload["symbols"]["NDX.DWX"]["source_symbol"], "EURUSD.DWX")

    def test_p7_and_p8_generators_emit_expected_csvs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            p3 = root / "p3.csv"
            p3.write_text(
                "ea_id,phase,symbol,period,run_id,verdict\n"
                "1001,P3,EURUSD.DWX,H1,r1,PASS\n"
                "1001,P3,NDX.DWX,H1,r2,PASS\n",
                encoding="utf-8",
            )
            out = root / "out"
            proc = _run(
                [
                    "python",
                    str(SCRIPTS / "p7_sweep_pass_rows_generator.py"),
                    "--ea",
                    "QM5_1001",
                    "--p3-report",
                    str(p3),
                    "--out-prefix",
                    str(out),
                ]
            )
            self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")
            with (out / "QM5_1001" / "P3" / "sweep_pass_rows.csv").open(encoding="utf-8", newline="") as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual(rows[0]["pass_rows"], "2")

            metrics = root / "metrics.json"
            metrics.write_text(json.dumps({"symbol": "EURUSD.DWX", "pf": 1.3, "trade_count": 120}), encoding="utf-8")
            proc = _run(
                [
                    "python",
                    str(SCRIPTS / "p8_news_matrix_generator.py"),
                    "--ea",
                    "QM5_1001",
                    "--metrics-json",
                    str(metrics),
                    "--out-prefix",
                    str(out),
                ]
            )
            self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")
            with (out / "QM5_1001" / "P7" / "news_matrix.csv").open(encoding="utf-8", newline="") as handle:
                matrix_rows = list(csv.DictReader(handle))
            self.assertGreaterEqual(len(matrix_rows), 7)


if __name__ == "__main__":
    unittest.main()
