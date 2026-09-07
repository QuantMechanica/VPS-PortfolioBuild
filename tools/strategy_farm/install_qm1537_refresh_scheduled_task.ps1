[CmdletBinding()]
param(
    [switch]$Apply,
    [ValidateSet('SYSTEM', 'qm-admin')]
    [string]$RunAs = 'SYSTEM',
    [string]$OwnerReleaseId = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskName = 'QM_MonthlySleeveCalendar_Refresh'
$python = 'C:\Python311\python.exe'
$runner = 'C:\QM\repo\tools\strategy_farm\qm1537_monthly_sleeve_refresh.py'
$log = 'D:\QM\reports\state\qm1537_refresh.log'
$expectedTimeZone = 'W. Europe Standard Time'
$actualTimeZone = (Get-TimeZone).Id

if ($actualTimeZone -ne $expectedTimeZone) {
    throw "Refusing scheduler definition outside Europe/Berlin ($expectedTimeZone); found $actualTimeZone"
}
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    throw "Python executable is missing: $python"
}
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
    throw "QM5_1537 refresh runner is missing: $runner"
}

# The Windows trigger supplies cadence only. The runner verifies days 1-3,
# weekend eligibility, and the authoritative first native XAG D1 bar itself.
$taskCommand = 'cmd.exe /d /c ""C:\Python311\python.exe" "C:\QM\repo\tools\strategy_farm\qm1537_monthly_sleeve_refresh.py" >> "D:\QM\reports\state\qm1537_refresh.log" 2>&1"'
$taskArguments = @(
    '/Create',
    '/TN', $taskName,
    '/TR', $taskCommand,
    '/SC', 'MONTHLY',
    '/D', '1,2,3',
    '/ST', '05:30',
    '/RU', $RunAs,
    '/RL', 'HIGHEST'
)

function Format-CommandArgument {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value -match '[\s"]') {
        return '"' + ($Value -replace '"', '\"') + '"'
    }
    return $Value
}

$display = 'schtasks.exe ' + (($taskArguments | ForEach-Object { Format-CommandArgument ([string]$_) }) -join ' ')

if (-not $Apply) {
    Write-Output 'DRY_RUN: no scheduled task was registered.'
    Write-Output $display
    exit 0
}

if ($OwnerReleaseId -notmatch '^OWNER-DEC-[A-Z0-9][A-Z0-9-]+$') {
    throw 'Apply requires an explicit CEO/OWNER release id such as OWNER-DEC-...'
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $log) | Out-Null
& "$env:SystemRoot\System32\schtasks.exe" @taskArguments
if ($LASTEXITCODE -ne 0) {
    throw "schtasks registration failed with exit code $LASTEXITCODE"
}
Write-Output "REGISTERED: $taskName under release $OwnerReleaseId"
