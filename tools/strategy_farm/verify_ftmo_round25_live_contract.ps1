<#
.SYNOPSIS
  Verify the approved FTMO Round25 live recovery contract without changing state.

.DESCRIPTION
  Fail-closed verifier for the FTMO Free Trial deployment approved in
  decisions/2026-07-05_ftmo_round25_phase1_deploy.md. It checks:
  - account/server identity in common.ini;
  - the exact 12-chart Default profile and one enabled EA per chart;
  - chart symbol/timeframe, EA path, EA id, magic slot and risk inputs;
  - every applicable parameter from the SHA-pinned deployment preset; and
  - both the deployed and recovery-package .ex5 SHA-256 values.

  Chart window geometry and graphical objects are deliberately excluded: MT5 may
  save those fields during normal operation. The trading contract is not excluded.
  This script is read-only and is intended to run only after the FTMO process is
  confirmed absent, immediately before FTMO_ON.ps1 edits common.ini and starts MT5.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$dataDir = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850'
$profileDir = Join-Path $dataDir 'MQL5\Profiles\Charts\Default'
$terminalExpertsDir = Join-Path $dataDir 'MQL5\Experts\Live EAs'
$common = Join-Path $dataDir 'config\common.ini'
$packageDir = 'C:\QM\deploy\FTMO_Round25_2026-07-05'
$packageExpertsDir = Join-Path $packageDir 'live_eas'
$packagePresetsDir = Join-Path $packageDir 'presets'
$packageManifest = Join-Path $packageDir 'preset_manifest.json'
$expectedAccount = '1513845506'
$expectedServer = 'FTMO-Demo'

