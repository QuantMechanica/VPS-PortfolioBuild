param(
    [string]$PayloadPath = 'C:\QM\repo\artifacts\qua-342\cto_payload_patch_template.json'
)

if (-not (Test-Path -LiteralPath $PayloadPath)) {
    Write-Error "Payload not found: $PayloadPath"
    exit 1
}

$payload = Get-Content -LiteralPath $PayloadPath -Raw | ConvertFrom-Json
$req = $payload.required_updates
$errors = @()

if (-not $req.ea_id -or $req.ea_id -match '^<.*>$') { $errors += 'ea_id missing or placeholder' }
if (-not $req.ea_name -or $req.ea_name -match '^<.*>$') { $errors += 'ea_name missing or placeholder' }
if (-not $req.setfile_path -or $req.setfile_path -match '^<.*>$') { $errors += 'setfile_path missing or placeholder' }

if ($req.setfile_path -and -not ($req.setfile_path -match '^<.*>$')) {
    $resolved = $req.setfile_path
    if (-not (Test-Path -LiteralPath $resolved)) {
        $errors += "setfile_path does not exist: $resolved"
    }
}

$result = [pscustomobject]@{
    payload_path = $PayloadPath
    valid = ($errors.Count -eq 0)
    errors = $errors
}

$result | ConvertTo-Json -Depth 4
if ($errors.Count -gt 0) { exit 2 }
