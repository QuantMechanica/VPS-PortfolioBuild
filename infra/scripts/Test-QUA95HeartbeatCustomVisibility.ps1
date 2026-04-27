[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$HeartbeatPath = 'docs\ops\QUA-95_BLOCKED_HEARTBEAT_2026-04-27.json',
    [string]$CustomVisibilityEvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host $Message
    exit 1
}

$heartbeatFull = Join-Path $RepoRoot $HeartbeatPath
$evidenceFull = Join-Path $RepoRoot $CustomVisibilityEvidencePath

foreach ($path in @($heartbeatFull, $evidenceFull)) {
    if (-not (Test-Path -LiteralPath $path)) {
        Fail ("missing_file=" + $path)
    }
}

$hb = Get-Content -LiteralPath $heartbeatFull -Raw | ConvertFrom-Json
$evidence = Get-Content -LiteralPath $evidenceFull -Raw | ConvertFrom-Json

if ([string]$hb.issue -ne 'QUA-95') { Fail 'heartbeat_issue_mismatch' }
if ($null -eq $hb.custom_visibility) { Fail 'heartbeat_custom_visibility_missing' }
if ([string]$evidence.target -ne 'XTIUSD.DWX') { Fail 'evidence_target_mismatch' }

if ([bool]$hb.custom_visibility.isolated_custom_bars_visibility_failure -ne [bool]$evidence.isolated_custom_bars_visibility_failure) {
    Fail 'custom_visibility_flag_mismatch'
}
if ([int]$hb.custom_visibility.target_bars_range_m1 -ne [int]$evidence.target_probe.rates_range_m1_count) {
    Fail 'custom_visibility_target_range_mismatch'
}
if ([int]$hb.custom_visibility.target_bars_from_pos_m1 -ne [int]$evidence.target_probe.rates_from_pos_m1_count) {
    Fail 'custom_visibility_target_pos_mismatch'
}
if ([int]$hb.custom_visibility.source_bars_range_m1 -ne [int]$evidence.source_probe.rates_range_m1_count) {
    Fail 'custom_visibility_source_range_mismatch'
}
if ([int]$hb.custom_visibility.source_bars_from_pos_m1 -ne [int]$evidence.source_probe.rates_from_pos_m1_count) {
    Fail 'custom_visibility_source_pos_mismatch'
}

Write-Host ("status=ok isolated_custom_failure={0} target_bars={1}/{2} source_bars={3}/{4}" -f `
    $evidence.isolated_custom_bars_visibility_failure, `
    $evidence.target_probe.rates_range_m1_count, `
    $evidence.target_probe.rates_from_pos_m1_count, `
    $evidence.source_probe.rates_range_m1_count, `
    $evidence.source_probe.rates_from_pos_m1_count)
exit 0
