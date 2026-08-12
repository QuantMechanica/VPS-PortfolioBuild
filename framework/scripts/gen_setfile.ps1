param(
    [Parameter(Mandatory = $true)]
    [string]$EaSlug,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Z0-9._]+\.DWX$')]
    [string]$Symbol,
    [Parameter(Mandatory = $true)]
    [ValidateSet('M1', 'M2', 'M5', 'M10', 'M15', 'M30', 'H1', 'H2', 'H3', 'H4', 'H6', 'H8', 'H12', 'D1', 'W1', 'MN1')]
    [string]$TF,
    [ValidateSet('backtest', 'demo', 'shadow', 'live')]
    [string]$Env = 'backtest',
    [double]$RiskFixed = 1000,
    [double]$RiskPercent = 0,
    [double]$PortfolioWeight = 1.0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$easRoot = Join-Path $repoRoot 'framework\EAs'
$farmCardsRoot = $null
if (-not [string]::IsNullOrWhiteSpace(${env:QM_STRATEGY_FARM_ROOT})) {
    $farmCardsRoot = Join-Path ${env:QM_STRATEGY_FARM_ROOT} 'artifacts\cards_approved'
}

$cardsRoots = @(
    (Join-Path $repoRoot 'strategy-seeds\cards'),
    (Join-Path $repoRoot 'strategy-seeds\cards\approved'),
    (Join-Path $repoRoot 'artifacts\cards_approved'),
    $farmCardsRoot,
    'D:\QM\strategy_farm\artifacts\cards_approved'
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

function Find-CardPath {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$CardsRoots,
        [Parameter(Mandatory = $true)]
        [string]$EaSlug
    )

    $base = $EaSlug -replace '^QM5_[^_]+_', ''
    if ([string]::IsNullOrWhiteSpace($base)) {
        return $null
    }
    $slug = $base.Replace('_', '-')

    foreach ($CardsRoot in $CardsRoots) {
        $exact = Join-Path $CardsRoot ($EaSlug + '.md')
        if (Test-Path -LiteralPath $exact) {
            return $exact
        }
        $candidate = Join-Path $CardsRoot ($slug + '_card.md')
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    # Fallback: strategy_id-based slug (e.g., QM5_SRC04_S03_...)
    if ($EaSlug -match '^QM5_(SRC\d+_S\d+)_') {
        $strategyId = $matches[1]
        foreach ($CardsRoot in $CardsRoots) {
            $cardFiles = Get-ChildItem -Path $CardsRoot -Filter '*.md' -File -ErrorAction SilentlyContinue
            foreach ($cf in $cardFiles) {
                try {
                    $head = Get-Content -LiteralPath $cf.FullName -TotalCount 80
                    if ($head -match ("strategy_id:\s*" + [regex]::Escape($strategyId))) {
                        return $cf.FullName
                    }
                } catch {
                    continue
                }
            }
        }
    }

    # Fallback: resolve slug from ea_id_registry.csv (ea_id -> strategy slug)
    if ($EaSlug -match '^QM5_(\d+)_') {
        $eaId = $matches[1]
        $registryPath = Join-Path $repoRoot 'framework\registry\ea_id_registry.csv'
        if (Test-Path -LiteralPath $registryPath) {
            try {
                $rows = Import-Csv -LiteralPath $registryPath
                $row = $rows | Where-Object { $_.ea_id -eq $eaId } | Select-Object -First 1
                if ($row -and $row.slug) {
                    $slug2 = [string]$row.slug
                    foreach ($CardsRoot in $CardsRoots) {
                        $candidate2 = Join-Path $CardsRoot ($slug2 + '_card.md')
                        if (Test-Path -LiteralPath $candidate2) {
                            return $candidate2
                        }
                    }
                }
            } catch {
                # best-effort fallback only
            }
        }
    }
    return $null
}

function Parse-CardDefaults {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CardPath
    )

    $out = [ordered]@{}
    $lines = Get-Content -LiteralPath $CardPath
    if (-not $lines -or $lines.Count -eq 0) {
        return $out
    }

    # Current approved-card format: a markdown table headed "param | default".
    $inParamTable = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*##\s+') {
            $inParamTable = $false
        }
        if ($line -match '^\s*\|\s*param\s*\|\s*default\s*\|') {
            $inParamTable = $true
            continue
        }
        if ($inParamTable) {
            if ($line -match '^\s*\|\s*-+\s*\|') {
                continue
            }
            if ($line -notmatch '^\s*\|') {
                $inParamTable = $false
                continue
            }
            if ($line -match '^\s*\|\s*`?([A-Za-z_][A-Za-z0-9_]*)`?\s*\|\s*`?([^|`]+?)`?\s*\|') {
                $k = $matches[1].Trim()
                $v = $matches[2].Trim().Trim('"').Trim()
                if ($k -and $v -and $k -notin @('param', 'parameter', 'name')) {
                    $out[$k] = $v
                }
            }
        }
    }

    # Current YAML-like parameter list format: "- name: X" followed by "default: Y".
    $currName = $null
    foreach ($line in $lines) {
        if ($line -match '^\s*-\s*name:\s*([A-Za-z_][A-Za-z0-9_]*)\s*$') {
            $currName = $matches[1].Trim()
            continue
        }
        if ($currName -and $line -match '^\s*default:\s*([^#\r\n]+)') {
            $v = $matches[1].Trim().Trim('"')
            if ($v -and $v -ne 'TBD' -and $v -ne 'NOT_SPECIFIED') {
                $out[$currName] = $v
            }
            $currName = $null
            continue
        }
    }

    # Section 4 parser: captures "PARAMETERS" bullets like "- SSL1 = 0.75"
    $inSection4 = $false
    $inParameters = $false
    foreach ($line in $lines) {
        if ($line -match '^##\s+4\.') {
            $inSection4 = $true
            $inParameters = $false
            continue
        }
        if ($inSection4 -and $line -match '^##\s+') {
            $inSection4 = $false
            $inParameters = $false
        }
        if (-not $inSection4) { continue }

        if ($line -match '^\s*PARAMETERS\b') {
            $inParameters = $true
            continue
        }

        if ($inParameters) {
            if ($line -match '^\s*-\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^/\r\n#]+)') {
                $k = $matches[1].Trim()
                $v = $matches[2].Trim().Trim('"')
                if ($k -and $v) { $out[$k] = $v }
                continue
            }
            if ($line -match '^\s*-\s*`?([A-Za-z_][A-Za-z0-9_]*)`?\s+default\s+`?([^`\r\n#]+)`?') {
                $k = $matches[1].Trim()
                $v = $matches[2].Trim().Trim('"')
                if ($k -and $v) { $out[$k] = $v }
                continue
            }
            if ($line -match '^\s*$' -or $line -match '^\s*[A-Z][A-Za-z ]+[:]?$') {
                $inParameters = $false
            }
        }
    }

    # Also capture "default" bullet style from section 6 when present.
    $inSection6 = $false
    foreach ($line in $lines) {
        if ($line -match '^##\s+6\.') { $inSection6 = $true; continue }
        if ($inSection6 -and $line -match '^##\s+') { $inSection6 = $false }
        if (-not $inSection6) { continue }
        if ($line -match '^\s*-\s*`?([A-Za-z_][A-Za-z0-9_]*)`?\s+default\s+`?([^`\r\n#]+)`?') {
            $k = $matches[1].Trim()
            $v = $matches[2].Trim().Trim('"')
            if ($k -and $v) { $out[$k] = $v }
        }
    }

    # Section 8 parser: captures YAML defaults per "- name: X" + "default: Y"
    $inSection8 = $false
    $currName = $null
    foreach ($line in $lines) {
        if ($line -match '^##\s+8\.') {
            $inSection8 = $true
            $currName = $null
            continue
        }
        if ($inSection8 -and $line -match '^##\s+') {
            $inSection8 = $false
            $currName = $null
        }
        if (-not $inSection8) { continue }

        if ($line -match '^\s*-\s*name:\s*([A-Za-z_][A-Za-z0-9_]*)\s*$') {
            $currName = $matches[1].Trim()
            continue
        }
        if ($currName -and $line -match '^\s*default:\s*([^#\r\n]+)') {
            $v = $matches[1].Trim().Trim('"')
            if ($v -and $v -ne 'TBD' -and $v -ne 'NOT_SPECIFIED') {
                $out[$currName] = $v
            }
            $currName = $null
            continue
        }
    }

    return $out
}

