from __future__ import annotations

import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[3]
STRATEGY_FARM = ROOT / "tools" / "strategy_farm"
FACTORY_ON = STRATEGY_FARM / "Factory_ON.ps1"
HEALTH_GATE = STRATEGY_FARM / "factory_restart_health.ps1"
MANIFEST = STRATEGY_FARM / "qm_tasks.manifest.ps1"
PS_TEST = STRATEGY_FARM / "tests" / "Test-FactoryRestartPostStartHealth.ps1"


def _ps_array(source: str, variable_name: str) -> str:
    return source.split(f"${variable_name} = @(", 1)[1].split("\n)", 1)[0]


def test_factory_on_health_gate_precedes_restart_hold_release() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")

    load_gate = source.index(". $restartHealthPath")
    remove_off = source.index("Remove-Item -LiteralPath $factoryOffFlagPath")
    quota_start = source.index(
        "Start-ScheduledTask -TaskName 'QM_StrategyFarm_QuotaPull' -ErrorAction Stop"
    )
    router_start = source.index(
        "Start-ScheduledTask -TaskName 'QM_StrategyFarm_AgentRouter_5min' -ErrorAction Stop"
    )
    pump_start = source.index(
        "Start-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction Stop"
    )
    health_wait = source.index("$postStartHealth = Wait-QmFactoryPostStartHealth")
    release_hold = source.rindex("Invoke-RestartHoldReleaseWithMutationLock")

    assert load_gate < remove_off
    assert quota_start < router_start < pump_start < health_wait < release_hold
    assert "factoryPostStartHealthTimeoutSeconds = 300" in source
    assert "Invoke-FailClosedRollback -Reason $failure" in source[health_wait:]


def test_factory_on_builds_exact_non_live_task_and_worker_expectations() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")

    expected_map = source.index("$expectedTaskEnabledState = [ordered]@{}")
    mutation_lock = source.index(
        "$script:factoryRestartMutationLock = Enter-FactoryMutationLock"
    )
    assert expected_map < mutation_lock
    assert "Add-QmExpectedTaskEnabledState" in source[expected_map:mutation_lock]
    assert "if ($taskName -in $QM_LIVE_TASKS" in source[expected_map:mutation_lock]
    assert "registration " in source[expected_map:mutation_lock]
    assert "cardinality is not exactly one" in source[expected_map:mutation_lock]

    assert "$expectedWorkerTerminals = @(1..10" in source
    assert "invalid disabled-terminal rows" in source
    assert "duplicate disabled terminals" in source
    assert "-ExpectedWorkerTerminals $expectedWorkerTerminals" in source
    assert "-ExpectedSessionId $mySession" in source


def test_health_evaluator_is_fail_closed_for_fresh_tasks_and_exact_workers() -> None:
    source = HEALTH_GATE.read_text(encoding="utf-8-sig")

    assert "$script:QmFactoryRestartHealthProtocolVersion = 1" in source
    assert "enabled = [bool]$task.Settings.Enabled" in source
    assert "([string]$task.State -ne 'Disabled')" not in source
    assert "Settings.Enabled boolean" in source
    assert "enabled-state mismatch" in source
    assert "last run predates this restart window" in source
    assert "has not advanced beyond its pre-start baseline" in source
    assert "does not have a successful result" in source
    assert "-ne 'Ready'" in source
    assert "Unexpected worker terminal" in source
    assert "is duplicated" in source
    assert "is not visible" in source
    assert "is not in interactive session" in source
    assert "health gate timed out" in source


def test_unreadable_links_task_remains_disabled_pending_owner_decision() -> None:
    source = MANIFEST.read_text(encoding="utf-8-sig")
    always_on = _ps_array(source, "QM_ALWAYSON_TASKS")
    enforce_disabled = _ps_array(source, "QM_ENFORCE_DISABLED_TASKS")

    assert "QM_StrategyFarm_UnreadableLinks_Friday" not in always_on
    assert "QM_StrategyFarm_UnreadableLinks_Friday" in enforce_disabled
    assert "pending explicit OWNER decision" in enforce_disabled


def test_isolated_powershell_health_contract() -> None:
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    result = subprocess.run(
        (
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(PS_TEST),
        ),
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS Test-FactoryRestartPostStartHealth.ps1" in result.stdout


def test_restart_powershell_sources_parse() -> None:
    quoted_paths = ",".join(f"'{path}'" for path in (FACTORY_ON, HEALTH_GATE, MANIFEST, PS_TEST))
    parser = (
        f"$files=@({quoted_paths});"
        "foreach($file in $files){"
        "$tokens=$null;$errors=$null;"
        "[System.Management.Automation.Language.Parser]::ParseFile("
        "$file,[ref]$tokens,[ref]$errors)|Out-Null;"
        "if($errors.Count){$errors|ForEach-Object{Write-Error $_};exit 1}}"
    )
    result = subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", parser),
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
