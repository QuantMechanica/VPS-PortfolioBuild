"""Q04 work-item command payload bridge tests."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm import farmctl


class Q04LatestFullYearPayloadTests(unittest.TestCase):
    def test_q04_budget_uses_q02_runtime_for_child_and_all_fold_outer_net(self) -> None:
        parent = {
            "id": "q02-pass",
            "phase": "Q02",
            "ea_id": "QM5_11078",
            "symbol": "USDJPY.DWX",
            "setfile_path": "fixture.set",
            "status": "done",
            "verdict": "PASS",
            "updated_at": "2026-08-16T01:00:00+00:00",
            "payload_json": json.dumps({
                "started_at_iso": "2026-08-16T00:00:00+00:00",
                "timeout_min": 45,
            }),
        }
        payload = {"q04_latest_full_year": 2025, "timeout_min": 45}

        # A direct Q02 parent does not query the connection.
        farmctl._apply_q04_timeout_budget(None, parent, payload)  # type: ignore[arg-type]

        self.assertEqual(payload["q02_full_runtime_sec"], 3600)
        self.assertEqual(payload["q04_fold_timeout_sec"], 5400)
        self.assertEqual(payload["q04_fold_count_budgeted"], 3)
        self.assertEqual(payload["timeout_min"], 285)
        self.assertEqual(payload["q02_source_work_item_id"], "q02-pass")

    def test_q04_budget_floor_and_large_payload_are_bounded_and_not_shrunk(self) -> None:
        self.assertEqual(farmctl._q04_fold_timeout_seconds({}), 1800)
        payload = {"q04_latest_full_year": 2025, "timeout_min": 600}
        parent = {
            "id": "q02-pass-large",
            "phase": "Q02",
            "updated_at": "2026-08-16T00:10:00+00:00",
            "payload_json": json.dumps({
                "started_at_iso": "2026-08-16T00:00:00+00:00",
                "timeout_min": 600,
            }),
        }

        farmctl._apply_q04_timeout_budget(None, parent, payload)  # type: ignore[arg-type]

        self.assertEqual(
            payload["q04_fold_timeout_sec"],
            farmctl.Q04_FOLD_TIMEOUT_MAX_SEC,
        )
        self.assertGreaterEqual(payload["timeout_min"], 600)

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
                "id": "wi-q04-slug",
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
        self.assertEqual(
            Path(cmd[cmd.index("--report-root") + 1]),
            farmctl.PIPELINE_REPORT_ROOT,
        )
        self.assertEqual(
            Path(cmd[cmd.index("--scratch-root") + 1]),
            root / "reports",
        )
        self.assertEqual(cmd[cmd.index("--evidence-key") + 1], "wi-q04-slug")
        self.assertEqual(cmd[cmd.index("--timeout-sec") + 1], "1800")

    def test_q04_runner_receives_derived_fold_timeout(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            setfile = root / "QM5_11078_rsioma-reversal_USDJPY.DWX_H4_backtest.set"
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            item = {
                "id": "wi-q04-timeout",
                "phase": "Q04",
                "ea_id": "QM5_11078",
                "symbol": "USDJPY.DWX",
                "setfile_path": str(setfile),
                "payload_json": json.dumps({"q04_fold_timeout_sec": 6210}),
            }

            cmd = farmctl._phase_runner_cmd_for_work_item(
                root, item, root / "reports", terminal="T4"  # type: ignore[arg-type]
            )

        self.assertIsNotNone(cmd)
        assert cmd is not None
        self.assertEqual(cmd[cmd.index("--timeout-sec") + 1], "6210")

    def test_q04_work_item_payload_can_clamp_latest_full_year(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            setfile = root / (
                "QM5_12712_edgelab-eurgbp-euraud-cointegration_"
                "QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1_D1_backtest.set"
            )
            setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
            item = {
                "id": "wi-q04-clamp",
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
