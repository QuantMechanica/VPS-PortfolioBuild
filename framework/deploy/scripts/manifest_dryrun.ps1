[CmdletBinding()]
param(
    [string]$ManifestPath = "C:\QM\repo\framework\deploy\manifests\T6_DRYRUN_v0.yaml"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Manifest not found: $ManifestPath"
}

$lines = Get-Content -LiteralPath $ManifestPath
$kv = @{}
$placement = [ordered]@{}
$inPlacement = $false

foreach ($line in $lines) {
    if ($line -match '^\s*-\s*ea_id:\s*(.+)$') {
        $inPlacement = $true
        $placement['ea_id'] = $Matches[1].Trim()
        continue
    }
    if ($line -match '^\s*([a-z_]+):\s*(.+?)\s*$') {
        $k = $Matches[1].Trim()
        $v = $Matches[2].Trim()
        if ($v -eq 'null') { $v = $null }
        if ($inPlacement -and $line -match '^\s{4,}') { $placement[$k] = $v } else { $kv[$k] = $v }
    }
}

$errors = @()
foreach ($req in @('manifest_id','environment','terminal','approved_by')) {
    if (-not $kv.ContainsKey($req) -or [string]::IsNullOrWhiteSpace([string]$kv[$req])) { $errors += "missing:$req" }
}
foreach ($req in @('ea_id','ea_file','symbol','timeframe','setfile','magic','risk_percent','source_card')) {
    if (-not $placement.Contains($req) -or [string]::IsNullOrWhiteSpace([string]$placement[$req])) { $errors += "missing_placement:$req" }
}
if (($kv['terminal']) -ne 'T6') { $errors += "invalid_terminal:$($kv['terminal'])" }
if (($kv['approved_by']) -ne 'OWNER') { $errors += "invalid_approved_by:$($kv['approved_by'])" }
if (($kv['environment']) -notin @('live_burn_in','live_full')) { $errors += "invalid_environment:$($kv['environment'])" }

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Output "validation_error=$_" }
    Write-Output 'manifest_parse_result=FAIL'
    exit 1
}

Write-Output "manifest_path=$ManifestPath"
Write-Output "manifest_id=$($kv['manifest_id'])"
Write-Output "environment=$($kv['environment'])"
Write-Output "terminal=$($kv['terminal'])"
Write-Output "placement_ea_id=$($placement['ea_id'])"
Write-Output "placement_symbol=$($placement['symbol'])"
Write-Output "placement_timeframe=$($placement['timeframe'])"
Write-Output "dryrun_action=WOULD_COPY_EA:$($placement['ea_file'])"
Write-Output "dryrun_action=WOULD_APPLY_SETFILE:$($placement['setfile'])"
Write-Output "dryrun_action=WOULD_ATTACH_ON_T6_CHART:$($placement['symbol'])/$($placement['timeframe'])"
Write-Output 'manifest_parse_result=PASS'
Write-Output 'dryrun_write_guard=EXITING_BEFORE_ANY_MT5_WRITE'
exit 0