function Get-EAInputDefaults {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EAFolder
    )

    $result = [ordered]@{
        all = [ordered]@{}
        strategy = [ordered]@{}
        types = [ordered]@{}
    }

    $mq5 = Get-ChildItem -LiteralPath $EAFolder -Filter '*.mq5' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $mq5) {
        return $result
    }

    $group = ''
    foreach ($line in Get-Content -LiteralPath $mq5.FullName) {
        if ($line -match '^\s*input\s+group\s+"([^"]+)"') {
            $group = $matches[1]
            continue
        }
        if ($line -match '^\s*input\s+(?<type>[A-Za-z_][A-Za-z0-9_<>]*)\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?<value>[^;]+);') {
            $type = $matches['type'].Trim()
            $name = $matches['name'].Trim()
            $value = $matches['value'].Trim()
            $result.all[$name] = $value
            $result.types[$name] = $type
            # Legacy/current EAs are not consistent about input groups.  The
            # live-set invariant below already treats strategy_* as strategy
            # parameters, so collect the same prefix even outside a group.
            if ($group -eq 'Strategy' -or $name -like 'strategy_*') {
                $result.strategy[$name] = $value
            }
        }
    }

    return $result
}

function Convert-EAInputValueForSetfile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [Parameter(Mandatory = $true)]
        [hashtable]$InputTypes
    )

    if (-not $InputTypes.Contains($Name)) {
        return $Value
    }

    $inputType = [string]$InputTypes[$Name]
    if ($inputType -eq 'string') {
        # MT5 .set files treat all text after '=' as the runtime string value.
        # MQL source-literal quotes are therefore data here, not syntax: keeping
        # them breaks equality checks and FileOpen paths inside the EA.
        $candidate = $Value.Trim()
        if ($candidate.Length -ge 2 -and
            $candidate[0] -eq '"' -and
            $candidate[$candidate.Length - 1] -eq '"') {
            return $candidate.Substring(1, $candidate.Length - 2)
        }
        return $candidate
    }

    if ($inputType -ne 'ENUM_TIMEFRAMES') {
        return $Value
    }

    # MT5's tester report echoes symbolic PERIOD_* text from a .set file, but
    # the runtime enum receives zero (PERIOD_CURRENT).  Serialize the actual
    # MQL5 ENUM_TIMEFRAMES integer so the value observed by the EA is exact.
    $timeframeValues = @{
        PERIOD_CURRENT = 0
        PERIOD_M1 = 1; PERIOD_M2 = 2; PERIOD_M3 = 3; PERIOD_M4 = 4
        PERIOD_M5 = 5; PERIOD_M6 = 6; PERIOD_M10 = 10; PERIOD_M12 = 12
        PERIOD_M15 = 15; PERIOD_M20 = 20; PERIOD_M30 = 30
        PERIOD_H1 = 16385; PERIOD_H2 = 16386; PERIOD_H3 = 16387
        PERIOD_H4 = 16388; PERIOD_H6 = 16390; PERIOD_H8 = 16392
        PERIOD_H12 = 16396; PERIOD_D1 = 16408; PERIOD_W1 = 32769
        PERIOD_MN1 = 49153
    }
    $candidate = $Value.Trim()
    if ($timeframeValues.ContainsKey($candidate)) {
        return [string]$timeframeValues[$candidate]
    }
    if ($candidate -match '^-?\d+$') {
        return $candidate
    }
    throw "UNSUPPORTED_TIMEFRAME_SET_VALUE: input=$Name value=$Value"
}

