param(
    [Parameter(Mandatory = $true)]
    [string]$EAId,
    [Parameter(Mandatory = $true)]
    [ValidateSet('P3.5','P5','P5b','P5c','P6','P7','P8','P9','P10')]
    [string]$Phase,
    [string]$OutRoot = 'D:\QM\reports\pipeline',
    [string[]]$Symbols = @(),
    [string[]]$RunnerArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runnerMap = @{
    'P3.5' = 'p35_csr_runner.py'
    'P5'   = 'p5_stress_runner.py'
    'P5b'  = 'p5b_calibrated_noise.py'
    'P5c'  = 'p5c_crisis_slices.py'
    'P6'   = 'p6_multiseed.py'
    'P7'   = 'p7_statval.py'
    'P8'   = 'p8_news_impact.py'
    'P9'   = 'p9_portfolio_aggregate.py'
    'P10'  = 'p10_dxz_compliance_gate.py'
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

function Resolve-EANumericId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EAValue
    )
    if ($EAValue -match '^QM5_(\d+)$') {
        return [int]$Matches[1]
    }
    if ($EAValue -match '^\d+$') {
        return [int]$EAValue
    }
    throw "Could not parse numeric ea_id from -EA '$EAValue'. Expected QM5_<id> or numeric id."
}

function Get-AllowedSymbolsFromRegistry {
    param(
        [Parameter(Mandatory = $true)]
        [int]$NumericEaId,
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )
    $registryPath = Join-Path $RepoRoot 'framework\registry\magic_numbers.csv'
    if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
        throw "Magic registry not found: $registryPath"
    }

    $rows = Import-Csv -Path $registryPath
    $symbols = @(
        $rows |
        Where-Object {
            $_.ea_id -eq $NumericEaId.ToString() -and
            ($_.status -eq 'active' -or [string]::IsNullOrWhiteSpace($_.status))
        } |
        ForEach-Object { ($_.symbol | ForEach-Object { "$_".Trim() }) } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
    )
    return $symbols
}

function Write-CanonicalJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [object]$Payload
    )
    $json = $Payload | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

$numericEaId = Resolve-EANumericId -EAValue $EAId
$allowedSymbols = Get-AllowedSymbolsFromRegistry -NumericEaId $numericEaId -RepoRoot $repoRoot
$effectiveSymbols = @()
if (@($Symbols).Count -gt 0) {
    $effectiveSymbols = @($Symbols | ForEach-Object { "$_".Trim() } | Where-Object { $_ -ne '' } | Select-Object -Unique)
    if (@($allowedSymbols).Count -gt 0) {
        $invalid = @($effectiveSymbols | Where-Object { $_ -notin $allowedSymbols })
        if (@($invalid).Count -gt 0) {
            throw "Provided -Symbols contain values not registered for EA ${EAId}: $($invalid -join ', '). Allowed: $($allowedSymbols -join ', ')"
        }
    }
} else {
    $effectiveSymbols = @($allowedSymbols)
}

if (@($effectiveSymbols).Count -eq 0) {
    throw "No symbols resolved for EA $EAId. Provide -Symbols or register active symbols in framework/registry/magic_numbers.csv."
}

$runnerName = $runnerMap[$Phase]
$runnerPath = Join-Path $scriptDir $runnerName
if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw "Runner script not found for phase ${Phase}: $runnerPath"
}

$phaseToken = $Phase.Replace('.', '_')
$phaseOut = Join-Path (Join-Path $OutRoot $EAId) $phaseToken
New-Item -ItemType Directory -Path $phaseOut -Force | Out-Null

$pythonArgs = @($runnerPath, '--ea', $EAId, '--out-prefix', $OutRoot) + $RunnerArgs
if ($Phase -eq 'P5b' -and ($pythonArgs -notcontains '--symbol')) {
    $pythonArgs += @('--symbol', $effectiveSymbols[0])
}
Write-Output ("run_phase.command=python " + ($pythonArgs -join ' '))

& python @pythonArgs
if ($LASTEXITCODE -ne 0) {
    throw "Phase runner failed for $Phase (exit=$LASTEXITCODE)."
}

$resultPath = Join-Path $phaseOut ($phaseToken + '_' + $EAId + '_result.json')
if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
    throw "Runner completed but result JSON not found: $resultPath"
}
$resultJson = Get-Content -Raw -Path $resultPath | ConvertFrom-Json
$orchestratorRecord = [ordered]@{
    criterion = $resultJson.criterion
    ea_id = $EAId
    evidence_path = "$resultPath"
    phase = $Phase
    symbols = $effectiveSymbols
    ts_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    verdict = $resultJson.verdict
}
Write-CanonicalJson -Path (Join-Path $phaseOut 'phase_orchestrator_last.json') -Payload $orchestratorRecord

$aggregatePath = Join-Path $scriptDir 'aggregate_phase_results.py'
& python $aggregatePath --ea $EAId --input-root $OutRoot --output-root $OutRoot
if ($LASTEXITCODE -ne 0) {
    throw "Aggregation failed after phase $Phase (exit=$LASTEXITCODE)."
}

$aggregatedPath = Join-Path (Join-Path $OutRoot $EAId) 'index.json'
$runMeta = [ordered]@{
    aggregate_path = "$aggregatedPath"
    criterion = $resultJson.criterion
    ea_id = $EAId
    evidence_path = "$resultPath"
    phase = $Phase
    symbols = $effectiveSymbols
    ts_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    verdict = $resultJson.verdict
}
Write-CanonicalJson -Path (Join-Path $phaseOut 'run_phase_last.json') -Payload $runMeta

Write-Output "run_phase.result=OK"
