[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$buildCheck = Join-Path $repoRoot "framework\scripts\build_check.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("qm-buildcheck-events-" + [guid]::NewGuid().ToString("N"))
$eaLabel = "QM5_9999_fixture"
$eaDir = Join-Path $tempRoot "framework\EAs\$eaLabel"
$registryDir = Join-Path $tempRoot "framework\registry"
$reportRoot = Join-Path $tempRoot "reports"
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Invoke-FixtureBuildCheck {
    param([Parameter(Mandatory = $true)][string]$SamplePath)

    $output = & pwsh -NoProfile -File $buildCheck `
        -RepoRoot $tempRoot `
        -EALabel $eaLabel `
        -LoggerSamplePath $SamplePath `
        -ReportRoot $reportRoot `
        -SkipCompile `
        -SkipMagicCheck `
        -SkipSetValidation `
        -SkipForbiddenScan `
        -SkipInputGroupCheck `
        -SkipMaeHookCheck `
        -SkipPerfStaticCheck 2>&1
    return @{
        ExitCode = $LASTEXITCODE
        Text = ($output | Out-String)
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

try {
    New-Item -ItemType Directory -Force -Path $eaDir, $registryDir, $reportRoot | Out-Null
    $registry = @{
        schema_version = 1
        streams = @{
            qm_events = @{
                schema_version = 1
                event_names = @("REGISTERED_EVENT")
                required_fields = @("sv", "ts_utc", "ts_broker", "level", "ea_id", "slug", "symbol", "tf", "magic", "event", "payload")
            }
            q08_trades = @{
                schema_version = 1
                event_names = @("TRADE_CLOSED")
                required_fields = @("event", "magic", "time", "entry_time", "mae_acct", "net", "profit", "swap", "commission", "volume", "notional", "symbol")
            }
        }
    }
    Write-Utf8NoBom -Path (Join-Path $registryDir "event_vocabulary.json") `
        -Content ($registry | ConvertTo-Json -Depth 8)

    $eaPath = Join-Path $eaDir "$eaLabel.mq5"
    Write-Utf8NoBom -Path $eaPath -Content @'
void OnTick()
  {
   QM_KillSwitchCheck();
   QM_LogEvent(QM_INFO, "REGISTERED_EVENT", "{}");
  }
'@

    $validPath = Join-Path $tempRoot "valid.jsonl"
    Write-Utf8NoBom -Path $validPath -Content '{"sv":1,"ts_utc":"2026-07-20T00:00:00Z","ts_broker":"2026-07-20T02:00:00","level":"INFO","ea_id":9999,"slug":"fixture","symbol":"EURUSD.DWX","tf":"H1","magic":99990000,"event":"REGISTERED_EVENT","payload":{}}'
    $valid = Invoke-FixtureBuildCheck -SamplePath $validPath
    Assert-True ($valid.ExitCode -eq 0) "registered schema-v1 sample should pass: $($valid.Text)"
    Assert-True ($valid.Text -notmatch "EVENT_VOCABULARY_UNKNOWN") "registered event emitted an unknown warning"

    $q08Path = Join-Path $tempRoot "q08.jsonl"
    Write-Utf8NoBom -Path $q08Path -Content '{"event":"TRADE_CLOSED","magic":99990000,"time":1784505600,"entry_time":1784502000,"mae_acct":-12.5,"net":4.0,"profit":5.0,"swap":0.0,"commission":-1.0,"volume":0.1,"notional":10000.0,"symbol":"EURUSD.DWX"}'
    $q08 = Invoke-FixtureBuildCheck -SamplePath $q08Path
    Assert-True ($q08.ExitCode -eq 0) "registered bare q08 schema should pass: $($q08.Text)"

    $badVersionPath = Join-Path $tempRoot "bad-version.jsonl"
    Write-Utf8NoBom -Path $badVersionPath -Content '{"sv":2,"ts_utc":"2026-07-20T00:00:00Z","ts_broker":"2026-07-20T02:00:00","level":"INFO","ea_id":9999,"slug":"fixture","symbol":"EURUSD.DWX","tf":"H1","magic":99990000,"event":"REGISTERED_EVENT","payload":{}}'
    $badVersion = Invoke-FixtureBuildCheck -SamplePath $badVersionPath
    Assert-True ($badVersion.ExitCode -eq 1) "wrong schema version should fail"
    Assert-True ($badVersion.Text -match "BUILD_CHECK_LOGGER_SCHEMA_VERSION_INVALID") "wrong schema version failure class missing"

    $unknownPath = Join-Path $tempRoot "unknown.jsonl"
    Write-Utf8NoBom -Path $unknownPath -Content '{"sv":1,"ts_utc":"2026-07-20T00:00:00Z","ts_broker":"2026-07-20T02:00:00","level":"INFO","ea_id":9999,"slug":"fixture","symbol":"EURUSD.DWX","tf":"H1","magic":99990000,"event":"UNKNOWN_RUNTIME_EVENT","payload":{}}'
    $unknown = Invoke-FixtureBuildCheck -SamplePath $unknownPath
    Assert-True ($unknown.ExitCode -eq 0) "unknown runtime event must warn, not fail: $($unknown.Text)"
    Assert-True ($unknown.Text -match "BUILD_CHECK_EVENT_VOCABULARY_UNKNOWN") "unknown runtime warning missing"

    Write-Utf8NoBom -Path $eaPath -Content @'
void OnTick()
  {
   QM_KillSwitchCheck();
   QM_LogEvent(QM_INFO, "UNKNOWN_STATIC_EVENT", "{}");
  }
'@
    $unknownStatic = Invoke-FixtureBuildCheck -SamplePath $validPath
    Assert-True ($unknownStatic.ExitCode -eq 0) "unknown EA literal must warn, not fail: $($unknownStatic.Text)"
    Assert-True ($unknownStatic.Text -match "EA_EVENT_VOCABULARY_UNKNOWN") "unknown EA-literal warning missing"

    Write-Output "Test-BuildCheckEventVocabulary=PASS"
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
