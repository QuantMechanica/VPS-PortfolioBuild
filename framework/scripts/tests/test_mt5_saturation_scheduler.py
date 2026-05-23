from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from framework.scripts.mt5_saturation_scheduler import ensure_schema, run_tick
from framework.scripts.pipeline_dispatcher import save_dispatch_state


def _job(
    *,
    symbol: str,
    status: str = "queued",
    priority: int = 0,
    target_terminal: str = "any",
    setfile_path: str = "framework/EAs/QM5_1001_example/sets/QM5_1001_example_EURUSD.DWX_H1_backtest.set",
) -> tuple:
    return (
        "QM5_1001",
        "v1",
        "P2",
        symbol,
        "cfg001",
        setfile_path,
        target_terminal,
        priority,
        status,
    )


class MT5SaturationSchedulerTests(unittest.TestCase):
    def test_run_tick_dispatches_until_capacity(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            db_path = root / "queue.db"
            state_path = root / "dispatch_state.json"
            save_dispatch_state({"running": {"T1": 2, "T2": 3, "T3": 3, "T4": 3, "T5": 3}}, state_path)

            conn = sqlite3.connect(str(db_path))
            try:
                ensure_schema(conn)
                conn.execute(
                    """
                    INSERT INTO mt5_job_queue
                    (ea_id,version,phase,symbol,sub_gate_config_hash,setfile_path,target_terminal,priority,status)
                    VALUES (?,?,?,?,?,?,?,?,?)
                    """,
                    _job(symbol="EURUSD.DWX", priority=10),
                )
                conn.execute(
                    """
                    INSERT INTO mt5_job_queue
                    (ea_id,version,phase,symbol,sub_gate_config_hash,setfile_path,target_terminal,priority,status)
                    VALUES (?,?,?,?,?,?,?,?,?)
                    """,
                    _job(symbol="GBPUSD.DWX", priority=9),
                )
                conn.commit()
            finally:
                conn.close()

            with patch("framework.scripts.pipeline_dispatcher.active_terminals", return_value=("T1", "T2", "T3", "T4", "T5")):
                with patch("framework.scripts.mt5_saturation_scheduler.active_terminals", return_value=("T1", "T2", "T3", "T4", "T5")):
                    summary = run_tick(
                        sqlite_path=db_path,
                        dispatch_state_path=state_path,
                        max_per_terminal=3,
                        scan_limit=100,
                        dry_run=False,
                    )
            self.assertEqual(summary["scheduled"], 1)
            self.assertEqual(summary["no_capacity"], 1)

            conn = sqlite3.connect(str(db_path))
            try:
                statuses = conn.execute("SELECT symbol,status FROM mt5_job_queue ORDER BY id ASC").fetchall()
            finally:
                conn.close()
            self.assertEqual(statuses[0][1], "dispatched")
            self.assertEqual(statuses[1][1], "queued")

    def test_run_tick_marks_invalid_rows(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            db_path = root / "queue.db"
            state_path = root / "dispatch_state.json"
            save_dispatch_state({"running": {"T1": 0, "T2": 0, "T3": 0, "T4": 0, "T5": 0}}, state_path)

            conn = sqlite3.connect(str(db_path))
            try:
                ensure_schema(conn)
                conn.execute(
                    """
                    INSERT INTO mt5_job_queue
                    (ea_id,version,phase,symbol,sub_gate_config_hash,setfile_path,target_terminal,priority,status)
                    VALUES (?,?,?,?,?,?,?,?,?)
                    """,
                    _job(symbol="EURUSD", priority=10),
                )
                conn.commit()
            finally:
                conn.close()

            summary = run_tick(
                sqlite_path=db_path,
                dispatch_state_path=state_path,
                max_per_terminal=3,
                scan_limit=100,
                dry_run=False,
            )
            self.assertEqual(summary["invalid"], 1)

            conn = sqlite3.connect(str(db_path))
            try:
                row = conn.execute("SELECT status,last_error FROM mt5_job_queue WHERE id=1").fetchone()
            finally:
                conn.close()
            self.assertEqual(row[0], "invalid")
            self.assertIn(".DWX", row[1])


if __name__ == "__main__":
    unittest.main()
