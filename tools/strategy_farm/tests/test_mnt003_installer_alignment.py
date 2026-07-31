from __future__ import annotations

import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
INSTALLERS = {
    "AgyGovernor": ROOT
    / "tools/strategy_farm/install_agy_governor_scheduled_task.ps1",
    "CodexFleetPacer": ROOT
    / "tools/strategy_farm/install_codex_fleet_pacer_scheduled_task.ps1",
    "GeminiOrchestration": ROOT
    / "tools/strategy_farm/install_agent_orchestration_scheduled_tasks.ps1",
    "MailboxSourceIntake": ROOT
    / "tools/strategy_farm/install_mailbox_source_intake_task.ps1",
    "WorkerDedupe": ROOT
    / "tools/strategy_farm/install_hygiene_and_lsm_tasks.ps1",
}


def _source(label: str) -> str:
    return INSTALLERS[label].read_text(encoding="utf-8-sig")


def test_five_installers_emit_mnt003_v2_console_bridge_templates() -> None:
    expected_wait = {
        "AgyGovernor": 240,
        "CodexFleetPacer": 300,
        "GeminiOrchestration": 14100,
        "MailboxSourceIntake": 2640,
        "WorkerDedupe": 540,
    }
    for label, wait_seconds in expected_wait.items():
        source = _source(label)
        templates = [
            line.strip()
            for line in source.splitlines()
            if "-NoLogo -NoProfile -NonInteractive" in line
        ]
        assert templates, label
        assert any(f"-WaitSeconds {wait_seconds}" in line for line in templates)
        assert any('-File "{0}"' in line for line in templates)
        assert any('-Exe "{1}"' in line for line in templates)
        assert any('-Arguments "{2}"' in line for line in templates)
        assert any('-WorkDir "{3}"' in line for line in templates)
        assert any('-TargetUser "{4}"' in line for line in templates)
        assert r"WindowsPowerShell\v1.0\powershell.exe".replace("\\\\", "\\") in source
        assert "run_in_console_session.ps1" in source
        assert ".Contains(\"'\")" in source


def test_target_task_installers_use_system_service_account_roots() -> None:
    expected_task_names = {
        "AgyGovernor": "QM_StrategyFarm_AgyGovernor",
        "CodexFleetPacer": "QM_StrategyFarm_CodexFleetPacer",
        "GeminiOrchestration": "QM_StrategyFarm_GeminiOrchestration_15min",
        "MailboxSourceIntake": "QM_StrategyFarm_MailboxSourceIntake_Daily",
        "WorkerDedupe": "QM_StrategyFarm_WorkerDedupe",
    }
    for label, task_name in expected_task_names.items():
        source = _source(label)
        assert task_name in source
        assert "ServiceAccount" in source
        assert "SYSTEM" in source


def test_task_specific_child_arguments_match_approved_v2_plan() -> None:
    assert "agy_governor.py" in _source("AgyGovernor")
    assert "codex_fleet_pacer.py" in _source("CodexFleetPacer")

    orchestration = _source("GeminiOrchestration")
    assert "if ($taskName -eq 'QM_StrategyFarm_GeminiOrchestration_15min')" in orchestration
    assert "$wrapper --agent $agent --max-sessions $maxSessions" in orchestration
    assert "outside this five-task MNT-003 change" in orchestration

    assert "mailbox_source_intake.py" in _source("MailboxSourceIntake")
    worker = _source("WorkerDedupe")
    assert (
        "$dedupeScript --repo-root $RepoRoot --farm-root "
        "D:\\QM\\strategy_farm --dedupe"
    ) in worker


def test_five_aligned_installers_parse_in_windows_powershell_51() -> None:
    probe = r"""
$failed = @()
foreach ($path in $env:QM_MNT003_INSTALLERS.Split(';')) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $path,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null
    if ($parseErrors.Count -ne 0) {
        $failed += "$path : " + (($parseErrors | ForEach-Object Message) -join '; ')
    }
}
if ($failed.Count -ne 0) { throw ($failed -join "`n") }
'PS51_PARSE_PASS'
"""
    env = os.environ.copy()
    env["QM_MNT003_INSTALLERS"] = ";".join(
        str(path) for path in INSTALLERS.values()
    )
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
    assert completed.stdout.strip() == "PS51_PARSE_PASS"
