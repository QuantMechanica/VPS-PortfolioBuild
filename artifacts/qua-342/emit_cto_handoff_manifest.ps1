param(
    [string]$RepoRoot = 'C:\QM\repo'
)

$base = Join-Path $RepoRoot 'artifacts\qua-342'
$utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

function ReadJson($path) {
    if (Test-Path -LiteralPath $path) {
        return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    }
    return $null
}

$unblock = ReadJson (Join-Path $base 'unblock_status_latest.json')
$escalation = ReadJson (Join-Path $base 'cto_escalation_trigger_latest.json')
$readiness = ReadJson (Join-Path $base 'src04_s03_readiness_latest.json')

$manifest = [pscustomobject]@{
    issue = 'QUA-342'
    generated_at_utc = $utc
    blocked = if ($unblock) { [bool]$unblock.blocked } else { $true }
    dispatch_ready = if ($unblock) { [bool]$unblock.dispatch_ready } else { $false }
    escalate_now = if ($unblock) { [bool]$unblock.escalate_now } else { $false }
    unblock_owner = if ($unblock) { $unblock.unblock_owner } else { 'CTO' }
    unblock_action = if ($unblock) { $unblock.unblock_action } else { 'Provide ea_name, setfile_path, and mapped ea_id' }
    missing_fields = if ($unblock -and $unblock.missing_fields) { @($unblock.missing_fields) } else { @() }
    artifacts = [ordered]@{
        tick_bundle_latest = (Join-Path $base 'tick_bundle_latest.json')
        unblock_status_latest = (Join-Path $base 'unblock_status_latest.json')
        blocked_streak_latest = (Join-Path $base 'blocked_streak_latest.json')
        readiness_latest = (Join-Path $base 'src04_s03_readiness_latest.json')
        cto_unblock_request_md = (Join-Path $base 'cto_unblock_request_latest.md')
        cto_unblock_request_json = (Join-Path $base 'cto_unblock_request_latest.json')
        cto_escalation_trigger = (Join-Path $base 'cto_escalation_trigger_latest.json')
        cto_payload_patch_template = (Join-Path $base 'cto_payload_patch_template.json')
        cto_mapping_validator = (Join-Path $base 'validate_cto_mapping_payload.ps1')
        cto_mapping_preview_apply = (Join-Path $base 'apply_cto_mapping_preview.ps1')
        cto_mapping_env_generator = (Join-Path $base 'generate_cto_payload_from_env.ps1')
        cto_fill_payload_example_cmd = (Join-Path $base 'cto_fill_payload_example.cmd')
        current_blocker_status_md = (Join-Path $base 'CURRENT_BLOCKER_STATUS.md')
        status_artifacts_readme = (Join-Path $base 'README_STATUS_ARTIFACTS.md')
    }
    escalation = $escalation
    readiness = $readiness
}

$out = Join-Path $base 'cto_handoff_manifest_latest.json'
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $out
Write-Output "manifest.output=$out"



