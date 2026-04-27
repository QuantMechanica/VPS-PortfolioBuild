[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReportPath,
    [string]$TokenPath,
    [switch]$Recurse,
    [switch]$NoBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    return $repoRoot.Path
}

function Get-ReportFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,
        [switch]$Recursive
    )

    $resolved = Resolve-Path -LiteralPath $InputPath
    $targetPath = $resolved.Path

    if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
        return @(Get-Item -LiteralPath $targetPath)
    }

    $files = Get-ChildItem -LiteralPath $targetPath -File -Include "*.htm", "*.html" -Recurse:$Recursive.IsPresent
    return @($files)
}

function New-BrandCss {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Tokens
    )

    $bg = $Tokens.color.surface.bg
    $surface0 = $Tokens.color.surface.surface_0
    $surface1 = $Tokens.color.surface.surface_1
    $surface2 = $Tokens.color.surface.surface_2
    $border = $Tokens.color.border.default
    $borderStrong = $Tokens.color.border.strong
    $text = $Tokens.color.text.primary
    $textDim = $Tokens.color.text.dim
    $textMuted = $Tokens.color.text.muted
    $emerald = $Tokens.color.brand.emerald
    $emeraldLight = $Tokens.color.brand.emerald_light
    $fail = $Tokens.color.status.fail
    $warn = $Tokens.color.status.warn

    return @"
/* qm-brand-report-css-v1 */
:root {
  --qm-bg: $bg;
  --qm-surface-0: $surface0;
  --qm-surface-1: $surface1;
  --qm-surface-2: $surface2;
  --qm-border: $border;
  --qm-border-strong: $borderStrong;
  --qm-text: $text;
  --qm-text-dim: $textDim;
  --qm-text-muted: $textMuted;
  --qm-emerald: $emerald;
  --qm-emerald-light: $emeraldLight;
  --qm-fail: $fail;
  --qm-warn: $warn;
}
html, body {
  background: var(--qm-bg) !important;
  color: var(--qm-text) !important;
  font-family: Inter, "Segoe UI", Helvetica, sans-serif !important;
}
a {
  color: var(--qm-emerald) !important;
}
a:hover {
  color: var(--qm-emerald-light) !important;
}
table {
  width: 100%;
  border-collapse: collapse;
  background: var(--qm-surface-1);
  border: 1px solid var(--qm-border);
}
th, td {
  border: 1px solid var(--qm-border);
  padding: 6px 8px;
}
th {
  background: var(--qm-surface-2);
  color: var(--qm-text-dim);
}
tr:nth-child(even) td {
  background: var(--qm-surface-0);
}
h1, h2, h3, h4 {
  color: var(--qm-text);
  letter-spacing: -0.02em;
}
.qm-brand-report-banner {
  margin: 0 0 12px 0;
  padding: 10px 12px;
  background: var(--qm-surface-1);
  border: 1px solid var(--qm-border-strong);
  border-radius: 10px;
  font-weight: 700;
}
.qm-brand-report-banner .qm-left {
  color: var(--qm-text);
}
.qm-brand-report-banner .qm-right {
  color: var(--qm-emerald);
}
.qm-badge-pass, .profit, .positive {
  color: var(--qm-emerald) !important;
}
.qm-badge-fail, .loss, .negative {
  color: var(--qm-fail) !important;
}
.qm-badge-warn, .warning {
  color: var(--qm-warn) !important;
}
/* /qm-brand-report-css-v1 */
"@
}

