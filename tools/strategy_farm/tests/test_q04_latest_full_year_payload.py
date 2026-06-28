"""Q04 work-item command payload bridge tests."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm import farmctl


class Q04LatestFullYearPayloadTests(unittest.TestCase):
    def test_q04_work_item_payload_can_clamp_latest_full_year(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            setfile = root / (
                "QM5_12712_edgelab-eurgbp-euraud-cointegration_"
                "QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1_D1_backtest.set"
            )
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            item = {
                "phase": "Q04",
                "ea_id": "QM5_12712",
                "symbol": "QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1",
                "setfile_path": str(setfile),
                "payload_json": json.dumps(
                    {
                        "host_symbol": "EURGBP.DWX",
                        "host_timeframe": "D1",
                        "q04_latest_full_year": 2024,
                    }
                ),
            }

            cmd = farmctl._phase_runner_cmd_for_work_item(
                root,
                item,  # type: ignore[arg-type]
                root / "reports",
                terminal="T4",
            )

        self.assertIsNotNone(cmd)
        assert cmd is not None
        self.assertIn("--latest-full-year", cmd)
        self.assertEqual(cmd[cmd.index("--latest-full-year") + 1], "2024")


if __name__ == "__main__":
    unittest.main()
