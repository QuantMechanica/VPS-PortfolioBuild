<#
.SYNOPSIS
  WS-E1 fixture / state-machine tests for the live-terminal alarm STATE contract
  (Live_Alarm_State.ps1) and recovery-invariance proof for T_Live_Watchdog.ps1.

.DESCRIPTION
  Two independent proofs, plain asserts, no live process access:

    1. STATE MACHINE  -- Get-LiveAlarmCondition maps facts to the correct
       condition for BOTH monitored sessions (T_Live, FTMO) independently across
       missing / recovered / duplicate / maintenance / probe-unknown /
       launch-failed / stale-state / reboot-suppression, with correct precedence.
       Write-LiveAlarmState is exercised against real temp files to prove the
       transition-deduplication invariant (transitions / since_utc / last_change
       move ONLY on a genuine condition change) and the atomic write + schema.

    2. RECOVERY INVARIANCE  -- the modified watchdog preserves the existing
       recovery + reboot state machine byte-for-byte (verbatim block comparison
       against the pristine canonical baseline), the alarm emission is guarded and
       side-effect-free, and the helper contains no launcher / reboot / mail /
       process-control commands.

.PARAMETER HelperPath           Live_Alarm_State.ps1 (default: ..\Live_Alarm_State.ps1)
.PARAMETER WatchdogPath         modified T_Live_Watchdog.ps1 (default: ..\T_Live_Watchdog.ps1)
.PARAMETER BaselineWatchdogPath pristine canonical watchdog for the verbatim check (optional)
.PARAMETER WorkDir              scratch dir for fixture state files (default: temp)
#>
param(
    [string]$HelperPath = (Join-Path $PSScriptRoot '..\Live_Alarm_State.ps1'),
    [string]$WatchdogPath = (Join-Path $PSScriptRoot '..\T_Live_Watchdog.ps1'),
    [string]$BaselineWatchdogPath = '',
    [string]$WorkDir = (Join-Path ([IO.Path]::GetTempPath()) ('wse1_alarm_' + [guid]::NewGuid().ToString('N')))
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:PassCount = 0
$script:Failures = New-Object System.Collections.Generic.List[string]

function Assert-QmTrue {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:PassCount++ } else { [void]$script:Failures.Add("FAIL: $Name") }
}
function Assert-QmFalse { param([bool]$Condition, [string]$Name) Assert-QmTrue -Condition (-not $Condition) -Name $Name }
function Assert-QmEqual {
    param($Expected, $Actual, [string]$Name)
    Assert-QmTrue -Condition ($Expected -eq $Actual) -Name ("{0} (expected='{1}', actual='{2}')" -f $Name, $Expected, $Actual)
}

# ---------------------------------------------------------------------------
# Load the helper (function-only, must be side-effect free).
# ---------------------------------------------------------------------------
$HelperPath = [IO.Path]::GetFullPath($HelperPath)
$WatchdogPath = [IO.Path]::GetFullPath($WatchdogPath)
Assert-QmTrue -Condition (Test-Path -LiteralPath $HelperPath -PathType Leaf) -Name "helper exists: $HelperPath"
. $HelperPath

[IO.Directory]::CreateDirectory($WorkDir) | Out-Null

# ===========================================================================
# PART 1 -- STATE MACHINE (Get-LiveAlarmCondition), session-agnostic pure fn.
# Facts are supplied as a hashtable; each case names the expected condition.
# The two live sessions map to identical fact-shapes, so a table proven here
# holds for both T_Live and FTMO (session identity enters only at dedup time,
# proven independently in PART 2).
# ===========================================================================
function New-Facts {
    param(
        [ValidateSet('RUNNING', 'PARKED', 'MAINTENANCE')][string]$ExpectedState = 'RUNNING',
        [bool]$ReviewExpired = $false,
        [bool]$Maintenance = $false,
        [bool]$ProbeOk = $true,
        [bool]$Running = $true,
        [int]$ProcessCount = 1,
        [bool]$SessionExists = $true,
        [bool]$PlacementOk = $true,
        [bool]$SupervisorHeartbeatReady = $true,
        [string]$SupervisorReason = 'ready',
        [bool]$SupervisorLaunchFailed = $false
    )
    return @{
        ExpectedState = $ExpectedState; ReviewExpired = $ReviewExpired
        Maintenance = $Maintenance; ProbeOk = $ProbeOk; Running = $Running
        ProcessCount = $ProcessCount; SessionExists = $SessionExists; PlacementOk = $PlacementOk
        SupervisorHeartbeatReady = $SupervisorHeartbeatReady; SupervisorReason = $SupervisorReason
        SupervisorLaunchFailed = $SupervisorLaunchFailed
    }
}

