from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
TOOLS = ROOT / "tools" / "strategy_farm"
STARTER = TOOLS / "Start_Live_SessionSupervisor.ps1"
INSTALLER = TOOLS / "install_live_uptime_tasks.ps1"


def test_runex_starter_is_ascii_and_non_destructive() -> None:
    source = STARTER.read_text(encoding="ascii")
    assert all(byte < 128 for byte in STARTER.read_bytes())
    assert "$taskRunUseSessionId = 4" in source
    assert ".RunEx($null, $taskRunUseSessionId, [int]$targetSession.id, $null)" in source
    assert "GetInstances(0)" in source
    assert "EnginePID" in source
    assert "supervisor_pid" in source
    assert "identity_sid" in source
    assert "Start-ScheduledTask" not in source
    assert "Stop-ScheduledTask" not in source
    assert "Stop-Process" not in source
    assert "shutdown.exe" not in source
    assert "terminal64.exe" not in source


def test_runex_starter_fails_closed_on_task_or_session_drift() -> None:
    source = STARTER.read_text(encoding="ascii")
    assert "Expected exactly one existing session" in source
    assert "SessionId must identify an interactive session greater than zero" in source
    assert "principal drift" in source
    assert "LogonType drift" in source
    assert "executable drift" in source
    assert "arguments drift" in source
    assert "logon-trigger user drift" in source
    assert "AllowDemandStart -ne $true" in source
    assert "MultipleInstances -ne 'IgnoreNew'" in source
    assert "already has a running instance outside session" in source


def test_installer_separates_one_shot_and_resident_demand_start_contracts() -> None:
    source = INSTALLER.read_text(encoding="ascii")
    interactive_block = source.split("$interactiveSettings =", 1)[1].split("$watchdogSettings =", 1)[0]
    supervisor_block = source.split("$sessionSupervisorSettings =", 1)[1].split(
        "function Register-LiveLogonTask", 1
    )[0]
    assert "-DisallowDemandStart" in interactive_block
    assert "-DisallowDemandStart" not in supervisor_block
    assert "$verifiedSupervisor.Settings.AllowDemandStart -ne $true" in source
    assert "must be logon-only; demand starts queue in disconnected RDP sessions" in source
    assert "Start_Live_SessionSupervisor.ps1" in source


@pytest.mark.skipif(os.name != "nt", reason="Windows PowerShell 5.1 only")
def test_windows_powershell_51_parses_runex_starter() -> None:
    parser = (
        "$tokens=$null;$errors=$null;"
        f"[System.Management.Automation.Language.Parser]::ParseFile('{STARTER}',"
        "[ref]$tokens,[ref]$errors)|Out-Null;"
        "if($errors.Count){$errors|ForEach-Object{Write-Error $_};exit 1}"
    )
    result = subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", parser),
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout
