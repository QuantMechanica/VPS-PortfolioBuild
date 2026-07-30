from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
STRATEGY_FARM = ROOT / "tools" / "strategy_farm"
FACTORY_ON = STRATEGY_FARM / "Factory_ON.ps1"
FACTORY_OFF = STRATEGY_FARM / "Factory_OFF.ps1"
LOCK_PROTOCOL = STRATEGY_FARM / "factory_mutation_lock.ps1"
PREPARATION = (
    ROOT
    / "docs"
    / "ops"
    / "evidence"
    / "2026-07-30_factory_preparation_owner_decision.json"
)


def _ps_function(source: str, name: str) -> str:
    candidates = [
        index
        for token in (f"function {name} ", f"function {name}(")
        if (index := source.find(token)) >= 0
    ]
    if not candidates:
        raise ValueError(f"PowerShell function not found: {name}")
    start = min(candidates)
    next_function = source.find("\nfunction ", start + len(name) + 9)
    if next_function < 0:
        main_start = source.find("\n}\n\ntry {", start)
        if main_start < 0:
            return source[start:]
        return source[start : main_start + 2]
    return source[start:next_function]


def _ps_literal(value: Path | str) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def _run(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script),
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=30,
        check=False,
    )


def _records(tmp_path: Path) -> tuple[Path, Path, list[str]]:
    preparation = json.loads(PREPARATION.read_text(encoding="utf-8"))
    task_map = preparation["restore_intent"]["task_enabled_before"]
    initial = {
        "schema_version": 2,
        "state": "OFF",
        "updated_at": "2026-07-30T08:00:00Z",
        "task_enabled_before": task_map,
    }
    replacement = {
        **initial,
        "updated_at": "2026-07-30T08:00:01Z",
        "off_request_id": "new-concurrent-owner-intent",
    }
    initial_path = tmp_path / "initial.flag"
    replacement_path = tmp_path / "replacement.flag"
    initial_path.write_bytes(
        (json.dumps(initial, sort_keys=True, separators=(",", ":")) + "\n").encode()
    )
    replacement_path.write_bytes(
        (json.dumps(replacement, sort_keys=True, separators=(",", ":")) + "\n").encode()
    )
    return initial_path, replacement_path, list(task_map)


