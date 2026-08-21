from __future__ import annotations

from pathlib import Path
from unittest import mock

from tools.strategy_farm import health


def _fake_run(returncode_text: str):
    def _run(*args, **kwargs):
        return mock.Mock(stdout=returncode_text, stderr="")
    return _run


def test_ignorenew_refused_with_no_lock_is_not_fail(tmp_path: Path) -> None:
    # 2147946720 == 0x800710E0 == "The operator or administrator has refused
    # the request" -- the exact code Task Scheduler stamps when
    # MultipleInstances=IgnoreNew skips a trigger because the prior 5-min
    # pump cycle was still running (PT30M execution limit on a 5-min
    # cadence). This must not be reported as a pump failure (MNT-003).
    with (
        mock.patch.object(health.subprocess, "run", _fake_run("2147946720")),
        mock.patch.object(health, "ROOT", tmp_path),
    ):
        result = health.chk_pump_task_health()

    assert result["status"] == "OK"
    assert result["value"] == 2147946720


def test_ignorenew_refused_with_orphaned_lock_still_fails(tmp_path: Path) -> None:
    # The benign-busy code must not blind the orphaned-lock evidence check --
    # a genuinely stuck pump hiding behind this code is still an outage.
    log_dir = tmp_path / "logs"
    log_dir.mkdir()
    lock_path = log_dir / "pump_task.lock"
    lock_path.write_text("999999999", encoding="ascii")
    import os
    old_mtime = 0
    os.utime(lock_path, (old_mtime, old_mtime))

    with (
        mock.patch.object(health.subprocess, "run", _fake_run("2147946720")),
        mock.patch.object(health, "ROOT", tmp_path),
        mock.patch.object(health, "_pid_alive_no_signal", return_value=False),
    ):
        result = health.chk_pump_task_health()

    assert result["status"] == "FAIL"
    assert "orphan_lock_pid" in str(result["value"])


def test_genuine_nonzero_exit_still_fails(tmp_path: Path) -> None:
    with (
        mock.patch.object(health.subprocess, "run", _fake_run("112")),
        mock.patch.object(health, "ROOT", tmp_path),
    ):
        result = health.chk_pump_task_health()

    assert result["status"] == "FAIL"
    assert result["value"] == 112


def test_currently_running_code_unchanged(tmp_path: Path) -> None:
    with (
        mock.patch.object(health.subprocess, "run", _fake_run("267009")),
        mock.patch.object(health, "ROOT", tmp_path),
    ):
        result = health.chk_pump_task_health()

    assert result["status"] == "OK"
