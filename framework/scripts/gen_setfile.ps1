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

if ($EaSlug -notmatch '^QM5_(\d+)_') {
    throw "EaSlug must be full slug format QM5_<ea_id>_<slug>. Got: $EaSlug"
}
$eaPrefix = "QM5_$($Matches[1])"

$eaFolder = Join-Path $easRoot $EaSlug
if (-not (Test-Path -LiteralPath $eaFolder -PathType Container)) {
    throw "EA folder not found: $eaFolder"
}

$setsFolder = Join-Path $eaFolder 'sets'
New-Item -ItemType Directory -Path $setsFolder -Force | Out-Null

$fileName = "${eaPrefix}_${Symbol}_${TF}_${Env}.set"
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
    "; GeneratedAtUtc=$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))",
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
