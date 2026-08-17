from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import governed_work_item_hold as hold


def _db(tmp_path: Path) -> Path:
    db = tmp_path / "farm.sqlite"
    with sqlite3.connect(db) as conn:
        conn.executescript(
            """
            CREATE TABLE work_items(
              id TEXT PRIMARY KEY,kind TEXT,ea_id TEXT,symbol TEXT,phase TEXT,
              status TEXT,verdict TEXT,claimed_by TEXT,created_at TEXT,updated_at TEXT
            );
            CREATE TABLE work_item_holds(
              work_item_id TEXT PRIMARY KEY,hold_code TEXT NOT NULL,reason TEXT NOT NULL,
              active INTEGER NOT NULL,release_on_restart INTEGER NOT NULL,
              created_at TEXT NOT NULL,updated_at TEXT NOT NULL,released_at TEXT,release_note TEXT
            );
            CREATE TABLE events(
              id INTEGER PRIMARY KEY,ts TEXT NOT NULL,entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,event TEXT NOT NULL,detail_json TEXT NOT NULL
            );
            """
        )
        conn.executemany(
            "INSERT INTO work_items VALUES(?,?,?,?,?,'pending',NULL,NULL,'old','old')",
            [
                ("one", "backtest", "QM5_31003", "AUDUSD.DWX", "Q02"),
                ("two", "backtest", "QM5_31003", "EURUSD.DWX", "Q02"),
                ("three", "backtest", "QM5_31003", "GBPJPY.DWX", "Q02"),
            ],
        )
    return db


TARGETS = [("one", "AUDUSD.DWX"), ("two", "EURUSD.DWX"), ("three", "GBPJPY.DWX")]
COMMON = {
    "ea_id": "QM5_31003",
    "phase": "Q02",
    "hold_code": "UNSAFE_FOREIGN_SYMBOL_SCOPE",
    "reason": "runtime foreign universe is not admitted",
    "release_condition": "offline artifact or basket manifest plus canary",
}


def test_apply_is_atomic_audited_backed_up_and_unclaimable(tmp_path: Path) -> None:
    db = _db(tmp_path)
    result = hold.apply_holds(db, tmp_path / "backups", TARGETS, **COMMON)
    assert result["inserted"] == 3
    assert result["all_unclaimable"] is True
    assert Path(result["backup"]["path"]).is_file()
    assert len(result["backup"]["sha256"]) == 64
    with sqlite3.connect(db) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_item_holds WHERE active=1 AND release_on_restart=0").fetchone()[0] == 3
        assert conn.execute("SELECT COUNT(*) FROM events WHERE event='governed_hold_activated'").fetchone()[0] == 3
        assert conn.execute("SELECT COUNT(*) FROM work_items WHERE status='pending'").fetchone()[0] == 3


def test_precondition_mismatch_aborts_without_partial_holds(tmp_path: Path) -> None:
    db = _db(tmp_path)
    with sqlite3.connect(db) as conn:
        conn.execute("UPDATE work_items SET claimed_by='T1' WHERE id='two'")
    with pytest.raises(hold.HoldError, match="work_item_precondition:two"):
        hold.apply_holds(db, tmp_path / "backups", TARGETS, **COMMON)
    with sqlite3.connect(db) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_item_holds").fetchone()[0] == 0


def test_conflicting_active_hold_aborts(tmp_path: Path) -> None:
    db = _db(tmp_path)
    with sqlite3.connect(db) as conn:
        conn.execute(
            "INSERT INTO work_item_holds VALUES('one','OTHER','other',1,0,'old','old',NULL,NULL)"
        )
    with pytest.raises(hold.HoldError, match="conflicting_active_hold"):
        hold.plan_holds(db, TARGETS, **COMMON)


def test_repeated_apply_is_idempotent(tmp_path: Path) -> None:
    db = _db(tmp_path)
    first = hold.apply_holds(db, tmp_path / "backups1", TARGETS, **COMMON)
    second = hold.apply_holds(db, tmp_path / "backups2", TARGETS, **COMMON)
    assert first["inserted"] == 3
    assert second["inserted"] == 0
    assert second["already_held"] == 3
    with sqlite3.connect(db) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_item_holds").fetchone()[0] == 3
        details = [json.loads(row[0]) for row in conn.execute("SELECT detail_json FROM events")]
        assert all(detail["release_on_restart"] is False for detail in details)
