[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$SuiteScript = 'infra\scripts\Test-QUA95OpsSuite.ps1',
    [string]$OutPath = 'docs\ops\QUA-95_OPS_SUITE_2026-04-27.json',
    [string]$ManifestUpdateScript = 'infra\scripts\Update-QUA95OpsBundleManifest.ps1',
    [switch]$SkipManifestResync,
    [switch]$SkipBlockerTaskHealthCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$suiteFull = Join-Path $RepoRoot $SuiteScript
if (-not (Test-Path -LiteralPath $suiteFull)) {
    throw "Suite script missing: $suiteFull"
}

$outFull = Join-Path $RepoRoot $OutPath
$outDir = Split-Path -Parent $outFull
if ($outDir) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

if (-not $SkipManifestResync) {
    $manifestUpdateFull = Join-Path $RepoRoot $ManifestUpdateScript
    if (-not (Test-Path -LiteralPath $manifestUpdateFull)) {
        throw "Manifest update script missing: $manifestUpdateFull"
    }
    $manifestPreOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $manifestUpdateFull 2>&1
    $manifestPreCode = $LASTEXITCODE
    ($manifestPreOut | ForEach-Object { $_.ToString() }) | Write-Output
    if ($manifestPreCode -ne 0) {
        throw ("Manifest pre-resync failed: exit_code={0}" -f $manifestPreCode)
    }
}

$args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $suiteFull)
if ($SkipBlockerTaskHealthCheck) {
    $args += '-SkipBlockerTaskHealthCheck'
}
$json = & powershell @args
$code = $LASTEXITCODE
$json | Set-Content -LiteralPath $outFull -Encoding UTF8

if (-not $SkipManifestResync) {
    $manifestPostOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $manifestUpdateFull 2>&1
    $manifestPostCode = $LASTEXITCODE
    ($manifestPostOut | ForEach-Object { $_.ToString() }) | Write-Output
    if ($manifestPostCode -ne 0) {
        throw ("Manifest post-resync failed: exit_code={0}" -f $manifestPostCode)
    }
}

Write-Output ("suite_exit_code={0}" -f $code)
Write-Output ("wrote={0}" -f $outFull)

if ($code -ne 0) {
    exit $code
}
exit 0
