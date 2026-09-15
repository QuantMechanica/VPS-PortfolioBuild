"""Kimi research lane router tests (slice C2, OWNER-DEC-KIMI-INTEGRATION-20260915).

Covers KIMI_INTEGRATION_ARCHITECTURE.md §5 (lane row + task types + cost_rank),
§7 (KIMI_LOW_QUOTA flag consumption in Plane A) and §9 (routing receipts).
All routing runs against a temp root; no D:/QM path is written (routing receipts
go to an injected temp directory).
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.strategy_farm import agent_router
from tools.strategy_farm import farmctl


EXPECTED_KIMI_CAPS = {
    "research",
    "strategy",
    "summary",
    "source_discovery",
    "deep_research",
    "long_context_synthesis",
    "edge_discovery",
    "cross_experiment_analysis",
    "research_review",
    "research_critic",
    "hypothesis_authoring",
    "ml_research",
}
FORBIDDEN_KIMI_CAPS = {"code", "tests", "repo_edit", "repo", "ops", "scalpel_mechanization"}


class KimiLaneRouterTests(unittest.TestCase):
    # --- registry declaration -------------------------------------------------

    def test_kimi_lane_declares_research_only_capabilities(self) -> None:
        row = agent_router.DEFAULT_AGENT_REGISTRY["kimi"]
        self.assertTrue(row["enabled"])
        self.assertEqual(row["max_parallel"], 1)
        self.assertEqual(row["cost_rank"], 12)
        self.assertEqual(set(row["capabilities"]), EXPECTED_KIMI_CAPS)
        # None of the build/ops/repo capabilities may appear (code-level guard).
        self.assertEqual(set(row["capabilities"]) & FORBIDDEN_KIMI_CAPS, set())
        # And kimi must not be pinned to any task-type lane.
        self.assertNotIn("kimi", agent_router.AGENT_TASK_TYPE_LANES)

    def test_new_research_task_types_are_registered_and_routable(self) -> None:
        for task_type in ("research_edge_discovery", "research_hypothesis", "research_critique"):
            self.assertIn(task_type, agent_router.TASK_TYPE_CAPABILITIES)
        # research_critique needs the research_critic cap that only kimi declares.
        self.assertEqual(
            agent_router.TASK_TYPE_CAPABILITIES["research_critique"], ["research_critic"]
        )

    # --- routing --------------------------------------------------------------

    def _sync_normal(self, root: Path) -> None:
        agent_router.sync_default_registry(
            root,
            claude_disabled_flag=root / "missing.flag",
            kimi_low_quota_flag=root / "missing_kimi.flag",
        )

    def _route(self, root: Path, *, kimi_flag: Path | None = None, receipts: Path | None = None):
        return agent_router.route_once(
            root,
            claude_disabled_flag=root / "missing.flag",
            kimi_low_quota_flag=kimi_flag or (root / "missing_kimi.flag"),
            routing_receipts_dir=receipts,
        )

    def test_research_edge_discovery_routes_to_kimi(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            self._sync_normal(root)
            task = agent_router.enqueue_task(root, "research_edge_discovery", priority=50)
            decision = self._route(root)
            self.assertEqual(decision.task_id, task["task_id"])
            self.assertEqual(decision.assigned_agent, "kimi")

    def test_generic_research_strategy_prefers_gemini_not_kimi(self) -> None:
        # cost_rank 12 keeps kimi behind gemini(10) for generic research, so a
        # NORMAL kimi lane never captures the cheap research funnel.
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            self._sync_normal(root)
            agent_router.enqueue_task(root, "research_strategy", priority=50)
            decision = self._route(root)
            self.assertEqual(decision.assigned_agent, "gemini")

    def test_build_ea_and_ops_issue_never_route_to_kimi(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            self._sync_normal(root)
            agent_router.enqueue_task(root, "build_ea", priority=80)
            agent_router.enqueue_task(root, "ops_issue", priority=80)
            first = self._route(root)
            second = self._route(root)
            self.assertNotEqual(first.assigned_agent, "kimi")
            self.assertNotEqual(second.assigned_agent, "kimi")

    # --- KIMI_LOW_QUOTA flag consumption (Plane A) ----------------------------

    def _write_flag(self, root: Path, state: str | None) -> Path:
        flag = root / "kimi_quota.flag"
        flag.write_text("" if state is None else json.dumps({"state": state}), encoding="utf-8")
        return flag

    def test_conserve_keeps_only_three_research_task_types_routable_to_kimi(self) -> None:
        # Each survivor task type routes to kimi under CONSERVE. A fresh root per
        # type because kimi max_parallel=1 (only one kimi task IN_PROGRESS).
        for task_type in ("research_edge_discovery", "research_hypothesis", "research_critique"):
            with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
                root = Path(tmp)
                flag = self._write_flag(root, "CONSERVE")
                agent_router.sync_default_registry(
                    root,
                    claude_disabled_flag=root / "missing.flag",
                    kimi_low_quota_flag=flag,
                )
                agent_router.enqueue_task(root, task_type, priority=50)
                decision = self._route(root, kimi_flag=flag)
                self.assertEqual(decision.task_type, task_type)
                self.assertEqual(decision.assigned_agent, "kimi", task_type)

    def test_conserve_excludes_generic_research_strategy_from_kimi(self) -> None:
        # kimi-only registry proves the route-time gate excludes research_strategy
        # even when kimi is the sole lane (capability subset alone cannot do it).
        kimi_only = {"kimi": dict(agent_router.DEFAULT_AGENT_REGISTRY["kimi"])}
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            flag = self._write_flag(root, "CONSERVE")
            with patch.object(agent_router, "DEFAULT_AGENT_REGISTRY", kimi_only):
                agent_router.sync_default_registry(
                    root,
                    claude_disabled_flag=root / "missing.flag",
                    kimi_low_quota_flag=flag,
                )
                agent_router.enqueue_task(root, "research_strategy", priority=50)
                # research_strategy is the only task: kimi is stripped by the
                # CONSERVE gate, so nothing routes even though kimi is the sole
                # lane and its caps are a superset of {research,strategy}.
                refused = self._route(root, kimi_flag=flag)
                self.assertEqual(refused.task_type, "research_strategy")
                self.assertIsNone(refused.assigned_agent)
                # A survivor task type still routes to kimi in the same root.
                agent_router.enqueue_task(root, "research_edge_discovery", priority=60)
                allowed = self._route(root, kimi_flag=flag)
                self.assertEqual(allowed.task_type, "research_edge_discovery")
                self.assertEqual(allowed.assigned_agent, "kimi")

    def test_exhausted_disables_kimi_lane(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            flag = self._write_flag(root, "EXHAUSTED")
            sync = agent_router.sync_default_registry(
                root,
                claude_disabled_flag=root / "missing.flag",
                kimi_low_quota_flag=flag,
            )
            self.assertEqual(sync["kimi_quota_state"], "EXHAUSTED")
            with agent_router.connect(root) as conn:
                kimi_row = conn.execute(
                    "SELECT enabled, max_parallel FROM agent_registry WHERE agent_id='kimi'"
                ).fetchone()
            self.assertEqual(int(kimi_row["enabled"]), 0)
            self.assertEqual(int(kimi_row["max_parallel"]), 0)
            # A kimi-only task type now has no eligible lane.
            agent_router.enqueue_task(root, "research_edge_discovery", priority=50)
            decision = self._route(root, kimi_flag=flag)
            self.assertIsNone(decision.assigned_agent)

    def _work_items_count(self, root: Path) -> int | None:
        with agent_router.connect(root) as conn:
            has = conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='work_items'"
            ).fetchone()
            if not has:
                return None
            return int(conn.execute("SELECT COUNT(*) AS c FROM work_items").fetchone()["c"])

    def test_kimi_unavailable_leaves_other_lanes_and_work_items_untouched(self) -> None:
        # F7 (2026-09-15): with kimi EXHAUSTED (routing-disabled) and, separately, with
        # kimi entirely absent from the registry (the cli_missing/unavailable posture -
        # the router never calls the adapter, so its absence must be inert), build_ea and
        # ops_issue still route to their non-kimi lanes and no kimi path touches work_items.
        scenarios = ["exhausted", "kimi_absent"]
        for scenario in scenarios:
            with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
                root = Path(tmp)
                if scenario == "exhausted":
                    flag = self._write_flag(root, "EXHAUSTED")
                    agent_router.sync_default_registry(
                        root, claude_disabled_flag=root / "missing.flag", kimi_low_quota_flag=flag)
                else:
                    flag = root / "missing_kimi.flag"
                    reg = {k: v for k, v in agent_router.DEFAULT_AGENT_REGISTRY.items() if k != "kimi"}
                    with patch.object(agent_router, "DEFAULT_AGENT_REGISTRY", reg):
                        agent_router.sync_default_registry(
                            root, claude_disabled_flag=root / "missing.flag", kimi_low_quota_flag=flag)

                wi_before = self._work_items_count(root)
                agent_router.enqueue_task(root, "build_ea", priority=80)
                agent_router.enqueue_task(root, "ops_issue", priority=80)

                seen: dict[str, str] = {}
                for _ in range(4):
                    decision = self._route(root, kimi_flag=flag)
                    if decision.assigned_agent:
                        seen[decision.task_type] = decision.assigned_agent

                self.assertIn("build_ea", seen, scenario)
                self.assertNotEqual(seen["build_ea"], "kimi", scenario)
                self.assertIn("ops_issue", seen, scenario)
                self.assertNotEqual(seen["ops_issue"], "kimi", scenario)

                wi_after = self._work_items_count(root)
                self.assertEqual(wi_before, wi_after, f"{scenario}: work_items changed")
                if wi_after is not None:
                    self.assertEqual(wi_after, 0, scenario)

    def test_bare_flag_fails_closed_to_exhausted(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            flag = self._write_flag(root, None)  # empty body
            self.assertEqual(agent_router.kimi_quota_state(root, flag), "EXHAUSTED")

    # --- routing receipts (§9) ------------------------------------------------

    def test_routing_receipt_written_when_kimi_chosen(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            receipts = root / "receipts"
            self._sync_normal(root)
            task = agent_router.enqueue_task(root, "research_edge_discovery", priority=50)
            self._route(root, receipts=receipts)
            files = list(receipts.glob("*.json"))
            self.assertEqual(len(files), 1)
            data = json.loads(files[0].read_text(encoding="utf-8"))
            self.assertEqual(data["task_id"], task["task_id"])
            self.assertEqual(data["task_type"], "research_edge_discovery")
            self.assertEqual(data["chosen_lane"], "kimi")
            self.assertEqual(data["kimi_quota_state"], "NORMAL")
            self.assertIn("capability_set", data)
            self.assertIn("candidates_considered", data)
            self.assertIn("reason", data)
            lanes = {c["lane"] for c in data["candidates_considered"]}
            self.assertIn("kimi", lanes)
            for cand in data["candidates_considered"]:
                self.assertIn("cost_rank", cand)

    def test_routing_receipt_written_when_kimi_candidate_loses(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            receipts = root / "receipts"
            self._sync_normal(root)
            agent_router.enqueue_task(root, "research_strategy", priority=50)
            decision = self._route(root, receipts=receipts)
            # gemini wins on cost_rank, but kimi was a candidate -> receipt logged.
            self.assertEqual(decision.assigned_agent, "gemini")
            files = list(receipts.glob("*.json"))
            self.assertEqual(len(files), 1)
            data = json.loads(files[0].read_text(encoding="utf-8"))
            self.assertEqual(data["chosen_lane"], "gemini")
            lanes = {c["lane"] for c in data["candidates_considered"]}
            self.assertIn("kimi", lanes)

    def test_no_receipt_when_kimi_not_a_candidate(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            receipts = root / "receipts"
            self._sync_normal(root)
            # ops_issue requires [ops, code] which kimi never declares.
            agent_router.enqueue_task(root, "ops_issue", priority=50)
            self._route(root, receipts=receipts)
            self.assertFalse(receipts.exists() and list(receipts.glob("*.json")))


if __name__ == "__main__":
    unittest.main()
