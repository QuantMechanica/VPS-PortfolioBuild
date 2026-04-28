[CmdletBinding()]
param(
    [string]$TransitionPayloadPath = "C:\QM\repo\docs\ops\QUA-185_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json",
    [string]$OutPath = "C:\QM\repo\docs\ops\QUA-185_ISSUE_STATUS_UPDATE_2026-04-27.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-ParentDirectory {
    param([string]$Path)
    $parent = Split-Path -Path $Path -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

if (-not (Test-Path -LiteralPath $TransitionPayloadPath -PathType Leaf)) {
    throw "Transition payload not found: $TransitionPayloadPath"
}

$transition = Get-Content -Raw -LiteralPath $TransitionPayloadPath | ConvertFrom-Json
if (-not $transition.issue_id) {
    throw "Transition payload missing issue_id: $TransitionPayloadPath"
}
if (-not $transition.target_status) {
    throw "Transition payload missing target_status: $TransitionPayloadPath"
}

$payload = [ordered]@{
    issue_id = $transition.issue_id
    updated_at_local = (Get-Date).ToString("o")
    issue_update = [ordered]@{
        status = $transition.target_status
    }
    reason = "qua185_transition_payload_applied"
    source_transition_payload = [IO.Path]::GetFileName($TransitionPayloadPath)
}

Ensure-ParentDirectory -Path $OutPath
$payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutPath -Encoding ASCII
$payload | ConvertTo-Json -Depth 6
