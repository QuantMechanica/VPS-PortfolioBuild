[CmdletBinding()]
param(
    [string]$TesterRoot = "$env:APPDATA\MetaQuotes\Tester",
    [string[]]$TerminalIds = @(),
    [double]$WarnTotalGb = 2.0,
    [double]$CriticalTotalGb = 5.0,
    [double]$WarnGrowthGbPer5Min = 0.75,
    [double]$CriticalGrowthGbPer5Min = 1.5,
    [ValidateSet("none", "delete_stale_tmp")]
    [string]$ContainmentMode = "none",
    [int]$ContainmentMinAgeMinutes = 10,
    [switch]$AllowContainmentWithTesterRunning,
    [int]$TopFiles = 10,
    [string]$StateFilePath = "Company/scripts/infra/mt5_tester_bar_tmp_watchdog_state.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
}

function Test-PathUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root)
    if (-not $fullRoot.EndsWith("\")) {
        $fullRoot = "$fullRoot\"
    }
    return $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-TerminalDirectories {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string[]]$SelectedTerminalIds
    )

    $all = @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^[A-Fa-f0-9]{32}$" })

    if ($SelectedTerminalIds.Count -eq 0) {
        return $all
    }

    $set = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($id in $SelectedTerminalIds) {
        [void]$set.Add($id)
    }

    return @($all | Where-Object { $set.Contains($_.Name) })
}

function Get-BarTmpFiles {
    param([Parameter(Mandatory = $true)][System.IO.DirectoryInfo[]]$TerminalDirs)

    $files = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    foreach ($dir in $TerminalDirs) {
        $matches = @(Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Filter "bar*.tmp" -ErrorAction SilentlyContinue)
        foreach ($file in $matches) {
            $files.Add($file)
        }
    }
    return @($files.ToArray())
}

function Get-TerminalIdForFile {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$FileInfo)

    foreach ($segment in $FileInfo.FullName.Split("\")) {
        if ($segment -match "^[A-Fa-f0-9]{32}$") {
            return $segment
        }
    }
    return "unknown"
}

function Get-AgentNameForFile {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$FileInfo)

    foreach ($segment in $FileInfo.FullName.Split("\")) {
        if ($segment -like "Agent-*") {
            return $segment
        }
    }
    return "unknown-agent"
}

