[CmdletBinding()]
param(
    [string]$PlanPath = "C:\QM\repo\docs\ops\evidence\2026-07-31_mnt003_minimal_plan.json",
    [string]$ResultPath = "D:\QM\reports\state\mnt003_r2_probe_harness.json",
    [string]$ChildResultPath = "D:\QM\reports\state\mnt003_r2_probe_child.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$ArgumentString,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )

    $start = Get-Date
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $ArgumentString
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    [pscustomobject]@{
        file = $FilePath
        arguments = $ArgumentString
        working_directory = $WorkingDirectory
        root_pid = $process.Id
        exit_code = $process.ExitCode
        started_at = $start.ToUniversalTime().ToString("o")
        finished_at = (Get-Date).ToUniversalTime().ToString("o")
        stdout = $stdout.Trim()
        stderr = $stderr.Trim()
    }
}

$helper = "C:\QM\repo\tools\strategy_farm\run_in_console_session.ps1"
$pythonw = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe"
$agyGovernor = "C:\QM\repo\tools\strategy_farm\agy_governor.py"
$workDir = "C:\QM\repo"
$systemPowerShell = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

$plan = Get-Content -Raw -LiteralPath $PlanPath | ConvertFrom-Json
$agySpec = $plan.tasks | Where-Object name -eq "QM_StrategyFarm_AgyGovernor"
if (-not $agySpec) { throw "AgyGovernor plan entry missing: $PlanPath" }

$rootLocalAppData = $env:LOCALAPPDATA
$rootAgyCandidate = if ($rootLocalAppData) {
    Join-Path $rootLocalAppData "agy\bin\agy.exe"
} else {
    ""
}
$rootEvidence = [ordered]@{
    identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    whoami = (& "$env:SystemRoot\System32\whoami.exe").Trim()
    session_id = (Get-Process -Id $PID).SessionId
    process_id = $PID
    user_profile = $env:USERPROFILE
    local_app_data = $rootLocalAppData
    path = $env:PATH
    test_paths = [ordered]@{
        helper = [bool](Test-Path -LiteralPath $helper -PathType Leaf)
        pythonw = [bool](Test-Path -LiteralPath $pythonw -PathType Leaf)
        agy_governor = [bool](Test-Path -LiteralPath $agyGovernor -PathType Leaf)
        working_directory = [bool](Test-Path -LiteralPath $workDir -PathType Container)
        local_app_data_agy = [bool]($rootAgyCandidate -and (Test-Path -LiteralPath $rootAgyCandidate -PathType Leaf))
    }
}

# Reinvoke the exact raw action through the same native command-line boundary as
# Task Scheduler, but capture the helper's otherwise-discarded stdout/stderr.
$exact = Invoke-CapturedProcess `
    -FilePath ([string]$agySpec.after.action.execute) `
    -ArgumentString ([string]$agySpec.after.action.arguments) `
    -WorkingDirectory ([string]$agySpec.after.action.working_directory)

# Candidate v2 changes only the raw scheduler quoting contract.  The repository
# paths contain no spaces, so the child script itself needs no embedded quotes;
# the outer double quotes bind the complete -Arguments value without becoming
# literal apostrophes in the CreateProcessAsUser command line.
$candidateArguments = (
    '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden ' +
    '-File "{0}" -Exe "{1}" -Arguments "{2}" -WorkDir "{3}" ' +
    '-TargetUser "qm-admin" -WaitSeconds 240'
) -f $helper, $pythonw, $agyGovernor, $workDir
$candidate = Invoke-CapturedProcess `
    -FilePath ([string]$agySpec.after.action.execute) `
    -ArgumentString $candidateArguments `
    -WorkingDirectory ([string]$agySpec.after.action.working_directory)

Remove-Item -LiteralPath $ChildResultPath -Force -ErrorAction SilentlyContinue
$childScript = @'
$ErrorActionPreference = "Stop"
$helper = "C:\QM\repo\tools\strategy_farm\run_in_console_session.ps1"
$pythonw = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe"
$agyGovernor = "C:\QM\repo\tools\strategy_farm\agy_governor.py"
$workDir = "C:\QM\repo"
$localAgy = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "agy\bin\agy.exe" } else { "" }
$record = [ordered]@{
    identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    whoami = (& "$env:SystemRoot\System32\whoami.exe").Trim()
    session_id = (Get-Process -Id $PID).SessionId
    process_id = $PID
    parent_process_id = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
    current_directory = (Get-Location).Path
    user_profile = $env:USERPROFILE
    local_app_data = $env:LOCALAPPDATA
    app_data = $env:APPDATA
    path = $env:PATH
    test_paths = [ordered]@{
        helper = [bool](Test-Path -LiteralPath $helper -PathType Leaf)
        pythonw = [bool](Test-Path -LiteralPath $pythonw -PathType Leaf)
        agy_governor = [bool](Test-Path -LiteralPath $agyGovernor -PathType Leaf)
        working_directory = [bool](Test-Path -LiteralPath $workDir -PathType Container)
        local_app_data_agy = [bool]($localAgy -and (Test-Path -LiteralPath $localAgy -PathType Leaf))
    }
}
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath '__CHILD_RESULT__' -Encoding UTF8
'@
$childScript = $childScript.Replace(
    "__CHILD_RESULT__",
    $ChildResultPath.Replace("'", "''")
)
$childEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childScript))
$childArguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $childEncoded"
$diagnosticHelperArguments = (
    '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden ' +
    '-File "{0}" -Exe "{1}" -Arguments "{2}" -WorkDir "{3}" ' +
    '-TargetUser "qm-admin" -WaitSeconds 30'
) -f $helper, $systemPowerShell, $childArguments, $workDir
$diagnostic = Invoke-CapturedProcess `
    -FilePath $systemPowerShell `
    -ArgumentString $diagnosticHelperArguments `
    -WorkingDirectory $workDir

$childEvidence = $null
if (Test-Path -LiteralPath $ChildResultPath -PathType Leaf) {
    $childEvidence = Get-Content -Raw -LiteralPath $ChildResultPath | ConvertFrom-Json
}

$result = [ordered]@{
    schema = "qm.mnt003.r2-probe/v1"
    captured_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    root_system_environment = $rootEvidence
    exact_planned_action_capture = $exact
    candidate_quote_only_action_capture = $candidate
    diagnostic_user_environment_capture = $diagnostic
    diagnostic_child = $childEvidence
}
$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ResultPath -Encoding UTF8

if ($exact.exit_code -ne 2) {
    throw "exact action did not reproduce exit 2 (observed $($exact.exit_code))"
}
if ($candidate.exit_code -ne 0) {
    throw "quote-only candidate did not exit 0 (observed $($candidate.exit_code))"
}
if ($diagnostic.exit_code -ne 0 -or -not $childEvidence) {
    throw "diagnostic user-token launch failed (rc=$($diagnostic.exit_code))"
}
