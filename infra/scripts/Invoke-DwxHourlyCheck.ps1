[CmdletBinding()]
param(
    [string]$CsvSourceDir = 'D:\QM\reports\setup\tick-data-timezone',
    [string]$ImportQueueDir = 'D:\QM\mt5\T1\MQL5\Files\imports',
    [string]$StateDir = 'D:\QM\mt5\T1\dwx_import\state',
    [string]$LogDir = 'D:\QM\mt5\T1\dwx_import\logs',
    [string]$PythonExe = 'python',
    [string]$PrepareImportScript = 'D:\QM\mt5\T1\dwx_import\prepare_import.py',
    [string]$VerifyImportScript = 'D:\QM\mt5\T1\dwx_import\verify_import.py',
    [string]$ServiceHeartbeatFile = 'D:\QM\mt5\T1\MQL5\Files\imports\service_heartbeat.txt',
    [int]$MinStableMinutes = 30,
    [int]$MaxServiceHeartbeatMinutes = 15,
    [int]$LockStaleMinutes = 110
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-RunLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')] [string]$Level = 'INFO'
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line
    Add-Content -LiteralPath $script:RunLogPath -Value $line
}

function Get-SymbolRoot {
    param([Parameter(Mandatory = $true)] [string]$CsvName)

    if ($CsvName -match '^(?<root>.+)_GMT[+-]\d+_(EU|US)-DST\.csv$') {
        return $matches['root']
    }

    return $null
}

function Test-IsStable {
    param(
        [Parameter(Mandatory = $true)] [System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)] [datetime]$StableBefore
    )

    return $File.LastWriteTime -le $StableBefore
}

$null = New-Item -ItemType Directory -Path $StateDir -Force
$null = New-Item -ItemType Directory -Path $LogDir -Force

$runStamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$script:RunLogPath = Join-Path $LogDir "dwx_hourly_$runStamp.log"
New-Item -ItemType File -Path $script:RunLogPath -Force | Out-Null

$lockPath = Join-Path $StateDir 'dwx_hourly.lock'
$statePath = Join-Path $StateDir 'dwx_hourly_state.json'

if (Test-Path -LiteralPath $lockPath) {
    $lockAge = (Get-Date) - (Get-Item -LiteralPath $lockPath).LastWriteTime
    if ($lockAge.TotalMinutes -lt $LockStaleMinutes) {
        Write-RunLog -Message ("Lock file exists and is fresh ({0:N1} min). Skipping this run." -f $lockAge.TotalMinutes) -Level 'WARN'
        exit 0
    }

    Write-RunLog -Message ("Stale lock detected ({0:N1} min). Removing and continuing." -f $lockAge.TotalMinutes) -Level 'WARN'
    Remove-Item -LiteralPath $lockPath -Force
}

New-Item -ItemType File -Path $lockPath -Force | Out-Null

$state = [ordered]@{
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    status = 'ok'
    staged = 0
    deferred = 0
    skipped = 0
    queue_pending = 0
    queue_done = 0
    verify_ran = $false
    notes = @()
}

