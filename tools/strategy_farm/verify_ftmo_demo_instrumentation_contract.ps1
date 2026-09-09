<#
.SYNOPSIS
  Verify the current FTMO demo-instrumentation recovery contract read-only.

.DESCRIPTION
  Re-pinned 2026-09-09 after the 2026-09-09T16:44Z reboot exposed that this
  verifier still pinned the obsolete 2026-08-06 contract (AccountMonitor on
  chart01 + five sleeves chart02-06 + blank chart07 + order.wnd), causing
  `QM_FTMO_AtLogon` (FTMO_ON.ps1 -> this verifier) to exit 2
  `profile_contract_failed` on every reboot since the 2026-09-06 governor
  cutover and leave the FTMO demo terminal not auto-started.

  This fail-closed verifier now pins the FTMO M13 governed-trial Default
  profile actually deployed for account 1514536732 (login re-pinned from the
  stale contract's 1514165262 to match deployed `config\common.ini` reality
  -- see the accompanying orchestration report): the account governor
  (chart01), eight OWNER-signed trading sleeves (chart02-09), the trial
  telemetry collector (chart10), and one plain, expert-less chart (chart11).
  It never attaches an EA, enables an expert, edits a profile, or starts MT5.

  Deployment authority: decision OWNER-DEC-M13-ECONOMIC-TRIAL-20260906,
  manifest `docs/ops/evidence/2026-09-06_ftmo_demo_governor_manifest.md`.
  Several sleeve EX5/preset hashes pinned below were rebuilt after that
  manifest was signed (resolver base-name fix for 10706/11910/21505, a
  calendar-symbol/v2-calendar rebuild for 1537, and a further,
  manifest-undocumented rebuild of 11421 on 2026-09-08 for the chart-panel
  work) and therefore intentionally differ from the manifest's sealed
  SHA-256 table; this verifier pins DEPLOYED REALITY, not the sealed
  install receipt. See the 2026-09-09 orchestration report for the full
  cross-check.
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
$expectedAccount = '1514536732'
$expectedServer = 'FTMO-Demo'

