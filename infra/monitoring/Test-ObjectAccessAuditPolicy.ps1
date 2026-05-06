param(
    [switch]$RequireSuccess,
    [switch]$RequireFailure
)

$ErrorActionPreference = "Stop"

function Get-SubcategoryState {
    param([string]$Subcategory)
    $raw = (auditpol /get /subcategory:"$Subcategory" /r | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }
    $csv = $raw | ConvertFrom-Csv
    if (-not $csv) {
        return $null
    }
    $row = @($csv)[0]
    $setting = $row.'Inclusion Setting'
    if ([string]::IsNullOrWhiteSpace($setting)) {
        $setting = $row.Setting
    }
    return [pscustomobject]@{
        machine_name = $row.'Machine Name'
        subcategory = $row.Subcategory
        setting = $setting
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
