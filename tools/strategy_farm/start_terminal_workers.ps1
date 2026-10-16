param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$FarmRoot = "D:\QM\strategy_farm",
    [string]$Mt5Root = "D:\QM\mt5"
)

$ErrorActionPreference = "Stop"

# One launch authority owns reservation filtering, duplicate detection,
# resource admission, and the canonical machine-scoped worker environment.
# Keeping a second PowerShell implementation here caused restarter drift.
$starter = Join-Path $RepoRoot "tools\strategy_farm\start_terminal_workers.py"
if (-not (Test-Path -LiteralPath $starter -PathType Leaf)) {
    throw "Missing worker starter: $starter"
}
$python = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
if (-not $python) { throw "python.exe is not available" }

& $python $starter `
    --repo-root $RepoRoot `
    --farm-root $FarmRoot `
    --mt5-root $Mt5Root `
    --dedupe
exit $LASTEXITCODE
