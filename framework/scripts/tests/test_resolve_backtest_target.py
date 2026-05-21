from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from framework.scripts.resolve_backtest_target import (
    BACKTEST_SETFILE_ERROR,
    _drain_pending_matrix_jobs,
    _reject_missing_setfile,
)


class ResolveBacktestTargetTests(unittest.TestCase):
    def test_rejects_missing_setfile_field(self) -> None:
        rejected = _reject_missing_setfile({"ea_id": "QM5_1001"})
        self.assertIsNotNone(rejected)
        self.assertEqual(rejected["error_code"], BACKTEST_SETFILE_ERROR)

    def test_rejects_nonexistent_relative_setfile(self) -> None:
        rejected = _reject_missing_setfile({"setfile_path": "does/not/exist.set"})
        self.assertIsNotNone(rejected)
        self.assertEqual(rejected["error_code"], BACKTEST_SETFILE_ERROR)

    def test_accepts_existing_absolute_setfile(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            setfile = Path(tmp_dir) / "ok.set"
            setfile.write_text("ENV=backtest\n", encoding="utf-8")
            rejected = _reject_missing_setfile({"setfile_path": str(setfile)})
        self.assertIsNone(rejected)

    def test_drain_pending_matrix_jobs_schedules_when_capacity_frees(self) -> None:
        pending_job = {
            "ea_id": "QM5_1001",
            "phase": "P2",
            "setfile_path": "framework/EAs/QM5_1001_example/sets/QM5_1001_example_EURUSD.DWX_H1_backtest.set",
            "sub_gate_config_hash": "cfg001",
            "symbol": "EURUSD.DWX",
            "version": "v1",
            "target_terminal": "any",
        }
        state = {
            "dedup": {},
            "last_rr_index": -1,
            "running": {"T1": 2, "T2": 3, "T3": 3, "T4": 3, "T5": 3},
            "symbol_affinity": {},
            "pending_matrix_jobs": {"QM5_1001_v1_P2": [pending_job]},
        }
        with patch("framework.scripts.pipeline_dispatcher.active_terminals", return_value=("T1", "T2", "T3", "T4", "T5")):
            summary = _drain_pending_matrix_jobs(state, max_per_terminal=3)
        self.assertEqual(summary["scheduled"], 1)
        self.assertEqual(summary["no_capacity"], 0)
        self.assertNotIn("QM5_1001_v1_P2", state["pending_matrix_jobs"])

    def test_drain_pending_matrix_jobs_keeps_queue_when_still_no_capacity(self) -> None:
        pending_job = {
            "ea_id": "QM5_1001",
            "phase": "P2",
            "setfile_path": "framework/EAs/QM5_1001_example/sets/QM5_1001_example_EURUSD.DWX_H1_backtest.set",
            "sub_gate_config_hash": "cfg001",
            "symbol": "EURUSD.DWX",
            "version": "v1",
            "target_terminal": "any",
        }
        state = {
            "dedup": {},
            "last_rr_index": -1,
            "running": {"T1": 3, "T2": 3, "T3": 3, "T4": 3, "T5": 3},
            "symbol_affinity": {},
            "pending_matrix_jobs": {"QM5_1001_v1_P2": [pending_job]},
        }
        with patch("framework.scripts.pipeline_dispatcher.active_terminals", return_value=("T1", "T2", "T3", "T4", "T5")):
            summary = _drain_pending_matrix_jobs(state, max_per_terminal=3)
        self.assertEqual(summary["scheduled"], 0)
        self.assertEqual(summary["no_capacity"], 1)
        self.assertIn("QM5_1001_v1_P2", state["pending_matrix_jobs"])
        self.assertEqual(len(state["pending_matrix_jobs"]["QM5_1001_v1_P2"]), 1)


if __name__ == "__main__":
    unittest.main()
