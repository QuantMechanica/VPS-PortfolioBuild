from __future__ import annotations

import json
import sqlite3
import sys
from datetime import timedelta
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
STRATEGY_FARM = REPO / "tools" / "strategy_farm"
sys.path.insert(0, str(STRATEGY_FARM))

import release_containment_standing as rcs  # noqa: E402


def _make_db(tmp_path: Path, rows: list[dict]) -> Path:
    state = tmp_path / "state"
    state.mkdir(parents=True, exist_ok=True)
    db = state / "farm_state.sqlite"
    conn = sqlite3.connect(str(db))
    conn.execute(
        "CREATE TABLE work_items (id TEXT PRIMARY KEY, phase TEXT, status TEXT, "
        "verdict TEXT, claimed_by TEXT, updated_at TEXT, payload_json TEXT, attempt_count INTEGER)"
    )
    for row in rows:
        conn.execute(
            "INSERT INTO work_items (id,phase,status,verdict,claimed_by,updated_at,payload_json,attempt_count) "
            "VALUES (?,?,?,?,?,?,?,?)",
            (row["id"], row.get("phase", "OPT_CENSUS"), row["status"], row.get("verdict"),
             row.get("claimed_by"), "2026-09-02T00:00:00+00:00", row.get("payload_json", "{}"),
             row.get("attempt_count", 1)),
        )
    conn.commit()
    conn.close()
    return db


def test_live_terminals_maps_process_paths():
    snap = {"runner_processes": [
        {"ExecutablePath": r"D:\QM\mt5\T2\terminal64.exe"},
        {"ExecutablePath": r"D:\QM\mt5\T10\metatester64.exe"},
        {"ExecutablePath": r"C:\Windows\explorer.exe"},
    ]}
    assert rcs._live_terminals(snap) == {"T2", "T10"}


def test_containment_released_reads_mode(tmp_path: Path):
    mode = tmp_path / "mode.json"
    mode.write_text(json.dumps({"enabled": False}), encoding="utf-8")
    assert rcs.containment_released(mode) is True
    mode.write_text(json.dumps({"enabled": True}), encoding="utf-8")
    assert rcs.containment_released(mode) is False
    assert rcs.containment_released(tmp_path / "missing.json") is False


def test_reap_only_orphaned_active_rows(tmp_path: Path):
    _make_db(tmp_path, [
        {"id": "live", "status": "active", "claimed_by": "T2"},
        {"id": "orphan", "status": "active", "claimed_by": "T7"},
        {"id": "unclaimed", "status": "active", "claimed_by": None},
        {"id": "done", "status": "done", "claimed_by": "T3"},
    ])
    snapshot = {
        "quiescent": False,
        "active_work_items": [
            {"id": "live", "phase": "OPT_CENSUS", "claimed_by": "T2"},
            {"id": "orphan", "phase": "OPT_CENSUS", "claimed_by": "T7"},
            {"id": "unclaimed", "phase": "Q05", "claimed_by": None},
        ],
        "runner_processes": [{"ExecutablePath": r"D:\QM\mt5\T2\terminal64.exe"}],
    }
    log = tmp_path / "log.jsonl"
    reaped = rcs.reap_orphaned_active_claims(
        farm_root=tmp_path, snapshot=snapshot, log_path=log
    )
    reaped_ids = {r["id"] for r in reaped}
    assert reaped_ids == {"orphan", "unclaimed"}

    conn = sqlite3.connect(str(tmp_path / "state" / "farm_state.sqlite"))
    statuses = dict(conn.execute("SELECT id,status FROM work_items").fetchall())
    conn.close()
    assert statuses["live"] == "active"        # live worker untouched
    assert statuses["orphan"] == "pending"     # reaped
    assert statuses["unclaimed"] == "pending"  # reaped
    assert statuses["done"] == "done"          # non-active untouched
    assert log.exists()


def test_reap_dry_run_does_not_write(tmp_path: Path):
    _make_db(tmp_path, [{"id": "orphan", "status": "active", "claimed_by": "T7"}])
    snapshot = {"active_work_items": [{"id": "orphan", "claimed_by": "T7"}], "runner_processes": []}
    reaped = rcs.reap_orphaned_active_claims(
        farm_root=tmp_path, snapshot=snapshot, execute=False, log_path=tmp_path / "log.jsonl"
    )
    assert [r["id"] for r in reaped] == ["orphan"]
    conn = sqlite3.connect(str(tmp_path / "state" / "farm_state.sqlite"))
    assert conn.execute("SELECT status FROM work_items WHERE id='orphan'").fetchone()[0] == "active"
    conn.close()


