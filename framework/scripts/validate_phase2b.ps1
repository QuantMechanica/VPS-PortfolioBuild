param(
    [string]$PythonExe = "python",
    [string]$EvidencePath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

$tests = @(
    "framework/scripts/tests/test_phase_runners_contract.py",
    "framework/scripts/tests/test_phase_verdict_semantics.py",
    "framework/scripts/tests/test_phase_runners_idempotence.py",
    "framework/scripts/tests/test_phase_end_to_end_dryrun.py",
    "framework/scripts/tests/test_phase_runner_log_schema.py",
    "framework/scripts/tests/test_calibration_contract.py"
)

$results = @()
$overall = "PASS"

Push-Location $repoRoot
try {
    foreach ($t in $tests) {
        $module = ($t -replace "/", "." -replace "\\", "." -replace "\.py$", "")
        Write-Host "[phase2b] running $module"
        & $PythonExe -m unittest $module
        $code = $LASTEXITCODE
        $status = if ($code -eq 0) { "PASS" } else { "FAIL" }
        $results += [ordered]@{
            test = $t
            exit_code = $code
            status = $status
        }
        if ($code -ne 0) {
            $overall = "FAIL"
            break
        }
    }
}
finally {
    Pop-Location
}

if ($EvidencePath -ne "") {
    $receipt = [ordered]@{
        phase2b_validation = [ordered]@{
            ts_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            overall = $overall
            tests = $results
        }
    }
    $target = $EvidencePath
    $dir = Split-Path -Parent $target
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $json = $receipt | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($target, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[phase2b] evidence written: $target"
}

if ($overall -ne "PASS") {
    throw "Phase 2b validation failed"
}

Write-Host "[phase2b] all validation checks passed"
