import inspect
import unittest

from tools.strategy_farm import farmctl


class OneShotMailDisabledTests(unittest.TestCase):
    def test_pump_does_not_invoke_one_shot_notifiers(self) -> None:
        source = inspect.getsource(farmctl.pump)

        self.assertNotIn("_ws0_check_and_notify", source)
        self.assertNotIn("_task_watch_check_and_notify", source)
        self.assertNotIn("ws0_notifier import", source)
        self.assertNotIn("task_watch_notifier import", source)
        self.assertIn("disabled_by_owner_2026_05_22", source)
        self.assertIn("ws0_clear_notifier", source)
        self.assertIn("task_watch_notifier", source)


if __name__ == "__main__":
    unittest.main()