def _on_guard_harness(
    tmp_path: Path,
    *,
    scenario: str,
    appearance_context: str = "",
) -> tuple[str, Path, Path]:
    initial_path, replacement_path, tasks = _records(tmp_path)
    live_flag = tmp_path / "FACTORY_OFF.flag"
    request_flag = tmp_path / "FACTORY_OFF_REQUEST.flag"
    live_flag.write_bytes(initial_path.read_bytes())
    on = FACTORY_ON.read_text(encoding="utf-8-sig")
    helpers = "\n".join(
        (
            _ps_function(on, "ConvertTo-ExactTaskEnabledState"),
            _ps_function(on, "Assert-NoPendingFactoryOffRequest"),
            _ps_function(on, "Get-ValidatedFactoryOffSnapshot"),
            _ps_function(on, "Assert-BoundFactoryOffRecordUnchanged"),
            _ps_function(on, "Assert-NoFactoryOffIntent"),
            _ps_function(on, "Remove-BoundFactoryOffRecord"),
        )
    )
    task_literals = ",".join(_ps_literal(task) for task in tasks)
    initial_sha = hashlib.sha256(initial_path.read_bytes()).hexdigest()
    setup = f"""
. {_ps_literal(LOCK_PROTOCOL)}
$factoryOffFlagPath = {_ps_literal(live_flag)}
$factoryOffRequestPath = {_ps_literal(request_flag)}
$QM_QUIESCENCE_TASKS = @({task_literals})
$expectedRecord = Get-Content -LiteralPath {_ps_literal(initial_path)} -Raw | ConvertFrom-Json
$expectedMap = ConvertTo-ExactTaskEnabledState -State $expectedRecord.task_enabled_before `
    -ExpectedTasks $QM_QUIESCENCE_TASKS -SourceLabel 'test expected map'
$initial = Get-ValidatedFactoryOffSnapshot -ExpectedSha256 '{initial_sha}' `
    -ExpectedTaskMap $expectedMap -Context 'initial precheck'
$script:boundFactoryOffRawBytesBase64 = [string]$initial.raw_bytes_base64
$script:boundFactoryOffSha256 = [string]$initial.sha256
$script:boundFactoryOffTaskMap = $initial.task_enabled_before
$script:retainFactoryMutationLock = $false
"""
    replace = (
        f"[IO.File]::WriteAllBytes({_ps_literal(live_flag)}, "
        f"[IO.File]::ReadAllBytes({_ps_literal(replacement_path)}))"
    )
    if scenario == "replacement_after_precheck":
        body = f"""
{replace}
$caught = $false
try {{ Assert-BoundFactoryOffRecordUnchanged -Context 'after lock acquisition' | Out-Null }} `
catch {{ $caught = $_.Exception.Message -match 'raw-byte SHA-256 drift' }}
if (-not $caught -or -not $script:retainFactoryMutationLock) {{ exit 31 }}
"""
    elif scenario == "replacement_after_lock":
        body = f"""
Assert-BoundFactoryOffRecordUnchanged -Context 'after lock acquisition' | Out-Null
{replace}
$caught = $false
try {{ Assert-BoundFactoryOffRecordUnchanged -Context 'locked preflight' | Out-Null }} `
catch {{ $caught = $_.Exception.Message -match 'raw-byte SHA-256 drift' }}
if (-not $caught -or -not $script:retainFactoryMutationLock) {{ exit 32 }}
"""
    elif scenario == "replacement_immediately_pre_remove":
        body = f"""
Assert-BoundFactoryOffRecordUnchanged -Context 'after lock acquisition' | Out-Null
{replace}
$caught = $false
try {{ Remove-BoundFactoryOffRecord }} `
catch {{ $caught = $_.Exception.Message -match 'raw-byte SHA-256 drift' }}
if (-not $caught -or -not $script:retainFactoryMutationLock) {{ exit 33 }}
"""
    elif scenario == "appearance_after_remove":
        body = f"""
Remove-BoundFactoryOffRecord
if (Test-Path -LiteralPath $factoryOffFlagPath) {{ exit 34 }}
[IO.File]::WriteAllText($factoryOffRequestPath, 'new serialized emergency OFF request')
{replace}
$caught = $false
try {{ Assert-NoFactoryOffIntent -Context {_ps_literal(appearance_context)} }} `
catch {{ $caught = $_.Exception.Message -match 'OFF wins' }}
if (-not $caught -or -not $script:retainFactoryMutationLock) {{ exit 35 }}
"""
    else:
        raise AssertionError(scenario)
    script = helpers + setup + body + f"""
$actual = [Convert]::ToBase64String([IO.File]::ReadAllBytes({_ps_literal(live_flag)}))
$expected = [Convert]::ToBase64String([IO.File]::ReadAllBytes({_ps_literal(replacement_path)}))
if ($actual -cne $expected) {{ exit 36 }}
Write-Output 'PASS serialized-off-race'
"""
    return script, live_flag, replacement_path


@pytest.mark.parametrize(
    "scenario",
    [
        "replacement_after_precheck",
        "replacement_after_lock",
        "replacement_immediately_pre_remove",
    ],
)
def test_factory_on_never_deletes_a_replaced_bound_off_record(
    tmp_path: Path, scenario: str
) -> None:
    script, live_flag, replacement = _on_guard_harness(tmp_path, scenario=scenario)
    result = _run(script)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS serialized-off-race" in result.stdout
    assert live_flag.read_bytes() == replacement.read_bytes()


def test_factory_on_rejects_serialized_off_request_after_precheck(
    tmp_path: Path,
) -> None:
    script, live_flag, _ = _on_guard_harness(
        tmp_path, scenario="replacement_after_lock"
    )
    # Replace the simulated main-flag write with the canonical OFF-first request
    # marker.  The already-bound main OFF bytes must remain untouched.
    marker_write = next(
        line for line in script.splitlines() if line.startswith("[IO.File]::WriteAllBytes(")
    )
    script = script.replace(
        marker_write,
        "[IO.File]::WriteAllText($factoryOffRequestPath, 'concurrent OFF request')",
        1,
    )
    script = script.replace(
        "$caught = $_.Exception.Message -match 'raw-byte SHA-256 drift'",
        "$caught = $_.Exception.Message -match 'pending FACTORY_OFF request'",
        1,
    )
    # The shared harness compares against replacement bytes; for this case the
    # main flag must instead remain the initial bound record.
    compare_start = script.index("$actual = [Convert]::ToBase64String")
    script = script[:compare_start] + "Write-Output 'PASS serialized-off-request-race'\n"
    initial_bytes = live_flag.read_bytes()
    result = _run(script)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS serialized-off-request-race" in result.stdout
    assert live_flag.read_bytes() == initial_bytes


