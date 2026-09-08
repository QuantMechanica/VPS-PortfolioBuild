<#
One-shot, OWNER-authorized recovery of a proven missing-report tester stall.
Uses the runner's normal exit/report-missing path. No DB/claim/verdict writes.
Default is diagnostic only; execution requires exact terminal PID + work item.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^T([1-9]|10)$')][string]$Terminal,
    [Parameter(Mandatory)][int]$ExpectedPid,
    [Parameter(Mandatory)][guid]$WorkItemId,
    [switch]$Execute
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scriptPath = Join-Path $repo 'framework\scripts\run_smoke.ps1'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
if (@($errors).Count) { throw ($errors | Out-String) }
foreach ($name in @('Get-FileEvidenceIdentity','Get-TesterIniEvidence','Get-TesterLogTailText','Get-TesterPostEngineObservation','Update-PostEngineWatchState')) {
    $f = $ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name}, $true)
    if (-not $f) { throw "Missing $name" }
    Invoke-Expression $f.Extent.Text
}
$root = "D:\QM\mt5\$Terminal"
$proc = Get-Process -Id $ExpectedPid -ErrorAction Stop
if ($proc.Path -ine "$root\terminal64.exe") { throw 'Exact terminal path mismatch' }
$created = $proc.StartTime
$native = Get-CimInstance Win32_Process -Filter "ProcessId=$ExpectedPid"
if ($native.CommandLine -notmatch '/config:(?:"(?<quoted>[^"]+)"|(?<bare>[^\s]+))') { throw 'No exact tester config' }
$ini = if ($Matches['quoted']) { $Matches['quoted'] } else { $Matches['bare'] }
$workroot = "D:\QM\reports\work_items\$WorkItemId\"
if (-not [IO.Path]::GetFullPath($ini).StartsWith($workroot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Work item/config mismatch' }
function Assert-Claim {
    $query = "import sqlite3,sys; c=sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro',uri=True); r=c.execute('select status,claimed_by from work_items where id=?',(sys.argv[1],)).fetchone(); sys.exit(0 if r==('active',sys.argv[2]) else 1)"
    & python -c $query $WorkItemId.ToString() $Terminal
    if ($LASTEXITCODE -ne 0) { throw 'Claim no longer belongs to this terminal' }
}
Assert-Claim
$identity = Get-TesterIniEvidence -Path $ini
$params = @{}
Get-Content -LiteralPath $ini | ForEach-Object { if ($_ -match '^([^=]+)=(.*)$') { $params[$Matches[1]]=$Matches[2] } }
if ($params['Model'] -ne '4' -or $params['Optimization'] -ne '0' -or $params['ShutdownTerminal'] -ne '1') { throw 'Not the expected single real-tick tester run' }
$report = $params['Report']
if (-not [IO.Path]::IsPathRooted($report)) { $report = Join-Path $root $report }
if (Test-Path -LiteralPath $report) { throw 'Report exists; do not interfere with export' }
$first = Get-TesterPostEngineObservation -TerminalRoot $root -StartedAfter $created -Expert $identity.expert -Symbol $identity.symbol -Period $identity.period
if (-not $first) { throw 'No current exact-engine completion proof' }
$age = ((Get-Date) - [datetime]$first.engine_finished_at_local).TotalSeconds
if ($age -lt 600) { throw 'Engine has not waited ten minutes' }
$firstTime = (Get-Date).ToUniversalTime()
$state = Update-PostEngineWatchState -Previous $null -Observation $first -ReportExists $false -NowUtc $firstTime
Start-Sleep -Seconds 15
$second = Get-TesterPostEngineObservation -TerminalRoot $root -StartedAfter $created -Expert $identity.expert -Symbol $identity.symbol -Period $identity.period
$state = Update-PostEngineWatchState -Previous $state -Observation $second -ReportExists (Test-Path -LiteralPath $report) -NowUtc ((Get-Date).ToUniversalTime())
if (-not $state -or $state.idle_seconds -lt 14) { throw 'Progress or changed identity; recovery refused' }
$evidenceDir = 'D:\QM\reports\maintenance\backtest_latency_20260908'
New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
$evidencePath = Join-Path $evidenceDir ("recovery_{0}_{1}.json" -f $Terminal,(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss'))
$evidence = [ordered]@{ schema='qm.post-engine-recovery/v1'; owner_authority='2026-09-08 user: monitor factory tightly and use test terminals for faster equal-quality backtests';
    terminal=$Terminal; work_item_id=$WorkItemId.ToString(); terminal_pid=$ExpectedPid; terminal_started_at=$created.ToString('o');
    ini=$identity; report_path=$report; report_exists=$false; engine_wait_seconds=$age;
    first=$first; second=$second; execute_requested=[bool]$Execute; action='diagnostic only';
    no_verdict_or_claim_write=$true; original_journals_preserved=$true }
$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
if ($Execute) {
    Assert-Claim
    $current = Get-Process -Id $ExpectedPid -ErrorAction Stop
    $agent = Get-Process -Id $second.agent_pid -ErrorAction Stop
    if ($current.Path -ine "$root\terminal64.exe" -or $current.StartTime -ne $created -or
        $agent.Path -ine "$root\metatester64.exe" -or
        $agent.StartTime.ToUniversalTime().ToString('o') -cne $second.agent_started_at_utc -or
        (Test-Path -LiteralPath $report)) { throw 'Final identity/report fence failed' }
    Stop-Process -InputObject $current -Force -ErrorAction Stop
    Stop-Process -InputObject $agent -Force -ErrorAction Stop
    $evidence.action = 'stopped exact stalled tester pair; existing runner owns INFRA disposition/retry'
    $evidence['action_at_utc'] = (Get-Date).ToUniversalTime().ToString('o')
    $evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
}
[pscustomobject]@{terminal=$Terminal; work_item_id=$WorkItemId; action=$evidence.action; evidence=$evidencePath; engine_wait_seconds=$age} | ConvertTo-Json
