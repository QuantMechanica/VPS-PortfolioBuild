<#
.SYNOPSIS
  Shared, side-effect-free parsing library for MT5 live `.chr` profile contracts.

.DESCRIPTION
  This is the SINGLE source of truth for the MetaTrader `.chr` chart-contract
  grammar used across the live-deployment tooling. It exists so the two
  fail-closed PowerShell verifiers

      prepare_dxz_v2_liveops_profile.ps1
      verify_ftmo_round25_live_contract.ps1

  and the read-only Python verifier

      verify_live_deployment_contract.py   (WS-E3)

  all parse `.chr` files through ONE implementation instead of three divergent
  copies. The two PowerShell scripts dot-source this file and delegate; the
  Python tool invokes the JSON adapter mode below.

  DOT-SOURCING IS SAFE. When dot-sourced with no parameters this file only
  DEFINES functions -- it reads nothing, writes nothing, and has no top-level
  side effect. (This is why the "generalize the existing parsers" refactor is
  option (a) -- a shared module both PS scripts and the Python tool consume --
  rather than option (b): the two existing scripts are NOT import-safe. Their
  own bodies run T_Live-mutating / verify-and-exit logic on execution, so
  "invoking their existing functions" from Python is impossible without first
  extracting the grammar into an import-safe unit -- which is exactly this file.)

  ADAPTER MODE. Invoked as a script with a parameter it emits JSON to stdout and
  exits, reading only the given path(s):

      pwsh -NoProfile -File liveops_profile_contract.ps1 -EmitProfileJson <dir>
          -> { "charts": [ <chart record>, ... ] } for every chart*.chr in <dir>
      pwsh -NoProfile -File liveops_profile_contract.ps1 -EmitChartJson <file>
          -> a single <chart record>
      pwsh -NoProfile -File liveops_profile_contract.ps1 -EmitCommonIni <file>
          -> { "Login": <str|null>, "Server": <str|null> }

  A <chart record> is a TOLERANT parse (records rather than throws on a bad
  chart -- empty/0-byte, multi-expert, missing header) so a downstream verifier
  can classify. Get-ChartContract by contrast is the STRICT parse the two PS
  verifiers already relied on (throws on anything off-contract). Both share the
  same underlying grammar (Get-ChartExperts + the field regexes), which is the
  whole point.

  STRICTLY READ-ONLY. Nothing here writes a file or touches a database.
