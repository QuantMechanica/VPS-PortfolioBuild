from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
RUNNER = REPO_ROOT / "framework" / "scripts" / "p6_multiseed.py"
SEEDS_FIXTURE = REPO_ROOT / "framework" / "scripts" / "tests" / "fixtures" / "p6_seeds.csv"


def _run_runner(tmp_path: Path, *, seeds_csv: Path, seeds: str | None = None) -> dict:
    args = [
        sys.executable,
        str(RUNNER),
        "--ea",
        "QM5_1001",
        "--out-prefix",
        str(tmp_path),
        "--seeds-csv",
        str(seeds_csv),
    ]
    if seeds is not None:
        args.extend(["--seeds", seeds])

    completed = subprocess.run(
        args,
        cwd=str(REPO_ROOT),
        check=True,
        capture_output=True,
        text=True,
    )
    result_path = Path(completed.stdout.strip())
    return json.loads(result_path.read_text(encoding="utf-8"))


class TestP6MultiSeedRunner(unittest.TestCase):
    def test_p6_multiseed_happy_path_pass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = _run_runner(Path(tmp), seeds_csv=SEEDS_FIXTURE)

        self.assertEqual(result["phase"], "P6")
        self.assertEqual(result["verdict"], "MULTI_SEED_PASS")
        self.assertEqual(result["details"]["required_seeds"], [42, 17, 99, 7, 2026])
        self.assertEqual(result["details"]["pass_count"], 5)
        self.assertEqual(result["details"]["missing_seeds"], [])
        self.assertEqual(result["details"]["incomplete_seeds"], [])
        self.assertEqual(len(result["details"]["seed_metrics"]), 5)

    def test_p6_multiseed_edge_missing_required_seed_waiver(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = _run_runner(
                Path(tmp),
                seeds_csv=SEEDS_FIXTURE,
                seeds="42,17,99,7,2026,555",
            )

        self.assertEqual(result["phase"], "P6")
        self.assertEqual(result["verdict"], "MULTI_SEED_WAIVER")
        self.assertEqual(result["details"]["required_seeds"], [42, 17, 99, 7, 2026, 555])
        self.assertEqual(result["details"]["missing_seeds"], [555])


if __name__ == "__main__":
    unittest.main()
