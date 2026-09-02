"""Orphaned pre-spawn claim recovery.

A worker that claims a pre-spawn item, hits a busy DB during the run, and then
cannot even RELEASE that claim (the same lock storm) used to exit (return 1) and
strand the row as status='active', claimed_by=<terminal>, no runner pid — pinning
that terminal's symbol lane until an operator ran release_stale_claims by hand
(row c261068d, T4, 2026-09-02). These tests cover the three recovery layers:
  1. the release now retries with a ~60s exponential envelope;
  2. on persistent lock it drops a durable orphan-claim marker;
  3. worker startup / the pump reconcile stage drains the marker to pending; and
  4. release_stale_claims already treats a missing/None pid as 'runner gone'.
"""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from unittest.mock import patch

from tools.strategy_farm import farmctl, terminal_worker


def _make_db(root: Path) -> Path:
    database = root / farmctl.DB_REL
    if database.exists():
        return database
    database.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(database) as connection:
        connection.execute(
            "CREATE TABLE IF NOT EXISTS work_items("
            "id TEXT PRIMARY KEY,status TEXT,verdict TEXT,claimed_by TEXT,"
            "payload_json TEXT,updated_at TEXT)"
        )
        connection.execute(
            "CREATE TABLE IF NOT EXISTS events("
            "id INTEGER PRIMARY KEY AUTOINCREMENT,ts TEXT,entity_type TEXT,"
            "entity_id TEXT,event TEXT,detail_json TEXT)"
        )
    return database


def _insert_row(
    root: Path, item_id: str, terminal: str, *, pid: object = None, status: str = "active"
) -> None:
    _make_db(root)
    payload = {"program_id": "DL089_TEST", "pid": pid}
    with sqlite3.connect(root / farmctl.DB_REL) as connection:
        connection.execute(
            "INSERT INTO work_items(id,status,verdict,claimed_by,payload_json,updated_at) "
            "VALUES(?,?,NULL,?,?,?)",
            (
                item_id,
                status,
                terminal if status == "active" else None,
                json.dumps(payload),
                farmctl.utc_now(),
            ),
        )
        connection.commit()


def _init_db_with_active_row(
    root: Path, item_id: str, terminal: str, *, pid: object = None, status: str = "active"
) -> None:
    _insert_row(root, item_id, terminal, pid=pid, status=status)


def _read_row(root: Path, item_id: str) -> tuple[str, object, dict]:
    with farmctl.connect(root) as conn:
        status, claimed_by, raw = conn.execute(
            "SELECT status,claimed_by,payload_json FROM work_items WHERE id=?",
            (item_id,),
        ).fetchone()
    return status, claimed_by, json.loads(raw)


def _write_marker(root: Path, item_id: str, terminal: str) -> Path:
    marker = terminal_worker._orphan_claim_marker_path(root, item_id)
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text(
        json.dumps(
            {
                "item_id": item_id,
                "terminal": terminal,
                "reason": "worker_exit_sqlite_busy_defer_release_failed",
                "created_at_iso": farmctl.utc_now(),
            }
        ),
        encoding="utf-8",
    )
    return marker


# --- Layer 2: defer writes a durable marker when release stays locked ---------


def test_defer_writes_orphan_marker_when_release_persistently_locked(tmp_path: Path) -> None:
    item_id = "item-orphan-1"

    def _always_busy(*_args, **_kwargs):
        raise sqlite3.OperationalError("database is locked")

    with patch.object(terminal_worker, "retry_sqlite_busy", _always_busy):
        deferred = terminal_worker._defer_item_after_sqlite_busy(
            tmp_path,
            {"id": item_id},
            "T4",
            sqlite3.OperationalError("database is locked"),
        )

    assert deferred is False
    marker = terminal_worker._orphan_claim_marker_path(tmp_path, item_id)
    assert marker.exists()
    record = json.loads(marker.read_text(encoding="utf-8"))
    assert record["item_id"] == item_id
    assert record["terminal"] == "T4"
    assert record["reason"] == "worker_exit_sqlite_busy_defer_release_failed"


def test_defer_reraises_non_busy_operational_error(tmp_path: Path) -> None:
    def _syntax_error(*_args, **_kwargs):
        raise sqlite3.OperationalError("no such table: work_items")

    with patch.object(terminal_worker, "retry_sqlite_busy", _syntax_error):
        try:
            terminal_worker._defer_item_after_sqlite_busy(
                tmp_path, {"id": "x"}, "T4", sqlite3.OperationalError("boom")
            )
        except sqlite3.OperationalError as exc:
            assert "no such table" in str(exc)
        else:
            raise AssertionError("non-busy OperationalError must propagate")
    assert not terminal_worker._orphan_claim_marker_path(tmp_path, "x").exists()


# --- Layer 3: reconcile drains the marker to pending --------------------------


