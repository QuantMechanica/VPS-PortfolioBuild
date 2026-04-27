[CmdletBinding()]
param(
    [string[]]$FactoryTerminalRoots = @(
        'D:\QM\mt5\T1',
        'D:\QM\mt5\T2',
        'D:\QM\mt5\T3',
        'D:\QM\mt5\T4',
        'D:\QM\mt5\T5'
    ),
    [string]$MarkerFileName = 'portable.txt',
    [string]$EvidenceDirectory = 'D:\QM\reports\ops\devops',
    [switch]$RestartForNonPortableProbe,
    [int]$ProbeWaitSeconds = 12
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TerminalProcessesForRoot {
    param([string]$Root)
    $normalized = [IO.Path]::GetFullPath($Root).TrimEnd('\\')
    return @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($normalized, [System.StringComparison]::OrdinalIgnoreCase) })
}

function Get-LatestLogWriteUtc {
    param([string[]]$LogDirs)
    $latest = $null
    foreach ($dir in $LogDirs) {
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
            continue
        }

        $cand = Get-ChildItem -LiteralPath $dir -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
        if ($cand -and ($null -eq $latest -or $cand.LastWriteTimeUtc -gt $latest)) {
            $latest = $cand.LastWriteTimeUtc
        }
    }
    return $latest
}

function Get-AppDataMetaQuotesLatestLogUtc {
    $terminalRoot = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
    if (-not (Test-Path -LiteralPath $terminalRoot -PathType Container)) {
        return $null
    }

    $logDirs = New-Object System.Collections.Generic.List[string]
    $hashDirs = @(Get-ChildItem -LiteralPath $terminalRoot -Directory -ErrorAction SilentlyContinue)
    foreach ($hashDir in $hashDirs) {
        $logDirs.Add((Join-Path $hashDir.FullName 'logs')) | Out-Null
        $logDirs.Add((Join-Path $hashDir.FullName 'MQL5\Logs')) | Out-Null
    }

    return Get-LatestLogWriteUtc -LogDirs $logDirs.ToArray()
}

function Get-AppDataOriginWritesSince {
    param(
        [string]$TerminalExePath,
        [datetime]$SinceUtc
    )

    $terminalRoot = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
    if (-not (Test-Path -LiteralPath $terminalRoot -PathType Container)) {
        return @()
    }

    $matches = New-Object System.Collections.Generic.List[object]
    $needle = $TerminalExePath.ToLowerInvariant()
    $originFiles = @(Get-ChildItem -LiteralPath $terminalRoot -Filter 'origin.txt' -File -Recurse -ErrorAction SilentlyContinue)
    foreach ($origin in $originFiles) {
        $writeUtc = $origin.LastWriteTimeUtc
        if ($writeUtc -lt $SinceUtc) {
            continue
        }

        $content = (Get-Content -LiteralPath $origin.FullName -Raw -ErrorAction SilentlyContinue)
        if (-not $content) {
            continue
        }

        if ($content.ToLowerInvariant() -like "*$needle*") {
            $matches.Add([pscustomobject]@{
                origin_path = $origin.FullName
                last_write_utc = $writeUtc.ToString('o')
            }) | Out-Null
        }
    }

    return $matches.ToArray()
}

$results = New-Object System.Collections.Generic.List[object]
$changed = 0
$allMarkersPresent = $true

