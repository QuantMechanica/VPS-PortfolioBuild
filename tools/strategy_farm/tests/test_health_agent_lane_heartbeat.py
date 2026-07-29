import os
import sqlite3
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

from tools.strategy_farm import health


class AgentLaneHeartbeatHealthTests(unittest.TestCase):
    def _connection(self) -> sqlite3.Connection:
        con = sqlite3.connect(":memory:")
        con.execute(
            """
            CREATE TABLE agent_registry (
                agent_id TEXT PRIMARY KEY,
                enabled INTEGER NOT NULL,
                max_parallel INTEGER NOT NULL
            )
            """
        )
        con.executemany(
            "INSERT INTO agent_registry(agent_id, enabled, max_parallel) VALUES (?, ?, ?)",
            [
                ("codex", 1, 5),
                ("gemini", 1, 2),
                ("claude", 0, 0),
            ],
        )
        return con

    def test_warns_for_stale_enabled_lane_only(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            state = root / "state"
            state.mkdir()
            fresh = state / "lane_codex_heartbeat.json"
            stale = state / "lane_gemini_heartbeat.json"
            disabled = state / "lane_claude_heartbeat.json"
            for path in (fresh, stale, disabled):
                path.write_text("{}\n", encoding="utf-8")
            old = time.time() - (health.agent_router.LANE_HEARTBEAT_STALE_HOURS + 1) * 3600
            os.utime(stale, (old, old))
            os.utime(disabled, (old, old))
            con = self._connection()
            try:
                with mock.patch.object(health, "ROOT", root):
                    result = health.chk_agent_lane_heartbeat(con)
            finally:
                con.close()

            self.assertEqual(result["status"], "WARN")
            self.assertEqual(result["value"], 1)
            self.assertIn("gemini=", result["detail"])
            self.assertNotIn("claude=", result["detail"])

    def test_missing_or_fresh_heartbeat_is_not_reported_stale(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            state = root / "state"
            state.mkdir()
            (state / "lane_codex_heartbeat.json").write_text("{}\n", encoding="utf-8")
            con = self._connection()
            try:
                with mock.patch.object(health, "ROOT", root):
                    result = health.chk_agent_lane_heartbeat(con)
            finally:
                con.close()

            self.assertEqual(result["status"], "OK")
            self.assertEqual(result["value"], 0)


if __name__ == "__main__":
    unittest.main()
