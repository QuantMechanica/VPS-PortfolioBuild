[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PublicDataDir = "C:\QM\repo\public-data",
    [string]$OutputDir = "",
    [string]$PipelineStatePath = "D:\QM\reports\state\pipeline_state.json",
    [string]$FarmDbPath = "D:\QM\strategy_farm\state\farm_state.sqlite",
    [string]$FarmRoot = "D:\QM\strategy_farm",
    [string]$PythonExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe",
    [switch]$NoGit,
    [switch]$NoNetlifyFallback,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$SchemaVersionV1 = 1
$SchemaVersionV2 = 2

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

function Get-ObjectKeys {
    param([object]$Target)
    if ($Target -is [System.Collections.IDictionary]) {
        return @($Target.Keys | ForEach-Object { [string]$_ })
    }
    return @($Target.PSObject.Properties.Name)
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
            $requiredTop = @("schema_version", "generated_at", "phase", "agents", "pipeline", "public_archive", "pipeline_gates", "expenses")
            foreach ($key in $requiredTop) {
                if (-not (Test-ObjectHasKey -Target $Object -Key $key)) { throw "Missing key '$key' in $Name." }
            }
            if ($Object.schema_version -ne $SchemaVersionV2) { throw "Invalid schema_version in $Name." }
            if ([string]$Object.phase -cnotmatch '^Q(?:0[0-9]|1[0-7])$') { throw "Invalid Q-only phase in $Name." }
            foreach ($k in @("online", "offline", "blocked")) {
                if ($null -eq $Object.agents.$k -or $Object.agents.$k -lt 0) { throw "Invalid agents.$k in $Name." }
            }
            foreach ($k in @("strategy_cards", "eas_built")) {
                if ($null -eq $Object.pipeline.$k -or $Object.pipeline.$k -lt 0) { throw "Invalid pipeline.$k in $Name." }
            }
            if ($Object.pipeline.work_items_total -lt 0) { throw "Invalid pipeline.work_items_total in $Name." }
            if ($Object.pipeline.by_gate_v4.gate_contract_version -ne "v4") { throw "Invalid pipeline.by_gate_v4.gate_contract_version in $Name." }
            $v4GateKeys = @(0..17 | ForEach-Object { 'Q{0:d2}' -f $_ })
            foreach ($k in $v4GateKeys) {
                if (-not (Test-ObjectHasKey -Target $Object.pipeline.by_gate_v4 -Key $k) -or
                    $Object.pipeline.by_gate_v4.$k -lt 0) {
                    throw "Invalid pipeline.by_gate_v4.$k in $Name."
                }
            }
            foreach ($k in (Get-ObjectKeys -Target $Object.pipeline.by_gate_v4)) {
                if ($k -eq "gate_contract_version") { continue }
                if ($k -notmatch '^Q(?:0[0-9]|1[0-7])$' -or $Object.pipeline.by_gate_v4.$k -lt 0) { throw "Invalid pipeline.by_gate_v4.$k in $Name." }
            }
            if ($Object.expenses.spent_eur -lt 0 -or $Object.expenses.budget_eur -lt 0 -or $Object.expenses.entries -lt 0) { throw "Invalid expenses fields in $Name." }
            if ($Object.public_archive.gate_contract_version -cne "v4" -or
                $Object.public_archive.progress_metric -cne "highest_contiguous_valid_gate") {
                throw "Invalid public_archive contract in $Name."
            }
            $publicGateIds = @($Object.public_archive.gates)
            if ($publicGateIds.Count -ne 18 -or
                ($publicGateIds -join ',') -cne ((0..17 | ForEach-Object { 'Q{0:d2}' -f $_ }) -join ',')) {
                throw "Invalid public_archive gate order in $Name."
            }
            foreach ($card in @($Object.public_archive.cards)) {
                if ([string]$card.public_id -cnotmatch '^card_[0-9a-f]{16}$') {
                    throw "Invalid public_archive public_id in $Name."
                }
                foreach ($gateId in $publicGateIds) {
                    if ($card.gates.$gateId -cnotin @('PASS','FAIL','UNTESTED','IN_PROGRESS')) {
                        throw "Invalid public_archive state at $gateId in $Name."
                    }
                }
            }
            if ($Object.pipeline_gates.gate_contract_version -cne "v4" -or
                @($Object.pipeline_gates.macro_phases).Count -ne 3 -or
                @($Object.pipeline_gates.gates).Count -ne 18) {
                throw "Invalid pipeline_gates contract in $Name."
            }
            $gateCopyIds = @($Object.pipeline_gates.gates | ForEach-Object { [string]$_.id })
            if (($gateCopyIds -join ',') -cne ($publicGateIds -join ',')) {
                throw "Invalid pipeline_gates gate order in $Name."
            }
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
            foreach ($key in @("schema_version", '$schema_id', "generated_at", "gate_contract_version", "disclosure", "gates", "total", "items")) {
                if (-not (Test-ObjectHasKey -Target $Object -Key $key)) { throw "Missing key '$key' in $Name." }
            }
            if ($Object.schema_version -ne $SchemaVersionV2) { throw "Invalid schema_version in $Name." }
            if ($Object.gate_contract_version -cne 'v4' -or
                $Object.disclosure -cne 'terminal_pass_fail_without_metrics') {
                throw "Invalid contract metadata in $Name."
            }
            if ($Object.total -lt 0) { throw "Invalid total in $Name." }
            foreach ($item in $Object.items) {
                foreach ($k in @("public_id", "gate_coverage")) {
                    if (-not (Test-ObjectHasKey -Target $item -Key $k)) { throw "Missing item key '$k' in $Name." }
                }
                if ([string]$item.public_id -cnotmatch '^card_[0-9a-f]{16}$') { throw "Invalid public_id in $Name." }
                foreach ($gate in (Get-ObjectKeys -Target $item.gate_coverage)) {
                    if ($gate -cnotmatch '^Q(?:0[0-9]|1[0-7])$' -or
                        $item.gate_coverage.$gate -cnotin @('PASS','FAIL')) {
                        throw "Invalid gate coverage in $Name."
                    }
                }
            }
        }
        "public-stats" {
            foreach ($key in @("schema_version", "generated_at", "eas_compiled", "strategy_cards", "backtests_total", "phases")) {
                if (-not (Test-ObjectHasKey -Target $Object -Key $key)) { throw "Missing key '$key' in $Name." }
            }
            if ($Object.schema_version -ne $SchemaVersionV1) { throw "Invalid schema_version in $Name." }
            foreach ($key in @("eas_compiled", "strategy_cards", "backtests_total", "phases")) {
                if ($Object.$key -lt 0) { throw "Invalid $key in $Name." }
            }
            if ($Object.phases -ne 18) { throw "Invalid Q-gate count in $Name." }
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

function Get-PublicSnapshotBlocks {
    param(
        [string]$PythonPath,
        [string]$GeneratorPath,
        [string]$DatabasePath,
        [string]$RuntimeRoot,
        [string]$RepositoryRoot
    )
    if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) {
        throw "Python executable not found: $PythonPath"
    }
    if (-not (Test-Path -LiteralPath $GeneratorPath -PathType Leaf)) {
        throw "Public archive contract generator not found: $GeneratorPath"
    }
    $priorErrorPreference = $ErrorActionPreference
    try {
        # Windows PowerShell converts native stderr into error records under
        # Stop. Capture it, then trust only one complete JSON output record.
        $ErrorActionPreference = "Continue"
        $output = @(& $PythonPath $GeneratorPath `
            --public-bundle `
            --db $DatabasePath `
            --farm-root $RuntimeRoot `
            --repo-root $RepositoryRoot 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $priorErrorPreference
    }
    $jsonLines = @($output | ForEach-Object { [string]$_ } |
        Where-Object { $_.Trim().StartsWith('{') -and $_.Trim().EndsWith('}') })
    if ($exitCode -ne 0 -or $jsonLines.Count -ne 1) {
        throw ("Public archive contract generation failed " +
            "(rc=$exitCode output=$($output -join ' | '))")
    }
    try {
        $blocks = [string]$jsonLines[0] | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Public archive contract returned invalid JSON: $($_.Exception.Message)"
    }
    # Defence in depth: the Python allowlist is authoritative, while this grep
    # guard independently refuses the leak classes from the website incident.
    $serialized = $blocks | ConvertTo-Json -Depth 20 -Compress
    $forbidden = @(
        '(?i)(?<![A-Za-z0-9])[A-Za-z]:[\\/]',
        '(?i)file:/{2,}',
        '\\\\[A-Za-z0-9._$-]+\\',
        '(?i)\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
        '(?i)"(?:work_item_id|ea_id|symbol|path|email|threshold|metrics?)"\s*:'
    )
    foreach ($pattern in $forbidden) {
        if ($serialized -match $pattern) {
            throw "Public archive redaction grep guard refused generated blocks."
        }
    }
    if (-not (Test-ObjectHasKey -Target $blocks -Key 'strategy_archive_v2')) {
        throw 'Public archive bundle omitted strategy_archive_v2.'
    }
    return $blocks
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
$effectiveOutputDir = if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $PublicDataDir
} else {
    $OutputDir
}
Ensure-Directory -Path $effectiveOutputDir

$expenses = Get-ExpenseSummary -ExpensesCsvPath (Join-Path $RepoRoot "expenses\expenses.csv")
$processRoadmap = Get-ProcessRoadmap -ProcessesDir (Join-Path $RepoRoot "processes")
$publicBlocks = Get-PublicSnapshotBlocks `
    -PythonPath $PythonExe `
    -GeneratorPath (Join-Path $RepoRoot "tools\strategy_farm\website_archive_contract.py") `
    -DatabasePath $FarmDbPath `
    -RuntimeRoot $FarmRoot `
    -RepositoryRoot $RepoRoot
$strategyArchive = $publicBlocks.strategy_archive_v2

# Load pipeline_state.json (single source of truth for the public-snapshot live fields).
# Built by scripts/build_pipeline_state.py against D:/QM/reports/pipeline + watchdog + aggregator state.
$pipelineState = Read-JsonFile -Path $PipelineStatePath
if ($null -eq $pipelineState) {
    throw "Missing required file: $PipelineStatePath (run scripts/build_pipeline_state.py first)."
}
if ([int]$pipelineState.schema_version -ne 1) {
    throw "Unsupported pipeline_state.json schema_version. Expected 1, got $($pipelineState.schema_version)."
}

# Public operator surfaces use the exact Qxx token only.
$phaseOrder = @($pipelineState.by_gate_v4.PSObject.Properties.Name | Where-Object { $_ -match '^Q(?:0[0-9]|1[0-7])$' })
$highestPhase = $null
foreach ($p in $phaseOrder) {
    if ([int]$pipelineState.by_gate_v4.$p -gt 0) { $highestPhase = $p }
}
if ($null -eq $highestPhase) { $phaseLabel = "Q00" } else { $phaseLabel = $highestPhase }

# agents.{online,offline,blocked} from watchdog sub-agent state.
# online = sub-agents producing runs in last 2h; offline = idle >=2h.
$agentsOnline = [int]$pipelineState.agents_watchdog.online_count
$agentsOffline = [int]$pipelineState.agents_watchdog.offline_count
$agentsBlocked = 0

# pipeline.{strategy_cards,eas_built,work_items_total,by_gate_v4} comes from
# the read-only pipeline-state producer. The legacy P-keyed compatibility view
# is intentionally not public in v2.
$byGateV4 = [ordered]@{ gate_contract_version = [string]$pipelineState.by_gate_v4_gate_contract_version }
foreach ($p in $phaseOrder) {
    $byGateV4[$p] = [int]$pipelineState.by_gate_v4.$p
}

$publicSnapshot = [ordered]@{
    schema_version = $SchemaVersionV2
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
        work_items_total = [int]$pipelineState.work_items_total
        by_gate_v4 = $byGateV4
    }
    public_archive = $publicBlocks.public_archive
    pipeline_gates = $publicBlocks.pipeline_gates
    expenses = $expenses
}

$publicStats = [ordered]@{
    schema_version = $SchemaVersionV1
    generated_at = [datetime]::UtcNow.ToString("o")
    eas_compiled = [int]$pipelineState.eas_registered_count
    strategy_cards = [int]$pipelineState.strategy_cards_count
    backtests_total = [int]$pipelineState.work_items_total
    phases = 18
}

$publicSchemaPath = Join-Path $PublicDataDir "public-snapshot.schema.v2.json"
$roadmapSchemaPath = Join-Path $PublicDataDir "process-roadmap.schema.json"
$archiveSchemaPath = Join-Path $PublicDataDir "strategy-archive.schema.v2.json"
$companyModelSchemaPath = Join-Path $PublicDataDir "company-operating-model.schema.json"
$statsSchemaPath = Join-Path $PublicDataDir "public-stats.schema.json"
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
Validate-JsonAgainstSchema -Object $publicStats -SchemaPath $statsSchemaPath -Name "public-stats"

$changedFiles = New-Object System.Collections.Generic.List[string]

$publicPath = Join-Path $effectiveOutputDir "public-snapshot.json"
$roadmapPath = Join-Path $effectiveOutputDir "process-roadmap.json"
$archivePath = Join-Path $effectiveOutputDir "strategy-archive.json"
$companyModelOutputPath = Join-Path $effectiveOutputDir "company-operating-model.json"
$statsPath = Join-Path $effectiveOutputDir "stats.json"

if ($DryRun) {
    Write-Host "[DryRun] Would write public-snapshot:"
    $publicSnapshot | ConvertTo-Json -Depth 20 | Write-Host
    Write-Host "[DryRun] Process roadmap items: $($processRoadmap.total)"
    Write-Host "[DryRun] Strategy archive items: $($strategyArchive.total)"
    Write-Host "[DryRun] Public stats: eas=$($publicStats.eas_compiled) cards=$($publicStats.strategy_cards) work_items=$($publicStats.backtests_total) gates=$($publicStats.phases)"
    Write-Host "[DryRun] Skipping git + Netlify."
    exit 0
}

if (Write-JsonIfChanged -Path $publicPath -Object $publicSnapshot) { $changedFiles.Add($publicPath) }
if (Write-JsonIfChanged -Path $roadmapPath -Object $processRoadmap) { $changedFiles.Add($roadmapPath) }
if (Write-JsonIfChanged -Path $archivePath -Object $strategyArchive) { $changedFiles.Add($archivePath) }
if (Write-JsonIfChanged -Path $companyModelOutputPath -Object $companyOperatingModel) { $changedFiles.Add($companyModelOutputPath) }
if (Write-JsonIfChanged -Path $statsPath -Object $publicStats) { $changedFiles.Add($statsPath) }

if ($changedFiles.Count -eq 0) {
    Write-Host "No snapshot changes."
    exit 0
}

Write-Host "Snapshot files updated:"
$changedFiles | ForEach-Object { Write-Host "- $_" }

if ($NoGit) { exit 0 }

Push-Location $RepoRoot
try {
    git add public-data/public-snapshot.json public-data/process-roadmap.json public-data/strategy-archive.json public-data/company-operating-model.json public-data/stats.json
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