def test_reconcile_releases_orphan_row_and_removes_marker(tmp_path: Path) -> None:
    item_id = "item-orphan-2"
    _init_db_with_active_row(tmp_path, item_id, "T4")
    marker = _write_marker(tmp_path, item_id, "T4")

    released = terminal_worker.reconcile_orphan_claims(tmp_path, "T4")

    assert released == [item_id]
    assert not marker.exists()
    status, claimed_by, payload = _read_row(tmp_path, item_id)
    assert (status, claimed_by) == ("pending", None)
    assert payload["prior_failure"] == "worker_exit_sqlite_busy_released"
    assert "pid" not in payload  # stale runtime keys cleared
    with farmctl.connect(tmp_path) as conn:
        events = conn.execute(
            "SELECT event FROM events WHERE entity_id=? AND event='orphan_claim_released'",
            (item_id,),
        ).fetchall()
    assert len(events) == 1


def test_reconcile_is_scoped_to_its_own_terminal(tmp_path: Path) -> None:
    item_id = "item-orphan-3"
    _init_db_with_active_row(tmp_path, item_id, "T2")
    marker = _write_marker(tmp_path, item_id, "T2")

    released = terminal_worker.reconcile_orphan_claims(tmp_path, "T4")

    assert released == []
    assert marker.exists()  # left for T2's own worker / the fleet-wide pump pass
    status, claimed_by, _ = _read_row(tmp_path, item_id)
    assert (status, claimed_by) == ("active", "T2")


def test_reconcile_fleetwide_releases_any_terminal(tmp_path: Path) -> None:
    _init_db_with_active_row(tmp_path, "a", "T2")
    farmctl_connect = farmctl.connect
    with farmctl_connect(tmp_path) as conn:
        conn.execute(
            "INSERT INTO work_items(id,status,verdict,claimed_by,payload_json,updated_at) "
            "VALUES('b','active',NULL,'T7',?,?)",
            (json.dumps({"pid": None}), farmctl.utc_now()),
        )
        conn.commit()
    _write_marker(tmp_path, "a", "T2")
    _write_marker(tmp_path, "b", "T7")

    released = terminal_worker.reconcile_orphan_claims(tmp_path, None)

    assert sorted(released) == ["a", "b"]


def test_reconcile_keeps_marker_when_still_locked(tmp_path: Path) -> None:
    item_id = "item-orphan-4"
    _init_db_with_active_row(tmp_path, item_id, "T4")
    marker = _write_marker(tmp_path, item_id, "T4")

    def _always_busy(*_args, **_kwargs):
        raise sqlite3.OperationalError("database is locked")

    with patch.object(terminal_worker, "retry_sqlite_busy", _always_busy):
        released = terminal_worker.reconcile_orphan_claims(tmp_path, "T4")

    assert released == []
    assert marker.exists()  # kept for the next reconcile pass
    status, claimed_by, _ = _read_row(tmp_path, item_id)
    assert (status, claimed_by) == ("active", "T4")


def test_reconcile_clears_marker_when_row_already_pending(tmp_path: Path) -> None:
    item_id = "item-orphan-5"
    _init_db_with_active_row(tmp_path, item_id, "T4", status="pending")
    marker = _write_marker(tmp_path, item_id, "T4")

    released = terminal_worker.reconcile_orphan_claims(tmp_path, "T4")

    assert released == []  # nothing released, but the stale marker is drained
    assert not marker.exists()


def test_reconcile_drops_unparseable_marker(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    bad = tmp_path / terminal_worker.ORPHAN_CLAIMS_REL / "garbage.json"
    bad.parent.mkdir(parents=True, exist_ok=True)
    bad.write_text("{not json", encoding="utf-8")

    released = terminal_worker.reconcile_orphan_claims(tmp_path, "T4")

    assert released == []
    assert not bad.exists()


def test_reconcile_missing_dir_is_noop(tmp_path: Path) -> None:
    assert terminal_worker.reconcile_orphan_claims(tmp_path, "T4") == []


# --- Layer 4: release_stale treats a missing/None pid as runner-gone ----------


def test_release_stale_releases_active_row_with_none_pid(tmp_path: Path) -> None:
    # release_stale runs farmctl.init_db internally, so build the real schema.
    item_id = "item-stale-1"
    farmctl.init_db(tmp_path)
    now = farmctl.utc_now()
    with farmctl.connect(tmp_path) as conn:
        conn.execute(
            "INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,"
            "attempt_count,claimed_by,payload_json,created_at,updated_at,sh3_enforced) "
            "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,0)",
            (
                item_id, "backtest", "OPT_CENSUS", 41097, "USDJPY", "x.set",
                "active", 1, "T4", json.dumps({"pid": None}), now, now,
            ),
        )
        conn.commit()

    released = terminal_worker.release_stale_claims_for_terminal(tmp_path, "T4")

    assert released == [item_id]
    status, claimed_by, payload = _read_row(tmp_path, item_id)
    assert (status, claimed_by) == ("pending", None)
    assert payload["prior_failure"] == "worker_restart_released_stale_claim"


def test_pid_tree_exists_handles_none() -> None:
    # A payload with no pid must not raise and must read as 'runner gone'.
    assert farmctl._pid_tree_exists(None) is False
