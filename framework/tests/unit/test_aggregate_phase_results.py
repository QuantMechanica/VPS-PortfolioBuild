from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
RUNNER = REPO_ROOT / "framework" / "scripts" / "aggregate_phase_results.py"


def _write_phase_result(root: Path, ea_id: str, phase: str, verdict: str) -> None:
    phase_safe = phase.replace(".", "_")
    out_dir = root / ea_id / phase_safe
    out_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "criterion": "test",
        "details": {},
        "ea_id": ea_id,
        "evidence_path": "test",
        "phase": phase,
        "verdict": verdict,
    }
    result_file = out_dir / f"{phase_safe}_{ea_id}_result.json"
    result_file.write_text(json.dumps(payload), encoding="utf-8")


def _run_aggregator(input_root: Path, output_root: Path, ea_id: str = "QM5_1001") -> dict:
    cmd = [
        sys.executable,
        str(RUNNER),
        "--ea",
        ea_id,
        "--input-root",
        str(input_root),
        "--output-root",
        str(output_root),
    ]
    completed = subprocess.run(
        cmd,
        cwd=str(REPO_ROOT),
        check=True,
        capture_output=True,
        text=True,
    )
    out_path = Path(completed.stdout.strip().splitlines()[-1])
    return json.loads(out_path.read_text(encoding="utf-8"))


class TestAggregatePhaseResults(unittest.TestCase):
    def test_ready_when_all_required_phases_pass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for phase, verdict in {
                "P3.5": "AUTO_PASS",
                "P5": "PASS",
                "P5b": "PASS",
                "P6": "MULTI_SEED_PASS",
                "P7": "PASS",
                "P8": "MODE_SELECTED",
                "P9": "PASS",
            }.items():
                _write_phase_result(root, "QM5_1001", phase, verdict)

            result = _run_aggregator(root, root)

        self.assertEqual(result["final_verdict"], "READY")
        self.assertEqual(result["phase_blockers"], [])
        self.assertEqual(result["phase_review_required"], [])

    def test_review_required_when_manual_acceptance_needed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for phase, verdict in {
                "P3.5": "PASS",
                "P5": "PASS",
                "P5b": "YELLOW",
                "P6": "MULTI_SEED_MIXED",
                "P7": "PASS",
                "P8": "MODE_SELECTED",
                "P9": "PASS",
            }.items():
                _write_phase_result(root, "QM5_1001", phase, verdict)

            result = _run_aggregator(root, root)

        self.assertEqual(result["final_verdict"], "REVIEW_REQUIRED")
        self.assertEqual(result["phase_blockers"], [])
        self.assertEqual(
            result["phase_review_required"],
            [{"phase": "P5b", "verdict": "YELLOW"}],
        )

    def test_blocked_when_required_phase_missing_or_failed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for phase, verdict in {
                "P3.5": "PASS",
                "P5": "PASS",
                "P5b": "PASS",
                "P6": "MULTI_SEED_FAIL",
                "P7": "PASS",
                # P8 intentionally missing; P9 intentionally missing.
            }.items():
                _write_phase_result(root, "QM5_1001", phase, verdict)

            result = _run_aggregator(root, root)

        self.assertEqual(result["final_verdict"], "BLOCKED")
        self.assertIn({"phase": "P6", "verdict": "MULTI_SEED_FAIL"}, result["phase_blockers"])
        self.assertIn({"phase": "P8", "verdict": "MISSING"}, result["phase_blockers"])


if __name__ == "__main__":
    unittest.main()
