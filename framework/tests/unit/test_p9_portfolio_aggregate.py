import csv
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
RUNNER = REPO_ROOT / "framework" / "scripts" / "p9_portfolio_aggregate.py"


class P9PortfolioAggregateRunnerTests(unittest.TestCase):
    def _curve(self, path: Path, rows: list[tuple[str, float]]) -> None:
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=["timestamp", "equity"])
            writer.writeheader()
            for ts, equity in rows:
                writer.writerow({"timestamp": ts, "equity": equity})

    def test_pass(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            c1 = root / "a.csv"
            c2 = root / "b.csv"
            basket = root / "basket.json"
            self._curve(c1, [("2026-01-01T00:00:00+00:00", 100000), ("2026-01-02T00:00:00+00:00", 101000)])
            self._curve(c2, [("2026-01-01T00:00:00+00:00", 100000), ("2026-01-02T00:00:00+00:00", 100500)])
            basket.write_text(
                json.dumps(
                    [
                        {"ea": "QM5_1001", "symbol": "EURUSD.DWX", "equity_curve": str(c1)},
                        {"ea": "QM5_1002", "symbol": "GBPUSD.DWX", "equity_curve": str(c2)},
                    ]
                ),
                encoding="utf-8",
            )
            cmd = [
                sys.executable,
                str(RUNNER),
                "--ea",
                "QM5_1001",
                "--out-prefix",
                str(root),
                "--basket-json",
                str(basket),
            ]
            completed = subprocess.run(cmd, cwd=str(REPO_ROOT), capture_output=True, text=True, check=False)
            self.assertEqual(completed.returncode, 0, msg=completed.stderr)


if __name__ == "__main__":
    unittest.main()
