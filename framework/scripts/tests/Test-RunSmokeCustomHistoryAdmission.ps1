[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$scriptPath = Join-Path $repoRoot 'framework\scripts\run_smoke.ps1'
$helperPath = Join-Path $repoRoot 'tools\strategy_farm\custom_history_smoke_admission.py'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath, [ref]$tokens, [ref]$errors
)
if (@($errors).Count -gt 0) {
    throw "run_smoke.ps1 parse errors: $($errors | Out-String)"
}

$text = [System.IO.File]::ReadAllText($scriptPath)
$admission = $text.IndexOf('$smokeReservation = Invoke-CustomHistorySmokeAdmission')
$spawn = $text.IndexOf('$runExec = Start-TesterRun')
$release = $text.LastIndexOf('Exit-CustomHistorySmokeAdmission -Admission $smokeReservation')
if ($admission -lt 0 -or $spawn -lt 0 -or $release -lt 0) {
    throw 'Custom-history admission/reservation boundaries are missing.'
}
if (-not ($admission -lt $spawn -and $spawn -lt $release)) {
    throw 'Custom-history gate/reservation must precede terminal launch and release afterwards.'
}
foreach ($required in @(
    '--expected-work-item-id',
    'PASS_RESERVED',
    'custom_history_reservation_release_failed'
)) {
    if (-not $text.Contains($required)) {
        throw "run_smoke Custom-history admission marker missing: $required"
    }
}

$helper = [System.IO.File]::ReadAllText($helperPath)
foreach ($required in @(
    'custom_history_gate.run_worker_gate',
    'farmctl.terminal_reservation',
    'farmctl.set_terminal_reservation',
    'farmctl.release_terminal_reservation',
    'admission_allowed'
)) {
    if (-not $helper.Contains($required)) {
        throw "smoke admission helper contract missing: $required"
    }
}

Write-Host 'PASS Test-RunSmokeCustomHistoryAdmission'

