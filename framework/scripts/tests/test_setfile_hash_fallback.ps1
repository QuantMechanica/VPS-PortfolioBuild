<#
Regression proof for the setfile generator's module-independent SHA-256 path.

Scheduled workers may inherit an empty PSModulePath, where the module-exported
Get-FileHash command cannot autoload. The generator must still return the exact
lowercase SHA-256 after writing a setfile.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$genPath = Join-Path $PSScriptRoot '..\gen_setfile.ps1'
if (-not (Test-Path -LiteralPath $genPath)) { throw "generator not found: $genPath" }

$lines = Get-Content -LiteralPath $genPath
$start = ($lines | Select-String -Pattern '^function Get-QmFileSha256\s*\{' |
    Select-Object -First 1).LineNumber
if (-not $start) { throw 'Get-QmFileSha256 not found in generator' }
$depth = 0
$end = $null
for ($i = $start - 1; $i -lt $lines.Count; $i++) {
    $depth += ([regex]::Matches($lines[$i], '\{')).Count
    $depth -= ([regex]::Matches($lines[$i], '\}')).Count
    if ($depth -le 0 -and $i -gt ($start - 1)) { $end = $i; break }
}
if ($null -eq $end) { throw 'could not delimit Get-QmFileSha256' }
Invoke-Expression (($lines[($start - 1)..$end]) -join "`n")

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("qm-sethash-" + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $tempRoot 'abc.bin'
try {
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    [System.IO.File]::WriteAllBytes($fixture, [System.Text.Encoding]::ASCII.GetBytes('abc'))

    # A throwing shadow proves the helper has no hidden dependency on the
    # module-exported command even when a command of that name is unusable.
    function Get-FileHash { throw 'Get-FileHash must not be called' }
    $actual = Get-QmFileSha256 -LiteralPath $fixture
    $expected = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    if ($actual -cne $expected) {
        throw "SHA256 mismatch: actual=$actual expected=$expected"
    }
    Write-Output 'PASS: module-independent setfile SHA-256'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
