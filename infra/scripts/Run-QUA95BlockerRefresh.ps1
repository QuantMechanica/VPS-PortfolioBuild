[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$LogPath = 'C:\QM\repo\infra\smoke\qua95_blocker_refresh_task.log',
    [string]$TaskName = 'QM_QUA95_BlockerRefresh',
    [string]$PythonExe = 'python'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-TaskLog {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
    Write-LogText -Text "[${ts}] $Message"
}

function Write-LogText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [int]$MaxAttempts = 12,
        [int]$SleepMilliseconds = 250
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Add-Content -LiteralPath $LogPath -Value $Text -Encoding utf8
            return
        } catch [System.IO.IOException] {
            if ($attempt -eq $MaxAttempts) {
                throw
            }
            Start-Sleep -Milliseconds $SleepMilliseconds
        }
    }
}

function Write-CommandOutputToLog {
    param(
        [AllowNull()]
        [object[]]$Output
    )

    if ($null -eq $Output) {
        return
    }

    foreach ($line in $Output) {
        $text = if ($null -eq $line) { '' } else { $line.ToString() }
        Write-LogText -Text $text
    }
}

$invoke = Join-Path $RepoRoot 'infra\scripts\Invoke-VerifyDisposition.ps1'
$sync = Join-Path $RepoRoot 'infra\scripts\Update-QUA95BlockerStatus.ps1'
$summary = Join-Path $RepoRoot 'infra\scripts\Write-QUA95BlockedSummary.ps1'
$gate = Join-Path $RepoRoot 'infra\scripts\Get-QUA95GateDecision.ps1'
$assertion = Join-Path $RepoRoot 'infra\scripts\Update-QUA95BlockedAssertion.ps1'
$transition = Join-Path $RepoRoot 'infra\scripts\New-QUA95IssueTransitionPayload.ps1'
$transitionCheck = Join-Path $RepoRoot 'infra\scripts\Test-QUA95IssueTransitionPayload.ps1'
$blockedInvariant = Join-Path $RepoRoot 'infra\scripts\Test-QUA95BlockedInvariant.ps1'
$unblockReadiness = Join-Path $RepoRoot 'infra\scripts\Update-QUA95UnblockReadiness.ps1'
$unblockReadinessSummary = Join-Path $RepoRoot 'infra\scripts\Write-QUA95UnblockReadinessSummary.ps1'
$automationHealth = Join-Path $RepoRoot 'infra\monitoring\Test-QUA95AutomationHealth.ps1'
$auditSignal = Join-Path $RepoRoot 'infra\scripts\Update-QUA95AuditSignal.ps1'
$integrity = Join-Path $RepoRoot 'infra\scripts\Test-QUA95HandoffIntegrity.ps1'
$opsSuiteWriter = Join-Path $RepoRoot 'infra\scripts\Write-QUA95OpsSuiteSnapshot.ps1'
$opsBundleManifest = Join-Path $RepoRoot 'infra\scripts\Update-QUA95OpsBundleManifest.ps1'
$manifest = Join-Path $RepoRoot 'docs\ops\QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.sha256'
$gateOut = 'docs\ops\QUA-95_GATE_DECISION_2026-04-27.json'

foreach ($f in @($invoke, $sync, $summary, $gate, $assertion, $transition, $transitionCheck, $blockedInvariant, $unblockReadiness, $unblockReadinessSummary, $automationHealth, $auditSignal, $integrity, $opsSuiteWriter, $opsBundleManifest, $manifest)) {
    if (-not (Test-Path -LiteralPath $f)) {
        throw "Required script missing: $f"
    }
}

