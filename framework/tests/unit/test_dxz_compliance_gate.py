import csv
import tempfile
import unittest
from pathlib import Path

from framework.scripts.dxz_compliance_gate import check_dxz_compliance


class DXZComplianceGateTests(unittest.TestCase):
    def _write_equity_curve(self, path: Path, rows: list[tuple[str, float]]) -> None:
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=["timestamp", "equity"])
            writer.writeheader()
            for ts, equity in rows:
                writer.writerow({"timestamp": ts, "equity": equity})

    def test_pass_when_under_thresholds(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            report = root / "report.csv"
            report.write_text("close_time,profit\n", encoding="utf-8")
            curve = root / "equity.csv"
            self._write_equity_curve(
                curve,
                [
                    ("2026-01-01T08:00:00+00:00", 100000.0),
                    ("2026-01-01T20:00:00+00:00", 97000.0),
                    ("2026-01-02T08:00:00+00:00", 98000.0),
                ],
            )
            result = check_dxz_compliance(report, curve)
            self.assertEqual(result["verdict"], "DXZ_PASS")

    def test_fail_daily_breach(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            report = root / "report.csv"
            report.write_text("close_time,profit\n", encoding="utf-8")
            curve = root / "equity.csv"
            self._write_equity_curve(
                curve,
                [
                    ("2026-01-01T08:00:00+00:00", 100000.0),
                    ("2026-01-01T09:00:00+00:00", 94000.0),
                ],
            )
            result = check_dxz_compliance(report, curve)
            self.assertEqual(result["verdict"], "DXZ_FAIL")
            self.assertIn("FAIL_DAILY_DD", result["reason"])


if __name__ == "__main__":
    unittest.main()
