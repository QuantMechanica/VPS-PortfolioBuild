"""Q04 work-item command payload bridge tests."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm import farmctl


class Q04LatestFullYearPayloadTests(unittest.TestCase):
    def test_q04_runner_uses_slugged_ea_label_from_setfile(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ea_label = "QM5_12110_mtf-stochastic-confirmation"
            setfile = root / "framework" / "EAs" / ea_label / "sets" / (
                f"{ea_label}_EURJPY.DWX_H1_backtest.set"
            )
            setfile.parent.mkdir(parents=True)
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            item = {
                "phase": "Q04",
                "ea_id": "QM5_12110",
                "symbol": "EURJPY.DWX",
                "setfile_path": str(setfile),
                "payload_json": json.dumps({"host_timeframe": "H1"}),
            }

            cmd = farmctl._phase_runner_cmd_for_work_item(
                root, item, root / "reports", terminal="T4"  # type: ignore[arg-type]
            )

        self.assertIsNotNone(cmd)
        assert cmd is not None
        self.assertEqual(cmd[cmd.index("--ea") + 1], ea_label)

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

    def test_q05_payload_timeout_reaches_phase_runner(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            setfile = root / (
                "QM5_12834_wti-jpy-spread_"
                "QM5_12834_XTI_USDJPY_SPREAD_D1_D1_backtest.set"
            )
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            item = {
                "phase": "Q05",
                "ea_id": "QM5_12834",
                "symbol": "QM5_12834_XTI_USDJPY_SPREAD_D1",
                "setfile_path": str(setfile),
                "payload_json": json.dumps(
                    {
                        "host_symbol": "XTIUSD.DWX",
                        "host_timeframe": "D1",
                        "timeout_min": 120,
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
        self.assertIn("--timeout-sec", cmd)
        self.assertEqual(
            cmd[cmd.index("--timeout-sec") + 1],
            str(120 * 60 - farmctl.PHASE_RUNNER_TIMEOUT_HEADROOM_SEC),
        )


if __name__ == "__main__":
    unittest.main()