try {
    if (-not (Test-Path -LiteralPath $CsvSourceDir)) {
        $state.status = 'blocked'
        $state.notes += "csv_source_missing:$CsvSourceDir"
        Write-RunLog "CSV source directory missing: $CsvSourceDir" 'ERROR'
        return
    }

    if (-not (Test-Path -LiteralPath $ImportQueueDir)) {
        $state.status = 'blocked'
        $state.notes += "import_queue_missing:$ImportQueueDir"
        Write-RunLog "Import queue directory missing: $ImportQueueDir" 'ERROR'
        return
    }

    $stableBefore = (Get-Date).AddMinutes(-1 * $MinStableMinutes)

    $ws30TickPath = Join-Path $CsvSourceDir 'WS30_GMT+2_US-DST.csv'
    $ws30M1Path = Join-Path $CsvSourceDir 'WS30_GMT+2_US-DST_M1.csv'
    $hasWs30Pair = (Test-Path -LiteralPath $ws30TickPath) -and (Test-Path -LiteralPath $ws30M1Path)
    if (-not $hasWs30Pair) {
        $state.status = 'waiting_ws30'
        $state.notes += 'ws30_pair_missing'
        Write-RunLog 'WS30 gate not satisfied: missing one or both WS30 files.'
        return
    }

    $ws30Tick = Get-Item -LiteralPath $ws30TickPath
    $ws30M1 = Get-Item -LiteralPath $ws30M1Path
    if ((-not (Test-IsStable -File $ws30Tick -StableBefore $stableBefore)) -or (-not (Test-IsStable -File $ws30M1 -StableBefore $stableBefore))) {
        $state.status = 'waiting_ws30'
        $state.notes += 'ws30_pair_not_stable'
        Write-RunLog "WS30 gate not satisfied: files are newer than $MinStableMinutes minutes."
        return
    }

    $tickFiles = Get-ChildItem -LiteralPath $CsvSourceDir -Filter '*_GMT*DST.csv' -File |
        Where-Object { $_.Name -notlike '*_M1.csv' }

    foreach ($tickFile in $tickFiles) {
        $root = Get-SymbolRoot -CsvName $tickFile.Name
        if (-not $root) {
            $state.skipped++
            Write-RunLog "Skipping unrecognized CSV naming: $($tickFile.Name)" 'WARN'
            continue
        }

        $m1Path = Join-Path $CsvSourceDir ("{0}_GMT+2_US-DST_M1.csv" -f $root)
        if (-not (Test-Path -LiteralPath $m1Path)) {
            $state.deferred++
            Write-RunLog ("Deferring {0}: missing M1 file." -f $root)
            continue
        }

        $m1File = Get-Item -LiteralPath $m1Path
        if ((-not (Test-IsStable -File $tickFile -StableBefore $stableBefore)) -or (-not (Test-IsStable -File $m1File -StableBefore $stableBefore))) {
            $state.deferred++
            Write-RunLog ("Deferring {0}: files are newer than {1} minutes." -f $root, $MinStableMinutes)
            continue
        }

        if (-not (Test-Path -LiteralPath $PrepareImportScript)) {
            $state.status = 'blocked'
            $state.notes += "prepare_script_missing:$PrepareImportScript"
            Write-RunLog "prepare_import.py not found at $PrepareImportScript" 'ERROR'
            break
        }

        Write-RunLog "Staging $root via prepare_import.py"
        & $PythonExe $PrepareImportScript $tickFile.FullName
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            $state.status = 'degraded'
            $state.notes += ("prepare_failed:{0}:{1}" -f $root, $exitCode)
            Write-RunLog "prepare_import.py failed for $root with code $exitCode" 'WARN'
            continue
        }

        $state.staged++
    }

    $queuePending = @(Get-ChildItem -LiteralPath $ImportQueueDir -Filter '*.import.txt' -File -ErrorAction SilentlyContinue).Count
    $queueDoneDir = Join-Path $ImportQueueDir 'done'
    $queueDone = 0
    if (Test-Path -LiteralPath $queueDoneDir) {
        $queueDone = @(Get-ChildItem -LiteralPath $queueDoneDir -Filter '*.import.txt' -File -ErrorAction SilentlyContinue).Count
    }

    $state.queue_pending = $queuePending
    $state.queue_done = $queueDone

    if ($queuePending -eq 0 -and (Test-Path -LiteralPath $VerifyImportScript)) {
        Write-RunLog 'Queue empty. Running verify_import.py.'
        & $PythonExe $VerifyImportScript
        $verifyExit = $LASTEXITCODE
        $state.verify_ran = $true
        if ($verifyExit -ne 0) {
            $state.status = 'degraded'
            $state.notes += "verify_failed:$verifyExit"
            Write-RunLog "verify_import.py failed with code $verifyExit" 'WARN'
        }
    }

    if (Test-Path -LiteralPath $ServiceHeartbeatFile) {
        $hbAge = ((Get-Date) - (Get-Item -LiteralPath $ServiceHeartbeatFile).LastWriteTime).TotalMinutes
        if ($hbAge -gt $MaxServiceHeartbeatMinutes) {
            $state.status = 'degraded'
            $state.notes += "service_heartbeat_stale_minutes:$([int]$hbAge)"
            Write-RunLog -Message ("Service heartbeat is stale ({0:N1} min)." -f $hbAge) -Level 'WARN'
        }
    }
    else {
        $state.status = 'degraded'
        $state.notes += 'service_heartbeat_missing'
        Write-RunLog "Service heartbeat file missing: $ServiceHeartbeatFile" 'WARN'
    }
}
finally {
    $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath -Encoding ASCII
    if (Test-Path -LiteralPath $lockPath) {
        Remove-Item -LiteralPath $lockPath -Force
    }
    Write-RunLog "Run completed with status=$($state.status), staged=$($state.staged), deferred=$($state.deferred), skipped=$($state.skipped), queue_pending=$($state.queue_pending)."
}
