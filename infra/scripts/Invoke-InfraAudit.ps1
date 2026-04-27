[CmdletBinding()]
param(
    [string[]]$DiskDrives = @('C','D'),
    [int]$DiskWarnGb = 60,
    [int]$DiskCriticalGb = 30,
    [string[]]$FactoryTerminalRoots = @('D:\QM\mt5\T1', 'D:\QM\mt5\T2', 'D:\QM\mt5\T3', 'D:\QM\mt5\T4', 'D:\QM\mt5\T5'),
    [string[]]$T6TerminalRoots = @('C:\QM\mt5\T6_Live', 'C:\QM\mt5\T6_Demo'),
    [string]$AggregatorStateFile = 'D:\QM\reports\state\last_check_state.json',
    [int]$AggregatorSilentMinutes = 15,
    [string]$DriveLogDir = 'C:\ProgramData\Google\DriveFS\Logs',
    [int]$DriveSilentMinutes = 60,
    [string[]]$GitRepoRoots = @('C:\QM\repo', 'C:\QM\paperclip'),
    [int]$StaleIndexLockMinutes = 10,
    [string]$PaperclipProcessPattern = 'paperclip',
    [string]$Qua95TaskName = 'QM_QUA95_BlockerRefresh',
    [int]$Qua95TaskMaxAgeMinutes = 125,
    [string]$Qua95TaskHealthScript = 'C:\QM\repo\infra\monitoring\Test-QUA95BlockerTaskHealth.ps1',
    [string]$Qua95TransitionPayloadCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95IssueTransitionPayload.ps1',
    [string]$OutJson = 'C:\QM\repo\infra\reports\infra_audit_latest.json',
    [switch]$FailOnCritical
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$issues = @()
$checks = @()

function Add-Check {
    param(
        [string]$Name,
        [string]$Status,
        $Meta
    )

    $script:checks += [pscustomobject]@{
        name = $Name
        status = $Status
        meta = $Meta
    }

    if ($Status -in @('warn','critical')) {
        $script:issues += [pscustomobject]@{ name = $Name; status = $Status; meta = $Meta }
    }
}

# Disk checks
foreach ($drive in $DiskDrives) {
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${drive}:'" -ErrorAction SilentlyContinue
    if (-not $disk) {
        Add-Check -Name "disk_${drive}" -Status 'warn' -Meta @{ reason = 'drive_not_found' }
        continue
    }

    $freeGb = [math]::Round(($disk.FreeSpace / 1GB), 2)
    $totalGb = [math]::Round(($disk.Size / 1GB), 2)
    $status = 'ok'
    if ($freeGb -lt $DiskCriticalGb) {
        $status = 'critical'
    }
    elseif ($freeGb -lt $DiskWarnGb) {
        $status = 'warn'
    }

    Add-Check -Name "disk_${drive}" -Status $status -Meta @{
        free_gb = $freeGb
        total_gb = $totalGb
        warn_below_gb = $DiskWarnGb
        critical_below_gb = $DiskCriticalGb
    }
}

# terminal64 process map
$terminalProcs = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue)

foreach ($root in $FactoryTerminalRoots) {
    $normalized = [IO.Path]::GetFullPath($root).TrimEnd('\\')
    $matches = @($terminalProcs | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($normalized, [System.StringComparison]::OrdinalIgnoreCase) })
    $status = if ($matches.Count -gt 0) { 'ok' } else { 'critical' }
    Add-Check -Name ("factory_terminal_{0}" -f (Split-Path $normalized -Leaf)) -Status $status -Meta @{
        root = $normalized
        pids = @($matches | ForEach-Object { $_.ProcessId })
    }
}

# T6 isolation/liveness
$t6Live = @()
$t6Demo = @()
if ($T6TerminalRoots.Count -ge 1) {
    $liveRoot = [IO.Path]::GetFullPath($T6TerminalRoots[0]).TrimEnd('\\')
    $t6Live = @($terminalProcs | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($liveRoot, [System.StringComparison]::OrdinalIgnoreCase) })
}
if ($T6TerminalRoots.Count -ge 2) {
    $demoRoot = [IO.Path]::GetFullPath($T6TerminalRoots[1]).TrimEnd('\\')
    $t6Demo = @($terminalProcs | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($demoRoot, [System.StringComparison]::OrdinalIgnoreCase) })
}

$t6Status = if ($t6Live.Count -gt 0) { 'ok' } else { 'critical' }
if ($T6TerminalRoots.Count -ge 2 -and (Test-Path -LiteralPath $T6TerminalRoots[1]) -and $t6Demo.Count -eq 0) {
    if ($t6Status -eq 'ok') { $t6Status = 'warn' }
}

$factoryLeaks = @()
$t6LiveRoot = ''
$t6DemoRoot = ''
if ($T6TerminalRoots.Count -ge 1) { $t6LiveRoot = $T6TerminalRoots[0] }
if ($T6TerminalRoots.Count -ge 2) { $t6DemoRoot = $T6TerminalRoots[1] }

Add-Check -Name 't6_live_demo_isolation' -Status $t6Status -Meta @{
    live_root = $t6LiveRoot
    demo_root = $t6DemoRoot
    live_pids = @($t6Live | ForEach-Object { $_.ProcessId })
    demo_pids = @($t6Demo | ForEach-Object { $_.ProcessId })
    factory_leak_pids = @($factoryLeaks | ForEach-Object { $_.ProcessId })
}