$cases = @(
    @{ name = 'ok/recovered';                 expect = 'ok';            facts = (New-Facts) },
    @{ name = 'missing (recovery pending)';    expect = 'missing';       facts = (New-Facts -Running $false -ProcessCount 0) },
    @{ name = 'missing (no session)';          expect = 'missing';       facts = (New-Facts -Running $false -ProcessCount 0 -SessionExists $false) },
    @{ name = 'missing (supervisor not fresh)';expect = 'missing';       facts = (New-Facts -Running $false -ProcessCount 0 -SupervisorHeartbeatReady $false -SupervisorReason 'state_stale') },
    @{ name = 'launch_failed';                 expect = 'launch_failed'; facts = (New-Facts -Running $false -ProcessCount 0 -SupervisorLaunchFailed $true) },
    @{ name = 'duplicate (count>1)';           expect = 'duplicate';     facts = (New-Facts -ProcessCount 2) },
    @{ name = 'duplicate (wrong session)';     expect = 'duplicate';     facts = (New-Facts -ProcessCount 1 -PlacementOk $false) },
    @{ name = 'maintenance';                   expect = 'maintenance';   facts = (New-Facts -Maintenance $true -Running $false -ProcessCount 0) },
    @{ name = 'probe_unknown';                 expect = 'probe_unknown'; facts = (New-Facts -ProbeOk $false) },
    @{ name = 'stale (terminal up, hb stale)'; expect = 'stale';         facts = (New-Facts -SupervisorHeartbeatReady $false -SupervisorReason 'state_stale') },
    @{ name = 'parked and off';                expect = 'parked';        facts = (New-Facts -ExpectedState 'PARKED' -Running $false -ProcessCount 0) },
    @{ name = 'parked but running';             expect = 'unexpected_running'; facts = (New-Facts -ExpectedState 'PARKED') },
    @{ name = 'review expired';                 expect = 'contract_expired'; facts = (New-Facts -ReviewExpired $true) },
    @{ name = 'expected maintenance';           expect = 'maintenance'; facts = (New-Facts -ExpectedState 'MAINTENANCE' -Running $false -ProcessCount 0) },
    # precedence
    @{ name = 'precedence maintenance>probe';  expect = 'maintenance';   facts = (New-Facts -Maintenance $true -ProbeOk $false) },
    @{ name = 'precedence probe>duplicate';    expect = 'probe_unknown'; facts = (New-Facts -ProbeOk $false -ProcessCount 2) },
    @{ name = 'precedence launch_failed>missing'; expect = 'launch_failed'; facts = (New-Facts -Running $false -ProcessCount 0 -SupervisorLaunchFailed $true -SessionExists $false) },
    @{ name = 'precedence duplicate>stale';    expect = 'duplicate';     facts = (New-Facts -ProcessCount 2 -SupervisorHeartbeatReady $false) }
)

foreach ($session in @('T_LIVE', 'FTMO')) {
    foreach ($case in $cases) {
        # splat a hashtable of named params:
        $splat = @{
            ExpectedState = $case.facts.ExpectedState; ReviewExpired = $case.facts.ReviewExpired
            Maintenance = $case.facts.Maintenance; ProbeOk = $case.facts.ProbeOk; Running = $case.facts.Running
            ProcessCount = $case.facts.ProcessCount; SessionExists = $case.facts.SessionExists; PlacementOk = $case.facts.PlacementOk
            SupervisorHeartbeatReady = $case.facts.SupervisorHeartbeatReady; SupervisorReason = $case.facts.SupervisorReason
            SupervisorLaunchFailed = $case.facts.SupervisorLaunchFailed
        }
        $r = Get-LiveAlarmCondition @splat
        Assert-QmEqual -Expected $case.expect -Actual $r.condition -Name "[$session] state: $($case.name)"
        Assert-QmTrue -Condition ([bool]$r.detail) -Name "[$session] detail non-empty: $($case.name)"
    }
}

