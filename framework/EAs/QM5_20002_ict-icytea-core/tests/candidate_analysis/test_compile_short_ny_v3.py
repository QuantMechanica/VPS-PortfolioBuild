from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[2]
CONTROLLER_PATH = (
    EA_ROOT / "tools" / "candidate_analysis" / "compile_short_ny_v3.ps1"
)
CONTROLLER = CONTROLLER_PATH.read_text(encoding="utf-8")


def _function(name: str) -> str:
    start = CONTROLLER.index(f"function {name}")
    end = CONTROLLER.find("\nfunction ", start + len(name) + 9)
    return CONTROLLER[start:] if end < 0 else CONTROLLER[start:end]


def _assert_in_order(text: str, *needles: str) -> None:
    cursor = -1
    for needle in needles:
        position = text.find(needle, cursor + 1)
        assert position >= 0, f"missing ordered compiler fence: {needle}"
        assert position > cursor
        cursor = position


def _target_task_registration(text: str) -> str:
    start = text.index("$settings = New-ScheduledTaskSettingsSet")
    end = text.index("$task = Get-ScheduledTask -TaskName $taskName", start)
    return text[start:end]


def _assert_security_contract(text: str) -> None:
    target = _target_task_registration(text)
    for required in (
        "-DisallowHardTerminate",
        "-ExecutionTimeLimit (New-TimeSpan -Minutes 5)",
        "-MultipleInstances IgnoreNew",
        "Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath",
        "-RunLevel Limited",
    ):
        assert required in target
    assert "-StartWhenAvailable" not in target
    for required in (
        "$task.TaskName -cne $taskName",
        "$task.TaskPath -cne $taskPath",
        "$task.State.ToString() -cne 'Ready'",
        "$task.Settings.MultipleInstances.ToString() -cne 'IgnoreNew'",
        "[bool]$task.Settings.StartWhenAvailable -or",
        "[bool]$task.Settings.AllowHardTerminate -or",
        "[string]$task.Settings.ExecutionTimeLimit -cne 'PT5M'",
        "@($stageMq5, [string]$result.source_mq5_sha256, 'staged source')",
        "@($stageEx5, [string]$result.ex5_sha256, 'staged EX5')",
        "@($compileLog, [string]$result.compile_log_sha256, 'compile log')",
        "@($childLog, [string]$result.child_log_sha256, 'compile child log')",
        "@($includeManifest, [string]$result.include_manifest_sha256, 'include manifest')",
        "@($includeAudit, [string]$result.include_path_audit_sha256, 'include path audit')",
        "$outputSnapshotPostFenceSha256 -cne $outputSnapshotPostDrainSha256",
        "[IO.File]::Replace($tempTarget, $repoEx5, $null, $true)",
        "[IO.File]::Move($tempTarget, $repoEx5)",
        "Repository EX5 atomic publication verification failed.",
    ):
        assert required in text
    assert "-not [bool]$task.Settings.StartWhenAvailable -or" not in text
    assert "-not [bool]$task.Settings.AllowHardTerminate -or" not in text
    assert "$complete" not in text
    assert "$preexistingBackup" not in text
    assert "Remove-Item -LiteralPath $repoEx5" not in text