function Add-DefaultsMatchingInputs {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Target,
        [Parameter(Mandatory = $true)]
        [hashtable]$Defaults,
        [Parameter(Mandatory = $true)]
        [hashtable]$InputDefaults
    )

    foreach ($k in $Defaults.Keys) {
        if ($InputDefaults.Contains($k)) {
            $Target[$k] = $Defaults[$k]
        }
    }
}

function Normalize-CardDefaultsForSetfile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EaSlug,
        [Parameter(Mandatory = $true)]
        [hashtable]$Defaults
    )

    $normalized = [ordered]@{}
    foreach ($k in $Defaults.Keys) {
        $normalized[$k] = $Defaults[$k]
    }

    # Compatibility mapping for cards that use source-level variable names instead of EA input names.
    if ($EaSlug -eq 'QM5_1003_davey_baseline_3bar') {
        if ($normalized.Contains('ssl') -and -not $normalized.Contains('ssl_usd_cap')) {
            $normalized['ssl_usd_cap'] = $normalized['ssl']
        }
        if ($normalized.Contains('ATR_period') -and -not $normalized.Contains('strategy_atr_period')) {
            $normalized['strategy_atr_period'] = $normalized['ATR_period']
        }
        if ($normalized.Contains('nContracts')) {
            $normalized.Remove('nContracts')
        }
        if ($normalized.Contains('ssl')) {
            $normalized.Remove('ssl')
        }
        if ($normalized.Contains('ATR_period')) {
            $normalized.Remove('ATR_period')
        }
    }

    return $normalized
}

