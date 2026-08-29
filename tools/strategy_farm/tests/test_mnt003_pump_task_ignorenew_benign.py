from __future__ import annotations

import datetime as dt
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
    # pump cycle was still running (PT1H execution limit on a 5-min
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


def test_repeated_scheduler_termination_is_critical(tmp_path: Path) -> None:
    state = tmp_path / "state"
    state.mkdir()
    now = dt.datetime.now(dt.timezone.utc)
    (state / "pump_task_termination_history.json").write_text(
        '[{"last_run":"first","result":267014,'
        f'"observed_at":"{now.isoformat()}"}}]',
        encoding="utf-8",
    )
    payload = '{"result":267014,"last_run":"second"}'
    with (
        mock.patch.object(health.subprocess, "run", _fake_run(payload)),
        mock.patch.object(health, "ROOT", tmp_path),
    ):
        result = health.chk_pump_task_health()

    assert result["status"] == "FAIL"
    assert "CRITICAL" in result["detail"]
    assert "0x00041306" in result["detail"]


def test_success_breaks_scheduler_termination_sequence(tmp_path: Path) -> None:
    state = tmp_path / "state"
    state.mkdir()
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    (state / "pump_task_termination_history.json").write_text(
        '[{"last_run":"terminated","result":267014,'
        f'"observed_at":"{now}"}},{{"last_run":"success","result":0,'
        f'"observed_at":"{now}"}}]',
        encoding="utf-8",
    )
    with (
        mock.patch.object(
            health.subprocess, "run",
            _fake_run('{"result":267014,"last_run":"terminated-again"}'),
        ),
        mock.patch.object(health, "ROOT", tmp_path),
    ):
        result = health.chk_pump_task_health()

    assert result["status"] == "FAIL"
    assert "CRITICAL" not in result["detail"]


def test_pump_installer_keeps_cold_cache_execution_headroom() -> None:
    installer = (
        Path(__file__).resolve().parents[1] / "install_pump_scheduled_task.ps1"
    ).read_text(encoding="utf-8")
    assert "-ExecutionTimeLimit (New-TimeSpan -Hours 1)" in installer