# alarm-classification helper
Assert-QmTrue  -Condition (Test-LiveAlarmCondition -Condition 'missing')       -Name 'missing is alarm'
Assert-QmTrue  -Condition (Test-LiveAlarmCondition -Condition 'duplicate')     -Name 'duplicate is alarm'
Assert-QmTrue  -Condition (Test-LiveAlarmCondition -Condition 'launch_failed') -Name 'launch_failed is alarm'
Assert-QmTrue  -Condition (Test-LiveAlarmCondition -Condition 'probe_unknown') -Name 'probe_unknown is alarm'
Assert-QmTrue  -Condition (Test-LiveAlarmCondition -Condition 'stale')         -Name 'stale is alarm'
Assert-QmTrue  -Condition (Test-LiveAlarmCondition -Condition 'unexpected_running') -Name 'unexpected_running is alarm'
Assert-QmTrue  -Condition (Test-LiveAlarmCondition -Condition 'contract_expired') -Name 'contract_expired is alarm'
Assert-QmFalse -Condition (Test-LiveAlarmCondition -Condition 'ok')            -Name 'ok is not alarm'
Assert-QmFalse -Condition (Test-LiveAlarmCondition -Condition 'parked')        -Name 'parked is not alarm'
Assert-QmFalse -Condition (Test-LiveAlarmCondition -Condition 'maintenance')   -Name 'maintenance is not alarm'

# ===========================================================================
# PART 2 -- TRANSITION DEDUPLICATION + independence, via the real atomic write.
# ===========================================================================
$requiredSessionKeys = @('session', 'condition', 'since_utc', 'transitions', 'last_change')

