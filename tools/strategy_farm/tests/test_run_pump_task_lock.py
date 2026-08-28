from __future__ import annotations

import os
import time

from tools.strategy_farm import run_pump_task as task


def test_acquire_lock_reclaims_fresh_lock_owned_by_dead_process(tmp_path, monkeypatch):
    lock = tmp_path / "pump_task.lock"
    lock.write_text("37968", encoding="ascii")
    monkeypatch.setattr(task, "LOG_DIR", tmp_path)
    monkeypatch.setattr(task, "LOCK_PATH", lock)
    monkeypatch.setattr(task, "get_process_identity", lambda _pid: None)

    fd = task._acquire_lock()
    try:
        assert fd is not None
        assert lock.read_text(encoding="ascii") == str(os.getpid())
    finally:
        if fd is not None:
            os.close(fd)


def test_acquire_lock_keeps_fresh_lock_owned_by_live_process(tmp_path, monkeypatch):
    lock = tmp_path / "pump_task.lock"
    lock.write_text("1234", encoding="ascii")
    monkeypatch.setattr(task, "LOG_DIR", tmp_path)
    monkeypatch.setattr(task, "LOCK_PATH", lock)
    monkeypatch.setattr(
        task,
        "get_process_identity",
        lambda _pid: {"is_running": True},
    )

    assert task._acquire_lock() is None
    assert lock.read_text(encoding="ascii") == "1234"


def test_acquire_lock_age_ceiling_still_recovers_unreadable_lock(tmp_path, monkeypatch):
    lock = tmp_path / "pump_task.lock"
    lock.write_text("not-a-pid", encoding="ascii")
    old = time.time() - task.LOCK_STALE_SECONDS - 1
    os.utime(lock, (old, old))
    monkeypatch.setattr(task, "LOG_DIR", tmp_path)
    monkeypatch.setattr(task, "LOCK_PATH", lock)

    fd = task._acquire_lock()
    try:
        assert fd is not None
    finally:
        if fd is not None:
            os.close(fd)
