from __future__ import annotations

import re
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
        assert root.findtext(".//t:LogonType", namespaces=NS) == "ServiceAccount"
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

    owner_check = script.index("$normalizedOwnerAuthorizedAtUtc = Assert-OwnerAuthorization")
    lock_enter = script.index("$lock = Enter-TaskContractMutationLock")
    receipt_reserve = script.index("-CreateOnly", lock_enter)
    task_loop = script.index("foreach ($entry in $plan.entries)", receipt_reserve)
    assert owner_check < lock_enter < receipt_reserve < task_loop
