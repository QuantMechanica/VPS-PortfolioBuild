[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$EvidencePath = 'lessons-learned\evidence\2026-04-27_qua93_xauusd_rerun_evidence.json',
    [string]$BlockerPath = 'docs\ops\QUA-93_XAUUSD_BLOCKER_STATUS_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$evidenceFull = Join-Path $RepoRoot $EvidencePath
$blockerFull = Join-Path $RepoRoot $BlockerPath

if (-not (Test-Path -LiteralPath $evidenceFull)) {
    throw "Evidence JSON not found: $evidenceFull"
}

$ev = Get-Content -LiteralPath $evidenceFull -Raw | ConvertFrom-Json
if ($null -eq $ev.symbol) {
    throw "Evidence JSON missing symbol payload: $evidenceFull"
}

if (-not (Test-Path -LiteralPath $blockerFull)) {
    $dir = Split-Path -Parent $blockerFull
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $seed = [ordered]@{
        issue = 'QUA-93'
        parent_issue = 'QUA-19'
        symbol = 'XAUUSD.DWX'
        recommended_state = 'blocked'
        blocker_reason = 'Acceptance unmet: verifier still returns zero bars and missing tail for XAUUSD.DWX.'
        acceptance = [ordered]@{
            criterion = 'Re-run verifier for XAUUSD.DWX with non-zero bars and matching tail'
            met = $false
        }
        current_observed = [ordered]@{
            symbol = 'XAUUSD.DWX'
            verdict = 'unknown'
            bars_got = 0
            tail_shortfall_seconds = 0.0
            disposition = 'unknown'
        }
        unblock_owners = @(
            [ordered]@{
                owner = 'Verifier/import owner (D:\QM\mt5\T1\dwx_import\verify_import.py + XAU export pipeline)'
                required_action = 'Refresh aligned XAU tick/M1 exports, rebuild XAUUSD.DWX custom history + sidecars, rerun verifier'
            }
        )
        handoff_artifacts = [ordered]@{
            investigation_markdown = 'lessons-learned/2026-04-27_qua93_xauusd_verifier_failure_investigation.md'
            rerun_evidence_json = $EvidencePath
            csv_tail_alignment_json = 'lessons-learned/evidence/2026-04-27_qua93_xauusd_tail_alignment_check.json'
            csv_mismatch_nudge_json = 'lessons-learned/evidence/2026-04-27_qua93_csv_tail_mismatch_nudge_validation.json'
        }
    }
    $seed | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $blockerFull -Encoding UTF8
}

$bl = Get-Content -LiteralPath $blockerFull -Raw | ConvertFrom-Json

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
$bl.acceptance.met = ($ev.symbol.bars_got -gt 0 -and ($ev.symbol.tail_ms_expected -eq $ev.symbol.tail_ms_got))

Set-OrAddProperty -Object $bl -Name 'last_checked_local' -Value $ev.generated_at_local
Set-OrAddProperty -Object $bl -Name 'last_evidence_path' -Value $EvidencePath
Set-OrAddProperty -Object $bl -Name 'last_verify_exit_code' -Value ([int]$ev.verify_exit_code)
Set-OrAddProperty -Object $bl -Name 'recommended_state' -Value ($(if ($bl.acceptance.met) { 'ready' } else { 'blocked' }))

$bl | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $blockerFull -Encoding UTF8
Write-Host ("updated={0}" -f $blockerFull)
