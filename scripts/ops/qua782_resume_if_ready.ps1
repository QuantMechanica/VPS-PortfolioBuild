param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$OutRoot = 'D:\QM\reports\pipeline\QM5_1003\P3',
    [int]$SemanticBlockTtlHours = 24
)

$probeScript = Join-Path $RepoRoot 'scripts\ops\qua782_unblock_probe.ps1'

# If a recent semantic block marker exists, short-circuit to blocked state.
$semanticBlock = Get-ChildItem -Path $OutRoot -File -Filter 'qua782_semantic_block_*.json' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if ($semanticBlock) {
    $ageHours = ((Get-Date) - $semanticBlock.LastWriteTime).TotalHours
    if ($ageHours -lt $SemanticBlockTtlHours) {
        $statePath = Join-Path $OutRoot 'qua782_gate_state.json'
        $state = [ordered]@{
            issue = 'QUA-782'
            checked_at_local = (Get-Date).ToString('o')
            status = 'BLOCKED'
            block_type = 'semantic_exhaustion'
            semantic_block_file = $semanticBlock.FullName
            unblock_owner = 'OWNER/Research'
            unblock_action = 'Provide correct axis mapping or updated EA/setfiles exposing breakout_lookback and atr_stop_mult.'
        }
        New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null
        ($state | ConvertTo-Json -Depth 6) | Out-File -FilePath $statePath -Encoding utf8 -Force
        Write-Output 'action=skipped reason=blocked_semantic_exhaustion'
        Write-Output ("state_file=" + $statePath)
        Write-Output ("semantic_block_file=" + $semanticBlock.FullName)
        exit 3
    }
}

$probe = & powershell -ExecutionPolicy Bypass -File $probeScript
$probeLines = @($probe)
$status = if ($probeLines -match 'status=READY') { 'READY' } else { 'BLOCKED' }
$missing = @()
foreach ($line in $probeLines) {
    if ($line -like 'missing_setfile=*') {
        $missing += $line.Substring('missing_setfile='.Length)
    }
}

$statePath = Join-Path $OutRoot 'qua782_gate_state.json'
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null
$state = [ordered]@{
    issue = 'QUA-782'
    checked_at_local = (Get-Date).ToString('o')
    status = $status
    missing_setfiles = $missing
}
($state | ConvertTo-Json -Depth 6) | Out-File -FilePath $statePath -Encoding utf8 -Force

if ($status -eq 'READY') {
    $existing = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -ieq 'python.exe' -and
            $_.CommandLine -match 'p3_param_sweep\.py' -and
            $_.CommandLine -match '--ea\s+QM5_1003'
        } |
        Select-Object ProcessId, CommandLine)
    if ($existing.Count -gt 1) {
        $state.status = 'BLOCKED'
        $state.block_type = 'concurrent_runs'
        $state.unblock_owner = 'OWNER/Research + DevOps'
        $state.unblock_action = 'Enforce single active QM5_1003 P3 sweep process before resume; terminate/retire duplicate launcher and keep one canonical run.'
        $state.active_run_pids = @($existing | ForEach-Object { $_.ProcessId })
        $state.active_run_count = $existing.Count
        ($state | ConvertTo-Json -Depth 8) | Out-File -FilePath $statePath -Encoding utf8 -Force
        Write-Output ("action=skipped reason=concurrent_runs count=" + $existing.Count)
        $existing | ForEach-Object { Write-Output ("active_pid=" + $_.ProcessId + " cmd=" + $_.CommandLine) }
        Write-Output ("state_file=" + $statePath)
        exit 4
    }
    if ($existing.Count -eq 1) {
        Write-Output ("action=skipped reason=already_running pid=" + $existing[0].ProcessId)
        Write-Output ("state_file=" + $statePath)
        exit 0
    }

    $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outLog = Join-Path $OutRoot "p3_m15_resume_${ts}.out.log"
    $errLog = Join-Path $OutRoot "p3_m15_resume_${ts}.err.log"
    $sweepScript = Join-Path $RepoRoot 'framework\scripts\p3_param_sweep.py'
    $args = @(
        $sweepScript
        '--ea','QM5_1003'
        '--symbols','AUDCHF.DWX,EURNZD.DWX'
        '--periods','M15'
        '--year','2024'
        '--max-runs','24'
    )
    $env:PYTHONUNBUFFERED = '1'
    $p = Start-Process -FilePath python -ArgumentList $args -WorkingDirectory $RepoRoot -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru -NoNewWindow
    Write-Output "action=launched pid=$($p.Id) out=$outLog err=$errLog"
    exit 0
}

Write-Output 'action=skipped reason=blocked_missing_setfiles'
Write-Output ("state_file=" + $statePath)
$probeLines | ForEach-Object { Write-Output $_ }
exit 2
