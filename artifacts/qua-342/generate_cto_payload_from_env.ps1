param(
    [string]$OutputPath = 'C:\QM\repo\artifacts\qua-342\cto_payload_patch_filled.json'
)

$eaId = $env:EA_ID
$eaName = $env:EA_NAME
$setfile = $env:SETFILE_PATH

if (-not $eaId -or -not $eaName -or -not $setfile) {
    Write-Error 'Missing required env vars: EA_ID, EA_NAME, SETFILE_PATH'
    exit 1
}

$payload = [pscustomobject]@{
    issue = 'QUA-342'
    strategy = 'SRC04_S03'
    action = 'fill_missing_mapping_fields'
    required_updates = [pscustomobject]@{
        ea_id = $eaId
        ea_name = $eaName
        setfile_path = $setfile
    }
    validation_expectation = [pscustomobject]@{
        dispatch_ready = $true
        payload_ready = $true
        missing_fields = @()
    }
    notes = 'Generated from environment variables.'
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath

$validator = 'C:\QM\repo\artifacts\qua-342\validate_cto_mapping_payload.ps1'
if (Test-Path -LiteralPath $validator) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $validator -PayloadPath $OutputPath
    exit $LASTEXITCODE
}

Write-Output "payload.output=$OutputPath"
