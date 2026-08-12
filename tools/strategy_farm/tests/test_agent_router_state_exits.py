"""State-machine exit tests (census 2026-07-27 ranks 4/5/8/9/12).

Covers the contractual exits for the three router-exitless limbo states
(RECYCLE / APPROVED / PIPELINE), the pipeline_run retirement, and the
artifact-must-be-a-file enforcement on write.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm import agent_router
from tools.strategy_farm import farmctl


def _insert_task(root: Path, *, task_type: str, state: str, payload: dict | None = None,
                 artifact_path: str | None = None, verdict: str | None = None) -> str:
    """Insert an agent_task directly in a chosen state (bypasses enqueue's TODO)."""
    import uuid
    tid = str(uuid.uuid4())
    now = farmctl.utc_now()
    with agent_router.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO agent_tasks(
                id, task_type, state, priority, required_capabilities_json,
                required_skills_json, assigned_agent, budget_class, parent_id,
                artifact_path, verdict, payload_json, created_at, updated_at
            ) VALUES (?, ?, ?, 50, '[]', '[]', NULL, 'standard', NULL, ?, ?, ?, ?, ?)
            """,
            (tid, task_type, state, artifact_path, verdict, json.dumps(payload or {}), now, now),
        )
        conn.commit()
    return tid


def _state_of(root: Path, task_id: str) -> str:
    with agent_router.connect(root) as conn:
        return conn.execute("SELECT state FROM agent_tasks WHERE id=?", (task_id,)).fetchone()["state"]


def _payload_of(root: Path, task_id: str) -> dict:
    with agent_router.connect(root) as conn:
        raw = conn.execute("SELECT payload_json FROM agent_tasks WHERE id=?", (task_id,)).fetchone()["payload_json"]
    return json.loads(raw or "{}")


class ReconcileExitsTests(unittest.TestCase):
    def test_approved_non_pipeline_task_resolves_to_passed(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            tid = _insert_task(root, task_type="research_strategy", state="APPROVED")
            agent_router.reconcile_task_exits(root, apply=True)
            self.assertEqual(_state_of(root, tid), "PASSED")

    def test_approved_safe_defer_resolves_to_blocked_not_passed(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            tid = _insert_task(
                root,
                task_type="ops_issue",
                state="APPROVED",
                verdict="SAFE_DEFER accepted: isolated but repair remains open",
            )
            result = agent_router.reconcile_task_exits(root, apply=True)
            self.assertEqual(_state_of(root, tid), "BLOCKED")
            self.assertIn(
                "APPROVED->BLOCKED:approved_safe_defer_not_completed",
                result["would_move"],
            )
            self.assertTrue(_payload_of(root, tid)["safe_defer_reclassified"])

    def test_approved_build_ea_advances_to_pipeline(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            tid = _insert_task(root, task_type="build_ea", state="APPROVED",
                               payload={"ea_id": "QM5_555001"})
            agent_router.reconcile_task_exits(root, apply=True)
            self.assertEqual(_state_of(root, tid), "PIPELINE")

    def test_pipeline_resolves_to_passed_on_q10_pass(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            with agent_router.connect(root) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items(
                        id, kind, phase, ea_id, symbol, status, verdict, setfile_path,
                        attempt_count, evidence_path, payload_json, created_at, updated_at
                    ) VALUES ('wi1','backtest','Q10','QM5_555002','EURUSD.DWX','done','PASS',
                        'x.set', 1, 'e.json', '{}', ?, ?)
                    """,
                    (farmctl.utc_now(), farmctl.utc_now()),
                )
                conn.commit()
            tid = _insert_task(root, task_type="build_ea", state="PIPELINE",
                               payload={"ea_id": "QM5_555002"})
            agent_router.reconcile_task_exits(root, apply=True)
            self.assertEqual(_state_of(root, tid), "PASSED")

    def test_pipeline_resolves_to_failed_on_q10_fail(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            with agent_router.connect(root) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items(
                        id, kind, phase, ea_id, symbol, status, verdict, setfile_path,
                        attempt_count, evidence_path, payload_json, created_at, updated_at
                    ) VALUES ('wi2','backtest','Q10','QM5_555003','EURUSD.DWX','done','FAIL',
                        'x.set', 1, 'e.json', '{}', ?, ?)
                    """,
                    (farmctl.utc_now(), farmctl.utc_now()),
                )
                conn.commit()
            tid = _insert_task(root, task_type="build_ea", state="PIPELINE",
                               payload={"ea_id": "QM5_555003"})
            agent_router.reconcile_task_exits(root, apply=True)
            self.assertEqual(_state_of(root, tid), "FAILED")

    def test_pipeline_left_in_flight_when_no_closing_verdict(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            with agent_router.connect(root) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items(
                        id, kind, phase, ea_id, symbol, status, verdict, setfile_path,
                        attempt_count, evidence_path, payload_json, created_at, updated_at
                    ) VALUES ('wi3','backtest','Q02','QM5_555004','EURUSD.DWX','pending',NULL,
                        'x.set', 1, NULL, '{}', ?, ?)
                    """,
                    (farmctl.utc_now(), farmctl.utc_now()),
                )
                conn.commit()
            tid = _insert_task(root, task_type="build_ea", state="PIPELINE",
                               payload={"ea_id": "QM5_555004"})
            result = agent_router.reconcile_task_exits(root, apply=True)
            self.assertEqual(_state_of(root, tid), "PIPELINE")
            self.assertIn("pipeline_in_flight_no_closing_verdict", result["left_in_place"])

    def test_recycle_requeues_to_todo_and_increments_count(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            tid = _insert_task(root, task_type="build_ea", state="RECYCLE",
                               payload={"ea_id": "QM5_555005"})
            agent_router.reconcile_task_exits(root, apply=True)
            self.assertEqual(_state_of(root, tid), "TODO")
            self.assertEqual(_payload_of(root, tid)["recycle_count"], 1)

    def test_close_review_records_recycle_once_before_requeue(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            tid = _insert_task(root, task_type="ops_issue", state="REVIEW")
            closed = agent_router.close_review_task(
                root,
                tid,
                close_state="RECYCLE",
                verdict="one bounded delta remains",
            )
            self.assertTrue(closed["closed"])
            review_payload = _payload_of(root, tid)
            self.assertEqual(review_payload["recycle_count"], 1)
            self.assertEqual(
                review_payload["recycle_count_recorded_at_review"],
                review_payload["review_closed_at"],
            )

            agent_router.reconcile_task_exits(root, apply=True)
            self.assertEqual(_state_of(root, tid), "TODO")
            self.assertEqual(_payload_of(root, tid)["recycle_count"], 1)

    def test_recycle_blocks_after_max_attempts(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            tid = _insert_task(root, task_type="build_ea", state="RECYCLE",
                               payload={"ea_id": "QM5_555006",
                                        "recycle_count": agent_router.RECYCLE_MAX_ATTEMPTS})
            agent_router.reconcile_task_exits(root, apply=True)
            self.assertEqual(_state_of(root, tid), "BLOCKED")

    def test_dry_run_moves_nothing_but_reports(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            tid = _insert_task(root, task_type="ops_issue", state="APPROVED")
            result = agent_router.reconcile_task_exits(root, apply=False)
            self.assertEqual(_state_of(root, tid), "APPROVED")  # unchanged
            self.assertEqual(result["moved_count"], 0)
            self.assertIn("APPROVED->PASSED:approved_accepted_terminal", result["would_move"])

    def test_limit_bounds_applied_moves(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            for _ in range(4):
                _insert_task(root, task_type="ops_issue", state="APPROVED")
            result = agent_router.reconcile_task_exits(root, apply=True, limit=2)
            self.assertEqual(result["moved_count"], 2)
            with agent_router.connect(root) as conn:
                still_approved = conn.execute(
                    "SELECT COUNT(*) n FROM agent_tasks WHERE state='APPROVED'"
                ).fetchone()["n"]
            self.assertEqual(still_approved, 2)

    def test_states_filter_only_touches_named_state(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            appr = _insert_task(root, task_type="ops_issue", state="APPROVED")
            recy = _insert_task(root, task_type="build_ea", state="RECYCLE",
                                payload={"ea_id": "QM5_555007"})
            agent_router.reconcile_task_exits(root, apply=True, states=["APPROVED"])
            self.assertEqual(_state_of(root, appr), "PASSED")
            self.assertEqual(_state_of(root, recy), "RECYCLE")  # untouched

    def test_pipeline_run_row_is_blocked(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            tid = _insert_task(root, task_type="pipeline_run", state="RECYCLE")
            agent_router.reconcile_task_exits(root, apply=True)
            self.assertEqual(_state_of(root, tid), "BLOCKED")


class RemovedTaskTypeTests(unittest.TestCase):
    def test_pipeline_run_no_longer_enqueuable(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            with self.assertRaises(ValueError):
                agent_router.enqueue_task(root, "pipeline_run")

    def test_no_enabled_agent_declares_pipeline_capability(self) -> None:
        for cfg in agent_router.DEFAULT_AGENT_REGISTRY.values():
            self.assertNotIn("pipeline", cfg["capabilities"])


class ArtifactFileEnforcementTests(unittest.TestCase):
    def test_safe_defer_cannot_close_review_as_approved(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            evidence = root / "defer.md"
            evidence.write_text("repair deferred", encoding="utf-8")
            created = agent_router.enqueue_task(root, "ops_issue")
            agent_router.update_task(root, created["task_id"], state="REVIEW")
            result = agent_router.close_review_task(
                root,
                created["task_id"],
                close_state="APPROVED",
                verdict="SAFE-DEFER: terminal isolated",
                artifact_path=str(evidence),
            )
            self.assertFalse(result["closed"])
            self.assertEqual(result["reason"], "safe_defer_must_be_blocked")
            self.assertEqual(_state_of(root, created["task_id"]), "REVIEW")

    def test_directory_artifact_rejected_on_update_task(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            a_dir = root / "some_dir"
            a_dir.mkdir()
            created = agent_router.enqueue_task(root, "ops_issue")
            result = agent_router.update_task(root, created["task_id"], state="REVIEW",
                                              artifact_path=str(a_dir))
            self.assertFalse(result["updated"])
            self.assertEqual(result["reason"], "artifact_must_be_file_not_directory")

    def test_directory_artifact_rejected_on_enqueue(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            a_dir = root / "ea_folder"
            a_dir.mkdir()
            with self.assertRaises(ValueError):
                agent_router.enqueue_task(root, "ops_issue", artifact_path=str(a_dir))

    def test_directory_artifact_rejected_on_close_review(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            a_dir = root / "ea_folder"
            a_dir.mkdir()
            created = agent_router.enqueue_task(root, "ops_issue")
            agent_router.update_task(root, created["task_id"], state="REVIEW")
            result = agent_router.close_review_task(root, created["task_id"],
                                                    close_state="APPROVED", verdict="ok",
                                                    artifact_path=str(a_dir))
            self.assertFalse(result["closed"])
            self.assertEqual(result["reason"], "artifact_must_be_file_not_directory")

    def test_multipath_semicolon_files_still_accepted(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            f1 = root / "a.md"; f1.write_text("a", encoding="utf-8")
            f2 = root / "b.md"; f2.write_text("b", encoding="utf-8")
            created = agent_router.enqueue_task(root, "ops_issue")
            result = agent_router.update_task(root, created["task_id"], state="REVIEW",
                                              artifact_path=f"{f1};{f2}")
            self.assertTrue(result["updated"])

    def test_nonexistent_relative_file_path_still_accepted(self) -> None:
        # A not-yet-written file path must not be rejected (artifacts are often
        # recorded before they land); only an existing directory is refused.
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            created = agent_router.enqueue_task(root, "ops_issue")
            result = agent_router.update_task(root, created["task_id"], state="REVIEW",
                                              artifact_path="docs/ops/evidence.md")
            self.assertTrue(result["updated"])


if __name__ == "__main__":
    unittest.main()
