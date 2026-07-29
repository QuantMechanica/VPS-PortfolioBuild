from __future__ import annotations

import inspect
from pathlib import Path

from tools.strategy_farm import farmctl


def test_both_work_item_spawn_paths_assign_job_before_identity_metadata() -> None:
    for function in (
        farmctl._spawn_run_smoke_for_work_item,
        farmctl._spawn_phase_runner_for_work_item,
    ):
        source = inspect.getsource(function)
        reap_at = source.index("reap_finished_job_objects()")
        flags_at = source.index("creationflags = suspended_runner_creation_flags()")
        popen_at = source.index("proc = subprocess.Popen(")
        bind_at = source.index("process_identity = bind_spawned_process_to_kill_job(")
        capture_at = source.index("_capture_spawned_process_identity", bind_at)
        suspended_contract_at = source.index(
            'process_created_suspended=(sys.platform == "win32")', bind_at
        )

        assert reap_at < flags_at < popen_at < bind_at < capture_at < suspended_contract_at
        assert source.count("proc = subprocess.Popen(") == 1
        assert source.count("bind_spawned_process_to_kill_job(") == 1
        assert "**process_identity" in source


def test_dispatch_persists_job_assignment_metadata_with_creation_identity() -> None:
    source = inspect.getsource(farmctl.dispatch_work_items)

    creation_at = source.index('"process_creation_key": spawn["process_creation_key"]')
    assigned_at = source.index('"job_object_assigned": spawn.get("job_object_assigned")')
    mode_at = source.index('"job_object_mode": spawn.get("job_object_mode")')
    registry_at = source.index(
        '"job_object_registry_key": spawn.get("job_object_registry_key")'
    )
    suspended_at = source.index(
        '"process_started_suspended": spawn.get("process_started_suspended")'
    )
    resumed_at = source.index(
        '"primary_thread_resumed": spawn.get("primary_thread_resumed")'
    )

    assert creation_at < assigned_at < mode_at < registry_at < suspended_at < resumed_at


def test_farmctl_job_binding_import_is_not_optional_or_fail_open() -> None:
    source = inspect.getsource(farmctl)

    assert "bind_spawned_process_to_kill_job" in source
    assert "except JobObjectError" not in inspect.getsource(
        farmctl._spawn_run_smoke_for_work_item
    )
    assert "except JobObjectError" not in inspect.getsource(
        farmctl._spawn_phase_runner_for_work_item
    )


def test_production_caller_is_a_resident_daemon_that_owns_job_handles() -> None:
    source = (Path(farmctl.__file__).with_name("terminal_worker.py")).read_text(
        encoding="utf-8"
    )

    assert "resident production owner" in source
    assert "while not _STOP" in source
    assert "orderly worker exit intentionally closes" in source
