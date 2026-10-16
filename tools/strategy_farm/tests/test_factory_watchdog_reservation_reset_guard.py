"""A live terminal reservation must block every watchdog clean-slate reset.

Task d6d04eca (2026-10-16 rework): the ``noop_terminal_reserved`` branch only
covered a full unreserved fleet, so reservation + unreserved shortfall +
REAL-STALL fell through to ``Enter-GuardedFactoryReset`` and
``Start-ScheduledTask QM_StrategyFarm_FactoryON_AtLogon`` - a clean slate that
kills the reserved exclusive session.  These tests execute the real watchdog
decision chain (extracted from the script AST) with every side effect stubbed:
no scheduled task, file write, process query or sleep reaches the host.
"""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
WATCHDOG = REPO / "tools" / "strategy_farm" / "factory_watchdog.ps1"
LIVE_RESERVATIONS_LITERAL = r"'D:\QM\strategy_farm\state\terminal_reservations.json'"
# The scheduled task runs Windows PowerShell 5.1 (powershell.exe); prefer it.
PWSH = shutil.which("powershell") or shutil.which("pwsh")

DRIVER = r"""
param([string]$Watchdog, [string]$ScenarioPath)
$ErrorActionPreference = 'Stop'
$scenario = Get-Content -LiteralPath $ScenarioPath -Raw | ConvertFrom-Json
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Watchdog, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw "watchdog parse errors: $($errors.Count)" }

$functions = @{}
foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
    $functions[$fn.Name] = $fn.Extent.Text
}
$probeText = $functions['Get-LiveTerminalReservations']
if (-not $probeText.Contains($scenario.live_literal)) { throw 'live reservations literal not found' }
$probeText = $probeText.Replace($scenario.live_literal, "'" + $scenario.reservations_path.Replace("'", "''") + "'")
. ([scriptblock]::Create($probeText))
. ([scriptblock]::Create($functions['Enter-GuardedFactoryReset']))
. ([scriptblock]::Create($functions['ConvertFrom-UtcStamp']))

$script:calls = [System.Collections.Generic.List[string]]::new()
function Get-DirtyTreeDeferral { param([string]$PythonExe) $null }
function Set-WatchdogResetAdmissionBlock { param([string]$Reason) $script:calls.Add("admission_block:$Reason") }
function Clear-WatchdogResetAdmissionBlock { $script:calls.Add('admission_clear') }
function Get-ActiveBacktestProtection {
    param([string]$PythonExe)
    [pscustomobject]@{ probe_ok = $true; registry_ok = $true; active_multisym_count = 0; active_recent_progress_count = 0 }
}
function Invoke-InteractiveWorkerDedupe { param($PythonExe, $WorkersBefore, $ExpectedWorkers) $script:calls.Add('dedupe'); [pscustomobject]@{ session_id = 1; workers_after = $ExpectedWorkers } }
function Invoke-StallDumpCapture { param($RequestPath, $DumpDir) 'dump_stub' }
function Start-ScheduledTask { param([string]$TaskName, $ErrorAction) $script:calls.Add("start_task:$TaskName") }
function Start-Sleep { param($Seconds) }
function Set-Content { param($Path, $Value, $Encoding) $script:calls.Add("set_content:$Path") }
function Get-CimInstance { param($ClassName, $Filter, $ErrorAction) @() }
function Get-ItemProperty { param($Path, $ErrorAction) [pscustomobject]@{ DefaultUserName = 'qm-admin' } }
function qwinsta { @() }
function tscon.exe { $script:calls.Add('tscon') }
$realStallStateJson = $scenario.realstall_state_json
function Get-Content {
    param([Parameter(Position = 0)]$Path, [string]$LiteralPath, [switch]$Raw)
    $target = if ($LiteralPath) { $LiteralPath } else { [string]$Path }
    if ($target -like '*watchdog_realstall.json') { return $realStallStateJson }
    if ($LiteralPath) { return Microsoft.PowerShell.Management\Get-Content -LiteralPath $LiteralPath -Raw:$Raw -ErrorAction Stop }
    return Microsoft.PowerShell.Management\Get-Content -Path $Path -Raw:$Raw -ErrorAction Stop
}
function Test-Path { param([Parameter(Position = 0)]$Path, [string]$LiteralPath)
    $target = if ($LiteralPath) { $LiteralPath } else { [string]$Path }
    if ($target -like '*watchdog_realstall.json') { return $true }
    Microsoft.PowerShell.Management\Test-Path -LiteralPath $target
}

$decision = $ast.EndBlock.Statements | Where-Object {
    $_ -is [System.Management.Automation.Language.IfStatementAst] -and
    $_.Clauses[0].Item1.Extent.Text -eq '$factoryEnabled -and $sessionLost' -and
    $_.Extent.Text.Contains('Enter-GuardedFactoryReset')
} | Select-Object -First 1
if (-not $decision) { throw 'decision chain not found' }

$probe = Get-LiveTerminalReservations
$reservationProbeOk = [bool]$probe.ok
$liveReservedTerminals = @($probe.terminals)
$disabledTerminals = @($scenario.disabled_terminals)
$reservedTerminals = @($liveReservedTerminals | Where-Object { $_ -notin $disabledTerminals })
$reservedCount = $reservedTerminals.Count

$factoryEnabled = $true; $sessionLost = $false; $lsmDegraded = $false
$diskFreeGb = 200
$nWorkers = [int]$scenario.n_workers
$ExpectWorkers = [int]$scenario.expect_workers
$MinWorkers = [int]$scenario.expect_workers
$realStall = [bool]$scenario.real_stall
$realStallSuppressedReason = ''
$realStallInfo = 'real_verdicts_2h=0'
$dispatchStalled = [bool]$scenario.dispatch_stalled
$stallInfo = 'stub'
$activeProtectionProbeOk = $true; $multisymRegistryOk = $true; $activeMultisymCount = 0
$activeRecentProgressCount = 0; $activeProtectionDetail = 'none'
$activeProtection = [pscustomobject]@{ protected_terminals = @() }
$stallDumpRequest = 'stub'; $stallDumpDir = 'stub'
$py = 'python'
$action = ''; $detail = ''

. ([scriptblock]::Create($decision.Extent.Text))

[pscustomobject]@{
    action = $action
    detail = $detail
    calls = @($script:calls)
    reserved_count = $reservedCount
    live_reserved = @($liveReservedTerminals)
} | ConvertTo-Json -Compress -Depth 4
"""


