from __future__ import annotations

import json
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
CAL = REPO / "framework" / "calibrations" / "VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json"


class CalibrationContractTests(unittest.TestCase):
    def test_calibration_v2_measured_and_numeric(self) -> None:
        payload = json.loads(CAL.read_text(encoding="utf-8"))
        self.assertEqual(str(payload.get("measurement_status", "")).upper(), "MEASURED")
        symbols = payload.get("symbols")
        self.assertIsInstance(symbols, dict)
        self.assertIn("EURUSD.DWX", symbols)
        eur = symbols["EURUSD.DWX"]

        self.assertIsInstance(eur.get("commission_cents_per_lot"), (int, float))
        self.assertIsInstance(eur.get("latency_ms", {}).get("avg"), (int, float))
        self.assertIsInstance(eur.get("latency_ms", {}).get("p95"), (int, float))
        self.assertIsInstance(eur.get("slippage_points", {}).get("avg"), (int, float))
        self.assertIsInstance(eur.get("slippage_points", {}).get("p95"), (int, float))
        self.assertIsInstance(eur.get("spread_points", {}).get("median"), (int, float))
        self.assertIsInstance(eur.get("spread_points", {}).get("p95"), (int, float))


if __name__ == "__main__":
    unittest.main()
