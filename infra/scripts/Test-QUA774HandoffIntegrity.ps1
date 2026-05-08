param(
    [string]$ManifestPath = 'docs\ops\QUA-774_BLOCKED_PACKAGE_2026-05-08.sha256'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$manifestFull = Join-Path $repoRoot $ManifestPath

if (-not (Test-Path -LiteralPath $manifestFull -PathType Leaf)) {
    Write-Host ("status=critical reason=missing_manifest path={0}" -f $manifestFull)
    exit 2
}

$lines = Get-Content -LiteralPath $manifestFull -Encoding UTF8 | Where-Object { $_.Trim() -ne '' }
$checked = 0
$failed = 0

foreach ($line in $lines) {
    $parts = $line -split '\s+', 2
    if ($parts.Count -lt 2) {
        Write-Host ("status=critical reason=malformed_row row={0}" -f $line)
        $failed++
        continue
    }

    $expected = $parts[0].Trim().ToLowerInvariant()
    $relativePath = $parts[1].Trim()
    $fullPath = Join-Path $repoRoot $relativePath

    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        Write-Host ("status=critical reason=missing_file path={0}" -f $relativePath)
        $failed++
        continue
    }

    $actual = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        Write-Host ("status=critical reason=hash_mismatch path={0}" -f $relativePath)
        $failed++
        continue
    }

    Write-Host ("status=ok path={0}" -f $relativePath)
    $checked++
}

if ($failed -gt 0) {
    Write-Host ("summary=fail checked={0} failed={1}" -f $checked, $failed)
    exit 2
}

Write-Host ("summary=ok checked={0} failed={1}" -f $checked, $failed)
exit 0
