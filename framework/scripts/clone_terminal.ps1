param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^T(?:[1-9]|10)$')]
    [string]$SourceTerminal,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^T(?:[1-9]|10)$')]
    [string]$TargetTerminal,

    [string]$Mt5Root = "D:\QM\mt5"
)

$ErrorActionPreference = "Stop"

function Resolve-ExistingPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required path does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Copy-DirectoryIfExists {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        Write-Host "skip missing directory: $Source"
        return
    }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force -ErrorAction Stop
    }
}

function Copy-FileIfExists {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        Write-Host "skip missing file: $Source"
        return
    }
    $parent = Split-Path -Parent $Destination
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop
}

function New-EmptyDirectoryTree {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        Write-Host "skip missing directory tree: $Source"
        return
    }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -Directory -Recurse -Force | ForEach-Object {
        $relative = [System.IO.Path]::GetRelativePath($Source, $_.FullName)
        New-Item -ItemType Directory -Force -Path (Join-Path $Destination $relative) | Out-Null
    }
}

function Ensure-Junction {
    param(
        [Parameter(Mandatory = $true)][string]$LinkPath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    $resolvedTarget = Resolve-ExistingPath -Path $TargetPath
    if (Test-Path -LiteralPath $LinkPath) {
        $item = Get-Item -LiteralPath $LinkPath -Force
        if (-not (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq [IO.FileAttributes]::ReparsePoint)) {
            throw "Refusing to replace non-junction path: $LinkPath"
        }
        $currentTarget = $item.Target
        if ($currentTarget -is [array]) {
            $currentTarget = $currentTarget[0]
        }
        $resolvedCurrent = Resolve-ExistingPath -Path $currentTarget
        if ($resolvedCurrent -ne $resolvedTarget) {
            throw "Junction target mismatch for $LinkPath. current=$resolvedCurrent expected=$resolvedTarget"
        }
        Write-Host "junction exists: $LinkPath -> $resolvedTarget"
        return
    }

    $parent = Split-Path -Parent $LinkPath
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    New-Item -ItemType Junction -Path $LinkPath -Target $resolvedTarget | Out-Null
    Write-Host "junction created: $LinkPath -> $resolvedTarget"
}

$sourceRoot = Resolve-ExistingPath -Path (Join-Path $Mt5Root $SourceTerminal)
$targetRoot = Join-Path $Mt5Root $TargetTerminal

if ($SourceTerminal -eq $TargetTerminal) {
    throw "SourceTerminal and TargetTerminal must differ."
}
if ($TargetTerminal -eq "T_Live" -or $targetRoot -match '\\T_Live$') {
    throw "Refusing to create or modify T_Live."
}

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null

foreach ($file in @("terminal64.exe", "MetaEditor64.exe", "metaeditor.exe", "portable.txt", "terminal.ini")) {
    Copy-FileIfExists -Source (Join-Path $sourceRoot $file) -Destination (Join-Path $targetRoot $file)
}

foreach ($dir in @("Config", "Profiles", "Sounds", "Templates")) {
    Copy-DirectoryIfExists -Source (Join-Path $sourceRoot $dir) -Destination (Join-Path $targetRoot $dir)
}

foreach ($dir in @("Experts", "Include", "Scripts", "Profiles")) {
    Copy-DirectoryIfExists -Source (Join-Path $sourceRoot (Join-Path "MQL5" $dir)) -Destination (Join-Path $targetRoot (Join-Path "MQL5" $dir))
}

New-EmptyDirectoryTree -Source (Join-Path $sourceRoot "Tester") -Destination (Join-Path $targetRoot "Tester")
New-Item -ItemType Directory -Force -Path (Join-Path $targetRoot "MQL5\Files") | Out-Null

Ensure-Junction -LinkPath (Join-Path $targetRoot "Bases") -TargetPath (Join-Path $sourceRoot "Bases")
Ensure-Junction -LinkPath (Join-Path $targetRoot "MQL5\Files\registry") -TargetPath (Join-Path $sourceRoot "MQL5\Files\registry")

$importsPath = Join-Path $targetRoot "MQL5\Files\imports"
if (Test-Path -LiteralPath $importsPath) {
    $item = Get-Item -LiteralPath $importsPath -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq [IO.FileAttributes]::ReparsePoint) {
        Write-Host "note: imports reparse point already exists: $importsPath"
    } else {
        Write-Warning "imports path exists and was left untouched: $importsPath"
    }
}

Write-Host "cloned portable terminal: $TargetTerminal from $SourceTerminal"
