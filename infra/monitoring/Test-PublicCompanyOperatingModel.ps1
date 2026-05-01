[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$path = Join-Path $RepoRoot "public-data\company-operating-model.json"
if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing file: $path"
}

$data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop

$requiredSections = @(
    "control_tower",
    "capability_cells",
    "process_loop",
    "sections",
    "first_48h_actions",
    "stale_data_behavior"
)

foreach ($section in $requiredSections) {
    if ($null -eq $data.dashboard.$section) {
        throw "Missing dashboard section: $section"
    }
}

if ($null -eq $data.menu -or $data.menu.Count -lt 1) {
    throw "Menu entries missing or empty."
}

$payload = $data | ConvertTo-Json -Depth 20
$privateUrlPattern = '(?i)(localhost:|/QUA/issues/|api[_-]?key|secret|password|token\s*[:=])'
if ($payload -match $privateUrlPattern) {
    throw "Public-safety violation: private URL or credential-like token found in payload."
}

# Block GUID-like agent/internal IDs from public payload.
$guidPattern = '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b'
if ($payload -match $guidPattern) {
    throw "Public-safety violation: GUID-like identifier found in payload."
}

Write-Host "status=ok file=public-data/company-operating-model.json checks=render_sections,menu,public_safety"
