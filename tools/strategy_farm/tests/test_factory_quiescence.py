from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
STRATEGY_FARM = REPO / "tools" / "strategy_farm"
sys.path.insert(0, str(STRATEGY_FARM))

import codex_fleet_pacer as pacer  # noqa: E402
import run_worktree_clean_task as cleaner  # noqa: E402


FACTORY_OFF = STRATEGY_FARM / "Factory_OFF.ps1"
FACTORY_ON = STRATEGY_FARM / "Factory_ON.ps1"
SNAPSHOT_TASK = REPO / "scripts" / "run_public_snapshot_task.ps1"
SWEEP = STRATEGY_FARM / "sweep_enqueue_built_eas.py"


def _powershell() -> str | None:
    return shutil.which("powershell.exe") or shutil.which("pwsh")


def _ps_array(source: str, name: str) -> set[str]:
    match = re.search(
        rf"\${re.escape(name)}\s*=\s*@\((.*?)\n\)",
        source,
        flags=re.DOTALL,
    )
    assert match, f"PowerShell array {name} not found"
    return set(re.findall(r"'([^']+)'", match.group(1)))


def test_pacer_factory_off_drains_only_managed_leases(tmp_path: Path, monkeypatch) -> None:
    farm = tmp_path / "farm"
    flag = farm / "state" / "FACTORY_OFF.flag"
    flag.parent.mkdir(parents=True)
    flag.write_text("{}", encoding="utf-8")
    state = tmp_path / "reports" / "pacer-state.json"
    log = tmp_path / "reports" / "pacer.log"
    leases = [
        {"pid": 101, "purpose": "fleet_pacer"},
        {"pid": 202, "purpose": "codex_orchestration"},
    ]
    calls = 0
    stopped: list[int] = []

    def list_live(_root: Path, **_kwargs: object) -> list[dict[str, object]]:
        nonlocal calls
        calls += 1
        return leases if calls == 1 else []

    monkeypatch.setattr(pacer, "FARM_ROOT", farm)
    monkeypatch.setattr(pacer, "FACTORY_OFF_FLAG", flag)
    monkeypatch.setattr(
        pacer,
        "FACTORY_MUTATION_LOCK",
        farm / "state" / "FACTORY_MUTATION.lock",
    )
    monkeypatch.setattr(pacer, "STATE", state)
    monkeypatch.setattr(pacer, "LOG", log)
    monkeypatch.setattr(pacer, "list_live_managed_codex_processes", list_live)
    monkeypatch.setattr(
        pacer,
        "terminate_managed_codex_pid",
        lambda _root, pid: stopped.append(pid)
        or {"pid": pid, "stopped": True, "reason": "test"},
    )
    monkeypatch.setattr(
        pacer,
        "_read_quota",
        lambda: pytest.fail("quota must not be read behind FACTORY_OFF"),
    )

    assert pacer.main([]) == 0
    assert stopped == [101, 202]
    payload = json.loads(state.read_text(encoding="utf-8"))
    assert payload["action"] == "factory_off_cleanup"
    assert payload["managed_before"] == 2
    assert payload["managed_remaining"] == 0


def test_pacer_rechecks_interlock_before_spawn(tmp_path: Path, monkeypatch) -> None:
    farm = tmp_path / "farm"
    flag = farm / "state" / "FACTORY_OFF.flag"
    state = tmp_path / "pacer-state.json"
    log = tmp_path / "pacer.log"

    def list_live(_root: Path, *, purpose: str | None = None) -> list[dict]:
        assert purpose == "fleet_pacer"
        flag.parent.mkdir(parents=True, exist_ok=True)
        flag.write_text("{}", encoding="utf-8")
        return []

    monkeypatch.setattr(pacer, "FARM_ROOT", farm)
    monkeypatch.setattr(pacer, "FACTORY_OFF_FLAG", flag)
    monkeypatch.setattr(
        pacer,
        "FACTORY_MUTATION_LOCK",
        farm / "state" / "FACTORY_MUTATION.lock",
    )
    monkeypatch.setattr(pacer, "STATE", state)
    monkeypatch.setattr(pacer, "LOG", log)
    monkeypatch.setattr(
        pacer,
        "_read_quota",
        lambda: (10.0, pacer._now() + pacer.dt.timedelta(hours=24)),
    )
    monkeypatch.setattr(pacer, "list_live_managed_codex_processes", list_live)
    monkeypatch.setattr(
        pacer,
        "_spawn_agent",
        lambda _prompt: pytest.fail("spawn must be blocked by the second interlock check"),
    )

    assert pacer.main([]) == 0
    payload = json.loads(state.read_text(encoding="utf-8"))
    assert payload["spawned"] == 0
    assert payload["action"] == "factory_off_no_spawn"