Write-TaskLog "start task=$TaskName"
try {
    $global:LASTEXITCODE = 0
    $invokeOutput = & $invoke -IssueId 'QUA-95' -Symbol 'XTIUSD.DWX' -PythonExe "$PythonExe" 2>&1
    Write-CommandOutputToLog -Output $invokeOutput
    Write-TaskLog ("invoke_verify_disposition_exit_code={0}" -f $LASTEXITCODE)

    $global:LASTEXITCODE = 0
    $syncOutput = & $sync 2>&1
    Write-CommandOutputToLog -Output $syncOutput
    if (-not $?) { throw ("Step failed: {0}" -f $sync) }

    $global:LASTEXITCODE = 0
    $summaryOutput = & $summary 2>&1
    Write-CommandOutputToLog -Output $summaryOutput
    if (-not $?) { throw ("Step failed: {0}" -f $summary) }

    $global:LASTEXITCODE = 0
    $gateOutput = & $gate -OutPath $gateOut -NoFail 2>&1
    Write-CommandOutputToLog -Output $gateOutput
    if (-not $?) { throw ("Step failed: {0}" -f $gate) }

    $global:LASTEXITCODE = 0
    $assertionOutput = & $assertion 2>&1
    Write-CommandOutputToLog -Output $assertionOutput
    if (-not $?) { throw ("Step failed: {0}" -f $assertion) }

    $global:LASTEXITCODE = 0
    $transitionOutput = & $transition 2>&1
    Write-CommandOutputToLog -Output $transitionOutput
    if (-not $?) { throw ("Step failed: {0}" -f $transition) }

    $global:LASTEXITCODE = 0
    $transitionCheckOutput = & $transitionCheck 2>&1
    Write-CommandOutputToLog -Output $transitionCheckOutput
    if ($LASTEXITCODE -ne 0) { throw ("Step failed with exit code {0}: {1}" -f $LASTEXITCODE, $transitionCheck) }

    $global:LASTEXITCODE = 0
    $blockedInvariantOutput = & $blockedInvariant 2>&1
    Write-CommandOutputToLog -Output $blockedInvariantOutput
    if ($LASTEXITCODE -ne 0) { throw ("Step failed with exit code {0}: {1}" -f $LASTEXITCODE, $blockedInvariant) }

    $global:LASTEXITCODE = 0
    $unblockReadinessOutput = & $unblockReadiness 2>&1
    Write-CommandOutputToLog -Output $unblockReadinessOutput
    if ($LASTEXITCODE -ne 0) { throw ("Step failed with exit code {0}: {1}" -f $LASTEXITCODE, $unblockReadiness) }

    $global:LASTEXITCODE = 0
    $unblockReadinessSummaryOutput = & $unblockReadinessSummary 2>&1
    Write-CommandOutputToLog -Output $unblockReadinessSummaryOutput
    if ($LASTEXITCODE -ne 0) { throw ("Step failed with exit code {0}: {1}" -f $LASTEXITCODE, $unblockReadinessSummary) }

    $global:LASTEXITCODE = 0
    $automationHealthOutput = & $automationHealth -SkipRefreshLastResultCheck -SkipTaskHealthCheck 2>&1
    Write-CommandOutputToLog -Output $automationHealthOutput
    if ($LASTEXITCODE -ne 0) { throw ("Step failed with exit code {0}: {1}" -f $LASTEXITCODE, $automationHealth) }

    $global:LASTEXITCODE = 0
    $auditSignalOutput = & $auditSignal 2>&1
    Write-CommandOutputToLog -Output $auditSignalOutput
    if ($LASTEXITCODE -ne 0) { throw ("Step failed with exit code {0}: {1}" -f $LASTEXITCODE, $auditSignal) }

    $hashFiles = @(
        'docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.md',
        'docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.json',
        'docs/ops/QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json'
    )
    $lines = foreach ($rel in $hashFiles) {
        $full = Join-Path $RepoRoot $rel
        $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $full).Hash.ToLowerInvariant()
        "{0}  {1}" -f $h, $rel
    }
    $lines | Set-Content -LiteralPath $manifest -Encoding ASCII
    Write-TaskLog "manifest_refreshed"

    $global:LASTEXITCODE = 0
    $integrityOutput = & $integrity 2>&1
    Write-CommandOutputToLog -Output $integrityOutput
    if ($LASTEXITCODE -ne 0) { throw ("Step failed with exit code {0}: {1}" -f $LASTEXITCODE, $integrity) }

    $global:LASTEXITCODE = 0
    $opsBundleOutput = & $opsBundleManifest 2>&1
    Write-CommandOutputToLog -Output $opsBundleOutput
    if ($LASTEXITCODE -ne 0) { throw ("Step failed with exit code {0}: {1}" -f $LASTEXITCODE, $opsBundleManifest) }

    $global:LASTEXITCODE = 0
    $opsSuiteOutput = & $opsSuiteWriter -SkipBlockerTaskHealthCheck 2>&1
    Write-CommandOutputToLog -Output $opsSuiteOutput
    if ($LASTEXITCODE -ne 0) { throw ("Step failed with exit code {0}: {1}" -f $LASTEXITCODE, $opsSuiteWriter) }

    $global:LASTEXITCODE = 0
    $opsBundleOutput = & $opsBundleManifest 2>&1
    Write-CommandOutputToLog -Output $opsBundleOutput
    if ($LASTEXITCODE -ne 0) { throw ("Step failed with exit code {0}: {1}" -f $LASTEXITCODE, $opsBundleManifest) }

    Write-TaskLog "success task=$TaskName"
    exit 0
} catch {
    Write-TaskLog "failure task=$TaskName"
    Write-TaskLog ("error=" + $_.Exception.Message)
    exit 1
}
