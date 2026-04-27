[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$ReadinessPath = 'docs\ops\QUA-95_UNBLOCK_READINESS_2026-04-27.json',
    [string]$OutPath = 'docs\ops\QUA-95_UNBLOCK_READINESS_SUMMARY_2026-04-27.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$readinessFull = Join-Path $RepoRoot $ReadinessPath
$outFull = Join-Path $RepoRoot $OutPath

if (-not (Test-Path -LiteralPath $readinessFull)) {
    throw "Readiness artifact missing: $readinessFull"
}

$r = Get-Content -Raw -LiteralPath $readinessFull | ConvertFrom-Json

$lines = @()
$lines += '# QUA-95 Unblock Readiness Summary (2026-04-27)'
$lines += ''
$lines += ('Issue: `{0}`' -f $r.issue)
$lines += ('Generated: `{0}`' -f $r.generated_at_local)
$lines += ''
$lines += '## Status'
$lines += ''
$lines += ('- `ready_to_unblock`: `{0}`' -f $r.readiness.ready_to_unblock.ToString().ToLowerInvariant())
$lines += ('- `recommended_state`: `{0}`' -f $r.current.recommended_state)
$lines += ('- `disposition`: `{0}`' -f $r.current.disposition)
$lines += ('- `bars_got`: `{0}`' -f $r.current.bars_got)
$lines += ('- `tail_shortfall_seconds`: `{0}`' -f $r.current.tail_shortfall_seconds)
$lines += ''
$lines += '## Unmet Criteria'
$lines += ''
if (@($r.readiness.unmet_criteria).Count -eq 0) {
    $lines += '- none'
}
else {
    foreach ($item in @($r.readiness.unmet_criteria)) {
        $lines += ('- `{0}`' -f $item)
    }
}
$lines += ''
$lines += '## Unblock Owners'
$lines += ''
foreach ($owner in @($r.unblock_owners)) {
    $lines += ('- `{0}`: {1}' -f $owner.owner, $owner.required_action)
}

$outDir = Split-Path -Parent $outFull
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$lines -join [Environment]::NewLine | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Output ("wrote={0}" -f $outFull)
exit 0