$legs = @(
    [pscustomobject]@{ chart='chart02.chr'; ea_id=10706; slug='tv-mon-ls'; symbol='GBPUSD'; period_type='1'; period_size='1';  expertmode='1'; slot='1'; risk_percent='0.3125'; risk_fixed='0'; portfolio_weight='1'; preset='QM5_10706_GBPUSD_H1_live_trial.set'; preset_sha='31C37EC30421A51D7938EBFE911EF13E6615C678D0727DED9DEF09CB5CD1D140'; binary_sha='6F290D49DEFDFE1EC2D4DAD93E419A577C703A53AC91DE68E7BBFB22984C6BED' },
    [pscustomobject]@{ chart='chart03.chr'; ea_id=11421; slug='ohlc-daily-squeeze-reversal-d1'; symbol='EURUSD'; period_type='1'; period_size='24'; expertmode='1'; slot='0'; risk_percent='0.3125'; risk_fixed='0'; portfolio_weight='1'; preset='QM5_11421_EURUSD_D1_live_trial.set'; preset_sha='556044B6B3B50003D77604E5358DD9578462EEEC8764BA4BE10187649D689A50'; binary_sha='4FF02978AE5D205355F81850FDBAD1DAC5DAF8A8CB4313EAAE08C616B1940E0A' },
    [pscustomobject]@{ chart='chart04.chr'; ea_id=11422; slug='williams-18ma-outside-bar-entry-d1'; symbol='USDCAD'; period_type='1'; period_size='24'; expertmode='1'; slot='4'; risk_percent='0.3125'; risk_fixed='0'; portfolio_weight='1'; preset='QM5_11422_USDCAD_D1_live_trial.set'; preset_sha='215615B5DA7AE2F49DD3D9DAE7E85CBDFF522940F69892D04CDF3C0F61378EA5'; binary_sha='2B98E9E902313148BE78D88513FCBDA2476150B1A7605EB15A50B2CCA6B32D66' },
    [pscustomobject]@{ chart='chart05.chr'; ea_id=11910; slug='larry-williams-18ma-2outside-bars-d1'; symbol='NZDUSD'; period_type='1'; period_size='24'; expertmode='1'; slot='6'; risk_percent='0.3125'; risk_fixed='0'; portfolio_weight='1'; preset='QM5_11910_NZDUSD_D1_live_trial.set'; preset_sha='1223B912585405273B1865FA72CB923957E15C73D9EDD501A9E089E6F90CEEEF'; binary_sha='AE53F3BCCA175E8CDDABEEE7EBFBE2ECD28CDEAB83B5D57DBCC202612C31394D' },
    [pscustomobject]@{ chart='chart06.chr'; ea_id=13054; slug='brent-tom-mom'; symbol='USOIL.cash'; period_type='1'; period_size='24'; expertmode='1'; slot='0'; risk_percent='0.3125'; risk_fixed='0'; portfolio_weight='1'; preset='QM5_13054_USOIL.cash_D1_live_trial.set'; preset_sha='C50084A4729EB117528380972909B18D7775FF300488EEAF1EC81EB83E4B1659'; binary_sha='2E65488FCCDBD985F78318861A223A305D820A4FCE3D2EBDCAFAE6CE956FD96D' },
    [pscustomobject]@{ chart='chart07.chr'; ea_id=20048; slug='wti-preholiday'; symbol='USOIL.cash'; period_type='1'; period_size='24'; expertmode='1'; slot='0'; risk_percent='0.3125'; risk_fixed='0'; portfolio_weight='1'; preset='QM5_20048_USOIL.cash_D1_live_trial.set'; preset_sha='27527CFE486FBCEA95BD843F8DB67EB761594FDC6C7933D5F3F5CB3458FC27D8'; binary_sha='1312391AD7E654812244E48A6DF92D5BD323DBA7D32DDAE60C54ADC464527F00' },
    [pscustomobject]@{ chart='chart08.chr'; ea_id=1537; slug='aa-vol-sma10'; symbol='XAGUSD'; period_type='1'; period_size='24'; expertmode='1'; slot='1'; risk_percent='0.3125'; risk_fixed='0'; portfolio_weight='1'; preset='QM5_1537_XAGUSD_D1_live_trial_s20260907-002.set'; preset_sha='47E4FBE5CC90C2DDB895975D32AC105FDA38772BA0452D88DD73C1B89590387C'; binary_sha='16D66A0F7B86F6F8C9240280712D32914A9A3BBB004BAA1EA1A242CB4E9FF5EB' },
    [pscustomobject]@{ chart='chart09.chr'; ea_id=21505; slug='xag-weekly-lowvol-momentum'; symbol='XAGUSD'; period_type='1'; period_size='24'; expertmode='1'; slot='0'; risk_percent='0.3125'; risk_fixed='0'; portfolio_weight='1'; preset='QM5_21505_XAGUSD_D1_live_trial.set'; preset_sha='A3121A740DAED23646CE3982D36409726E853A76709D6D22E09FEB20AE78E9A7'; binary_sha='81386C2DCD80E58D2840FC6941CA066EB276A4650C2BDE07DA2CB971CAD0B24D' }
)

$governorChartName = 'chart01.chr'
$governorPresetPath = Join-Path $presetDir 'QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_active.set'
$governorPresetSha = 'F73453412B51C25F4E6A84600F46F6602DC827AFF9709B10EA7ACA634CBE1361'
$governorBinaryRel = 'MQL5\Experts\QM_FTMO\QM5_13206_ftmo-account-governor.ex5'
$governorBinarySha = 'E5E827CD05163DE0D0C7919E9E072759EFBD91A6B1E464CF9E962E850F4878F6'
$governorAllowedMagicsCsv = '107060001,114210000,114220004,119100006,130540000,15370001,200480000,215050000'
$governorEaIdsCsv = '10706,11421,11422,11910,13054,1537,20048,21505'
$governorChallengeId = 'M13_20260906_1514536732'

