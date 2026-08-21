"""QM-TODO-20260821-202: guard the pipeline_state.json rebuild task installer.

pipeline_state.json is actively consumed (public-snapshot export -> quantmechanica.com,
internal daily summary). Its dedicated hourly rebuild task must stay a READ-ONLY,
SYSTEM, no-window pythonw build decoupled from public publication. These tests pin
the installer invariants so a future edit cannot silently degrade the task shape.
"""
from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
INSTALLER = ROOT / "scripts/install_pipeline_state_scheduled_task.ps1"
BUILDER = ROOT / "scripts/build_pipeline_state.py"


def _source() -> str:
    return INSTALLER.read_text(encoding="utf-8-sig")


def test_installer_and_builder_exist() -> None:
    assert INSTALLER.is_file(), INSTALLER
    assert BUILDER.is_file(), BUILDER


def test_task_name_and_system_service_account() -> None:
    source = _source()
    assert "QM_StrategyFarm_PipelineState" in source
    # SYSTEM service account, HighestAvailable — matches sibling QM_StrategyFarm_* tasks.
    assert '-UserId "SYSTEM"' in source
    assert "-LogonType ServiceAccount" in source
    assert "-RunLevel Highest" in source


def test_action_builds_pipeline_state_via_no_window_pythonw() -> None:
    source = _source()
    assert "build_pipeline_state.py" in source
    # pythonw.exe = GUI-subsystem interpreter => no console window (CREATE_NO_WINDOW-equivalent).
    assert "pythonw.exe" in source
    assert "-WorkingDirectory $RepoRoot" in source


def test_hourly_cadence_and_documented_rollback() -> None:
    source = _source()
    assert "-RepetitionInterval (New-TimeSpan -Hours $IntervalHours)" in source
    assert "$IntervalHours = 1" in source
    # Rollback must be documented in-file (deprecation/backout path).
    assert 'schtasks /delete /tn' in source


def test_installer_parses_in_windows_powershell_51() -> None:
    probe = r"""
$path = $env:QM_PIPELINE_STATE_INSTALLER
$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    $path, [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count -ne 0) {
    throw (($parseErrors | ForEach-Object Message) -join '; ')
}
'PS51_PARSE_PASS'
"""
    env = os.environ.copy()
    env["QM_PIPELINE_STATE_INSTALLER"] = str(INSTALLER)
    completed = subprocess.run(
        ["powershell.exe", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", probe],
        text=True,
        capture_output=True,
        check=True,
        env=env,
    )
    assert completed.stdout.strip() == "PS51_PARSE_PASS"
