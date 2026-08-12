from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parents[3]
PACKAGE = ROOT / "tools" / "ops" / "task_contract_fix_2026-07-28"
NS = {"t": "http://schemas.microsoft.com/windows/2004/02/mit/task"}


def _after(task_name: str) -> ElementTree.Element:
    return ElementTree.parse(PACKAGE / "after" / f"{task_name}.xml").getroot()


def _duration_seconds(value: str) -> int:
    match = re.fullmatch(
        r"PT(?:(?P<hours>\d+)H)?(?:(?P<minutes>\d+)M)?(?:(?P<seconds>\d+)S)?",
        value,
    )
    assert match is not None
    return (
        int(match.group("hours") or 0) * 3600
        + int(match.group("minutes") or 0) * 60
        + int(match.group("seconds") or 0)
    )


def test_auth_bound_after_contracts_use_qm_admin_console_wrapper() -> None:
    expected = {
        "QM_StrategyFarm_GeminiOrchestration_15min": (
            "run_agent_orchestration_task.py",
            "-WaitSeconds 14100",
        ),
        "QM_StrategyFarm_MailboxSourceIntake_Daily": (
            "mailbox_source_intake.py",
            "-WaitSeconds 2640",
        ),
    }
    for task_name, (entry_script, wait_arg) in expected.items():
        root = _after(task_name)
        assert root.findtext(".//t:UserId", namespaces=NS) == "S-1-5-18"
        # On this host, schema v1.3 infers ServiceAccount from the SYSTEM SID;
        # an explicit LogonType element is rejected by the Scheduler COM parser.
        assert root.find(".//t:LogonType", namespaces=NS) is None
        command = root.findtext(".//t:Actions/t:Exec/t:Command", namespaces=NS) or ""
        arguments = root.findtext(".//t:Actions/t:Exec/t:Arguments", namespaces=NS) or ""
        description = root.findtext(".//t:RegistrationInfo/t:Description", namespaces=NS) or ""
        assert command.endswith(r"\powershell.exe")
        assert "run_in_console_session.ps1" in arguments
        assert "-TargetUser 'qm-admin'" in arguments
        assert entry_script in arguments
        assert wait_arg in arguments
        assert "qm-admin" in description
        exe_match = re.search(r"-Exe\s+'([^']+)'", arguments)
        wait_match = re.search(r"-WaitSeconds\s+(\d+)", arguments)
        execution_limit = root.findtext(
            ".//t:Settings/t:ExecutionTimeLimit", namespaces=NS
        )
        assert exe_match is not None
        assert exe_match.group(1).lower().endswith(r"\pythonw.exe")
        assert wait_match is not None
        assert execution_limit is not None
        assert int(wait_match.group(1)) <= _duration_seconds(execution_limit)


def test_package_documents_enabled_state_preservation_and_split_scopes() -> None:
    readme = (PACKAGE / "README.md").read_text(encoding="utf-8")
    assert "There is no transient default-enable window" in readme
    assert "-TaskScope Factory" in readme
    assert "-TaskScope Live" in readme


def test_apply_script_ignores_enabled_only_for_identity_and_preserves_it_on_write() -> None:
    script = (PACKAGE / "Apply-TaskContractFix.ps1").read_text(encoding="utf-8-sig")
    assert "//t:Settings/t:Enabled" in script
    assert "Set-TaskXmlEnabledState" in script
    assert "ConvertTo-TaskSchedulerXmlString" in script
    assert "$enabled = Get-TaskXmlEnabledState -XmlText $liveXml" in script
    assert "-Enabled $enabled" in script
    assert "Operational State=Running/Ready is deliberately" in script
    assert "$currentFingerprint -ne $Entry.live_contract_sha256" in script
    assert "$currentEnabled -ne $Entry.enabled_before" in script
    assert "Get-ScheduledTask" not in script
    assert "Enable-ScheduledTask" not in script
    assert "Disable-ScheduledTask" not in script
    assert "Start-ScheduledTask" not in script
    assert "Stop-ScheduledTask" not in script


