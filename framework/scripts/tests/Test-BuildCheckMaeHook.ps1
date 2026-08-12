[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$buildCheck = Join-Path $repoRoot "framework\scripts\build_check.ps1"
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("qm_build_check_mae_" + [guid]::NewGuid().ToString("N"))
$eaRoot = Join-Path $fixtureRoot "framework\EAs"
$reportRoot = Join-Path $fixtureRoot "reports"

function Invoke-Fixture {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Source
    )

    $target = Join-Path $eaRoot $Label
    $caseReportRoot = Join-Path $reportRoot $Label
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $target "$Label.mq5") -Value $Source -Encoding utf8

    & pwsh -NoProfile -File $buildCheck `
        -RepoRoot $fixtureRoot `
        -EALabel $Label `
        -ReportRoot $caseReportRoot `
        -SkipCompile `
        -SkipMagicCheck `
        -SkipSetValidation `
        -SkipLoggerSchema `
        -SkipForbiddenScan `
        -SkipInputGroupCheck `
        -SkipPerfStaticCheck | Out-Null
    if($LASTEXITCODE -ne 0) {
        throw "$Label build_check exited $LASTEXITCODE"
    }
    $reports = @(Get-ChildItem -LiteralPath $caseReportRoot -Filter "build_check_*.json")
    if($reports.Count -ne 1) {
        throw "$Label expected one report, got $($reports.Count)"
    }
    return (Get-Content -Raw -LiteralPath $reports[0].FullName | ConvertFrom-Json)
}

try {
    New-Item -ItemType Directory -Path $eaRoot -Force | Out-Null

    $missing = Invoke-Fixture -Label "QM5_90001_retest-mae-missing" -Source @'
void OnTick()
  {
   if(false) return;
  }
'@
    if(@($missing.warnings | Where-Object { $_ -match "EA_Q08_MAE_HOOK_MISSING" }).Count -ne 1) {
        throw "missing fixture did not emit exactly one MAE warning"
    }

    $direct = Invoke-Fixture -Label "QM5_90002_direct-mae" -Source @'
void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
  }
'@
    if(@($direct.warnings | Where-Object { $_ -match "EA_Q08_MAE_HOOK_MISSING" }).Count -ne 0) {
        throw "direct fixture emitted a false MAE warning"
    }

    $fallback = Invoke-Fixture -Label "QM5_90003_killswitch-mae" -Source @'
void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
  }
'@
    if(@($fallback.warnings | Where-Object { $_ -match "EA_Q08_MAE_HOOK_MISSING" }).Count -ne 0) {
        throw "kill-switch fallback fixture emitted a false MAE warning"
    }

    $noTick = Invoke-Fixture -Label "QM5_90004_no-ontick" -Source @'
int OnInit() { return 0; }
'@
    if(@($noTick.warnings | Where-Object { $_ -match "EA_Q08_MAE_HOOK_MISSING" }).Count -ne 0) {
        throw "no-OnTick fixture emitted a false MAE warning"
    }

    Write-Output "Test-BuildCheckMaeHook=PASS"
}
finally {
    if(Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}