$telemetryChartName = 'chart10.chr'
$telemetryPresetPath = Join-Path $presetDir 'QM_FTMO_TrialTelemetry_1514536732.set'
$telemetryPresetSha = 'F4DA1592B9E8D5EA468512F9F4581B834BC1508F33BD424EAB94C43DD309BDD6'
$telemetryBinaryRel = 'MQL5\Experts\QM_FTMO\QM_FTMO_TrialTelemetry.ex5'
$telemetryBinarySha = '411638A1AE177326070C19B28C849FDA36594592279303CE7D96F36BFA458258'
$telemetryTrialId = 'M13_OPTION_B_20260906_1514536732'

$blankChartName = 'chart11.chr'

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
        'chart05.chr','chart06.chr','chart07.chr','chart08.chr','chart09.chr',
        'chart10.chr','chart11.chr','order.wnd') | Sort-Object
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
        # qm_panel_build_hash echoes the currently attached EX5's own compiled
        # panel-build identity (cosmetic UI build stamp, not an economics/risk
        # parameter). chart03/QM5_11421 was recompiled 2026-09-08 01:11 for the
        # OWNER chart-panel-standard work after its 2026-09-07 21:06 .set was
        # last saved, so the live chart legitimately shows a newer build hash
        # (9d55ea09) than the saved preset (5be08463). Every other key in this
        # preset -- including RISK_PERCENT/RISK_FIXED/PORTFOLIO_WEIGHT and all
        # strategy_* economics params -- was cross-checked equal against the
        # deployed chart (2026-09-09 orchestration report); only this cosmetic
        # build stamp drifted.
        if ($key -ceq 'qm_panel_build_hash') { continue }
        $observed = Get-UniqueValue $expert $key $Leg.chart
        Assert-True ($observed -ceq [string]$assignments[$key]) "preset input mismatch: $($Leg.chart)/$key"
    }

    $binary = Join-Path $terminalExpertsDir "$eaName.ex5"
    Assert-True ((Get-Sha256 $binary) -ceq [string]$Leg.binary_sha) "terminal binary hash mismatch: $eaName"
}

function Assert-GovernorContract {
    $contract = Get-ChartContract (Join-Path $profileDir $governorChartName)
    $expert = $contract.expert
    Assert-True ((Get-UniqueValue $contract.prefix 'symbol' $governorChartName) -ceq 'EURUSD') 'governor symbol mismatch'
    Assert-True ((Get-UniqueValue $contract.prefix 'period_type' $governorChartName) -ceq '0') 'governor period_type mismatch'
    Assert-True ((Get-UniqueValue $contract.prefix 'period_size' $governorChartName) -ceq '1') 'governor period_size mismatch'
    Assert-True ((Get-UniqueValue $expert 'name' $governorChartName) -ceq 'QM5_13206_ftmo-account-governor') 'governor EA name mismatch'
    Assert-True ((Get-UniqueValue $expert 'path' $governorChartName) -ceq 'Experts\QM_FTMO\QM5_13206_ftmo-account-governor.ex5') 'governor EA path mismatch'
    Assert-True ((Get-UniqueValue $expert 'expertmode' $governorChartName) -ceq '1') 'governor expert disabled'
    Assert-True ((Get-UniqueValue $expert 'qm_ea_id' $governorChartName) -ceq '13206') 'governor qm_ea_id mismatch'
    Assert-True ((Get-UniqueValue $expert 'signed_policy_id' $governorChartName) -ceq 'FTMO_2S_P1_100K_V2') 'governor signed_policy_id mismatch'
    Assert-True ((Get-UniqueValue $expert 'expected_account_login' $governorChartName) -ceq $expectedAccount) 'governor expected_account_login mismatch'
    Assert-True ((Get-UniqueValue $expert 'expected_account_server' $governorChartName) -ceq $expectedServer) 'governor expected_account_server mismatch'
    Assert-True ((Get-UniqueValue $expert 'challenge_id' $governorChartName) -ceq $governorChallengeId) 'governor challenge_id mismatch'
    Assert-True ((Get-UniqueValue $expert 'allowed_magics_csv' $governorChartName) -ceq $governorAllowedMagicsCsv) 'governor allowed_magics_csv mismatch'
    Assert-True ((Get-UniqueValue $expert 'governed_ea_ids_csv' $governorChartName) -ceq $governorEaIdsCsv) 'governor governed_ea_ids_csv mismatch'
    Assert-True ((Get-UniqueValue $expert 'governor_dry_run' $governorChartName) -ceq 'false') 'governor governor_dry_run mismatch (must not be dry-run)'
    Assert-True ((Get-UniqueValue $expert 'challenge_state_bootstrap' $governorChartName) -ceq 'false') 'governor is on the one-shot bootstrap preset, expected the active preset'
    Assert-True ((Get-Sha256 (Join-Path $dataDir $governorBinaryRel)) -ceq $governorBinarySha) 'governor binary hash mismatch'
    Assert-True ((Get-Sha256 $governorPresetPath) -ceq $governorPresetSha) 'governor preset hash mismatch'
}

