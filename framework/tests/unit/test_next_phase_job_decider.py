from __future__ import annotations

import unittest

from framework.scripts.next_phase_job_decider import derive_transition_jobs


class NextPhaseJobDeciderTests(unittest.TestCase):
    def test_derives_only_pass_to_next_phase(self) -> None:
        rows = [
            {"ea_id": "QM5_1001", "phase": "P1", "symbol": "EURUSD.DWX", "verdict": "PASS", "config_hash": "a1"},
            {"ea_id": "QM5_1002", "phase": "P2", "symbol": "GBPUSD.DWX", "verdict": "FAIL", "config_hash": "a2"},
            {"ea_id": "QM5_1003", "phase": "P8", "symbol": "XAUUSD.DWX", "verdict": "AUTO_PASS", "config_hash": "a3"},
        ]
        jobs = derive_transition_jobs(rows)
        self.assertEqual(jobs[0]["phase"], "P2")
        self.assertEqual(jobs[1]["phase"], "P10")
        self.assertEqual(len(jobs), 2)

    def test_rejects_non_dwx_symbol(self) -> None:
        rows = [{"ea_id": "QM5_1001", "phase": "P1", "symbol": "EURUSD", "verdict": "PASS", "config_hash": "a1"}]
        with self.assertRaisesRegex(ValueError, r"\.DWX"):
            derive_transition_jobs(rows)


if __name__ == "__main__":
    unittest.main()
