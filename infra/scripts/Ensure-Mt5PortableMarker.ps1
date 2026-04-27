[CmdletBinding()]
param(
    [string[]]$FactoryTerminalRoots = @(
        'D:\QM\mt5\T1',
        'D:\QM\mt5\T2',
        'D:\QM\mt5\T3',
        'D:\QM\mt5\T4',
        'D:\QM\mt5\T5'
    ),
    [string]$MarkerFileName = 'portable.txt',
    [switch]$FailOnMissingRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$results = New-Object System.Collections.Generic.List[object]
$missingRoots = New-Object System.Collections.Generic.List[string]
$changed = 0

foreach ($root in $FactoryTerminalRoots) {
    $normalized = [IO.Path]::GetFullPath($root).TrimEnd('\\')
    $leaf = Split-Path -Path $normalized -Leaf

    if ($leaf -match '^T6(_|$)') {
        throw "Refusing to manage portable marker for T6 path '$normalized' without explicit OWNER + LiveOps approval."
    }

    if (-not (Test-Path -LiteralPath $normalized -PathType Container)) {
        $missingRoots.Add($normalized)
        $results.Add([pscustomobject]@{
            terminal_root = $normalized
            status = 'missing_root'
            marker_path = Join-Path $normalized $MarkerFileName
        }) | Out-Null
        continue
    }

    $markerPath = Join-Path $normalized $MarkerFileName
    $state = 'unchanged'
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        Set-Content -LiteralPath $markerPath -Value '' -Encoding ASCII -NoNewline
        $state = 'created'
        $changed += 1
    }
    else {
        $size = (Get-Item -LiteralPath $markerPath).Length
        if ($size -ne 0) {
            Set-Content -LiteralPath $markerPath -Value '' -Encoding ASCII -NoNewline
            $state = 'normalized_to_empty'
            $changed += 1
        }
    }

    $results.Add([pscustomobject]@{
        terminal_root = $normalized
        status = $state
        marker_path = $markerPath
    }) | Out-Null
}

$summary = [ordered]@{
    changed = $changed
    checked = $FactoryTerminalRoots.Count
    missing_roots = $missingRoots.ToArray()
    results = $results.ToArray()
}

$summary | ConvertTo-Json -Depth 6

if ($FailOnMissingRoot.IsPresent -and $missingRoots.Count -gt 0) {
    exit 2
}

exit 0
