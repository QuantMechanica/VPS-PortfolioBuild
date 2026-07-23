from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from framework.scripts.multi_ea_scheduler import (
    SchedulerError,
    build_launch_command,
    load_queue,
    scheduler_tick,
    select_jobs,
    validate_queue_item,
)


class MultiEASchedulerTests(unittest.TestCase):
    def test_validate_queue_item_rejects_non_dwx_symbol(self) -> None:
        with self.assertRaisesRegex(SchedulerError, r"\.DWX"):
            validate_queue_item({"ea_id": "QM5_1001", "phase": "P0", "symbol": "EURUSD", "config_hash": "a1"})

    def test_load_queue_requires_array(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "queue.json"
            path.write_text("{}", encoding="utf-8")
            with self.assertRaisesRegex(SchedulerError, r"array"):
                load_queue(path)

    def test_select_jobs_uses_free_terminals_fifo(self) -> None:
        jobs = [
            validate_queue_item({"ea_id": "QM5_1001", "phase": "P0", "symbol": "EURUSD.DWX", "config_hash": "a1"}),
            validate_queue_item({"ea_id": "QM5_1002", "phase": "P0", "symbol": "GBPUSD.DWX", "config_hash": "a1"}),
        ]
        launches = select_jobs(jobs, running_terminals={"T1", "T3"}, max_launches=2)
        self.assertEqual(launches[0][0], "T2")
        self.assertEqual(launches[1][0], "T4")

    def test_build_launch_command_p0_resolves_canonical_label_to_slugged_expert(self) -> None:
        job = validate_queue_item({"ea_id": "QM5_1014", "phase": "P0", "symbol": "EURUSD.DWX", "config_hash": "a1"})
        cmd = build_launch_command(job, "T2")
        command_text = cmd[-1]
        self.assertIn("-EAId 1014", command_text)
        self.assertIn("-Expert 'QM\\QM5_1014_lien_channels'", command_text)
        self.assertIn("-Terminal T2", command_text)

    def test_build_launch_command_p0_accepts_slugged_label(self) -> None:
        job = validate_queue_item(
            {"ea_id": "QM5_1014_lien_channels", "phase": "P0", "symbol": "EURUSD.DWX", "config_hash": "a1"}
        )
        cmd = build_launch_command(job, "T3")
        command_text = cmd[-1]
        self.assertIn("-EAId 1014", command_text)
        self.assertIn("-Expert 'QM\\QM5_1014_lien_channels'", command_text)
        self.assertIn("-Terminal T3", command_text)

    @patch("framework.scripts.multi_ea_scheduler.subprocess.Popen")
    def test_scheduler_tick_emits_idle_alarm_after_threshold(self, mock_popen) -> None:
        mock_popen.return_value.pid = 12345
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            queue = root / "queue.json"
            state = root / "state.json"
            runs = root / "runs"
            alarm = root / "alarm.json"
            phase_state = root / "PHASE_STATE.md"

            queue.write_text("[]\n", encoding="utf-8")
            state.write_text(
                json.dumps(
                    {
                        "running": {},
                        "last_active_utc": "2026-05-09T09:00:00Z",
                        "history": [],
                        "idle_alarm": {"active": False, "last_alarm_utc": None},
                    }
                ),
                encoding="utf-8",
            )

            with patch("framework.scripts.multi_ea_scheduler.utc_now") as fake_now:
                from datetime import datetime, timezone

                fake_now.return_value = datetime(2026, 5, 9, 9, 20, 0, tzinfo=timezone.utc)
                result = scheduler_tick(
                    None,
                    queue,
                    state,
                    runs,
                    alarm,
                    phase_state,
                    idle_seconds=600,
                    max_launches=5,
                )

            self.assertEqual(result["scheduled"], 0)
            self.assertTrue(alarm.exists())
            payload = json.loads(alarm.read_text(encoding="utf-8"))
            self.assertEqual(payload["severity"], "class_2")
            updated = json.loads(state.read_text(encoding="utf-8"))
            self.assertTrue(updated["idle_alarm"]["active"])
            self.assertTrue(phase_state.exists())
            self.assertIn("MT5 saturation last 24h:", phase_state.read_text(encoding="utf-8"))

    @patch("framework.scripts.multi_ea_scheduler.build_launch_command")
    @patch("framework.scripts.multi_ea_scheduler.subprocess.Popen")
    def test_scheduler_tick_rebuilds_queue_from_source(self, mock_popen, mock_build_launch) -> None:
        mock_popen.return_value.pid = 12345
        mock_build_launch.return_value = ["echo", "ok"]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            queue = root / "queue.json"
            source = root / "source.json"
            state = root / "state.json"
            runs = root / "runs"
            alarm = root / "alarm.json"
            phase_state = root / "PHASE_STATE.md"

            source.write_text(
                json.dumps(
                    {
                        "approved_waiting_p0": [
                            {"ea_id": "QM5_1014", "phase": "P0", "symbol": "EURUSD.DWX", "config_hash": "cfg-a"}
                        ],
                        "transition_ready": [
                            {"ea_id": "QM5_1017", "phase": "P2", "symbol": "XAUUSD.DWX", "config_hash": "cfg-b"}
                        ],
                    }
                ),
                encoding="utf-8",
            )
            queue.write_text("[]\n", encoding="utf-8")

            result = scheduler_tick(
                source,
                queue,
                state,
                runs,
                alarm,
                phase_state,
                idle_seconds=600,
                max_launches=5,
            )

            self.assertEqual(result["scheduled"], 2)
            persisted_queue = json.loads(queue.read_text(encoding="utf-8"))
            self.assertEqual(persisted_queue, [])

    @patch("framework.scripts.multi_ea_scheduler.build_launch_command")
    @patch("framework.scripts.multi_ea_scheduler.subprocess.Popen")
    def test_scheduler_tick_dry_run_skips_process_spawn(self, mock_popen, mock_build_launch) -> None:
        mock_build_launch.return_value = ["echo", "ok"]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            queue = root / "queue.json"
            state = root / "state.json"
            runs = root / "runs"
            alarm = root / "alarm.json"
            phase_state = root / "PHASE_STATE.md"

            queue.write_text(
                json.dumps(
                    [
                        {"ea_id": "QM5_1014", "phase": "P0", "symbol": "EURUSD.DWX", "config_hash": "cfg-a"},
                        {"ea_id": "QM5_1017", "phase": "P2", "symbol": "XAUUSD.DWX", "config_hash": "cfg-b"},
                    ]
                ),
                encoding="utf-8",
            )
            result = scheduler_tick(
                None,
                queue,
                state,
                runs,
                alarm,
                phase_state,
                idle_seconds=600,
                max_launches=5,
                dry_run=True,
            )
            self.assertEqual(result["scheduled"], 2)
            mock_popen.assert_not_called()


if __name__ == "__main__":
    unittest.main()