# Paperclip daemon process health
$paperclipCandidates = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -and $_.CommandLine -match [regex]::Escape($PaperclipProcessPattern)
})
$paperclipStatus = if ($paperclipCandidates.Count -gt 0) { 'ok' } else { 'critical' }
Add-Check -Name 'paperclip_daemon_health' -Status $paperclipStatus -Meta @{
    match_pattern = $PaperclipProcessPattern
    pids = @($paperclipCandidates | ForEach-Object { $_.ProcessId })
}

# Aggregator silence check
if (-not (Test-Path -LiteralPath $AggregatorStateFile)) {
    Add-Check -Name 'aggregator_loop_freshness' -Status 'critical' -Meta @{ reason = 'state_file_missing'; path = $AggregatorStateFile }
}
else {
    $ageMin = [math]::Round(((Get-Date) - (Get-Item -LiteralPath $AggregatorStateFile).LastWriteTime).TotalMinutes, 2)
    $status = if ($ageMin -gt $AggregatorSilentMinutes) { 'critical' } else { 'ok' }
    Add-Check -Name 'aggregator_loop_freshness' -Status $status -Meta @{ age_minutes = $ageMin; threshold_minutes = $AggregatorSilentMinutes; path = $AggregatorStateFile }
}

# Drive sync check
$driveProc = Get-Process -Name 'GoogleDriveFS' -ErrorAction SilentlyContinue
if (-not $driveProc) {
    Add-Check -Name 'google_drive_sync' -Status 'critical' -Meta @{ reason = 'process_missing' }
}
elseif (-not (Test-Path -LiteralPath $DriveLogDir)) {
    Add-Check -Name 'google_drive_sync' -Status 'warn' -Meta @{ reason = 'log_dir_missing'; path = $DriveLogDir }
}
else {
    $latestLog = Get-ChildItem -LiteralPath $DriveLogDir -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $latestLog) {
        Add-Check -Name 'google_drive_sync' -Status 'warn' -Meta @{ reason = 'no_log_files'; path = $DriveLogDir }
    }
    else {
        $ageMin = [math]::Round(((Get-Date) - $latestLog.LastWriteTime).TotalMinutes, 2)
        $status = if ($ageMin -gt $DriveSilentMinutes) { 'critical' } else { 'ok' }
        Add-Check -Name 'google_drive_sync' -Status $status -Meta @{ latest_log = $latestLog.FullName; age_minutes = $ageMin; threshold_minutes = $DriveSilentMinutes }
    }
}

# stale index.lock scan
$staleLocks = @()
foreach ($repoRoot in $GitRepoRoots) {
    if (-not (Test-Path -LiteralPath $repoRoot)) {
        continue
    }

    $lockPath = Join-Path $repoRoot '.git\index.lock'
    if (-not (Test-Path -LiteralPath $lockPath)) {
        continue
    }

    $ageMin = [math]::Round(((Get-Date) - (Get-Item -LiteralPath $lockPath).LastWriteTime).TotalMinutes, 2)
    if ($ageMin -ge $StaleIndexLockMinutes) {
        $staleLocks += [pscustomobject]@{ path = $lockPath; age_minutes = $ageMin }
    }
}

$staleLockStatus = if ($staleLocks.Count -gt 0) { 'critical' } else { 'ok' }
Add-Check -Name 'stale_git_index_lock' -Status $staleLockStatus -Meta @{
    threshold_minutes = $StaleIndexLockMinutes
    stale_locks = @($staleLocks)
}

# QUA-95 blocker task health
if (-not (Test-Path -LiteralPath $Qua95TaskHealthScript)) {
    Add-Check -Name 'qua95_blocker_task_health' -Status 'warn' -Meta @{
        reason = 'health_script_missing'
        path = $Qua95TaskHealthScript
    }
}
else {
    $healthOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95TaskHealthScript -TaskName $Qua95TaskName -MaxAgeMinutes $Qua95TaskMaxAgeMinutes 2>&1
    $healthCode = $LASTEXITCODE
    $healthText = ($healthOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $healthStatus = if ($healthCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_blocker_task_health' -Status $healthStatus -Meta @{
        task_name = $Qua95TaskName
        max_age_minutes = $Qua95TaskMaxAgeMinutes
        exit_code = $healthCode
        output = $healthText
    }
}

# QUA-95 transition payload consistency
if (-not (Test-Path -LiteralPath $Qua95TransitionPayloadCheckScript)) {
    Add-Check -Name 'qua95_transition_payload_consistency' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95TransitionPayloadCheckScript
    }
}
else {
    $payloadOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95TransitionPayloadCheckScript 2>&1
    $payloadCode = $LASTEXITCODE
    $payloadText = ($payloadOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $payloadStatus = if ($payloadCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_transition_payload_consistency' -Status $payloadStatus -Meta @{
        exit_code = $payloadCode
        output = $payloadText
    }
}

$overallStatus = 'ok'
if ((@($checks | Where-Object { $_.status -eq 'critical' }).Count) -gt 0) {
    $overallStatus = 'critical'
}
elseif ((@($checks | Where-Object { $_.status -eq 'warn' }).Count) -gt 0) {
    $overallStatus = 'warn'
}

$summary = [ordered]@{
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    host = $env:COMPUTERNAME
    overall_status = $overallStatus
    checks = @($checks)
    issues = @($issues)
}

$targetDir = Split-Path -Path $OutJson -Parent
if ($targetDir) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutJson -Encoding ASCII
Write-Host "Infra audit completed: status=$($summary.overall_status), checks=$($checks.Count), issues=$($issues.Count)"
Write-Host "Report: $OutJson"

if ($FailOnCritical.IsPresent -and $summary.overall_status -eq 'critical') {
    exit 2
}