def test_pacer_spawn_lock_is_exclusive_and_rechecks_factory_off(
    tmp_path: Path, monkeypatch
) -> None:
    farm = tmp_path / "farm"
    flag = farm / "state" / "FACTORY_OFF.flag"
    lock = farm / "state" / "FACTORY_MUTATION.lock"
    monkeypatch.setattr(pacer, "FACTORY_OFF_FLAG", flag)
    monkeypatch.setattr(pacer, "FACTORY_MUTATION_LOCK", lock)
    monkeypatch.setattr(pacer, "LOG", tmp_path / "pacer.log")

    fd = pacer._acquire_spawn_lock()
    assert fd is not None
    assert lock.exists()
    pacer._release_spawn_lock(fd)
    assert not lock.exists()

    lock.write_text('{"pid":999,"owner":"other"}', encoding="utf-8")
    assert pacer._acquire_spawn_lock() is None
    assert "other" in lock.read_text(encoding="utf-8")
    lock.unlink()

    flag.write_text("{}", encoding="utf-8")
    assert pacer._acquire_spawn_lock() is None
    assert not lock.exists()


def _patch_cleaner_paths(tmp_path: Path, monkeypatch) -> tuple[Path, Path]:
    farm = tmp_path / "farm"
    log_dir = farm / "logs"
    flag = farm / "state" / "FACTORY_OFF.flag"
    mutation_lock = farm / "state" / "FACTORY_MUTATION.lock"
    monkeypatch.setattr(cleaner, "REPO_ROOT", tmp_path / "repo")
    monkeypatch.setattr(cleaner, "FARM_ROOT", farm)
    monkeypatch.setattr(cleaner, "LOG_DIR", log_dir)
    monkeypatch.setattr(cleaner, "LOCK_PATH", log_dir / "cleaner.lock")
    monkeypatch.setattr(cleaner, "FACTORY_OFF_FLAG", flag)
    monkeypatch.setattr(cleaner, "FACTORY_MUTATION_LOCK", mutation_lock)
    return flag, mutation_lock


def test_worktree_cleaner_skips_before_git_when_factory_off(
    tmp_path: Path, monkeypatch
) -> None:
    flag, mutation_lock = _patch_cleaner_paths(tmp_path, monkeypatch)
    flag.parent.mkdir(parents=True)
    flag.write_text("{}", encoding="utf-8")
    monkeypatch.setattr(
        cleaner,
        "_git_status",
        lambda: pytest.fail("git must not be touched behind FACTORY_OFF"),
    )

    assert cleaner.main() == 0
    assert not mutation_lock.exists()
    logs = list((tmp_path / "farm" / "logs").glob("worktree_clean_task_*.log"))
    assert len(logs) == 1
    assert json.loads(logs[0].read_text(encoding="utf-8"))["skipped"] == (
        "FACTORY_OFF.flag set"
    )


def test_worktree_cleaner_respects_busy_global_writer_lock(
    tmp_path: Path, monkeypatch
) -> None:
    _flag, mutation_lock = _patch_cleaner_paths(tmp_path, monkeypatch)
    mutation_lock.parent.mkdir(parents=True)
    mutation_lock.write_text('{"pid":999,"owner":"other"}', encoding="utf-8")
    monkeypatch.setattr(
        cleaner,
        "_git_status",
        lambda: pytest.fail("git must not be touched while writer lock is busy"),
    )

    assert cleaner.main() == 0
    assert mutation_lock.exists()


def test_public_snapshot_exits_cleanly_before_python_when_factory_off(
    tmp_path: Path,
) -> None:
    powershell = _powershell()
    if not powershell:
        pytest.skip("PowerShell is not installed")
    flag = tmp_path / "farm" / "state" / "FACTORY_OFF.flag"
    flag.parent.mkdir(parents=True)
    flag.write_text("{}", encoding="utf-8")
    log = tmp_path / "logs" / "snapshot.log"
    command = [
        powershell,
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(SNAPSHOT_TASK),
        "-RepoRoot",
        str(tmp_path / "missing-repo"),
        "-PythonExe",
        str(tmp_path / "missing-python.exe"),
        "-FactoryOffFlagPath",
        str(flag),
        "-FactoryMutationLockPath",
        str(tmp_path / "farm" / "state" / "FACTORY_MUTATION.lock"),
        "-LogPath",
        str(log),
    ]

    result = subprocess.run(command, text=True, capture_output=True, timeout=30)

    assert result.returncode == 0, result.stderr
    assert "skipped=FACTORY_OFF.flag" in log.read_text(encoding="utf-8")


def test_sweep_apply_exits_before_db_import_when_factory_off(tmp_path: Path) -> None:
    farm = tmp_path / "farm"
    flag = farm / "state" / "FACTORY_OFF.flag"
    flag.parent.mkdir(parents=True)
    flag.write_text("{}", encoding="utf-8")
    env = os.environ.copy()
    env.update(
        {
            "QM_STRATEGY_FARM_ROOT": str(farm),
            "QM_CANONICAL_REPO_ROOT": str(tmp_path / "missing-repo"),
            "QM_REPORT_ROOT": str(tmp_path / "reports"),
        }
    )

    result = subprocess.run(
        [sys.executable, str(SWEEP), "--apply"],
        text=True,
        capture_output=True,
        timeout=30,
        env=env,
    )

    assert result.returncode == 0, result.stderr
    assert "FACTORY_OFF.flag set" in result.stdout
    assert not (farm / "state" / "farm_state.sqlite").exists()
    assert not (farm / "state" / "FACTORY_MUTATION.lock").exists()


