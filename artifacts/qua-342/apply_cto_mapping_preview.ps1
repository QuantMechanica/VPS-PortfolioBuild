param(
    [string]$MappingPath = 'C:\QM\repo\artifacts\qua-342\cto_payload_patch_template.json',
    [string]$TargetPayloadPath = 'C:\QM\repo\artifacts\qua-342\src04_s03_cto_payload_proposal_2026-04-28T085344Z.json'
)

if (-not (Test-Path -LiteralPath $MappingPath)) { Write-Error "Mapping file not found: $MappingPath"; exit 1 }
if (-not (Test-Path -LiteralPath $TargetPayloadPath)) { Write-Error "Target payload not found: $TargetPayloadPath"; exit 1 }

$mapping = Get-Content -LiteralPath $MappingPath -Raw | ConvertFrom-Json
$target = Get-Content -LiteralPath $TargetPayloadPath -Raw | ConvertFrom-Json
$req = $mapping.required_updates

$errors = @()
if (-not $req.ea_id -or $req.ea_id -match '^<.*>$') { $errors += 'ea_id missing or placeholder' }
if (-not $req.ea_name -or $req.ea_name -match '^<.*>$') { $errors += 'ea_name missing or placeholder' }
if (-not $req.setfile_path -or $req.setfile_path -match '^<.*>$') { $errors += 'setfile_path missing or placeholder' }
if ($errors.Count -gt 0) {
    [pscustomobject]@{ applied = $false; errors = $errors } | ConvertTo-Json -Depth 4
    exit 2
}

# Apply mapping fields to preview copy.
$target.ea_id = $req.ea_id
$target.ea_name = $req.ea_name
$target.setfile_path = $req.setfile_path

$out = [System.IO.Path]::ChangeExtension($TargetPayloadPath, '.patched_preview.json')
$target | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $out

[pscustomobject]@{
    applied = $true
    output_preview = $out
    target_original = $TargetPayloadPath
    updated_fields = @('ea_id','ea_name','setfile_path')
} | ConvertTo-Json -Depth 4
