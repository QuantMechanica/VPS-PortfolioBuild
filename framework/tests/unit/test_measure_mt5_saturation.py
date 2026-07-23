from __future__ import annotations

from datetime import datetime, timezone
import unittest

from framework.scripts.measure_mt5_saturation import evaluate_saturation


class MeasureMT5SaturationTests(unittest.TestCase):
    def test_pass_when_average_above_threshold(self) -> None:
        now = datetime(2026, 5, 9, 10, 30, 0, tzinfo=timezone.utc)
        samples = [
            {"ts_utc": "2026-05-09T10:26:00Z", "active_ratio": 0.6},
            {"ts_utc": "2026-05-09T10:27:00Z", "active_ratio": 0.8},
            {"ts_utc": "2026-05-09T10:28:00Z", "active_ratio": 0.4},
        ]
        out = evaluate_saturation(samples, min_ratio=0.5, min_minutes=5, now=now)
        self.assertEqual(out["verdict"], "PASS")

    def test_fail_when_no_recent_samples(self) -> None:
        now = datetime(2026, 5, 9, 10, 30, 0, tzinfo=timezone.utc)
        samples = [{"ts_utc": "2026-05-09T10:00:00Z", "active_ratio": 1.0}]
        out = evaluate_saturation(samples, min_ratio=0.5, min_minutes=5, now=now)
        self.assertEqual(out["verdict"], "FAIL")
        self.assertEqual(out["sample_count"], 0)


if __name__ == "__main__":
    unittest.main()