def _run(tmp_path: Path, *, reservations: object, **scenario: object) -> dict:
    if PWSH is None:
        pytest.skip("PowerShell is not available")
    reservations_path = tmp_path / "terminal_reservations.json"
    if isinstance(reservations, str):
        reservations_path.write_text(reservations, encoding="utf-8")
    else:
        reservations_path.write_text(json.dumps(reservations), encoding="utf-8")
    payload = {
        "live_literal": LIVE_RESERVATIONS_LITERAL,
        "reservations_path": str(reservations_path),
        "realstall_state_json": json.dumps(
            {"pending_since": "2026-10-16T00:00:00Z", "last_reset": "2026-10-01T00:00:00Z"}
        ),
        "disabled_terminals": [],
        "dispatch_stalled": False,
        **scenario,
    }
    scenario_path = tmp_path / "scenario.json"
    scenario_path.write_text(json.dumps(payload), encoding="utf-8")
    driver = tmp_path / "driver.ps1"
    driver.write_text(DRIVER, encoding="utf-8")
    completed = subprocess.run(
        [PWSH, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", str(driver),
         "-Watchdog", str(WATCHDOG), "-ScenarioPath", str(scenario_path)],
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    assert completed.returncode == 0, completed.stderr or completed.stdout
    return json.loads(completed.stdout.strip().splitlines()[-1])


def _live(terminal: str) -> dict:
    return {"reservations": {terminal: {"reserved_by": "dwx2026:1:task", "until_utc": "2099-01-01T00:00:00+00:00"}}}


def test_reserved_shortfall_realstall_refuses_clean_slate_reset(tmp_path: Path) -> None:
    result = _run(
        tmp_path,
        reservations=_live("T1"),
        n_workers=8,
        expect_workers=11,
        real_stall=True,
    )
    assert result["reserved_count"] == 1
    assert result["action"] == "realstall_guarded_reserved"
    assert "T1" in result["detail"]
    assert not any(call.startswith("start_task:") for call in result["calls"])
    # Refused before the admission marker: workers keep claiming.
    assert not any(call.startswith("admission_block") for call in result["calls"])


def test_unreserved_realstall_still_resets_so_the_guard_is_not_vacuous(tmp_path: Path) -> None:
    expired = {"reservations": {"T1": {"reserved_by": "x", "until_utc": "2000-01-01T00:00:00+00:00"}}}
    result = _run(
        tmp_path,
        reservations=expired,
        n_workers=8,
        expect_workers=12,
        real_stall=True,
    )
    assert result["reserved_count"] == 0
    assert result["action"] == "healed_full_reset"
    assert "start_task:QM_StrategyFarm_FactoryON_AtLogon" in result["calls"]
    assert "admission_block:realstall" in result["calls"]


def test_reservation_on_disabled_terminal_still_blocks_dispatch_stall_reset(tmp_path: Path) -> None:
    # Disabled terminals are excluded from capacity math, so no noop branch
    # fires; Factory_ON's clean slate would still kill the reserved terminal64.
    result = _run(
        tmp_path,
        reservations=_live("T3"),
        disabled_terminals=["T3"],
        n_workers=11,
        expect_workers=11,
        real_stall=False,
        dispatch_stalled=True,
    )
    assert result["reserved_count"] == 0
    assert result["live_reserved"] == ["T3"]
    assert result["action"] == "heal_deferred_terminal_reserved"
    assert not any(call.startswith("start_task:") for call in result["calls"])
    assert not any(call.startswith("admission_block") for call in result["calls"])


def test_unreadable_reservations_fail_closed(tmp_path: Path) -> None:
    result = _run(
        tmp_path,
        reservations="{not json",
        n_workers=8,
        expect_workers=12,
        real_stall=True,
    )
    assert result["action"] == "noop_terminal_reservation_unknown"
    assert not any(call.startswith("start_task:") for call in result["calls"])


def test_every_factory_on_reset_is_behind_the_reservation_boundary() -> None:
    source = WATCHDOG.read_text(encoding="utf-8")
    guard = source[source.index("function Enter-GuardedFactoryReset"):]
    guard = guard[: guard.index("\nfunction ") if "\nfunction " in guard else len(guard)]
    assert guard.index("Get-LiveTerminalReservations") < guard.index("Set-WatchdogResetAdmissionBlock")
    assert "kind = 'terminal_reserved'" in guard
    # Every clean-slate FactoryON start sits in a branch that first consulted the guard.
    body = source[source.index("$existingResetAdmission = Get-WatchdogResetAdmissionState"):]
    starts = [i for i in range(len(body)) if body.startswith("Start-ScheduledTask -TaskName 'QM_StrategyFarm_FactoryON_AtLogon'", i)]
    assert len(starts) == 2
    for start in starts:
        preceding = body[max(0, start - 1500):start]
        assert "Enter-GuardedFactoryReset" in preceding
        assert "$resetGuard.allowed" in preceding
    # The session-lost reboot is guarded too.
    reboot = source[source.index("$rebootReservationGate = Get-LiveTerminalReservations"):source.index("shutdown.exe /r")]
    assert "session_lost_reservation_guard" in reboot
