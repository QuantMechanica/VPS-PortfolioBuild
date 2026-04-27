[CmdletBinding()]
param(
    [string[]]$DiskDrives = @('C','D'),
    [int]$DiskWarnGb = 60,
    [int]$DiskCriticalGb = 30,
    [string[]]$FactoryTerminalRoots = @('D:\QM\mt5\T1', 'D:\QM\mt5\T2', 'D:\QM\mt5\T3', 'D:\QM\mt5\T4', 'D:\QM\mt5\T5'),
    [string]$FactoryPortableMarkerName = 'portable.txt',
    [string[]]$T6TerminalRoots = @('C:\QM\mt5\T6_Live', 'C:\QM\mt5\T6_Demo'),
    [string]$AggregatorStateFile = 'D:\QM\reports\state\last_check_state.json',
    [int]$AggregatorSilentMinutes = 15,
    [string]$DriveLogDir = 'C:\ProgramData\Google\DriveFS\Logs',
    [int]$DriveSilentMinutes = 60,
    [string[]]$GitRepoRoots = @('C:\QM\repo', 'C:\QM\paperclip'),
    [int]$StaleIndexLockMinutes = 10,
    [string]$PaperclipProcessPattern = 'paperclip',
    [string]$Qua95TaskName = 'QM_QUA95_BlockerRefresh',
    [string]$Qua95TaskHealthTaskName = 'QM_QUA95_TaskHealth_15min',
    [int]$Qua95TaskMaxAgeMinutes = 125,
    [string]$Qua95TaskHealthScript = 'C:\QM\repo\infra\monitoring\Test-QUA95BlockerTaskHealth.ps1',
    [string]$Qua95TaskHealthActionWiringScript = 'C:\QM\repo\infra\scripts\Test-QUA95TaskHealthActionWiring.ps1',
    [string]$Qua95BlockerRefreshActionWiringScript = 'C:\QM\repo\infra\scripts\Test-QUA95BlockerRefreshActionWiring.ps1',
    [string]$Qua95AutomationHealthScript = 'C:\QM\repo\infra\monitoring\Test-QUA95AutomationHealth.ps1',
    [string]$Qua95TransitionPayloadCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95IssueTransitionPayload.ps1',
    [string]$Qua95BlockedInvariantScript = 'C:\QM\repo\infra\scripts\Test-QUA95BlockedInvariant.ps1',
    [string]$Qua95HandoffIntegrityScript = 'C:\QM\repo\infra\scripts\Test-QUA95HandoffIntegrity.ps1',
    [string]$Qua95BlockerStatusJson = 'C:\QM\repo\docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
    [string]$Qua95BlockedAssertionMd = 'C:\QM\repo\docs\ops\QUA-95_BLOCKED_STATE_ASSERTION_2026-04-27.md',
    [int]$Qua95BlockedAssertionMaxLagMinutes = 30,
    [string]$Qua95UnblockReadinessCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95UnblockReadiness.ps1',
    [string]$Qua95UnblockOwnerConsistencyCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95UnblockOwnerConsistency.ps1',
    [string]$Qua95AuditSignalCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95AuditSignal.ps1',
    [string]$Qua95DirectVerifierProofCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95DirectVerifierProof.ps1',
    [string]$Qua95CustomVisibilityProofCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95CustomVisibilityProof.ps1',
    [string]$Qua95EvidenceCohesionCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95EvidenceCohesion.ps1',
    [string]$Qua95FailureSignatureCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95FailureSignature.ps1',
    [string]$Qua95HeartbeatCustomVisibilityCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95HeartbeatCustomVisibility.ps1',
    [string]$Qua95CanonicalSnapshotCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95CanonicalSnapshot.ps1',
    [string]$Qua95CanonicalSnapshotFreshnessCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95CanonicalSnapshotFreshness.ps1',
    [string]$Qua95OpsBundleManifestScript = 'C:\QM\repo\infra\scripts\Test-QUA95OpsBundleManifest.ps1',
    [string]$Qua95BlockedHeartbeatWrapperTestScript = 'C:\QM\repo\infra\monitoring\Test-QUA95BlockedHeartbeatWrapper.ps1',
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

# Factory portable marker convergence signal
foreach ($root in $FactoryTerminalRoots) {
    $normalized = [IO.Path]::GetFullPath($root).TrimEnd('\\')
    $leaf = Split-Path -Path $normalized -Leaf
    $markerPath = Join-Path $normalized $FactoryPortableMarkerName

    if (-not (Test-Path -LiteralPath $normalized -PathType Container)) {
        Add-Check -Name ("factory_portable_marker_{0}" -f $leaf) -Status 'critical' -Meta @{
            reason = 'terminal_root_missing'
            root = $normalized
            marker_path = $markerPath
        }
        continue
    }

    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        Add-Check -Name ("factory_portable_marker_{0}" -f $leaf) -Status 'critical' -Meta @{
            reason = 'marker_missing'
            root = $normalized
            marker_path = $markerPath
        }
        continue
    }

    $sizeBytes = (Get-Item -LiteralPath $markerPath).Length
    $markerStatus = if ($sizeBytes -eq 0) { 'ok' } else { 'warn' }
    Add-Check -Name ("factory_portable_marker_{0}" -f $leaf) -Status $markerStatus -Meta @{
        root = $normalized
        marker_path = $markerPath
        size_bytes = $sizeBytes
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

# QUA-95 task-health action wiring
if (-not (Test-Path -LiteralPath $Qua95TaskHealthActionWiringScript)) {
    Add-Check -Name 'qua95_task_health_action_wiring' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95TaskHealthActionWiringScript
    }
}
else {
    $wiringOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95TaskHealthActionWiringScript -TaskName $Qua95TaskHealthTaskName 2>&1
    $wiringCode = $LASTEXITCODE
    $wiringText = ($wiringOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $wiringStatus = if ($wiringCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_task_health_action_wiring' -Status $wiringStatus -Meta @{
        task_name = $Qua95TaskHealthTaskName
        exit_code = $wiringCode
        output = $wiringText
    }
}

# QUA-95 blocker-refresh action wiring
if (-not (Test-Path -LiteralPath $Qua95BlockerRefreshActionWiringScript)) {
    Add-Check -Name 'qua95_blocker_refresh_action_wiring' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95BlockerRefreshActionWiringScript
    }
}
else {
    $refreshWiringOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95BlockerRefreshActionWiringScript -TaskName $Qua95TaskName 2>&1
    $refreshWiringCode = $LASTEXITCODE
    $refreshWiringText = ($refreshWiringOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $refreshWiringStatus = if ($refreshWiringCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_blocker_refresh_action_wiring' -Status $refreshWiringStatus -Meta @{
        task_name = $Qua95TaskName
        exit_code = $refreshWiringCode
        output = $refreshWiringText
    }
}

# QUA-95 combined automation health
if (-not (Test-Path -LiteralPath $Qua95AutomationHealthScript)) {
    Add-Check -Name 'qua95_automation_health' -Status 'warn' -Meta @{
        reason = 'health_script_missing'
        path = $Qua95AutomationHealthScript
    }
}
else {
    $automationOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95AutomationHealthScript -NoWriteSnapshot 2>&1
    $automationCode = $LASTEXITCODE
    $automationText = ($automationOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $automationStatus = if ($automationCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_automation_health' -Status $automationStatus -Meta @{
        exit_code = $automationCode
        output = $automationText
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

# QUA-95 blocked invariant enforcement
if (-not (Test-Path -LiteralPath $Qua95BlockedInvariantScript)) {
    Add-Check -Name 'qua95_blocked_invariant' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95BlockedInvariantScript
    }
}
else {
    $invariantOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95BlockedInvariantScript 2>&1
    $invariantCode = $LASTEXITCODE
    $invariantText = ($invariantOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $invariantStatus = if ($invariantCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_blocked_invariant' -Status $invariantStatus -Meta @{
        exit_code = $invariantCode
        output = $invariantText
    }
}

# QUA-95 handoff integrity
if (-not (Test-Path -LiteralPath $Qua95HandoffIntegrityScript)) {
    Add-Check -Name 'qua95_handoff_integrity' -Status 'warn' -Meta @{
        reason = 'integrity_script_missing'
        path = $Qua95HandoffIntegrityScript
    }
}
else {
    $integrityOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95HandoffIntegrityScript 2>&1
    $integrityCode = $LASTEXITCODE
    $integrityText = ($integrityOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $integrityStatus = if ($integrityCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_handoff_integrity' -Status $integrityStatus -Meta @{
        exit_code = $integrityCode
        output = $integrityText
    }
}

# QUA-95 blocked assertion freshness
if (-not (Test-Path -LiteralPath $Qua95BlockerStatusJson)) {
    Add-Check -Name 'qua95_blocked_assertion_freshness' -Status 'warn' -Meta @{
        reason = 'blocker_status_missing'
        blocker_status_json = $Qua95BlockerStatusJson
    }
}
elseif (-not (Test-Path -LiteralPath $Qua95BlockedAssertionMd)) {
    Add-Check -Name 'qua95_blocked_assertion_freshness' -Status 'critical' -Meta @{
        reason = 'blocked_assertion_missing'
        blocked_assertion_md = $Qua95BlockedAssertionMd
    }
}
else {
    $blocker = Get-Content -Raw -LiteralPath $Qua95BlockerStatusJson | ConvertFrom-Json
    $blockerChecked = Get-Date $blocker.last_checked_local
    $assertionWrite = (Get-Item -LiteralPath $Qua95BlockedAssertionMd).LastWriteTime
    $lag = [math]::Round(([math]::Abs(($assertionWrite - $blockerChecked).TotalMinutes)), 2)
    $assertionStatus = if ($lag -le $Qua95BlockedAssertionMaxLagMinutes) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_blocked_assertion_freshness' -Status $assertionStatus -Meta @{
        max_lag_minutes = $Qua95BlockedAssertionMaxLagMinutes
        lag_minutes = $lag
        blocker_last_checked = $blocker.last_checked_local
        assertion_last_write_local = $assertionWrite.ToString('o')
    }
}

# QUA-95 unblock readiness freshness/consistency
if (-not (Test-Path -LiteralPath $Qua95UnblockReadinessCheckScript)) {
    Add-Check -Name 'qua95_unblock_readiness_freshness' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95UnblockReadinessCheckScript
    }
}
else {
    $readinessOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95UnblockReadinessCheckScript 2>&1
    $readinessCode = $LASTEXITCODE
    $readinessText = ($readinessOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $readinessStatus = if ($readinessCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_unblock_readiness_freshness' -Status $readinessStatus -Meta @{
        exit_code = $readinessCode
        output = $readinessText
    }
}

# QUA-95 unblock owner/action consistency
if (-not (Test-Path -LiteralPath $Qua95UnblockOwnerConsistencyCheckScript)) {
    Add-Check -Name 'qua95_unblock_owner_consistency' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95UnblockOwnerConsistencyCheckScript
    }
}
else {
    $ownerConsistencyOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95UnblockOwnerConsistencyCheckScript 2>&1
    $ownerConsistencyCode = $LASTEXITCODE
    $ownerConsistencyText = ($ownerConsistencyOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $ownerConsistencyStatus = if ($ownerConsistencyCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_unblock_owner_consistency' -Status $ownerConsistencyStatus -Meta @{
        exit_code = $ownerConsistencyCode
        output = $ownerConsistencyText
    }
}

# QUA-95 audit signal consistency
if (-not (Test-Path -LiteralPath $Qua95AuditSignalCheckScript)) {
    Add-Check -Name 'qua95_audit_signal' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95AuditSignalCheckScript
    }
}
else {
    $auditSignalOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95AuditSignalCheckScript 2>&1
    $auditSignalCode = $LASTEXITCODE
    $auditSignalText = ($auditSignalOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $auditSignalStatus = if ($auditSignalCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_audit_signal' -Status $auditSignalStatus -Meta @{
        exit_code = $auditSignalCode
        output = $auditSignalText
    }
}

# QUA-95 direct verifier proof consistency
if (-not (Test-Path -LiteralPath $Qua95DirectVerifierProofCheckScript)) {
    Add-Check -Name 'qua95_direct_verifier_proof' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95DirectVerifierProofCheckScript
    }
}
else {
    $directProofOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95DirectVerifierProofCheckScript 2>&1
    $directProofCode = $LASTEXITCODE
    $directProofText = ($directProofOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $directProofStatus = if ($directProofCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_direct_verifier_proof' -Status $directProofStatus -Meta @{
        exit_code = $directProofCode
        output = $directProofText
    }
}

# QUA-95 custom visibility proof consistency
if (-not (Test-Path -LiteralPath $Qua95CustomVisibilityProofCheckScript)) {
    Add-Check -Name 'qua95_custom_visibility_proof' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95CustomVisibilityProofCheckScript
    }
}
else {
    $customVisibilityOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95CustomVisibilityProofCheckScript 2>&1
    $customVisibilityCode = $LASTEXITCODE
    $customVisibilityText = ($customVisibilityOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $customVisibilityStatus = if ($customVisibilityCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_custom_visibility_proof' -Status $customVisibilityStatus -Meta @{
        exit_code = $customVisibilityCode
        output = $customVisibilityText
    }
}

# QUA-95 cross-artifact evidence cohesion
if (-not (Test-Path -LiteralPath $Qua95EvidenceCohesionCheckScript)) {
    Add-Check -Name 'qua95_evidence_cohesion' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95EvidenceCohesionCheckScript
    }
}
else {
    $cohesionOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95EvidenceCohesionCheckScript 2>&1
    $cohesionCode = $LASTEXITCODE
    $cohesionText = ($cohesionOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $cohesionStatus = if ($cohesionCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_evidence_cohesion' -Status $cohesionStatus -Meta @{
        exit_code = $cohesionCode
        output = $cohesionText
    }
}

# QUA-95 systemic failure signature coherence
if (-not (Test-Path -LiteralPath $Qua95FailureSignatureCheckScript)) {
    Add-Check -Name 'qua95_failure_signature' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95FailureSignatureCheckScript
    }
}
else {
    $failureSignatureOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95FailureSignatureCheckScript 2>&1
    $failureSignatureCode = $LASTEXITCODE
    $failureSignatureText = ($failureSignatureOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $failureSignatureStatus = if ($failureSignatureCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_failure_signature' -Status $failureSignatureStatus -Meta @{
        exit_code = $failureSignatureCode
        output = $failureSignatureText
    }
}

# QUA-95 heartbeat custom-visibility coherence
if (-not (Test-Path -LiteralPath $Qua95HeartbeatCustomVisibilityCheckScript)) {
    Add-Check -Name 'qua95_heartbeat_custom_visibility' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95HeartbeatCustomVisibilityCheckScript
    }
}
else {
    $hbCustomVisibilityOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95HeartbeatCustomVisibilityCheckScript 2>&1
    $hbCustomVisibilityCode = $LASTEXITCODE
    $hbCustomVisibilityText = ($hbCustomVisibilityOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $hbCustomVisibilityStatus = if ($hbCustomVisibilityCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_heartbeat_custom_visibility' -Status $hbCustomVisibilityStatus -Meta @{
        exit_code = $hbCustomVisibilityCode
        output = $hbCustomVisibilityText
    }
}

# QUA-95 canonical snapshot consistency
if (-not (Test-Path -LiteralPath $Qua95CanonicalSnapshotCheckScript)) {
    Add-Check -Name 'qua95_canonical_snapshot' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95CanonicalSnapshotCheckScript
    }
}
else {
    $canonicalOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95CanonicalSnapshotCheckScript 2>&1
    $canonicalCode = $LASTEXITCODE
    $canonicalText = ($canonicalOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $canonicalStatus = if ($canonicalCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_canonical_snapshot' -Status $canonicalStatus -Meta @{
        exit_code = $canonicalCode
        output = $canonicalText
    }
}

# QUA-95 canonical snapshot freshness
if (-not (Test-Path -LiteralPath $Qua95CanonicalSnapshotFreshnessCheckScript)) {
    Add-Check -Name 'qua95_canonical_snapshot_freshness' -Status 'warn' -Meta @{
        reason = 'check_script_missing'
        path = $Qua95CanonicalSnapshotFreshnessCheckScript
    }
}
else {
    $canonicalFreshnessOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95CanonicalSnapshotFreshnessCheckScript 2>&1
    $canonicalFreshnessCode = $LASTEXITCODE
    $canonicalFreshnessText = ($canonicalFreshnessOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $canonicalFreshnessStatus = if ($canonicalFreshnessCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_canonical_snapshot_freshness' -Status $canonicalFreshnessStatus -Meta @{
        exit_code = $canonicalFreshnessCode
        output = $canonicalFreshnessText
    }
}

# QUA-95 ops bundle manifest integrity
if (-not (Test-Path -LiteralPath $Qua95OpsBundleManifestScript)) {
    Add-Check -Name 'qua95_ops_bundle_manifest' -Status 'warn' -Meta @{
        reason = 'manifest_script_missing'
        path = $Qua95OpsBundleManifestScript
    }
}
else {
    $bundleOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95OpsBundleManifestScript 2>&1
    $bundleCode = $LASTEXITCODE
    $bundleText = ($bundleOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $bundleStatus = if ($bundleCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_ops_bundle_manifest' -Status $bundleStatus -Meta @{
        exit_code = $bundleCode
        output = $bundleText
    }
}

# QUA-95 blocked-heartbeat wrapper validation
if (-not (Test-Path -LiteralPath $Qua95BlockedHeartbeatWrapperTestScript)) {
    Add-Check -Name 'qua95_blocked_heartbeat_wrapper' -Status 'warn' -Meta @{
        reason = 'wrapper_test_script_missing'
        path = $Qua95BlockedHeartbeatWrapperTestScript
    }
}
else {
    $wrapperOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $Qua95BlockedHeartbeatWrapperTestScript 2>&1
    $wrapperCode = $LASTEXITCODE
    $wrapperText = ($wrapperOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $wrapperStatus = if ($wrapperCode -eq 0) { 'ok' } else { 'critical' }
    Add-Check -Name 'qua95_blocked_heartbeat_wrapper' -Status $wrapperStatus -Meta @{
        exit_code = $wrapperCode
        output = $wrapperText
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
