from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
RUNNER = REPO_ROOT / "framework" / "scripts" / "p7_statval.py"
COMPAT_RUNNER = REPO_ROOT / "framework" / "scripts" / "p7_stat_validation_runner.py"
SWEEP_FIXTURE = REPO_ROOT / "framework" / "scripts" / "tests" / "fixtures" / "p7_sweep_pass_rows.csv"
MULTISEED_FIXTURE = REPO_ROOT / "framework" / "scripts" / "tests" / "fixtures" / "p7_multiseed_rows.csv"


def _run_runner(tmp_path: Path, *, script: Path, sweep_rows: Path, multiseed_rows: Path) -> dict:
    args = [
        sys.executable,
        str(script),
        "--ea",
        "QM5_1001",
        "--out-prefix",
        str(tmp_path),
        "--sweep-pass-rows",
        str(sweep_rows),
        "--multiseed-rows",
        str(multiseed_rows),
    ]
    completed = subprocess.run(
        args,
        cwd=str(REPO_ROOT),
        check=True,
        capture_output=True,
        text=True,
    )
    result_path = Path(completed.stdout.strip())
    return json.loads(result_path.read_text(encoding="utf-8"))


class TestP7Statval(unittest.TestCase):
    def test_happy_path_pass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = _run_runner(
                Path(tmp),
                script=RUNNER,
                sweep_rows=SWEEP_FIXTURE,
                multiseed_rows=MULTISEED_FIXTURE,
            )

        self.assertEqual(result["phase"], "P7")
        self.assertEqual(result["verdict"], "PASS")
        self.assertTrue(result["details"]["gate_status"]["pbo_lt_5pct"])
        self.assertEqual(result["details"]["metrics"]["sample_size"], 220)

    def test_edge_case_pbo_hard_gate_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            sweep = tmp_path / "sweep_rows.csv"
            sweep.write_text(
                "rank,symbol,trades,pbo,dsr,mc_pvalue,fdr_qvalue\n"
                "1,EURUSD.DWX,240,0.08,0.40,0.01,0.02\n",
                encoding="utf-8",
            )

            result = _run_runner(
                tmp_path,
                script=RUNNER,
                sweep_rows=sweep,
                multiseed_rows=MULTISEED_FIXTURE,
            )

        self.assertEqual(result["verdict"], "FAIL")
        self.assertFalse(result["details"]["gate_status"]["pbo_lt_5pct"])
        self.assertTrue(result["details"]["pbo_hard_gate_failed"])

    def test_compat_wrapper_matches_runner(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            canonical = _run_runner(
                tmp_path,
                script=RUNNER,
                sweep_rows=SWEEP_FIXTURE,
                multiseed_rows=MULTISEED_FIXTURE,
            )
            compat = _run_runner(
                tmp_path,
                script=COMPAT_RUNNER,
                sweep_rows=SWEEP_FIXTURE,
                multiseed_rows=MULTISEED_FIXTURE,
            )

        self.assertEqual(canonical["phase"], compat["phase"])
        self.assertEqual(canonical["verdict"], compat["verdict"])
        self.assertEqual(canonical["details"], compat["details"])


if __name__ == "__main__":
    unittest.main()
