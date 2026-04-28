param(
    [string]$ApiBase = "http://127.0.0.1:3100/api",
    [string]$Issue = "QUA-420",
    [string]$RunId = ""
)

if ([string]::IsNullOrWhiteSpace($RunId)) {
    $RunId = $env:PAPERCLIP_RUN_ID
}

$headers = @{ "X-Paperclip-Run-Id" = $RunId; "Content-Type" = "application/json" }

Write-Output "GET issue (expected OK)"
try {
    $get = Invoke-RestMethod -Method Get -Uri "$ApiBase/issues/$Issue" -Headers $headers
    Write-Output ("GET_OK status={0}" -f $get.status)
} catch {
    Write-Output ("GET_FAIL {0}" -f $_.Exception.Message)
}

Write-Output "PATCH issue status (currently failing with 500)"
$patchBody = @{ status = "in_review"; resume = $true; comment = "QUA-420 transition probe" } | ConvertTo-Json
try {
    $patch = Invoke-RestMethod -Method Patch -Uri "$ApiBase/issues/$Issue" -Headers $headers -Body $patchBody
    Write-Output "PATCH_OK"
} catch {
    Write-Output ("PATCH_FAIL {0}" -f $_.Exception.Message)
}

Write-Output "POST issue comment (currently failing with 500)"
$commentBody = @{ comment = "QUA-420 comment probe"; resume = $true } | ConvertTo-Json
try {
    $post = Invoke-RestMethod -Method Post -Uri "$ApiBase/issues/$Issue/comments" -Headers $headers -Body $commentBody
    Write-Output "POST_OK"
} catch {
    Write-Output ("POST_FAIL {0}" -f $_.Exception.Message)
}
