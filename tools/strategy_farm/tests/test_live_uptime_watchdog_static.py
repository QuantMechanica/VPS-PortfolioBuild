from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
TOOLS = ROOT / "tools" / "strategy_farm"
WATCHDOG = TOOLS / "T_Live_Watchdog.ps1"
INSTALLER = TOOLS / "install_live_uptime_tasks.ps1"
DXZ_ON = TOOLS / "T_Live_ON.ps1"
FTMO_ON = TOOLS / "FTMO_ON.ps1"
DXZ_PROFILE = TOOLS / "prepare_dxz_v2_liveops_profile.ps1"
FTMO_CONTRACT = TOOLS / "verify_ftmo_round25_live_contract.ps1"
SESSION_SUPERVISOR = TOOLS / "Live_MT5_SessionSupervisor.ps1"
SESSION_SUPERVISOR_STARTER = TOOLS / "Start_Live_SessionSupervisor.ps1"
TASK_MANIFEST = TOOLS / "qm_tasks.manifest.ps1"


def test_live_scripts_are_windows_powershell_encoding_safe() -> None:
    for path in (WATCHDOG, INSTALLER, DXZ_ON, FTMO_ON, DXZ_PROFILE, FTMO_CONTRACT, SESSION_SUPERVISOR, SESSION_SUPERVISOR_STARTER):
        assert all(byte < 128 for byte in path.read_bytes()), path


@pytest.mark.skipif(os.name != "nt", reason="Windows PowerShell 5.1 only")
def test_windows_powershell_51_parses_live_uptime_scripts() -> None:
    paths = ",".join(f"'{path}'" for path in (WATCHDOG, INSTALLER, DXZ_ON, FTMO_ON, DXZ_PROFILE, FTMO_CONTRACT, SESSION_SUPERVISOR, SESSION_SUPERVISOR_STARTER))
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
        cwd=ROOT, capture_output=True, text=True, timeout=20, check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout


def test_watchdog_destructive_path_is_fail_closed_and_cancellable() -> None:
    source = WATCHDOG.read_text(encoding="ascii")
    assert "if ($finalProc.dxz_running -or $finalProc.ftmo_running -or $independent.any_live)" in source
    assert "reboot_cancelled_process_probe_unknown" in source
    assert "reboot_countdown_aborted" in source
    assert "reboot_cancelled_maintenance_after_final_probes" in source
    assert "reboot_cancelled_maintenance_before_shutdown" in source
    assert "reboot_countdown_aborted_maintenance" in source
    assert 'shutdown.exe" /a' in source
    assert "function Test-MaintenanceRequested" in source
    assert source.count("Test-MaintenanceRequested") >= 6
    countdown = source.split("for ($i = 0; $i -lt 19; $i++)", 1)[1]
    assert "$countdownMaintenance = Test-MaintenanceRequested" in countdown
    assert "if ($countdownMaintenance -or" in countdown
    assert "consecutive_both_down = 0" in source
    assert "Stop-Process" not in source


def test_watchdog_requires_exact_recovery_and_autologon_contracts() -> None:
    source = WATCHDOG.read_text(encoding="ascii")
    assert "function Get-RecoveryTaskContractState" in source
    assert "Resolve-IdentitySid" in source
    assert "-TaskPath '\\'" in source
    assert "principal_sid" in source
    assert "action_executable" in source
    assert "action_arguments" in source
    assert "working_directory" in source
    assert "MSFT_TaskLogonTrigger" in source
    assert "trigger_user_sid" in source
    assert "allow_demand_start" in source
    assert "execution_time_limit" in source
    assert "restart_count" in source
    assert "DefaultDomainName" in source
    assert "Win32_UserAccount" in source
    assert "account_enabled" in source
    assert "OpenSubKey('CurrVal')" in source
    assert "secret_payload_nonempty" in source
    assert "reboot_blocked_recovery_task_contract" in source


def test_unguarded_hygiene_reboot_is_enforce_disabled() -> None:
    source = TASK_MANIFEST.read_text(encoding="utf-8")
    installer = INSTALLER.read_text(encoding="ascii")
    always_on = source.split("$QM_ALWAYSON_TASKS = @(", 1)[1].split("\n)", 1)[0]
    enforce_disabled = source.split("$QM_ENFORCE_DISABLED_TASKS = @(", 1)[1].split("\n)", 1)[0]
    assert "QM_StrategyFarm_HygieneReboot" not in always_on
    assert "QM_StrategyFarm_HygieneReboot" in enforce_disabled
    assert "Disable-ScheduledTask -TaskName $hygiene.TaskName" in installer
    assert "Enable-ScheduledTask -TaskName $hygiene.TaskName" not in installer


