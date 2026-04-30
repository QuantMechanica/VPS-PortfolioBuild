from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
RUN_PHASE = REPO_ROOT / "framework" / "scripts" / "run_phase.ps1"
P35_BASELINE_FIXTURE = REPO_ROOT / "framework" / "scripts" / "tests" / "fixtures" / "p35_baseline.csv"


def _run_phase(*, out_root: Path, symbols: list[str] | None = None) -> subprocess.CompletedProcess[str]:
    def psq(path: str) -> str:
        return "'" + path.replace("'", "''") + "'"

    symbols_segment = ""
    if symbols:
        quoted = ",".join(psq(symbol) for symbol in symbols)
        symbols_segment = f" -Symbols @({quoted})"

    ps_command = (
        f"$runnerArgs=@('--baseline-csv',{psq(str(P35_BASELINE_FIXTURE))}); "
        f"& {psq(str(RUN_PHASE))} -EAId QM5_1001 -Phase P3.5 -OutRoot {psq(str(out_root))}"
        f"{symbols_segment} -RunnerArgs $runnerArgs"
    )

    command = ["powershell", "-NoProfile", "-Command", ps_command]
    return subprocess.run(
        command,
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
        check=False,
    )


class TestRunPhaseOrchestrator(unittest.TestCase):
    def test_happy_path_writes_structured_orchestrator_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out_root = Path(tmp)
            result = _run_phase(out_root=out_root)

            self.assertEqual(result.returncode, 0, msg=result.stderr)
            phase_dir = out_root / "QM5_1001" / "P3_5"
            result_json = phase_dir / "P3_5_QM5_1001_result.json"
            orchestrator_json = phase_dir / "phase_orchestrator_last.json"
            run_meta_json = phase_dir / "run_phase_last.json"
            aggregate_json = out_root / "QM5_1001" / "index.json"

            self.assertTrue(result_json.exists())
            self.assertTrue(orchestrator_json.exists())
            self.assertTrue(run_meta_json.exists())
            self.assertTrue(aggregate_json.exists())

            orchestrator = json.loads(orchestrator_json.read_text(encoding="utf-8"))
            self.assertEqual(orchestrator["phase"], "P3.5")
            self.assertEqual(orchestrator["ea_id"], "QM5_1001")
            self.assertIn(orchestrator["verdict"], {"AUTO_PASS", "NEEDS_RERUN", "PASS", "FAIL", "NO_PASS_BASELINE"})
            self.assertIsInstance(orchestrator["criterion"], str)
            self.assertEqual(orchestrator["symbols"], ["EURUSD.DWX"])
            self.assertTrue(str(orchestrator["evidence_path"]).endswith("P3_5_QM5_1001_result.json"))

    def test_edge_case_rejects_unregistered_symbol(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out_root = Path(tmp)
            result = _run_phase(out_root=out_root, symbols=["XAUUSD.DWX"])

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("not registered for EA QM5_1001", result.stderr + result.stdout)


if __name__ == "__main__":
    unittest.main()
