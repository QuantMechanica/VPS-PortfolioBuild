from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm import agent_router
from tools.strategy_farm import farmctl


class AgentRouterTests(unittest.TestCase):
    def _write_ready_card(self, path: Path, ea_id: str, slug: str) -> None:
        path.write_text(
            f"""---
ea_id: {ea_id}
slug: {slug}
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 12
---
# Ready Card

Thesis: monthly event drift.
Universe: XAUUSD.DWX
Timeframe: D1
Entry: enter on event window.
Exit: exit after window.
Risk: fixed fractional.
Filters: news blackout is mandatory; no optional regime or volatility filter.
Falsification: fail if PF below threshold.
Q08/Q11 risks: event concentration and news robustness.
Implementation notes: simple MQL5 date filter and narrow setfile.
""",
            encoding="utf-8",
        )

    def test_next_action_routes_active_research_away_from_disabled_claude(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            (root / "CLAUDE_DISABLED.flag").write_text("disabled\n", encoding="utf-8")
            farmctl.init_db(root)
            with farmctl.connect(root) as conn:
                conn.execute(
                    """
                    INSERT INTO sources(id, source_type, uri, title, priority, lane, status, notes_path, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        "src-1",
                        "web_blog",
                        "https://example.test/strategy",
                        "Example source",
                        10,
                        "research",
                        "active",
                        None,
                        farmctl.utc_now(),
                        farmctl.utc_now(),
                    ),
                )
                conn.commit()

            action = farmctl.next_action(root)
            self.assertEqual(action["action"], "research_active_source")
            self.assertEqual(action["role"], "Codex")
            self.assertIn("CLAUDE_DISABLED.flag", action["routing_reason"])

    def test_claude_disabled_flag_removes_claude_from_routing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            flag = root / "CLAUDE_DISABLED.flag"
            flag.write_text("disabled\n", encoding="utf-8")

            result = agent_router.sync_default_registry(root, claude_disabled_flag=flag)
            self.assertTrue(result["claude_disabled"])
            status = agent_router.status(root)
            claude = next(agent for agent in status["agents"] if agent["agent_id"] == "claude")
            self.assertFalse(claude["enabled"])
            self.assertEqual(claude["max_parallel"], 0)

    def test_claude_enabled_cap_is_three(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            agent_router.sync_default_registry(root, claude_disabled_flag=root / "missing.flag")
            status = agent_router.status(root, claude_disabled_flag=root / "missing.flag")
            claude = next(agent for agent in status["agents"] if agent["agent_id"] == "claude")
            self.assertTrue(claude["enabled"])
            self.assertEqual(claude["max_parallel"], 3)

    def test_routes_by_capability_and_wip_limit(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            agent_router.sync_default_registry(root, claude_disabled_flag=root / "missing.flag")
            build = agent_router.enqueue_task(root, "build_ea", priority=10)
            research = agent_router.enqueue_task(root, "research_strategy", priority=20)

            first = agent_router.route_once(root)
            second = agent_router.route_once(root)

            self.assertEqual(first.task_id, build["task_id"])
            self.assertEqual(first.assigned_agent, "codex")
            self.assertEqual(second.task_id, research["task_id"])
            self.assertEqual(second.assigned_agent, "gemini")

    def test_route_once_skips_temporarily_unavailable_head_task(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            agent_router.sync_default_registry(root, claude_disabled_flag=root / "missing.flag")
            blocked = agent_router.enqueue_task(
                root,
                "research_strategy",
                priority=5,
                required_capabilities=["research", "strategy", "source_discovery"],
            )
            for _ in range(2):
                filler = agent_router.enqueue_task(
                    root,
                    "research_strategy",
                    priority=1,
                    required_capabilities=["research", "strategy", "source_discovery"],
                )
                decision = agent_router.route_once(root, claude_disabled_flag=root / "missing.flag")
                self.assertEqual(decision.assigned_agent, "gemini")
                self.assertEqual(decision.task_id, filler["task_id"])

            ops = agent_router.enqueue_task(root, "ops_issue", priority=10)
            decision = agent_router.route_once(root, claude_disabled_flag=root / "missing.flag")

            self.assertEqual(decision.task_id, ops["task_id"])
            self.assertEqual(decision.assigned_agent, "codex")
            self.assertNotEqual(decision.task_id, blocked["task_id"])

    def test_replenish_is_frozen_when_card_pool_low(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            result = agent_router.replenish(
                root,
                min_ready_strategy_cards=2,
                claude_disabled_flag=root / "missing.flag",
            )
            self.assertTrue(result["frozen"])
            self.assertEqual(result["created"], [])
            self.assertEqual(agent_router.status(root)["tasks"], [])

    def test_replenish_freeze_reports_inventory_without_creating_tasks(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            result = agent_router.replenish(
                root,
                min_ready_strategy_cards=3,
                claude_disabled_flag=root / "missing.flag",
            )

            self.assertEqual(result["ready_strategy_cards"], 0)
            self.assertEqual(result["created"], [])
            self.assertTrue(result["frozen"])
            self.assertEqual(agent_router.list_tasks(root), [])

    def test_replenish_pauses_research_when_card_pool_is_sufficient(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            approved = root / "artifacts" / "cards_approved"
            approved.mkdir(parents=True)
            for idx in range(5):
                self._write_ready_card(
                    approved / f"QM5_TEST_{idx}_ready-card-{idx}.md",
                    f"QM5_TEST_{idx}",
                    f"ready-card-{idx}",
                )

            result = agent_router.replenish(
                root,
                min_ready_strategy_cards=5,
                claude_disabled_flag=root / "missing.flag",
            )

            self.assertEqual(result["ready_strategy_cards"], 5)
            self.assertEqual(result["created"], [])
            self.assertTrue(result["frozen"])
            self.assertEqual(agent_router.status(root)["tasks"], [])

    def test_run_once_does_not_replenish_generic_research(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            result = agent_router.run_once(
                root,
                min_ready_strategy_cards=3,
                max_routes=5,
                claude_disabled_flag=root / "missing.flag",
            )

            self.assertEqual(result["replenish"]["created"], [])
            self.assertTrue(result["replenish"]["frozen"])
            assigned = [r for r in result["routes"] if r["reason"] == "assigned"]
            self.assertEqual(assigned, [])
            self.assertEqual(agent_router.status(root)["tasks"], [])

    def test_friday_smoke_tasks_route_to_all_three_workers_when_enabled(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            agent_router.sync_default_registry(root, claude_disabled_flag=root / "missing.flag")
            created = agent_router.enqueue_friday_smoke_tasks(root, claude_disabled_flag=root / "missing.flag")
            self.assertEqual(len(created["created"]), 3)

            routed = agent_router.route_many(root, max_routes=5, claude_disabled_flag=root / "missing.flag")
            assigned = {row["assigned_agent"] for row in routed if row["reason"] == "assigned"}

            self.assertEqual(assigned, {"codex", "gemini", "claude"})

    def test_friday_smoke_skips_disabled_and_existing_targets(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            flag = root / "claude.disabled"
            flag.write_text("off", encoding="utf-8")

            first = agent_router.enqueue_friday_smoke_tasks(root, claude_disabled_flag=flag)
            second = agent_router.enqueue_friday_smoke_tasks(root, claude_disabled_flag=flag)

            self.assertEqual(len(first["created"]), 2)
            self.assertIn({"agent": "claude", "reason": "agent_disabled"}, first["skipped"])
            self.assertEqual(len(second["created"]), 0)
            self.assertIn({"agent": "codex", "reason": "already_open"}, second["skipped"])

    def test_update_task_records_artifact_verdict_and_state(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            created = agent_router.enqueue_task(root, "ops_issue", priority=10)

            result = agent_router.update_task(
                root,
                created["task_id"],
                state="REVIEW",
                artifact_path="docs/ops/evidence.md",
                verdict="READY_FOR_REVIEW",
            )

            self.assertTrue(result["updated"])
            task = agent_router.list_tasks(root)[0]
            self.assertEqual(task["state"], "REVIEW")
            self.assertEqual(task["id"], created["task_id"])

    def test_close_review_requires_existing_artifact_for_approval(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            created = agent_router.enqueue_task(root, "ops_issue", priority=10)
            agent_router.update_task(root, created["task_id"], state="REVIEW")

            missing = agent_router.close_review_task(
                root,
                created["task_id"],
                close_state="APPROVED",
                verdict="OK",
                artifact_path=str(root / "missing.md"),
            )
            self.assertFalse(missing["closed"])
            self.assertEqual(missing["reason"], "artifact_missing")

            artifact = root / "artifact.md"
            artifact.write_text("done\n", encoding="utf-8")
            closed = agent_router.close_review_task(
                root,
                created["task_id"],
                close_state="APPROVED",
                verdict="OK",
                artifact_path=str(artifact),
            )
            self.assertTrue(closed["closed"])
            self.assertEqual(agent_router.list_tasks(root)[0]["state"], "APPROVED")

    def test_sync_q11_candidates_mirrors_p8_pass_work_items(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            with agent_router.connect(root) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items(
                        id, kind, phase, ea_id, symbol, status, verdict,
                        setfile_path, attempt_count, evidence_path, payload_json, created_at, updated_at
                    )
                    VALUES (
                        'wi-q11-pass', 'backtest', 'P8', 'QM5_999001', 'EURUSD.DWX',
                        'done', 'PASS', 'D:/QM/sets/test.set', 1, 'D:/QM/reports/x/summary.json',
                        '{}', '2026-05-21T00:00:00+00:00', '2026-05-21T00:00:00+00:00'
                    )
                    """
                )
                conn.commit()

            first = agent_router.sync_q11_candidates(root)
            second = agent_router.sync_q11_candidates(root)

            self.assertEqual(first["created"], 1)
            self.assertEqual(second["created"], 0)
            self.assertEqual(second["existing"], 1)

    def test_research_task_cannot_return_card_directly_to_approved_pool(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            approved = root / "artifacts" / "cards_approved"
            approved.mkdir(parents=True)
            created = agent_router.enqueue_task(root, "research_strategy", priority=10)

            result = agent_router.update_task(
                root,
                created["task_id"],
                state="REVIEW",
                artifact_path=str(approved / "QM5_900001_bad.md"),
                verdict="RESEARCH_DRAFT_READY",
            )

            self.assertFalse(result["updated"])
            self.assertEqual(result["reason"], "research_artifact_must_use_cards_review")

    def test_research_review_card_rejects_duplicate_fingerprint(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            approved = root / "artifacts" / "cards_approved"
            review = root / "artifacts" / "cards_review"
            approved.mkdir(parents=True)
            review.mkdir(parents=True)
            self._write_ready_card(approved / "QM5_900001_ready-card.md", "QM5_900001", "ready-card")
            self._write_ready_card(review / "QM5_900002_ready-card.md", "QM5_900002", "ready-card")
            created = agent_router.enqueue_task(root, "research_strategy", priority=10)

            result = agent_router.update_task(
                root,
                created["task_id"],
                state="REVIEW",
                artifact_path=str(review / "QM5_900002_ready-card.md"),
                verdict="RESEARCH_DRAFT_READY",
            )

            self.assertFalse(result["updated"])
            self.assertEqual(result["reason"], "duplicate_strategy_card_fingerprint")

    def test_research_review_card_requires_schema(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            review = root / "artifacts" / "cards_review"
            review.mkdir(parents=True)
            card = review / "QM5_900003_thin.md"
            card.write_text(
                """---
ea_id: QM5_900003
slug: thin
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 12
---
# Thin
""",
                encoding="utf-8",
            )
            created = agent_router.enqueue_task(root, "research_strategy", priority=10)

            result = agent_router.update_task(
                root,
                created["task_id"],
                state="REVIEW",
                artifact_path=str(card),
                verdict="RESEARCH_DRAFT_READY",
            )

            self.assertFalse(result["updated"])
            self.assertEqual(result["reason"], "strategy_card_schema_failed")

    def test_research_review_card_requires_filters_block(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            review = root / "artifacts" / "cards_review"
            review.mkdir(parents=True)
            card = review / "QM5_900004_schema-gap.md"
            card.write_text(
                """---
ea_id: QM5_900004
slug: schema-gap
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 12
---
# Schema Gap

Thesis: monthly event drift.
Universe: XAUUSD.DWX
Timeframe: D1
Entry: enter on event window.
Exit: exit after window.
Risk: fixed fractional.
Falsification: fail if PF below threshold.
Q08/Q11 risks: event concentration and news robustness.
Implementation notes: simple MQL5 date filter and narrow setfile.
""",
                encoding="utf-8",
            )
            created = agent_router.enqueue_task(root, "research_strategy", priority=10)

            result = agent_router.update_task(
                root,
                created["task_id"],
                state="REVIEW",
                artifact_path=str(card),
                verdict="RESEARCH_DRAFT_READY",
            )

            self.assertFalse(result["updated"])
            self.assertEqual(result["reason"], "strategy_card_schema_failed")


if __name__ == "__main__":
    unittest.main()
