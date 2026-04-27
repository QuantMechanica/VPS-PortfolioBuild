[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$SuiteScript = 'infra\scripts\Test-QUA95OpsSuite.ps1',
    [string]$OutPath = 'docs\ops\QUA-95_OPS_SUITE_2026-04-27.json',
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

$args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $suiteFull)
if ($SkipBlockerTaskHealthCheck) {
    $args += '-SkipBlockerTaskHealthCheck'
}
$json = & powershell @args
$code = $LASTEXITCODE
$json | Set-Content -LiteralPath $outFull -Encoding UTF8

Write-Output ("suite_exit_code={0}" -f $code)
Write-Output ("wrote={0}" -f $outFull)

if ($code -ne 0) {
    exit $code
}
exit 0
