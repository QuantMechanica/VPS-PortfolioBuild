import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm import agent_router, farmctl, task_watch_notifier


class TaskWatchNotifierTests(unittest.TestCase):
    def test_default_watch_groups_include_edge_lab_d1_followup(self) -> None:
        watches = [
            task
            for group in task_watch_notifier.DEFAULT_WATCH_GROUPS
            for task in group.get("tasks", [])
        ]

        self.assertIn(
            {
                "id": "fccb8155-cdb2-4ca9-822c-15d209cced05",
                "target_state": "REVIEW",
                "label": "Edge Lab D1 EA build follow-up",
            },
            watches,
        )

    def test_group_sends_once_after_all_targets_reached(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            task_one = agent_router.enqueue_task(root, "ops_issue", payload={"title": "one"})["task_id"]
            task_two = agent_router.enqueue_task(root, "ops_issue", payload={"title": "two"})["task_id"]
            agent_router.update_task(root, task_one, state="REVIEW", verdict="READY")
            sent: list[tuple[str, str]] = []
            group = {
                "id": "unit_watch",
                "subject": "unit watch ready",
                "tasks": [
                    {"id": task_one, "target_state": "REVIEW", "label": "one"},
                    {"id": task_two, "target_state": "REVIEW", "label": "two"},
                ],
            }

            first = task_watch_notifier.check_and_notify(
                root,
                watch_groups=[group],
                send_mail=lambda subject, body: sent.append((subject, body)) or {"sent": True},
            )
            self.assertFalse(first["triggered"])
            self.assertEqual(len(sent), 0)

            agent_router.update_task(root, task_two, state="APPROVED", verdict="DONE")
            second = task_watch_notifier.check_and_notify(
                root,
                watch_groups=[group],
                send_mail=lambda subject, body: sent.append((subject, body)) or {"sent": True},
            )
            third = task_watch_notifier.check_and_notify(
                root,
                watch_groups=[group],
                send_mail=lambda subject, body: sent.append((subject, body)) or {"sent": True},
            )

            self.assertTrue(second["triggered"])
            self.assertFalse(third["triggered"])
            self.assertEqual(len(sent), 1)
            self.assertIn(task_one, sent[0][1])
            self.assertIn(task_two, sent[0][1])


if __name__ == "__main__":
    unittest.main()