# Chart order is the deployed Default-profile order, captured and OWNER-verified
# on 2026-07-05. Binary and preset hashes are the immutable deployment-package
# hashes recorded by that decision.
$legs = @(
    [pscustomobject]@{ chart='chart01.chr'; ea_id=10163; slug='tv-rsi-macd-long'; symbol='US100.cash'; period_size='1'; slot=0;  risk='422';  cap='1.0'; preset='r25p1_US100.cash_H1_QM5_10163_tv-rsi-macd-long_magic101630000.set'; preset_sha='57170A4F99464B250E71F3E31195E04B7F1333CB59E1D7FDF9727D9FDA0B6C0C'; binary_sha='D6EF030475400A5AD0639A5EAD6C30C7C6A1746CC4FFDACC7D69E94BDA366898' },
    [pscustomobject]@{ chart='chart02.chr'; ea_id=10440; slug='mql5-ohlc-mtf'; symbol='US100.cash'; period_size='1'; slot=3;  risk='459';  cap='1.0'; preset='r25p1_US100.cash_H1_QM5_10440_mql5-ohlc-mtf_magic104400003.set'; preset_sha='8DFFBD8E01260EC7F27A683CB94EC785785CFAD2566C10F6D25D3DC831191F45'; binary_sha='4CE578A80D685A0CA7B2EB19FCF6670984C7685EEA14F6F1764708B8499276DB' },
    [pscustomobject]@{ chart='chart03.chr'; ea_id=10692; slug='tv-ls-ms'; symbol='US100.cash'; period_size='1'; slot=5;  risk='1117'; cap='2.0'; preset='r25p1_US100.cash_H1_QM5_10692_tv-ls-ms_magic106920005.set'; preset_sha='6B6AE7325E766D2FB4441489FA22CBEF81BC8CB725C427989ED95BC6F2291D96'; binary_sha='24CA22B63ACC015493C021795A00A79A290C28CEF49A157A3B305A79ED2E1F3E' },
    [pscustomobject]@{ chart='chart04.chr'; ea_id=12475; slug='gh-macd-cross'; symbol='US100.cash'; period_size='1'; slot=3;  risk='325';  cap='1.0'; preset='r25p1_US100.cash_H1_QM5_12475_gh-macd-cross_magic124750003.set'; preset_sha='83567818E5FE5891179C3DB4306AA79169BC2DAAE4A31A0A58B5AC5651F523B5'; binary_sha='F1AF8EB9277EEFE7158BB85BC6BE40379E46A5C338A6436827AEA7F9881B48A9' },
    [pscustomobject]@{ chart='chart05.chr'; ea_id=10911; slug='grimes-complex-pb'; symbol='GER40.cash'; period_size='1'; slot=3;  risk='1256'; cap='2.0'; preset='r25p1_GER40.cash_H1_QM5_10911_grimes-complex-pb_magic109110003.set'; preset_sha='286F3E3D0C4617CF0AE0D9412A454D61494DD82DDC6066233755C22BD5184B3E'; binary_sha='C717CDE58AA991C00EA3CC55E16D34B5CF20A8C0F6DEDD092C4E479B22243C40' },
    [pscustomobject]@{ chart='chart06.chr'; ea_id=12958; slug='nnfx-hma-wae-swing'; symbol='XAUUSD'; period_size='24'; slot=0; risk='1256'; cap='2.0'; preset='r25p1_XAUUSD_D1_QM5_12958_nnfx-hma-wae-swing_magic129580000.set'; preset_sha='F16C1FC708BDD432ED3F01E7168FB29F1E27F760F317CDDA6C49E4B571B38CD2'; binary_sha='DEDA6CFE36262BF142107A9401519AC309147DAB6CE832B4532AE41D89EBC1B4' },
    [pscustomobject]@{ chart='chart07.chr'; ea_id=10848; slug='tv-mtf-ambush'; symbol='XAUUSD'; period_size='1'; slot=2;  risk='838';  cap='1.0'; preset='r25p1_XAUUSD_H1_QM5_10848_tv-mtf-ambush_magic108480002.set'; preset_sha='B0EFFBF0B8F917C56CC886AD174210061A20EA2900E7B3C90C774947B4894EC5'; binary_sha='12DF52B5ACFB7C8BF267BB9A7152D151CA50AF00A5032F064AB569C04406D1F2' },
    [pscustomobject]@{ chart='chart08.chr'; ea_id=10700; slug='tv-liq-break'; symbol='XAUUSD'; period_size='1'; slot=3;  risk='624';  cap='1.0'; preset='r25p1_XAUUSD_H1_QM5_10700_tv-liq-break_magic107000003.set'; preset_sha='0510BAF99AEA81ADE9892C4B7E81B9DFE8F5F8EA920CD00F7B29E4743E3519C0'; binary_sha='432879F816D9DCD3B27D8E3C93A41C9B7C603544676C61397D4D41114900C066' },
    [pscustomobject]@{ chart='chart09.chr'; ea_id=11476; slug='lien-k-double-bb-trend-h1'; symbol='USDJPY'; period_size='1'; slot=2; risk='1435'; cap='2.0'; preset='r25p1_USDJPY_H1_QM5_11476_lien-k-double-bb-trend-h1_magic114760002.set'; preset_sha='22311CC6A2E83952A548B7E5841E027F43A520D811F67F56BEBBD12E64488BD6'; binary_sha='114EA8BD67F86D6CBF9B6BBA11ED7E01A21DE70EFD5954A55E7CE64AD4AE1FBD' },
    [pscustomobject]@{ chart='chart10.chr'; ea_id=10847; slug='tv-inside-gem'; symbol='GBPUSD'; period_size='1'; slot=1;  risk='389';  cap='1.0'; preset='r25p1_GBPUSD_H1_QM5_10847_tv-inside-gem_magic108470001.set'; preset_sha='0FD8798D4CB1785BAB0CC871C845CF4CE2E02B690486E724BDD5432571766ABC'; binary_sha='99AF5333FBD783D84F4DE7BFEC1B207189EE2D48BDC67C539D4F8EB202ED8DBC' },
    [pscustomobject]@{ chart='chart11.chr'; ea_id=12990; slug='grimes-context-pb-v2'; symbol='GBPUSD'; period_size='4'; slot=1; risk='360'; cap='1.0'; preset='r25p1_GBPUSD_H4_QM5_12990_grimes-context-pb-v2_magic129900001.set'; preset_sha='0777DE35923190253B24D8ECA8222E95238686533A18486C04189A6FA2CC51BD'; binary_sha='91B5DD8ACCE4DFFA4914ABAF783F25A71587B13AA7AC690695909424903CC350' },
    [pscustomobject]@{ chart='chart12.chr'; ea_id=10286; slug='cinar-supertrend'; symbol='USOIL.cash'; period_size='24'; slot=36; risk='518'; cap='1.0'; preset='r25p1_USOIL.cash_D1_QM5_10286_cinar-supertrend_magic102860036.set'; preset_sha='A475CE1BBD177F73994C3C8C771D5E21D942171ED210374290B0E9D9B004B349'; binary_sha='F6740C0A9C1E21F38F9E4CC8D3EDC142C0784680723B9312D6753BC4C0D3A02C' }
)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Sha256 {
    param([string]$Path)
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "missing file: $Path"
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-UniqueValue {
    param([string]$Text, [string]$Key, [string]$Context)
    $matches = [regex]::Matches($Text, "(?m)^$([regex]::Escape($Key))=([^`r`n]*)`r?$")
    Assert-True ($matches.Count -eq 1) "expected exactly one '$Key' in $Context; found $($matches.Count)"
    return $matches[0].Groups[1].Value
}

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
    $expected = @($legs | ForEach-Object chart) + 'order.wnd'
    $actual = @((Get-ChildItem -LiteralPath $profileDir -File | ForEach-Object Name | Sort-Object))
    $expected = @($expected | Sort-Object)
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

function Assert-PackageManifest {
    Assert-True (Test-Path -LiteralPath $packageManifest -PathType Leaf) "missing package manifest: $packageManifest"
    $manifest = Get-Content -LiteralPath $packageManifest -Raw | ConvertFrom-Json
    Assert-True (@($manifest.legs).Count -eq $legs.Count) 'package manifest must contain exactly 12 legs'
    foreach ($leg in $legs) {
        $manifestLeg = @($manifest.legs | Where-Object {
            [int]$_.ea_id -eq [int]$leg.ea_id -and [string]$_.slug -ceq [string]$leg.slug
        })
        Assert-True ($manifestLeg.Count -eq 1) "package manifest leg mismatch: ea_id=$($leg.ea_id)"
        $m = $manifestLeg[0]
        $expectedMagic = ([int]$leg.ea_id * 10000) + [int]$leg.slot
        Assert-True ([string]$m.ftmo_symbol -ceq [string]$leg.symbol) "manifest symbol mismatch: $($leg.ea_id)"
        Assert-True ([int]$m.magic -eq $expectedMagic) "manifest magic mismatch: $($leg.ea_id)"
        Assert-True ([int]$m.risk_fixed_usd -eq [int]$leg.risk) "manifest risk mismatch: $($leg.ea_id)"
        Assert-True ([string]$m.preset -ceq [string]$leg.preset) "manifest preset mismatch: $($leg.ea_id)"
        Assert-True ([string]$m.preset_sha256 -ceq [string]$leg.preset_sha) "manifest preset hash mismatch: $($leg.ea_id)"
    }
}

function Assert-LegContract {
    param([pscustomobject]$Leg)

    $chartPath = Join-Path $profileDir $Leg.chart
    Assert-True (Test-Path -LiteralPath $chartPath -PathType Leaf) "missing chart: $chartPath"
    $text = [IO.File]::ReadAllText($chartPath)
    $experts = [regex]::Matches($text, '(?ms)<expert>\s*.*?</expert>')
    Assert-True ($experts.Count -eq 1) "expected exactly one expert in $($Leg.chart)"
    $expert = $experts[0].Value
    Assert-True ([regex]::Matches($expert, '(?m)^<inputs>\r?$').Count -eq 1) "missing inputs in $($Leg.chart)"
    Assert-True ([regex]::Matches($expert, '(?m)^</inputs>\r?$').Count -eq 1) "unterminated inputs in $($Leg.chart)"

    $prefix = $text.Substring(0, $experts[0].Index)
    $eaName = "QM5_$($Leg.ea_id)_$($Leg.slug)"
    $expectedPath = "Experts\Live EAs\$eaName.ex5"
    $expectedMagic = ([int]$Leg.ea_id * 10000) + [int]$Leg.slot

    Assert-True ((Get-UniqueValue $prefix 'symbol' $Leg.chart) -ceq [string]$Leg.symbol) "symbol mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $prefix 'period_type' $Leg.chart) -ceq '1') "period_type mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $prefix 'period_size' $Leg.chart) -ceq [string]$Leg.period_size) "period_size mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'name' $Leg.chart) -ceq $eaName) "EA name mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'path' $Leg.chart) -ceq $expectedPath) "EA path mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'expertmode' $Leg.chart) -ceq '1') "expert disabled: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'qm_ea_id' $Leg.chart) -ceq [string]$Leg.ea_id) "EA id mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'qm_magic_slot_offset' $Leg.chart) -ceq [string]$Leg.slot) "magic slot mismatch: $($Leg.chart)"
    Assert-True ($expectedMagic -eq ([int]$Leg.ea_id * 10000 + [int](Get-UniqueValue $expert 'qm_magic_slot_offset' $Leg.chart))) "magic derivation mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'RISK_PERCENT' $Leg.chart) -ceq '0') "RISK_PERCENT mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'RISK_FIXED' $Leg.chart) -ceq [string]$Leg.risk) "RISK_FIXED mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'PORTFOLIO_WEIGHT' $Leg.chart) -ceq '1.0') "PORTFOLIO_WEIGHT mismatch: $($Leg.chart)"
    Assert-True ((Get-UniqueValue $expert 'qm_risk_cap_pct' $Leg.chart) -ceq [string]$Leg.cap) "risk cap mismatch: $($Leg.chart)"

    $presetPath = Join-Path $packagePresetsDir $Leg.preset
    Assert-True ((Get-Sha256 $presetPath) -ceq [string]$Leg.preset_sha) "preset hash mismatch: $($Leg.preset)"
    $presetAssignments = Get-PresetAssignments $presetPath
    foreach ($key in $presetAssignments.Keys) {
        # The historical packaging scaffold included filter-library keys that these
        # compiled EAs do not expose. MT5 ignored them at attach; all other packaged
        # inputs must be present and byte-equivalent in the saved chart contract.
        if ($key -like 'qm_filter_*') { continue }
        $observed = Get-UniqueValue $expert $key $Leg.chart
        Assert-True ($observed -ceq [string]$presetAssignments[$key]) "preset input mismatch: $($Leg.chart)/$key"
    }

    $terminalBinary = Join-Path $terminalExpertsDir "$eaName.ex5"
    $packageBinary = Join-Path $packageExpertsDir "$eaName.ex5"
    Assert-True ((Get-Sha256 $terminalBinary) -ceq [string]$Leg.binary_sha) "terminal binary hash mismatch: $eaName"
    Assert-True ((Get-Sha256 $packageBinary) -ceq [string]$Leg.binary_sha) "package binary hash mismatch: $eaName"
}

try {
    Assert-True (Test-Path -LiteralPath $profileDir -PathType Container) "missing FTMO Default profile: $profileDir"
    Assert-ExactProfileFiles
    Assert-CommonContract
    Assert-PackageManifest
    foreach ($leg in $legs) { Assert-LegContract $leg }
    Write-Host 'VERIFIED: FTMO account 1513845506 / Default = approved Round25 12-leg profile + 12 SHA-pinned binaries'
    exit 0
} catch {
    Write-Error "FTMO Round25 live contract verification failed: $($_.Exception.Message)"
    exit 2
}
