[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$EvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_rerun_evidence.json',
    [string]$BlockerPath = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$evidenceFull = Join-Path $RepoRoot $EvidencePath
$blockerFull = Join-Path $RepoRoot $BlockerPath

if (-not (Test-Path -LiteralPath $evidenceFull)) {
    throw "Evidence JSON not found: $evidenceFull"
}
if (-not (Test-Path -LiteralPath $blockerFull)) {
    throw "Blocker JSON not found: $blockerFull"
}

$ev = Get-Content -LiteralPath $evidenceFull -Raw | ConvertFrom-Json
$bl = Get-Content -LiteralPath $blockerFull -Raw | ConvertFrom-Json

if ($null -eq $ev.symbol) {
    throw "Evidence JSON missing symbol payload: $evidenceFull"
}

function Set-OrAddProperty {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] $Value
    )
    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

$bl.current_observed.symbol = $ev.symbol.name
$bl.current_observed.verdict = $ev.symbol.verdict
$bl.current_observed.bars_got = [int]$ev.symbol.bars_got
$bl.current_observed.tail_shortfall_seconds = [double]$ev.symbol.tail_shortfall_seconds
$bl.current_observed.disposition = $ev.disposition
$tailAligned = $false
if ($ev.symbol.PSObject.Properties.Name -contains 'tail_delta_ms' -and $null -ne $ev.symbol.tail_delta_ms) {
    $tailAligned = ([math]::Abs([double]$ev.symbol.tail_delta_ms) -le 1000.0)
} elseif ($null -ne $ev.symbol.tail_ms_expected -and $null -ne $ev.symbol.tail_ms_got) {
    $tailAligned = ($ev.symbol.tail_ms_expected -eq $ev.symbol.tail_ms_got)
}
$bl.acceptance.met = ($ev.symbol.bars_got -gt 0 -and $tailAligned)
if ($bl.acceptance.met -and [string]$ev.disposition -eq 'clear') {
    $bl.recommended_state = 'clear'
    $bl.reason = 'XTIUSD.DWX verifier rerun now meets bars+tail acceptance.'
} else {
    $bl.recommended_state = 'blocked'
    $bl.reason = 'XTIUSD.DWX bars visibility failure persists; verifier rerun remains defer.'
}
Set-OrAddProperty -Object $bl -Name 'last_checked_local' -Value $ev.generated_at_local
Set-OrAddProperty -Object $bl -Name 'last_evidence_path' -Value $EvidencePath
Set-OrAddProperty -Object $bl -Name 'last_verify_exit_code' -Value ([int]$ev.verify_exit_code)

$bl | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $blockerFull -Encoding UTF8
Write-Host ("updated={0}" -f $blockerFull)
