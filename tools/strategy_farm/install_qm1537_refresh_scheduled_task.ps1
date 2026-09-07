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
# schtasks /SC MONTHLY accepts a single /D value only ("Invalid value for /D option"
# on 2026-09-07 for 1,2,3), so the trigger is built as a CIM monthly trigger with
# DaysOfMonth 1,2,3 via Register-ScheduledTask (CEO fix 2026-09-07, task 447f4995).
$actionArgs = '/d /c ""' + $python + '" "' + $runner + '" >> "' + $log + '" 2>&1"'
$display = "Register-ScheduledTask -TaskName $taskName -Action (cmd.exe $actionArgs) -Trigger (Monthly DaysOfMonth 1,2,3 at 05:30 local, $expectedTimeZone) -Principal ($RunAs, RunLevel Highest)"

if (-not $Apply) {
    Write-Output 'DRY_RUN: no scheduled task was registered.'
    Write-Output $display
    exit 0
}

if ($OwnerReleaseId -notmatch '^OWNER-DEC-[A-Z0-9][A-Z0-9-]+$') {
    throw 'Apply requires an explicit CEO/OWNER release id such as OWNER-DEC-...'
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $log) | Out-Null
$startBoundary = (Get-Date -Format 'yyyy-MM-dd') + 'T05:30:00'
$escapedArgs = [System.Security.SecurityElement]::Escape($actionArgs)
$escapedDescription = [System.Security.SecurityElement]::Escape("QM5_1537 monthly sleeve calendar refresh (create-only, stops in REVIEW). Release: " + $OwnerReleaseId)
if ($RunAs -eq 'SYSTEM') {
    $principalXml = '<Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal>'
} else {
    $principalXml = '<Principal id="Author"><UserId>' + $RunAs + '</UserId><LogonType>S4U</LogonType><RunLevel>HighestAvailable</RunLevel></Principal>'
}
# Task Scheduler XML: monthly calendar trigger on days 1-3 (schtasks /D accepts one day only).
$workDir = 'C:' + [char]92 + 'QM' + [char]92 + 'repo'
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>$escapedDescription</Description></RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$startBoundary</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByMonth>
        <DaysOfMonth><Day>1</Day><Day>2</Day><Day>3</Day></DaysOfMonth>
        <Months><January/><February/><March/><April/><May/><June/><July/><August/><September/><October/><November/><December/></Months>
      </ScheduleByMonth>
    </CalendarTrigger>
  </Triggers>
  <Principals>$principalXml</Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT2H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>cmd.exe</Command>
      <Arguments>$escapedArgs</Arguments>
      <WorkingDirectory>$workDir</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@
Register-ScheduledTask -TaskName $taskName -Xml $taskXml -Force | Out-Null
Write-Output "REGISTERED: $taskName under release $OwnerReleaseId"