if ($EaSlug -notmatch '^QM5_[A-Za-z0-9_-]+$') {
    throw "EaSlug must start with QM5_ and contain only letters, digits, underscores, and hyphens. Got: $EaSlug"
}

$eaFolder = Join-Path $easRoot $EaSlug
New-Item -ItemType Directory -Path $eaFolder -Force | Out-Null
$eaInputDefaults = Get-EAInputDefaults -EAFolder $eaFolder

$setsFolder = Join-Path $eaFolder 'sets'
New-Item -ItemType Directory -Path $setsFolder -Force | Out-Null

$fileName = "${EaSlug}_${Symbol}_${TF}_${Env}.set"
$targetPath = Join-Path $setsFolder $fileName

if ($Env -eq 'backtest') {
    if ($RiskFixed -le 0) {
        throw "For Env=backtest, RiskFixed must be > 0."
    }
    if ($RiskPercent -ne 0) {
        throw "For Env=backtest, RiskPercent must be 0."
    }
}

$eaId = ''
$eaSlugOnly = $EaSlug
$magicSlot = 0
if ($EaSlug -match '^QM5_(\d+)_(.+)$') {
    $eaId = $matches[1]
    $eaSlugOnly = $matches[2]
    $registryPath = Join-Path $repoRoot 'framework\registry\magic_numbers.csv'
    # 2026-07-06 audit G9: a missing active registry row previously defaulted
    # SILENTLY to slot 0 — a collision-prone artifact that QM_MagicRegistered
    # would happily validate (slot-0 magic IS registered, just for the wrong
    # symbol). The operating rule (dirs -> CSV -> regen -> verify -> compile)
    # requires the row to exist BEFORE setfile generation; enforce it.
    if (-not (Test-Path -LiteralPath $registryPath)) {
        throw "MAGIC_REGISTRY_MISSING: $registryPath not found; cannot resolve symbol_slot for $EaSlug $Symbol."
    }
    $magicRow = Import-Csv -LiteralPath $registryPath |
        Where-Object { $_.ea_id -eq ([int]$eaId).ToString() -and $_.symbol -eq $Symbol -and $_.status -eq 'active' } |
        Select-Object -First 1
    if (-not $magicRow) {
        throw "MAGIC_REGISTRY_ROW_MISSING: no active magic_numbers.csv row for ea_id=$eaId symbol=$Symbol; register the slot before generating setfiles (order-of-operations rule)."
    }
    $magicSlot = [int]$magicRow.symbol_slot
}

