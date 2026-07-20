[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function New-LoggerRow {
    param(
        [Parameter(Mandatory = $true)]
        [int]$EAId,
        [Parameter(Mandatory = $true)]
        [string]$Event
    )
    return ('{{"sv":1,"ts_utc":"2026-07-20T12:00:00Z","ts_broker":"2026-07-20T14:00:00","level":"INFO","ea_id":{0},"slug":"ea-{0}","symbol":"EURUSD.DWX","tf":"H1","magic":{0},"event":"{1}","payload":{{}}}}' -f $EAId, $Event)
}

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "run_smoke.ps1"
$tokens = $null
$parseErrors = $null
$scriptAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw "run_smoke.ps1 failed to parse: $($parseErrors[0])"
}

$requiredFunctions = @("Get-FilePrefixSha256", "Get-QmLoggerFileState", "Save-QmLoggerDelta")
$functionAsts = @($scriptAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $requiredFunctions -contains $node.Name
}, $true))
foreach ($functionName in $requiredFunctions) {
    $functionAst = @($functionAsts | Where-Object { $_.Name -eq $functionName })
    if ($functionAst.Count -ne 1) {
        throw "Expected one $functionName definition, found $($functionAst.Count)."
    }
    Invoke-Expression $functionAst[0].Extent.Text
}

$scriptText = Get-Content -Raw -LiteralPath $scriptPath
$runCaptureIndex = $scriptText.LastIndexOf('Save-QmLoggerDelta `')
$logBombGuardIndex = $scriptText.LastIndexOf('if ($runExec.log_bomb)')
$timeoutGuardIndex = $scriptText.LastIndexOf('if ($runExec.timed_out)')
Assert-True -Condition ($runCaptureIndex -gt 0) -Message "Run-loop logger capture call is missing."
Assert-True `
    -Condition ($logBombGuardIndex -gt 0 -and $logBombGuardIndex -lt $runCaptureIndex) `
    -Message "Log-bomb handling must precede logger capture so partial rows are never published."
Assert-True `
    -Condition ($timeoutGuardIndex -gt 0 -and $timeoutGuardIndex -lt $runCaptureIndex) `
    -Message "Timeout cleanup must precede logger capture so partial rows are never published."
$captureGuardStart = $scriptText.LastIndexOf('if ($null -ne $loggerStateBefore)', $runCaptureIndex)
$captureGuard = $scriptText.Substring($captureGuardStart, $runCaptureIndex - $captureGuardStart)
Assert-True `
    -Condition ($captureGuard -match 'Wait-ForMetaTesterQuiescence') `
    -Message "Logger capture must prove metatester quiescence before reading the delta."

$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $tempBase ("qm-run-smoke-logger-{0}" -f [guid]::NewGuid().ToString("N"))))
if (-not $tempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing test temp path outside '$tempBase': '$tempRoot'"
}

try {
    $eaId = 4242
    $loggerDir = Join-Path $tempRoot "Tester\Agent-127.0.0.1-3001\MQL5\Files\QM"
    New-Item -ItemType Directory -Path $loggerDir -Force | Out-Null
    $loggerPath = Join-Path $loggerDir "QM5_4242_ea-4242.log"
    $utf8 = [System.Text.UTF8Encoding]::new($false)

    $baselineBytes = $utf8.GetBytes((New-LoggerRow -EAId $eaId -Event "BASELINE") + "`r`n")
    [System.IO.File]::WriteAllBytes($loggerPath, $baselineBytes)
    $beforeState = Get-QmLoggerFileState -TerminalRoot $tempRoot -EAIdValue $eaId

    $deltaText = (New-LoggerRow -EAId $eaId -Event "SMOKE_START") + "`r`n" +
        (New-LoggerRow -EAId $eaId -Event "SMOKE_DONE") + "`r`n"
    $deltaBytes = $utf8.GetBytes($deltaText)
    $appendStream = [System.IO.File]::Open(
        $loggerPath,
        [System.IO.FileMode]::Append,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::ReadWrite
    )
    try {
        $appendStream.Write($deltaBytes, 0, $deltaBytes.Length)
    } finally {
        $appendStream.Dispose()
    }

    $samplePath = Join-Path $tempRoot "evidence\logger_sample.jsonl"
    $capture = Save-QmLoggerDelta `
        -BeforeState $beforeState `
        -TerminalRoot $tempRoot `
        -EAIdValue $eaId `
        -DestinationPath $samplePath

    Assert-True -Condition ($null -ne $capture) -Message "Expected a valid exact logger capture."
    $actualBytes = [System.IO.File]::ReadAllBytes($samplePath)
    Assert-True `
        -Condition ([System.Convert]::ToBase64String($actualBytes) -ceq [System.Convert]::ToBase64String($deltaBytes)) `
        -Message "Published logger sample is not byte-identical to the appended source delta."
    Assert-True -Condition ($capture.event_count -eq 2) -Message "Expected two captured events."
    Assert-True -Condition ($capture.source_offset_start -eq $baselineBytes.Length) -Message "Unexpected source start offset."
    Assert-True `
        -Condition ($capture.source_offset_end_exclusive -eq ($baselineBytes.Length + $deltaBytes.Length)) `
        -Message "Unexpected source end offset."

    $rejectRoot = Join-Path $tempRoot "wrong-ea"
    $rejectDir = Join-Path $rejectRoot "Tester\Agent-127.0.0.1-3002\MQL5\Logs\QM"
    New-Item -ItemType Directory -Path $rejectDir -Force | Out-Null
    $rejectLog = Join-Path $rejectDir "QM5_4242_ea-4242.log"
    [System.IO.File]::WriteAllBytes($rejectLog, $baselineBytes)
    $rejectBefore = Get-QmLoggerFileState -TerminalRoot $rejectRoot -EAIdValue $eaId
    $wrongEaBytes = $utf8.GetBytes((New-LoggerRow -EAId 9999 -Event "WRONG_EA") + "`r`n")
    $rejectAppend = [System.IO.File]::Open($rejectLog, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
    try {
        $rejectAppend.Write($wrongEaBytes, 0, $wrongEaBytes.Length)
    } finally {
        $rejectAppend.Dispose()
    }
    $rejected = Save-QmLoggerDelta `
        -BeforeState $rejectBefore `
        -TerminalRoot $rejectRoot `
        -EAIdValue $eaId `
        -DestinationPath (Join-Path $rejectRoot "logger_sample.jsonl") `
        3>$null
    Assert-True -Condition ($null -eq $rejected) -Message "Wrong-EA logger rows must be rejected."

    Write-Output "Test-RunSmokeLoggerSample.result=PASS"
} finally {
    if ((Test-Path -LiteralPath $tempRoot) -and
        $tempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