def test_registration_xml_is_a_utf16_declared_string_with_same_contract() -> None:
    script_path = PACKAGE / "Apply-TaskContractFix.ps1"
    sample_path = PACKAGE / "after" / "QM_StrategyFarm_AgyGovernor.xml"
    probe = r"""
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    $env:QM_TASK_FIX_SCRIPT,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -ne 0) { throw 'Apply script did not parse.' }
$required = @(
    'Get-BytesSha256',
    'Get-TextSha256',
    'Get-TaskContractFingerprint',
    'Get-TaskXmlEnabledState',
    'ConvertTo-TaskSchedulerXmlString',
    'Set-TaskXmlEnabledState',
    'Join-TaskContractErrorMessage'
)
foreach ($name in $required) {
    $matches = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $name
    }, $true))
    if ($matches.Count -ne 1) { throw "Expected one function definition for $name" }
    Invoke-Expression $matches[0].Extent.Text
}
$source = [IO.File]::ReadAllText($env:QM_TASK_FIX_SAMPLE, [Text.Encoding]::UTF8)
$beforeFingerprint = Get-TaskContractFingerprint -XmlText $source
[string]$serialized = Set-TaskXmlEnabledState -XmlText $source -Enabled $false
$afterFingerprint = Get-TaskContractFingerprint -XmlText $serialized
[ordered]@{
    dotnet_type = $serialized.GetType().FullName
    declaration = [regex]::Match($serialized, '^<\?xml[^?]+\?>').Value
    enabled = Get-TaskXmlEnabledState -XmlText $serialized
    before_fingerprint = $beforeFingerprint
    after_fingerprint = $afterFingerprint
    reparses = $null -ne ([xml]$serialized).DocumentElement
    combined_error = Join-TaskContractErrorMessage `
        -Primary 'register failed' `
        -Additional 'lock cleanup failed'
} | ConvertTo-Json -Compress
"""
    env = os.environ.copy()
    env["QM_TASK_FIX_SCRIPT"] = str(script_path)
    env["QM_TASK_FIX_SAMPLE"] = str(sample_path)
    completed = subprocess.run(
        [
            "powershell.exe",
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            probe,
        ],
        text=True,
        capture_output=True,
        check=True,
        env=env,
    )
    payload = json.loads(completed.stdout.strip())
    assert payload["dotnet_type"] == "System.String"
    assert payload["declaration"].lower() == (
        '<?xml version="1.0" encoding="utf-16"?>'
    )
    assert payload["enabled"] is False
    assert payload["before_fingerprint"] == payload["after_fingerprint"]
    assert payload["reparses"] is True
    assert payload["combined_error"] == "register failed; lock cleanup failed"


def test_factory_registration_payloads_pass_windows_scheduler_com_parser() -> None:
    script_path = PACKAGE / "Apply-TaskContractFix.ps1"
    probe = r"""
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $env:QM_TASK_FIX_SCRIPT,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -ne 0) { throw 'Apply script did not parse.' }
$required = @(
    'Get-BytesSha256',
    'Get-TextSha256',
    'Get-TaskContractFingerprint',
    'ConvertTo-TaskSchedulerXmlString',
    'Set-TaskXmlEnabledState',
    'Assert-TaskSchedulerXmlRegistrationPayload'
)
foreach ($name in $required) {
    $matches = @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $name
    }, $true))
    if ($matches.Count -ne 1) { throw "Expected one function definition for $name" }
    Invoke-Expression $matches[0].Extent.Text
}
$names = @(
    'QM_StrategyFarm_AgyGovernor',
    'QM_StrategyFarm_CodexFleetPacer',
    'QM_StrategyFarm_GeminiOrchestration_15min',
    'QM_StrategyFarm_MailboxSourceIntake_Daily',
    'QM_StrategyFarm_WorkerDedupe'
)
$rows = @()
foreach ($name in $names) {
    foreach ($kind in @('after', 'before')) {
        $path = Join-Path (Join-Path $env:QM_TASK_FIX_PACKAGE $kind) ($name + '.xml')
        $source = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
        [string]$serialized = if ($kind -eq 'after') {
            Set-TaskXmlEnabledState -XmlText $source -Enabled $false
        } else {
            ConvertTo-TaskSchedulerXmlString -Document ([xml]$source)
        }
        Assert-TaskSchedulerXmlRegistrationPayload `
            -XmlText $serialized `
            -TaskLabel "$name $kind test"

        $service = $null
        $definition = $null
        try {
            $service = New-Object -ComObject 'Schedule.Service'
            [void]$service.Connect()
            $definition = $service.NewTask(0)
            $definition.XmlText = $serialized
            $rows += [pscustomobject][ordered]@{
                task = $name
                kind = $kind
                user_id = [string]$definition.Principal.UserId
                logon_type = [int]$definition.Principal.LogonType
            }
        } finally {
            if ($null -ne $definition) {
                [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($definition)
            }
            if ($null -ne $service) {
                [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($service)
            }
        }
    }
}
@($rows) | ConvertTo-Json -Compress
"""
    env = os.environ.copy()
    env["QM_TASK_FIX_SCRIPT"] = str(script_path)
    env["QM_TASK_FIX_PACKAGE"] = str(PACKAGE)
    completed = subprocess.run(
        [
            "powershell.exe",
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            probe,
        ],
        text=True,
        capture_output=True,
        check=True,
        env=env,
    )
    rows = json.loads(completed.stdout.strip())
    assert len(rows) == 10
    desired = [row for row in rows if row["kind"] == "after"]
    assert len(desired) == 5
    assert all(row["user_id"] == "SYSTEM" for row in desired)
    assert all(row["logon_type"] == 5 for row in desired)


def test_mutation_requires_one_explicit_factory_or_live_scope() -> None:
    script = (PACKAGE / "Apply-TaskContractFix.ps1").read_text(encoding="utf-8-sig")
    assert "[ValidateSet('Factory', 'Live')]" in script
    assert "$selected = if ($Scope -eq 'Factory')" in script
    assert "Live task contracts are plan-only" in script
    assert "$factoryTaskNames" in script
    assert "$liveTaskNames" in script


