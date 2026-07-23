[CmdletBinding()]
param(
    [string]$ReadinessJson = "C:\QM\worktrees\pipeline-operator\artifacts\qua-340-real\qua340_readiness_check_2026-04-28.json",
    [string]$OutPath = "C:\QM\worktrees\pipeline-operator\docs\ops\QUA-340_UNBLOCK_PAYLOAD_2026-04-28.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReadinessJson -PathType Leaf)) {
    throw "Readiness JSON not found: $ReadinessJson"
}

$data = Get-Content -LiteralPath $ReadinessJson -Raw | ConvertFrom-Json
$eaRaw = $data.card_parse.raw
$ready = [bool]$data.readiness.ready_for_queued_smoke

$lines = @(
    '# QUA-340 Unblock Payload (Pipeline-Operator)',
    '',
    '- issue: QUA-340 / SRC04_S02a',
    ('- generated_utc: ' + [DateTime]::UtcNow.ToString('o')),
    ('- readiness_ready_for_queued_smoke: ' + $ready),
    ('- card_ea_id_raw: ' + $eaRaw),
    ('- registry_path: ' + $data.magic_registry.path),
    ('- readiness_evidence_json: ' + $ReadinessJson),
    '',
    '## Required Unblock Owners',
    '',
    '1. CEO + CTO',
    '2. CTO / Development',
    '',
    '## Required Unblock Actions',
    '',
    '1. Set numeric `ea_id` for `SRC04_S02a` in strategy card (replace `TBD`).',
    '2. Add active row for that `ea_id` in `framework/registry/magic_numbers.csv`.',
    '3. Build and deploy `QM5_<ea_id>.ex5` to `D:\QM\mt5\T1..T5\MQL5\Experts\QM\`.',
    '4. Pipeline-Operator reruns queued smoke with new digest (`qua340-smoke-010`).',
    '',
    '## Pipeline-Operator Next Command (after unblock)',
    '',
    '```powershell',
    '.\infra\scripts\Invoke-QUA340ReadinessCheck.ps1',
    '.\infra\scripts\Invoke-PipelineQueuedSmokeRun.ps1 -EAId <ea_id> -Version v5.0.0-qua340 -Symbol EURUSD.DWX -Phase P2 -SubGateConfig qua340-smoke-010 -Terminal T2 -Year 2022 -Period M15 -Runs 2 -MinTrades 1',
    '```'
)

$lines | Set-Content -LiteralPath $OutPath -Encoding UTF8
Write-Output "wrote=$OutPath"
