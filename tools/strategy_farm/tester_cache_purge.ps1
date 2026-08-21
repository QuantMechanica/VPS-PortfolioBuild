# =====================================================================
#  QuantMechanica - Tester-Cache Purge (permanent fix for D: fill-up)
#  Periodically reclaims the regenerable MT5 tester history caches that
#  otherwise fill D: over ~days of backtesting (incident 2026-06-02).
#
#  Clears ONLY regenerable caches:
#    D:\QM\mt5\T<n>\Tester\bases\*   (tester history .hcc cache)
#    D:\QM\mt5\T<n>\Tester\Agent-*   (per-agent working dirs; MT5 recreates)
#  NEVER touches source tick data (T<n>\Bases top-level) or reports (D:\QM\reports).
#
#  IdleCaches acts when D: free < LowWaterGB (default 150): stop only idle
#  factory slots -> clear their caches -> start only missing workers via the
#  interactive-session token launcher. Because MT5 agents read these caches
#  mid-run, the factory MUST be stopped first.
#
#  BusyScratch is deliberately narrower and never stops a terminal. It removes
#  only released bar*.tmp files under T1-T10\Tester\Agent-*\temp after BOTH an
#  age guard and a per-file exclusive-open test. All is the scheduled default:
#  perform that safe busy-scratch sweep, then the threshold-driven idle purge.
#
#  The controller may run as SYSTEM, but run_in_console_session.ps1 uses the
#  logged-on user's token, so missing daemons land in the existing desktop
#  session rather than as session-0 children. Live terminals are outside every
#  kill/purge scope.
# =====================================================================
[CmdletBinding()]
param(
    # 2026-07-21 raised 80->150: on a 1TB disk an 80GB floor let ~200GB of regenerable
    # Tester cache accumulate (it purges only below the floor, and D: hovered just above 80).
    [int]$LowWaterGB = 150,
    [string]$RepoRoot = "C:\QM\repo",
    [string]$FarmRoot = "D:\QM\strategy_farm",
    [string]$Mt5Root = "D:\QM\mt5",
    [ValidateSet('All', 'IdleCaches', 'BusyScratch')]
    [string]$Mode = 'All',
    [ValidateRange(1, 1440)]
    [int]$MinAgeMinutes = 5,
    [ValidatePattern('^(T(?:[1-9]|10))?$')]
    [string]$Terminal = '',
    [switch]$DryRun
)
$ErrorActionPreference = 'Continue'
$py = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$log = "D:\QM\reports\state\tester_cache_purge.log"
$resourcePolicy = Join-Path $RepoRoot 'tools\strategy_farm\resource_headroom.py'
function Now { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
function FreeGB { [math]::Round((Get-PSDrive D).Free/1GB,2) }
function Log($m) { $line = "$(Now) $m"; Write-Output $line; try { Add-Content -Path $log -Value $line -Encoding UTF8 } catch {} }
function Get-ReclaimTelemetry {
    param([long]$ExpectedDeletedBytes, [double]$BeforeGb, [double]$AfterGb)
    if (-not (Test-Path -LiteralPath $resourcePolicy -PathType Leaf)) {
        return [pscustomobject]@{ status = 'TELEMETRY_ERROR'; reason = 'resource_policy_missing' }
    }
    $beforeText = $BeforeGb.ToString('R', [Globalization.CultureInfo]::InvariantCulture)
    $afterText = $AfterGb.ToString('R', [Globalization.CultureInfo]::InvariantCulture)
    try {
        $raw = @(& $py $resourcePolicy validate-reclaim `
            --expected-deleted-bytes $ExpectedDeletedBytes `
            --free-before-gb $beforeText --free-after-gb $afterText 2>$null)
        $result = (($raw -join '') | ConvertFrom-Json -ErrorAction Stop)
        if (-not $result.status) { throw 'telemetry result missing status' }
        return $result
    } catch {
        return [pscustomobject]@{ status = 'TELEMETRY_ERROR'; reason = "validator_failed:$($_.Exception.Message)" }
    }
}
function Invoke-BusyScratchReclaim {
    param(
        [string]$Root,
        [int]$MinimumAgeMinutes,
        [string]$OnlyTerminal,
        [bool]$Apply
    )

    $before = FreeGB
    $cutoff = (Get-Date).AddMinutes(-$MinimumAgeMinutes)
    $terminalNames = if ($OnlyTerminal) { @($OnlyTerminal.ToUpperInvariant()) } else { @(1..10 | ForEach-Object { "T$_" }) }
    [long]$totalCandidateBytes = 0
    [long]$totalReclaimedBytes = 0
    $totalCandidates = 0
    $totalLocked = 0
    $totalDeleteErrors = 0

    foreach ($terminalName in $terminalNames) {
        $testerRoot = Join-Path (Join-Path $Root $terminalName) 'Tester'
        $terminalCandidates = 0
        $terminalLocked = 0
        $terminalDeleteErrors = 0
        [long]$terminalCandidateBytes = 0
        [long]$terminalReclaimedBytes = 0

        foreach ($agent in @(Get-ChildItem -LiteralPath $testerRoot -Directory -Filter 'Agent-*' -ErrorAction SilentlyContinue)) {
            $tempRoot = Join-Path $agent.FullName 'temp'
            if (-not (Test-Path -LiteralPath $tempRoot -PathType Container)) { continue }
            foreach ($file in @(Get-ChildItem -LiteralPath $tempRoot -File -Filter 'bar*.tmp' -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt $cutoff })) {
                $terminalCandidates++
                $terminalCandidateBytes += $file.Length
                $stream = $null
                try {
                    # Share=None proves the agent has released this exact file.
                    # Anything still held raises and is skipped; never force-delete.
                    $stream = [System.IO.File]::Open(
                        $file.FullName,
                        [System.IO.FileMode]::Open,
                        [System.IO.FileAccess]::ReadWrite,
                        [System.IO.FileShare]::None
                    )
                } catch {
                    $terminalLocked++
                    continue
                } finally {
                    if ($null -ne $stream) { $stream.Dispose() }
                }

                if ($Apply) {
                    try {
                        Remove-Item -LiteralPath $file.FullName -ErrorAction Stop
                        $terminalReclaimedBytes += $file.Length
                    } catch {
                        # A post-probe race or filesystem error is a skip, not a
                        # reason to weaken sharing semantics or force deletion.
                        $terminalDeleteErrors++
                    }
                } else {
                    $terminalReclaimedBytes += $file.Length
                }
            }
        }

        $totalCandidates += $terminalCandidates
        $totalCandidateBytes += $terminalCandidateBytes
        $totalReclaimedBytes += $terminalReclaimedBytes
        $totalLocked += $terminalLocked
        $totalDeleteErrors += $terminalDeleteErrors
        Log ("BUSY_SCRATCH terminal={0} mode={1} candidates={2} candidate_gb={3:N2} {4}_gb={5:N2} locked_skips={6} delete_error_skips={7}" -f `
            $terminalName, $(if ($Apply) { 'APPLY' } else { 'DRYRUN' }), $terminalCandidates,
            ($terminalCandidateBytes / 1GB), $(if ($Apply) { 'reclaimed' } else { 'reclaimable' }),
            ($terminalReclaimedBytes / 1GB), $terminalLocked, $terminalDeleteErrors)
    }

    if ($Apply) { Start-Sleep -Seconds 2 }
    $after = FreeGB
    $telemetry = if ($Apply) {
        Get-ReclaimTelemetry -ExpectedDeletedBytes $totalReclaimedBytes -BeforeGb $before -AfterGb $after
    } else {
        [pscustomobject]@{ status = 'DRYRUN'; reason = 'no_free_space_claim' }
    }
    Log ("BUSY_SCRATCH_SUMMARY mode={0} min_age_minutes={1} candidates={2} candidate_gb={3:N2} {4}_gb={5:N2} locked_skips={6} delete_error_skips={7} d_free_before_gb={8:N2} d_free_after_gb={9:N2} telemetry_status={10} telemetry_reason={11}" -f `
        $(if ($Apply) { 'APPLY' } else { 'DRYRUN' }), $MinimumAgeMinutes, $totalCandidates,
        ($totalCandidateBytes / 1GB), $(if ($Apply) { 'reclaimed' } else { 'reclaimable' }),
        ($totalReclaimedBytes / 1GB), $totalLocked, $totalDeleteErrors, $before, $after,
        $telemetry.status, $telemetry.reason)
    if ($telemetry.status -eq 'TELEMETRY_ERROR') {
        Log "TELEMETRY_ERROR scope=busy_scratch reason=$($telemetry.reason) expected_deleted_bytes=$totalReclaimedBytes d_free_before_gb=$before d_free_after_gb=$after"
    }
    $script:BusyScratchTelemetry = $telemetry
}
function Invoke-InteractiveWorkerDedupe {
    $launcher = Join-Path $RepoRoot 'tools\strategy_farm\run_in_console_session.ps1'
    $starter = Join-Path $RepoRoot 'tools\strategy_farm\start_terminal_workers.py'
    if (-not (Test-Path -LiteralPath $launcher)) { throw "interactive-session launcher missing: $launcher" }
    if (-not (Test-Path -LiteralPath $starter)) { throw "worker starter missing: $starter" }

    $targetUser = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultUserName
    if (-not $targetUser) { $targetUser = 'qm-admin' }
    $spawnScript = @"
Remove-Item Env:PYTHONHOME -ErrorAction SilentlyContinue
Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue
& '$py' '$starter' --repo-root '$RepoRoot' --farm-root '$FarmRoot' --dedupe
exit `$LASTEXITCODE
"@
    $encodedSpawn = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($spawnScript))
    $sessionShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $starterArgs = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encodedSpawn"
    $launchOutput = @(& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
        -File $launcher -Exe $sessionShell -Arguments $starterArgs -WorkDir $RepoRoot `
        -TargetUser $targetUser -WaitSeconds 180 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "CreateProcessAsUser launcher rc=$LASTEXITCODE output=$($launchOutput -join ' ')"
    }
    $launchText = $launchOutput -join ' '
    # Accept any session-label word: run_in_console_session.ps1 emits "console session"
    # (never "interactive session"), so the old "(?:interactive )?session" pattern threw
    # on every successful respawn. See 2026-07-27_interactive_task_selfheal_fix.md.
    if ($launchText -notmatch 'LAUNCHED pid=\d+ into (?:\w+ )?session (\d+)') {
        throw "CreateProcessAsUser launcher returned no session evidence: $launchText"
    }
    return $launchText
}
function Get-FactoryTerminalFromCommandLine {
    param([string]$CommandLine)
    if (-not $CommandLine) { return $null }
    if ($CommandLine -match '\\mt5\\(T(?:[1-9]|10))\\') { return $matches[1].ToUpperInvariant() }
    if ($CommandLine -match '--terminal\s+(T(?:[1-9]|10))\b') { return $matches[1].ToUpperInvariant() }
    return $null
}
function Get-ProtectedFactoryTerminals {
    $terms = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $probe = @'
import json
import sqlite3

out = []
try:
    conn = sqlite3.connect(r"D:/QM/strategy_farm/state/farm_state.sqlite")
    conn.row_factory = sqlite3.Row
    for row in conn.execute("SELECT claimed_by, payload_json FROM work_items WHERE status='active'"):
        term = (row["claimed_by"] or "").strip().upper()
        if not term:
            try:
                payload = json.loads(row["payload_json"] or "{}")
                term = str(payload.get("terminal") or "").strip().upper()
            except Exception:
                term = ""
        if term:
            out.append(term)
except Exception:
    pass
print(json.dumps(sorted(set(out))))
'@
    try {
        $activeTerms = (($probe | & $py - 2>$null) -join '' | ConvertFrom-Json)
        foreach ($t in @($activeTerms)) {
            if ($t -match '^T(?:[1-9]|10)$') { [void]$terms.Add($t.ToUpperInvariant()) }
        }
    } catch {}
    foreach ($p in @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue)) {
        $t = Get-FactoryTerminalFromCommandLine $p.CommandLine
        if ($t) { [void]$terms.Add($t) }
    }
    return @($terms)
}

