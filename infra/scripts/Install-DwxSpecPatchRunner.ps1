[CmdletBinding()]
param(
    [string]$TerminalRoot = "D:\QM\mt5\T1",
    [string]$FromVersion = "v2",
    [string]$ToVersion = "v3",
    [string]$SourceIniPath = "",
    [string]$TargetIniPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-VersionToken {
    param([Parameter(Mandatory = $true)][string]$Version)

    $trimmed = $Version.Trim()
    if (-not $trimmed) {
        throw "Version token cannot be empty."
    }

    if ($trimmed -match "^[vV](\d+)$") {
        return "v$($matches[1])"
    }

    if ($trimmed -match "^\d+$") {
        return "v$trimmed"
    }

    throw "Invalid version token '$Version'. Use values like 'v3' or '3'."
}

function Assert-SafeTerminalRoot {
    param([Parameter(Mandatory = $true)][string]$RootPath)

    $normalized = $RootPath.Replace("/", "\")
    if ($normalized -match "\\T6(_|\\)") {
        throw "Refusing to manage spec patch runner under T6 path '$RootPath' without explicit OWNER + LiveOps approval."
    }
}

function Normalize-Text {
    param([string]$Value)

    if ($null -eq $Value) {
        return ""
    }

    $normalized = $Value -replace "`r`n", "`n"
    $normalized = $normalized -replace "`r", "`n"
    return $normalized.TrimEnd("`n")
}

$from = Convert-VersionToken -Version $FromVersion
$to = Convert-VersionToken -Version $ToVersion

if ($from -eq $to) {
    throw "FromVersion and ToVersion resolve to the same value '$to'."
}

Assert-SafeTerminalRoot -RootPath $TerminalRoot

$sourceIni = if ($SourceIniPath) {
    $SourceIniPath
} else {
    Join-Path $TerminalRoot ("run_fix_dwx_spec_{0}.ini" -f $from)
}

$targetIni = if ($TargetIniPath) {
    $TargetIniPath
} else {
    Join-Path $TerminalRoot ("run_fix_dwx_spec_{0}.ini" -f $to)
}

if (-not (Test-Path -LiteralPath $sourceIni)) {
    throw "Source INI not found: $sourceIni"
}

$terminalExe = Join-Path $TerminalRoot "terminal64.exe"
if (-not (Test-Path -LiteralPath $terminalExe)) {
    throw "terminal64.exe not found under TerminalRoot: $terminalExe"
}

$fromScript = "Fix_DWX_Spec_{0}" -f $from
$toScript = "Fix_DWX_Spec_{0}" -f $to

$sourceContent = Get-Content -LiteralPath $sourceIni -Raw -ErrorAction Stop
$targetContent = $sourceContent.Replace($fromScript, $toScript)
$targetContent = $targetContent.Replace(
    ("run_fix_dwx_spec_{0}.ini" -f $from),
    ("run_fix_dwx_spec_{0}.ini" -f $to)
)

if ($targetContent -eq $sourceContent) {
    Write-Warning "No '$fromScript' token found in source INI. Keeping original content and writing to target path."
}

if (-not ($targetContent -match "(?im)^\s*ShutdownTerminal\s*=\s*1\s*$")) {
    if ($targetContent -notmatch "(?im)^\s*\[Common\]\s*$") {
        $targetContent = "[Common]`r`nShutdownTerminal=1`r`n`r`n$targetContent"
    }
    else {
        $targetContent = [regex]::Replace(
            $targetContent,
            "(?im)^\s*\[Common\]\s*$",
            "[Common]`r`nShutdownTerminal=1",
            1
        )
    }
}

$targetContent = (Normalize-Text -Value $targetContent) -replace "`n", "`r`n"
$targetContent = "$targetContent`r`n"

$parentDir = Split-Path -Parent $targetIni
if ($parentDir) {
    $null = New-Item -ItemType Directory -Path $parentDir -Force
}

$shouldWrite = $true
if (Test-Path -LiteralPath $targetIni) {
    $existing = Get-Content -LiteralPath $targetIni -Raw -ErrorAction Stop
    if ((Normalize-Text -Value $existing) -eq (Normalize-Text -Value $targetContent)) {
        $shouldWrite = $false
    }
}

if ($shouldWrite) {
    Set-Content -LiteralPath $targetIni -Value $targetContent -Encoding ASCII -NoNewline
    Write-Host "Converged INI: $targetIni"
}
else {
    Write-Host "INI already converged: $targetIni"
}

Write-Host "Run command:"
Write-Host "$terminalExe /portable /config:$targetIni"
