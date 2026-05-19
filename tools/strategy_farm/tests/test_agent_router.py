from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm import agent_router


class AgentRouterTests(unittest.TestCase):
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

    def test_routes_by_capability_and_wip_limit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
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

    def test_replenish_adds_research_when_card_pool_low(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = agent_router.replenish(root, min_ready_strategy_cards=2)
            self.assertEqual(len(result["created"]), 2)
            status = agent_router.status(root)
            research = [row for row in status["tasks"] if row["task_type"] == "research_strategy"]
            self.assertEqual(research[0]["count"], 2)


if __name__ == "__main__":
    unittest.main()