foreach ($root in $FactoryTerminalRoots) {
    $normalized = [IO.Path]::GetFullPath($root).TrimEnd('\\')
    $leaf = Split-Path -Path $normalized -Leaf
    if ($leaf -match '^T6(_|$)') {
        throw "Refusing T6 scope path '$normalized'. This script is factory-only (T1-T5)."
    }

    $markerPath = Join-Path $normalized $MarkerFileName
    $entry = [ordered]@{
        terminal = $leaf
        terminal_root = $normalized
        marker_path = $markerPath
        marker_status = 'unknown'
        marker_exists = $false
        probe = $null
    }

    if (-not (Test-Path -LiteralPath $normalized -PathType Container)) {
        $entry.marker_status = 'missing_root'
        $allMarkersPresent = $false
        $results.Add([pscustomobject]$entry) | Out-Null
        continue
    }

    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        Set-Content -LiteralPath $markerPath -Value '' -Encoding ASCII -NoNewline
        $entry.marker_status = 'created'
        $changed += 1
    }
    else {
        $size = (Get-Item -LiteralPath $markerPath).Length
        if ($size -ne 0) {
            Set-Content -LiteralPath $markerPath -Value '' -Encoding ASCII -NoNewline
            $entry.marker_status = 'normalized_to_empty'
            $changed += 1
        }
        else {
            $entry.marker_status = 'unchanged'
        }
    }

    $entry.marker_exists = Test-Path -LiteralPath $markerPath -PathType Leaf
    if (-not $entry.marker_exists) {
        $allMarkersPresent = $false
    }

    if ($RestartForNonPortableProbe.IsPresent) {
        $terminalExe = Join-Path $normalized 'terminal64.exe'
        if (-not (Test-Path -LiteralPath $terminalExe -PathType Leaf)) {
            $entry.probe = [ordered]@{
                status = 'skipped'
                reason = 'terminal_exe_missing'
                terminal_exe = $terminalExe
            }
            $results.Add([pscustomobject]$entry) | Out-Null
            continue
        }

        $previous = @(Get-TerminalProcessesForRoot -Root $normalized)
        foreach ($p in $previous) {
            try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch {}
        }
        Start-Sleep -Seconds 2

        $appDataBefore = Get-AppDataMetaQuotesLatestLogUtc
        $probeStart = (Get-Date).ToUniversalTime()
        $started = Start-Process -FilePath $terminalExe -PassThru
        Start-Sleep -Seconds $ProbeWaitSeconds

        $procNow = @(Get-CimInstance Win32_Process -Filter "ProcessId=$($started.Id)" -ErrorAction SilentlyContinue)
        $rootLogLatest = Get-LatestLogWriteUtc -LogDirs @(
            (Join-Path $normalized 'logs'),
            (Join-Path $normalized 'MQL5\Logs')
        )
        $appDataAfter = Get-AppDataMetaQuotesLatestLogUtc

        $cmdLine = $null
        if ($procNow.Count -gt 0) { $cmdLine = $procNow[0].CommandLine }
        $launchedWithoutPortableArg = $true
        if ($cmdLine -and $cmdLine -match '(?i)\s/portable(\s|$)') {
            $launchedWithoutPortableArg = $false
        }

        $rootLogsTouched = ($null -ne $rootLogLatest -and $rootLogLatest -ge $probeStart)
        $appDataTouched = $false
        if ($null -ne $appDataAfter -and $appDataAfter -ge $probeStart) {
            if ($null -eq $appDataBefore -or $appDataAfter -gt $appDataBefore) {
                $appDataTouched = $true
            }
        }
        $appDataOriginWrites = @(Get-AppDataOriginWritesSince -TerminalExePath $terminalExe -SinceUtc $probeStart)
        $appDataOriginTouched = $appDataOriginWrites.Count -gt 0

        try { Stop-Process -Id $started.Id -Force -ErrorAction SilentlyContinue } catch {}
        Start-Sleep -Seconds 1

        if ($previous.Count -gt 0) {
            Start-Process -FilePath $terminalExe -ArgumentList '/portable' | Out-Null
            Start-Sleep -Seconds 2
        }

        $probeStatus = if ($launchedWithoutPortableArg -and -not $appDataOriginTouched -and (Test-Path -LiteralPath (Join-Path $normalized 'Bases\Custom') -PathType Container)) { 'pass' } else { 'inconclusive' }
        $entry.probe = [ordered]@{
            status = $probeStatus
            launched_without_portable_arg = $launchedWithoutPortableArg
            root_logs_touched = $rootLogsTouched
            appdata_logs_touched = $appDataTouched
            appdata_origin_touched_for_terminal = $appDataOriginTouched
            appdata_origin_writes = $appDataOriginWrites
            root_logs_latest_utc = $(if ($rootLogLatest) { $rootLogLatest.ToString('o') } else { $null })
            appdata_logs_latest_before_utc = $(if ($appDataBefore) { $appDataBefore.ToString('o') } else { $null })
            appdata_logs_latest_after_utc = $(if ($appDataAfter) { $appDataAfter.ToString('o') } else { $null })
            custom_symbols_path = (Join-Path $normalized 'Bases\Custom')
            custom_symbols_path_exists = (Test-Path -LiteralPath (Join-Path $normalized 'Bases\Custom') -PathType Container)
            started_pid = $started.Id
            probe_start_utc = $probeStart.ToString('o')
        }
    }

    $results.Add([pscustomobject]$entry) | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
$evidencePath = Join-Path $EvidenceDirectory ("portable_marker_evidence_{0}.json" -f $timestamp)

$summary = [ordered]@{
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    host = $env:COMPUTERNAME
    changed = $changed
    checked = $FactoryTerminalRoots.Count
    all_markers_present = $allMarkersPresent
    probe_mode = [bool]$RestartForNonPortableProbe.IsPresent
    evidence_path = $evidencePath
    results = $results.ToArray()
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding ASCII
$summary | ConvertTo-Json -Depth 8

if (-not $allMarkersPresent) {
    exit 2
}
exit 0
