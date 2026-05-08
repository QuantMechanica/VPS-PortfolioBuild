[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$artifactDir = Join-Path $RepoRoot "artifacts\qua-913"
$required = @(
    "qua913_qm_token_monitor_sample_2026-05-08.json",
    "qua913_qm_token_monitor_sample_2026-05-08.md",
    "qua913_qm_token_monitor_sample_state_2026-05-08.json",
    "qua913_done_candidate_status_2026-05-08.json",
    "qua913_issue_status_update_payload_2026-05-08.json",
    "qua913_artifact_manifest_2026-05-08.sha256",
    "QUA-913_READY_TO_CLOSE_2026-05-08.flag"
)

if (-not (Test-Path -LiteralPath $artifactDir -PathType Container)) {
    throw "Missing artifact directory: $artifactDir"
}

foreach ($name in $required) {
    $path = Join-Path $artifactDir $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required artifact: $path"
    }
}

$payloadPath = Join-Path $artifactDir "qua913_issue_status_update_payload_2026-05-08.json"
$payload = Get-Content -Raw -LiteralPath $payloadPath | ConvertFrom-Json
if ($payload.issue -ne "QUA-913") { throw "Payload issue mismatch." }
if ($payload.target_status -ne "done") { throw "Payload target_status mismatch." }

$donePath = Join-Path $artifactDir "qua913_done_candidate_status_2026-05-08.json"
$done = Get-Content -Raw -LiteralPath $donePath | ConvertFrom-Json
if ($done.issue -ne "QUA-913") { throw "Done-candidate issue mismatch." }
if ($done.status -ne "done_candidate") { throw "Done-candidate status mismatch." }

$manifestPath = Join-Path $artifactDir "qua913_artifact_manifest_2026-05-08.sha256"
$manifestLines = Get-Content -LiteralPath $manifestPath
if (@($manifestLines).Count -lt 3) { throw "Manifest unexpectedly short." }

Write-Host "PASS Test-QUA913ArtifactBundle"

