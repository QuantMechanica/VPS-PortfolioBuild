param(
    [Parameter(Mandatory = $true)]
    [string]$EaSlug,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Z0-9._]+\.DWX$')]
    [string]$Symbol,
    [Parameter(Mandatory = $true)]
    [ValidateSet('M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1', 'MN1')]
    [string]$TF,
    [ValidateSet('backtest', 'demo', 'shadow', 'live')]
    [string]$Env = 'backtest',
    [double]$RiskFixed = 1000,
    [double]$RiskPercent = 0,
    [double]$PortfolioWeight = 1.0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$easRoot = Join-Path $repoRoot 'framework\EAs'

if ($EaSlug -notmatch '^QM5_[A-Za-z0-9_]+$') {
    throw "EaSlug must start with QM5_ and contain only letters, digits, and underscores. Got: $EaSlug"
}

$eaFolder = Join-Path $easRoot $EaSlug
New-Item -ItemType Directory -Path $eaFolder -Force | Out-Null

$setsFolder = Join-Path $eaFolder 'sets'
New-Item -ItemType Directory -Path $setsFolder -Force | Out-Null

$fileName = "${EaSlug}_${Symbol}_${TF}_${Env}.set"
$targetPath = Join-Path $setsFolder $fileName

if ($Env -eq 'backtest') {
    if ($RiskFixed -le 0) {
        throw "For Env=backtest, RiskFixed must be > 0."
    }
    if ($RiskPercent -ne 0) {
        throw "For Env=backtest, RiskPercent must be 0."
    }
}

$lines = @(
    "; QuantMechanica V5 generated set file",
    "; Generator=framework/scripts/gen_setfile.ps1",
    "ENV=$Env",
    "RISK_FIXED=$RiskFixed",
    "RISK_PERCENT=$RiskPercent",
    "PORTFOLIO_WEIGHT=$PortfolioWeight",
    "; strategy-specific params from card must be appended below this line"
)

$content = ($lines -join "`n") + "`n"
[System.IO.File]::WriteAllText($targetPath, $content, [System.Text.UTF8Encoding]::new($false))

$sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $targetPath).Hash.ToLowerInvariant()
[pscustomobject]@{
    status = 'ok'
    ea = $EaSlug
    env = $Env
    symbol = $Symbol
    tf = $TF
    setfile_path = $targetPath
    setfile_sha256 = $sha
} | ConvertTo-Json -Depth 4
