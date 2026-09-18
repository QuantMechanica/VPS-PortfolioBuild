<#
.SYNOPSIS
  Verify the current FTMO demo-instrumentation recovery contract read-only.

.DESCRIPTION
  RE-PINNED 2026-09-18 for the FTMO demo book v3 cutover (roster **D2g6**).
  Authority: decision OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917.
  Package:   docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\
             (PACKAGE.md sections 3/4, CHART_PLAN.md section 2, roster.json,
             sets\manifest.json, bin\). Re-pin owed by GAPS G1 of that package
             and by router ops_issue 57bfd3af item 1; RUNBOOK step 0/7.

  Previously this verifier pinned the incumbent 2026-09-06 M13 profile: the
  account governor on chart01, EIGHT trading sleeves on chart02-09, the trial
  telemetry collector on chart10 and a blank chart11. D2g6 detaches six of
  those sleeves and attaches four new ones, so the deployed profile becomes
  NINE charts: governor + SIX sleeves + collector + blank. Anything still
  pinned to the eleven-chart shape exits 2 and `FTMO_ON.ps1` (scheduled task
  `QM_FTMO_AtLogon`) refuses to launch with `profile_contract_failed` -- the
  exact regression already recorded on 2026-09-09.

  The D2g6 book, from roster.json / CHART_PLAN.md section 2c:

      13213 balke-gmt3-range-breakout     USDJPY H1  slot 0  magic 132130000  RISK 0.15625
      10706 tv-mon-ls                     GBPUSD H1  slot 1  magic 107060001  RISK 0.3125
      10700 tv-liq-break                  XAUUSD H1  slot 3  magic 107000003  RISK 0.3125
      11422 williams-18ma-outside-bar-d1  USDCAD D1  slot 4  magic 114220004  RISK 0.3125
      10403 et-turtle20x                  XAUUSD D1  slot 2  magic 104030002  RISK 0.3125
      41219 cum-rsi2-commodity-requal8    XAUUSD D1  slot 0  magic 412190000  RISK 0.3125

  Book risk 1.71875 %. 13213 is the ONE sleeve at half risk -- a 0.3125 there
  silently turns a 1.71875 % book into 1.875 %, so it is pinned explicitly.

  PRESET DIRECTORY MOVED. The incumbent pin read the flat `MQL5\Presets`.
  `demo_install` writes every D2g6 preset into `MQL5\Profiles\Presets\QM_FTMO_M13`
  (see demo_install_dryrun.json `plan.copies`), which is also where CHART_PLAN
  section 2c tells the operator to load them from. This verifier now pins that
  directory. The flat copy is legacy and is deliberately NOT consulted.

  PINNED HASHES. Preset sha256 are the package `sets\` / `collector\` bytes and
  binary sha256 the package `bin\` bytes (PACKAGE.md section 3 and 4), upper-cased
  because `Get-Sha256` returns upper-case and every comparison is `-ceq`. The
  governor's own preset and binary are NOT in the package: the binary is
  unchanged, and the preset is the one `governor_rebind --apply` rewrote in the
  repo (receipt governor_rebind_receipt.json, `active f7345341... -> f1b277a6...`).

  ASSUMPTIONS -- read before trusting a green run (RUNBOOK step 7):

  (A) CHART FILE NAMES. MT5 renumbers `chart*.chr` on clean shutdown, and
      CHART_PLAN.md section 3 states plainly that the post-edit numbering "is
      not predictable from this table and must be read back from disk". No
      post-edit numbering exists in CHART_PLAN.md to copy, so `$legs` below
      carries the numbering implied by CHART_PLAN section 2 -- the five
      surviving charts keep their window order and renumber contiguously
      (governor, 10706, 11422, collector, blank -> chart01..chart05), then the
      four new charts follow in CHART_PLAN section 2c row order
      (13213, 10700, 10403, 41219 -> chart06..chart09). EVERY OTHER FIELD in
      this file is derived from the package and is authoritative; the `chart`
      column is the single field that must be re-confirmed against the step-6
      `Get-ChildItem ... Get-FileHash` readback and corrected there if MT5
      ordered the windows differently. A wrong name here fails closed (symbol /
      EA-name mismatch), never open.

  (B) GOVERNOR PRESET PLACEMENT. `demo_install` does not copy the governor
      preset; the operator refreshes
      `QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_active.set` into
      `Profiles\Presets\QM_FTMO_M13` from the repo after `governor_rebind`
      (CHART_PLAN section 2d). Its pin is the LINE-ENDING-NORMALIZED digest of
      the rebound repo file -- which is what the deployed copy has always
      hashed to (the incumbent pin F7345341... equals the binding's normalized
      `sha256_before`, and the deployed file on 2026-09-18 hashes to exactly
      that). If the deployed copy ever carries CRLF this assertion fires, and
      the fix is to re-copy the preset, never to relax the pin.

  This verifier never attaches an EA, enables an expert, edits a profile, or
  starts MT5. It is fail-closed: any mismatch exits 2.

  Historical note retained: several incumbent sleeve hashes pinned before this
  re-pin were rebuilt after the 2026-09-06 manifest was signed, so this script
  has always pinned DEPLOYED REALITY rather than the sealed install receipt.
  For D2g6 the two coincide -- `demo_install.validate_sources()` re-checks every
  repo `.ex5` against its Q10 seal (`sealed_binary_mismatch`) at install time,
  so the binaries pinned here are the sealed ones.
#>
[CmdletBinding()]
param(
    # Overrides exist so the pinned table can be proven to parse against a
    # synthetic fixture WITHOUT touching the live FTMO terminal. They default to
    # the real demo terminal, so the launcher invocation is unchanged.
    [string]$DataDir = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850',
    [string]$ProfileDir,
    [string]$PresetDir,
    [string]$ExpertsDir,
    [string]$CommonIni
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'liveops_profile_contract.ps1')

$dataDir = $DataDir
if (-not $ProfileDir) { $ProfileDir = Join-Path $dataDir 'MQL5\Profiles\Charts\Default' }
if (-not $PresetDir)  { $PresetDir  = Join-Path $dataDir 'MQL5\Profiles\Presets\QM_FTMO_M13' }
if (-not $ExpertsDir) { $ExpertsDir = Join-Path $dataDir 'MQL5\Experts\QM_FTMO' }
if (-not $CommonIni)  { $CommonIni  = Join-Path $dataDir 'config\common.ini' }

$profileDir = $ProfileDir
$presetDir = $PresetDir
$terminalExpertsDir = $ExpertsDir
$common = $CommonIni
$expectedAccount = '1514536732'
$expectedServer = 'FTMO-Demo'

# D2g6 sleeves. period_type=1 is "hours": H1 = 1/1, D1 = 1/24 (CHART_PLAN 2c).
# See assumption (A) above for the `chart` column.
$legs = @(
    [pscustomobject]@{ chart='chart02.chr'; ea_id=10706; slug='tv-mon-ls'; symbol='GBPUSD'; period_type='1'; period_size='1';  expertmode='1'; slot='1'; risk_percent='0.3125';  risk_fixed='0'; portfolio_weight='1'; preset='QM5_10706_GBPUSD_H1_live_trial.set'; preset_sha='31C37EC30421A51D7938EBFE911EF13E6615C678D0727DED9DEF09CB5CD1D140'; binary_sha='EAFFDA6F03C8B422896C0E9AB5EA0F3C7100F8546592353ED661F19D056B78CB' },
    [pscustomobject]@{ chart='chart03.chr'; ea_id=11422; slug='williams-18ma-outside-bar-entry-d1'; symbol='USDCAD'; period_type='1'; period_size='24'; expertmode='1'; slot='4'; risk_percent='0.3125';  risk_fixed='0'; portfolio_weight='1'; preset='QM5_11422_USDCAD_D1_live_trial.set'; preset_sha='215615B5DA7AE2F49DD3D9DAE7E85CBDFF522940F69892D04CDF3C0F61378EA5'; binary_sha='2B98E9E902313148BE78D88513FCBDA2476150B1A7605EB15A50B2CCA6B32D66' },
    [pscustomobject]@{ chart='chart06.chr'; ea_id=13213; slug='balke-gmt3-range-breakout'; symbol='USDJPY'; period_type='1'; period_size='1';  expertmode='1'; slot='0'; risk_percent='0.15625'; risk_fixed='0'; portfolio_weight='1'; preset='QM5_13213_USDJPY_H1_live_trial.set'; preset_sha='19C771FF8224DCFFA5E86DF0814F5C51ECAC8B2D7F5D898D1EE2E855C849A777'; binary_sha='8C99DEA16FBF758A4B2DA9F49A26DB26BFE7FED3589F2066BE5120314106A8F0' },
    [pscustomobject]@{ chart='chart07.chr'; ea_id=10700; slug='tv-liq-break'; symbol='XAUUSD'; period_type='1'; period_size='1';  expertmode='1'; slot='3'; risk_percent='0.3125';  risk_fixed='0'; portfolio_weight='1'; preset='QM5_10700_XAUUSD_H1_live_trial.set'; preset_sha='6E319D98E5EA7B6790B8C05A7CF2D3B24CB184C070576F20D906FCB0DCD69DD7'; binary_sha='5FBF2BA0048250041296DEDA0008FF6757F56DCE27E39EFEAD69F45838E5E6BE' },
    [pscustomobject]@{ chart='chart08.chr'; ea_id=10403; slug='et-turtle20x'; symbol='XAUUSD'; period_type='1'; period_size='24'; expertmode='1'; slot='2'; risk_percent='0.3125';  risk_fixed='0'; portfolio_weight='1'; preset='QM5_10403_XAUUSD_D1_live_trial.set'; preset_sha='9D8414CE65912A6B75228717D9CF24CDD8329D2F31A8171851242E051132B1EF'; binary_sha='F927F07F46579BBB9A1BDCFDB7CAA9B246E9D7555935FBB878F7FC01AFBF7AB3' },
    [pscustomobject]@{ chart='chart09.chr'; ea_id=41219; slug='cum-rsi2-commodity-requal8'; symbol='XAUUSD'; period_type='1'; period_size='24'; expertmode='1'; slot='0'; risk_percent='0.3125';  risk_fixed='0'; portfolio_weight='1'; preset='QM5_41219_XAUUSD_D1_live_trial.set'; preset_sha='BA8FFD63DB87DE12495A7536FF8F8FEF4E9447A9795C76D82EF2416F08D5F128'; binary_sha='E9670141E89249AFF7DF44A10A2402E2103AA4CECF8D0A35A8CD6D6BABEDF108' }
)

# The magics the book is supposed to carry (ea_id*10000+slot). Asserted against
# the legs themselves AND against the governor allow-list, so a hand-edit that
# changes one of the two cannot pass unnoticed.
$expectedMagics = @('104030002','107000003','107060001','114220004','132130000','412190000')
$expectedBookRiskPct = 1.71875

$governorChartName = 'chart01.chr'
$governorPresetPath = Join-Path $presetDir 'QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_active.set'
$governorPresetSha = 'F1B277A6BF46CE6FA634E3E3A264F0CCBE667E5013417F6CF5C36F5A3D8FA5C6'
$governorBinaryRel = 'MQL5\Experts\QM_FTMO\QM5_13206_ftmo-account-governor.ex5'
$governorBinarySha = 'E5E827CD05163DE0D0C7919E9E072759EFBD91A6B1E464CF9E962E850F4878F6'
$governorAllowedMagicsCsv = '104030002,107000003,107060001,114220004,132130000,412190000'
$governorEaIdsCsv = '10403,10700,10706,11422,13213,41219'
$governorSymbolsCsv = 'GBPUSD,USDCAD,USDJPY,XAUUSD'
$governorChallengeId = 'M13_D2G6_20260918_1514536732'

$telemetryChartName = 'chart04.chr'
$telemetryPresetPath = Join-Path $presetDir 'QM_FTMO_TrialTelemetry_1514536732.set'
$telemetryPresetSha = '9DE24D3D6B3EE4C46AA3F1D7A8F0B0FF56BACB830E4F200651EBF4E2E581E88C'
$telemetryBinaryRel = 'MQL5\Experts\QM_FTMO\QM_FTMO_TrialTelemetry.ex5'
$telemetryBinarySha = '411638A1AE177326070C19B28C849FDA36594592279303CE7D96F36BFA458258'
$telemetryTrialId = 'M13_D2G6_20260918_1514536732'
$telemetryOutputDir = 'QM\ftmo_trial\FTMO_DEMO_BOOK_V3_D2G6_20260918'

$blankChartName = 'chart05.chr'

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
    # Nine charts: governor + six sleeves + collector + blank, plus order.wnd.
    $expected = @('chart01.chr','chart02.chr','chart03.chr','chart04.chr',
        'chart05.chr','chart06.chr','chart07.chr','chart08.chr','chart09.chr',
        'order.wnd') | Sort-Object
    $actual = @(Get-ChildItem -LiteralPath $profileDir -File |
        ForEach-Object Name | Sort-Object)
    Assert-True ([string]::Join('|', $actual) -ceq [string]::Join('|', $expected)) (
        'unexpected Default profile file set: ' + [string]::Join(', ', $actual)
    )
}

function Assert-BookShape {
    # The legs table must itself describe the D2g6 book: six sleeves, the magic
    # formula ea_id*10000+slot, the pinned magic set and the 1.71875 % book.
    Assert-True ($legs.Count -eq 6) "expected six D2g6 sleeves, table has $($legs.Count)"
    $charts = @($legs | ForEach-Object { $_.chart } | Sort-Object -Unique)
    Assert-True ($charts.Count -eq $legs.Count) 'two sleeves pinned to the same chart file'
    $magics = @($legs | ForEach-Object { [string]([int]$_.ea_id * 10000 + [int]$_.slot) } | Sort-Object)
    $wanted = @($expectedMagics | Sort-Object)
    Assert-True ([string]::Join(',', $magics) -ceq [string]::Join(',', $wanted)) (
        'leg magics are not the D2g6 six: ' + [string]::Join(',', $magics)
    )
    $risk = 0.0
    foreach ($leg in $legs) { $risk += [double]$leg.risk_percent }
    Assert-True ([math]::Abs($risk - $expectedBookRiskPct) -lt 1e-9) (
        "book risk $risk does not equal $expectedBookRiskPct"
    )
    Assert-True ($governorAllowedMagicsCsv -ceq [string]::Join(',', $wanted)) (
        'governor allow-list pin disagrees with the leg magics'
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
        # qm_filter_* are pattern-permission-filter slots the EA rewrites at
        # runtime; they are not economics/risk parameters and the saved chart
        # legitimately differs from the derived preset. Nothing else is exempt:
        # the 2026-09-08 qm_panel_build_hash carve-out was for QM5_11421, which
        # D2g6 detaches, and no D2g6 preset contains that key.
        if ($key -like 'qm_filter_*') { continue }
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
    Assert-True ((Get-UniqueValue $expert 'governed_symbols_csv' $governorChartName) -ceq $governorSymbolsCsv) 'governor governed_symbols_csv mismatch'
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
    Assert-True ((Get-UniqueValue $expert 'InpOutputDir' $telemetryChartName) -ceq $telemetryOutputDir) 'telemetry InpOutputDir mismatch (collector not bound to the D2g6 cycle)'
    Assert-True ((Get-Sha256 (Join-Path $dataDir $telemetryBinaryRel)) -ceq $telemetryBinarySha) 'telemetry binary hash mismatch'
    Assert-True ((Get-Sha256 $telemetryPresetPath) -ceq $telemetryPresetSha) 'telemetry preset hash mismatch'
}

function Assert-BlankChartContract {
    $path = Join-Path $profileDir $blankChartName
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "missing blank chart: $path"
    $text = [IO.File]::ReadAllText($path)
    Assert-True ((Get-ChartExperts $text).Count -eq 0) "$blankChartName must remain blank (no expert block)"
    Assert-True ((Get-UniqueValue $text 'symbol' $blankChartName) -ceq 'EURUSD') 'blank chart symbol mismatch'
    Assert-True ((Get-UniqueValue $text 'period_type' $blankChartName) -ceq '1') 'blank chart period_type mismatch'
    Assert-True ((Get-UniqueValue $text 'period_size' $blankChartName) -ceq '24') 'blank chart period_size mismatch'
}

try {
    Assert-True (Test-Path -LiteralPath $profileDir -PathType Container) "missing FTMO Default profile: $profileDir"
    Assert-True (Test-Path -LiteralPath $presetDir -PathType Container) "missing FTMO preset dir: $presetDir"
    Assert-BookShape
    Assert-ExactProfileFiles
    Assert-CommonContract
    Assert-GovernorContract
    foreach ($leg in $legs) { Assert-LegContract $leg }
    Assert-TelemetryContract
    Assert-BlankChartContract
    Write-Host 'VERIFIED: FTMO account 1514536732 / Default = account governor + six SHA-pinned D2g6 sleeves (book risk 1.71875%) + trial telemetry collector + blank EURUSD chart'
    exit 0
} catch {
    Write-Error "FTMO demo instrumentation contract verification failed: $($_.Exception.Message)"
    exit 2
}
