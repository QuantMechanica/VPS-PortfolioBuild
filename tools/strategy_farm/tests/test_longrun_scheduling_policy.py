"""Tests for the fleet-wide long-run claim-selection cap.

Router task de0f052e-8e04-419a-bfc6-c81ff4362abf, following
docs/ops/evidence/2026-08-24_throughput_forensics.md recommendation 1: cap
concurrent 29-cell expanded Q10_NEWS parents at 2 and concurrent Q07/Q08
long regenerations at 2, fleet-wide, so at least 6 terminals stay available
for ordinary short gates/compiles.

Covers the acceptance criteria: (1) unit coverage of the pure classify/skip
functions including the literal "3rd expansion not claimed while 2 active"
case; (2) an end-to-end `terminal_worker.claim_atomic` integration test
proving short rows are not displaced by long-run occupancy (the floor);
(3) the QM_DISABLE_LONGRUN_SCHEDULING_CAP config-flag rollback switch.
"""

from __future__ import annotations

import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402
import longrun_scheduling_policy as policy  # noqa: E402

NEWS_PHASE = "Q10_NEWS"


class ClassifyAndCapTests(unittest.TestCase):
    def test_expanded_news_matrix_classified(self) -> None:
        cls = policy.classify_longrun_candidate(
            NEWS_PHASE, {"force_expanded_news_matrix": True}, news_phase=NEWS_PHASE
        )
        self.assertEqual(cls, policy.EXPANDED_NEWS_PARENT_CLASS)

    def test_standard_news_matrix_not_classified(self) -> None:
        cls = policy.classify_longrun_candidate(
            NEWS_PHASE, {"q09_cell_count": 8}, news_phase=NEWS_PHASE
        )
        self.assertIsNone(cls)

    def test_q07_and_q08_classified(self) -> None:
        self.assertEqual(
            policy.classify_longrun_candidate("Q07", {}, news_phase=NEWS_PHASE),
            policy.Q07_Q08_LONGRUN_CLASS,
        )
        self.assertEqual(
            policy.classify_longrun_candidate("Q08", {}, news_phase=NEWS_PHASE),
            policy.Q07_Q08_LONGRUN_CLASS,
        )

    def test_ordinary_phase_not_classified(self) -> None:
        self.assertIsNone(
            policy.classify_longrun_candidate("Q03", {}, news_phase=NEWS_PHASE)
        )

    def test_third_expansion_skipped_while_two_active(self) -> None:
        """The literal acceptance case: 3 pending expansions, 2 already active."""
        active_counts = {policy.EXPANDED_NEWS_PARENT_CLASS: 2, policy.Q07_Q08_LONGRUN_CLASS: 0}
        payload = {"force_expanded_news_matrix": True}
        skip, detail = policy.should_skip_for_longrun_cap(
            NEWS_PHASE, payload, active_counts, news_phase=NEWS_PHASE
        )
        self.assertTrue(skip)
        self.assertEqual(detail["longrun_class"], policy.EXPANDED_NEWS_PARENT_CLASS)
        self.assertEqual(detail["active_count"], 2)
        self.assertEqual(detail["fleet_cap"], 2)

    def test_second_expansion_admitted_while_one_active(self) -> None:
        active_counts = {policy.EXPANDED_NEWS_PARENT_CLASS: 1, policy.Q07_Q08_LONGRUN_CLASS: 0}
        payload = {"force_expanded_news_matrix": True}
        skip, detail = policy.should_skip_for_longrun_cap(
            NEWS_PHASE, payload, active_counts, news_phase=NEWS_PHASE
        )
        self.assertFalse(skip)
        self.assertIsNone(detail)

    def test_third_q07_q08_skipped_while_two_active(self) -> None:
        active_counts = {policy.EXPANDED_NEWS_PARENT_CLASS: 0, policy.Q07_Q08_LONGRUN_CLASS: 2}
        skip, detail = policy.should_skip_for_longrun_cap(
            "Q08", {}, active_counts, news_phase=NEWS_PHASE
        )
        self.assertTrue(skip)
        self.assertEqual(detail["longrun_class"], policy.Q07_Q08_LONGRUN_CLASS)

    def test_ordinary_row_never_skipped_regardless_of_active_counts(self) -> None:
        active_counts = {policy.EXPANDED_NEWS_PARENT_CLASS: 5, policy.Q07_Q08_LONGRUN_CLASS: 5}
        skip, detail = policy.should_skip_for_longrun_cap(
            "Q03", {}, active_counts, news_phase=NEWS_PHASE
        )
        self.assertFalse(skip)
        self.assertIsNone(detail)

    def test_disabled_policy_never_skips(self) -> None:
        active_counts = {policy.EXPANDED_NEWS_PARENT_CLASS: 99, policy.Q07_Q08_LONGRUN_CLASS: 99}
        skip, detail = policy.should_skip_for_longrun_cap(
            NEWS_PHASE,
            {"force_expanded_news_matrix": True},
            active_counts,
            news_phase=NEWS_PHASE,
            enabled=False,
        )
        self.assertFalse(skip)
        self.assertIsNone(detail)

    def test_policy_enabled_reads_env_flag(self) -> None:
        with patch.dict("os.environ", {policy.DISABLE_ENV_VAR: "1"}):
            self.assertFalse(policy.policy_enabled())
        with patch.dict("os.environ", {}, clear=False):
            import os

            os.environ.pop(policy.DISABLE_ENV_VAR, None)
            self.assertTrue(policy.policy_enabled())


class ActiveLongrunCountsDbTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "farm"
        farmctl.init_db(self.root)

    def _insert(self, item_id: str, *, phase: str, status: str, payload: dict) -> None:
        now = farmctl.utc_now()
        with sqlite3.connect(self.root / farmctl.DB_REL) as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   attempt_count, parent_task_id, evidence_path, claimed_by,
                   payload_json, created_at, updated_at)
                VALUES (?, 'backtest', ?, 'QM5_1', ?, 'dummy.set', ?, NULL,
                        0, NULL, NULL, 'T1', ?, ?, ?)
                """,
                (item_id, phase, item_id, status, json.dumps(payload), now, now),
            )
            conn.commit()

    def test_counts_only_active_rows(self) -> None:
        self._insert("a1", phase=NEWS_PHASE, status="active", payload={"force_expanded_news_matrix": True})
        self._insert("a2", phase=NEWS_PHASE, status="pending", payload={"force_expanded_news_matrix": True})
        self._insert("a3", phase="Q08", status="active", payload={})
        self._insert("a4", phase=NEWS_PHASE, status="active", payload={"q09_cell_count": 8})
        with sqlite3.connect(self.root / farmctl.DB_REL) as conn:
            conn.row_factory = sqlite3.Row
            counts = policy.active_longrun_counts(conn, news_phase=NEWS_PHASE)
        self.assertEqual(counts[policy.EXPANDED_NEWS_PARENT_CLASS], 1)
        self.assertEqual(counts[policy.Q07_Q08_LONGRUN_CLASS], 1)


class ClaimAtomicIntegrationTests(unittest.TestCase):
    """End-to-end: the real claim_atomic loop against a temp farm root."""

    def setUp(self) -> None:
        self._original_commit_headroom_gb = terminal_worker._commit_headroom_gb
        terminal_worker._commit_headroom_gb = lambda: 10_000.0
        self.addCleanup(self._restore)
        self.tmp = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "farm"

    def _restore(self) -> None:
        terminal_worker._commit_headroom_gb = self._original_commit_headroom_gb

    def _insert(
        self,
        item_id: str,
        symbol: str,
        *,
        phase: str,
        status: str = "pending",
        claimed_by: str | None = None,
        payload: dict | None = None,
        ea_id: str = "QM5_9999",
    ) -> None:
        farmctl.init_db(self.root)
        now = farmctl.utc_now()
        with sqlite3.connect(self.root / farmctl.DB_REL) as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   attempt_count, parent_task_id, evidence_path, claimed_by,
                   payload_json, created_at, updated_at)
                VALUES (?, 'backtest', ?, ?, ?, 'dummy.set', ?, NULL,
                        0, NULL, NULL, ?, ?, ?, ?)
                """,
                (
                    item_id, phase, ea_id, symbol, status, claimed_by,
                    json.dumps(payload or {}), now, now,
                ),
            )
            conn.commit()

    def test_third_expansion_not_claimed_while_two_active_fleet_wide(self) -> None:
        expanded_payload = {
            "force_expanded_news_matrix": True,
            "q09_binding_version": "q09-news-dispatch-binding/v1",
            "q09_run_plan_path": "D:/QM/reports/q09_plans/dummy.json",
            "q09_run_plan_file_sha256": "a" * 64,
            "q09_dispatch_binding_sha256": "b" * 64,
        }
        # Two already active elsewhere in the fleet.
        self._insert("active-1", "EURUSD.DWX", phase=terminal_worker._Q09_NEWS_PHASE,
                      status="active", claimed_by="T1", payload=expanded_payload, ea_id="QM5_1")
        self._insert("active-2", "GBPUSD.DWX", phase=terminal_worker._Q09_NEWS_PHASE,
                      status="active", claimed_by="T2", payload=expanded_payload, ea_id="QM5_2")
        # A third pending expansion is the only claimable candidate for T3.
        self._insert("pending-3", "USDJPY.DWX", phase=terminal_worker._Q09_NEWS_PHASE,
                      status="pending", payload=expanded_payload, ea_id="QM5_3")

        result = terminal_worker.claim_atomic(self.root, "T3")

        self.assertFalse(result.get("claimed"))
        self.assertEqual(result.get("reason"), "no_pending_claimable")
        skipped = result.get("longrun_cap_skipped") or []
        self.assertEqual(len(skipped), 1)
        self.assertEqual(skipped[0]["item_id"], "pending-3")
        self.assertEqual(skipped[0]["longrun_class"], policy.EXPANDED_NEWS_PARENT_CLASS)

    def test_short_row_not_displaced_by_capped_longrun_row(self) -> None:
        """Floor case: an ordinary short row is claimed even though a
        capped-out expansion sorts ahead of it in priority order."""
        expanded_payload = {
            "force_expanded_news_matrix": True,
            "q09_binding_version": "q09-news-dispatch-binding/v1",
            "q09_run_plan_path": "D:/QM/reports/q09_plans/dummy.json",
            "q09_run_plan_file_sha256": "a" * 64,
            "q09_dispatch_binding_sha256": "b" * 64,
        }
        self._insert("active-1", "EURUSD.DWX", phase=terminal_worker._Q09_NEWS_PHASE,
                      status="active", claimed_by="T1", payload=expanded_payload, ea_id="QM5_1")
        self._insert("active-2", "GBPUSD.DWX", phase=terminal_worker._Q09_NEWS_PHASE,
                      status="active", claimed_by="T2", payload=expanded_payload, ea_id="QM5_2")
        # A capped-out third expansion AND an ordinary Q03 row are both pending.
        self._insert("pending-expansion", "USDJPY.DWX", phase=terminal_worker._Q09_NEWS_PHASE,
                      status="pending", payload=expanded_payload, ea_id="QM5_3")
        self._insert("pending-short", "AUDUSD.DWX", phase="Q03", status="pending", ea_id="QM5_4")

        result = terminal_worker.claim_atomic(self.root, "T3")

        self.assertTrue(result.get("claimed"))
        self.assertEqual(result["item"]["id"], "pending-short")

    def test_policy_disabled_allows_third_expansion_to_claim(self) -> None:
        expanded_payload = {
            "force_expanded_news_matrix": True,
            "q09_binding_version": "q09-news-dispatch-binding/v1",
            "q09_run_plan_path": "D:/QM/reports/q09_plans/dummy.json",
            "q09_run_plan_file_sha256": "a" * 64,
            "q09_dispatch_binding_sha256": "b" * 64,
        }
        self._insert("active-1", "EURUSD.DWX", phase=terminal_worker._Q09_NEWS_PHASE,
                      status="active", claimed_by="T1", payload=expanded_payload, ea_id="QM5_1")
        self._insert("active-2", "GBPUSD.DWX", phase=terminal_worker._Q09_NEWS_PHASE,
                      status="active", claimed_by="T2", payload=expanded_payload, ea_id="QM5_2")
        self._insert("pending-3", "USDJPY.DWX", phase=terminal_worker._Q09_NEWS_PHASE,
                      status="pending", payload=expanded_payload, ea_id="QM5_3")

        with patch.dict("os.environ", {policy.DISABLE_ENV_VAR: "1"}):
            result = terminal_worker.claim_atomic(self.root, "T3")

        self.assertTrue(result.get("claimed"))
        self.assertEqual(result["item"]["id"], "pending-3")


if __name__ == "__main__":
    unittest.main()
