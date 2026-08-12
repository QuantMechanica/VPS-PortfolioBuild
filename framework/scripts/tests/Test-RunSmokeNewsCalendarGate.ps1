$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$scriptPath = Join-Path $repoRoot 'framework\scripts\run_smoke.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw "run_smoke.ps1 parse errors: $($errors | Out-String)" }
$text = Get-Content -Raw -LiteralPath $scriptPath
foreach ($required in @(
    'MetaQuotes\Terminal\Common\Files',
    'COMMON_MISMATCH',
    'MISSING_COMMON',
    'STALE_COMMON',
    'Get-FileHash',
    'EA-readable Common path')) {
    if (-not $text.Contains($required)) { throw "calendar gate missing: $required" }
}
$start = $text.IndexOf('$newsCalendarDiagnostics = Resolve-NewsCalendarDiagnostics')
$spawn = $text.IndexOf('$runExec = Start-TesterRun')
if ($start -lt 0 -or $spawn -lt 0 -or $start -gt $spawn) {
    throw 'calendar validation must occur before terminal start'
}
Write-Host 'PASS: run_smoke validates the EA-readable Common calendar before terminal start'
