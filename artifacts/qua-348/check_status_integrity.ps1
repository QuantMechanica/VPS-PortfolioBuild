$source = "C:\QM\repo\docs\ops\QUA-348_ISSUE_STATUS_UPDATE_2026-04-28.json"
$mirror = "C:\QM\repo\artifacts\qua-348\latest_status.json"
$out = "C:\QM\repo\artifacts\qua-348\status_integrity_latest.json"

$srcExists = Test-Path -LiteralPath $source
$mirExists = Test-Path -LiteralPath $mirror
$equal = $false

if($srcExists -and $mirExists) {
  $srcHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash
  $mirHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $mirror).Hash
  $equal = ($srcHash -eq $mirHash)
} else {
  $srcHash = $null
  $mirHash = $null
}

$result = [ordered]@{
  issue = "QUA-348"
  checked_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  source_path = $source
  mirror_path = $mirror
  source_exists = $srcExists
  mirror_exists = $mirExists
  source_sha256 = $srcHash
  mirror_sha256 = $mirHash
  in_sync = $equal
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $out
if($equal) { Write-Output "SYNC_OK" } else { Write-Output "SYNC_MISMATCH" }
