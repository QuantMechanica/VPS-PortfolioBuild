"""Pytest wrapper for the run_smoke report-capture-race helper unit test.

The substantive assertions live in the standalone PowerShell test
``Test-RunSmokeReportFinalizeGrace.ps1`` (same AST-extraction pattern as the
sibling ``Test-RunSmokeWaitForCompleteReport.ps1``): it extracts the new
report-shell / journal-deal / finalization-wait helpers from run_smoke.ps1 and
exercises them against fixture report.htm files and tester journals covering
shell+deals -> REPORT_CAPTURE_INCOMPLETE, shell+no-deals -> genuine zero, and a
full report -> unchanged path. This wrapper runs that PowerShell test under
pytest via pwsh so ``python -m pytest`` covers it.
"""

from __future__ import annotations

import shutil
import subprocess
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
PS_TEST = REPO / "framework" / "scripts" / "tests" / "Test-RunSmokeReportFinalizeGrace.ps1"


def _pwsh() -> str | None:
    for exe in ("pwsh", "powershell"):
        if shutil.which(exe):
            return exe
    return None


class RunSmokeReportFinalizeGraceTests(unittest.TestCase):
    def test_report_finalize_grace_helpers(self) -> None:
        pwsh = _pwsh()
        if pwsh is None:
            self.skipTest("PowerShell (pwsh/powershell) not available")
        self.assertTrue(PS_TEST.is_file(), msg=f"missing PowerShell test {PS_TEST}")
        proc = subprocess.run(
            [pwsh, "-NoProfile", "-File", str(PS_TEST)],
            cwd=str(REPO),
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            proc.returncode,
            0,
            msg=f"stdout={proc.stdout}\nstderr={proc.stderr}",
        )
        self.assertIn("PASS Test-RunSmokeReportFinalizeGrace", proc.stdout)


if __name__ == "__main__":
    unittest.main()
