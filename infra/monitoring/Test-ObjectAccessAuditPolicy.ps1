param(
    [switch]$RequireSuccess,
    [switch]$RequireFailure
)

$ErrorActionPreference = "Stop"

function Get-SubcategoryState {
    param([string]$Subcategory)
    $line = (auditpol /get /subcategory:"$Subcategory" /r) | Select-Object -Skip 1 | Select-Object -First 1
    if (-not $line) {
        return $null
    }
    $parts = $line -split ','
    if ($parts.Count -lt 3) {
        return $null
    }
    return [pscustomobject]@{
        machine_name = $parts[0]
        subcategory = $parts[1]
        setting = $parts[2]
    }
}

$required = @("File System", "Handle Manipulation")
$rows = @()
$issues = @()

foreach ($subcat in $required) {
    $state = Get-SubcategoryState -Subcategory $subcat
    if ($null -eq $state) {
        $issues += "missing_state:$subcat"
        continue
    }
    $rows += $state
    $setting = $state.setting
    $hasSuccess = $setting -match 'Success'
    $hasFailure = $setting -match 'Failure'
    if ($RequireSuccess -and -not $hasSuccess) {
        $issues += "missing_success:$subcat"
    }
    if ($RequireFailure -and -not $hasFailure) {
        $issues += "missing_failure:$subcat"
    }
}

$status = if ($issues.Count -eq 0) { "ok" } else { "critical" }
$result = [ordered]@{
    status = $status
    rows = $rows
    issues = $issues
}

$result | ConvertTo-Json -Depth 6
if ($status -ne "ok") {
    exit 2
}
