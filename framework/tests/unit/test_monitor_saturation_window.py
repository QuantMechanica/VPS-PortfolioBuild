from __future__ import annotations

from datetime import datetime, timezone
import unittest

from framework.scripts.monitor_saturation_window import evaluate_window


class MonitorSaturationWindowTests(unittest.TestCase):
    def test_window_pass(self) -> None:
        start = datetime(2026, 5, 9, 10, 0, 0, tzinfo=timezone.utc)
        end = datetime(2026, 5, 9, 10, 5, 0, tzinfo=timezone.utc)
        samples = [
            {"ts_utc": "2026-05-09T10:01:00Z", "active_ratio": 0.6},
            {"ts_utc": "2026-05-09T10:03:00Z", "active_ratio": 0.5},
        ]
        out = evaluate_window(samples, window_start=start, window_end=end, min_ratio=0.5)
        self.assertEqual(out["verdict"], "PASS")

    def test_window_fail_without_samples(self) -> None:
        start = datetime(2026, 5, 9, 10, 0, 0, tzinfo=timezone.utc)
        end = datetime(2026, 5, 9, 10, 5, 0, tzinfo=timezone.utc)
        out = evaluate_window([], window_start=start, window_end=end, min_ratio=0.5)
        self.assertEqual(out["verdict"], "FAIL")


if __name__ == "__main__":
    unittest.main()
