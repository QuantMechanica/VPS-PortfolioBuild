[CmdletBinding()]
param(
    [string]$DiskPath = "C:\",
    [int]$DiskWarnGb = 60,
    [int]$DiskCriticalGb = 30,
    [string]$PaperclipHealthUrl = $(if ($env:PAPERCLIP_HEALTH_URL) { $env:PAPERCLIP_HEALTH_URL } else { "http://127.0.0.1:8501/api/health" }),
    [string]$AggregatorHeartbeatPath = "C:\QM\logs\aggregator\heartbeat.txt",
    [int]$AggregatorMaxSilentMinutes = 15,
    [string]$DriveSyncHeartbeatPath = "C:\QM\logs\drive-sync\heartbeat.txt",
    [int]$DriveSyncMaxSilentMinutes = 60,
    [string[]]$RepoRoots = @("C:\QM\repo"),
    [int]$IndexLockStaleMinutes = 20,
    [string]$OutputDirectory = "C:\QM\logs\infra\health",
    [string]$AlertWebhookUrl = $(if ($env:QM_ALERT_WEBHOOK_URL) { $env:QM_ALERT_WEBHOOK_URL } else { "" }),
    [string[]]$FactoryHeartbeats = @(
        "D:\QM\mt5\T1\MQL5\Files\factory_heartbeat.txt",
        "D:\QM\mt5\T2\MQL5\Files\factory_heartbeat.txt",
        "D:\QM\mt5\T3\MQL5\Files\factory_heartbeat.txt",
        "D:\QM\mt5\T4\MQL5\Files\factory_heartbeat.txt",
        "D:\QM\mt5\T5\MQL5\Files\factory_heartbeat.txt"
    ),
    [int]$FactoryMaxAgeMinutes = 10,
    [string]$T6LiveHeartbeat = "D:\QM\mt5\T6_Live\MQL5\Files\terminal_heartbeat.txt",
    [string]$T6DemoHeartbeat = "D:\QM\mt5\T6_Demo\MQL5\Files\terminal_heartbeat.txt",
    [int]$T6MaxAgeMinutes = 5,
    [string]$DwxHeartbeatScript = "C:\QM\repo\infra\monitoring\Test-DwxHeartbeat.ps1",
    [string]$DriveGitExclusionScript = "C:\QM\repo\infra\monitoring\Test-DriveGitExclusion.ps1",
    [string]$TaskTickScript = "C:\QM\repo\infra\tasks\Test-HourlyTaskTick.ps1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function New-Check {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Message,
        [object]$Details = $null
    )
    [ordered]@{
        check = $Name
        status = $Status
        message = $Message
        details = $Details
    }
}

function Get-FileAgeMinutes {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    return [math]::Round(([datetime]::UtcNow - $item.LastWriteTimeUtc).TotalMinutes, 2)
}

$now = [datetime]::UtcNow
$checks = New-Object System.Collections.Generic.List[object]

# Disk health
try {
    $drive = Get-PSDrive -Name ($DiskPath.Substring(0, 1))
    $freeGb = [math]::Round($drive.Free / 1GB, 2)
    if ($freeGb -lt $DiskCriticalGb) {
        $checks.Add((New-Check -Name "disk_free_gb" -Status "critical" -Message "Disk free below critical threshold." -Details @{ free_gb = $freeGb; threshold_gb = $DiskCriticalGb }))
    } elseif ($freeGb -lt $DiskWarnGb) {
        $checks.Add((New-Check -Name "disk_free_gb" -Status "warn" -Message "Disk free below warning threshold." -Details @{ free_gb = $freeGb; threshold_gb = $DiskWarnGb }))
    } else {
        $checks.Add((New-Check -Name "disk_free_gb" -Status "ok" -Message "Disk free within normal range." -Details @{ free_gb = $freeGb }))
    }
}
catch {
    $checks.Add((New-Check -Name "disk_free_gb" -Status "critical" -Message "Disk check failed." -Details $_.Exception.Message))
}

# T1-T5 factory heartbeats
for ($i = 0; $i -lt $FactoryHeartbeats.Count; $i++) {
    $path = $FactoryHeartbeats[$i]
    $terminal = "T$($i + 1)"
    $age = Get-FileAgeMinutes -Path $path
    if ($null -eq $age) {
        $checks.Add((New-Check -Name "factory_$terminal" -Status "critical" -Message "Factory heartbeat missing." -Details @{ path = $path }))
        continue
    }
    if ($age -gt $FactoryMaxAgeMinutes) {
        $checks.Add((New-Check -Name "factory_$terminal" -Status "critical" -Message "Factory terminal heartbeat stale." -Details @{ path = $path; age_minutes = $age; max_age_minutes = $FactoryMaxAgeMinutes }))
    } else {
        $checks.Add((New-Check -Name "factory_$terminal" -Status "ok" -Message "Factory terminal heartbeat fresh." -Details @{ age_minutes = $age }))
    }
}

