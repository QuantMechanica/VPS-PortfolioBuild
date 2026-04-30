[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cardPath = Join-Path $RepoRoot "strategy-seeds\cards\lien-20day-breakout_card.md"
$srcPath = Join-Path $RepoRoot "strategy-seeds\sources\SRC04\raw\ch13-16_technical.txt"
$manifestPath = Join-Path $RepoRoot "artifacts\qua-346\src04_s07_run_manifest_template.json"
$cardsDir = Join-Path $RepoRoot "strategy-seeds\cards"

$cardCandidates = @()
if (Test-Path -LiteralPath $cardsDir -PathType Container) {
    $nameCandidates = Get-ChildItem -LiteralPath $cardsDir -File -Filter "*lien*.md" -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
    $contentCandidates = @(Get-ChildItem -LiteralPath $cardsDir -File -Filter "*.md" -ErrorAction SilentlyContinue |
        Select-String -Pattern "SRC04_S07|20-day-breakout|20day-breakout|lien-20day-breakout" -SimpleMatch -List -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Path -Unique)
    $cardCandidates = @($nameCandidates + $contentCandidates | Sort-Object -Unique)
}

$checks = @(
    [pscustomobject]@{ name = "card_exists"; path = $cardPath; ok = (Test-Path -LiteralPath $cardPath -PathType Leaf) },
    [pscustomobject]@{ name = "source_exists"; path = $srcPath; ok = (Test-Path -LiteralPath $srcPath -PathType Leaf) },
    [pscustomobject]@{ name = "manifest_exists"; path = $manifestPath; ok = (Test-Path -LiteralPath $manifestPath -PathType Leaf) }
)

$manifestReady = $false
$manifestMissingFields = @()
if (($checks | Where-Object { $_.name -eq "manifest_exists" }).ok) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $required = $manifest.required_fields
    if (-not $required.symbols -or $required.symbols.Count -eq 0) { $manifestMissingFields += "required_fields.symbols" }
    if ([string]::IsNullOrWhiteSpace($required.from)) { $manifestMissingFields += "required_fields.from" }
    if ([string]::IsNullOrWhiteSpace($required.to)) { $manifestMissingFields += "required_fields.to" }
    if ([string]::IsNullOrWhiteSpace($required.ea_name)) { $manifestMissingFields += "required_fields.ea_name" }
    if ([string]::IsNullOrWhiteSpace($required.setfile_path)) { $manifestMissingFields += "required_fields.setfile_path" }
    $manifestReady = ($manifestMissingFields.Count -eq 0)
}

$coreReady = @($checks | Where-Object { $_.name -in @("card_exists", "source_exists") -and $_.ok -eq $false }).Count -eq 0
$ready = $coreReady -and $manifestReady

$cardExists = ($checks | Where-Object { $_.name -eq "card_exists" } | Select-Object -First 1).ok
$sourceExists = ($checks | Where-Object { $_.name -eq "source_exists" } | Select-Object -First 1).ok
$manifestExists = ($checks | Where-Object { $_.name -eq "manifest_exists" } | Select-Object -First 1).ok

$unblockSteps = @()
if (-not $cardExists) { $unblockSteps += "restore/publish SRC04_S07 card path" }
if (-not $sourceExists) { $unblockSteps += "publish SRC04 source artifact" }
if (-not $manifestExists) { $unblockSteps += "create run manifest template" }
if ($manifestMissingFields.Count -gt 0) { $unblockSteps += "fill required manifest fields" }
if ($unblockSteps.Count -eq 0) { $unblockSteps += "execute first full baseline cohort" }

$unblockAction = ($unblockSteps -join "; ") + "."

$result = [ordered]@{
    issue = "QUA-346"
    strategy_id = "SRC04_S07"
    checked_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    ready = $ready
    checks = $checks
    manifest_ready = $manifestReady
    manifest_missing_fields = $manifestMissingFields
    card_candidates = $cardCandidates
    unblock_owner = "CEO + CTO"
    unblock_action = $unblockAction
    next_action_when_ready = "Run first full baseline cohort and publish filesystem-truth + report-size evidence."
}

$json = $result | ConvertTo-Json -Depth 6
Write-Output $json

if ($ready) { exit 0 } else { exit 1 }