function Write-Cycle {
    param(
        [string]$Path,
        [string]$Stamp,
        [hashtable]$Sessions,
        [bool]$Maintenance = $false,
        [bool]$RebootSuppressed = $false,
        [string]$Status = 'degraded',
        [hashtable]$ExpectedStates = @{ T_LIVE = 'RUNNING'; FTMO = 'RUNNING' },
        [int]$EscalationThreshold = 3
    )
    $sess = @{}
    foreach ($k in $Sessions.Keys) {
        $sess[$k] = [pscustomobject]@{ condition = $Sessions[$k]; detail = ("detail_for_" + $Sessions[$k]) }
    }
    Write-LiveAlarmState -AlarmFilePath $Path -NowStamp $Stamp -WatchdogStatus $Status `
        -Maintenance $Maintenance -RebootSuppressed $RebootSuppressed -Sessions $sess `
        -ExpectedStates $ExpectedStates -EscalationThreshold $EscalationThreshold | Out-Null
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

$alarmFile = Join-Path $WorkDir 'live_alarm_state.json'
if (Test-Path -LiteralPath $alarmFile) { Remove-Item -LiteralPath $alarmFile -Force }

# t0: both ok -> baseline, transitions=0
$d0 = Write-Cycle -Path $alarmFile -Stamp '2026-07-26T10:00:00Z' -Sessions @{ T_LIVE = 'ok'; FTMO = 'ok' } -Status 'healthy'
foreach ($s in @('T_LIVE', 'FTMO')) {
    foreach ($k in $requiredSessionKeys) {
        Assert-QmTrue -Condition ($d0.sessions.$s.PSObject.Properties.Name -contains $k) -Name "schema field '$k' present [$s]"
    }
    Assert-QmEqual -Expected $s -Actual $d0.sessions.$s.session -Name "session name self-labels [$s]"
    Assert-QmEqual -Expected 0 -Actual $d0.sessions.$s.transitions -Name "baseline transitions=0 [$s]"
    Assert-QmEqual -Expected '2026-07-26T10:00:00Z' -Actual (ConvertTo-LiveAlarmStamp $d0.sessions.$s.since_utc) -Name "baseline since_utc [$s]"
}
Assert-QmEqual -Expected $false -Actual $d0.any_alarm -Name 'both ok => any_alarm false'
Assert-QmEqual -Expected 'healthy' -Actual $d0.watchdog_status -Name 'watchdog_status passthrough'
Assert-QmTrue  -Condition ([bool]$d0.generated_utc) -Name 'generated_utc present (freshness)'

# t1: unchanged (both ok) -> DEDUP: transitions and since_utc must NOT move; generated_utc refreshes.
$d1 = Write-Cycle -Path $alarmFile -Stamp '2026-07-26T10:01:00Z' -Sessions @{ T_LIVE = 'ok'; FTMO = 'ok' } -Status 'healthy'
foreach ($s in @('T_LIVE', 'FTMO')) {
    Assert-QmEqual -Expected 0 -Actual $d1.sessions.$s.transitions -Name "dedup: transitions stable while ok [$s]"
    Assert-QmEqual -Expected '2026-07-26T10:00:00Z' -Actual (ConvertTo-LiveAlarmStamp $d1.sessions.$s.since_utc) -Name "dedup: since_utc stable while ok [$s]"
}
Assert-QmEqual -Expected '2026-07-26T10:01:00Z' -Actual (ConvertTo-LiveAlarmStamp $d1.generated_utc) -Name 'generated_utc refreshes each cycle'

# t2: T_LIVE goes MISSING, FTMO stays ok -> INDEPENDENCE + a single transition on T_LIVE only.
$d2 = Write-Cycle -Path $alarmFile -Stamp '2026-07-26T10:02:00Z' -Sessions @{ T_LIVE = 'missing'; FTMO = 'ok' }
Assert-QmEqual -Expected 1 -Actual $d2.sessions.T_LIVE.transitions -Name 'T_LIVE transition ok->missing counts once'
Assert-QmEqual -Expected '2026-07-26T10:02:00Z' -Actual (ConvertTo-LiveAlarmStamp $d2.sessions.T_LIVE.since_utc) -Name 'T_LIVE since_utc resets on transition'
Assert-QmEqual -Expected '2026-07-26T10:02:00Z' -Actual (ConvertTo-LiveAlarmStamp $d2.sessions.T_LIVE.last_change) -Name 'T_LIVE last_change == since_utc on transition'
Assert-QmEqual -Expected 'ok' -Actual $d2.sessions.T_LIVE.previous_condition -Name 'T_LIVE previous_condition captured'
Assert-QmEqual -Expected 0 -Actual $d2.sessions.FTMO.transitions -Name 'FTMO independent: no transition'
Assert-QmEqual -Expected '2026-07-26T10:00:00Z' -Actual (ConvertTo-LiveAlarmStamp $d2.sessions.FTMO.since_utc) -Name 'FTMO independent: since_utc unchanged'
Assert-QmEqual -Expected $true -Actual $d2.any_alarm -Name 'T_LIVE missing => any_alarm true'
Assert-QmEqual -Expected $true -Actual $d2.sessions.T_LIVE.alarm -Name 'T_LIVE alarm=true'
Assert-QmEqual -Expected $false -Actual $d2.sessions.FTMO.alarm -Name 'FTMO alarm=false'

# t3: T_LIVE still missing (dedup), FTMO now DUPLICATE (its first transition).
$d3 = Write-Cycle -Path $alarmFile -Stamp '2026-07-26T10:03:00Z' -Sessions @{ T_LIVE = 'missing'; FTMO = 'duplicate' }
Assert-QmEqual -Expected 1 -Actual $d3.sessions.T_LIVE.transitions -Name 'T_LIVE dedup: transitions stable while missing'
Assert-QmEqual -Expected '2026-07-26T10:02:00Z' -Actual (ConvertTo-LiveAlarmStamp $d3.sessions.T_LIVE.since_utc) -Name 'T_LIVE dedup: since_utc stable while missing'
Assert-QmEqual -Expected 1 -Actual $d3.sessions.FTMO.transitions -Name 'FTMO transition ok->duplicate counts once'
Assert-QmEqual -Expected 'ok' -Actual $d3.sessions.FTMO.previous_condition -Name 'FTMO previous_condition ok'

# t4: T_LIVE RECOVERS to ok (cleared), FTMO -> launch_failed.
$d4 = Write-Cycle -Path $alarmFile -Stamp '2026-07-26T10:04:00Z' -Sessions @{ T_LIVE = 'ok'; FTMO = 'launch_failed' }
Assert-QmEqual -Expected 2 -Actual $d4.sessions.T_LIVE.transitions -Name 'T_LIVE recovery counts as transition (missing->ok)'
Assert-QmEqual -Expected 'missing' -Actual $d4.sessions.T_LIVE.previous_condition -Name 'T_LIVE previous_condition missing'
Assert-QmEqual -Expected $false -Actual $d4.sessions.T_LIVE.alarm -Name 'T_LIVE cleared on recovery'
Assert-QmEqual -Expected 2 -Actual $d4.sessions.FTMO.transitions -Name 'FTMO duplicate->launch_failed counts once more'
Assert-QmEqual -Expected $true -Actual $d4.any_alarm -Name 'FTMO launch_failed keeps any_alarm true'

# t5: both maintenance -> condition maintenance, not an alarm; transitions advance once.
$d5 = Write-Cycle -Path $alarmFile -Stamp '2026-07-26T10:05:00Z' -Maintenance $true -Sessions @{ T_LIVE = 'maintenance'; FTMO = 'maintenance' }
Assert-QmEqual -Expected $false -Actual $d5.any_alarm -Name 'maintenance => any_alarm false (suppressed)'
Assert-QmEqual -Expected $true -Actual $d5.maintenance -Name 'top-level maintenance flag set'
Assert-QmEqual -Expected 3 -Actual $d5.sessions.T_LIVE.transitions -Name 'T_LIVE ok->maintenance transition'

# reboot-suppression: both sessions missing while a reboot was suppressed this cycle.
$rebootFile = Join-Path $WorkDir 'live_alarm_state_reboot.json'
if (Test-Path -LiteralPath $rebootFile) { Remove-Item -LiteralPath $rebootFile -Force }
$rb0 = Write-Cycle -Path $rebootFile -Stamp '2026-07-26T11:00:00Z' -Sessions @{ T_LIVE = 'missing'; FTMO = 'missing' } -RebootSuppressed $true -Status 'critical'
Assert-QmEqual -Expected $true -Actual $rb0.reboot_suppressed -Name 'reboot_suppressed surfaced to consumers'
Assert-QmEqual -Expected 'missing' -Actual $rb0.sessions.T_LIVE.condition -Name 'reboot-suppression: T_LIVE missing'
Assert-QmEqual -Expected 'missing' -Actual $rb0.sessions.FTMO.condition -Name 'reboot-suppression: FTMO missing'
Assert-QmEqual -Expected $true -Actual $rb0.any_alarm -Name 'reboot-suppression: any_alarm true'
Assert-QmEqual -Expected 'critical' -Actual $rb0.watchdog_status -Name 'reboot-suppression: watchdog_status critical'

# Park-aware state + exactly one escalation edge after three identical failures.
$parkFile = Join-Path $WorkDir 'live_alarm_state_parked.json'
if (Test-Path -LiteralPath $parkFile) { Remove-Item -LiteralPath $parkFile -Force }
$expected = @{ T_LIVE = 'RUNNING'; FTMO = 'PARKED' }
$pk0 = Write-Cycle -Path $parkFile -Stamp '2026-07-26T12:00:00Z' `
    -Sessions @{ T_LIVE = 'ok'; FTMO = 'parked' } -ExpectedStates $expected
Assert-QmEqual -Expected 'PARKED' -Actual $pk0.sessions.FTMO.expected_state -Name 'FTMO expected state persisted'
Assert-QmEqual -Expected $false -Actual $pk0.sessions.FTMO.alarm -Name 'PARKED+OFF is healthy'
$pk1 = Write-Cycle -Path $parkFile -Stamp '2026-07-26T12:01:00Z' `
    -Sessions @{ T_LIVE = 'ok'; FTMO = 'unexpected_running' } -ExpectedStates $expected
$pk2 = Write-Cycle -Path $parkFile -Stamp '2026-07-26T12:02:00Z' `
    -Sessions @{ T_LIVE = 'ok'; FTMO = 'unexpected_running' } -ExpectedStates $expected
$pk3 = Write-Cycle -Path $parkFile -Stamp '2026-07-26T12:03:00Z' `
    -Sessions @{ T_LIVE = 'ok'; FTMO = 'unexpected_running' } -ExpectedStates $expected
$pk4 = Write-Cycle -Path $parkFile -Stamp '2026-07-26T12:04:00Z' `
    -Sessions @{ T_LIVE = 'ok'; FTMO = 'unexpected_running' } -ExpectedStates $expected
Assert-QmEqual -Expected 1 -Actual $pk1.sessions.FTMO.identical_failure_cycles -Name 'alarm streak starts at one'
Assert-QmEqual -Expected $false -Actual $pk2.sessions.FTMO.new_escalation -Name 'no escalation before threshold'
Assert-QmEqual -Expected $true -Actual $pk3.sessions.FTMO.new_escalation -Name 'single escalation at threshold'
Assert-QmEqual -Expected $false -Actual $pk4.sessions.FTMO.new_escalation -Name 'steady alarm does not re-escalate'
Assert-QmEqual -Expected '2026-07-26T12:03:00Z' -Actual (ConvertTo-LiveAlarmStamp $pk4.sessions.FTMO.escalation_sent_utc) `
    -Name 'first escalation timestamp is stable'

# atomic write: no temp/backup residue left behind in the work dir.
$residue = @(Get-ChildItem -LiteralPath $WorkDir -Force | Where-Object { $_.Name -like '.live_alarm_state.*' })
Assert-QmEqual -Expected 0 -Actual $residue.Count -Name 'atomic write leaves no temp/backup residue'

# ===========================================================================
# PART 3 -- Get-SupervisorAlarmFacts fixtures (launch-failed + stale detection
# from the resident supervisor's existing state file, read-only).
# ===========================================================================
$now = [DateTime]::UtcNow
function New-SupervisorFixture {
    param([string]$Path, [datetime]$Checked, [string]$DxzState, [string]$FtmoState, [string[]]$Errors)
    $obj = [ordered]@{
        schema_version = 1
        last_checked_utc = $Checked.ToString('yyyy-MM-ddTHH:mm:ssZ')
        dxz_state = $DxzState
        ftmo_state = $FtmoState
        errors = @($Errors)
    }
    [IO.File]::WriteAllText($Path, ($obj | ConvertTo-Json -Depth 6), ([Text.UTF8Encoding]::new($false)))
}

# fresh + DXZ launcher failure recorded
$supA = Join-Path $WorkDir 'sup_fresh_dxz_launchfail.json'
New-SupervisorFixture -Path $supA -Checked $now -DxzState 'confidently_missing' -FtmoState 'healthy' -Errors @('launcher_failed:DXZ:exit=1')
$fa = Get-SupervisorAlarmFacts -StateFilePath $supA -NowUtc $now
Assert-QmEqual -Expected $true  -Actual $fa.fresh              -Name 'sup facts: fresh'
Assert-QmEqual -Expected $true  -Actual $fa.dxz_launch_failed  -Name 'sup facts: DXZ launch_failed detected'
Assert-QmEqual -Expected $false -Actual $fa.ftmo_launch_failed -Name 'sup facts: FTMO not launch_failed'

# fresh + FTMO exception variant
$supB = Join-Path $WorkDir 'sup_fresh_ftmo_exception.json'
New-SupervisorFixture -Path $supB -Checked $now -DxzState 'healthy' -FtmoState 'confidently_missing' -Errors @('launcher_exception:FTMO:boom')
$fb = Get-SupervisorAlarmFacts -StateFilePath $supB -NowUtc $now
Assert-QmEqual -Expected $true  -Actual $fb.ftmo_launch_failed -Name 'sup facts: FTMO launch_failed via exception'
Assert-QmEqual -Expected $false -Actual $fb.dxz_launch_failed  -Name 'sup facts: DXZ not launch_failed'

# stale supervisor state (older than freshness window) -> not fresh; launch_failed must be gated by freshness upstream
$supC = Join-Path $WorkDir 'sup_stale.json'
New-SupervisorFixture -Path $supC -Checked $now.AddSeconds(-600) -DxzState 'confidently_missing' -FtmoState 'healthy' -Errors @('launcher_failed:DXZ:exit=1')
$fc = Get-SupervisorAlarmFacts -StateFilePath $supC -NowUtc $now
Assert-QmEqual -Expected $false -Actual $fc.fresh -Name 'sup facts: stale state not fresh'

# missing supervisor file
$fd = Get-SupervisorAlarmFacts -StateFilePath (Join-Path $WorkDir 'does_not_exist.json') -NowUtc $now
Assert-QmEqual -Expected $false -Actual $fd.fresh -Name 'sup facts: missing file not fresh'
Assert-QmEqual -Expected 'state_missing' -Actual $fd.reason -Name 'sup facts: missing file reason'

# malformed timestamp
$supE = Join-Path $WorkDir 'sup_bad_ts.json'
[IO.File]::WriteAllText($supE, '{"last_checked_utc":"not-a-date","dxz_state":"healthy","ftmo_state":"healthy","errors":[]}', ([Text.UTF8Encoding]::new($false)))
$fe = Get-SupervisorAlarmFacts -StateFilePath $supE -NowUtc $now
Assert-QmEqual -Expected $false -Actual $fe.fresh -Name 'sup facts: malformed timestamp not fresh'
Assert-QmEqual -Expected 'invalid_timestamp' -Actual $fe.reason -Name 'sup facts: malformed timestamp reason'

# The upstream freshness gate: a stale supervisor with a launch error must NOT
# yield launch_failed at the watchdog (it becomes stale/missing instead). Prove
# the gating expression the watchdog uses: ($facts.fresh -and $facts.dxz_launch_failed).
Assert-QmFalse -Condition ($fc.fresh -and $fc.dxz_launch_failed) -Name 'stale sup launch error is gated off (not launch_failed)'
Assert-QmTrue  -Condition ($fa.fresh -and $fa.dxz_launch_failed) -Name 'fresh sup launch error is honored (launch_failed)'

# End-to-end: a stale supervisor while the terminal is UP => condition 'stale'.
$condStale = Get-LiveAlarmCondition -Maintenance $false -ProbeOk $true -Running $true -ProcessCount 1 `
    -SessionExists $true -PlacementOk $true -SupervisorHeartbeatReady $false -SupervisorReason 'state_stale' -SupervisorLaunchFailed $false
Assert-QmEqual -Expected 'stale' -Actual $condStale.condition -Name 'e2e: terminal up + supervisor stale => stale'

# ===========================================================================
# PART 4 -- HELPER is side-effect free (no launcher / reboot / mail / process
# control). This enforces "no second recovery authority".
# ===========================================================================
$helperTokens = $null; $helperParseErrors = $null
$helperAst = [System.Management.Automation.Language.Parser]::ParseFile($HelperPath, [ref]$helperTokens, [ref]$helperParseErrors)
Assert-QmEqual -Expected 0 -Actual @($helperParseErrors).Count -Name 'helper parses clean'
$helperCommands = @($helperAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) |
    ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
foreach ($forbidden in @(
    'Start-Process', 'Stop-Process', 'Start-ScheduledTask', 'Stop-ScheduledTask',
    'Enable-ScheduledTask', 'Disable-ScheduledTask', 'Restart-Computer', 'Send-MailMessage',
    'shutdown', 'shutdown.exe', 'Get-CimInstance', 'Get-Process', 'Invoke-CimMethod')) {
    Assert-QmFalse -Condition ($helperCommands -contains $forbidden) -Name "helper has no side-effect/process command '$forbidden'"
}

# ===========================================================================
# PART 5 -- RECOVERY INVARIANCE of the modified watchdog.
# ===========================================================================
Assert-QmTrue -Condition (Test-Path -LiteralPath $WatchdogPath -PathType Leaf) -Name "watchdog exists: $WatchdogPath"
$wdTokens = $null; $wdParseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($WatchdogPath, [ref]$wdTokens, [ref]$wdParseErrors)
Assert-QmEqual -Expected 0 -Actual @($wdParseErrors).Count -Name 'modified watchdog parses clean'
$wdText = [IO.File]::ReadAllText($WatchdogPath)

# 5a. Alarm emission is guarded by the fail-closed flag and wrapped in try/catch,
#     and sits AFTER the main evidence write but BEFORE the reboot state machine.
$idxEvidence = $wdText.IndexOf('Write-Evidence -State $state -Record $record', [StringComparison]::Ordinal)
$idxAlarmGuard = $wdText.IndexOf('if ($alarmHelperLoaded) {', [StringComparison]::Ordinal)
$idxRebootBlock = $wdText.IndexOf("if (`$actions -contains 'controlled_reboot_requested') {", [StringComparison]::Ordinal)
Assert-QmTrue -Condition ($idxEvidence -ge 0) -Name 'watchdog retains main Write-Evidence call'
Assert-QmTrue -Condition ($idxAlarmGuard -ge 0) -Name 'alarm emission guarded by $alarmHelperLoaded'
Assert-QmTrue -Condition ($idxRebootBlock -ge 0) -Name 'watchdog retains reboot state-machine entry'
Assert-QmTrue -Condition ($idxEvidence -lt $idxAlarmGuard -and $idxAlarmGuard -lt $idxRebootBlock) `
    -Name 'alarm block sits between evidence write and reboot block (does not disturb reboot)'
Assert-QmTrue -Condition ($wdText.Contains('. $alarmHelperScript')) -Name 'helper dot-sourced fail-closed'
Assert-QmTrue -Condition ($wdText.Contains('Join-Path $PSScriptRoot ''Live_Alarm_State.ps1''')) -Name 'helper resolved via $PSScriptRoot'

# 5b. Every recovery/reboot action + safety string literal from the canonical
#     watchdog is still present (superset check) -- proves nothing was removed.
$recoveryTokens = @(
    'noop_maintenance_flag', 'noop_process_probe_failed', 'noop_post_relaunch_process_probe_failed',
    'delegated_to_session_supervisor', 'resident_supervisor_unavailable',
    'no_interactive_session_for_resident_relaunch',
    'session_supervisor_started_or_verified_via_runex', 'would_start_session_supervisor_via_runex',
    'session_supervisor_start_cancelled_maintenance',
    'reboot_suppressed_by_switch', 'reboot_suppressed_startup_grace', 'reboot_suppressed_cooldown',
    'reboot_cancelled_maintenance_before_final_probes', 'reboot_cancelled_process_probe_unknown',
    'reboot_cancelled_live_process_reappeared', 'reboot_cancelled_maintenance_after_final_probes',
    'controlled_reboot_requested', 'reboot_cancelled_maintenance_before_shutdown',
    'reboot_countdown_aborted', 'reboot_countdown_aborted_maintenance',
    'shutdown.exe', '/r /t 20 /f /d p:4:1', 'shutdown.exe" /a',
    'consecutive_both_down', 'consecutive_relaunch_failed', 'NoReboot.IsPresent',
    'Test-MaintenanceRequested', 'Get-IndependentLivePresence'
)
foreach ($tok in $recoveryTokens) {
    Assert-QmTrue -Condition ($wdText.Contains($tok)) -Name "recovery token preserved: '$tok'"
}

# 5c. STRONG verbatim-block comparison vs the pristine canonical baseline (if given).
if ($BaselineWatchdogPath -and (Test-Path -LiteralPath $BaselineWatchdogPath -PathType Leaf)) {
    $baseText = [IO.File]::ReadAllText($BaselineWatchdogPath)
    # Block A: all recovery functions + main state machine + the main evidence write.
    $aStart = 'function Get-UtcStamp {'
    $aEnd = 'Write-Evidence -State $state -Record $record'
    $ai = $baseText.IndexOf($aStart, [StringComparison]::Ordinal)
    $aj = $baseText.IndexOf($aEnd, [StringComparison]::Ordinal)
    Assert-QmTrue -Condition ($ai -ge 0 -and $aj -gt $ai) -Name 'baseline: block A anchors found'
    $blockA = $baseText.Substring($ai, ($aj - $ai) + $aEnd.Length)
    Assert-QmTrue -Condition ($wdText.Contains($blockA)) -Name 'INVARIANCE: recovery functions + main state machine byte-for-byte preserved'

    # Block B: the entire reboot state machine, from its entry to EOF.
    $bStart = "if (`$actions -contains 'controlled_reboot_requested') {"
    $bi = $baseText.IndexOf($bStart, [StringComparison]::Ordinal)
    Assert-QmTrue -Condition ($bi -ge 0) -Name 'baseline: block B anchor found'
    $blockB = $baseText.Substring($bi).TrimEnd("`r", "`n")
    Assert-QmTrue -Condition ($wdText.Contains($blockB)) -Name 'INVARIANCE: reboot state machine byte-for-byte preserved'

    # The canonical variable lines around the insertion point are untouched.
    Assert-QmTrue -Condition ($wdText.Contains("`$sessionSupervisorStarter = Join-Path `$repoRoot 'tools\strategy_farm\Start_Live_SessionSupervisor.ps1'")) `
        -Name 'INVARIANCE: canonical supervisor-starter var line intact'
    Assert-QmTrue -Condition ($wdText.Contains("`$dxzPath = 'C:\QM\mt5\T_Live\MT5_Base\terminal64.exe'")) `
        -Name 'INVARIANCE: canonical dxzPath var line intact'
} else {
    [void]$script:Failures  # baseline not supplied -> structural checks (5a/5b) still ran
    Write-Warning 'Baseline watchdog not supplied; skipped strong verbatim-block comparison (structural checks still enforced).'
}

# ---------------------------------------------------------------------------
if ($script:Failures.Count -gt 0) {
    $script:Failures | ForEach-Object { Write-Error $_ }
    throw "WS-E1 alarm-state tests FAILED: $($script:Failures.Count) failure(s), $($script:PassCount) pass(es)."
}
Write-Output "WS-E1 alarm-state tests PASS ($($script:PassCount) assertions)."
Write-Output "Fixtures written under: $WorkDir"