def test_off_on_share_complete_quiescence_set_and_exclude_live_paths() -> None:
    off = FACTORY_OFF.read_text(encoding="utf-8-sig")
    on = FACTORY_ON.read_text(encoding="utf-8-sig")
    off_tasks = _ps_array(off, "QM_QUIESCENCE_TASKS")
    on_tasks = _ps_array(on, "QM_QUIESCENCE_TASKS")

    assert off_tasks == on_tasks
    assert {
        "QM_Repo_Push",
        "QM_CodexParallel_RestoreOnReset",
        "QM_StrategyFarm_CodexFleetPacer",
        "QM_StrategyFarm_SweepEnqueue_Hourly",
        "QM_StrategyFarm_MailboxSourceIntake_Daily",
        "QM_Public_Snapshot_Hourly",
        "QM_StrategyFarm_TesterCachePurge",
        "QM_StrategyFarm_WorktreeClean_4h",
        "QM_StrategyFarm_HourlyMonitor_60min",
        "QM_WorkItemLogPruner_Daily_0310",
    } <= off_tasks
    assert not any("T_Live" in task or "FTMO" in task for task in off_tasks)
    assert "FACTORY_MUTATION.lock" in off
    assert "FACTORY_MUTATION.lock" in on
    assert "FACTORY_MUTATION.lock" in (STRATEGY_FARM / "codex_fleet_pacer.py").read_text(
        encoding="utf-8"
    )


def test_off_asserts_interlock_before_scheduler_or_process_mutation() -> None:
    source = FACTORY_OFF.read_text(encoding="utf-8-sig")
    main_start = source.index("Write-Host ''", source.index("$offRecord ="))
    interlock = source.index("Write-FactoryOffRecord $offRecord", main_start)
    disable_task = source.index("Disable-ScheduledTask", interlock)
    drain = source.index("Wait-FactoryMutationDrain -TimeoutSeconds 600", disable_task)
    stop_process = source.index(
        "Stop-EvidencedFactoryProcesses -EvidenceRecords $beforeProcessScan.phase_runners",
        interlock,
    )

    assert interlock < disable_task < drain < stop_process
    assert "if ($taskName -notin $QM_QUIESCENCE_TASKS" in source
    assert "OFF_INCOMPLETE" in source
    assert "pacer_cleanup_ok" in source


def test_on_requires_verified_off_and_repairs_only_after_release() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    release = source.index("Remove-Item -LiteralPath $factoryOffFlagPath")
    repair = source.index("    Invoke-RepairWithMutationLock", release)
    spawn = source.index("start_terminal_workers.py", repair)
    enable = source.index("Enable-ScheduledTask", repair)

    assert "verified schema-v2 OFF record required" in source
    assert release < repair < spawn < enable
    assert "OFF_RECOVERY_REQUIRED" in source
    assert "if ($taskName -in $QM_LIVE_TASKS" in source
    assert "Invoke-RestartHoldReleaseWithMutationLock" in source
    assert "--held-lock-nonce $script:factoryMutationLockNonce" in source
    assert "T_Live/FTMO task state, live terminals and AutoTrading were not touched" in source


def test_hourly_monitor_cannot_reenable_tasks_while_factory_is_off() -> None:
    source = (STRATEGY_FARM / "hourly_monitor.ps1").read_text(encoding="utf-8-sig")
    interlock = source.index("Test-Path -LiteralPath $factoryOffFlag")
    health = source.index("# 1. health")
    enable = source.index("Enable-ScheduledTask")

    assert interlock < health < enable
    assert "exit 0" in source[interlock:health]


def test_off_force_disables_permanent_hazards_while_monitor_is_inert() -> None:
    source = FACTORY_OFF.read_text(encoding="utf-8-sig")
    manifest = (STRATEGY_FARM / "qm_tasks.manifest.ps1").read_text(encoding="utf-8-sig")
    enforce_disabled = _ps_array(manifest, "QM_ENFORCE_DISABLED_TASKS")

    assert len(enforce_disabled) == 6
    assert "QM_StrategyFarm_UnreadableLinks_Friday" in enforce_disabled
    assert "$offDisableTasks = @($managedTasks + $QM_ENFORCE_DISABLED_TASKS" in source
    assert "foreach ($taskName in $offDisableTasks)" in source
    assert "$taskDrift = @($offDisableTasks | Where-Object" in source
    assert "task_enabled_before = $taskEnabledBefore" in source
    assert "$taskEnabledBefore[$taskName]" in source
    assert "$QM_ENFORCE_DISABLED_TASKS" not in source[
        source.index("$taskEnabledBefore ="):source.index("$offAt =")
    ]
