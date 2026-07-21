from __future__ import annotations

import hashlib
import json
import os
import secrets
import shutil
import subprocess
import sys
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[2]
TOOLS = EA_ROOT / "tools" / "candidate_analysis"
G1_AUDITOR = TOOLS / "audit_short_ny_reverse_time.py"
G1_SCHEDULER = TOOLS / "run_outcome_fenced_task.ps1"
G1_CONTROL = TOOLS / "assert_qm20002_control_path.ps1"
G2_SCHEDULER = TOOLS / "run_outcome_fenced_task_g2.ps1"
G2_CONTROL = TOOLS / "assert_qm20002_control_path_g2.ps1"


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _pwsh() -> Path | None:
    candidates = [
        Path(r"C:\Program Files\PowerShell\7\pwsh.exe"),
        Path(shutil.which("pwsh") or ""),
        Path(shutil.which("powershell") or ""),
    ]
    return next((candidate.resolve() for candidate in candidates if candidate.is_file()), None)


PWSH = _pwsh()
WINDOWS_PWSH = pytest.mark.skipif(
    os.name != "nt" or PWSH is None,
    reason="requires Windows PowerShell ScheduledTasks support",
)


def _run_pwsh_file(script: Path, *arguments: str, timeout: int = 60) -> subprocess.CompletedProcess[str]:
    assert PWSH is not None
    return subprocess.run(
        [
            str(PWSH),
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(script),
            *arguments,
        ],
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def _last_json(stdout: str) -> dict:
    lines = [line.strip() for line in stdout.splitlines() if line.strip()]
    assert lines, "PowerShell emitted no JSON"
    payload = json.loads(lines[-1])
    assert isinstance(payload, dict)
    return payload


def test_g1_frozen_runtime_bytes_remain_exact() -> None:
    expected = {
        G1_AUDITOR: (249680, "4f9068c710a34d7f0bd72ad0c93a856d966ca58943ca84fa48f4addc686b0a2f"),
        G1_SCHEDULER: (11213, "a11e058453f362785a9c7f2d94b4194dd61de3dcadbeb0184884628e4dfe3bf2"),
        G1_CONTROL: (32942, "b3be96b0beb5b264390ba6087deacfd9fb3174537c2495d566e431d71089fc2f"),
    }
    for path, (size, digest) in expected.items():
        assert path.stat().st_size == size
        assert _sha256(path) == digest


def test_g2_helpers_have_distinct_closed_identity_and_root() -> None:
    scheduler = G2_SCHEDULER.read_text(encoding="utf-8")
    control = G2_CONTROL.read_text(encoding="utf-8")

    assert "^QM_QM20002_G2_AUDIT_[0-9a-f]{24}$" in scheduler
    assert "^QM_QM20002_AUDIT_[0-9a-f]{24}$" not in scheduler
    assert "$controlRoot = Join-Path $anchorRoot 'short_ny_reverse_time_g2'" in control
    assert "$controlRoot = Join-Path $anchorRoot 'short_ny_reverse_time'" not in control
    assert "CommandLine" not in scheduler
    assert "CommandLine" not in control


@WINDOWS_PWSH
@pytest.mark.parametrize("helper", [G2_SCHEDULER, G2_CONTROL])
def test_g2_helpers_parse_without_powershell_ast_errors(helper: Path, tmp_path: Path) -> None:
    harness = tmp_path / "parse_helper.ps1"
    harness.write_text(
        """
param([Parameter(Mandatory=$true)][string]$Helper)
$tokens = $null
$errors = $null
[void][Management.Automation.Language.Parser]::ParseFile(
    [IO.Path]::GetFullPath($Helper), [ref]$tokens, [ref]$errors
)
if ($errors.Count -ne 0) {
    $errors | ForEach-Object { [Console]::Error.WriteLine($_.Message) }
    exit 2
}
[ordered]@{ status = 'PASS'; error_count = 0 } | ConvertTo-Json -Compress
""".strip()
        + "\n",
        encoding="utf-8",
    )
    completed = _run_pwsh_file(harness, "-Helper", str(helper))
    assert completed.returncode == 0, completed.stderr
    assert _last_json(completed.stdout) == {"status": "PASS", "error_count": 0}


@WINDOWS_PWSH
def test_g2_non_null_normalization_and_actual_trigger_rejection(tmp_path: Path) -> None:
    harness = tmp_path / "exercise_g2_contract.ps1"
    harness.write_text(
        r"""
param([Parameter(Mandatory=$true)][string]$Helper)
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    [IO.Path]::GetFullPath($Helper), [ref]$tokens, [ref]$errors
)
if ($errors.Count -ne 0) { throw 'G2 helper AST failed.' }
$wanted = @('ConvertTo-QmFullPath', 'Get-QmNonNullItemCount', 'Assert-QmTaskContract')
foreach ($name in $wanted) {
    $matches = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -ceq $name
    }, $true))
    if ($matches.Count -ne 1) { throw "Expected one production function $name." }
    Invoke-Expression $matches[0].Extent.Text
}

$TaskName = 'QM_QM20002_G2_AUDIT_0123456789abcdef01234567'
$ExecutionLimitSeconds = 60
$windowsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$identity = [pscustomobject]@{ Name = $windowsIdentity.Name; Sid = $windowsIdentity.User.Value }
$executable = [IO.Path]::GetFullPath((Get-Process -Id $PID).Path)
$working = [IO.Path]::GetFullPath((Get-Location).Path)
$contract = [pscustomobject]@{
    Description = 'synthetic exact G2 task'
    PythonExe = $executable
    RepoRoot = $working
    Arguments = 'synthetic arguments'
}
$principal = [pscustomobject]@{
    UserId = $identity.Name
    LogonType = 'S4U'
    RunLevel = 'Highest'
}
$settings = [pscustomobject]@{
    MultipleInstances = 'IgnoreNew'
    Enabled = $true
    AllowDemandStart = $true
    StartWhenAvailable = $true
    AllowHardTerminate = $true
    Hidden = $true
    DisallowStartIfOnBatteries = $false
    StopIfGoingOnBatteries = $false
    RunOnlyIfIdle = $false
    RunOnlyIfNetworkAvailable = $false
    WakeToRun = $false
    RestartCount = 0
    RestartInterval = ''
    ExecutionTimeLimit = 'PT1M'
}
$action = [pscustomobject]@{
    Execute = $executable
    Arguments = $contract.Arguments
    WorkingDirectory = $working
}
$realTrigger = [pscustomobject]@{ Kind = 'actual-trigger' }
$secondTrigger = [pscustomobject]@{ Kind = 'second-trigger' }
$nullOnly = [object[]]::new(1)
$nullOnly[0] = $null
$empty = [object[]]::new(0)
$mixedTrigger = [object[]]::new(2)
$mixedTrigger[0] = $null
$mixedTrigger[1] = $realTrigger
$twoTriggers = [object[]]@($realTrigger, $secondTrigger)
$mixedAction = [object[]]::new(2)
$mixedAction[0] = $null
$mixedAction[1] = $action

function New-SyntheticTask([object]$Triggers, [object]$Actions) {
    return [pscustomobject]@{
        TaskName = $TaskName
        TaskPath = '\'
        Description = $contract.Description
        Principal = $principal
        Triggers = $Triggers
        Actions = $Actions
        Settings = $settings
    }
}

function Test-TriggerRejected([object]$Triggers) {
    try {
        Assert-QmTaskContract -Task (New-SyntheticTask $Triggers $mixedAction) `
            -Contract $contract -Identity $identity
        return $false
    } catch {
        if ($_.Exception.Message -notlike '*triggerless*') { throw }
        return $true
    }
}

function Test-ActionsRejected([object]$Actions) {
    try {
        Assert-QmTaskContract -Task (New-SyntheticTask $nullOnly $Actions) `
            -Contract $contract -Identity $identity
        return $false
    } catch {
        if ($_.Exception.Message -notlike '*exactly one action*') { throw }
        return $true
    }
}

# A host-style one-element null trigger collection and null+one action must pass.
Assert-QmTaskContract -Task (New-SyntheticTask $nullOnly $mixedAction) `
    -Contract $contract -Identity $identity

$nullActions = [object[]]::new(1)
$nullActions[0] = $null
$twoActions = [object[]]@($action, $action)
$result = [ordered]@{
    null_scalar = Get-QmNonNullItemCount -Items $null
    empty = Get-QmNonNullItemCount -Items $empty
    null_only = Get-QmNonNullItemCount -Items $nullOnly
    object = Get-QmNonNullItemCount -Items $realTrigger
    null_plus_object = Get-QmNonNullItemCount -Items $mixedTrigger
    two_objects = Get-QmNonNullItemCount -Items $twoTriggers
    one_trigger_rejected = Test-TriggerRejected $realTrigger
    null_plus_trigger_rejected = Test-TriggerRejected $mixedTrigger
    two_triggers_rejected = Test-TriggerRejected $twoTriggers
    null_actions_rejected = Test-ActionsRejected $nullActions
    two_actions_rejected = Test-ActionsRejected $twoActions
}
$result | ConvertTo-Json -Compress
""".strip()
        + "\n",
        encoding="utf-8",
    )
    completed = _run_pwsh_file(harness, "-Helper", str(G2_SCHEDULER))
    assert completed.returncode == 0, completed.stderr
    assert _last_json(completed.stdout) == {
        "null_scalar": 0,
        "empty": 0,
        "null_only": 0,
        "object": 1,
        "null_plus_object": 1,
        "two_objects": 2,
        "one_trigger_rejected": True,
        "null_plus_trigger_rejected": True,
        "two_triggers_rejected": True,
        "null_actions_rejected": True,
        "two_actions_rejected": True,
    }


def _scheduled_task_call(
    operation: str,
    *,
    task_name: str,
    python_exe: Path,
    tool_path: Path,
    job_path: Path,
    repo_root: Path,
    helper_sha256: str,
) -> subprocess.CompletedProcess[str]:
    assert PWSH is not None
    return subprocess.run(
        [
            str(PWSH),
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(G2_SCHEDULER),
            "-Operation",
            operation,
            "-TaskName",
            task_name,
            "-PythonExe",
            str(python_exe),
            "-ToolPath",
            str(tool_path),
            "-JobPath",
            str(job_path),
            "-RepoRoot",
            str(repo_root),
            "-ExecutionLimitSeconds",
            "60",
            "-ExpectedHelperSha256",
            helper_sha256,
        ],
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=60,
        check=False,
    )


@WINDOWS_PWSH
def test_real_temporary_triggerless_task_roundtrip_reports_zero_and_is_removed(
    tmp_path: Path,
) -> None:
    task_name = "QM_QM20002_G2_AUDIT_" + secrets.token_hex(12)
    tool = tmp_path / "never_started.py"
    job = tmp_path / "never_started_job.json"
    tool.write_text("raise SystemExit('this scheduled action must never start')\n", encoding="utf-8")
    job.write_text("{}\n", encoding="utf-8")
    helper_sha = _sha256(G2_SCHEDULER)

    cleanup_script = tmp_path / "cleanup_task.ps1"
    cleanup_script.write_text(
        """
param([Parameter(Mandatory=$true)][string]$TaskName)
$task = Get-ScheduledTask -TaskName $TaskName -TaskPath '\\' -ErrorAction SilentlyContinue
if ($null -ne $task) {
    Unregister-ScheduledTask -TaskName $TaskName -TaskPath '\\' -Confirm:$false -ErrorAction Stop
}
if ($null -ne (Get-ScheduledTask -TaskName $TaskName -TaskPath '\\' -ErrorAction SilentlyContinue)) {
    throw 'Temporary G2 task remained after cleanup.'
}
""".strip()
        + "\n",
        encoding="utf-8",
    )

    # Recover from a same-name residue only; the 96-bit random suffix keeps the
    # exact cleanup target isolated from every production task.
    initial_cleanup = _run_pwsh_file(cleanup_script, "-TaskName", task_name)
    assert initial_cleanup.returncode == 0, initial_cleanup.stderr
    try:
        registered = _scheduled_task_call(
            "Register",
            task_name=task_name,
            python_exe=Path(sys.executable).resolve(),
            tool_path=tool,
            job_path=job,
            repo_root=tmp_path,
            helper_sha256=helper_sha,
        )
        assert registered.returncode == 0, registered.stderr
        register_payload = _last_json(registered.stdout)
        assert register_payload["operation"] == "Register"
        assert register_payload["task_name"] == task_name
        assert register_payload["triggers_count"] == 0
        assert register_payload["actions_count"] == 1
        assert register_payload["last_run_utc"] is None

        inspected = _scheduled_task_call(
            "Inspect",
            task_name=task_name,
            python_exe=Path(sys.executable).resolve(),
            tool_path=tool,
            job_path=job,
            repo_root=tmp_path,
            helper_sha256=helper_sha,
        )
        assert inspected.returncode == 0, inspected.stderr
        inspect_payload = _last_json(inspected.stdout)
        assert inspect_payload["operation"] == "Inspect"
        assert inspect_payload["task_name"] == task_name
        assert inspect_payload["state"] == "Ready"
        assert inspect_payload["triggers_count"] == 0
        assert inspect_payload["actions_count"] == 1
        assert inspect_payload["last_run_utc"] is None
    finally:
        cleanup = _run_pwsh_file(cleanup_script, "-TaskName", task_name)
        assert cleanup.returncode == 0, cleanup.stderr
