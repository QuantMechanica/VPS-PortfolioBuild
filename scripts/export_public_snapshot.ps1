[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PublicDataDir = "C:\QM\repo\public-data",
    [switch]$NoGit,
    [switch]$NoNetlifyFallback
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
    $newJson | Set-Content -LiteralPath $tmp -Encoding UTF8
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
            $requiredTop = @("generated_at", "phase", "agents", "pipeline", "t6", "expenses")
            foreach ($key in $requiredTop) {
                if (-not (Test-ObjectHasKey -Target $Object -Key $key)) { throw "Missing key '$key' in $Name." }
            }
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
            foreach ($key in @("generated_at", "total", "items")) {
                if (-not (Test-ObjectHasKey -Target $Object -Key $key)) { throw "Missing key '$key' in $Name." }
            }
            if ($Object.total -lt 0) { throw "Invalid total in $Name." }
            foreach ($item in $Object.items) {
                foreach ($k in @("id", "title", "status", "last_updated_utc")) {
                    if (-not (Test-ObjectHasKey -Target $item -Key $k)) { throw "Missing item key '$k' in $Name." }
                }
                if ($item.status -notin @("active", "paused", "draft", "deprecated")) { throw "Invalid process status '$($item.status)' in $Name." }
            }
        }
        "strategy-archive" {
            foreach ($key in @("generated_at", "total", "items")) {
                if (-not (Test-ObjectHasKey -Target $Object -Key $key)) { throw "Missing key '$key' in $Name." }
            }
            if ($Object.total -lt 0) { throw "Invalid total in $Name." }
            foreach ($item in $Object.items) {
                foreach ($k in @("slug", "source", "visibility", "last_updated_utc")) {
                    if (-not (Test-ObjectHasKey -Target $item -Key $k)) { throw "Missing item key '$k' in $Name." }
                }
                if ($item.visibility -notin @("public", "private_redacted")) { throw "Invalid strategy visibility '$($item.visibility)' in $Name." }
            }
        }
        "company-operating-model" {
            foreach ($key in @("generated_at", "status", "roles", "operating_principles", "dashboard_sections", "process_links", "first_48h_actions")) {
                if (-not (Test-ObjectHasKey -Target $Object -Key $key)) { throw "Missing key '$key' in $Name." }
            }
            if ($Object.status -notin @("draft", "active", "paused")) { throw "Invalid status '$($Object.status)' in $Name." }
            foreach ($role in $Object.roles) {
                foreach ($k in @("role", "status", "primary_skill", "model_tier", "heartbeat")) {
                    if (-not (Test-ObjectHasKey -Target $role -Key $k)) { throw "Missing role key '$k' in $Name." }
                }
                if ($role.status -notin @("live", "hire_now", "on_demand", "planned", "deferred")) { throw "Invalid role status '$($role.status)' in $Name." }
            }
            foreach ($section in $Object.dashboard_sections) {
                foreach ($k in @("id", "title", "source", "status")) {
                    if (-not (Test-ObjectHasKey -Target $section -Key $k)) { throw "Missing dashboard section key '$k' in $Name." }
                }
                if ($section.status -notin @("draft", "active", "planned")) { throw "Invalid dashboard section status '$($section.status)' in $Name." }
            }
            foreach ($link in $Object.process_links) {
                foreach ($k in @("id", "path")) {
                    if (-not (Test-ObjectHasKey -Target $link -Key $k)) { throw "Missing process link key '$k' in $Name." }
                }
            }
            foreach ($action in $Object.first_48h_actions) {
                foreach ($k in @("owner", "action", "status")) {
                    if (-not (Test-ObjectHasKey -Target $action -Key $k)) { throw "Missing action key '$k' in $Name." }
                }
                if ($action.status -notin @("todo", "in_progress", "done", "blocked")) { throw "Invalid action status '$($action.status)' in $Name." }
            }
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
        generated_at = [datetime]::UtcNow.ToString("o")
        total = $items.Count
        items = $items
    }
}

function Get-StrategyArchiveSnapshot {
    param([string]$StrategySeedSpecsDir)
    $items = @()
    if (Test-Path -LiteralPath $StrategySeedSpecsDir) {
        $items = Get-ChildItem -LiteralPath $StrategySeedSpecsDir -File -Filter "*.md" |
            Sort-Object Name |
            ForEach-Object {
                [ordered]@{
                    slug = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                    source = "strategy-seeds/specs"
                    visibility = "public"
                    last_updated_utc = $_.LastWriteTimeUtc.ToString("o")
                }
            }
    }
    return [ordered]@{
        generated_at = [datetime]::UtcNow.ToString("o")
        total = $items.Count
        items = $items
    }
}