def test_installer_arms_only_interactive_live_launches_and_system_watchdog() -> None:
    source = INSTALLER.read_text(encoding="ascii")
    assert "-LogonType Interactive" in source
    assert "-LogonType ServiceAccount" in source
    assert "AutoAdminLogon is not enabled" in source
    assert "autologon_secret_probe -ne 'present'" in source
    assert "Assert-TaskContract" in source
    assert "recovery_task_contract_ready" in source
    assert "session_supervisor_scheduler_owned" in source
    assert "-ExecutionTimeLimit (New-TimeSpan -Minutes 2)" in source
    assert "-DisallowDemandStart" in source
    assert "-ExecutionTimeLimit ([TimeSpan]::Zero)" in source
    assert "-RestartCount 255" in source
    assert "PT45S" in source
    assert '-File `"$watchdogScript`" -NoReboot' in source


def test_live_launchers_reject_force_and_verify_experts_section() -> None:
    for path in (DXZ_ON, FTMO_ON):
        source = path.read_text(encoding="ascii")
        assert "-Force is intentionally unsupported" in source
        assert "post-write verification failed" in source
        assert r"^\[Experts\]" in source
        assert "process did not remain running" in source
        assert "one_or_more_terminal64_paths_unreadable" in source
        assert "WaitOne([TimeSpan]::FromSeconds(30))" in source
        assert "LIVE_UPTIME_MAINTENANCE.flag" in source


def test_dxz_recovery_uses_sealed_v2_plus_read_only_monitor_wrapper() -> None:
    launcher = DXZ_ON.read_text(encoding="ascii")
    watchdog = WATCHDOG.read_text(encoding="ascii")
    profile = DXZ_PROFILE.read_text(encoding="ascii")
    expected = "DarwinexZero_V2_LiveOps"

    assert f"$profile = '{expected}'" in launcher
    assert f"$expectedDxzProfile = '{expected}'" in watchdog
    assert "DarwinexZero_V2'" in profile
    assert "QM_AccountMonitor" in profile
    assert "chart25.chr" in profile
    assert "Assert-SealedProfile" in profile
    assert "operational contract drift" in profile


def test_ftmo_recovery_verifies_approved_profile_presets_and_binaries_before_launch() -> None:
    launcher = FTMO_ON.read_text(encoding="ascii")
    contract = FTMO_CONTRACT.read_text(encoding="ascii")

    assert "verify_ftmo_round25_live_contract.ps1" in launcher
    assert launcher.index("& powershell.exe") < launcher.index("[IO.File]::ReadAllText($common")
    assert contract.count("binary_sha=") == 12
    assert contract.count("preset_sha=") == 12
    assert "Assert-ExactProfileFiles" in contract
    assert "expected exactly one expert" in contract
    assert "Assert-PackageManifest" in contract
    assert "terminal binary hash mismatch" in contract
    assert "package binary hash mismatch" in contract
    assert "FTMO account mismatch" in contract


def test_resident_session_supervisor_is_fail_closed_and_non_destructive() -> None:
    source = SESSION_SUPERVISOR.read_text(encoding="ascii")
    assert "Global\\QM.LiveMT5.SessionSupervisor" in source
    assert "LIVE_UPTIME_MAINTENANCE.flag" in source
    assert "cim:one_or_more_terminal64_paths_unreadable" in source
    assert "cim_native_target_pid_disagreement" in source
    assert "confidently_missing" in source
    assert "MissingConfirmCycles = 2" in source
    assert "T_Live_ON.ps1" in source
    assert "FTMO_ON.ps1" in source
    assert "Start-Process" in source
    assert "WaitForExit(30000)" in source
    assert "Stop-Process" not in source
    assert "shutdown.exe" not in source
    assert "AutoTrading" not in source


def test_system_watchdog_delegates_in_session_instead_of_demand_starting_gui_tasks() -> None:
    source = WATCHDOG.read_text(encoding="ascii")
    assert "delegated_to_session_supervisor" in source
    assert "session_supervisor_heartbeat_ready" in source
    assert "session_supervisor_scheduler_owned" in source
    assert "session_supervisor_started_or_verified_via_runex" in source
    assert "Start_Live_SessionSupervisor.ps1" in source
    assert "Start-ScheduledTask -TaskName $taskName" not in source
