[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$RunAsUser = "",
    [string]$PythonExe = "python",
    [bool]$IncludeGateEvaluator = $true,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RunAsUser {
    param([string]$ExplicitUser)
    if (-not [string]::IsNullOrWhiteSpace($ExplicitUser)) {
        return $ExplicitUser
    }

    $preferredTaskNames = @(
        "QM_PipelineHealth_Watchdog",
        "QM_PipelineState_Build_Hourly",
        "QM_Phase_Orchestrator"
    )
    foreach ($taskName in $preferredTaskNames) {
        try {
            $csv = schtasks /Query /TN $taskName /V /FO CSV 2>$null
            if (-not $csv) { continue }
            $row = $csv | ConvertFrom-Csv | Select-Object -First 1
            $user = [string]$row."Run As User"
            if (-not [string]::IsNullOrWhiteSpace($user) -and $user -ne "N/A") {
                return $user
            }
        }
        catch {
            continue
        }
    }

    $all = schtasks /Query /FO CSV /V | ConvertFrom-Csv
    $qmUser = $all |
        Where-Object {
            $_.TaskName -like "\QM_*" -and
            $_."Run As User" -notin @("SYSTEM", "N/A", "", $null)
        } |
        Select-Object -ExpandProperty "Run As User" -First 1
    if (-not [string]::IsNullOrWhiteSpace([string]$qmUser)) {
        return [string]$qmUser
    }

    throw "Could not auto-detect QM service account from existing QM_* tasks. Pass -RunAsUser explicitly."
}

$taskXmlDir = Join-Path $RepoRoot "framework\ops\scheduled_tasks"
if (-not (Test-Path -LiteralPath $taskXmlDir)) {
    throw "Missing scheduled task XML directory: $taskXmlDir"
}

$resolvedUser = Resolve-RunAsUser -ExplicitUser $RunAsUser
Write-Host "Using RunAs account: $resolvedUser"

$resolvedPythonExe = $PythonExe
if (-not [System.IO.Path]::IsPathRooted($resolvedPythonExe)) {
    $pyCmd = Get-Command -Name $resolvedPythonExe -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $pyCmd -or [string]::IsNullOrWhiteSpace($pyCmd.Source)) {
        throw "Python executable '$PythonExe' is not resolvable to an absolute path. Pass -PythonExe explicitly."
    }
    $resolvedPythonExe = $pyCmd.Source
}
if (-not (Test-Path -LiteralPath $resolvedPythonExe -PathType Leaf)) {
    throw "Python executable not found: $resolvedPythonExe"
}
Write-Host "Using Python executable: $resolvedPythonExe"

$tempDir = Join-Path $env:TEMP ("qm_mt5_worker_xml_" + [guid]::NewGuid().ToString("N"))
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

function Register-TaskFromXml {
    param(
        [string]$TaskName,
        [string]$SourceXml,
        [string]$RenderedXml,
        [string]$RunAsUser,
        [string]$PythonExe,
        [switch]$WhatIf
    )

    if (-not (Test-Path -LiteralPath $SourceXml)) {
        throw "Missing XML definition: $SourceXml"
    }

    $content = Get-Content -LiteralPath $SourceXml -Raw
    $content = $content.Replace("__RUN_AS_USER__", $RunAsUser)
    $content = $content.Replace("__PYTHON_EXE__", $PythonExe)
    if ($TaskName -match '^QM_MT5_Worker_T(\d+)$') {
        $terminal = "T$($Matches[1])"
        $content = $content.Replace("terminal T1", "terminal $terminal")
        $content = $content.Replace("QM_MT5_Worker_T1", $TaskName)
        $content = $content.Replace("--terminal T1", "--terminal $terminal")
    }
    Set-Content -LiteralPath $RenderedXml -Value $content -Encoding Unicode

    $taskPath = "\" + $TaskName
    $deleteCmd = "schtasks /Delete /TN $taskPath /F"
    $createCmd = "schtasks /Create /TN $taskPath /XML `"$RenderedXml`" /F"
    if ($WhatIf.IsPresent) {
        Write-Host "[WhatIf] $deleteCmd"
        Write-Host "[WhatIf] $createCmd"
        return
    }

    try {
        Invoke-Expression $deleteCmd | Out-Null
    }
    catch {
        # Task may not exist yet; continue to create.
    }
    Invoke-Expression $createCmd | Out-Host
}

try {
    foreach ($terminal in 1..10) {
        $taskName = "QM_MT5_Worker_T$terminal"
        $sourceXml = Join-Path $taskXmlDir "$taskName.xml"
        if (-not (Test-Path -LiteralPath $sourceXml -PathType Leaf)) {
            $sourceXml = Join-Path $taskXmlDir "QM_MT5_Worker_T1.xml"
        }
        $renderedXml = Join-Path $tempDir "$taskName.xml"
        Register-TaskFromXml -TaskName $taskName -SourceXml $sourceXml -RenderedXml $renderedXml -RunAsUser $resolvedUser -PythonExe $resolvedPythonExe -WhatIf:$WhatIf.IsPresent
    }

    if ($IncludeGateEvaluator) {
        $gateTaskName = "QM_GateEvaluator_5min"
        $gateSourceXml = Join-Path $taskXmlDir "$gateTaskName.xml"
        $gateRenderedXml = Join-Path $tempDir "$gateTaskName.xml"
        Register-TaskFromXml -TaskName $gateTaskName -SourceXml $gateSourceXml -RenderedXml $gateRenderedXml -RunAsUser $resolvedUser -PythonExe $resolvedPythonExe -WhatIf:$WhatIf.IsPresent
    }
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

if (-not $WhatIf.IsPresent) {
    $taskNames = 1..10 | ForEach-Object { "QM_MT5_Worker_T$_" }
    if ($IncludeGateEvaluator) {
        $taskNames += "QM_GateEvaluator_5min"
    }
    foreach ($taskName in $taskNames) {
        schtasks /Query /TN ("\\" + $taskName) /V /FO LIST
    }
}
