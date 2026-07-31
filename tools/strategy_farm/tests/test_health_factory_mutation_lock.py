from __future__ import annotations

import datetime as dt
import json
from pathlib import Path
import sys
from unittest import mock

from tools.strategy_farm import health


def _write_lock(path: Path, *, age_seconds: float, pid: int = 999_999) -> None:
    record = {
        "pid": pid,
        "owner": "synthetic-health-owner",
        "nonce": "b" * 32,
        "created_at": (
            dt.datetime.now(dt.UTC) - dt.timedelta(seconds=age_seconds)
        ).isoformat(),
    }
    path.write_text(json.dumps(record, sort_keys=True) + "\n", encoding="utf-8")


def test_synthetic_old_orphan_is_fail(tmp_path: Path) -> None:
    path = tmp_path / "FACTORY_MUTATION.lock"
    _write_lock(path, age_seconds=300)
    inspection_module = sys.modules[health.inspect_factory_mutation_lock.__module__]
    with (
        mock.patch.object(health, "FACTORY_MUTATION_LOCK_PATH", path),
        mock.patch.object(
            inspection_module,
            "_pid_identity_state",
            return_value="dead",
        ),
    ):
        result = health.chk_factory_mutation_lock()

    assert result["status"] == "FAIL"
    assert "PID 999999 is dead" in result["detail"]
    assert "mutation_lock_reaps.jsonl" in result["action_hint"]


def test_old_live_holder_is_warn_not_fail(tmp_path: Path) -> None:
    path = tmp_path / "FACTORY_MUTATION.lock"
    _write_lock(path, age_seconds=900, pid=1234)
    inspection_module = sys.modules[health.inspect_factory_mutation_lock.__module__]
    with (
        mock.patch.object(health, "FACTORY_MUTATION_LOCK_PATH", path),
        mock.patch.object(
            inspection_module,
            "_pid_identity_state",
            return_value="live",
        ),
    ):
        result = health.chk_factory_mutation_lock()

    assert result["status"] == "WARN"
    assert "state=live" in result["detail"]
    assert "never reap" in result["action_hint"]


def test_absent_lock_is_ok(tmp_path: Path) -> None:
    with mock.patch.object(
        health,
        "FACTORY_MUTATION_LOCK_PATH",
        tmp_path / "missing.lock",
    ):
        result = health.chk_factory_mutation_lock()

    assert result["status"] == "OK"
    assert result["value"] == "absent"


def test_uninspectable_lock_age_warns_fail_closed() -> None:
    with mock.patch.object(
        health,
        "inspect_factory_mutation_lock",
        return_value={
            "status": "unreadable",
            "path": "synthetic.lock",
            "age_seconds": None,
            "error": "access denied",
        },
    ):
        result = health.chk_factory_mutation_lock()

    assert result["status"] == "WARN"
    assert "age could not be inspected" in result["detail"]
