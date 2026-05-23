[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PublicDataDir = "C:\QM\repo\public-data",
    [string]$PipelineStatePath = "D:\QM\reports\state\pipeline_state.json",
    [switch]$NoGit,
    [switch]$NoNetlifyFallback,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$SchemaVersionV1 = 1

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-JsonIfChanged {
    param(
        [string]$Path,
        [object]$Object
    )

    $newJson = $Object | ConvertTo-Json -Depth 20
    $existing = if (Test-Path -LiteralPath $Path) { Get-Content -LiteralPath $Path -Raw } else { "" }
    if ($existing -eq $newJson) { return $false }
    $tmp = "$Path.tmp"
    [System.IO.File]::WriteAllText($tmp, $newJson, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $Path -Force
    return $true
}

function Test-ObjectHasKey {
    param(
        [object]$Target,
        [string]$Key
    )
    if ($Target -is [System.Collections.IDictionary]) {
        return $Target.Contains($Key)
    }
    return $Target.PSObject.Properties.Name.Contains($Key)
}

function Validate-JsonAgainstSchema {
    param(
        [object]$Object,
        [string]$SchemaPath,
        [string]$Name
    )

    if (Get-Command Test-Json -ErrorAction SilentlyContinue) {
        $json = $Object | ConvertTo-Json -Depth 20
        $ok = $json | Test-Json -SchemaFile $SchemaPath
        if (-not $ok) {
            throw "$Name failed schema validation: $SchemaPath"
        }
        return
    }

    # Windows PowerShell 5.x fallback validation (schema-aligned checks).
    switch ($Name) {
        "public-snapshot" {
            $requiredTop = @("schema_version", "generated_at", "phase", "agents", "pipeline", "t6", "expenses")
            foreach ($key in $requiredTop) {
                if (-not (Test-ObjectHasKey -Target $Object -Key $key)) { throw "Missing key '$key' in $Name." }
            }
            if ($Object.schema_version -ne $SchemaVersionV1) { throw "Invalid schema_version in $Name." }
            foreach ($k in @("online", "offline", "blocked")) {
                if ($null -eq $Object.agents.$k -or $Object.agents.$k -lt 0) { throw "Invalid agents.$k in $Name." }
            }
            foreach ($k in @("strategy_cards", "eas_built")) {
                if ($null -eq $Object.pipeline.$k -or $Object.pipeline.$k -lt 0) { throw "Invalid pipeline.$k in $Name." }
            }
            $phaseKeys = @("G0", "P1", "P2", "P3", "P3_5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8", "P9", "P9b", "P10")
            foreach ($k in $phaseKeys) {
                if ($null -eq $Object.pipeline.by_phase.$k -or $Object.pipeline.by_phase.$k -lt 0) { throw "Invalid pipeline.by_phase.$k in $Name." }
            }
            if ($Object.t6.status -notin @("offline", "demo", "live", "degraded")) { throw "Invalid t6.status in $Name." }
            if ($Object.t6.risk_state -notin @("green", "yellow", "red")) { throw "Invalid t6.risk_state in $Name." }
            if ($Object.expenses.spent_eur -lt 0 -or $Object.expenses.budget_eur -lt 0 -or $Object.expenses.entries -lt 0) { throw "Invalid expenses fields in $Name." }
        }
        "process-roadmap" {
            foreach ($key in @("schema_version", "generated_at", "total", "items")) {
                if (-not (Test-ObjectHasKey -Target $Object -Key $key)) { throw "Missing key '$key' in $Name." }
            }
            if ($Object.schema_version -ne $SchemaVersionV1) { throw "Invalid schema_version in $Name." }
            if ($Object.total -lt 0) { throw "Invalid total in $Name." }
            foreach ($item in $Object.items) {
                foreach ($k in @("id", "title", "status", "last_updated_utc")) {
                    if (-not (Test-ObjectHasKey -Target $item -Key $k)) { throw "Missing item key '$k' in $Name." }
                }
                if ($item.status -notin @("active", "paused", "draft", "deprecated")) { throw "Invalid process status '$($item.status)' in $Name." }
            }
        }
        "strategy-archive" {
            foreach ($key in @("schema_version", "generated_at", "total", "items")) {
                if (-not (Test-ObjectHasKey -Target $Object -Key $key)) { throw "Missing key '$key' in $Name." }
            }
            if ($Object.schema_version -ne $SchemaVersionV1) { throw "Invalid schema_version in $Name." }
            if ($Object.total -lt 0) { throw "Invalid total in $Name." }
            foreach ($item in $Object.items) {
                foreach ($k in @("slug", "source", "visibility", "last_updated_utc")) {
                    if (-not (Test-ObjectHasKey -Target $item -Key $k)) { throw "Missing item key '$k' in $Name." }
                }
                if ($item.visibility -notin @("public", "private_redacted")) { throw "Invalid strategy visibility '$($item.visibility)' in $Name." }
            }
        }
        "company-operating-model" {
            foreach ($key in @("schema_version", "schema", "updated_at", "cache_ttl_minutes", "menu", "dashboard")) {
                if (-not (Test-ObjectHasKey -Target $Object -Key $key)) { throw "Missing key '$key' in $Name." }
            }
            if ($Object.schema_version -ne $SchemaVersionV1) { throw "Invalid schema_version in $Name." }
            if ($Object.schema -ne "quantmechanica.company-operating-model.v1") { throw "Invalid schema value in $Name." }
            if ($Object.cache_ttl_minutes -lt 1) { throw "Invalid cache_ttl_minutes in $Name." }
            if ($null -eq $Object.dashboard.stale_data_behavior.ui_label_template) { throw "Missing stale_data_behavior.ui_label_template in $Name." }
        }
        default {
            throw "No fallback validator implemented for $Name."
        }
    }
}

function Get-ExpenseSummary {
    param([string]$ExpensesCsvPath)
    if (-not (Test-Path -LiteralPath $ExpensesCsvPath)) {
        return @{ spent_eur = 0; budget_eur = 1850; entries = 0 }
    }

    $rows = Import-Csv -LiteralPath $ExpensesCsvPath
    $sum = 0.0
    foreach ($row in $rows) {
        $value = 0.0
        if ($row.amount_eur -and [double]::TryParse($row.amount_eur, [ref]$value)) {
            $sum += $value
        }
    }
    return @{
        spent_eur = [math]::Round($sum, 2)
        budget_eur = 1850
        entries = $rows.Count
    }
}

function Get-ProcessRoadmap {
    param([string]$ProcessesDir)
    $items = @()
    if (Test-Path -LiteralPath $ProcessesDir) {
        $items = Get-ChildItem -LiteralPath $ProcessesDir -File -Filter "*.md" |
            Sort-Object Name |
            ForEach-Object {
                [ordered]@{
                    id = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                    title = $_.BaseName
                    status = "active"
                    last_updated_utc = $_.LastWriteTimeUtc.ToString("o")
                }
            }
    }
    return [ordered]@{
        schema_version = $SchemaVersionV1
        generated_at = [datetime]::UtcNow.ToString("o")
        total = $items.Count
        items = $items
    }
}

function Get-StrategyArchiveSnapshot {
    param(
        [string]$StrategySeedSpecsDir,
        [string[]]$FarmCardDirs = @()
    )
    $items = @()
    $seen = @{}
    if (Test-Path -LiteralPath $StrategySeedSpecsDir) {
        $items = Get-ChildItem -LiteralPath $StrategySeedSpecsDir -File -Filter "*.md" |
            Sort-Object Name |
            ForEach-Object {
                $slug = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                $seen[$slug] = $true
                [ordered]@{
                    slug = $slug
                    source = "strategy-seeds/specs"
                    visibility = "public"
                    last_updated_utc = $_.LastWriteTimeUtc.ToString("o")
                }
            }
    }
    foreach ($dir in $FarmCardDirs) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        $leaf = Split-Path -Leaf $dir
        $source = if ($dir -like "*strategy-seeds*") {
            "strategy-seeds/$leaf"
        } else {
            "strategy_farm/artifacts/$leaf"
        }
        $farmItems = Get-ChildItem -LiteralPath $dir -File -Filter "*.md" |
            Sort-Object Name |
            ForEach-Object {
                $slug = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                if ($seen.ContainsKey($slug)) { return }
                $seen[$slug] = $true
                [ordered]@{
                    slug = $slug
                    source = $source
                    visibility = "public"
                    last_updated_utc = $_.LastWriteTimeUtc.ToString("o")
                }
            }
        $items = @($items) + @($farmItems)
    }
    return [ordered]@{
        schema_version = $SchemaVersionV1
        generated_at = [datetime]::UtcNow.ToString("o")
        total = $items.Count
        items = $items
    }
}

Ensure-Directory -Path $PublicDataDir

$expenses = Get-ExpenseSummary -ExpensesCsvPath (Join-Path $RepoRoot "expenses\expenses.csv")
$processRoadmap = Get-ProcessRoadmap -ProcessesDir (Join-Path $RepoRoot "processes")
$strategyArchive = Get-StrategyArchiveSnapshot `
    -StrategySeedSpecsDir (Join-Path $RepoRoot "strategy-seeds\specs") `
    -FarmCardDirs @(
        (Join-Path $RepoRoot "strategy-seeds\cards"),
        "D:\QM\strategy_farm\artifacts\cards_approved",
        "D:\QM\strategy_farm\artifacts\cards_draft"
    )

# Load pipeline_state.json (single source of truth for the public-snapshot live fields).
# Built by scripts/build_pipeline_state.py against D:/QM/reports/pipeline + watchdog + aggregator state.
$pipelineState = Read-JsonFile -Path $PipelineStatePath
if ($null -eq $pipelineState) {
    throw "Missing required file: $PipelineStatePath (run scripts/build_pipeline_state.py first)."
}
if ([int]$pipelineState.schema_version -ne 1) {
    throw "Unsupported pipeline_state.json schema_version. Expected 1, got $($pipelineState.schema_version)."
}

# Derive phase label: highest phase any EA has reached (best signal of company progress)
# under DL-061 Endausbaustufe-Modus (no company-level phase gating).
$phaseOrder = @("G0", "P1", "P2", "P3", "P3_5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8", "P9", "P9b", "P10")
$highestPhase = $null
foreach ($p in $phaseOrder) {
    if ([int]$pipelineState.by_phase.$p -gt 0) { $highestPhase = $p }
}
if ($null -eq $highestPhase) {
    $phaseLabel = "Endausbaustufe-Modus - no EA past G0 yet"
} else {
    $displayPhase = $highestPhase -replace "_", "."
    $phaseLabel = "Endausbaustufe-Modus - highest EA at $displayPhase"
}

# agents.{online,offline,blocked} from watchdog sub-agent state.
# online = sub-agents producing runs in last 2h; offline = idle >=2h; blocked = (future: Paperclip API count).
$agentsOnline = [int]$pipelineState.agents_watchdog.online_count
$agentsOffline = [int]$pipelineState.agents_watchdog.offline_count
$agentsBlocked = 0  # placeholder until Paperclip API integration

# pipeline.{strategy_cards,eas_built,by_phase} from pipeline_state.json.
$byPhaseLive = @{}
foreach ($p in $phaseOrder) {
    $byPhaseLive[$p] = [int]$pipelineState.by_phase.$p
}

$publicSnapshot = [ordered]@{
    schema_version = $SchemaVersionV1
    generated_at = [datetime]::UtcNow.ToString("o")
    phase = $phaseLabel
    agents = @{
        online = $agentsOnline
        offline = $agentsOffline
        blocked = $agentsBlocked
    }
    pipeline = @{
        strategy_cards = [int]$pipelineState.strategy_cards_count
        eas_built = [int]$pipelineState.eas_registered_count
        by_phase = $byPhaseLive
    }
    t6 = @{
        status = "offline"
        autotrading = $false
        risk_state = "green"
    }
    expenses = $expenses
}

$publicSchemaPath = Join-Path $PublicDataDir "public-snapshot.schema.json"
$roadmapSchemaPath = Join-Path $PublicDataDir "process-roadmap.schema.json"
$archiveSchemaPath = Join-Path $PublicDataDir "strategy-archive.schema.json"
$companyModelSchemaPath = Join-Path $PublicDataDir "company-operating-model.schema.json"
$companyModelPath = Join-Path $PublicDataDir "company-operating-model.json"
$companyOperatingModel = Read-JsonFile -Path $companyModelPath
if ($null -eq $companyOperatingModel) {
    throw "Missing required file: $companyModelPath"
}
if (-not (Test-ObjectHasKey -Target $companyOperatingModel -Key "schema_version")) {
    throw "Missing required key 'schema_version' in $companyModelPath"
}
if ([int]$companyOperatingModel.schema_version -ne $SchemaVersionV1) {
    throw "Invalid schema_version in $companyModelPath. Expected $SchemaVersionV1."
}

Validate-JsonAgainstSchema -Object $publicSnapshot -SchemaPath $publicSchemaPath -Name "public-snapshot"
Validate-JsonAgainstSchema -Object $processRoadmap -SchemaPath $roadmapSchemaPath -Name "process-roadmap"
Validate-JsonAgainstSchema -Object $strategyArchive -SchemaPath $archiveSchemaPath -Name "strategy-archive"
Validate-JsonAgainstSchema -Object $companyOperatingModel -SchemaPath $companyModelSchemaPath -Name "company-operating-model"

$changedFiles = New-Object System.Collections.Generic.List[string]

$publicPath = Join-Path $PublicDataDir "public-snapshot.json"
$roadmapPath = Join-Path $PublicDataDir "process-roadmap.json"
$archivePath = Join-Path $PublicDataDir "strategy-archive.json"

if ($DryRun) {
    Write-Host "[DryRun] Would write public-snapshot:"
    $publicSnapshot | ConvertTo-Json -Depth 20 | Write-Host
    Write-Host "[DryRun] Process roadmap items: $($processRoadmap.total)"
    Write-Host "[DryRun] Strategy archive items: $($strategyArchive.total)"
    Write-Host "[DryRun] Skipping git + Netlify."
    exit 0
}

if (Write-JsonIfChanged -Path $publicPath -Object $publicSnapshot) { $changedFiles.Add($publicPath) }
if (Write-JsonIfChanged -Path $roadmapPath -Object $processRoadmap) { $changedFiles.Add($roadmapPath) }
if (Write-JsonIfChanged -Path $archivePath -Object $strategyArchive) { $changedFiles.Add($archivePath) }
if (Write-JsonIfChanged -Path $companyModelPath -Object $companyOperatingModel) { $changedFiles.Add($companyModelPath) }

if ($changedFiles.Count -eq 0) {
    Write-Host "No snapshot changes."
    exit 0
}

Write-Host "Snapshot files updated:"
$changedFiles | ForEach-Object { Write-Host "- $_" }

if ($NoGit) { exit 0 }

Push-Location $RepoRoot
try {
    git add public-data/public-snapshot.json public-data/process-roadmap.json public-data/strategy-archive.json public-data/company-operating-model.json
    $diff = git diff --cached --name-only
    if (-not $diff) {
        Write-Host "No git-staged snapshot diff."
        exit 0
    }

    git commit -m "infra: refresh public snapshot data"
    $pushOk = $true
    git push
    if ($LASTEXITCODE -ne 0) { $pushOk = $false }

    if (-not $pushOk -and -not $NoNetlifyFallback -and $env:NETLIFY_BUILD_HOOK_URL) {
        try {
            Invoke-RestMethod -Method Post -Uri $env:NETLIFY_BUILD_HOOK_URL -TimeoutSec 20 | Out-Null
            Write-Host "Triggered Netlify Build Hook fallback."
        }
        catch {
            Write-Warning "Netlify Build Hook fallback failed: $($_.Exception.Message)"
            exit 1
        }
    }
}
finally {
    Pop-Location
}
