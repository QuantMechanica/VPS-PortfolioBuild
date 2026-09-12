[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$OwnerReleaseId = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskName = 'QM_Dukascopy_MonthlyCustomHistoryRefresh'
$python = 'C:\Python311\python.exe'
$runner = 'C:\QM\repo\tools\dukascopy\monthly_refresh.py'
$workDir = 'C:\QM\repo'
$expectedTimeZone = 'W. Europe Standard Time'

if ((Get-TimeZone).Id -ne $expectedTimeZone) {
    throw "Expected Europe/Berlin ($expectedTimeZone)"
}
foreach ($required in @($python, $runner)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file missing: $required"
    }
}

$display = "${taskName}: monthly day 3 at 03:10 local; registered Disabled; runner Default-OFF"
if (-not $Apply) {
    Write-Output 'DRY_RUN: no scheduled-task state changed.'
    Write-Output $display
    exit 0
}
if ($OwnerReleaseId -notmatch '^OWNER-DEC-[A-Z0-9][A-Z0-9-]+$') {
    throw 'Apply requires an explicit OWNER-DEC-* task-registration release.'
}

$startBoundary = (Get-Date -Format 'yyyy-MM') + '-03T03:10:00'
$escapedDescription = [Security.SecurityElement]::Escape(
    "Disabled monthly Dukascopy admission probe. No terminal/history mutation. Release: $OwnerReleaseId"
)
$escapedPython = [Security.SecurityElement]::Escape($python)
$escapedRunner = [Security.SecurityElement]::Escape('"' + $runner + '"')
$escapedWorkDir = [Security.SecurityElement]::Escape($workDir)
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>$escapedDescription</Description></RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$startBoundary</StartBoundary><Enabled>true</Enabled>
      <ScheduleByMonth>
        <DaysOfMonth><Day>3</Day></DaysOfMonth>
        <Months><January/><February/><March/><April/><May/><June/><July/><August/><September/><October/><November/><December/></Months>
      </ScheduleByMonth>
    </CalendarTrigger>
  </Triggers>
  <Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <AllowStartOnDemand>false</AllowStartOnDemand>
    <Enabled>false</Enabled>
    <Hidden>false</Hidden>
    <ExecutionTimeLimit>PT5M</ExecutionTimeLimit>
  </Settings>
  <Actions Context="Author">
    <Exec><Command>$escapedPython</Command><Arguments>$escapedRunner</Arguments><WorkingDirectory>$escapedWorkDir</WorkingDirectory></Exec>
  </Actions>
</Task>
"@

Register-ScheduledTask -TaskName $taskName -Xml $taskXml -Force | Out-Null
Disable-ScheduledTask -TaskName $taskName | Out-Null
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
if ([string]$task.State -ne 'Disabled') {
    throw "$taskName did not remain Disabled"
}
Write-Output "REGISTERED_DISABLED: $taskName under $OwnerReleaseId"