function Read-State {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Get-BytesSum {
    param([object[]]$Items)

    if ($null -eq $Items) {
        return [int64]0
    }

    $measure = @($Items) | Measure-Object -Property Length -Sum
    if ($null -eq $measure) {
        return [int64]0
    }

    $sumProp = $measure.PSObject.Properties["Sum"]
    if ($null -eq $sumProp -or $null -eq $sumProp.Value) {
        return [int64]0
    }

    return [int64]$sumProp.Value
}

function Write-State {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$Payload
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    ($Payload | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-Severity {
    param(
        [double]$TotalGb,
        [object]$GrowthGbPer5Min,
        [double]$WarnGb,
        [double]$CriticalGb,
        [double]$WarnGrowth,
        [double]$CriticalGrowth
    )

    $growthValue = $null
    if ($null -ne $GrowthGbPer5Min) {
        $growthValue = [double]$GrowthGbPer5Min
    }

    if ($TotalGb -ge $CriticalGb) {
        return "critical"
    }

    if ($null -ne $growthValue -and $growthValue -ge $CriticalGrowth) {
        return "critical"
    }

    if ($TotalGb -ge $WarnGb) {
        return "warn"
    }

    if ($null -ne $growthValue -and $growthValue -ge $WarnGrowth) {
        return "warn"
    }

    return "ok"
}

if (-not (Test-Path -LiteralPath $TesterRoot)) {
    throw "Tester root does not exist: $TesterRoot"
}

$testerRootResolved = Resolve-FullPath -Path $TesterRoot
$statePathResolved = [System.IO.Path]::GetFullPath($StateFilePath)
$terminalDirs = Get-TerminalDirectories -Root $testerRootResolved -SelectedTerminalIds $TerminalIds
$preFiles = Get-BarTmpFiles -TerminalDirs $terminalDirs

$preTotalBytes = Get-BytesSum -Items $preFiles

$preTotalGb = [math]::Round(($preTotalBytes / 1GB), 3)
$preFileCount = ($preFiles | Measure-Object).Count

$previousState = Read-State -Path $statePathResolved
$growthDeltaBytes = $null
$growthGbPer5Min = $null
$previousTimestampUtc = $null

if ($null -ne $previousState) {
    try {
        $previousTimestampUtc = [datetime]::Parse($previousState.timestamp_utc).ToUniversalTime()
        $previousTotalBytes = [int64]$previousState.total_bytes
        $growthDeltaBytes = [int64]$preTotalBytes - [int64]$previousTotalBytes

        $minutes = ((Get-Date).ToUniversalTime() - $previousTimestampUtc).TotalMinutes
        if ($minutes -gt 0) {
            $growthGbPer5Min = [math]::Round((($growthDeltaBytes / 1GB) * (5 / $minutes)), 3)
        }
    } catch {
        $growthDeltaBytes = $null
        $growthGbPer5Min = $null
        $previousTimestampUtc = $null
    }
}

$severityBefore = Get-Severity `
    -TotalGb $preTotalGb `
    -GrowthGbPer5Min $growthGbPer5Min `
    -WarnGb $WarnTotalGb `
    -CriticalGb $CriticalTotalGb `
    -WarnGrowth $WarnGrowthGbPer5Min `
    -CriticalGrowth $CriticalGrowthGbPer5Min

$terminalSummary = @()
foreach ($terminal in $terminalDirs) {
    $terminalFiles = @($preFiles | Where-Object { (Get-TerminalIdForFile -FileInfo $_) -eq $terminal.Name })
    $terminalBytes = Get-BytesSum -Items $terminalFiles

    $agentGroups = @($terminalFiles | Group-Object { Get-AgentNameForFile -FileInfo $_ } | ForEach-Object {
        $bytes = Get-BytesSum -Items $_.Group
        [PSCustomObject]@{
            agent = $_.Name
            file_count = $_.Count
            bytes = $bytes
            gb = [math]::Round(($bytes / 1GB), 3)
        }
    } | Sort-Object -Property bytes -Descending)

    $terminalSummary += [PSCustomObject]@{
        terminal_id = $terminal.Name
        file_count = ($terminalFiles | Measure-Object).Count
        bytes = $terminalBytes
        gb = [math]::Round(($terminalBytes / 1GB), 3)
        top_agents = @($agentGroups | Select-Object -First 3)
    }
}

$topFileRows = @($preFiles |
    Sort-Object -Property Length -Descending |
    Select-Object -First $TopFiles |
    ForEach-Object {
        [PSCustomObject]@{
            path = $_.FullName
            bytes = $_.Length
            mb = [math]::Round(($_.Length / 1MB), 2)
            last_write_utc = $_.LastWriteTimeUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
    })

$terminalProcCount = (Get-Process -Name terminal64 -ErrorAction SilentlyContinue | Measure-Object).Count
$testerProcCount = (Get-Process -Name metatester64 -ErrorAction SilentlyContinue | Measure-Object).Count
$runningTesterProcess = ($terminalProcCount + $testerProcCount) -gt 0

$containment = [ordered]@{
    mode = $ContainmentMode
    attempted = $false
    executed = $false
    skipped_reason = $null
    min_age_minutes = $ContainmentMinAgeMinutes
    candidate_file_count = 0
    candidate_bytes = 0
    deleted_file_count = 0
    deleted_bytes = 0
    delete_errors = @()
}

if ($ContainmentMode -eq "delete_stale_tmp") {
    $containment.attempted = $true

    $cutoff = (Get-Date).AddMinutes(-1 * $ContainmentMinAgeMinutes)
    $candidates = @($preFiles | Where-Object { $_.LastWriteTime -le $cutoff })
    $candidateBytes = Get-BytesSum -Items $candidates
    $containment.candidate_file_count = ($candidates | Measure-Object).Count
    $containment.candidate_bytes = $candidateBytes

    if ($runningTesterProcess -and -not $AllowContainmentWithTesterRunning.IsPresent) {
        $containment.skipped_reason = "terminal64/metatester64 process is active; pass -AllowContainmentWithTesterRunning to override."
    } elseif ($containment.candidate_file_count -eq 0) {
        $containment.skipped_reason = "no stale bar*.tmp candidates matched containment age filter."
    } else {
        foreach ($candidate in $candidates) {
            if (-not (Test-PathUnderRoot -Path $candidate.FullName -Root $testerRootResolved)) {
                $containment.delete_errors += "Skipped outside root: $($candidate.FullName)"
                continue
            }

            if ($candidate.Name -notlike "bar*.tmp") {
                $containment.delete_errors += "Skipped non-bar tmp filename: $($candidate.FullName)"
                continue
            }

            try {
                Remove-Item -LiteralPath $candidate.FullName -Force -ErrorAction Stop
                $containment.deleted_file_count += 1
                $containment.deleted_bytes += [int64]$candidate.Length
            } catch {
                $containment.delete_errors += "Delete failed: $($candidate.FullName) :: $($_.Exception.Message)"
            }
        }

        if ($containment.deleted_file_count -gt 0) {
            $containment.executed = $true
        } elseif ($containment.delete_errors.Count -eq 0) {
            $containment.skipped_reason = "candidate files were present but no file was deleted."
        }
    }
}

$postFiles = Get-BarTmpFiles -TerminalDirs $terminalDirs
$postTotalBytes = Get-BytesSum -Items $postFiles
$postTotalGb = [math]::Round(($postTotalBytes / 1GB), 3)
$postFileCount = ($postFiles | Measure-Object).Count

$severityAfter = Get-Severity `
    -TotalGb $postTotalGb `
    -GrowthGbPer5Min $growthGbPer5Min `
    -WarnGb $WarnTotalGb `
    -CriticalGb $CriticalTotalGb `
    -WarnGrowth $WarnGrowthGbPer5Min `
    -CriticalGrowth $CriticalGrowthGbPer5Min

$terminalBytesMap = @{}
foreach ($terminal in $terminalDirs) {
    $bytes = Get-BytesSum -Items ($postFiles | Where-Object { (Get-TerminalIdForFile -FileInfo $_) -eq $terminal.Name })
    $terminalBytesMap[$terminal.Name] = [int64]$bytes
}

$nowUtc = (Get-Date).ToUniversalTime()
Write-State -Path $statePathResolved -Payload @{
    timestamp_utc = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    total_bytes = [int64]$postTotalBytes
    terminal_bytes = $terminalBytesMap
}

$result = [ordered]@{
    timestamp_local = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
    timestamp_utc = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    tester_root = $testerRootResolved
    state_file_path = $statePathResolved
    terminal_ids = @($terminalDirs | ForEach-Object { $_.Name })
    process_state = [ordered]@{
        terminal64_count = $terminalProcCount
        metatester64_count = $testerProcCount
    }
    thresholds = [ordered]@{
        warn_total_gb = $WarnTotalGb
        critical_total_gb = $CriticalTotalGb
        warn_growth_gb_per_5m = $WarnGrowthGbPer5Min
        critical_growth_gb_per_5m = $CriticalGrowthGbPer5Min
    }
    scan_before = [ordered]@{
        file_count = $preFileCount
        total_bytes = [int64]$preTotalBytes
        total_gb = $preTotalGb
    }
    scan_after = [ordered]@{
        file_count = $postFileCount
        total_bytes = [int64]$postTotalBytes
        total_gb = $postTotalGb
    }
    growth = [ordered]@{
        previous_timestamp_utc = if ($null -eq $previousTimestampUtc) { $null } else { $previousTimestampUtc.ToString("yyyy-MM-ddTHH:mm:ssZ") }
        delta_bytes = if ($null -eq $growthDeltaBytes) { $null } else { [int64]$growthDeltaBytes }
        delta_gb_per_5m = $growthGbPer5Min
    }
    severity_before_containment = $severityBefore
    severity_after_containment = $severityAfter
    containment = $containment
    per_terminal = $terminalSummary
    largest_files = $topFileRows
}

$result | ConvertTo-Json -Depth 8
