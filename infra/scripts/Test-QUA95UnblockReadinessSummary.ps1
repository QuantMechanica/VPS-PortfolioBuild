[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$ReadinessJsonPath = 'docs\ops\QUA-95_UNBLOCK_READINESS_2026-04-27.json',
    [string]$SummaryMdPath = 'docs\ops\QUA-95_UNBLOCK_READINESS_SUMMARY_2026-04-27.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$jsonFull = Join-Path $RepoRoot $ReadinessJsonPath
$mdFull = Join-Path $RepoRoot $SummaryMdPath

if (-not (Test-Path -LiteralPath $jsonFull)) {
    Write-Host ("status=critical reason=readiness_json_missing path={0}" -f $jsonFull)
    exit 1
}
if (-not (Test-Path -LiteralPath $mdFull)) {
    Write-Host ("status=critical reason=summary_md_missing path={0}" -f $mdFull)
    exit 1
}

$r = Get-Content -Raw -LiteralPath $jsonFull | ConvertFrom-Json
$md = Get-Content -Raw -LiteralPath $mdFull

$issues = @()

$readyText = $r.readiness.ready_to_unblock.ToString().ToLowerInvariant()
$expectedReady = ('`ready_to_unblock`: `{0}`' -f $readyText)
if ($md -notmatch [regex]::Escape($expectedReady)) {
    $issues += 'ready_to_unblock_mismatch'
}

$expectedBars = ('`bars_got`: `{0}`' -f $r.current.bars_got)
if ($md -notmatch [regex]::Escape($expectedBars)) {
    $issues += 'bars_got_mismatch'
}

$expectedTail = ('`tail_shortfall_seconds`: `{0}`' -f $r.current.tail_shortfall_seconds)
if ($md -notmatch [regex]::Escape($expectedTail)) {
    $issues += 'tail_shortfall_mismatch'
}

foreach ($owner in @($r.unblock_owners)) {
    $ownerToken = ('`{0}`' -f $owner.owner)
    if ($md -notmatch [regex]::Escape($ownerToken)) {
        $issues += ("missing_owner_{0}" -f $owner.owner)
    }
}

if ($issues.Count -gt 0) {
    Write-Host ("status=critical issues={0}" -f ($issues -join ','))
    exit 1
}

Write-Host ("status=ok ready_to_unblock={0} bars_got={1}" -f $readyText, $r.current.bars_got)
exit 0
