[CmdletBinding()]
param(
    [string]$TaskName = "QM_TokenBurnWatch_60min",
    [int]$EveryMinutes = 60,
    [string]$RepoRoot = "C:\QM\repo",
    [string]$ApiUrl = "http://127.0.0.1:3100",
    [string]$CompanyId = "",
    [string]$StatePath = "C:\QM\logs\infra\health\qm_token_monitor_state.json",
    [string]$OutputJsonPath = "C:\QM\logs\infra\health\qm_token_monitor_latest.json",
    [string]$OutputMarkdownPath = "C:\QM\logs\infra\health\qm_token_monitor_latest.md",
    [string]$TokenBudgetPath = "C:\QM\repo\framework\registry\token_budget.json",
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($EveryMinutes -lt 5) {
    throw "EveryMinutes must be >= 5."
}

$scriptPath = Join-Path $RepoRoot "infra\monitoring\Invoke-QmTokenMonitor.ps1"
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Monitor script not found: $scriptPath"
}

$resolvedCompanyId = $CompanyId
if ([string]::IsNullOrWhiteSpace($resolvedCompanyId)) {
    $resolvedCompanyId = [Environment]::GetEnvironmentVariable("PAPERCLIP_COMPANY_ID", "Machine")
    if ([string]::IsNullOrWhiteSpace($resolvedCompanyId)) {
        $resolvedCompanyId = [Environment]::GetEnvironmentVariable("PAPERCLIP_COMPANY_ID", "Process")
    }
}

$taskArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", ('"{0}"' -f $scriptPath),
    "-ApiUrl", ('"{0}"' -f $ApiUrl),
    "-StatePath", ('"{0}"' -f $StatePath),
    "-OutputJsonPath", ('"{0}"' -f $OutputJsonPath),
    "-OutputMarkdownPath", ('"{0}"' -f $OutputMarkdownPath),
    "-TokenBudgetPath", ('"{0}"' -f $TokenBudgetPath)
)
if (-not [string]::IsNullOrWhiteSpace($resolvedCompanyId)) {
    $taskArgs += @("-CompanyId", ('"{0}"' -f $resolvedCompanyId))
}

$actionExe = "powershell.exe"
$actionArgString = $taskArgs -join " "

$startBoundary = (Get-Date).ToUniversalTime().AddMinutes(2)
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) -RepetitionDuration ([TimeSpan]::MaxValue)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
$action = New-ScheduledTaskAction -Execute $actionExe -Argument $actionArgString

$plan = [ordered]@{
    task_name = $TaskName
    every_minutes = $EveryMinutes
    action = [ordered]@{
        execute = $actionExe
        argument = $actionArgString
    }
    company_id_resolved = $resolvedCompanyId
    preview_only = [bool]$PreviewOnly
    start_boundary_utc = $startBoundary.ToString("o")
}

if ($PreviewOnly.IsPresent) {
    $plan | ConvertTo-Json -Depth 8
    exit 0
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
$plan["status"] = "registered"
$plan | ConvertTo-Json -Depth 8
exit 0

