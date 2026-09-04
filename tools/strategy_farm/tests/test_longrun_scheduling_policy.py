"""Tests for the fleet-wide long-run claim-selection cap.

Router task de0f052e-8e04-419a-bfc6-c81ff4362abf, following
docs/ops/evidence/2026-08-24_throughput_forensics.md recommendation 1: cap
all concurrent Q10_NEWS parents at 4, retain the expanded-parent subcap of 2,
and cap concurrent Q07/Q08 long regenerations at 2, fleet-wide, so at least 4
terminals stay available for ordinary short gates/compiles.

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

    def test_standard_news_matrix_classified_for_total_cap(self) -> None:
        cls = policy.classify_longrun_candidate(
            NEWS_PHASE, {"q09_cell_count": 8}, news_phase=NEWS_PHASE
        )
        self.assertEqual(cls, policy.TOTAL_NEWS_PARENT_CLASS)

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
        active_counts = {
            policy.EXPANDED_NEWS_PARENT_CLASS: 1,
            policy.TOTAL_NEWS_PARENT_CLASS: 1,
            policy.Q07_Q08_LONGRUN_CLASS: 0,
        }
        payload = {"force_expanded_news_matrix": True}
        skip, detail = policy.should_skip_for_longrun_cap(
            NEWS_PHASE, payload, active_counts, news_phase=NEWS_PHASE
        )
        self.assertFalse(skip)
        self.assertIsNone(detail)

    def test_fifth_standard_news_skipped_while_four_active(self) -> None:
        active_counts = {
            policy.EXPANDED_NEWS_PARENT_CLASS: 0,
            policy.TOTAL_NEWS_PARENT_CLASS: 4,
            policy.Q07_Q08_LONGRUN_CLASS: 0,
        }
        skip, detail = policy.should_skip_for_longrun_cap(
            NEWS_PHASE, {"q09_cell_count": 8}, active_counts, news_phase=NEWS_PHASE
        )
        self.assertTrue(skip)
        self.assertEqual(detail["longrun_class"], policy.TOTAL_NEWS_PARENT_CLASS)
        self.assertEqual(detail["active_count"], 4)
        self.assertEqual(detail["fleet_cap"], 4)

    def test_fourth_standard_news_admitted_while_three_active(self) -> None:
        active_counts = {
            policy.EXPANDED_NEWS_PARENT_CLASS: 0,
            policy.TOTAL_NEWS_PARENT_CLASS: 3,
            policy.Q07_Q08_LONGRUN_CLASS: 0,
        }
        skip, detail = policy.should_skip_for_longrun_cap(
            NEWS_PHASE, {"q09_cell_count": 8}, active_counts, news_phase=NEWS_PHASE
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
        self.assertEqual(counts[policy.TOTAL_NEWS_PARENT_CLASS], 2)
        self.assertEqual(counts[policy.Q07_Q08_LONGRUN_CLASS], 1)


class ClaimAtomicIntegrationTests(unittest.TestCase):
    """End-to-end: the real claim_atomic loop against a temp farm root."""

    def setUp(self) -> None:
        self._original_commit_headroom_gb = terminal_worker._commit_headroom_gb
        terminal_worker._commit_headroom_gb = lambda: 10_000.0
        # The claim path also reads the REAL host physical-RAM headroom
        # before admitting any candidate. Under fleet memory pressure
        # _free_ram_gb() falls below RAM_MIN_FREE_GB and every candidate that
        # is not long-run-capped is skipped_ram_class, which would mask the
        # behaviour under test. Pin it high; these tests exercise the
        # long-run scheduling cap, not the RAM guard.
        self._original_free_ram_gb = terminal_worker._free_ram_gb
        terminal_worker._free_ram_gb = lambda: 10_000.0
        self.addCleanup(self._restore)
        self.tmp = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "farm"

    def _restore(self) -> None:
        terminal_worker._commit_headroom_gb = self._original_commit_headroom_gb
        terminal_worker._free_ram_gb = self._original_free_ram_gb

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
        # 2026-09-04 (News-Gate A): the stubbed 10_000 GB of free RAM opens the
        # RAM-gated subcap of 3, so a THIRD active expansion is needed before the
        # pending one is refused.
        self._insert("active-2b", "NZDUSD.DWX", phase=terminal_worker._Q09_NEWS_PHASE,
                      status="active", claimed_by="T4", payload=expanded_payload, ea_id="QM5_2b")
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
        self.assertEqual(skipped[0]["fleet_cap"], policy.EXPANDED_NEWS_PARENT_FLEET_CAP_RAM_GATED)
        self.assertTrue(skipped[0]["ram_gated_cap"])

    def test_fifth_standard_news_not_claimed_while_four_active_fleet_wide(self) -> None:
        standard_payload = {
            "q09_cell_count": 8,
            "q09_binding_version": "q09-news-dispatch-binding/v1",
            "q09_run_plan_path": "D:/QM/reports/q09_plans/dummy.json",
            "q09_run_plan_file_sha256": "a" * 64,
            "q09_dispatch_binding_sha256": "b" * 64,
        }
        for index, symbol in enumerate(
            ("EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX"), start=1
        ):
            self._insert(
                f"active-standard-{index}", symbol,
                phase=terminal_worker._Q09_NEWS_PHASE, status="active",
                claimed_by=f"T{index}", payload=standard_payload, ea_id=f"QM5_{index}",
            )
        self._insert(
            "pending-standard-5", "USDCAD.DWX",
            phase=terminal_worker._Q09_NEWS_PHASE, payload=standard_payload, ea_id="QM5_5",
        )

        result = terminal_worker.claim_atomic(self.root, "T5")

        self.assertFalse(result.get("claimed"))
        skipped = result.get("longrun_cap_skipped") or []
        self.assertEqual(skipped[0]["item_id"], "pending-standard-5")
        self.assertEqual(skipped[0]["longrun_class"], policy.TOTAL_NEWS_PARENT_CLASS)

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
        # 2026-09-04 (News-Gate A): the stubbed 10_000 GB of free RAM opens the
        # RAM-gated subcap of 3, so a THIRD active expansion is needed before the
        # pending one is refused.
        self._insert("active-2b", "NZDUSD.DWX", phase=terminal_worker._Q09_NEWS_PHASE,
                      status="active", claimed_by="T4", payload=expanded_payload, ea_id="QM5_2b")
        # A capped-out third expansion AND an ordinary Q03 row are both pending.
        self._insert("pending-expansion", "USDJPY.DWX", phase=terminal_worker._Q09_NEWS_PHASE,
                      status="pending", payload=expanded_payload, ea_id="QM5_3")
        self._insert("pending-short", "AUDUSD.DWX", phase="Q03", status="pending", ea_id="QM5_4")

        result = terminal_worker.claim_atomic(self.root, "T3")

        self.assertTrue(result.get("claimed"))
        self.assertEqual(result["item"]["id"], "pending-short")

    def test_short_row_claimed_instead_of_fifth_standard_news(self) -> None:
        standard_payload = {
            "q09_cell_count": 8,
            "q09_binding_version": "q09-news-dispatch-binding/v1",
            "q09_run_plan_path": "D:/QM/reports/q09_plans/dummy.json",
            "q09_run_plan_file_sha256": "a" * 64,
            "q09_dispatch_binding_sha256": "b" * 64,
        }
        for index, symbol in enumerate(
            ("EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX"), start=1
        ):
            self._insert(
                f"active-standard-{index}", symbol,
                phase=terminal_worker._Q09_NEWS_PHASE, status="active",
                claimed_by=f"T{index}", payload=standard_payload, ea_id=f"QM5_{index}",
            )
        self._insert(
            "pending-standard-5", "USDCAD.DWX",
            phase=terminal_worker._Q09_NEWS_PHASE, payload=standard_payload, ea_id="QM5_5",
        )
        self._insert("pending-short", "XAUUSD.DWX", phase="Q03", ea_id="QM5_6")

        result = terminal_worker.claim_atomic(self.root, "T5")

        self.assertTrue(result.get("claimed"))
        self.assertEqual(result["item"]["id"], "pending-short")

    def test_policy_disabled_allows_fifth_standard_news_to_claim(self) -> None:
        standard_payload = {
            "q09_cell_count": 8,
            "q09_binding_version": "q09-news-dispatch-binding/v1",
            "q09_run_plan_path": "D:/QM/reports/q09_plans/dummy.json",
            "q09_run_plan_file_sha256": "a" * 64,
            "q09_dispatch_binding_sha256": "b" * 64,
        }
        for index, symbol in enumerate(
            ("EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX"), start=1
        ):
            self._insert(
                f"active-standard-{index}", symbol,
                phase=terminal_worker._Q09_NEWS_PHASE, status="active",
                claimed_by=f"T{index}", payload=standard_payload, ea_id=f"QM5_{index}",
            )
        self._insert(
            "pending-standard-5", "USDCAD.DWX",
            phase=terminal_worker._Q09_NEWS_PHASE, payload=standard_payload, ea_id="QM5_5",
        )

        with patch.dict("os.environ", {policy.DISABLE_ENV_VAR: "1"}):
            result = terminal_worker.claim_atomic(self.root, "T5")

        self.assertTrue(result.get("claimed"))
        self.assertEqual(result["item"]["id"], "pending-standard-5")

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


class LineageRerunExtraSlotTests(unittest.TestCase):
    """2026-09-03: a priority-tracked exact lineage rerun (Amendment B row) may
    take one Q07/Q08 slot above the cap; ordinary rows, unmarked reruns and
    quarantined lineages keep the cap of 2."""

    def _counts(self, q07_q08_active: int) -> dict[str, int]:
        return {
            policy.EXPANDED_NEWS_PARENT_CLASS: 0,
            policy.TOTAL_NEWS_PARENT_CLASS: 0,
            policy.Q07_Q08_LONGRUN_CLASS: q07_q08_active,
        }

    def test_lineage_rerun_takes_third_slot(self) -> None:
        payload = {"append_only_rerun": True, "priority_track": True}
        skip, detail = policy.should_skip_for_longrun_cap(
            "Q07", payload, self._counts(2), news_phase=NEWS_PHASE
        )
        self.assertFalse(skip)
        self.assertIsNone(detail)

    def test_lineage_rerun_bounded_at_cap_plus_one(self) -> None:
        payload = {"append_only_rerun": 1, "priority_track": True}
        skip, detail = policy.should_skip_for_longrun_cap(
            "Q08", payload, self._counts(3), news_phase=NEWS_PHASE
        )
        self.assertTrue(skip)
        self.assertEqual(detail["fleet_cap"], policy.Q07_Q08_LONGRUN_FLEET_CAP + 1)

    def test_ordinary_q07_row_keeps_cap_of_two(self) -> None:
        for payload in ({}, {"priority_track": True}, {"append_only_rerun": True},
                        {"append_only_rerun": True, "priority_track": True,
                         "poison_pill_priority_override": 1}):
            skip, detail = policy.should_skip_for_longrun_cap(
                "Q07", payload, self._counts(2), news_phase=NEWS_PHASE
            )
            self.assertTrue(skip, payload)
            self.assertEqual(detail["fleet_cap"], policy.Q07_Q08_LONGRUN_FLEET_CAP)

    def test_news_caps_unchanged_for_lineage_reruns(self) -> None:
        payload = {"append_only_rerun": True, "priority_track": True}
        counts = self._counts(0)
        counts[policy.TOTAL_NEWS_PARENT_CLASS] = policy.TOTAL_NEWS_PARENT_FLEET_CAP
        skip, _detail = policy.should_skip_for_longrun_cap(
            NEWS_PHASE, payload, counts, news_phase=NEWS_PHASE
        )
        self.assertTrue(skip)


class ExpandedNewsRamGatedCapTests(unittest.TestCase):
    """2026-09-04 (Auffangregel News-Gate A): the expansion subcap rises 2 -> 3
    only while the caller reports >= 10 GB free RAM; without a snapshot or
    below the gate the cap of 2 stands, and the combined news cap is untouched."""

    def _counts(self, expanded: int, total: int | None = None) -> dict[str, int]:
        return {
            policy.EXPANDED_NEWS_PARENT_CLASS: expanded,
            policy.TOTAL_NEWS_PARENT_CLASS: expanded if total is None else total,
            policy.Q07_Q08_LONGRUN_CLASS: 0,
        }

    def _expansion_payload(self) -> dict:
        return {"force_expanded_news_matrix": True}

    def _is_expansion(self) -> bool:
        return policy.classify_longrun_candidate(
            NEWS_PHASE, self._expansion_payload(), news_phase=NEWS_PHASE
        ) == policy.EXPANDED_NEWS_PARENT_CLASS

    def test_cap_stays_two_without_ram_snapshot(self) -> None:
        if not self._is_expansion():
            self.skipTest("expansion payload marker differs in this build")
        skip, detail = policy.should_skip_for_longrun_cap(
            NEWS_PHASE, self._expansion_payload(), self._counts(2), news_phase=NEWS_PHASE
        )
        self.assertTrue(skip)
        self.assertEqual(detail["fleet_cap"], policy.EXPANDED_NEWS_PARENT_FLEET_CAP)
        self.assertNotIn("ram_gated_cap", detail)

    def test_cap_stays_two_below_ram_gate(self) -> None:
        if not self._is_expansion():
            self.skipTest("expansion payload marker differs in this build")
        skip, detail = policy.should_skip_for_longrun_cap(
            NEWS_PHASE, self._expansion_payload(), self._counts(2),
            news_phase=NEWS_PHASE, free_ram_gb=policy.EXPANDED_NEWS_PARENT_RAM_GATE_GB - 0.1,
        )
        self.assertTrue(skip)
        self.assertEqual(detail["fleet_cap"], 2)

    def test_cap_rises_to_three_with_ram_headroom(self) -> None:
        if not self._is_expansion():
            self.skipTest("expansion payload marker differs in this build")
        skip, detail = policy.should_skip_for_longrun_cap(
            NEWS_PHASE, self._expansion_payload(), self._counts(2),
            news_phase=NEWS_PHASE, free_ram_gb=policy.EXPANDED_NEWS_PARENT_RAM_GATE_GB,
        )
        self.assertFalse(skip)
        self.assertIsNone(detail)
        skip3, detail3 = policy.should_skip_for_longrun_cap(
            NEWS_PHASE, self._expansion_payload(), self._counts(3),
            news_phase=NEWS_PHASE, free_ram_gb=20.0,
        )
        self.assertTrue(skip3)
        self.assertEqual(detail3["fleet_cap"], 3)
        self.assertTrue(detail3["ram_gated_cap"])

    def test_total_news_cap_unchanged_by_ram_gate(self) -> None:
        if not self._is_expansion():
            self.skipTest("expansion payload marker differs in this build")
        counts = self._counts(2, total=policy.TOTAL_NEWS_PARENT_FLEET_CAP)
        skip, detail = policy.should_skip_for_longrun_cap(
            NEWS_PHASE, self._expansion_payload(), counts, news_phase=NEWS_PHASE, free_ram_gb=30.0,
        )
        self.assertTrue(skip)
        self.assertEqual(detail["longrun_class"], policy.TOTAL_NEWS_PARENT_CLASS)
        self.assertEqual(detail["fleet_cap"], policy.TOTAL_NEWS_PARENT_FLEET_CAP)


class LegacyNewsLaneTests(unittest.TestCase):
    """2026-09-04: rows stored under the v3 lane name Q09_NEWS must count as
    news-class long runs for classification and for the active counts."""

    def test_legacy_news_lane_classified_as_news(self) -> None:
        self.assertEqual(
            policy.classify_longrun_candidate("Q09_NEWS", {}, news_phase=NEWS_PHASE),
            policy.TOTAL_NEWS_PARENT_CLASS,
        )
        self.assertEqual(
            policy.classify_longrun_candidate(
                "Q09_NEWS", {"force_expanded_news_matrix": True}, news_phase=NEWS_PHASE
            ),
            policy.EXPANDED_NEWS_PARENT_CLASS,
        )
        self.assertIsNone(policy.classify_longrun_candidate("Q06", {}, news_phase=NEWS_PHASE))

    def test_legacy_news_rows_counted_in_active_counts(self) -> None:
        import sqlite3 as _sqlite3
        conn = _sqlite3.connect(":memory:")
        conn.row_factory = _sqlite3.Row
        conn.execute("CREATE TABLE work_items(id TEXT, phase TEXT, status TEXT, payload_json TEXT)")
        rows = [
            ("a", "Q09_NEWS", "active", "{}"),
            ("b", "Q09_NEWS", "active", '{"force_expanded_news_matrix": true}'),
            ("c", NEWS_PHASE, "active", "{}"),
            ("d", "Q07", "active", "{}"),
            ("e", "Q09_NEWS", "pending", "{}"),
            ("f", "SOMETHING_NEWSY", "active", "{}"),
        ]
        conn.executemany("INSERT INTO work_items VALUES(?,?,?,?)", rows)
        counts = policy.active_longrun_counts(conn, news_phase=NEWS_PHASE)
        self.assertEqual(counts[policy.TOTAL_NEWS_PARENT_CLASS], 3)
        self.assertEqual(counts[policy.EXPANDED_NEWS_PARENT_CLASS], 1)
        self.assertEqual(counts[policy.Q07_Q08_LONGRUN_CLASS], 1)


if __name__ == "__main__":
    unittest.main()


class MeasuredRamCapTests(unittest.TestCase):
    """2026-09-04 18:50Z: a new long run is refused while the measured RAM of
    the active long runs is at or above LONG_RUN_RAM_CAP_GB; Q09 stress runs
    are classified (RAM-gated only, no count cap)."""

    def _skip(self, phase, ram, counts=None, payload="{}"):
        return policy.should_skip_for_longrun_cap(
            phase, payload, counts or {}, news_phase="Q10_NEWS",
            q07_phase="Q07", q08_phase="Q08", q09_phase="Q09",
            enabled=True, long_run_ram_gb=ram,
        )

    def test_q09_classified_without_count_cap(self) -> None:
        self.assertEqual(
            policy.classify_longrun_candidate("Q09", "{}", news_phase="Q10_NEWS"),
            policy.Q09_STRESS_LONGRUN_CLASS,
        )
        self.assertEqual(policy.fleet_cap_for_class(policy.Q09_STRESS_LONGRUN_CLASS), policy.NO_COUNT_CAP)
        skip, _ = self._skip("Q09", 12.0, {policy.Q09_STRESS_LONGRUN_CLASS: 5})
        self.assertFalse(skip)

    def test_new_long_run_refused_at_or_above_the_ram_cap(self) -> None:
        for phase in ("Q07", "Q08", "Q09", "Q10_NEWS"):
            skip, detail = self._skip(phase, policy.LONG_RUN_RAM_CAP_GB)
            self.assertTrue(skip, phase)
            self.assertEqual(detail["long_run_ram_cap_gb"], policy.LONG_RUN_RAM_CAP_GB)
            self.assertAlmostEqual(detail["long_run_ram_gb"], policy.LONG_RUN_RAM_CAP_GB)
        skip, detail = self._skip("Q07", 38.5)
        self.assertTrue(skip)
        self.assertEqual(detail["longrun_class"], policy.Q07_Q08_LONGRUN_CLASS)

    def test_long_run_admitted_below_the_ram_cap_and_without_a_snapshot(self) -> None:
        skip, _ = self._skip("Q07", policy.LONG_RUN_RAM_CAP_GB - 0.1)
        self.assertFalse(skip)
        skip, _ = self._skip("Q07", None)
        self.assertFalse(skip)

    def test_ordinary_rows_ignore_the_ram_cap(self) -> None:
        for phase in ("Q02", "Q04", "OPT_CENSUS", "Q12"):
            skip, _ = self._skip(phase, 60.0)
            self.assertFalse(skip, phase)

    def test_lineage_rerun_is_also_ram_capped(self) -> None:
        payload = '{"append_only_rerun": true, "priority_track": true}'
        skip, detail = self._skip("Q07", 30.0, payload=payload)
        self.assertTrue(skip)
        self.assertEqual(detail["longrun_class"], policy.Q07_Q08_LONGRUN_CLASS)

    def test_active_counts_include_q09(self) -> None:
        import sqlite3 as _sqlite3
        con = _sqlite3.connect(":memory:")
        con.row_factory = _sqlite3.Row
        con.execute("CREATE TABLE work_items (id TEXT, phase TEXT, status TEXT, payload_json TEXT)")
        con.executemany(
            "INSERT INTO work_items VALUES (?,?,?,?)",
            [("a", "Q09", "active", "{}"), ("b", "Q09", "done", "{}"), ("c", "Q07", "active", "{}")],
        )
        counts = policy.active_longrun_counts(con, news_phase="Q10_NEWS", q07_phase="Q07", q08_phase="Q08", q09_phase="Q09")
        self.assertEqual(counts[policy.Q09_STRESS_LONGRUN_CLASS], 1)
        self.assertEqual(counts[policy.Q07_Q08_LONGRUN_CLASS], 1)

