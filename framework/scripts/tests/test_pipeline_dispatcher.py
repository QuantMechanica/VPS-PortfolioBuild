from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from framework.scripts.pipeline_dispatcher import (
    TERMINALS,
    MATRIX_SYMBOL_COUNT,
    build_matrix_jobs,
    dedup_key,
    dispatch_job,
    export_phase_matrix_index,
    load_dedup_index,
    prune_state,
    release_job,
    resolve_target_terminal,
    save_dedup_index,
    validate_job,
    validate_matrix_payload,
)


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

    def test_validate_job_rejects_non_dwx_symbol(self) -> None:
        with self.assertRaisesRegex(ValueError, r"job\.symbol must end with \.DWX"):
            validate_job(base_job(symbol="EURUSD"))

    def test_validate_job_rejects_missing_required_field(self) -> None:
        job = base_job()
        del job["phase"]
        with self.assertRaisesRegex(ValueError, r"job\.phase must be a non-empty string"):
            validate_job(job)

    def test_validate_matrix_payload_accepts_exact_36_dwx_symbols(self) -> None:
        payload = {
            "ea_id": "QM5_1001",
            "version": "v1",
            "phase": "P1",
            "sub_gate_config_hash": "cfg001",
            "symbols": [f"S{i:02d}.DWX" for i in range(MATRIX_SYMBOL_COUNT)],
        }
        base, symbols = validate_matrix_payload(payload)
        self.assertEqual(base["ea_id"], "QM5_1001")
        self.assertEqual(len(symbols), MATRIX_SYMBOL_COUNT)

    def test_validate_matrix_payload_fail_fast_on_wrong_symbol_count(self) -> None:
        payload = {
            "ea_id": "QM5_1001",
            "version": "v1",
            "phase": "P1",
            "sub_gate_config_hash": "cfg001",
            "symbols": [f"S{i:02d}.DWX" for i in range(MATRIX_SYMBOL_COUNT - 1)],
        }
        with self.assertRaisesRegex(ValueError, r"exactly 36"):
            validate_matrix_payload(payload)

    def test_validate_matrix_payload_fail_fast_on_non_dwx_symbol(self) -> None:
        symbols = [f"S{i:02d}.DWX" for i in range(MATRIX_SYMBOL_COUNT)]
        symbols[5] = "EURUSD"
        payload = {
            "ea_id": "QM5_1001",
            "version": "v1",
            "phase": "P1",
            "sub_gate_config_hash": "cfg001",
            "symbols": symbols,
        }
        with self.assertRaisesRegex(ValueError, r"must end with \.DWX"):
            validate_matrix_payload(payload)

    def test_build_matrix_jobs_materializes_one_job_per_symbol(self) -> None:
        symbols = [f"S{i:02d}.DWX" for i in range(MATRIX_SYMBOL_COUNT)]
        payload = {
            "ea_id": "QM5_1001",
            "version": "v1",
            "phase": "P1",
            "sub_gate_config_hash": "cfg001",
            "symbols": symbols,
        }
        jobs = build_matrix_jobs(payload)
        self.assertEqual(len(jobs), MATRIX_SYMBOL_COUNT)
        self.assertEqual(jobs[0]["symbol"], "S00.DWX")
        self.assertEqual(jobs[-1]["symbol"], f"S{MATRIX_SYMBOL_COUNT - 1:02d}.DWX")


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
        self.assertEqual(decision["terminal"], "T1")


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

    def test_release_job_decrements_running_and_marks_complete(self) -> None:
        job = base_job()
        key = dedup_key(job)
        state = {
            "dedup": {key: {"terminal": "T2", "symbol": "EURUSD.DWX", "ts": 1000}},
            "running": {"T1": 0, "T2": 2, "T3": 0, "T4": 0, "T5": 0},
        }
        result = release_job(job, state, now_epoch=1002)
        self.assertEqual(result["status"], "released")
        self.assertEqual(result["terminal"], "T2")
        self.assertEqual(state["running"]["T2"], 1)
        self.assertEqual(state["dedup"][key]["status"], "complete")

    def test_release_job_noop_when_missing_dedup(self) -> None:
        state = {"dedup": {}, "running": {"T1": 0, "T2": 0, "T3": 0, "T4": 0, "T5": 0}}
        result = release_job(base_job(), state, now_epoch=1002)
        self.assertEqual(result["status"], "not_found")

    def test_release_job_updates_phase_matrix_and_pass_verdict(self) -> None:
        job = base_job(symbol="EURUSD.DWX")
        key = dedup_key(job)
        state = {
            "dedup": {key: {"terminal": "T1", "symbol": "EURUSD.DWX", "ts": 1000}},
            "running": {"T1": 1, "T2": 0, "T3": 0, "T4": 0, "T5": 0},
            "phase_matrix_index": {
                "QM5_1001_v1_P1": {
                    "matrix": [
                        {"symbol": "EURUSD.DWX", "terminal": "T1", "verdict": None, "evidence": None},
                        {"symbol": "GBPUSD.DWX", "terminal": "T2", "verdict": "PASS", "evidence": "ok"},
                    ],
                    "phase_verdict": None,
                    "next_strategy_unblocked": None,
                }
            },
        }
        release_job(job, state, now_epoch=1003, verdict="PASS", evidence="rep://EURUSD", pass_threshold=1)
        bucket = state["phase_matrix_index"]["QM5_1001_v1_P1"]
        eurusd_row = next(item for item in bucket["matrix"] if item["symbol"] == "EURUSD.DWX")
        self.assertEqual(eurusd_row["verdict"], "PASS")
        self.assertEqual(bucket["phase_verdict"], "PASS")

    def test_release_job_sets_fail_phase_when_no_symbol_passes(self) -> None:
        state = {
            "dedup": {
                dedup_key(base_job(symbol="EURUSD.DWX")): {"terminal": "T1", "symbol": "EURUSD.DWX", "ts": 1000},
                dedup_key(base_job(symbol="GBPUSD.DWX")): {"terminal": "T2", "symbol": "GBPUSD.DWX", "ts": 1000},
            },
            "running": {"T1": 1, "T2": 1, "T3": 0, "T4": 0, "T5": 0},
        }
        release_job(
            base_job(symbol="EURUSD.DWX"),
            state,
            now_epoch=1003,
            verdict="FAIL",
            fail_phase_label="P2",
            pass_threshold=1,
        )
        release_job(
            base_job(symbol="GBPUSD.DWX"),
            state,
            now_epoch=1004,
            verdict="FAIL",
            fail_phase_label="P2",
            pass_threshold=1,
            next_strategy_unblocked="SRC04_S2",
        )
        bucket = state["phase_matrix_index"]["QM5_1001_v1_P1"]
        self.assertEqual(bucket["phase_verdict"], "FAIL_PHASE_P2")
        self.assertEqual(bucket["next_strategy_unblocked"], "SRC04_S2")

    def test_prune_state_drops_old_completed_records(self) -> None:
        state = {
            "dedup": {
                "old": {"status": "complete", "completed_ts": 100},
                "fresh": {"status": "complete", "completed_ts": 90000},
                "active": {"status": "scheduled", "ts": 90000},
            }
        }
        removed = prune_state(state, now_epoch=170000, retention_seconds=86400)
        self.assertEqual(removed, 1)
        self.assertTrue("old" not in state["dedup"])
        self.assertTrue("fresh" in state["dedup"])
        self.assertTrue("active" in state["dedup"])

    def test_export_phase_matrix_index_returns_dict(self) -> None:
        state = {"phase_matrix_index": {"QM5_1001_v1_P2": {"matrix": [], "phase_verdict": None, "next_strategy_unblocked": None}}}
        exported = export_phase_matrix_index(state)
        self.assertIn("QM5_1001_v1_P2", exported)

    def test_save_and_load_dedup_index_round_trip(self) -> None:
        payload = {"QM5_1001_v1_P2": {"matrix": [{"symbol": "EURUSD.DWX", "terminal": "T1", "verdict": None, "evidence": None}], "phase_verdict": None, "next_strategy_unblocked": None}}
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "dedup_index.json"
            save_dedup_index(payload, path)
            loaded = load_dedup_index(path)
        self.assertEqual(loaded, payload)


if __name__ == "__main__":
    unittest.main()