#>
[CmdletBinding()]
param(
    [string]$EmitProfileJson,
    [string]$EmitChartJson,
    [string]$EmitCommonIni
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Primitives (identical semantics to the copies previously inlined in the two
# PowerShell verifiers).
# ---------------------------------------------------------------------------
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Sha256 {
    param([string]$Path)
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "missing file: $Path"
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToUpperInvariant()
}

function Get-UniqueValue {
    # Strict single-assignment reader (from verify_ftmo_round25_live_contract.ps1).
    param([string]$Text, [string]$Key, [string]$Context)
    $found = [regex]::Matches($Text, "(?m)^$([regex]::Escape($Key))=([^`r`n]*)`r?$")
    Assert-True ($found.Count -eq 1) "expected exactly one '$Key' in $Context; found $($found.Count)"
    return $found[0].Groups[1].Value
}

function Get-IniValue {
    # Non-throwing first-assignment reader for a flat INI (returns $null if absent).
    param([string]$Text, [string]$Key)
    $m = [regex]::Match($Text, "(?m)^$([regex]::Escape($Key))=([^`r`n]*)`r?$")
    if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}

# ---------------------------------------------------------------------------
# The .chr grammar -- the single source of truth.
# ---------------------------------------------------------------------------
function Get-ChartExperts {
    # Every <expert>...</expert> block in a chart's text. THE grammar anchor:
    # both PS verifiers and the Python tool agree on exactly-one-expert via this.
    # The leading comma returns the MatchCollection as a single object so callers
    # get a stable .Count / indexer instead of a pipeline-unrolled array.
    param([string]$Text)
    return , [regex]::Matches($Text, '(?ms)<expert>\s*.*?</expert>')
}

function Get-ChartField {
    # Non-throwing single field read from a chart or expert block.
    param([string]$Text, [string]$Key)
    $m = [regex]::Match($Text, "(?m)^$([regex]::Escape($Key))=(.+?)\r?`$")
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return $null
}

function Get-ChartContract {
    # STRICT parse used by the two fail-closed PowerShell verifiers. Throws on
    # anything off-contract. Returns a superset of the fields the old private
    # Get-ChartContract (prepare_dxz) returned, so callers are unaffected.
    param([string]$Path)
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "missing chart: $Path"
    $text = [IO.File]::ReadAllText($Path)
    $experts = Get-ChartExperts $text
    Assert-True ($experts.Count -eq 1) "expected exactly one expert in $Path"
    $prefix = $text.Substring(0, $experts[0].Index)
    $symbol = [regex]::Match($prefix, '(?m)^symbol=(.+?)\r?$')
    $periodType = [regex]::Match($prefix, '(?m)^period_type=(.+?)\r?$')
    $periodSize = [regex]::Match($prefix, '(?m)^period_size=(.+?)\r?$')
    Assert-True ($symbol.Success -and $periodType.Success -and $periodSize.Success) "chart header incomplete: $Path"
    return [pscustomobject]@{
        text        = $text
        prefix      = $prefix
        expert      = $experts[0].Value.Trim()
        n_experts   = $experts.Count
        symbol      = $symbol.Groups[1].Value.Trim()
        period_type = $periodType.Groups[1].Value.Trim()
        period_size = $periodSize.Groups[1].Value.Trim()
    }
}

function Get-ChartRecord {
    # TOLERANT parse for downstream classifiers (the Python WS-E3 verifier).
    # Never throws on a bad chart -- records the problem in .error so the caller
    # can distinguish MISSING / EMPTY / UNPARSEABLE / DUPLICATE-expert.
    param([string]$Path)
    $rec = [ordered]@{
        file        = [IO.Path]::GetFileName($Path)
        exists      = $false
        size        = 0
        empty       = $false
        bom         = 'none'
        n_experts   = 0
        symbol      = $null
        period_type = $null
        period_size = $null
        expert      = $null
        error       = $null
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $rec.error = 'file does not exist'
        return $rec
    }
    $rec.exists = $true
    $bytes = [IO.File]::ReadAllBytes($Path)
    $rec.size = $bytes.Length
    if ($bytes.Length -eq 0) {
        $rec.empty = $true
        $rec.error = 'empty file (0 bytes) -- MT5 truncated/lost the chart'
        return $rec
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $rec.bom = 'utf-16-le' }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { $rec.bom = 'utf-16-be' }
    elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $rec.bom = 'utf-8-sig' }
    else { $rec.bom = 'none' }

    try { $text = [IO.File]::ReadAllText($Path) }
    catch { $rec.error = "decode error: $($_.Exception.Message)"; return $rec }
    if ([string]::IsNullOrWhiteSpace($text)) {
        $rec.empty = $true
        $rec.error = 'whitespace-only file'
        return $rec
    }

    $experts = Get-ChartExperts $text
    $rec.n_experts = $experts.Count
    $prefix = if ($experts.Count -ge 1) { $text.Substring(0, $experts[0].Index) } else { $text }
    $rec.symbol = Get-ChartField $prefix 'symbol'
    $rec.period_type = Get-ChartField $prefix 'period_type'
    $rec.period_size = Get-ChartField $prefix 'period_size'
    if ($experts.Count -ne 1) {
        $rec.error = "expected exactly one <expert> block, found $($experts.Count)"
        return $rec
    }
    $ex = $experts[0].Value
    $rec.expert = [ordered]@{
        name                 = Get-ChartField $ex 'name'
        path                 = Get-ChartField $ex 'path'
        expertmode           = Get-ChartField $ex 'expertmode'
        qm_ea_id             = Get-ChartField $ex 'qm_ea_id'
        qm_magic_slot_offset = Get-ChartField $ex 'qm_magic_slot_offset'
        RISK_PERCENT         = Get-ChartField $ex 'RISK_PERCENT'
        RISK_FIXED           = Get-ChartField $ex 'RISK_FIXED'
        PORTFOLIO_WEIGHT     = Get-ChartField $ex 'PORTFOLIO_WEIGHT'
        qm_risk_cap_pct      = Get-ChartField $ex 'qm_risk_cap_pct'
    }
    return $rec
}

# ---------------------------------------------------------------------------
# Adapter mode (only runs when invoked as a script with a parameter). Emits
# JSON to stdout and exits; reads only the given path(s).
# ---------------------------------------------------------------------------
if ($EmitProfileJson) {
    Assert-True (Test-Path -LiteralPath $EmitProfileJson -PathType Container) "profile dir not found: $EmitProfileJson"
    $charts = @()
    foreach ($f in (Get-ChildItem -LiteralPath $EmitProfileJson -Filter 'chart*.chr' -File | Sort-Object Name)) {
        $charts += , (Get-ChartRecord $f.FullName)
    }
    [pscustomobject]@{
        profile_dir = (Resolve-Path -LiteralPath $EmitProfileJson).ProviderPath
        n_charts    = $charts.Count
        charts      = @($charts)
    } | ConvertTo-Json -Depth 8
    exit 0
}
if ($EmitChartJson) {
    Get-ChartRecord $EmitChartJson | ConvertTo-Json -Depth 8
    exit 0
}
if ($EmitCommonIni) {
    Assert-True (Test-Path -LiteralPath $EmitCommonIni -PathType Leaf) "common.ini not found: $EmitCommonIni"
    $text = [IO.File]::ReadAllText($EmitCommonIni)
    [pscustomobject]@{
        Login  = (Get-IniValue $text 'Login')
        Server = (Get-IniValue $text 'Server')
    } | ConvertTo-Json
    exit 0
}
