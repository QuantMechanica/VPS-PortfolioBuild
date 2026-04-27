[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$Target = 'XTIUSD.DWX',
    [string]$ProbeScript = 'C:\QM\repo\infra\scripts\probe_custom_symbol_visibility.py',
    [string]$OutEvidenceJson = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json',
    [string]$OutProofMd = 'docs\ops\QUA-95_CUSTOM_VISIBILITY_RERUN_2026-04-27.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ProbeScript)) {
    throw "Probe script not found: $ProbeScript"
}

$evidenceFull = Join-Path $RepoRoot $OutEvidenceJson
$proofFull = Join-Path $RepoRoot $OutProofMd

New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFull) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $proofFull) -Force | Out-Null

$probeOut = & python $ProbeScript --target $Target --json-out $evidenceFull 2>&1
$probeCode = $LASTEXITCODE
$outLines = @($probeOut | ForEach-Object { $_.ToString() })
$outLines | Write-Output

if (-not (Test-Path -LiteralPath $evidenceFull)) {
    throw "Expected probe evidence missing: $evidenceFull"
}

$evidence = Get-Content -LiteralPath $evidenceFull -Raw | ConvertFrom-Json
$capturedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
$evidence | Add-Member -NotePropertyName issue -NotePropertyValue 'QUA-95' -Force
$evidence | Add-Member -NotePropertyName captured_at_local -NotePropertyValue $capturedAt -Force
$evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $evidenceFull -Encoding UTF8

$isolatedFailure = [bool]$evidence.isolated_custom_bars_visibility_failure
$targetRange = [int]$evidence.target_probe.rates_range_m1_count
$targetPos = [int]$evidence.target_probe.rates_from_pos_m1_count
$targetTicks = [int]$evidence.target_probe.ticks_from_count
$sourceRange = [int]$evidence.source_probe.rates_range_m1_count
$sourcePos = [int]$evidence.source_probe.rates_from_pos_m1_count
$sourceTicks = [int]$evidence.source_probe.ticks_from_count

$proofLines = @(
    '# QUA-95 Custom Visibility Probe Rerun (2026-04-27)',
    '',
    'Issue: QUA-95  ',
    ("Target: {0}" -f $Target),
    '',
    '## Command',
    '',
    '```powershell',
    ("python {0} --target {1} --json-out {2}" -f $ProbeScript, $Target, $evidenceFull),
    '```',
    '',
    '## Result',
    '',
    ("- probe exit code: {0}" -f $probeCode),
    ("- isolated custom bars visibility failure: {0}" -f $isolatedFailure),
    ("- target bars (range/pos): {0}/{1}" -f $targetRange, $targetPos),
    ("- source bars (range/pos): {0}/{1}" -f $sourceRange, $sourcePos),
    ("- target ticks: {0}" -f $targetTicks),
    ("- source ticks: {0}" -f $sourceTicks),
    ("- evidence json: {0}" -f $evidenceFull),
    ("- captured at: {0}" -f $capturedAt),
    '',
    '## Disposition',
    '',
    ("Acceptance remains {0}; state stays blocked/defer." -f $(if ($isolatedFailure) { 'unmet' } else { 'under review' }))
)

$proofLines | Set-Content -LiteralPath $proofFull -Encoding UTF8

Write-Output ("probe_exit_code={0}" -f $probeCode)
Write-Output ("isolated_custom_bars_visibility_failure={0}" -f $isolatedFailure)
Write-Output ("wrote={0}" -f $evidenceFull)
Write-Output ("wrote={0}" -f $proofFull)
exit 0