@pytest.mark.parametrize(
    "context",
    [
        "worker launch phase",
        "scheduled-task enable phase",
        "immediately before restart-hold release",
        "immediately after restart-hold release",
    ],
)
def test_factory_on_honors_new_off_appearance_during_guarded_phases(
    tmp_path: Path, context: str
) -> None:
    script, live_flag, replacement = _on_guard_harness(
        tmp_path,
        scenario="appearance_after_remove",
        appearance_context=context,
    )
    result = _run(script)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS serialized-off-race" in result.stdout
    assert live_flag.read_bytes() == replacement.read_bytes()


def test_factory_off_lock_is_exclusive_while_intent_is_published(
    tmp_path: Path,
) -> None:
    off = FACTORY_OFF.read_text(encoding="utf-8-sig")
    helpers = "\n".join(
        (
            _ps_function(off, "Enter-FactoryOffSerializationLock"),
            _ps_function(off, "Assert-FactoryOffSerializationLockHeld"),
            _ps_function(off, "Exit-FactoryOffSerializationLock"),
        )
    )
    lock_path = tmp_path / "FACTORY_MUTATION.lock"
    flag_path = tmp_path / "FACTORY_OFF.flag"
    script = helpers + f"""
. {_ps_literal(LOCK_PROTOCOL)}
$factoryMutationLockPath = {_ps_literal(lock_path)}
$script:factoryOffSerializationLock = Enter-FactoryOffSerializationLock -TimeoutSeconds 1
try {{
    Assert-FactoryOffSerializationLockHeld -Context 'test publish' | Out-Null
    $secondAcquired = $false
    try {{
        $second = [IO.File]::Open($factoryMutationLockPath, 'CreateNew', 'ReadWrite', 'Read')
        $secondAcquired = $true
        $second.Dispose()
    }} catch [IO.IOException] {{}}
    if ($secondAcquired) {{ exit 41 }}
    [IO.File]::WriteAllText({_ps_literal(flag_path)}, 'serialized OFF intent')
    if (-not (Test-Path -LiteralPath $factoryMutationLockPath) -or
        -not (Test-Path -LiteralPath {_ps_literal(flag_path)})) {{ exit 42 }}
}} finally {{
    $released = Exit-FactoryOffSerializationLock -LockStream $script:factoryOffSerializationLock
}}
if (-not $released -or (Test-Path -LiteralPath $factoryMutationLockPath)) {{ exit 43 }}
Write-Output 'PASS factory-off-exclusive-publish'
"""
    result = _run(script)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS factory-off-exclusive-publish" in result.stdout


def test_emergency_off_intent_precedes_and_survives_fake_lock_wait(
    tmp_path: Path,
) -> None:
    off = FACTORY_OFF.read_text(encoding="utf-8-sig")
    helpers = "\n".join(
        (
            _ps_function(off, "Write-QmFileCreateNew"),
            _ps_function(off, "Assert-EmergencyFactoryOffIntent"),
            _ps_function(off, "Enter-FactoryOffSerializationLock"),
        )
    )
    lock_path = tmp_path / "FACTORY_MUTATION.lock"
    flag_path = tmp_path / "FACTORY_OFF.flag"
    request_path = tmp_path / "FACTORY_OFF_REQUEST.flag"
    fake_lock = b'{"pid":4,"owner":"fake-live-owner","nonce":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}'
    lock_path.write_bytes(fake_lock)
    script = helpers + f"""
. {_ps_literal(LOCK_PROTOCOL)}
$factoryMutationLockPath = {_ps_literal(lock_path)}
$factoryOffFlagPath = {_ps_literal(flag_path)}
$factoryOffRequestPath = {_ps_literal(request_path)}
Assert-EmergencyFactoryOffIntent
if (-not (Test-Path -LiteralPath $factoryOffRequestPath) -or
    -not (Test-Path -LiteralPath $factoryOffFlagPath)) {{ exit 61 }}
$record = Get-Content -LiteralPath $factoryOffFlagPath -Raw | ConvertFrom-Json
if ([string]$record.state -cne 'OFF_REQUESTED') {{ exit 62 }}
$blocked = $false
try {{ Enter-FactoryOffSerializationLock -TimeoutSeconds 0 | Out-Null }} `
catch {{ $blocked = $_.Exception.Message -match 'emergency OFF intent remains asserted' }}
if (-not $blocked) {{ exit 63 }}
Write-Output 'PASS emergency-off-before-fake-lock-wait'
"""
    result = _run(script)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS emergency-off-before-fake-lock-wait" in result.stdout
    assert lock_path.read_bytes() == fake_lock
    assert request_path.exists()
    assert flag_path.exists()


