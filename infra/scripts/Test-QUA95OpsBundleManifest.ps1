[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$ManifestPath = 'docs\ops\QUA-95_OPS_BUNDLE_2026-04-27.sha256'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$manifestFull = Join-Path $RepoRoot $ManifestPath
if (-not (Test-Path -LiteralPath $manifestFull)) {
    throw "Manifest not found: $manifestFull"
}

$lines = Get-Content -LiteralPath $manifestFull
if ($lines.Count -eq 0) {
    throw "Manifest is empty: $manifestFull"
}

$allOk = $true
foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        continue
    }

    $m = [regex]::Match($trimmed, '^(?<hash>[0-9a-f]{64})\s{2}(?<path>.+)$')
    if (-not $m.Success) {
        Write-Host "invalid_manifest_line=$trimmed"
        $allOk = $false
        continue
    }

    $expected = $m.Groups['hash'].Value.ToLowerInvariant()
    $relPath = $m.Groups['path'].Value
    $fullPath = Join-Path $RepoRoot $relPath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        Write-Host "missing_file=$relPath"
        $allOk = $false
        continue
    }

    $actual = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $ok = ($actual -eq $expected)
    Write-Host ("file={0} ok={1}" -f $relPath, $ok)
    if (-not $ok) {
        Write-Host ("expected={0}" -f $expected)
        Write-Host ("actual={0}" -f $actual)
        $allOk = $false
    }
}

if (-not $allOk) {
    exit 1
}
Write-Host "status=ok"
exit 0
