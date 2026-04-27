[CmdletBinding()]
param(
    [string]$TokenPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    return $repoRoot.Path
}

function Require-HexColor {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [Parameter(Mandatory = $true)]
        [string]$TokenName
    )

    if ($Value -notmatch "^#[0-9A-Fa-f]{6}$") {
        throw "Token '$TokenName' must be #RRGGBB, got '$Value'."
    }
}

function Convert-HexToMqlBgrLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Hex
    )

    $hex = $Hex.TrimStart("#")
    $r = $hex.Substring(0, 2).ToLowerInvariant()
    $g = $hex.Substring(2, 2).ToLowerInvariant()
    $b = $hex.Substring(4, 2).ToLowerInvariant()
    return "C'0x$b,0x$g,0x$r'"
}

function New-ColorDefineLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Hex
    )

    Require-HexColor -Value $Hex -TokenName $Name
    $literal = Convert-HexToMqlBgrLiteral -Hex $Hex
    return ("#define {0,-21} {1,-20} // {2}" -f $Name, $literal, $Hex.ToLowerInvariant())
}

$repoRootPath = Resolve-RepoRoot

if (-not $TokenPath) {
    $TokenPath = Join-Path $repoRootPath "branding\brand_tokens.json"
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRootPath "framework\include\QM_Branding.mqh"
}

$tokenJson = Get-Content -Raw -Path $TokenPath | ConvertFrom-Json

$colorLines = @(
    "// Surface",
    (New-ColorDefineLine -Name "QM_CLR_BG" -Hex $tokenJson.color.surface.bg),
    (New-ColorDefineLine -Name "QM_CLR_SURFACE_0" -Hex $tokenJson.color.surface.surface_0),
    (New-ColorDefineLine -Name "QM_CLR_SURFACE_1" -Hex $tokenJson.color.surface.surface_1),
    (New-ColorDefineLine -Name "QM_CLR_SURFACE_2" -Hex $tokenJson.color.surface.surface_2),
    "",
    "// Text",
    (New-ColorDefineLine -Name "QM_CLR_TEXT" -Hex $tokenJson.color.text.primary),
    (New-ColorDefineLine -Name "QM_CLR_TEXT_DIM" -Hex $tokenJson.color.text.dim),
    (New-ColorDefineLine -Name "QM_CLR_TEXT_MUTED" -Hex $tokenJson.color.text.muted),
    (New-ColorDefineLine -Name "QM_CLR_TEXT_SUBTLE" -Hex $tokenJson.color.text.subtle),
    (New-ColorDefineLine -Name "QM_CLR_TEXT_FAINT" -Hex $tokenJson.color.text.faint),
    "",
    "// Brand",
    (New-ColorDefineLine -Name "QM_CLR_EMERALD" -Hex $tokenJson.color.brand.emerald),
    (New-ColorDefineLine -Name "QM_CLR_EMERALD_LT" -Hex $tokenJson.color.brand.emerald_light),
    (New-ColorDefineLine -Name "QM_CLR_EMERALD_DARK" -Hex $tokenJson.color.brand.emerald_dark),
    "",
    "// Status",
    (New-ColorDefineLine -Name "QM_CLR_PASS" -Hex $tokenJson.color.status.pass),
    (New-ColorDefineLine -Name "QM_CLR_PROMISING" -Hex $tokenJson.color.status.promising),
    (New-ColorDefineLine -Name "QM_CLR_FAIL" -Hex $tokenJson.color.status.fail),
    (New-ColorDefineLine -Name "QM_CLR_DEAD" -Hex $tokenJson.color.status.dead),
    (New-ColorDefineLine -Name "QM_CLR_LIVE" -Hex $tokenJson.color.status.live),
    (New-ColorDefineLine -Name "QM_CLR_WARN" -Hex $tokenJson.color.status.warn),
    (New-ColorDefineLine -Name "QM_CLR_INFO" -Hex $tokenJson.color.status.info),
    "",
    "// MT5 font names (resolved by host OS)",
    ("#define {0,-21} ""{1}""" -f "QM_FONT_SANS", $tokenJson.typography.mt5_font_sans),
    ("#define {0,-21} ""{1}""" -f "QM_FONT_MONO", $tokenJson.typography.mt5_font_mono)
)

$generated = @(
    "#ifndef QM_BRANDING_MQH",
    "#define QM_BRANDING_MQH",
    "",
    "// ============================================================================",
    "// QuantMechanica V5 Branding Tokens for MQL5",
    "// Source: branding/brand_tokens.json",
    "// Generated mapping rule: RGB hex -> MQL5 BGR byte order in C'r,g,b'",
    "// ============================================================================",
    ""
) + $colorLines + @(
    "",
    "#endif // QM_BRANDING_MQH",
    ""
)

$newContent = $generated -join "`n"
$outputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$changed = $true
if (Test-Path $OutputPath) {
    $existing = Get-Content -Raw -Path $OutputPath
    $changed = $existing -ne $newContent
}

if ($changed) {
    [System.IO.File]::WriteAllText($OutputPath, $newContent, [System.Text.UTF8Encoding]::new($false))
}

$result = if ($changed) { "updated" } else { "no_change" }
Write-Output "sync_brand_tokens: $result"
Write-Output "token_path=$TokenPath"
Write-Output "output_path=$OutputPath"