def test_source_orders_serialization_revalidation_and_all_off_wins_checkpoints() -> None:
    on = FACTORY_ON.read_text(encoding="utf-8-sig")
    off = FACTORY_OFF.read_text(encoding="utf-8-sig")

    off_lock = off.index(
        "$script:factoryOffSerializationLock = Enter-FactoryOffSerializationLock"
    )
    emergency = off.rindex("Assert-EmergencyFactoryOffIntent", 0, off_lock)
    off_existing = off.index("$existingOff = $null", off_lock)
    off_capture = off.index("$taskEnabledBefore = [ordered]@{}", off_existing)
    off_publish = off.index("Write-FactoryOffRecord $offRecord", off_capture)
    off_final = off.rindex("Write-FactoryOffRecord $offRecord")
    off_verify = off.index("Assert-PublishedFactoryOffRecord", off_final)
    off_release = off.rindex("Exit-FactoryOffSerializationLock")
    assert emergency < off_lock < off_existing < off_capture < off_publish < off_final < off_verify < off_release
    assert "state = 'OFF_REQUESTED'" in off[:off_lock]

    precheck = on.index("-Context 'initial pre-lock binding'")
    on_lock = on.index("Enter-FactoryMutationLock -Owner 'factory_on_restart_window'")
    post_lock = on.index("-Context 'immediately after Factory_ON lock acquisition'", on_lock)
    conditional_remove = on.rindex("Remove-BoundFactoryOffRecord")
    assert precheck < on_lock < post_lock < conditional_remove
    assert "Remove-Item -LiteralPath $factoryOffFlagPath" not in on
    remove_helper = _ps_function(on, "Remove-BoundFactoryOffRecord")
    assert "Assert-BoundFactoryOffRecordUnchanged" in remove_helper
    assert "Remove-QmFileIfContentMatches" in remove_helper

    launch = on.index("start_terminal_workers.py", conditional_remove)
    enable = on.index("Enable-ScheduledTask", launch)
    pre_hold = on.index("immediately before restart-hold release", enable)
    hold = on.rindex("Invoke-RestartHoldReleaseWithMutationLock")
    post_hold = on.index("immediately after restart-hold release", hold)
    assert conditional_remove < launch < enable < pre_hold < hold < post_hold
    assert "Assert-NoFactoryOffIntent" in on[conditional_remove:post_hold]


def test_factory_on_rollback_preserves_external_off_bytes(tmp_path: Path) -> None:
    on = FACTORY_ON.read_text(encoding="utf-8-sig")
    rollback = _ps_function(on, "Invoke-FailClosedRollback")
    flag = tmp_path / "FACTORY_OFF.flag"
    codex = tmp_path / "codex_parallel.txt"
    raw = b'{"state":"OFF","off_request_id":"new-owner-intent"}\n'
    flag.write_bytes(raw)
    script = rollback + f"""
$factoryOffFlagPath = {_ps_literal(flag)}
$codexParallelPath = {_ps_literal(codex)}
$managedTasks = @()
$pythonExe = {_ps_literal(tmp_path / 'missing-python.exe')}
$pacerScript = {_ps_literal(tmp_path / 'missing-pacer.py')}
function Write-FactoryOffRecord {{ throw 'must not overwrite external OFF intent' }}
function Assert-FactoryOffRecoveryRecord {{ throw 'must not validate replacement recovery' }}
function Stop-FactoryProcesses {{}}
Invoke-FailClosedRollback -Reason 'test rollback' -PriorOffRecord $null
if (-not $script:externalFactoryOffIntentPreserved) {{ exit 51 }}
Write-Output 'PASS rollback-preserved-external-off'
"""
    result = _run(script)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS rollback-preserved-external-off" in result.stdout
    assert flag.read_bytes() == raw
