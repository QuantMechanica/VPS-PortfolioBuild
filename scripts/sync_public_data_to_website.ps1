[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$DataDir = "C:\QM\repo\public-data",
    [string]$SchemaDir = "C:\QM\repo\public-data",
    [string]$DeployRepo = "C:\QM\deploy\quantmechanica-ops",
    [string]$ReceiptPath = "",
    [switch]$Apply,
    [switch]$Commit,
    [switch]$Push
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Commit -and -not $Apply) { throw '-Commit requires -Apply.' }
if ($Push -and -not $Commit) { throw '-Push requires -Commit and -Apply.' }

function Quote-CommandArgument {
    param([string]$Value)
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Invoke-GitChecked {
    param([string[]]$Arguments)
    & git.exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git failed with exit code ${LASTEXITCODE}: git $($Arguments -join ' ')"
    }
}

function Write-Receipt {
    param([object]$Receipt)
    if ([string]::IsNullOrWhiteSpace($ReceiptPath)) { return }
    $parent = Split-Path -Parent $ReceiptPath
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temp = "$ReceiptPath.tmp.$PID"
    [IO.File]::WriteAllText(
        $temp,
        ($Receipt | ConvertTo-Json -Depth 12),
        (New-Object Text.UTF8Encoding($false))
    )
    Move-Item -LiteralPath $temp -Destination $ReceiptPath -Force
}

$validator = Join-Path $RepoRoot 'scripts\validate_public_snapshot.ps1'
$loaderSource = Join-Path $RepoRoot 'scripts\public_site\stats-loader.js'
$deployPublicDir = Join-Path $DeployRepo 'Website\public-data'
$deployLoader = Join-Path $DeployRepo 'Website\scripts\stats-loader.js'
$deployGitDir = Join-Path $DeployRepo '.git'
foreach ($required in @($validator, $loaderSource, $DataDir, $SchemaDir, $deployGitDir)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required publisher path missing: $required"
    }
}