class _FakeLock:
    def __init__(self, busy_times: int):
        self.busy_times = busy_times
        self.entered = False
        self.release_status = "released"

    def __enter__(self):
        if self.busy_times > 0:
            self.busy_times -= 1
            raise RuntimeError("factory mutation lock is busy: X")
        self.entered = True
        return self

    def __exit__(self, *a):
        return None


def test_acquire_lock_retries_then_succeeds(tmp_path, monkeypatch):
    monkeypatch.setattr(rcs.time, "sleep", lambda *_: None)
    holder = {"lock": _FakeLock(busy_times=2)}
    lock = rcs.acquire_lock_with_retry(
        acquire_deadline=rcs._now() + timedelta(minutes=5),
        poll_seconds=0,
        log_path=tmp_path / "log.jsonl",
        lock_factory=lambda: holder["lock"],
    )
    assert lock is holder["lock"]
    assert lock.entered is True


def test_acquire_lock_times_out(tmp_path, monkeypatch):
    monkeypatch.setattr(rcs.time, "sleep", lambda *_: None)
    lock = rcs.acquire_lock_with_retry(
        acquire_deadline=rcs._now() - timedelta(seconds=1),  # already past
        poll_seconds=0,
        log_path=tmp_path / "log.jsonl",
        lock_factory=lambda: _FakeLock(busy_times=99),
    )
    assert lock is None


def test_wait_for_quiescence_success(tmp_path):
    def probe(**_):
        return {"quiescent": True, "active_work_items": [], "runner_processes": []}
    ok, _ = rcs.wait_for_quiescence(
        farm_root=tmp_path,
        hold_deadline=rcs._now() + timedelta(minutes=1),
        poll_seconds=0,
        log_path=tmp_path / "log.jsonl",
        quiescence_probe=probe,
    )
    assert ok is True


def test_wait_for_quiescence_blocked_by_lease(tmp_path, monkeypatch):
    monkeypatch.setattr(rcs.time, "sleep", lambda *_: None)
    lease = rcs.custom_history_lease.lease_path(tmp_path)
    lease.parent.mkdir(parents=True, exist_ok=True)
    lease.write_text("x", encoding="utf-8")

    def probe(**_):
        return {"quiescent": True, "active_work_items": [], "runner_processes": []}
    ok, _ = rcs.wait_for_quiescence(
        farm_root=tmp_path,
        hold_deadline=rcs._now() + timedelta(milliseconds=50),
        poll_seconds=0,
        log_path=tmp_path / "log.jsonl",
        quiescence_probe=probe,
    )
    assert ok is False  # lease present blocks quiescence


def test_fire_release_fail_closed_on_non_lease_error(tmp_path, monkeypatch):
    monkeypatch.setattr(rcs, "MANIFEST", tmp_path / "manifest.json")
    (tmp_path / "manifest.json").write_text("{}", encoding="utf-8")
    mode = tmp_path / "mode.json"
    mode.write_text(json.dumps({"enabled": True}), encoding="utf-8")
    calls = {"n": 0}

    def fake_runner(cmd):
        calls["n"] += 1
        return 2, "matching dual-audit isolation activation must be written"

    rc = rcs.fire_release(
        reason="t", hold_deadline=rcs._now() + timedelta(minutes=1),
        log_path=tmp_path / "log.jsonl", runner=fake_runner, mode_json=mode,
    )
    assert rc == 2
    assert calls["n"] == 1  # no retry on a non-lease/non-quiescence error


def test_fire_release_retries_lease_flicker_then_succeeds(tmp_path, monkeypatch):
    monkeypatch.setattr(rcs, "MANIFEST", tmp_path / "manifest.json")
    (tmp_path / "manifest.json").write_text("{}", encoding="utf-8")
    monkeypatch.setattr(rcs.time, "sleep", lambda *_: None)
    mode = tmp_path / "mode.json"
    mode.write_text(json.dumps({"enabled": True}), encoding="utf-8")
    seq = iter([(1, "global Custom-history lease record still exists"), (0, "ok")])

    def fake_runner(cmd):
        return next(seq)

    rc = rcs.fire_release(
        reason="t", hold_deadline=rcs._now() + timedelta(minutes=1),
        log_path=tmp_path / "log.jsonl", runner=fake_runner, mode_json=mode,
    )
    assert rc == 0


def test_main_noop_when_already_released(tmp_path, monkeypatch):
    monkeypatch.setattr(rcs, "containment_released", lambda *a, **k: True)
    monkeypatch.setattr(rcs, "log_step", lambda *a, **k: None)
    assert rcs.main(["some_reason"]) == 0