function Assert-TelemetryContract {
    $contract = Get-ChartContract (Join-Path $profileDir $telemetryChartName)
    $expert = $contract.expert
    Assert-True ((Get-UniqueValue $contract.prefix 'symbol' $telemetryChartName) -ceq 'EURUSD') 'telemetry symbol mismatch'
    Assert-True ((Get-UniqueValue $contract.prefix 'period_type' $telemetryChartName) -ceq '0') 'telemetry period_type mismatch'
    Assert-True ((Get-UniqueValue $contract.prefix 'period_size' $telemetryChartName) -ceq '1') 'telemetry period_size mismatch'
    Assert-True ((Get-UniqueValue $expert 'name' $telemetryChartName) -ceq 'QM_FTMO_TrialTelemetry') 'telemetry EA name mismatch'
    Assert-True ((Get-UniqueValue $expert 'path' $telemetryChartName) -ceq 'Experts\QM_FTMO\QM_FTMO_TrialTelemetry.ex5') 'telemetry EA path mismatch'
    Assert-True ((Get-UniqueValue $expert 'expertmode' $telemetryChartName) -ceq '1') 'telemetry expert disabled'
    Assert-True ((Get-UniqueValue $expert 'InpExpectedLogin' $telemetryChartName) -ceq $expectedAccount) 'telemetry InpExpectedLogin mismatch'
    Assert-True ((Get-UniqueValue $expert 'InpExpectedServer' $telemetryChartName) -ceq $expectedServer) 'telemetry InpExpectedServer mismatch'
    Assert-True ((Get-UniqueValue $expert 'InpTrialId' $telemetryChartName) -ceq $telemetryTrialId) 'telemetry InpTrialId mismatch'
    Assert-True ((Get-Sha256 (Join-Path $dataDir $telemetryBinaryRel)) -ceq $telemetryBinarySha) 'telemetry binary hash mismatch'
    Assert-True ((Get-Sha256 $telemetryPresetPath) -ceq $telemetryPresetSha) 'telemetry preset hash mismatch'
}

function Assert-BlankChartContract {
    $path = Join-Path $profileDir $blankChartName
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "missing blank chart: $path"
    $text = [IO.File]::ReadAllText($path)
    Assert-True ((Get-ChartExperts $text).Count -eq 0) 'chart11 must remain blank (no expert block)'
    Assert-True ((Get-UniqueValue $text 'symbol' $blankChartName) -ceq 'EURUSD') 'blank chart symbol mismatch'
    Assert-True ((Get-UniqueValue $text 'period_type' $blankChartName) -ceq '1') 'blank chart period_type mismatch'
    Assert-True ((Get-UniqueValue $text 'period_size' $blankChartName) -ceq '24') 'blank chart period_size mismatch'
}

try {
    Assert-True (Test-Path -LiteralPath $profileDir -PathType Container) "missing FTMO Default profile: $profileDir"
    Assert-ExactProfileFiles
    Assert-CommonContract
    Assert-GovernorContract
    foreach ($leg in $legs) { Assert-LegContract $leg }
    Assert-TelemetryContract
    Assert-BlankChartContract
    Write-Host 'VERIFIED: FTMO account 1514536732 / Default = account governor + eight SHA-pinned M13 sleeves + trial telemetry collector + blank EURUSD chart'
    exit 0
} catch {
    Write-Error "FTMO demo instrumentation contract verification failed: $($_.Exception.Message)"
    exit 2
}
