param(
  [Parameter(Mandatory=$true)] [string]$ApiBase,
  [Parameter(Mandatory=$true)] [string]$ProjectId,
  [Parameter(Mandatory=$true)] [string]$ParentIssueId,
  [Parameter(Mandatory=$true)] [string]$BearerToken
)

$ErrorActionPreference = 'Stop'
$payloadDir = Join-Path $PSScriptRoot 'QUA-344_CHILD_ISSUE_PAYLOADS'
$files = @(
  '01_bind_strategy_identity.json',
  '02_compile_binding.json',
  '03_dispatch_baseline_binding.json',
  '04_first_executable_run.json'
)

$headers = @{ Authorization = "Bearer $BearerToken"; 'Content-Type' = 'application/json' }

foreach ($f in $files) {
  $p = Join-Path $payloadDir $f
  if (-not (Test-Path $p)) { throw "Missing payload: $p" }

  $obj = Get-Content $p -Raw | ConvertFrom-Json
  $body = [ordered]@{
    title = $obj.title
    body = $obj.body
    priority = $obj.priority
    parent_issue_id = $ParentIssueId
    labels = @('QUA-344','unblock')
  } | ConvertTo-Json -Depth 8

  $url = "$ApiBase/api/projects/$ProjectId/issues"
  Write-Host "POST $url :: $($obj.title)"
  try {
    $resp = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $body
    if ($resp.id) {
      Write-Host "Created child issue: $($resp.id)"
    } else {
      Write-Host "Created child issue response received (no id field)."
    }
  }
  catch {
    Write-Host "Failed creating from $f"
    throw
  }
}