$validatorCommand = @(
    'powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    (Quote-CommandArgument $validator), '-RepoRoot',
    (Quote-CommandArgument $RepoRoot), '-DataDir',
    (Quote-CommandArgument $DataDir)
) -join ' '

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator `
    -RepoRoot $RepoRoot -DataDir $DataDir
if ($LASTEXITCODE -ne 0) {
    throw "public snapshot validation failed with exit code $LASTEXITCODE"
}

$mappings = @(
    @{ Source = Join-Path $DataDir 'public-snapshot.json'; Target = Join-Path $deployPublicDir 'public-snapshot.json'; Relative = 'Website/public-data/public-snapshot.json' },
    @{ Source = Join-Path $DataDir 'process-roadmap.json'; Target = Join-Path $deployPublicDir 'process-roadmap.json'; Relative = 'Website/public-data/process-roadmap.json' },
    @{ Source = Join-Path $DataDir 'strategy-archive.json'; Target = Join-Path $deployPublicDir 'strategy-archive.json'; Relative = 'Website/public-data/strategy-archive.json' },
    @{ Source = Join-Path $DataDir 'company-operating-model.json'; Target = Join-Path $deployPublicDir 'company-operating-model.json'; Relative = 'Website/public-data/company-operating-model.json' },
    @{ Source = Join-Path $DataDir 'stats.json'; Target = Join-Path $deployPublicDir 'stats.json'; Relative = 'Website/public-data/stats.json' },
    @{ Source = Join-Path $SchemaDir 'public-snapshot.schema.v2.json'; Target = Join-Path $deployPublicDir 'public-snapshot.schema.v2.json'; Relative = 'Website/public-data/public-snapshot.schema.v2.json' },
    @{ Source = Join-Path $SchemaDir 'process-roadmap.schema.json'; Target = Join-Path $deployPublicDir 'process-roadmap.schema.json'; Relative = 'Website/public-data/process-roadmap.schema.json' },
    @{ Source = Join-Path $SchemaDir 'strategy-archive.schema.v2.json'; Target = Join-Path $deployPublicDir 'strategy-archive.schema.v2.json'; Relative = 'Website/public-data/strategy-archive.schema.v2.json' },
    @{ Source = Join-Path $SchemaDir 'company-operating-model.schema.json'; Target = Join-Path $deployPublicDir 'company-operating-model.schema.json'; Relative = 'Website/public-data/company-operating-model.schema.json' },
    @{ Source = Join-Path $SchemaDir 'public-stats.schema.json'; Target = Join-Path $deployPublicDir 'public-stats.schema.json'; Relative = 'Website/public-data/public-stats.schema.json' },
    @{ Source = $loaderSource; Target = $deployLoader; Relative = 'Website/scripts/stats-loader.js' }
)

$files = New-Object Collections.Generic.List[object]
$plannedCommands = New-Object Collections.Generic.List[string]
$executedCommands = New-Object Collections.Generic.List[string]
$plannedCommands.Add($validatorCommand)
$executedCommands.Add($validatorCommand)
$changed = New-Object Collections.Generic.List[object]

foreach ($mapping in $mappings) {
    if (-not (Test-Path -LiteralPath $mapping.Source -PathType Leaf)) {
        throw "Allowlisted publisher source missing: $($mapping.Source)"
    }
    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $mapping.Source).Hash.ToLowerInvariant()
    $targetHash = if (Test-Path -LiteralPath $mapping.Target -PathType Leaf) {
        (Get-FileHash -Algorithm SHA256 -LiteralPath $mapping.Target).Hash.ToLowerInvariant()
    } else { '' }
    $isChanged = $sourceHash -ne $targetHash
    $copyCommand = "Copy-Item -LiteralPath $(Quote-CommandArgument $mapping.Source) -Destination $(Quote-CommandArgument $mapping.Target) -Force"
    if ($isChanged) {
        $plannedCommands.Add($copyCommand)
        $changed.Add($mapping)
        if ($Apply) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $mapping.Target) -Force | Out-Null
            $temp = "$($mapping.Target).tmp.$PID"
            Copy-Item -LiteralPath $mapping.Source -Destination $temp -Force
            Move-Item -LiteralPath $temp -Destination $mapping.Target -Force
            $readbackHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $mapping.Target).Hash.ToLowerInvariant()
            if ($readbackHash -ne $sourceHash) {
                throw "Publisher readback hash mismatch: $($mapping.Target)"
            }
            $executedCommands.Add($copyCommand)
        }
    }
    $files.Add([ordered]@{
        source = $mapping.Source
        target = $mapping.Target
        relative_target = $mapping.Relative
        sha256 = $sourceHash
        changed = $isChanged
    })
}

$relativeTargets = @($mappings | ForEach-Object { $_.Relative })
$quotedTargets = @($relativeTargets | ForEach-Object { Quote-CommandArgument $_ })
$gitAddCommand = "git -C $(Quote-CommandArgument $DeployRepo) add -- $($quotedTargets -join ' ')"
$gitCommitCommand = "git -C $(Quote-CommandArgument $DeployRepo) commit -m `"web: refresh validated public data`" -- $($quotedTargets -join ' ')"
$gitPushCommand = "git -C $(Quote-CommandArgument $DeployRepo) push"
$publishCommands = @(
    @($plannedCommands | ForEach-Object { $_ }) +
    @($gitAddCommand, $gitCommitCommand, $gitPushCommand)
)
if ($Commit) {
    $plannedCommands.Add($gitAddCommand)
    $plannedCommands.Add($gitCommitCommand)
    Invoke-GitChecked -Arguments (@('-C', $DeployRepo, 'add', '--') + $relativeTargets)
    $executedCommands.Add($gitAddCommand)
    $staged = @(& git.exe -C $DeployRepo diff --cached --name-only -- @relativeTargets)
    if ($LASTEXITCODE -ne 0) { throw 'git staged-diff inspection failed' }
    if ($staged.Count -gt 0) {
        Invoke-GitChecked -Arguments (@('-C', $DeployRepo, 'commit', '-m', 'web: refresh validated public data', '--') + $relativeTargets)
        $executedCommands.Add($gitCommitCommand)
    }
}
if ($Push) {
    $plannedCommands.Add($gitPushCommand)
    Invoke-GitChecked -Arguments @('-C', $DeployRepo, 'push')
    $executedCommands.Add($gitPushCommand)
}

$mode = if ($Push) {
    'PUBLISH'
} elseif ($Commit) {
    'LOCAL_COMMIT'
} elseif ($Apply) {
    'APPLY_NO_GIT'
} else {
    'DRY_RUN'
}
$receipt = [ordered]@{
    schema = 'qm.public-data-deploy-sync-receipt/v1'
    generated_at_utc = [datetime]::UtcNow.ToString('o')
    mode = $mode
    validation_passed = $true
    apply_requested = [bool]$Apply
    commit_requested = [bool]$Commit
    push_requested = [bool]$Push
    deploy_repo = $DeployRepo
    netlify_toml_changed = $false
    files = @($files | ForEach-Object { $_ })
    changed_file_count = $changed.Count
    planned_commands = @($plannedCommands | ForEach-Object { $_ })
    publish_commands = $publishCommands
    executed_commands = @($executedCommands | ForEach-Object { $_ })
}
Write-Receipt -Receipt $receipt
$receipt | ConvertTo-Json -Depth 12