function Get-CompanyOperatingModelSnapshot {
    $roles = @(
        [ordered]@{ role = "CEO"; status = "live"; primary_skill = "delegation and gate decisions"; model_tier = "strong"; heartbeat = "30min timer" },
        [ordered]@{ role = "Chief of Staff / OS Controller"; status = "hire_now"; primary_skill = "AI-native org routing and token efficiency"; model_tier = "mid/strong"; heartbeat = "light timer plus on-demand" },
        [ordered]@{ role = "Token Controller"; status = "planned"; primary_skill = "token budget accounting"; model_tier = "lightweight"; heartbeat = "covered by Chief of Staff until justified" },
        [ordered]@{ role = "Research Lead"; status = "live"; primary_skill = "source-to-strategy extraction"; model_tier = "strong"; heartbeat = "event-driven" },
        [ordered]@{ role = "PDF Researcher"; status = "on_demand"; primary_skill = "PDF extraction"; model_tier = "strong on demand"; heartbeat = "none" },
        [ordered]@{ role = "Video Researcher"; status = "on_demand"; primary_skill = "video transcript analysis"; model_tier = "mid/strong"; heartbeat = "none" },
        [ordered]@{ role = "Data Environment Steward"; status = "on_demand"; primary_skill = ".DWX symbol verification"; model_tier = "lightweight/Codex"; heartbeat = "none until recurring failures" },
        [ordered]@{ role = "Pipeline-Operator"; status = "live"; primary_skill = "T1-T5 backtest dispatch"; model_tier = "Codex mid"; heartbeat = "work-queue driven" },
        [ordered]@{ role = "Visualization Controller"; status = "planned"; primary_skill = "project dashboard and OWNER high-altitude view"; model_tier = "lightweight/mid"; heartbeat = "hourly after dashboard feed is wired" },
        [ordered]@{ role = "Gmail Intake"; status = "planned"; primary_skill = "mail link triage"; model_tier = "lightweight"; heartbeat = "manual/on-demand until volume justifies timer" }
    )

    return [ordered]@{
        generated_at = [datetime]::UtcNow.ToString("o")
        status = "draft"
        roles = $roles
        operating_principles = @(
            "Paperclip runs as a control tower plus capability cells, not as a human org chart.",
            "One primary skill per agent.",
            "Hire persistent agents only against a measured recurring bottleneck.",
            "Research remains one approved source at a time.",
            "T1-T5 factory work is load-balanced and deduplicated.",
            "Lessons learned must feed a process, checklist, prompt proposal, or explicit no-change decision.",
            "Public dashboard reads redacted JSON snapshots, not private Paperclip state directly."
        )
        dashboard_sections = @(
            [ordered]@{ id = "project-dashboard"; title = "Project Dashboard"; source = "public-data/public-snapshot.json and public-data/company-runtime.json"; status = "active" },
            [ordered]@{ id = "company-operating-model"; title = "Company Operating Model"; source = "public-data/company-operating-model.json"; status = "draft" },
            [ordered]@{ id = "process-roadmap"; title = "Process Roadmap"; source = "public-data/process-roadmap.json"; status = "active" }
        )
        process_links = @(
            [ordered]@{ id = "company-operating-system"; path = "processes/18-company-operating-system.md" },
            [ordered]@{ id = "agent-runtime-health"; path = "processes/17-agent-runtime-health.md" },
            [ordered]@{ id = "pipeline-load-balancing"; path = "processes/15-pipeline-op-load-balancing.md" },
            [ordered]@{ id = "strategy-research"; path = "processes/13-strategy-research.md" }
        )
        first_48h_actions = @(
            [ordered]@{ owner = "CEO"; action = "Create and approve Chief of Staff / OS Controller hire issue."; status = "todo" },
            [ordered]@{ owner = "Chief of Staff / OS Controller"; action = "Produce AI-native control tower map, model-tier map, token-control policy."; status = "todo" },
            [ordered]@{ owner = "Video Researcher"; action = "Analyze YouTube source UIdH5Ac1Db8 and brief Chief of Staff."; status = "todo" },
            [ordered]@{ owner = "Data Environment Steward"; action = "Audit T1-T5 .DWX symbol coverage and backtest readiness."; status = "todo" },
            [ordered]@{ owner = "Visualization Controller / DevOps interim"; action = "Wire Company Operating Model into dashboard/menu data."; status = "todo" }
        )
    }
}

Ensure-Directory -Path $PublicDataDir

$expenses = Get-ExpenseSummary -ExpensesCsvPath (Join-Path $RepoRoot "expenses\expenses.csv")
$processRoadmap = Get-ProcessRoadmap -ProcessesDir (Join-Path $RepoRoot "processes")
$strategyArchive = Get-StrategyArchiveSnapshot -StrategySeedSpecsDir (Join-Path $RepoRoot "strategy-seeds\specs")
$companyOperatingModel = Get-CompanyOperatingModelSnapshot

$publicSnapshot = [ordered]@{
    generated_at = [datetime]::UtcNow.ToString("o")
    phase = "P0 Foundation"
    agents = @{
        online = 0
        offline = 0
        blocked = 0
    }
    pipeline = @{
        strategy_cards = 0
        eas_built = 0
        by_phase = @{
            G0 = 0
            P1 = 0
            P2 = 0
            P3 = 0
            P3_5 = 0
            P4 = 0
            P5 = 0
            P5b = 0
            P5c = 0
            P6 = 0
            P7 = 0
            P8 = 0
            P9 = 0
            P9b = 0
            P10 = 0
        }
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

Validate-JsonAgainstSchema -Object $publicSnapshot -SchemaPath $publicSchemaPath -Name "public-snapshot"
Validate-JsonAgainstSchema -Object $processRoadmap -SchemaPath $roadmapSchemaPath -Name "process-roadmap"
Validate-JsonAgainstSchema -Object $strategyArchive -SchemaPath $archiveSchemaPath -Name "strategy-archive"
Validate-JsonAgainstSchema -Object $companyOperatingModel -SchemaPath $companyModelSchemaPath -Name "company-operating-model"

$changedFiles = New-Object System.Collections.Generic.List[string]

$publicPath = Join-Path $PublicDataDir "public-snapshot.json"
if (Write-JsonIfChanged -Path $publicPath -Object $publicSnapshot) { $changedFiles.Add($publicPath) }
$roadmapPath = Join-Path $PublicDataDir "process-roadmap.json"
if (Write-JsonIfChanged -Path $roadmapPath -Object $processRoadmap) { $changedFiles.Add($roadmapPath) }
$archivePath = Join-Path $PublicDataDir "strategy-archive.json"
if (Write-JsonIfChanged -Path $archivePath -Object $strategyArchive) { $changedFiles.Add($archivePath) }
$companyModelPath = Join-Path $PublicDataDir "company-operating-model.json"
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