# T6 isolation + health
$t6LiveAge = Get-FileAgeMinutes -Path $T6LiveHeartbeat
$t6DemoAge = Get-FileAgeMinutes -Path $T6DemoHeartbeat
$liveRoot = Split-Path -Path (Split-Path -Path $T6LiveHeartbeat -Parent) -Parent
$demoRoot = Split-Path -Path (Split-Path -Path $T6DemoHeartbeat -Parent) -Parent
if ($liveRoot -eq $demoRoot) {
    $checks.Add((New-Check -Name "t6_isolation" -Status "critical" -Message "T6 Live/Demo path collision." -Details @{ live_root = $liveRoot; demo_root = $demoRoot }))
} else {
    $checks.Add((New-Check -Name "t6_isolation" -Status "ok" -Message "T6 Live and Demo roots are distinct." -Details @{ live_root = $liveRoot; demo_root = $demoRoot }))
}

if ($null -eq $t6LiveAge -or $t6LiveAge -gt $T6MaxAgeMinutes) {
    $checks.Add((New-Check -Name "t6_live_terminal" -Status "critical" -Message "T6 Live terminal heartbeat stale/missing." -Details @{ age_minutes = $t6LiveAge; max_age_minutes = $T6MaxAgeMinutes }))
} else {
    $checks.Add((New-Check -Name "t6_live_terminal" -Status "ok" -Message "T6 Live terminal heartbeat fresh." -Details @{ age_minutes = $t6LiveAge }))
}
if ($null -eq $t6DemoAge -or $t6DemoAge -gt $T6MaxAgeMinutes) {
    $checks.Add((New-Check -Name "t6_demo_terminal" -Status "critical" -Message "T6 Demo terminal heartbeat stale/missing." -Details @{ age_minutes = $t6DemoAge; max_age_minutes = $T6MaxAgeMinutes }))
} else {
    $checks.Add((New-Check -Name "t6_demo_terminal" -Status "ok" -Message "T6 Demo terminal heartbeat fresh." -Details @{ age_minutes = $t6DemoAge }))
}

# DarwinexZero DWX import service heartbeat
if (Test-Path -LiteralPath $DwxHeartbeatScript) {
    try {
        $dwx = & powershell -NoProfile -ExecutionPolicy Bypass -File $DwxHeartbeatScript 2>$null | Out-String
        $dwxObj = $dwx | ConvertFrom-Json -ErrorAction Stop
        $checks.Add((New-Check -Name "dwx_service_heartbeat" -Status $dwxObj.status -Message $dwxObj.message -Details $dwxObj))
    }
    catch {
        $checks.Add((New-Check -Name "dwx_service_heartbeat" -Status "critical" -Message "DWX heartbeat check execution failed." -Details $_.Exception.Message))
    }
}

# Drive/git exclusion check (PC1-00 hard rule)
if (Test-Path -LiteralPath $DriveGitExclusionScript) {
    try {
        $driveCheckRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File $DriveGitExclusionScript 2>$null | Out-String
        $driveCheck = $driveCheckRaw | ConvertFrom-Json -ErrorAction Stop
        $checks.Add((New-Check -Name "drive_git_exclusion" -Status $driveCheck.status -Message $driveCheck.message -Details $driveCheck))
    }
    catch {
        $checks.Add((New-Check -Name "drive_git_exclusion" -Status "critical" -Message "Drive/git exclusion check execution failed." -Details $_.Exception.Message))
    }
}

# Verify hourly cadence + observed tick for DWX heartbeat task
if (Test-Path -LiteralPath $TaskTickScript) {
    try {
        $tickRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File $TaskTickScript -TaskName "QM_DWX_HourlyCheck" 2>$null | Out-String
        $tickObj = $tickRaw | ConvertFrom-Json -ErrorAction Stop
        $checks.Add((New-Check -Name "dwx_hourly_task_tick" -Status $tickObj.status -Message $tickObj.message -Details $tickObj))
    }
    catch {
        $checks.Add((New-Check -Name "dwx_hourly_task_tick" -Status "critical" -Message "DWX hourly task tick check execution failed." -Details $_.Exception.Message))
    }
}

