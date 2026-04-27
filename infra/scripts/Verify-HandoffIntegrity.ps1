param(
    [string]$ManifestPath = 'C:\QM\repo\docs\ops\QUA-91_WS30_VERIFIER_HANDOFF_2026-04-27.sha256'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}

$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ManifestPath))
$lines = Get-Content -LiteralPath $ManifestPath | Where-Object { $_.Trim() -ne '' }

$checked = 0
$failed = 0

foreach ($line in $lines) {
    if ($line -notmatch '^(?<hash>[0-9a-f]{64})\s{2}(?<path>.+)$') {
        Write-Host "[WARN] skipped malformed line: $line"
        continue
    }

    $expected = $Matches['hash']
    $relPath = $Matches['path']
    $fullPath = Join-Path $root $relPath

    if (-not (Test-Path -LiteralPath $fullPath)) {
        Write-Host "[FAIL] missing: $relPath"
        $failed++
        continue
    }

    $actual = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLower()
    if ($actual -eq $expected) {
        Write-Host "[OK] $relPath"
    } else {
        Write-Host "[FAIL] $relPath"
        Write-Host "       expected=$expected"
        Write-Host "       actual  =$actual"
        $failed++
    }
    $checked++
}

Write-Host "checked=$checked failed=$failed"
if ($failed -gt 0) { exit 1 }
exit 0
