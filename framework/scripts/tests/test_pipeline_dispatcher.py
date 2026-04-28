from __future__ import annotations

import unittest

from framework.scripts.pipeline_dispatcher import TERMINALS, dedup_key, dispatch_job, resolve_target_terminal


def base_job(symbol: str = "EURUSD.DWX") -> dict[str, str]:
    return {
        "ea_id": "QM5_1001",
        "phase": "P1",
        "sub_gate_config_hash": "cfg001",
        "symbol": symbol,
        "version": "v1",
    }


class PipelineDispatcherTests(unittest.TestCase):
    def test_dedup_key_stable(self) -> None:
        self.assertEqual(dedup_key(base_job()), "QM5_1001|v1|EURUSD.DWX|P1|cfg001")


    def test_dispatch_skips_existing_dedup(self) -> None:
        job = base_job()
        state = {
            "dedup": {dedup_key(job): {"terminal": "T1"}},
            "last_rr_index": -1,
            "running": {name: 0 for name in TERMINALS},
            "symbol_affinity": {},
        }

        decision = dispatch_job(job, state, max_per_terminal=3)
        self.assertEqual(decision["status"], "duplicate")
        self.assertIsNone(decision["terminal"])


    def test_dispatch_respects_three_cap(self) -> None:
        job = base_job()
        state = {
            "dedup": {},
            "last_rr_index": -1,
            "running": {"T1": 3, "T2": 3, "T3": 2, "T4": 3, "T5": 3},
            "symbol_affinity": {},
        }

        decision = dispatch_job(job, state, max_per_terminal=3)
        self.assertEqual(decision["status"], "scheduled")
        self.assertEqual(decision["terminal"], "T3")
        self.assertEqual(state["running"]["T3"], 3)


    def test_dispatch_uses_affinity_when_load_tied(self) -> None:
        job = base_job(symbol="US500.DWX")
        state = {
            "dedup": {},
            "last_rr_index": 0,
            "running": {"T1": 1, "T2": 1, "T3": 3, "T4": 3, "T5": 3},
            "symbol_affinity": {"US500.DWX": {"terminal": "T2", "ts": 1000}},
        }

        decision = dispatch_job(job, state, max_per_terminal=3, now_epoch=1001)
        self.assertEqual(decision["status"], "scheduled")
        self.assertEqual(decision["terminal"], "T2")

    def test_stale_affinity_older_than_24h_is_ignored(self) -> None:
        job = base_job(symbol="XAUUSD.DWX")
        state = {
            "dedup": {},
            "last_rr_index": -1,
            "running": {"T1": 0, "T2": 0, "T3": 3, "T4": 3, "T5": 3},
            "symbol_affinity": {"XAUUSD.DWX": {"terminal": "T2", "ts": 0}},
        }

        decision = dispatch_job(job, state, max_per_terminal=3, now_epoch=90000)
        self.assertEqual(decision["status"], "scheduled")
        self.assertEqual(decision["terminal"], "T1")

    def test_tie_break_prefers_lower_recent_run_count(self) -> None:
        job = base_job(symbol="GBPUSD.DWX")
        state = {
            "dedup": {},
            "last_rr_index": 4,
            "running": {"T1": 0, "T2": 0, "T3": 3, "T4": 3, "T5": 3},
            "symbol_affinity": {},
            "recent_runs": {"T1": [990, 995], "T2": [999]},
        }

        decision = dispatch_job(job, state, max_per_terminal=3, now_epoch=1000)
        self.assertEqual(decision["status"], "scheduled")
        self.assertEqual(decision["terminal"], "T2")

    def test_resolve_target_terminal_keeps_pinned_target(self) -> None:
        state = {"dedup": {}, "running": {name: 0 for name in TERMINALS}}
        job = base_job()
        job["target_terminal"] = "T4"
        decision = resolve_target_terminal(job, state, now_epoch=1000)
        self.assertEqual(decision["status"], "pinned")
        self.assertEqual(decision["terminal"], "T4")

    def test_resolve_target_terminal_dispatches_any(self) -> None:
        state = {
            "dedup": {},
            "last_rr_index": -1,
            "running": {"T1": 0, "T2": 0, "T3": 3, "T4": 3, "T5": 3},
            "symbol_affinity": {},
        }
        job = base_job()
        job["target_terminal"] = "any"
        decision = resolve_target_terminal(job, state, now_epoch=1000)
        self.assertEqual(decision["status"], "scheduled")
        self.assertEqual(decision["terminal"], "T1")


if __name__ == "__main__":
    unittest.main()
