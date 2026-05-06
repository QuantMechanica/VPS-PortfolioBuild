param(
    [switch]$EnableSuccess = $true,
    [switch]$EnableFailure
)

$ErrorActionPreference = "Stop"

$subcategories = @("File System", "Handle Manipulation")

foreach ($subcat in $subcategories) {
    if ($EnableSuccess) {
        $out = & auditpol /set /subcategory:"$subcat" /success:enable 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw ("auditpol success-enable failed for '{0}': {1}" -f $subcat, (($out | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine))
        }
    }
    if ($EnableFailure) {
        $out = & auditpol /set /subcategory:"$subcat" /failure:enable 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw ("auditpol failure-enable failed for '{0}': {1}" -f $subcat, (($out | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine))
        }
    }
}

$verify = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "..\monitoring\Test-ObjectAccessAuditPolicy.ps1") -RequireSuccess @(
    if ($EnableFailure) { '-RequireFailure' }
) 2>&1
$verifyCode = $LASTEXITCODE
$verifyText = ($verify | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine

Write-Host $verifyText
if ($verifyCode -ne 0) {
    throw ("Post-set verification failed: exit_code={0}" -f $verifyCode)
}
