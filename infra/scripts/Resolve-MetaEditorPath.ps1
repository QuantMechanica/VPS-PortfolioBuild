[CmdletBinding()]
param(
    [string[]]$Candidates = @(
        'D:\QM\mt5\T1\MetaEditor64.exe',
        'D:\QM\mt5\T2\MetaEditor64.exe'
    ),
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolved = $null
foreach ($candidate in $Candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $resolved = (Resolve-Path -LiteralPath $candidate).Path
        break
    }
}

if (-not $resolved) {
    throw "MetaEditor64.exe not found. Checked: $($Candidates -join ', ')"
}

$result = [ordered]@{
    canonical_path = $resolved
    discovered_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    checked_candidates = @($Candidates)
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 4
} else {
    $resolved
}
