param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$OutPath = ""
)

$ErrorActionPreference = 'Stop'

if (-not $OutPath) {
    $OutPath = Join-Path $RepoRoot "docs\ops\QUA-344_READINESS_CHECK_$(Get-Date -Format yyyy-MM-dd).json"
}

$cardPath = Join-Path $RepoRoot "strategy-seeds\cards\lien-inside-day-breakout_card.md"
$templatePath = Join-Path $RepoRoot "docs\ops\QUA-344_P1_BASELINE_TEMPLATE_2026-04-28.json"

$result = [ordered]@{
    issue = "QUA-344"
    generated_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    checks = [ordered]@{}
    status = "blocked"
    unblock_owner = "Dev + CTO"
    unblock_action = "Provide ea_id, compiled .ex5 path, and dispatch fields"
}

$cardExists = Test-Path -LiteralPath $cardPath
$templateExists = Test-Path -LiteralPath $templatePath
$result.checks.card_exists = $cardExists
$result.checks.template_exists = $templateExists

$eaId = $null
$cardStatus = $null
if ($cardExists) {
    $content = Get-Content -LiteralPath $cardPath
    $eaLine = $content | Where-Object { $_ -match '^ea_id:\s*' } | Select-Object -First 1
    $statusLine = $content | Where-Object { $_ -match '^status:\s*' } | Select-Object -First 1
    if ($eaLine) { $eaId = ($eaLine -replace '^ea_id:\s*', '').Trim() }
    if ($statusLine) { $cardStatus = ($statusLine -replace '^status:\s*', '').Trim() }
}
$result.checks.card_status = $cardStatus
$result.checks.ea_id = $eaId

$ex5Path = $null
if ($templateExists) {
    $template = Get-Content -LiteralPath $templatePath -Raw | ConvertFrom-Json
    $ex5Path = [string]$template.template.ea_binary_path
}
$result.checks.ea_binary_path = $ex5Path
$result.checks.ea_binary_exists = $false
if ($ex5Path -and $ex5Path -ne 'TBD') {
    $resolved = $ex5Path
    if (-not [System.IO.Path]::IsPathRooted($resolved)) {
        $resolved = Join-Path $RepoRoot $resolved
    }
    $result.checks.ea_binary_exists = Test-Path -LiteralPath $resolved
}

$isRunnable = $cardExists -and $templateExists -and $cardStatus -and ($cardStatus -ne 'DRAFT') -and $eaId -and ($eaId -ne 'TBD') -and $ex5Path -and ($ex5Path -ne 'TBD') -and $result.checks.ea_binary_exists
if ($isRunnable) {
    $result.status = 'ready'
    $result.unblock_owner = 'none'
    $result.unblock_action = 'none'
}

($result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $OutPath
Write-Output $OutPath
