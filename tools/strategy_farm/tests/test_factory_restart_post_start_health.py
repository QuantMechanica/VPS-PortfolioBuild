from __future__ import annotations

import json
import hashlib
import os
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[3]
STRATEGY_FARM = ROOT / "tools" / "strategy_farm"
FACTORY_ON = STRATEGY_FARM / "Factory_ON.ps1"
HEALTH_GATE = STRATEGY_FARM / "factory_restart_health.ps1"
MANIFEST = STRATEGY_FARM / "qm_tasks.manifest.ps1"
PS_TEST = STRATEGY_FARM / "tests" / "Test-FactoryRestartPostStartHealth.ps1"
OWNER_DECISION = (
    ROOT
    / "docs"
    / "ops"
    / "evidence"
    / "2026-07-30_factory_preparation_owner_decision.json"
)


def _ps_array(source: str, variable_name: str) -> str:
    return source.split(f"${variable_name} = @(", 1)[1].split("\n)", 1)[0]


def _single_quoted_values(array_source: str) -> list[str]:
    return re.findall(r"'([^']+)'", array_source)


def _ps_function(source: str, name: str) -> str:
    start = source.index(f"function {name}")
    next_function = source.find("\nfunction ", start + len(name) + 9)
    if next_function < 0:
        return source[start:]
    return source[start:next_function]


def test_factory_on_health_gate_precedes_restart_hold_release() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")

    load_gate = source.index(". $restartHealthPath")
    remove_off = source.index("Remove-BoundFactoryOffRecord")
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
    assert "factoryPostStartHealthTimeoutSeconds = 1800" in source
    assert "Invoke-FailClosedRollbackWithLockRetention" in source[health_wait:]


def test_factory_on_builds_exact_non_live_task_and_worker_expectations() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    owner_decision = json.loads(OWNER_DECISION.read_text(encoding="utf-8"))

    expected_map = source.index("$expectedTaskEnabledState = [ordered]@{}")
    mutation_lock = source.index(
        "$script:factoryRestartMutationLock = Enter-FactoryMutationLock"
    )
    assert expected_map < mutation_lock
    assert "Add-QmExpectedTaskEnabledState" in source[expected_map:mutation_lock]
    assert "if ($taskName -in $QM_LIVE_TASKS" in source[expected_map:mutation_lock]
    assert "registration " in source[expected_map:mutation_lock]
    assert "cardinality is not exactly one" in source[expected_map:mutation_lock]

    disabled_terminals = _single_quoted_values(
        _ps_array(source, "QM_OWNER_APPROVED_DISABLED_TERMINALS")
    )
    worker_terminals = _single_quoted_values(
        _ps_array(source, "QM_OWNER_APPROVED_WORKER_TERMINALS")
    )
    assert owner_decision["worker_policy"]["t5_quarantine_ratified"] is True
    assert disabled_terminals == ["T5"]
    assert worker_terminals == owner_decision["worker_policy"]["expected_terminals"]
    assert len(worker_terminals) == owner_decision["worker_policy"]["expected_worker_count"] == 9
    assert "invalid disabled-terminal rows" in source
    assert "duplicate disabled terminals" in source
    assert "disabled-terminal exact-set mismatch" in source
    assert "worker-terminal exact-set mismatch" in source
    assert "$expectedWorkerTerminals = @($QM_OWNER_APPROVED_WORKER_TERMINALS)" in source
    assert "$expectWorkers -ne 9" in source
    assert "WARNING: non-standard disabled terminals" not in source
    assert "-ExpectedWorkerTerminals $expectedWorkerTerminals" in source
    assert "-ExpectedSessionId $mySession" in source
    assert source.index("Get-CanonicalDisabledTerminalPolicySnapshot") < source.index(
        "$offRecord = $null"
    )
    already_on = source.index("$alreadyOnWorkers = Test-ExactFactoryWorkerCohort")
    already_on_exit = source.index("FACTORY ALREADY ON")
    assert already_on < already_on_exit
    assert "$alreadyOnWorkers.healthy" in source[already_on:already_on_exit]
    assert "$alreadyOnWorkers.observed_count -eq 9" in source[already_on:already_on_exit]
    assert "T5 must be absent" in source