def test_mutation_is_off_hash_plan_lock_receipt_and_compensation_bound() -> None:
    script = (PACKAGE / "Apply-TaskContractFix.ps1").read_text(encoding="utf-8-sig")
    assert "ExpectedFactoryOffSha256" in script
    assert "ExpectedPlanId" in script
    assert "OwnerDecisionRef" in script
    assert "OwnerAuthorizedBy" in script
    assert "OwnerAuthorizedAtUtc" in script
    assert "ReceiptPath" in script
    assert "QmFactoryMutationLockProtocolVersion -ne 2" in script
    assert "FileMode]::CreateNew" in script
    assert "Assert-FactoryOffHash" in script
    assert "New-TaskContractPlan" in script
    assert "Assert-PlanApplicable" in script
    assert "Restore-AttemptedTasks" in script
    assert "compensation=PASS" in script
    assert "Remove-QmFactoryMutationLockIfUnchanged" in script
    assert "WHATIF_VALIDATED" in script
    assert "preimage_xml_base64" in script
    assert "FAILED_COMPENSATED" in script
    assert "FAILED_UNCOMPENSATED_LOCK_RETAINED" in script
    assert "RETAINED_FAIL_CLOSED" in script
    assert "APPLIED_VERIFIED" in script
    assert "ROLLED_BACK_VERIFIED" in script
    assert "primary_error = $null" in script
    assert "cleanup_error = $null" in script

    catch_start = script.index("} catch {\n    $failure = $_.Exception.Message")
    failure_capture = script.index(
        "$receiptDocument.failure.primary_error = [ordered]@{", catch_start
    )
    compensation = script.index("$recovery = Restore-AttemptedTasks", catch_start)
    assert catch_start < failure_capture < compensation
    assert "$receiptDocument.failure.cleanup_error = [ordered]@{" in script
    assert "RETAINED_CLEANUP_ERROR" in script
    assert "LOCK_RELEASE_EXCEPTION" in script
    assert "IDENTITY_RELEASE_FAILED" in script
    assert "Join-TaskContractErrorMessage" in script

    owner_check = script.index("$normalizedOwnerAuthorizedAtUtc = Assert-OwnerAuthorization")
    protocol_import = script.index(". $mutationProtocolPath")
    preflight = script.index("$preflight = New-TaskContractPlan")
    preflight_applicable = script.index("Assert-PlanApplicable -Plan $preflight")
    preflight_com = script.index(
        "Assert-TaskContractRegistrationPayloads -Plan $preflight"
    )
    lock_enter = script.index("$lock = Enter-TaskContractMutationLock")
    receipt_reserve = script.index("-CreateOnly", lock_enter)
    task_loop = script.index("foreach ($entry in $plan.entries)", receipt_reserve)
    assert (
        protocol_import
        < owner_check
        < preflight
        < preflight_applicable
        < preflight_com
        < lock_enter
    )
    assert lock_enter < receipt_reserve < task_loop


def test_lock_protocol_and_registration_payloads_validate_before_create_new() -> None:
    script = (PACKAGE / "Apply-TaskContractFix.ps1").read_text(encoding="utf-8-sig")
    assert script.count(". $mutationProtocolPath") == 1
    assert script.index(". $mutationProtocolPath") < script.index(
        "function Enter-TaskContractMutationLock"
    )
    enter_start = script.index("function Enter-TaskContractMutationLock")
    enter_end = script.index("function Exit-TaskContractMutationLock", enter_start)
    enter_body = script[enter_start:enter_end]
    assert enter_body.index("Assert-TaskContractMutationProtocolAvailable") < (
        enter_body.index("FileMode]::CreateNew")
    )

    preflight = script.index("$preflight = New-TaskContractPlan")
    com_preflight = script.index(
        "Assert-TaskContractRegistrationPayloads -Plan $preflight"
    )
    lock_enter = script.index("$lock = Enter-TaskContractMutationLock")
    assert preflight < com_preflight < lock_enter
    assert "desired_xml = Set-TaskXmlEnabledState" in script
    assert "original_registration_xml = ConvertTo-TaskSchedulerXmlString" in script
    assert "-XmlText $entry.desired_xml" in script
    assert "-XmlText $entry.original_registration_xml" in script
    assert "New-Object -ComObject 'Schedule.Service'" in script
    assert "$taskDefinition = $taskService.NewTask(0)" in script
    assert "$taskDefinition.XmlText = $XmlText" in script
    assert "-Xml $entry.original_registration_xml" in script

    plan_mode = script.index("if ($mode -eq 'PLAN')")
    plan_build = script.index("$plan = New-TaskContractPlan", plan_mode)
    plan_com = script.index("Assert-TaskContractRegistrationPayloads -Plan $plan", plan_build)
    plan_output = script.index("if ($Json.IsPresent)", plan_com)
    assert plan_mode < plan_build < plan_com < plan_output
