param(
    [Parameter(Mandatory = $true)]
    [string]$EaSlug,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Z0-9._]+\.DWX$')]
    [string]$Symbol,
    [Parameter(Mandatory = $true)]
    [ValidateSet('M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1', 'MN1')]
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
$cardsRoot = Join-Path $repoRoot 'strategy-seeds\cards'

function Find-CardPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CardsRoot,
        [Parameter(Mandatory = $true)]
        [string]$EaSlug
    )

    if (-not (Test-Path -LiteralPath $CardsRoot)) {
        return $null
    }

    $base = $EaSlug -replace '^QM5_[^_]+_', ''
    if ([string]::IsNullOrWhiteSpace($base)) {
        return $null
    }
    $slug = $base.Replace('_', '-')
    $candidate = Join-Path $CardsRoot ($slug + '_card.md')
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }

    # Fallback: strategy_id-based slug (e.g., QM5_SRC04_S03_...)
    if ($EaSlug -match '^QM5_(SRC\d+_S\d+)_') {
        $strategyId = $matches[1]
        $cardFiles = Get-ChildItem -Path $CardsRoot -Filter '*_card.md' -File -ErrorAction SilentlyContinue
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

    # Fallback: resolve slug from ea_id_registry.csv (ea_id -> strategy slug)
    if ($EaSlug -match '^QM5_(\d+)_') {
        $eaId = $matches[1]
        $repoRootGuess = Split-Path -Parent (Split-Path -Parent $CardsRoot)
        $registryPath = Join-Path $repoRootGuess 'framework\registry\ea_id_registry.csv'
        if (Test-Path -LiteralPath $registryPath) {
            try {
                $rows = Import-Csv -LiteralPath $registryPath
                $row = $rows | Where-Object { $_.ea_id -eq $eaId } | Select-Object -First 1
                if ($row -and $row.slug) {
                    $slug2 = [string]$row.slug
                    $candidate2 = Join-Path $CardsRoot ($slug2 + '_card.md')
                    if (Test-Path -LiteralPath $candidate2) {
                        return $candidate2
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
    if (Test-Path -LiteralPath $registryPath) {
        $magicRow = Import-Csv -LiteralPath $registryPath |
            Where-Object { $_.ea_id -eq ([int]$eaId).ToString() -and $_.symbol -eq $Symbol -and $_.status -eq 'active' } |
            Select-Object -First 1
        if ($magicRow) {
            $magicSlot = [int]$magicRow.symbol_slot
        }
    }
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
    "qm_magic_slot_offset=$magicSlot",
    "RISK_FIXED=$RiskFixed",
    "RISK_PERCENT=$RiskPercent",
    "PORTFOLIO_WEIGHT=$PortfolioWeight",
    "; core filter library params; filter-on/off variants must be pre-declared",
    "qm_filter_news_enabled=1",
    "qm_filter_news_mode=3",
    "qm_filter_regime_enabled=0",
    "qm_filter_regime_lookback_bars=100",
    "qm_filter_regime_bull_return_pct=2.0",
    "qm_filter_regime_bear_return_pct=2.0",
    "qm_filter_volatility_enabled=0",
    "qm_filter_volatility_atr_period=14",
    "qm_filter_volatility_lookback_bars=50",
    "qm_filter_volatility_compression_ratio=0.75",
    "qm_filter_volatility_expansion_ratio=1.25",
    "; strategy-specific params from card must be appended below this line"
)

$cardPath = Find-CardPath -CardsRoot $cardsRoot -EaSlug $EaSlug
if ($cardPath) {
    $defaults = Parse-CardDefaults -CardPath $cardPath
    $defaults = Normalize-CardDefaultsForSetfile -EaSlug $EaSlug -Defaults $defaults
    if ($defaults.Count -gt 0) {
        $lines += "; card_defaults_source=$cardPath"
        foreach ($k in $defaults.Keys) {
            $lines += "$k=$($defaults[$k])"
        }
    }
    else {
        $lines += "; card_defaults_source=$cardPath"
        $lines += "; card_defaults_status=none_found"
    }
}
else {
    $lines += "; card_defaults_source=not_found"
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
