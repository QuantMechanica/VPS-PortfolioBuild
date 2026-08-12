<#
.SYNOPSIS
  Verify the current FTMO demo-instrumentation recovery contract read-only.

.DESCRIPTION
  OWNER ratified FTMO as RUNNING on 2026-08-06. This fail-closed verifier pins
  the exact deployed Default profile for account 1514165262: AccountMonitor,
  five attached instrumentation sleeves, and the existing blank XAUUSD chart.
  It never attaches an EA, enables an expert, edits a profile, or starts MT5.

  The sixth staged XAUUSD/H4 sleeve is deliberately absent from this contract:
  it was not durably saved in the deployed profile before the host crash. A
  recovery must reproduce current deployed reality, not infer staged intent.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'liveops_profile_contract.ps1')

$dataDir = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850'
$profileDir = Join-Path $dataDir 'MQL5\Profiles\Charts\Default'
$presetDir = Join-Path $dataDir 'MQL5\Presets'
$terminalExpertsDir = Join-Path $dataDir 'MQL5\Experts\QM_FTMO'
$common = Join-Path $dataDir 'config\common.ini'
$expectedAccount = '1514165262'
$expectedServer = 'FTMO-Demo'

$legs = @(
    [pscustomobject]@{ chart='chart02.chr'; ea_id=13301; slug='balke-minute-range-breakout'; symbol='GER40.cash'; period_type='0'; period_size='5';  expertmode='1'; slot='10'; risk_percent='0.0692'; risk_fixed='0'; portfolio_weight='1';   preset='FTMO_GER40_cash_M5_QM5_13301.set'; preset_sha='44B39D2BC63B6F1B68C130F47C7AAD22770790CE5A3D8284DFA943DBCC39DC4B'; binary_sha='D7F10A684BDB007D9CB5B55E894A8E3B26192E38D3015E80550B9FA317E26483' },
    [pscustomobject]@{ chart='chart03.chr'; ea_id=10911; slug='grimes-complex-pb'; symbol='GER40.cash'; period_type='1'; period_size='1';  expertmode='0'; slot='3';  risk_percent='0.1276'; risk_fixed='0'; portfolio_weight='1.0'; preset='FTMO_GER40_cash_H1_QM5_10911.set'; preset_sha='04019E928630CFEAAF8936552D193598DEF7D3912F4162A483F416113D9EEEE6'; binary_sha='A815C73DA991736D25A02C027BBCFB23F68615ADB66B7325CC2EFCDC52344158' },
    [pscustomobject]@{ chart='chart04.chr'; ea_id=11165; slug='weiss-rsi-ma'; symbol='EURUSD'; period_type='1'; period_size='1'; expertmode='1'; slot='0'; risk_percent='0.4127'; risk_fixed='0'; portfolio_weight='1'; preset='FTMO_EURUSD_H1_QM5_11165.set'; preset_sha='F71B9EE5C0381ABA31FC028D3D07952C6E41385B41AB9FE33148B918DD80AE37'; binary_sha='8F6D33A3DFB05F7F9167C96D7A7069CB11D8C05F7137BE008530D9E12DF941E4' },
    [pscustomobject]@{ chart='chart05.chr'; ea_id=10706; slug='tv-mon-ls'; symbol='GBPUSD'; period_type='1'; period_size='1'; expertmode='1'; slot='1'; risk_percent='0.0530'; risk_fixed='0'; portfolio_weight='1'; preset='FTMO_GBPUSD_H1_QM5_10706.set'; preset_sha='F78F75A7573F17656C82207D1A48FD766571836BD6C346A67E4BBC03FAA44FD4'; binary_sha='01E34B2059DE6ED505D445CE9FCBAC7DA0EB10D51E5CBCBBD18D38A968916078' },
    [pscustomobject]@{ chart='chart06.chr'; ea_id=12969; slug='usdjpy-gotobi-nakane-fix'; symbol='USDJPY'; period_type='0'; period_size='30'; expertmode='1'; slot='0'; risk_percent='0.5100'; risk_fixed='0'; portfolio_weight='1'; preset='FTMO_USDJPY_M30_QM5_12969.set'; preset_sha='59AD0081613205EC8F163DE9BA976E0832ABBB4F40A52BF444E9CA1266695809'; binary_sha='933D63C036A154725DF1376E22CA74CB419860588F0313FC986FC3EAD7673BE4' }
)

$monitorChartName = 'chart01.chr'
$monitorBinaryRel = 'MQL5\Experts\QM_AccountMonitor.ex5'
$monitorBinarySha = '39B8300595953A3E7AE4E08BF1D2A836067EF431156EB4077F21ACDACE3E4133'
$blankChartName = 'chart07.chr'

function Get-PresetAssignments {
    param([string]$Path)
    $result = @{}
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*(?:;|$)') { continue }
        $match = [regex]::Match($line, '^([^=]+)=(.*)$')
        Assert-True $match.Success "unparseable preset line in ${Path}: $line"
        $key = $match.Groups[1].Value.Trim()
        Assert-True (-not $result.ContainsKey($key)) "duplicate preset key '$key' in $Path"
        $result[$key] = $match.Groups[2].Value.Trim()
    }
    return $result
}

function Assert-ExactProfileFiles {
    $expected = @('chart01.chr','chart02.chr','chart03.chr','chart04.chr',
        'chart05.chr','chart06.chr','chart07.chr','order.wnd') | Sort-Object
    $actual = @(Get-ChildItem -LiteralPath $profileDir -File |
        ForEach-Object Name | Sort-Object)
    Assert-True ([string]::Join('|', $actual) -ceq [string]::Join('|', $expected)) (
        'unexpected Default profile file set: ' + [string]::Join(', ', $actual)
    )
}

