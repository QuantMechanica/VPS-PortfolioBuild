param(
    [int]$SampleSeconds = 10,
    [switch]$AutoDrainOnStall = $true,
    [int]$StabilizeLoops = 4,
    [switch]$EmitBlockedSignal = $false,
    [int]$NextCheckMinutes = 30
)

$ErrorActionPreference = "Stop"

$issue = "QUA-739"
$reportRoot = "D:\QM\reports\pipeline\QM5_1003\P2"
$opsDir = "C:\QM\repo\docs\ops"
$timestamp = Get-Date
$stamp = $timestamp.ToString("yyyyMMddTHHmmsszzz").Replace(":", "")
$outPath = Join-Path $opsDir "QUA-739_GUARDED_SWEEP_${stamp}.json"

function Get-QmPython {
    Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
        Where-Object { $_.CommandLine -like "*p2_baseline.py*QM5_1003*" }
}

function Get-QmTesters {
    Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" |
        Where-Object { $_.CommandLine -like "*QM5_1003\P2*tester.ini*" }
}

$py = @(Get-QmPython)
$tt = @(Get-QmTesters)

$h1 = (Get-ChildItem -Path $reportRoot -Recurse -Filter *.htm -ErrorAction SilentlyContinue).Count

$cpu0 = @{}
foreach ($p in $py) {
    $pr = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
    if ($pr) {
        $cpu0["$($p.ProcessId)"] = [double]$pr.CPU
    }
}

Start-Sleep -Seconds $SampleSeconds

$h2 = (Get-ChildItem -Path $reportRoot -Recurse -Filter *.htm -ErrorAction SilentlyContinue).Count

$cpuDeltas = @()
$allZero = $true
foreach ($p in $py) {
    $pr = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
    if (-not $pr) {
        $cpuDeltas += [ordered]@{
            pid = $p.ProcessId
            cpu_delta = "exited"
        }
        $allZero = $false
        continue
    }
    $before = [double]($cpu0["$($p.ProcessId)"])
    $delta = [math]::Round(([double]$pr.CPU - $before), 4)
    $cpuDeltas += [ordered]@{
        pid = $p.ProcessId
        cpu_delta = $delta
    }
    if ($delta -gt 0) {
        $allZero = $false
    }
}

$htmDelta = $h2 - $h1
$stoppedPy = @()
$stoppedTt = @()
$autoDrained = $false

if ($AutoDrainOnStall -and $py.Count -gt 0 -and $allZero -and $htmDelta -eq 0) {
    foreach ($p in $py) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        $stoppedPy += $p.ProcessId
    }
    foreach ($p in $tt) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        $stoppedTt += $p.ProcessId
    }
    $autoDrained = $true
}

# Always drain orphan tester terminals when no matching python runners remain.
$remainingPy = @(Get-QmPython)
$remainingTt = @(Get-QmTesters)
if ($remainingPy.Count -eq 0 -and $remainingTt.Count -gt 0) {
    foreach ($p in $remainingTt) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        $stoppedTt += $p.ProcessId
    }
}

$finalPy = @(Get-QmPython)
$finalTt = @(Get-QmTesters)

# Race guard: a final settle + second drain pass for late-spawning residue.
$secondDrainPy = @()
$secondDrainTt = @()
if ($finalPy.Count -gt 0 -or $finalTt.Count -gt 0) {
    Start-Sleep -Seconds 2
    $latePy = @(Get-QmPython)
    $lateTt = @(Get-QmTesters)
    foreach ($p in $latePy) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        $secondDrainPy += $p.ProcessId
    }
    foreach ($p in $lateTt) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        $secondDrainTt += $p.ProcessId
    }
    if ($secondDrainPy.Count -gt 0 -or $secondDrainTt.Count -gt 0) {
        $stoppedPy += $secondDrainPy
        $stoppedTt += $secondDrainTt
    }
    $finalPy = @(Get-QmPython)
    $finalTt = @(Get-QmTesters)
}

# Stabilize loop: absorb rapid respawn races for a bounded number of passes.
$stabilizeLog = @()
for ($i = 1; $i -le $StabilizeLoops; $i++) {
    $curPy = @(Get-QmPython)
    $curTt = @(Get-QmTesters)
    if ($curPy.Count -eq 0 -and $curTt.Count -eq 0) {
        $stabilizeLog += [ordered]@{ iter = $i; state = "clean"; killed_python = 0; killed_testers = 0 }
        break
    }
    foreach ($p in $curPy) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        $stoppedPy += $p.ProcessId
    }
    foreach ($p in $curTt) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        $stoppedTt += $p.ProcessId
    }
    $stabilizeLog += [ordered]@{
        iter = $i
        state = "drain"
        killed_python = $curPy.Count
        killed_testers = $curTt.Count
    }
    Start-Sleep -Seconds 1
}

$finalPy = @(Get-QmPython)
$finalTt = @(Get-QmTesters)

$payload = [ordered]@{
    issue = $issue
    timestamp_local = (Get-Date).ToString("o")
    sample_seconds = $SampleSeconds
    initial_python = $py.Count
    initial_testers = $tt.Count
    htm_before = $h1
    htm_after = $h2
    htm_delta = $htmDelta
    cpu_deltas = $cpuDeltas
    auto_drain_on_stall = [bool]$AutoDrainOnStall
    auto_drained = $autoDrained
    stopped_python_pids = $stoppedPy
    stopped_tester_pids = $stoppedTt
    second_drain_python_pids = $secondDrainPy
    second_drain_tester_pids = $secondDrainTt
    stabilize_loops = $StabilizeLoops
    stabilize_log = $stabilizeLog
    remaining_python = $finalPy.Count
    remaining_testers = $finalTt.Count
}

$payload | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding utf8

if ($EmitBlockedSignal) {
    Write-Warning "-EmitBlockedSignal is deprecated and now ignored; use issue-state transitions in control plane instead of local blocked-signal files."
}

Write-Output "sweep=$outPath auto_drained=$autoDrained remaining_py=$($finalPy.Count) remaining_testers=$($finalTt.Count)"
