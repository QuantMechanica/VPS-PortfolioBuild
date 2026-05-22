import sys
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class P2PrescreenPolicyTests(unittest.TestCase):
    def test_prescreen_window_is_recent_six_months_inside_p2_window(self) -> None:
        self.assertEqual(
            farmctl._p2_prescreen_dates(2022),
            ("2022.07.01", "2022.12.31"),
        )

    def test_full_timeout_uses_prescreen_runtime_with_bounds(self) -> None:
        payload = {
            "p2_prescreen_runtime_sec": 60,
            "p2_prescreen_from_date": "2022.07.01",
            "p2_prescreen_to_date": "2022.12.31",
        }
        self.assertEqual(
            farmctl._p2_full_timeout_seconds(payload, "2017.01.01", "2022.12.31"),
            farmctl.P2_FULL_TIMEOUT_MIN_SECONDS,
        )

        payload["p2_prescreen_runtime_sec"] = 1800
        self.assertEqual(
            farmctl._p2_full_timeout_seconds(payload, "2017.01.01", "2022.12.31"),
            farmctl.P2_FULL_TIMEOUT_MAX_SECONDS,
        )

    def test_full_timeout_falls_back_to_min_without_measurement(self) -> None:
        self.assertEqual(
            farmctl._p2_full_timeout_seconds({}, "2017.01.01", "2022.12.31"),
            farmctl.P2_FULL_TIMEOUT_MIN_SECONDS,
        )


if __name__ == "__main__":
    unittest.main()
