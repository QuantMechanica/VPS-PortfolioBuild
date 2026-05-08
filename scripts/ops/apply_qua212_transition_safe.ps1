param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedRunId,
    [string]$PayloadPath = "C:/QM/repo/docs/ops/QUA-212_ISSUE_TRANSITION_PAYLOAD_2026-05-08.json",
    [string]$DiagScriptPath = "C:/QM/repo/scripts/ops/check_paperclip_ops_token_runid.ps1",
    [string]$TransitionScriptPath = "C:/QM/paperclip/tools/ops/apply_issue_transition_payload.py",
    [string]$OutDir = "C:/QM/repo/artifacts/qua-212"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$safeRun = $ExpectedRunId -replace "[^a-zA-Z0-9-]", "_"
$diagPath = Join-Path $OutDir ("ops_token_runid_check_" + $safeRun + "_guarded.json")

if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$diagJson = & powershell -ExecutionPolicy Bypass -File $DiagScriptPath -ExpectedRunId $ExpectedRunId -OutPath $diagPath
$diag = $diagJson | ConvertFrom-Json

if (-not $diag.match) {
    Write-Output ("guard_blocked=true reason=stale_ops_token expected_run_id=" + $diag.expected_run_id + " token_run_id=" + $diag.token_run_id)
    Write-Output ("artifact=" + $diagPath)
    exit 2
}

& python $TransitionScriptPath --payload $PayloadPath
$code = $LASTEXITCODE
if ($code -ne 0) {
    exit $code
}

Write-Output ("guard_blocked=false transitioned=true artifact=" + $diagPath)