$runBusyScratch = $Mode -in @('All', 'BusyScratch')
$telemetryErrors = @()
if ($runBusyScratch) {
    $script:BusyScratchTelemetry = $null
    Invoke-BusyScratchReclaim -Root $Mt5Root -MinimumAgeMinutes $MinAgeMinutes `
        -OnlyTerminal $Terminal -Apply:(-not $DryRun)
    $busyTelemetry = $script:BusyScratchTelemetry
    if ($busyTelemetry.status -eq 'TELEMETRY_ERROR') { $telemetryErrors += $busyTelemetry }
    if ($Mode -eq 'BusyScratch') {
        if ($telemetryErrors.Count -gt 0) { exit 2 }
        return
    }
}

$free = FreeGB
if ($free -ge $LowWaterGB) { Log "SKIP: D: free ${free}GB >= ${LowWaterGB}GB threshold"; return }

Log "TRIGGER: D: free ${free}GB < ${LowWaterGB}GB -> purge tester caches"
$protectedTerminals = @(Get-ProtectedFactoryTerminals)
$protectedLookup = @{}
foreach ($t in $protectedTerminals) { $protectedLookup[$t.ToUpperInvariant()] = $true }
if ($DryRun) { Log "DRYRUN: would pause new dispatch, protect active/running terminals=[$($protectedTerminals -join ',')], clear only idle T*\Tester caches, restart missing workers"; return }

# 1. stop factory (caches are read by running agents). Preserve the operator's
# enable-state: a maintenance purge must never turn a deliberately disabled
# dispatcher back on when it exits.
$pumpTask = Get-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue
$tickTask = Get-ScheduledTask -TaskName 'QM_StrategyFarm_Tick_5min' -ErrorAction SilentlyContinue
$pumpWasEnabled = ($null -ne $pumpTask -and $pumpTask.State -ne 'Disabled')
$tickWasEnabled = ($null -ne $tickTask -and $tickTask.State -ne 'Disabled')
$factoryOffFlag = Join-Path $FarmRoot 'state\FACTORY_OFF.flag'
$factoryOffWasPresent = Test-Path -LiteralPath $factoryOffFlag -PathType Leaf
$factoryRestartAuthorized = (-not $factoryOffWasPresent) -and ($pumpWasEnabled -or $tickWasEnabled)
Log "owner state captured: pump_enabled=$pumpWasEnabled tick_enabled=$tickWasEnabled factory_off_flag=$factoryOffWasPresent restart_authorized=$factoryRestartAuthorized"
Stop-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue | Out-Null
Disable-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue | Out-Null
Stop-ScheduledTask -TaskName 'QM_StrategyFarm_Tick_5min' -ErrorAction SilentlyContinue | Out-Null
Disable-ScheduledTask -TaskName 'QM_StrategyFarm_Tick_5min' -ErrorAction SilentlyContinue | Out-Null
# Gentler teardown (2026-06-22): verify a TRUE clean slate before clearing/restarting.
# Repeated abrupt force-kills in quick succession leaked OS resources (handles /
# window-station / single-instance state) and eventually wedged terminal64 launches
# (instant-exit ~0.06s) for hours — a state only Factory_OFF/ON could clear. Killing in
# a verify-loop + a longer settle lets Windows fully release those resources, and
# guarantees 0 survivors so the respawn can't over-provision on top of stragglers.
function Kill-FactoryProcs {
    param([hashtable]$Protected)
    @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
        Where-Object CommandLine -match 'terminal_worker\.py') | ForEach-Object {
            $tname = Get-FactoryTerminalFromCommandLine $_.CommandLine
            if ($tname -and -not $Protected.ContainsKey($tname)) {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
    # ONLY idle factory T1-T10 terminals — NEVER active/running protected terminals,
    # T_Live (live trading), or T_Export.
    @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match '\\mt5\\T(?:[1-9]|10)\\' }) | ForEach-Object {
            $tname = Get-FactoryTerminalFromCommandLine $_.CommandLine
            if ($tname -and -not $Protected.ContainsKey($tname)) {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
}
$killPass = 0
while ($killPass -lt 4) {
    Kill-FactoryProcs -Protected $protectedLookup
    Start-Sleep -Seconds 3
    $liveW = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'terminal_worker\.py' -and (Get-FactoryTerminalFromCommandLine $_.CommandLine) -and -not $protectedLookup.ContainsKey((Get-FactoryTerminalFromCommandLine $_.CommandLine)) }).Count
    $liveT = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match '\\mt5\\T(?:[1-9]|10)\\' -and (Get-FactoryTerminalFromCommandLine $_.CommandLine) -and -not $protectedLookup.ContainsKey((Get-FactoryTerminalFromCommandLine $_.CommandLine)) }).Count
    if ($liveW -eq 0 -and $liveT -eq 0) { break }
    $killPass++
}
Start-Sleep -Seconds 5   # extra settle so the OS releases handles before respawn
Log "idle factory slots stopped ($killPass extra kill pass(es); protected active/running terminals=[$($protectedTerminals -join ',')])"

# 2. clear regenerable tester caches
$purgedTerminals = @()
[long]$idleDeletedBytes = 0
foreach ($n in 1..10) {
    $terminalName = "T$n"
    if ($protectedLookup.ContainsKey($terminalName)) {
        Log "SKIP_PROTECTED: $terminalName has active work_item or running terminal64; cache left intact"
        continue
    }
    $t = Join-Path $Mt5Root "T$n"
    if (-not (Test-Path $t)) { continue }
    $testerRoot = [IO.Path]::GetFullPath((Join-Path $t 'Tester'))
    $targets = @(
        @(Get-ChildItem -LiteralPath (Join-Path $testerRoot 'bases') -ErrorAction SilentlyContinue)
        @(Get-ChildItem -LiteralPath $testerRoot -Directory -Filter 'Agent-*' -ErrorAction SilentlyContinue)
    )
    foreach ($target in $targets) {
        $targetPath = [IO.Path]::GetFullPath($target.FullName)
        $contained = $targetPath.StartsWith(
            $testerRoot.TrimEnd('\') + '\',
            [StringComparison]::OrdinalIgnoreCase
        )
        if (-not $contained) {
            Log "TELEMETRY_ERROR scope=idle_cache reason=target_outside_tester_root target=$targetPath root=$testerRoot"
            $telemetryErrors += [pscustomobject]@{ status = 'TELEMETRY_ERROR'; reason = 'target_outside_tester_root' }
            continue
        }
        [long]$beforeBytes = if ($target.PSIsContainer) {
            [long](Get-ChildItem -LiteralPath $targetPath -File -Recurse -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
        } else { [long]$target.Length }
        Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction SilentlyContinue
        [long]$afterBytes = 0
        if (Test-Path -LiteralPath $targetPath) {
            $afterBytes = [long](Get-ChildItem -LiteralPath $targetPath -File -Recurse -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
        }
        [long]$deletedBytes = [math]::Max(0, $beforeBytes - $afterBytes)
        $idleDeletedBytes += $deletedBytes
        Log "PURGE_TARGET terminal=$terminalName target=$targetPath before_bytes=$beforeBytes after_bytes=$afterBytes deleted_bytes=$deletedBytes"
    }
    $purgedTerminals += $terminalName
}
Start-Sleep -Seconds 2
$after = FreeGB
$idleTelemetry = Get-ReclaimTelemetry -ExpectedDeletedBytes $idleDeletedBytes -BeforeGb $free -AfterGb $after
if ($idleTelemetry.status -eq 'TELEMETRY_ERROR') {
    $telemetryErrors += $idleTelemetry
    Log "TELEMETRY_ERROR scope=idle_cache reason=$($idleTelemetry.reason) expected_deleted_bytes=$idleDeletedBytes d_free_before_gb=$free d_free_after_gb=$after"
}
Log "idle caches cleared terminals=[$($purgedTerminals -join ',')]: D: ${free}GB -> ${after}GB deleted_bytes=$idleDeletedBytes observed_free_delta_gb=$([math]::Round($after-$free,1)) telemetry_status=$($idleTelemetry.status) telemetry_reason=$($idleTelemetry.reason)"

# 3. Restart only when the captured OWNER state actually authorized the factory.
#    A cache-maintenance task must never turn Factory OFF into Factory ON. When
#    both dispatch tasks were disabled (or FACTORY_OFF.flag existed), leave them
#    disabled and do not queue an InteractiveToken start.
if (-not $factoryRestartAuthorized) {
    Log 'factory restart SKIPPED: captured OWNER state was OFF; caches purged without changing factory state'
    if ($telemetryErrors.Count -gt 0) { exit 2 }
    return
}

#    Restore only the dispatch tasks that were enabled on entry, then invoke the
#    same idempotent, interactive-session token launcher used by the hardened
#    factory watchdog. Unlike Factory_ON, it neither removes FACTORY_OFF nor
#    tears down healthy/protected worker slots.
try {
    if ($pumpWasEnabled) { Enable-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction Stop | Out-Null }
    if ($tickWasEnabled) { Enable-ScheduledTask -TaskName 'QM_StrategyFarm_Tick_5min' -ErrorAction Stop | Out-Null }
    $launchEvidence = Invoke-InteractiveWorkerDedupe
    Start-Sleep -Seconds 10
    $daemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
                 Where-Object { $_.CommandLine -match 'terminal_worker\.py' })
    Log "missing workers requested via interactive-session token launcher: $($daemons.Count) total worker daemon(s); D: free $(FreeGB)GB; $launchEvidence"
} catch {
    Log "factory missing-worker recovery FAILED (interactive-session token launcher): $($_.Exception.Message) - existing protected slots were not killed"
}
if ($telemetryErrors.Count -gt 0) { exit 2 }