function Assert-CommonContract {
    Assert-True (Test-Path -LiteralPath $common -PathType Leaf) "missing common.ini: $common"
    $text = [IO.File]::ReadAllText($common, [Text.Encoding]::Unicode)
    Assert-True ((Get-UniqueValue $text 'Login' 'common.ini') -ceq $expectedAccount) 'FTMO account mismatch'
    Assert-True ((Get-UniqueValue $text 'Server' 'common.ini') -ceq $expectedServer) 'FTMO server mismatch'
}

function Assert-LegContract {
    param([pscustomobject]$Leg)

    $chartPath = Join-Path $profileDir $Leg.chart
    $contract = Get-ChartContract $chartPath
    $prefix = $contract.prefix
    $expert = $contract.expert
    $eaName = "QM5_$($Leg.ea_id)_$($Leg.slug)"
    $expectedPath = "Experts\QM_FTMO\$eaName.ex5"

    Assert-True ((Get-UniqueValue $prefix 'symbol' $Leg.chart) -ceq [string]$Leg.symbol) "symbol mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $prefix 'period_type' $Leg.chart) -ceq [string]$Leg.period_type) "period_type mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $prefix 'period_size' $Leg.chart) -ceq [string]$Leg.period_size) "period_size mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'name' $Leg.chart) -ceq $eaName) "EA name mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'path' $Leg.chart) -ceq $expectedPath) "EA path mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'expertmode' $Leg.chart) -ceq [string]$Leg.expertmode) "expert mode mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'qm_ea_id' $Leg.chart) -ceq [string]$Leg.ea_id) "EA id mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'qm_magic_slot_offset' $Leg.chart) -ceq [string]$Leg.slot) "magic slot mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'RISK_PERCENT' $Leg.chart) -ceq [string]$Leg.risk_percent) "RISK_PERCENT mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'RISK_FIXED' $Leg.chart) -ceq [string]$Leg.risk_fixed) "RISK_FIXED mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'PORTFOLIO_WEIGHT' $Leg.chart) -ceq [string]$Leg.portfolio_weight) "PORTFOLIO_WEIGHT mismatch: $($Leg.chart)"

    $presetPath = Join-Path $presetDir $Leg.preset
    Assert-True ((Get-Sha256 $presetPath) -ceq [string]$Leg.preset_sha) "preset hash mismatch: $($Leg.preset)"
    $assignments = Get-PresetAssignments $presetPath
    foreach ($key in $assignments.Keys) {
        if ($key -like 'qm_filter_*') { continue }
        $observed = Get-UniqueValue $expert $key $Leg.chart
        Assert-True ($observed -ceq [string]$assignments[$key]) "preset input mismatch: $($Leg.chart)/$key"
    }

    $binary = Join-Path $terminalExpertsDir "$eaName.ex5"
    Assert-True ((Get-Sha256 $binary) -ceq [string]$Leg.binary_sha) "terminal binary hash mismatch: $eaName"
}

function Assert-MonitorContract {
    $contract = Get-ChartContract (Join-Path $profileDir $monitorChartName)
    Assert-True ((Get-UniqueValue $contract.prefix 'symbol' $monitorChartName) -ceq 'EURUSD') 'monitor symbol mismatch'
    Assert-True ((Get-UniqueValue $contract.prefix 'period_type' $monitorChartName) -ceq '1') 'monitor period_type mismatch'
    Assert-True ((Get-UniqueValue $contract.prefix 'period_size' $monitorChartName) -ceq '1') 'monitor period_size mismatch'
    Assert-True ((Get-UniqueValue $contract.expert 'name' $monitorChartName) -ceq 'QM_AccountMonitor') 'monitor EA name mismatch'
    Assert-True ((Get-UniqueValue $contract.expert 'path' $monitorChartName) -ceq 'Experts\QM_AccountMonitor.ex5') 'monitor EA path mismatch'
    Assert-True ((Get-UniqueValue $contract.expert 'expertmode' $monitorChartName) -ceq '1') 'monitor expert disabled'
    Assert-True ((Get-Sha256 (Join-Path $dataDir $monitorBinaryRel)) -ceq $monitorBinarySha) 'monitor binary hash mismatch'
}

function Assert-BlankChartContract {
    $path = Join-Path $profileDir $blankChartName
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "missing blank chart: $path"
    $text = [IO.File]::ReadAllText($path)
    Assert-True ((Get-ChartExperts $text).Count -eq 0) 'chart07 must remain blank (no expert block)'
    Assert-True ((Get-UniqueValue $text 'symbol' $blankChartName) -ceq 'XAUUSD') 'blank chart symbol mismatch'
    Assert-True ((Get-UniqueValue $text 'period_type' $blankChartName) -ceq '1') 'blank chart period_type mismatch'
    Assert-True ((Get-UniqueValue $text 'period_size' $blankChartName) -ceq '1') 'blank chart period_size mismatch'
}

try {
    Assert-True (Test-Path -LiteralPath $profileDir -PathType Container) "missing FTMO Default profile: $profileDir"
    Assert-ExactProfileFiles
    Assert-CommonContract
    Assert-MonitorContract
    foreach ($leg in $legs) { Assert-LegContract $leg }
    Assert-BlankChartContract
    Write-Host 'VERIFIED: FTMO account 1514165262 / Default = AccountMonitor + five SHA-pinned instrumentation sleeves + blank XAUUSD chart'
    exit 0
} catch {
    Write-Error "FTMO demo instrumentation contract verification failed: $($_.Exception.Message)"
    exit 2
}
