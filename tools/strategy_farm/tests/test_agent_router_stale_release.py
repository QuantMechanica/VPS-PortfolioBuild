import json
import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm import agent_router, farmctl


class AgentRouterStaleReleaseTests(unittest.TestCase):
    def test_releases_stale_in_progress_task_to_todo(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            task_id = agent_router.enqueue_task(root, "ops_issue", payload={"title": "stale"})["task_id"]
            with agent_router.connect(root) as conn:
                conn.execute(
                    """
                    UPDATE agent_tasks
                    SET state='IN_PROGRESS', assigned_agent='codex', updated_at='2026-05-22T00:00:00+00:00'
                    WHERE id=?
                    """,
                    (task_id,),
                )
                conn.commit()

            result = agent_router.release_stale_in_progress(root, max_age_hours=1)

            self.assertEqual(result["released"][0]["task_id"], task_id)
            with agent_router.connect(root) as conn:
                row = conn.execute("SELECT * FROM agent_tasks WHERE id=?", (task_id,)).fetchone()
            self.assertEqual(row["state"], "TODO")
            self.assertIsNone(row["assigned_agent"])
            payload = json.loads(row["payload_json"])
            self.assertEqual(payload["stale_releases"][0]["previous_assigned_agent"], "codex")


if __name__ == "__main__":
    unittest.main()