def test_factory_on_passes_only_the_seven_owner_approved_restart_hold_ids() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    owner_decision = json.loads(OWNER_DECISION.read_text(encoding="utf-8"))
    approved = _single_quoted_values(
        _ps_array(source, "QM_OWNER_APPROVED_RESTART_HOLD_IDS")
    )

    assert approved == owner_decision["restart_holds"]["authorized_work_item_ids"]
    assert len(set(approved)) == owner_decision["restart_holds"]["authorized_release_count"] == 7
    assert "--expected-work-item-id" not in source
    assert "--held-lock-owner-pid" not in source
    assert "--held-lock-owner" not in source
    assert "--held-lock-nonce" not in source
    assert "--factory-on-lock-nonce" in source
    assert source.index("$postStartHealth = Wait-QmFactoryPostStartHealth") < source.rindex(
        "Invoke-RestartHoldReleaseWithMutationLock"
    )


def test_factory_on_pins_canonical_owner_decision_sha_commit_and_blob() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    raw = OWNER_DECISION.read_bytes()
    sha256 = hashlib.sha256(raw).hexdigest()
    blob = hashlib.sha1(
        f"blob {len(raw)}\0".encode("ascii") + raw, usedforsecurity=False
    ).hexdigest()
    commit = subprocess.run(
        (
            "git",
            "log",
            "-1",
            "--format=%H",
            "--",
            OWNER_DECISION.relative_to(ROOT).as_posix(),
        ),
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()

    assert f"$QM_OWNER_DECISION_SHA256 = '{sha256}'" in source
    assert f"$QM_OWNER_DECISION_COMMIT = '{commit}'" in source
    assert f"$QM_OWNER_DECISION_BLOB = '{blob}'" in source
    assert "Assert-CanonicalOwnerRestartDecision" in source
    assert source.rindex("Assert-CanonicalOwnerRestartDecision") < source.index(
        "$script:factoryRestartMutationLock = Enter-FactoryMutationLock"
    )


def test_disabled_terminal_hash_is_revalidated_under_lock_before_launch_and_release() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    lock = source.index("$script:factoryRestartMutationLock = Enter-FactoryMutationLock")
    launch = source.index("& $pythonExe 'C:\\QM\\repo\\tools\\strategy_farm\\start_terminal_workers.py'")
    health = source.index("$postStartHealth = Wait-QmFactoryPostStartHealth")
    release = source.rindex("Invoke-RestartHoldReleaseWithMutationLock")
    launch_check = source.rfind("-Context 'immediately before worker launch'", lock, launch)
    release_check = source.rfind(
        "-Context 'immediately before restart-hold release'", health, release
    )

    assert launch_check > lock
    assert release_check > health
    assert "$script:disabledTerminalPolicySha256" in source[lock:release]


def test_runtime_authority_is_separate_fresh_and_precedes_every_mutation() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    preparation = json.loads(OWNER_DECISION.read_text(encoding="utf-8"))
    runtime_gate = source.rindex(
        "$script:runtimeAuthorization = Get-CanonicalRuntimeActivationAuthorization"
    )
    first_mutation = source.index(
        "$script:factoryRestartMutationLock = Enter-FactoryMutationLock"
    )

    assert runtime_gate < source.index("$offRecord = $null") < first_mutation
    assert "factory_runtime_activation.py" in source[:runtime_gate]
    assert "runtime-activation validator did not return authorized=true" in source
    assert preparation["restore_intent"]["factory_on_authorized"] is False
    assert preparation["restore_intent"]["runtime_flag_upgrade_authorized"] is False
    assert preparation["explicit_exclusions"]["hold_release_now"] is False
    assert "-CanonicalRuntimeHost" in source
    assert "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" in source
    assert "-EncodedCommand" in _ps_function(source, "Assert-CanonicalFactoryOnHostProcess")


def test_already_on_shortcut_requires_lock_absence_and_full_exact_task_contract() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    expected_map = source.index("$expectedTaskEnabledState = [ordered]@{}")
    off_branch = source.index("} else {", source.index("$offRecord = $null"))
    lock_reject = source.index("interlock absent but mutation lock exists", off_branch)
    workers = source.index("$alreadyOnWorkers = Test-ExactFactoryWorkerCohort", lock_reject)
    task_snapshot = source.index("$alreadyOnTaskSnapshot = Get-QmFactoryPostStartSnapshot", workers)
    task_contract = source.index("$alreadyOnTasks = Test-ExactFactoryTaskContract", task_snapshot)
    success = source.index("FACTORY ALREADY ON", task_contract)

    assert expected_map < off_branch < lock_reject < workers < task_snapshot < task_contract < success
    map_source = source[expected_map:off_branch]
    assert "$QM_FACTORY_TASKS + $QM_AI_TASKS + $QM_RESPAWN_TASKS" in map_source
    assert "foreach ($taskName in $QM_QUIESCENCE_TASKS)" in map_source
    assert "foreach ($taskName in $QM_ENFORCE_DISABLED_TASKS)" in map_source
    assert "foreach ($taskName in $QM_ALWAYSON_TASKS)" in map_source
    assert "$taskName -in $QM_LIVE_TASKS" in map_source
    assert "$alreadyOnTasks.healthy" in source[task_contract:success]
    assert "$alreadyOnTasks.observed_count -eq $expectedTaskEnabledState.Count" in source[
        task_contract:success
    ]


def test_immediate_full_health_revalidation_is_under_lock_before_hold_release() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    lock = source.index("$script:factoryRestartMutationLock = Enter-FactoryMutationLock")
    waited = source.index("$postStartHealth = Wait-QmFactoryPostStartHealth", lock)
    snapshot = source.index("$releaseHealthSnapshot = Get-QmFactoryPostStartSnapshot", waited)
    evaluation = source.index("$releaseHealth = Test-QmFactoryPostStartHealth", snapshot)
    rejection = source.index("if (-not $releaseHealth.healthy)", evaluation)
    release = source.rindex("$restartHoldRelease = Invoke-RestartHoldReleaseWithMutationLock")

    assert lock < waited < snapshot < evaluation < rejection < release
    assert "-ExpectedTaskEnabledState $expectedTaskEnabledState" in source[snapshot:release]
    assert "-ExpectedWorkerTerminals $expectedWorkerTerminals" in source[snapshot:release]
    assert "-ExpectedSessionId $mySession" in source[snapshot:release]


def test_release_helper_parses_committed_result_and_never_greens_degraded_evidence() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    helper = _ps_function(source, "Invoke-RestartHoldReleaseWithMutationLock")
    exit_check = helper.index("if ($releaseExitCode -ne 0)")
    committed = helper.index("$script:restartHoldMutationCommitted = $true")
    parse = helper.index("ConvertFrom-Json")
    evidence = helper.index("$result.post_commit_evidence.status")
    green_output = helper.index("Write-Host ($releaseOutput")

    assert exit_check < committed < parse < evidence < green_output
    assert "$result.mutation_committed" in helper
    assert "$result.runtime_decision_id" in helper
    assert "$result.runtime_decision_sha256" in helper
    assert "RESTART_HOLDS_COMMITTED_EVIDENCE_FAILED" in helper
    assert "$script:retainFactoryMutationLock = $true" in helper[evidence:green_output]


def test_exact_task_contract_rejects_all_non_exact_observations() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    helper = _ps_function(source, "Test-ExactFactoryTaskContract")
    harness = helper + r'''
$expected = [ordered]@{A=$true;B=$false;C=$true}
$rows = @(
    [pscustomobject]@{task_name='A';present=$true;enabled=$true;probe_error=''},
    [pscustomobject]@{task_name='B';present=$true;enabled=$false;probe_error=''},
    [pscustomobject]@{task_name='C';present=$true;enabled=$true;probe_error=''}
)
$healthy = Test-ExactFactoryTaskContract -TaskRows $rows -ExpectedState $expected
if (-not $healthy.healthy -or $healthy.observed_count -ne 3) { exit 20 }
$missing = Test-ExactFactoryTaskContract -TaskRows @($rows | Where-Object task_name -ne 'B') -ExpectedState $expected
if ($missing.healthy -or -not (@($missing.errors | Where-Object {$_ -match "Expected task 'B' is missing"}).Count)) { exit 21 }
$extra = Test-ExactFactoryTaskContract -TaskRows @($rows + [pscustomobject]@{task_name='D';present=$true;enabled=$true;probe_error=''}) -ExpectedState $expected
if ($extra.healthy -or -not (@($extra.errors | Where-Object {$_ -match "Unexpected task 'D'"}).Count)) { exit 22 }
$duplicate = Test-ExactFactoryTaskContract -TaskRows @($rows + $rows[0]) -ExpectedState $expected
if ($duplicate.healthy -or -not (@($duplicate.errors | Where-Object {$_ -match 'duplicated'}).Count)) { exit 23 }
$badState = @($rows | ForEach-Object { if ($_.task_name -eq 'B') {[pscustomobject]@{task_name='B';present=$true;enabled=$true;probe_error=''}} else {$_} })
$mismatch = Test-ExactFactoryTaskContract -TaskRows $badState -ExpectedState $expected
if ($mismatch.healthy -or -not (@($mismatch.errors | Where-Object {$_ -match 'enabled-state mismatch'}).Count)) { exit 24 }
$unreadable = @($rows | ForEach-Object { if ($_.task_name -eq 'C') {[pscustomobject]@{task_name='C';present=$true;enabled=$true;probe_error='denied'}} else {$_} })
$probe = Test-ExactFactoryTaskContract -TaskRows $unreadable -ExpectedState $expected
if ($probe.healthy -or -not (@($probe.errors | Where-Object {$_ -match 'cannot be verified'}).Count)) { exit 25 }
Write-Output 'PASS exact-task-contract'
'''
    result = subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", harness),
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS exact-task-contract" in result.stdout


def test_failed_off_rollback_retains_lock_instead_of_deleting_it() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    catch = source.index("rollback could not reassert/verify OFF")
    finally_block = source.index("} finally {", catch)

    assert "$script:retainFactoryMutationLock = $true" in source[:finally_block]
    assert "-RetainForRecovery $true" in source[finally_block:]
    rollback_helper = _ps_function(
        source, "Invoke-FailClosedRollbackWithLockRetention"
    )
    completion_helper = _ps_function(source, "Complete-FactoryMutationLockAfterAttempt")
    harness = rollback_helper + "\n" + completion_helper + r'''
$script:retainFactoryMutationLock = $false
function Invoke-FailClosedRollback { param($Reason,$PriorOffRecord) throw 'simulated OFF write failure' }
$rollbackThrew = $false
try {
    Invoke-FailClosedRollbackWithLockRetention -OriginalFailure 'start failure' -PriorOffRecord $null
} catch {
    $rollbackThrew = $_.Exception.Message -match 'simulated OFF write failure'
}
if (-not $rollbackThrew -or -not $script:retainFactoryMutationLock) { exit 8 }
$script:disposed = $false
$script:deletePathCalled = $false
$stream = [pscustomobject]@{}
$stream | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $script:disposed = $true }
function Exit-FactoryMutationLock { param($LockStream) $script:deletePathCalled = $true; return $true }
$released = Complete-FactoryMutationLockAfterAttempt -LockStream $stream -RetainForRecovery $script:retainFactoryMutationLock
if ($released -or -not $script:disposed -or $script:deletePathCalled) { exit 9 }
Write-Output 'PASS retained-lock'
'''
    result = subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", harness),
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS retained-lock" in result.stdout


def test_exact_worker_cohort_rejects_t5_missing_and_wrong_session() -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    helper = _ps_function(source, "Test-ExactFactoryWorkerCohort")
    harness = helper + r'''
$expected = @('T1','T2','T3','T4','T6','T7','T8','T9','T10')
$rows = @($expected | ForEach-Object { [pscustomobject]@{process_id=100;session_id=7;terminal=$_} })
$healthy = Test-ExactFactoryWorkerCohort -WorkerRows $rows -ExpectedTerminals $expected -ExpectedSessionId 7
if (-not $healthy.healthy -or $healthy.observed_count -ne 9) { exit 10 }
$withT5 = @($rows + [pscustomobject]@{process_id=200;session_id=7;terminal='T5'})
$badT5 = Test-ExactFactoryWorkerCohort -WorkerRows $withT5 -ExpectedTerminals $expected -ExpectedSessionId 7
if ($badT5.healthy -or -not (@($badT5.errors | Where-Object { $_ -match "Unexpected worker terminal 'T5'" }).Count)) { exit 11 }
$missing = @($rows | Where-Object { $_.terminal -ne 'T9' })
$badMissing = Test-ExactFactoryWorkerCohort -WorkerRows $missing -ExpectedTerminals $expected -ExpectedSessionId 7
if ($badMissing.healthy -or -not (@($badMissing.errors | Where-Object { $_ -match "Expected worker terminal 'T9'.*not visible" }).Count)) { exit 12 }
$wrongSession = @($expected | ForEach-Object { [pscustomobject]@{process_id=300;session_id=8;terminal=$_} })
$badSession = Test-ExactFactoryWorkerCohort -WorkerRows $wrongSession -ExpectedTerminals $expected -ExpectedSessionId 7
if ($badSession.healthy -or -not (@($badSession.errors | Where-Object { $_ -match 'not in interactive session 7' }).Count)) { exit 13 }
Write-Output 'PASS exact-worker-cohort'
'''
    result = subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", harness),
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS exact-worker-cohort" in result.stdout


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
