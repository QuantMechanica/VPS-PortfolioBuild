from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
RUNNER = REPO_ROOT / "framework" / "scripts" / "p35_csr_runner.py"
BASELINE_FIXTURE = REPO_ROOT / "framework" / "scripts" / "tests" / "fixtures" / "p35_baseline.csv"
CSR_FIXTURE = REPO_ROOT / "framework" / "scripts" / "tests" / "fixtures" / "p35_csr.csv"


def _run_runner(tmp_path: Path, *, baseline: Path, csr: Path | None = None) -> dict:
    args = [
        sys.executable,
        str(RUNNER),
        "--ea",
        "QM5_1001",
        "--out-prefix",
        str(tmp_path),
        "--baseline-csv",
        str(baseline),
    ]
    if csr is not None:
        args.extend(["--csr-results-csv", str(csr)])

    completed = subprocess.run(
        args,
        cwd=str(REPO_ROOT),
        check=True,
        capture_output=True,
        text=True,
    )
    result_path = Path(completed.stdout.strip())
    return json.loads(result_path.read_text(encoding="utf-8"))


class TestP35CsrRunner(unittest.TestCase):
    def test_p35_csr_happy_path_passes_after_rerun(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = _run_runner(Path(tmp), baseline=BASELINE_FIXTURE, csr=CSR_FIXTURE)

        self.assertEqual(result["phase"], "P3.5")
        self.assertEqual(result["verdict"], "PASS")
        self.assertEqual(result["details"]["baseline_pass_classes"], ["FX_MAJOR"])
        self.assertEqual(result["details"]["csr_pass_classes"], ["COMMODITY"])
        self.assertEqual(result["details"]["combined_pass_classes"], ["COMMODITY", "FX_MAJOR"])
        self.assertEqual(result["details"]["combined_pass_class_count"], 2)
        self.assertIs(result["details"]["csr_rerun_used"], True)

    def test_p35_csr_edge_no_pass_baseline(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            baseline = tmp_path / "baseline_no_pass.csv"
            baseline.write_text("symbol,verdict\nEURUSD.DWX,FAIL\nXAUUSD.DWX,FAIL\n", encoding="utf-8")

            result = _run_runner(tmp_path, baseline=baseline)

        self.assertEqual(result["phase"], "P3.5")
        self.assertEqual(result["verdict"], "NO_PASS_BASELINE")
        self.assertEqual(result["details"]["baseline_pass_classes"], [])
        self.assertEqual(result["details"]["baseline_pass_class_count"], 0)
        self.assertIs(result["details"]["csr_rerun_used"], False)


if __name__ == "__main__":
    unittest.main()