function Inject-Branding {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Html,
        [Parameter(Mandatory = $true)]
        [string]$CssBlock
    )

    $styleBlock = "<style id=`"qm-brand-report-css-v1`">`n$CssBlock`n</style>"
    $banner = '<div class="qm-brand-report-banner"><span class="qm-left">Quant</span><span class="qm-right">Mechanica</span> <span>V5</span></div>'
    $result = $Html -replace "`r`n", "`n"

    $existingStyleRegex = '(?is)<style\s+id=["'']qm-brand-report-css-v1["''][^>]*>.*?</style>'
    $existingBannerRegex = '(?is)<div\s+class=["'']qm-brand-report-banner["''][^>]*>.*?</div>'
    $result = [regex]::Replace($result, $existingStyleRegex, "", 1)
    $result = [regex]::Replace($result, $existingBannerRegex, "", 1)

    if ($result -match '(?is)<head[^>]*>') {
        $result = [regex]::Replace($result, '(?is)<head[^>]*>', "`$0`n$styleBlock`n", 1)
    } else {
        $result = "$styleBlock`n$result"
    }

    $bodyTagRegex = '(?is)<body(?<attrs>[^>]*)>'
    $result = [regex]::Replace(
        $result,
        $bodyTagRegex,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            $attrs = $m.Groups["attrs"].Value

            if ($attrs -match '(?is)\bclass\s*=\s*"(?<classes>[^"]*)"') {
                $classes = $Matches["classes"]
                if ($classes -match '(?is)\bqm-brand-report\b') {
                    return $m.Value
                }

                $newClasses = "$classes qm-brand-report".Trim()
                return [regex]::Replace($m.Value, '(?is)\bclass\s*=\s*"[^"]*"', "class=`"$newClasses`"")
            }

            if ($attrs -match "(?is)\bclass\s*=\s*'(?<classes>[^']*)'") {
                $classes = $Matches["classes"]
                if ($classes -match '(?is)\bqm-brand-report\b') {
                    return $m.Value
                }

                $newClasses = "$classes qm-brand-report".Trim()
                return [regex]::Replace($m.Value, "(?is)\bclass\s*=\s*'[^']*'", "class='$newClasses'")
            }

            return "<body$attrs class=`"qm-brand-report`">"
        },
        1
    )

    if ($result -match $bodyTagRegex) {
        $result = [regex]::Replace($result, $bodyTagRegex, "`$0`n$banner`n", 1)
    }

    $result = [regex]::Replace($result, "`n{3,}", "`n`n")
    return $result.TrimEnd() + "`n"
}

$repoRoot = Resolve-RepoRoot
if (-not $TokenPath) {
    $TokenPath = Join-Path $repoRoot "branding\brand_tokens.json"
}

$tokenJson = Get-Content -Raw -LiteralPath $TokenPath | ConvertFrom-Json
$css = New-BrandCss -Tokens $tokenJson
$reportFiles = @(Get-ReportFiles -InputPath $ReportPath -Recursive:$Recurse.IsPresent)

if ($reportFiles.Count -eq 0) {
    throw "No .htm or .html files found at: $ReportPath"
}

$processed = 0
$updated = 0
$skipped = 0

foreach ($reportFile in $reportFiles) {
    if ($reportFile.Extension.ToLowerInvariant() -notin @(".htm", ".html")) {
        $skipped += 1
        continue
    }

    $processed += 1
    $original = Get-Content -Raw -LiteralPath $reportFile.FullName
    $branded = Inject-Branding -Html $original -CssBlock $css

    if ($original -eq $branded) {
        $skipped += 1
        continue
    }

    if (-not $NoBackup.IsPresent) {
        $backupPath = "$($reportFile.FullName).bak"
        [System.IO.File]::WriteAllText($backupPath, $original, [System.Text.UTF8Encoding]::new($false))
    }

    [System.IO.File]::WriteAllText($reportFile.FullName, $branded, [System.Text.UTF8Encoding]::new($false))
    $updated += 1
}

Write-Output "brand_report.processed=$processed"
Write-Output "brand_report.updated=$updated"
Write-Output "brand_report.skipped=$skipped"
Write-Output "brand_report.token_path=$TokenPath"
Write-Output "brand_report.report_path=$ReportPath"

if ($updated -eq 0) {
    exit 2
}

exit 0
