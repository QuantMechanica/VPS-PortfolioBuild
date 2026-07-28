from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import run_agent_orchestration_task as orchestration  # noqa: E402


def test_live_lock_owner_is_never_displaced_by_age(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(orchestration, "LOCK_DIR", tmp_path)
    acquired, first = orchestration.acquire_lock("codex", stale_minutes=1)
    assert acquired is True
    lock_path = Path(first["lock_path"])
    old = time.time() - 10_000
    os.utime(lock_path, (old, old))

    acquired_again, second = orchestration.acquire_lock("codex", stale_minutes=1)

    assert acquired_again is False
    assert second["reason"] == "previous_run_active"
    orchestration.release_lock(first)


def test_recent_dead_owner_lock_is_retained_until_stale_window(
    tmp_path, monkeypatch
) -> None:
    monkeypatch.setattr(orchestration, "LOCK_DIR", tmp_path)
    lock_path = tmp_path / "codex_orchestration.lock"
    lock_path.write_text(
        json.dumps({"pid": 2_000_000_000, "owner_token": "dead"}),
        encoding="utf-8",
    )

    acquired, result = orchestration.acquire_lock("codex", stale_minutes=250)

    assert acquired is False
    assert result["reason"] == "recent_lock_owner_not_live"
    assert lock_path.exists()


def test_stale_dead_lock_takeover_is_atomic_and_token_owned(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(orchestration, "LOCK_DIR", tmp_path)
    lock_path = tmp_path / "codex_orchestration.lock"
    lock_path.write_text(
        json.dumps({"pid": 2_000_000_000, "owner_token": "dead"}),
        encoding="utf-8",
    )
    old = time.time() - 120
    os.utime(lock_path, (old, old))

    acquired, lock_info = orchestration.acquire_lock("codex", stale_minutes=1)

    assert acquired is True
    payload = json.loads(lock_path.read_text(encoding="utf-8"))
    assert payload["owner_token"] == lock_info["owner_token"]
    orchestration.release_lock(lock_info)
    assert not lock_path.exists()


def test_old_owner_token_cannot_release_replacement_lock(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(orchestration, "LOCK_DIR", tmp_path)
    acquired, lock_info = orchestration.acquire_lock("codex", stale_minutes=1)
    assert acquired is True
    lock_path = Path(lock_info["lock_path"])
    payload = json.loads(lock_path.read_text(encoding="utf-8"))
    payload["owner_token"] = "replacement-owner"
    lock_path.write_text(json.dumps(payload), encoding="utf-8")

    orchestration.release_lock(lock_info)

    assert lock_path.exists()


def test_pythonw_excepthook_persists_uncaught_traceback(tmp_path, monkeypatch) -> None:
    crash_log = tmp_path / "orchestration_pythonw_crash.log"
    monkeypatch.setattr(orchestration, "PYTHONW_CRASH_LOG", crash_log)
    try:
        raise RuntimeError("orchestration-hook-probe")
    except RuntimeError:
        exc_type, exc, tb = sys.exc_info()
        assert exc_type is not None and exc is not None
        orchestration._pythonw_excepthook(exc_type, exc, tb)

    text = crash_log.read_text(encoding="utf-8")
    assert "uncaught top-level exception" in text
    assert "RuntimeError: orchestration-hook-probe" in text
