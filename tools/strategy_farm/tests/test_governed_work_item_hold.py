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


def test_supersede_hold_code_rearms_in_place_and_records_prior_hold(tmp_path: Path) -> None:
    db = _db(tmp_path)
    with sqlite3.connect(db) as conn:
        conn.execute(
            "INSERT INTO work_item_holds VALUES"
            "('one','NEWS_RUNNER_SPAWN_SILENT_ABORT','runner vanished',1,0,'t0','t1',NULL,NULL)"
        )
        conn.execute(
            "INSERT INTO work_item_holds VALUES"
            "('two','NEWS_RUNNER_SPAWN_SILENT_ABORT','runner vanished',0,0,'t0','t2','t2','reviewed')"
        )
    # Without the explicit flag both the active and the released prior hold abort.
    with pytest.raises(hold.HoldError, match="conflicting_active_hold:one"):
        hold.plan_holds(db, TARGETS[:1], **COMMON)
    with pytest.raises(hold.HoldError, match="conflicting_inactive_hold:two"):
        hold.plan_holds(db, TARGETS[1:2], **COMMON)
    plan = hold.plan_holds(
        db, TARGETS, supersede_hold_code="NEWS_RUNNER_SPAWN_SILENT_ABORT", **COMMON
    )
    assert plan["would_supersede"] == 2
    result = hold.apply_holds(
        db, tmp_path / "backups", TARGETS,
        supersede_hold_code="NEWS_RUNNER_SPAWN_SILENT_ABORT", **COMMON,
    )
    assert result["superseded"] == 2
    assert result["inserted"] == 1
    assert result["all_unclaimable"] is True
    with sqlite3.connect(db) as conn:
        rows = conn.execute(
            "SELECT work_item_id,hold_code,active,release_on_restart,released_at,release_note "
            "FROM work_item_holds ORDER BY work_item_id"
        ).fetchall()
        assert rows == [
            ("one", COMMON["hold_code"], 1, 0, None, None),
            ("three", COMMON["hold_code"], 1, 0, None, None),
            ("two", COMMON["hold_code"], 1, 0, None, None),
        ]
        superseded = [
            json.loads(row[0])
            for row in conn.execute(
                "SELECT detail_json FROM events WHERE event='governed_hold_superseded'"
            )
        ]
        assert sorted(d["superseded_hold"]["work_item_id"] for d in superseded) == ["one", "two"]
        assert all(
            d["superseded_hold"]["hold_code"] == "NEWS_RUNNER_SPAWN_SILENT_ABORT" for d in superseded
        )
        assert conn.execute("SELECT COUNT(*) FROM work_items WHERE status='pending'").fetchone()[0] == 3
    # Idempotent: a second apply with the same flag re-arms nothing.
    again = hold.apply_holds(
        db, tmp_path / "backups2", TARGETS,
        supersede_hold_code="NEWS_RUNNER_SPAWN_SILENT_ABORT", **COMMON,
    )
    assert again["superseded"] == 0 and again["inserted"] == 0 and again["already_held"] == 3


def test_supersede_flag_never_touches_other_hold_codes(tmp_path: Path) -> None:
    db = _db(tmp_path)
    with sqlite3.connect(db) as conn:
        conn.execute(
            "INSERT INTO work_item_holds VALUES('one','OTHER','other',1,0,'old','old',NULL,NULL)"
        )
    with pytest.raises(hold.HoldError, match="conflicting_active_hold:one:OTHER"):
        hold.apply_holds(
            db, tmp_path / "backups", TARGETS,
            supersede_hold_code="NEWS_RUNNER_SPAWN_SILENT_ABORT", **COMMON,
        )
    with sqlite3.connect(db) as conn:
        assert conn.execute("SELECT hold_code,active FROM work_item_holds").fetchall() == [("OTHER", 1)]
