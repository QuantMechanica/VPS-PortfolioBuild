"""Repair work-item transitions are journalled and large passes are visible."""

from __future__ import annotations

import datetime as dt
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import repair  # noqa: E402


def _db() -> sqlite3.Connection:
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.executescript(
        """
        CREATE TABLE tasks (id TEXT PRIMARY KEY, status TEXT);
        CREATE TABLE work_items (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL DEFAULT 'backtest',
            phase TEXT NOT NULL,
            ea_id TEXT NOT NULL,
            symbol TEXT NOT NULL,
            setfile_path TEXT NOT NULL,
            status TEXT NOT NULL,
            verdict TEXT,
            attempt_count INTEGER NOT NULL DEFAULT 0,
            parent_task_id TEXT,
            evidence_path TEXT,
            claimed_by TEXT,
            payload_json TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE work_item_transition_ledger (
            seq INTEGER PRIMARY KEY AUTOINCREMENT,
            idempotency_key TEXT NOT NULL UNIQUE,
            ts TEXT NOT NULL,
            work_item_id TEXT NOT NULL,
            action TEXT NOT NULL,
            from_status TEXT,
            to_status TEXT,
            from_verdict TEXT,
            to_verdict TEXT,
            from_claimed_by TEXT,
            to_claimed_by TEXT,
            reason TEXT NOT NULL,
            run_id TEXT,
            detail_json TEXT NOT NULL
        );
        CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            event TEXT NOT NULL,
            detail_json TEXT NOT NULL
        );
        """
    )
    return con


def _insert_work_item(
    con: sqlite3.Connection,
    *,
    item_id: str,
    phase: str = "Q02",
    status: str = "pending",
    verdict: str | None = None,
    claimed_by: str | None = None,
    setfile_path: str = "missing.set",
    created_at: str = "2026-08-22T00:00:00+00:00",
    updated_at: str = "2026-08-22T00:00:00+00:00",
) -> None:
    con.execute(
        """
        INSERT INTO work_items(
            id, phase, ea_id, symbol, setfile_path, status, verdict,
            claimed_by, created_at, updated_at
        ) VALUES (?, ?, 'QM5_1009', 'EURUSD.DWX', ?, ?, ?, ?, ?, ?)
        """,
        (item_id, phase, setfile_path, status, verdict, claimed_by, created_at, updated_at),
    )
    con.commit()


class RepairTransitionLedgerTests(unittest.TestCase):
    def test_r5_active_to_pending_is_journalled(self) -> None:
        con = _db()
        old = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=3)).isoformat()
        _insert_work_item(con, item_id="r5", status="active", claimed_by="T9", updated_at=old)
        with mock.patch.object(repair, "_running_mt5_terminals", return_value=set()):
            result = repair.repair_stale_active_work_items(con)
        self.assertEqual(len(result), 1)
        ledger = con.execute("SELECT * FROM work_item_transition_ledger").fetchone()
        self.assertEqual(ledger["action"], "R5_dead_terminal_work_item")
        self.assertEqual((ledger["from_status"], ledger["to_status"]), ("active", "pending"))
        self.assertEqual(ledger["reason"], "claimed_terminal_process_not_running")
        con.close()

    def test_r11_pending_to_invalid_is_journalled(self) -> None:
        con = _db()
        _insert_work_item(con, item_id="r11")
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            with mock.patch.object(repair, "ROOT", Path(tmp)):
                result = repair.repair_pending_unclaimable_work_items(con)
        self.assertEqual(len(result), 1)
        ledger = con.execute("SELECT * FROM work_item_transition_ledger").fetchone()
        self.assertEqual(ledger["action"], "R11_pending_unclaimable_work_item")
        self.assertEqual((ledger["from_status"], ledger["to_status"]), ("pending", "failed"))
        self.assertEqual((ledger["from_verdict"], ledger["to_verdict"]), (None, "INVALID"))
        self.assertEqual(ledger["reason"], "setfile_missing")
        con.close()

    def test_r18_suppressed_duplicate_is_journalled(self) -> None:
        con = _db()
        _insert_work_item(con, item_id="first", setfile_path="same.set")
        _insert_work_item(
            con,
            item_id="second",
            setfile_path="same.set",
            created_at="2026-08-22T00:00:01+00:00",
            updated_at="2026-08-22T00:00:01+00:00",
        )
        result = repair.repair_duplicate_pending_q02_work_items(con)
        self.assertEqual(len(result), 1)
        ledger = con.execute("SELECT * FROM work_item_transition_ledger").fetchone()
        self.assertEqual(ledger["action"], "R18_duplicate_pending_q02_work_item")
        self.assertEqual(ledger["reason"], "duplicate_pending_q02_superseded")
        self.assertEqual((ledger["from_status"], ledger["to_status"]), ("pending", "failed"))
        con.close()

    def test_mass_change_alarm_names_handler_and_phase_distribution(self) -> None:
        con = _db()
        for index, phase in enumerate(("Q02", "Q02", "COMPILE_EA"), start=1):
            detail = {"handler": "R11_pending_unclaimable_work_item", "phase": phase}
            con.execute(
                """
                INSERT INTO work_item_transition_ledger(
                    idempotency_key, ts, work_item_id, action, reason, run_id, detail_json
                ) VALUES (?, '2026-08-22T00:00:00Z', ?,
                          'R11_pending_unclaimable_work_item', 'test', 'run-1', ?)
                """,
                (f"key-{index}", f"item-{index}", json.dumps(detail)),
            )
        con.commit()
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            alarm_path = Path(tmp) / "health_alarms.log"
            with mock.patch.object(repair, "HEALTH_ALARMS_LOG", alarm_path), \
                 mock.patch.object(repair, "_REPAIR_MASS_CHANGE_ALARM_THRESHOLD", 2):
                alarms = repair._raise_mass_change_alarm(
                    con,
                    run_id="run-1",
                    since_seq=0,
                    repair_function="repair_pending_unclaimable_work_items",
                )
            self.assertEqual(len(alarms), 1)
            alarm_text = alarm_path.read_text(encoding="utf-8")
            self.assertIn("R11_pending_unclaimable_work_item", alarm_text)
            self.assertIn('"COMPILE_EA": 1', alarm_text)
            self.assertIn('"Q02": 2', alarm_text)
        event = con.execute("SELECT * FROM events").fetchone()
        self.assertEqual(event["event"], "repair_mass_change_alarm")
        con.close()


if __name__ == "__main__":
    unittest.main()
