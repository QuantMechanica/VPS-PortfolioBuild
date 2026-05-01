param(
  [string]$RepoRoot = "."
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$blocked = "docs/ops/QUA-621_BLOCKED_ON_CTO_2026-05-01.json"
$manifest = "docs/ops/QUA-621_ARTIFACT_SHA256_2026-05-01.txt"

if (!(Test-Path $blocked)) { throw "Missing $blocked" }
if (!(Test-Path $manifest)) { throw "Missing $manifest" }

$j = Get-Content $blocked -Raw | ConvertFrom-Json
if ($j.review_range -ne "847dabad^..HEAD") { throw "review_range mismatch: $($j.review_range)" }
if ($j.head -ne "HEAD") { throw "head must be HEAD" }
if ($j.review_range_count -ne "DYNAMIC") { throw "review_range_count must be DYNAMIC" }
if ($j.review_range_count_cmd -ne "git rev-list --count 847dabad^..HEAD") { throw "review_range_count_cmd mismatch" }

$hash = (Get-FileHash $blocked -Algorithm SHA256).Hash
$line = Select-String -Path $manifest -Pattern "QUA-621_BLOCKED_ON_CTO_2026-05-01.json$" | Select-Object -First 1
if (!$line) { throw "Blocked JSON missing from manifest" }
if ($line.Line.Split(' ')[0] -ne $hash) { throw "Manifest hash mismatch for blocked JSON" }

$count = git rev-list --count 847dabad^..HEAD
$head = git rev-parse --short HEAD

Write-Output "QUA621_BLOCKED_VALIDATE=PASS"
Write-Output "HEAD=$head"
Write-Output "COUNT(847dabad^..HEAD)=$count"