# Paperclip daemon health
try {
    $response = Invoke-WebRequest -Uri $PaperclipHealthUrl -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
        $checks.Add((New-Check -Name "paperclip_daemon" -Status "ok" -Message "Paperclip daemon healthy." -Details @{ url = $PaperclipHealthUrl; status = $response.StatusCode }))
    } else {
        $checks.Add((New-Check -Name "paperclip_daemon" -Status "critical" -Message "Paperclip daemon health endpoint returned non-2xx." -Details @{ url = $PaperclipHealthUrl; status = $response.StatusCode }))
    }
}
catch {
    $checks.Add((New-Check -Name "paperclip_daemon" -Status "critical" -Message "Paperclip daemon unresponsive." -Details @{ url = $PaperclipHealthUrl; error = $_.Exception.Message }))
}

# Aggregator loop silence
$aggAge = Get-FileAgeMinutes -Path $AggregatorHeartbeatPath
if ($null -eq $aggAge -or $aggAge -gt $AggregatorMaxSilentMinutes) {
    $checks.Add((New-Check -Name "aggregator_silence" -Status "critical" -Message "Aggregator loop silent." -Details @{ path = $AggregatorHeartbeatPath; age_minutes = $aggAge; max_age_minutes = $AggregatorMaxSilentMinutes }))
} else {
    $checks.Add((New-Check -Name "aggregator_silence" -Status "ok" -Message "Aggregator heartbeat fresh." -Details @{ age_minutes = $aggAge }))
}

# Google Drive sync silence
$driveAge = Get-FileAgeMinutes -Path $DriveSyncHeartbeatPath
if ($null -eq $driveAge -or $driveAge -gt $DriveSyncMaxSilentMinutes) {
    $checks.Add((New-Check -Name "drive_sync" -Status "critical" -Message "Drive sync heartbeat stale/missing." -Details @{ path = $DriveSyncHeartbeatPath; age_minutes = $driveAge; max_age_minutes = $DriveSyncMaxSilentMinutes }))
} else {
    $checks.Add((New-Check -Name "drive_sync" -Status "ok" -Message "Drive sync heartbeat fresh." -Details @{ age_minutes = $driveAge }))
}

# Stale .git/index.lock files
$staleLocks = New-Object System.Collections.Generic.List[object]
foreach ($repo in $RepoRoots) {
    $lockPath = Join-Path $repo ".git\index.lock"
    if (-not (Test-Path -LiteralPath $lockPath)) { continue }
    $age = Get-FileAgeMinutes -Path $lockPath
    if ($null -ne $age -and $age -gt $IndexLockStaleMinutes) {
        $staleLocks.Add(@{ path = $lockPath; age_minutes = $age })
    }
}
if ($staleLocks.Count -gt 0) {
    $checks.Add((New-Check -Name "git_index_lock" -Status "critical" -Message "Stale .git/index.lock detected." -Details $staleLocks))
} else {
    $checks.Add((New-Check -Name "git_index_lock" -Status "ok" -Message "No stale .git/index.lock files detected." -Details @{ max_age_minutes = $IndexLockStaleMinutes }))
}

$criticalCount = @($checks | Where-Object { $_.status -eq "critical" }).Count
$warnCount = @($checks | Where-Object { $_.status -eq "warn" }).Count
$overall = if ($criticalCount -gt 0) { "critical" } elseif ($warnCount -gt 0) { "warn" } else { "ok" }

$result = [ordered]@{
    generated_at_utc = $now.ToString("o")
    overall_status = $overall
    counts = @{
        critical = $criticalCount
        warn = $warnCount
        ok = @($checks | Where-Object { $_.status -eq "ok" }).Count
    }
    checks = $checks
}

Ensure-Directory -Path $OutputDirectory
$outputPath = Join-Path $OutputDirectory "infra_health_latest.json"
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $outputPath -Encoding UTF8
Write-Host "Wrote health report: $outputPath"

if ($overall -ne "ok" -and $AlertWebhookUrl) {
    try {
        Invoke-RestMethod -Method Post -Uri $AlertWebhookUrl -ContentType "application/json" -Body ($result | ConvertTo-Json -Depth 10) | Out-Null
    }
    catch {
        Write-Warning "Alert webhook post failed: $($_.Exception.Message)"
    }
}

if ($criticalCount -gt 0) { exit 2 }
if ($warnCount -gt 0) { exit 1 }
exit 0