def test_powershell_ast_parses_without_execution() -> None:
    pwsh = shutil.which("pwsh")
    if pwsh is None:
        pytest.skip("PowerShell 7 is not installed")
    escaped = str(CONTROLLER_PATH).replace("'", "''")
    command = (
        "$tokens=$null; $errors=$null; "
        "[void][System.Management.Automation.Language.Parser]::ParseFile("
        f"'{escaped}',[ref]$tokens,[ref]$errors); "
        "if($errors.Count){$errors | ForEach-Object {$_.ToString()}; exit 1}; "
        "'AST_PARSE_PASS'"
    )
    completed = subprocess.run(
        [pwsh, "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", command],
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert completed.returncode == 0, completed.stdout + completed.stderr
    assert "AST_PARSE_PASS" in completed.stdout


def test_controller_binds_frozen_contract_and_source() -> None:
    assert "3fd49f2cea7575e659f1b1cf9c24c752a4a8e11db5e0c17cae69629a6f207f83" in CONTROLLER
    assert "6ee74c60a823fe87b03b40a2737ba67d113b2e52e7c09a05f42ba2084e17fefa" in CONTROLLER
    assert "3f1039f0eeb56ee882b5c3451eed3ee71567d6bc" in CONTROLLER
    assert "d902b04932c340dd1212b9420077d7cec6b0d80d" in CONTROLLER
    assert "git -C $repoRoot cat-file -e" in CONTROLLER
    assert "git -C $repoRoot merge-base --is-ancestor" in CONTROLLER


def test_controller_only_invokes_canonical_strict_compile_as_limited_task() -> None:
    assert "framework\\scripts\\compile_one.ps1" in CONTROLLER
    assert "-EAPath $stageMq5 -Strict -MetaEditorPath $metaEditor" in CONTROLLER
    assert "Start-Process" not in CONTROLLER
    assert "/config:" not in CONTROLLER
    target = _target_task_registration(CONTROLLER)
    assert "Start-ScheduledTask" not in target
    assert "-Trigger" not in target
    assert "-User $account -Password $plain -RunLevel Limited" in target


def test_target_task_settings_and_observed_contract_are_exact() -> None:
    _assert_security_contract(CONTROLLER)
    target = _target_task_registration(CONTROLLER)
    assert "-DisallowHardTerminate" in target
    assert "-StartWhenAvailable" not in target
    assert "$task.State.ToString() -cne 'Ready'" in CONTROLLER
    assert "$task.Settings.MultipleInstances.ToString() -cne 'IgnoreNew'" in CONTROLLER
    assert "[bool]$task.Settings.StartWhenAvailable -or" in CONTROLLER
    assert "[bool]$task.Settings.AllowHardTerminate -or" in CONTROLLER


def test_target_task_settings_constructor_materializes_exact_contract() -> None:
    pwsh = shutil.which("pwsh")
    if pwsh is None:
        pytest.skip("PowerShell 7 is not installed")
    command = (
        "$s=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries "
        "-DontStopIfGoingOnBatteries -DisallowHardTerminate -Hidden "
        "-ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew; "
        "if([bool]$s.StartWhenAvailable -or [bool]$s.AllowHardTerminate -or "
        "[string]$s.ExecutionTimeLimit -cne 'PT5M' -or "
        "$s.MultipleInstances.ToString() -cne 'IgnoreNew'){exit 1}; "
        "'TASK_SETTINGS_PASS'"
    )
    completed = subprocess.run(
        [pwsh, "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", command],
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert completed.returncode == 0, completed.stdout + completed.stderr
    assert "TASK_SETTINGS_PASS" in completed.stdout


def test_child_result_schema_has_exact_field_and_type_closure() -> None:
    reader = _function("Read-ValidatedCompileChildResult")
    match = re.search(r"\$fields = @\((.*?)\n    \)\n    \$kinds", reader, re.DOTALL)
    assert match is not None
    actual = tuple(re.findall(r"'([^']+)'", match.group(1)))
    expected = (
        "schema_version", "artifact_type", "success", "failure", "run_root", "run_id", "nonce",
        "request_sha256", "identity_account", "identity_sid", "profile_path", "common_path",
        "expected_task_name", "controller_path", "controller_sha256", "compile_one_path",
        "compile_one_sha256", "metaeditor_path", "metaeditor_sha256", "metaeditor_exit_code",
        "pwsh_path", "pwsh_sha256", "repo_include_path", "repo_include_snapshot_sha256", "errors",
        "warnings", "source_mq5_path", "source_mq5_sha256", "ex5_path", "ex5_size_bytes",
        "ex5_sha256", "compile_log_path", "compile_log_sha256", "child_log_path", "child_log_sha256",
        "include_manifest_path", "include_manifest_rows", "include_manifest_sha256",
        "include_path_audit_path", "include_path_audit_sha256", "included_paths_count",
        "outside_include_paths_count", "include_sync_targets", "lane_contract_sha256",
        "machine_credential_sha256", "machine_credential_helper_sha256", "rotation_receipt_sha256",
        "cleanup_helper_sha256", "started_utc", "finished_utc",
    )
    assert actual == expected
    assert "Read-ExactJson -Path $Path -ExpectedFields $fields" in reader
    assert "$kinds['failure'] = 'StringOrNull'" in reader
    assert "$kinds['include_sync_targets'] = 'Array'" in reader
    assert "-not [bool]$result.success -or $null -ne $result.failure" in reader
    assert "Compile child result exact path binding drifted." in reader
    assert "Compile child result artifact hash binding drifted." in reader
    assert "$actualTargetValues.Count -ne 2" in reader
    assert "$expectedTargetValues.Count -ne 2" in reader


def test_result_hash_binds_every_consumed_target_writable_artifact() -> None:
    reader = _function("Read-ValidatedCompileChildResult")
    for path_and_hash in (
        "@($ExpectedStageMq5, [string]$result.source_mq5_sha256)",
        "@($ExpectedStageEx5, [string]$result.ex5_sha256)",
        "@($compileLogPath, [string]$result.compile_log_sha256)",
        "@([string]$result.child_log_path, [string]$result.child_log_sha256)",
        "@([string]$result.include_manifest_path, [string]$result.include_manifest_sha256)",
        "@([string]$result.include_path_audit_path, [string]$result.include_path_audit_sha256)",
    ):
        assert path_and_hash in reader
    assert "[string]$binding[1] -cnotmatch '^[0-9a-f]{64}$'" in reader
    assert "(Get-Sha256 ([string]$binding[0])) -cne [string]$binding[1]" in reader


def test_complete_target_writable_tree_is_physical_and_rehashed() -> None:
    snapshot = _function("Get-PhysicalTreeSnapshot")
    assert "Get-ChildItem -LiteralPath $directory -Force" in snapshot
    assert "[IO.FileAttributes]::ReparsePoint" in snapshot
    assert "kind = 'directory'" in snapshot
    assert "kind = 'file'" in snapshot
    assert "sha256 = Get-Sha256 -Path $fullPath" in snapshot
    assert "Sort-Object relative_path, kind" in snapshot
    for required in (
        "$outputSnapshotPostDrain = @(Get-PhysicalTreeSnapshot -Root $outputRoot)",
        "$outputSnapshotPostDrainSha256 = Get-CanonicalObjectSha256 $outputSnapshotPostDrain",
        "$outputSnapshotPostFence = @(Get-PhysicalTreeSnapshot -Root $outputRoot)",
        "$outputSnapshotPostFenceSha256 = Get-CanonicalObjectSha256 $outputSnapshotPostFence",
        "$outputSnapshotPostFence.Count -ne $outputSnapshotPostDrain.Count",
        "$outputSnapshotPostFenceSha256 -cne $outputSnapshotPostDrainSha256",
    ):
        assert required in CONTROLLER


def test_physical_tree_snapshot_detects_deterministic_byte_tamper(tmp_path: Path) -> None:
    pwsh = shutil.which("pwsh")
    if pwsh is None:
        pytest.skip("PowerShell 7 is not installed")
    tree = tmp_path / "output"
    tree.mkdir()
    artifact = tree / "stage.ex5"
    artifact.write_bytes(b"frozen-ex5")
    harness = tmp_path / "snapshot_harness.ps1"
    harness.write_text(
        "param([string]$Root,[string]$Artifact)\n"
        + "Set-StrictMode -Version Latest\n$ErrorActionPreference='Stop'\n"
        + _function("Test-UnderRoot")
        + "\n"
        + _function("Assert-PhysicalPath")
        + "\n"
        + _function("Get-Sha256")
        + "\n"
        + _function("Get-CanonicalObjectSha256")
        + "\n"
        + _function("Get-PhysicalTreeSnapshot")
        + "\n"
        + "$before=@(Get-PhysicalTreeSnapshot -Root $Root)\n"
        + "$beforeHash=Get-CanonicalObjectSha256 $before\n"
        + "[IO.File]::WriteAllBytes($Artifact,[Text.Encoding]::UTF8.GetBytes('tampered-ex5'))\n"
        + "$after=@(Get-PhysicalTreeSnapshot -Root $Root)\n"
        + "$afterHash=Get-CanonicalObjectSha256 $after\n"
        + "if($beforeHash -ceq $afterHash){throw 'tamper escaped snapshot'}\n"
        + "'TREE_TAMPER_DETECTED'\n",
        encoding="utf-8",
    )
    completed = subprocess.run(
        [
            pwsh,
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-File",
            str(harness),
            "-Root",
            str(tree),
            "-Artifact",
            str(artifact),
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert completed.returncode == 0, completed.stdout + completed.stderr
    assert "TREE_TAMPER_DETECTED" in completed.stdout


def test_containment_order_is_drain_stop_disable_system_fence_rehash_publish() -> None:
    controller = _function("Invoke-CompileController")
    cleanup_start = controller.index("} finally {\n        $plain = $null")
    cleanup = controller[cleanup_start:]
    _assert_in_order(
        cleanup,
        "Remove-ScheduledTaskBounded -TaskName $taskName -DisableBeforeStop",
        "Stop-Dev1ProcessesExact -OwnerSid ([string]$accountState.Sid)",
        "$outputSnapshotPostDrain = @(Get-PhysicalTreeSnapshot -Root $outputRoot)",
        "Restore-TesterGroupsCanonical",
        "Disable-Dev1Account -State $accountState",
        "Assert-Contained -AccountState $accountState",
        "Invoke-CleanupLeaseFence -CleanupTaskName $cleanupTaskName",
        "Assert-Contained -AccountState $accountState -AllowedCleanupTaskName '__NO_TASK_ALLOWED__'",
        "@($stageMq5, [string]$result.source_mq5_sha256, 'staged source')",
        "$outputSnapshotPostFence = @(Get-PhysicalTreeSnapshot -Root $outputRoot)",
        "[IO.File]::Copy($stageEx5, $tempTarget, $false)",
        "[IO.File]::Replace($tempTarget, $repoEx5, $null, $true)",
        "Repository EX5 atomic publication verification failed.",
        "Write-AtomicJson -Path $evidencePath -Value $evidence",
    )


def test_cleanup_lease_is_disarmed_behind_system_action_mutex() -> None:
    fence = _function("Invoke-CleanupLeaseFence")
    _assert_in_order(
        fence,
        "Start-ScheduledTask -TaskName $CleanupTaskName",
        "Test-Path -LiteralPath $DisarmPath -PathType Leaf",
        "$fence = Enter-CleanupActionMutex -Name $CleanupActionMutexName",
        "Assert-CleanupEvidence -ResultPath $ResultPath -DisarmPath $DisarmPath",
        "Assert-Contained -AccountState $AccountState -AllowedCleanupTaskName '__NO_TASK_ALLOWED__'",
        "$fence.ReleaseMutex()",
    )
    evidence = _function("Assert-CleanupEvidence")
    assert "-not [bool]$disarm.lease_disarmed" in evidence
    assert "[bool]$disarm.cleanup_task_registered" in evidence
    assert "@($disarm.failures).Count -ne 0" in evidence


def test_ex5_publication_is_atomic_and_has_no_destructive_rollback() -> None:
    controller = _function("Invoke-CompileController")
    publication = controller[controller.index("$tempTarget = Join-Path"):]
    _assert_in_order(
        publication,
        "[IO.File]::Copy($stageEx5, $tempTarget, $false)",
        "EX5 delivery temp hash mismatch.",
        "[IO.File]::Replace($tempTarget, $repoEx5, $null, $true)",
        "[IO.File]::Move($tempTarget, $repoEx5)",
        "Remove-Item -LiteralPath $tempTarget -Force",
        "Repository EX5 atomic publication verification failed.",
    )
    assert "Copy-Item -LiteralPath $stageEx5 -Destination $repoEx5" not in publication
    assert "Remove-Item -LiteralPath $repoEx5" not in CONTROLLER
    assert "$preexistingBackup" not in CONTROLLER
    assert "$complete" not in CONTROLLER


def test_failure_paths_cannot_emit_pass_evidence_or_claim_success_early() -> None:
    controller = _function("Invoke-CompileController")
    _assert_in_order(
        controller,
        "if ($null -ne $primaryError -or $cleanupErrors.Count -ne 0)",
        "throw [InvalidOperationException]::new($combined)",
        "if (-not $compileSucceeded -or -not $cleanupTaskRegistered -or -not $cleanupLeaseDisarmed",
        "[IO.File]::Replace($tempTarget, $repoEx5, $null, $true)",
        "Repository EX5 atomic publication verification failed.",
        "Write-AtomicJson -Path $evidencePath -Value $evidence",
        "$finalEvidence = $evidence",
        "if ($null -ne $finalEvidence) { Write-Output",
    )
    assert "$delivered" not in CONTROLLER


@pytest.mark.parametrize(
    ("needle", "replacement"),
    (
        ("-DisallowHardTerminate -Hidden", "-Hidden"),
        ("[bool]$task.Settings.StartWhenAvailable -or", "-not [bool]$task.Settings.StartWhenAvailable -or"),
        ("@($stageEx5, [string]$result.ex5_sha256, 'staged EX5')", "@($stageMq5, [string]$result.source_mq5_sha256, 'staged source duplicate')"),
        ("$outputSnapshotPostFenceSha256 -cne $outputSnapshotPostDrainSha256", "$outputSnapshotPostFenceSha256 -ceq $outputSnapshotPostDrainSha256"),
        ("[IO.File]::Replace($tempTarget, $repoEx5, $null, $true)", "[IO.File]::Copy($tempTarget, $repoEx5, $true)"),
    ),
)
def test_deterministic_security_tamper_is_rejected(needle: str, replacement: str) -> None:
    assert CONTROLLER.count(needle) >= 1
    tampered = CONTROLLER.replace(needle, replacement, 1)
    with pytest.raises(AssertionError):
        _assert_security_contract(tampered)


def test_evidence_binds_compile_and_post_fence_artifact_closure() -> None:
    for field in (
        "contract_commit",
        "contract_sha256",
        "source_git_commit",
        "source_sha256",
        "metaeditor_sha256",
        "compile_one_sha256",
        "compile_controller_sha256",
        "compile_child_result_sha256",
        "compile_log_sha256",
        "include_sync_manifest_sha256",
        "include_path_audit_sha256",
        "target_writable_artifact_count",
        "target_writable_artifact_snapshot_post_drain_sha256",
        "target_writable_artifact_snapshot_post_fence_sha256",
        "source_manifest_sha256",
        "active_dev1_processes_after",
        "ephemeral_tasks_after",
        "git_head_after",
    ):
        assert f"{field} =" in CONTROLLER
    assert "$researchStatus = 'CARD_INTAKE_NOT_APPROVED'" in CONTROLLER
    assert "research_status = $researchStatus" in CONTROLLER
