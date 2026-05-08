param(
    [string]$ZipPath = "C:\QM\repo\artifacts\QUA-743_signoff_bundle_2026-05-05.zip",
    [string]$ShaPath = "C:\QM\repo\artifacts\QUA-743_signoff_bundle_2026-05-05.sha256"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
    throw "Missing zip: $ZipPath"
}
if (-not (Test-Path -LiteralPath $ShaPath -PathType Leaf)) {
    throw "Missing sha file: $ShaPath"
}

$expectedLine = (Get-Content -LiteralPath $ShaPath -Raw).Trim()
$expectedHash = ($expectedLine -split '\s+')[0].ToLower()
$actualHash = (Get-FileHash -Algorithm SHA256 -Path $ZipPath).Hash.ToLower()

if ($actualHash -ne $expectedHash) {
    Write-Output "status=FAIL"
    Write-Output "expected=$expectedHash"
    Write-Output "actual=$actualHash"
    exit 1
}

Write-Output "status=PASS"
Write-Output "sha256=$actualHash"