$today = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
$lines = @(
    ";==========================================================",
    "; QM5 Set File",
    "; ea_id:        $eaId",
    "; ea_slug:      $eaSlugOnly",
    "; ea_version:   v5.0",
    "; set_version:  s$($today.Replace('-', ''))-001",
    "; symbol:       $Symbol",
    "; timeframe:    $TF",
    "; environment:  $Env",
    "; magic_slot:   $magicSlot",
    "; risk_mode:    $(if ($Env -eq 'backtest') { 'FIXED' } else { 'PERCENT' })",
    "; portfolio_weight: $PortfolioWeight",
    "; build_hash:   pending",
    "; author:       Development",
    "; date:         $today",
    ";==========================================================",
    "qm_ea_id=$eaId",
    "qm_magic_slot_offset=$magicSlot",
    "RISK_FIXED=$RiskFixed",
    "RISK_PERCENT=$RiskPercent",
    "PORTFOLIO_WEIGHT=$PortfolioWeight",
    "; strategy-specific params from card/input defaults must be appended below this line"
)

$cardPath = Find-CardPath -CardsRoots $cardsRoots -EaSlug $EaSlug
if ($cardPath) {
    $defaults = Parse-CardDefaults -CardPath $cardPath
    $defaults = Normalize-CardDefaultsForSetfile -EaSlug $EaSlug -Defaults $defaults
    $setDefaults = [ordered]@{}
    Add-DefaultsMatchingInputs -Target $setDefaults -Defaults $defaults -InputDefaults $eaInputDefaults.all
    foreach ($k in $eaInputDefaults.strategy.Keys) {
        if (-not $setDefaults.Contains($k)) {
            $setDefaults[$k] = $eaInputDefaults.strategy[$k]
        }
    }
    if ($setDefaults.Count -gt 0) {
        $lines += "; card_defaults_source=$cardPath"
        foreach ($k in $setDefaults.Keys) {
            $serialized = Convert-EAInputValueForSetfile -Name $k -Value ([string]$setDefaults[$k]) -InputTypes $eaInputDefaults.types
            $lines += "$k=$serialized"
        }
    }
    else {
        $lines += "; card_defaults_source=$cardPath"
        $lines += "; card_defaults_status=none_found"
    }
}
else {
    # A missing card must not silently create a parameter-empty setfile.  The
    # EA source is the authoritative fallback for explicit input defaults.
    if ($eaInputDefaults.strategy.Count -gt 0) {
        $lines += "; card_defaults_source=ea_input_defaults"
        foreach ($k in $eaInputDefaults.strategy.Keys) {
            $serialized = Convert-EAInputValueForSetfile -Name $k -Value ([string]$eaInputDefaults.strategy[$k]) -InputTypes $eaInputDefaults.types
            $lines += "$k=$serialized"
        }
    }
    else {
        $lines += "; card_defaults_source=not_found"
    }
}

if ($Env -eq 'live' -and -not ($lines | Where-Object { $_ -match '^strategy_[A-Za-z0-9_]+\s*=' })) {
    throw "LIVE_SETFILE_STRATEGY_PARAMS_MISSING: $EaSlug $Symbol $TF would produce a live setfile without explicit strategy_* params."
}

$content = ($lines -join "`n") + "`n"
[System.IO.File]::WriteAllText($targetPath, $content, [System.Text.UTF8Encoding]::new($false))

$sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $targetPath).Hash.ToLowerInvariant()
[pscustomobject]@{
    status = 'ok'
    ea = $EaSlug
    env = $Env
    symbol = $Symbol
    tf = $TF
    card_path = $cardPath
    setfile_path = $targetPath
    setfile_sha256 = $sha
} | ConvertTo-Json -Depth 4
