from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
FARM_TOOLS = REPO / "tools" / "strategy_farm"
HYGIENE = FARM_TOOLS / "weekly_hygiene_reboot.ps1"
INSTALLER = FARM_TOOLS / "install_hygiene_and_lsm_tasks.ps1"
LSM_PROBE = FARM_TOOLS / "lsm_health_probe.ps1"


def test_windows_powershell_task_scripts_are_encoding_safe() -> None:
    for path in (HYGIENE, INSTALLER, LSM_PROBE):
        data = path.read_bytes()
        assert all(byte < 128 for byte in data), path


@pytest.mark.skipif(os.name != "nt", reason="Windows PowerShell 5.1 only")
def test_windows_powershell_51_parses_task_scripts() -> None:
    paths = ",".join(f"'{path}'" for path in (HYGIENE, INSTALLER, LSM_PROBE))
    parser = (
        "$failed=$false;"
        f"foreach($path in @({paths})){{"
        "$tokens=$null;$errors=$null;"
        "[System.Management.Automation.Language.Parser]::ParseFile($path,"
        "[ref]$tokens,[ref]$errors)|Out-Null;"
        "if($errors.Count){$failed=$true;$errors|ForEach-Object{Write-Error $_}}};"
        "if($failed){exit 1}"
    )
    result = subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", parser),
        cwd=REPO,
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout


def test_installer_preflights_before_replacing_task_and_sets_retries() -> None:
    source = INSTALLER.read_text(encoding="ascii")

    preflight = source.index(
        "Assert-WindowsPowerShellScriptSafe -Path $hygieneScript"
    )
    unregister = source.index("Unregister-ScheduledTask -TaskName $hygieneTask")
    assert preflight < unregister
    assert "-RestartCount 3" in source
    assert "-RestartInterval (New-TimeSpan -Minutes 2)" in source
    assert "-Settings $hygieneSettings" in source
    assert "Microsoft-Windows-TaskScheduler/Operational" in source
    assert "Disable-ScheduledTask -TaskName $hygieneTask" in source
    assert "Enable-ScheduledTask -TaskName $hygieneTask" not in source


def test_lsm_probe_does_not_flag_intentionally_disabled_task_cadence() -> None:
    source = LSM_PROBE.read_text(encoding="ascii")
    task_lookup = source.index("Get-ScheduledTask -TaskName $t.Name")
    disabled_guard = source.index("$task.State -eq 'Disabled'", task_lookup)
    info_lookup = source.index("Get-ScheduledTaskInfo -TaskName $t.Name", task_lookup)
    assert task_lookup < disabled_guard < info_lookup
    assert "continue" in source[disabled_guard:info_lookup]
