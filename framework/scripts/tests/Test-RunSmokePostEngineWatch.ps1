[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '..\run_smoke.ps1'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if (@($errors).Count) { throw ($errors | Out-String) }
foreach ($name in @('Get-TesterLogTailText', 'Get-TesterPostEngineObservation', 'Update-PostEngineWatchState')) {
    $f = $ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name}, $true)
    if (-not $f) { throw "Missing $name" }
    Invoke-Expression $f.Extent.Text
}
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('qm-post-engine-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    foreach ($encoding in @([Text.Encoding]::Unicode, [Text.UTF8Encoding]::new($true), [Text.UTF8Encoding]::new($false))) {
        $path = Join-Path $tmp ('tail-' + [guid]::NewGuid() + '.log')
        [IO.File]::WriteAllText($path, ('prefix' * 1000000) + "`nold`nfirst`nsecond`n", $encoding)
        $before = (Get-FileHash -LiteralPath $path).Hash
        $value = Get-TesterLogTailText -TesterLogPath $path -LineCount 3 -MaxBytes 1024
        if ($value -notmatch 'first\r?\nsecond' -or $value -match 'prefix') { throw "Bounded tail failed: $value" }
        if ($before -ne (Get-FileHash -LiteralPath $path).Hash) { throw 'Journal modified' }
    }
    $now = [datetime]'2026-09-08T14:00:00Z'
    $obs = [pscustomobject]@{ agent_pid=10; agent_started_at_utc='start'; journal_path='journal';
        journal_bytes=100; journal_mtime_ticks=20; dispatcher_bytes=90; dispatcher_mtime_ticks=30; agent_cpu_seconds=40.0 }
    $state = Update-PostEngineWatchState -Previous $null -Observation $obs -ReportExists $false -NowUtc $now
    if ($state.stalled) { throw 'Immediate false stall' }
    $next = Update-PostEngineWatchState -Previous $state -Observation $obs -ReportExists $false -NowUtc $now.AddSeconds(599)
    if ($next.stalled) { throw 'Grace shortened' }
    $next = Update-PostEngineWatchState -Previous $state -Observation $obs -ReportExists $false -NowUtc $now.AddSeconds(600)
    if (-not $next.stalled) { throw 'No bounded stall after 600s' }
    if ($null -ne (Update-PostEngineWatchState -Previous $state -Observation $obs -ReportExists $true -NowUtc $now.AddSeconds(900))) { throw 'Existing report lost grace' }
    if ($null -ne (Update-PostEngineWatchState -Previous $state -Observation $null -ReportExists $false -NowUtc $now.AddSeconds(900))) { throw 'Missing identity became stall' }
    foreach ($field in @('agent_pid', 'journal_bytes', 'journal_mtime_ticks', 'dispatcher_bytes', 'dispatcher_mtime_ticks', 'agent_cpu_seconds')) {
        $changed = $obs.PSObject.Copy(); $changed.$field += 1
        $next = Update-PostEngineWatchState -Previous $state -Observation $changed -ReportExists $false -NowUtc $now.AddSeconds(900)
        if ($next.stalled -or $next.idle_seconds -ne 0) { throw "Progress not reset: $field" }
    }
    $root = Join-Path $tmp 'T1'
    $agentDir = Join-Path $root 'Tester\Agent-127.0.0.1-3000\logs'
    New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
    $script:fakeRoot = $root
    $script:fakeStart = (Get-Date).AddSeconds(-10)
    function Get-Process { param($Name, $ErrorAction)
        [pscustomobject]@{ Id=10; Path=(Join-Path $script:fakeRoot 'metatester64.exe'); StartTime=$script:fakeStart;
            TotalProcessorTime=[timespan]::FromSeconds(2) }
    }
    $journal = Join-Path $agentDir ((Get-Date).ToString('yyyyMMdd') + '.log')
    $finished = (Get-Date).AddSeconds(-2).ToString('HH:mm:ss.fff')
    $native = "CS`t0`t$finished`tTester`tXAUUSD.DWX,Daily: 100 ticks, 10 bars generated. Test passed in 0:00:00.287.`nCS`t0`t$finished`tTester`ttest Experts\QM\Example.ex5 on XAUUSD.DWX,Daily thread finished`n"
    [IO.File]::WriteAllText($journal, $native, [Text.Encoding]::Unicode)
    $valid = Get-TesterPostEngineObservation -TerminalRoot $root -StartedAfter $script:fakeStart -Expert 'QM\Example' -Symbol XAUUSD.DWX -Period D1
    if ($null -eq $valid -or $valid.agent_pid -ne 10) { throw 'Fresh exact engine not detected' }
    if ($null -ne (Get-TesterPostEngineObservation -TerminalRoot $root -StartedAfter $script:fakeStart -Expert 'QM\Other' -Symbol XAUUSD.DWX -Period D1)) { throw 'Wrong EA accepted' }
    if ($null -ne (Get-TesterPostEngineObservation -TerminalRoot $root -StartedAfter (Get-Date) -Expert 'QM\Example' -Symbol XAUUSD.DWX -Period D1)) { throw 'Old engine accepted' }
    [IO.File]::AppendAllText($journal, "CS`t0`t$finished`tTester`tnew work started`n", [Text.Encoding]::Unicode)
    if ($null -ne (Get-TesterPostEngineObservation -TerminalRoot $root -StartedAfter $script:fakeStart -Expert 'QM\Example' -Symbol XAUUSD.DWX -Period D1)) { throw 'Later work ignored' }
    Write-Host 'PASS Test-RunSmokePostEngineWatch (bounded tails, identity, grace, progress, no report latch)'
} finally {
    $resolved = [IO.Path]::GetFullPath($tmp)
    if (-not $resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $resolved) -notlike 'qm-post-engine-*') { throw 'Unsafe fixture cleanup' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
