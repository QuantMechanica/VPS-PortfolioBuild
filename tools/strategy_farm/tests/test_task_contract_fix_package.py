from __future__ import annotations

from pathlib import Path
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parents[3]
PACKAGE = ROOT / "tools" / "ops" / "task_contract_fix_2026-07-28"
NS = {"t": "http://schemas.microsoft.com/windows/2004/02/mit/task"}


def _after(task_name: str) -> ElementTree.Element:
    return ElementTree.parse(PACKAGE / "after" / f"{task_name}.xml").getroot()


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


def test_package_warns_that_xml_force_registration_can_reenable_tasks() -> None:
    readme = (PACKAGE / "README.md").read_text(encoding="utf-8")
    assert "default enabled state" in readme
    assert "deliberately disabled task" in readme
