[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RunDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Dev1Root = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV1')
$script:ReportsRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev1')
$script:PwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
$script:AllowedSymbols = @('NDX.DWX', 'GDAXI.DWX', 'EURUSD.DWX', 'GBPUSD.DWX', 'USDJPY.DWX', 'XAUUSD.DWX')
$script:AllowedParameterOrder = @(
    'EAId', 'EALabel', 'Symbol', 'Year', 'FromDate', 'ToDate', 'Expert', 'Period', 'Runs',
    'MinTrades', 'Model', 'TimeoutSeconds', 'SetFile', 'AllowMissingRealTicksLogMarker',
    'CommissionPerLot', 'TesterCurrencyOverride', 'TesterDepositOverride', 'SmokeMode'
)
$script:SwitchParameters = @('AllowMissingRealTicksLogMarker', 'SmokeMode')

function ConvertTo-QmFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path.IndexOfAny([char[]]"`r`n`0") -ge 0) { throw 'Path contains CR, LF, or NUL.' }
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-QmPathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [switch]$AllowRoot
    )
    $fullPath = ConvertTo-QmFullPath -Path $Path
    $fullRoot = (ConvertTo-QmFullPath -Path $Root).TrimEnd('\')
    if ($AllowRoot -and $fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $fullPath.StartsWith($fullRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-QmNoReparseComponents {
    param([Parameter(Mandatory = $true)][string]$Path)
    $fullPath = ConvertTo-QmFullPath -Path $Path
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Required path does not exist: $fullPath" }
    $root = [System.IO.Path]::GetPathRoot($fullPath)
    $cursor = $root
    foreach ($part in @($fullPath.Substring($root.Length).Split('\', [System.StringSplitOptions]::RemoveEmptyEntries))) {
        $cursor = Join-Path $cursor $part
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point found in task path: $cursor"
        }
    }
}

function Resolve-QmAccountSid {
    param([Parameter(Mandatory = $true)][string]$AccountName)
    $normalized = if ($AccountName.StartsWith('.\')) { "$env:COMPUTERNAME\$($AccountName.Substring(2))" } else { $AccountName }
    return (New-Object System.Security.Principal.NTAccount($normalized)).Translate([System.Security.Principal.SecurityIdentifier]).Value
}

function Assert-QmNoDev1Processes {
    $running = @(
        Get-CimInstance -ClassName Win32_Process -ErrorAction Stop | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.ExecutablePath) -and
            (Test-QmPathWithin -Path ([string]$_.ExecutablePath) -Root $script:Dev1Root)
        }
    )
    if ($running.Count -gt 0) {
        throw "DEV1 is not idle inside the task preflight; exact-path process count=$($running.Count)."
    }
}

function Clear-QmInheritedEnvironment {
    param([Parameter(Mandatory = $true)][string]$ExpectedProfile)
    # Never serialize or log the inherited environment. Preserve only the small,
    # non-secret system/profile contract needed by PowerShell and MT5.
    $systemRoot = $env:SystemRoot
    $profile = ConvertTo-QmFullPath -Path $ExpectedProfile
    $safe = [ordered]@{
        SystemRoot = $systemRoot
        windir = $systemRoot
        SystemDrive = [System.IO.Path]::GetPathRoot($systemRoot).TrimEnd('\')
        ComSpec = Join-Path $systemRoot 'System32\cmd.exe'
        ProgramData = $env:ProgramData
        ProgramFiles = $env:ProgramFiles
        'ProgramFiles(x86)' = ${env:ProgramFiles(x86)}
        ProgramW6432 = $env:ProgramW6432
        CommonProgramFiles = $env:CommonProgramFiles
        'CommonProgramFiles(x86)' = ${env:CommonProgramFiles(x86)}
        CommonProgramW6432 = $env:CommonProgramW6432
        COMPUTERNAME = $env:COMPUTERNAME
        USERNAME = $env:USERNAME
        USERDOMAIN = $env:USERDOMAIN
        USERPROFILE = $profile
        APPDATA = Join-Path $profile 'AppData\Roaming'
        LOCALAPPDATA = Join-Path $profile 'AppData\Local'
        TEMP = Join-Path $profile 'AppData\Local\Temp'
        TMP = Join-Path $profile 'AppData\Local\Temp'
        HOMEDRIVE = [System.IO.Path]::GetPathRoot($profile).TrimEnd('\')
        HOMEPATH = $profile.Substring([System.IO.Path]::GetPathRoot($profile).Length - 1)
        OS = 'Windows_NT'
        PROCESSOR_ARCHITECTURE = $env:PROCESSOR_ARCHITECTURE
        NUMBER_OF_PROCESSORS = $env:NUMBER_OF_PROCESSORS
        PSModulePath = "$PSHOME\Modules;$env:ProgramFiles\PowerShell\Modules;$systemRoot\system32\WindowsPowerShell\v1.0\Modules"
        Path = "$systemRoot\System32;$systemRoot;$systemRoot\System32\Wbem;$systemRoot\System32\WindowsPowerShell\v1.0;$([System.IO.Path]::GetDirectoryName($script:PwshPath))"
        PATHEXT = '.COM;.EXE;.BAT;.CMD'
    }
    foreach ($name in @([System.Environment]::GetEnvironmentVariables('Process').Keys)) {
        Remove-Item -LiteralPath ("Env:\{0}" -f [string]$name) -ErrorAction SilentlyContinue
    }
    foreach ($entry in $safe.GetEnumerator()) {
        if ($null -ne $entry.Value) {
            [System.Environment]::SetEnvironmentVariable([string]$entry.Key, [string]$entry.Value, 'Process')
        }
    }
}

function Assert-QmRequestSchema {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Request,
        [Parameter(Mandatory = $true)][string]$ExpectedRunDirectory
    )
    $required = @(
        'schema_version', 'run_id', 'nonce', 'created_utc', 'expires_utc', 'expected_account',
        'expected_sid', 'expected_profile', 'expected_common_path', 'dev1_root', 'reports_root',
        'smoke_report_root', 'run_smoke_path', 'run_smoke_sha256', 'smoke_parameters'
    )
    $extra = @($Request.Keys | Where-Object { $_ -notin $required })
    $missing = @($required | Where-Object { -not $Request.ContainsKey($_) })
    if ($extra.Count -gt 0 -or $missing.Count -gt 0 -or [int]$Request.schema_version -ne 1) {
        throw "Invalid DEV1 request schema. Missing=$([string]::Join(',', $missing)); extra=$([string]::Join(',', $extra))"
    }
    if ([string]$Request.run_id -notmatch '^[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}$' -or
        [string]$Request.nonce -notmatch '^[0-9a-f]{32}$') {
        throw 'Invalid run_id or nonce.'
    }
    $expires = [DateTimeOffset]::Parse([string]$Request.expires_utc).ToUniversalTime()
    if ($expires -le [DateTimeOffset]::UtcNow) { throw 'DEV1 request is expired.' }
    if (-not (ConvertTo-QmFullPath -Path ([string]$Request.dev1_root)).Equals($script:Dev1Root, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (ConvertTo-QmFullPath -Path ([string]$Request.reports_root)).Equals($script:ReportsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'DEV1 request changed a fixed isolation root.'
    }
    if (-not (Test-QmPathWithin -Path ([string]$Request.smoke_report_root) -Root $ExpectedRunDirectory)) {
        throw 'Smoke ReportRoot escaped the nonce-bound run directory.'
    }
    if (-not (Test-QmPathWithin -Path $ExpectedRunDirectory -Root $script:ReportsRoot)) {
        throw 'RunDirectory escaped D:\QM\reports\dev1.'
    }

    $parameters = [hashtable]$Request.smoke_parameters
    $unknown = @($parameters.Keys | Where-Object { $_ -notin $script:AllowedParameterOrder })
    if ($unknown.Count -gt 0) { throw "Forbidden smoke parameter(s): $([string]::Join(',', $unknown))" }
    foreach ($forbidden in @('Terminal', 'ReportRoot', 'AllowRunningTerminal', 'DispatchPhase', 'DispatchVersion', 'DispatchSubGateHash')) {
        if ($parameters.ContainsKey($forbidden)) { throw "Forbidden DEV1 parameter: $forbidden" }
    }
    foreach ($mandatory in @('EAId', 'Symbol', 'Year', 'Expert', 'Period', 'Runs', 'MinTrades', 'Model', 'TimeoutSeconds')) {
        if (-not $parameters.ContainsKey($mandatory)) { throw "Missing smoke parameter: $mandatory" }
    }
    if ([string]$parameters.Symbol -notin $script:AllowedSymbols) { throw 'Symbol is outside the DEV1 allowlist.' }
    if ([string]$parameters.Expert -notmatch '^QM\\[A-Za-z0-9_.-]+$') { throw 'Expert path is invalid.' }
    if ([string]$parameters.Period -notmatch '^[A-Z][A-Z0-9]{0,4}$') { throw 'Period is invalid.' }
    if ([int]$parameters.Year -lt 2000 -or [int]$parameters.Year -gt 2100 -or
        [int]$parameters.Runs -lt 1 -or [int]$parameters.Runs -gt 10 -or
        [int]$parameters.Model -ne 4 -or [int]$parameters.TimeoutSeconds -lt 60 -or [int]$parameters.TimeoutSeconds -gt 28800) {
        throw 'Numeric smoke parameter is outside its fixed range.'
    }
    foreach ($key in @($parameters.Keys)) {
        $value = $parameters[$key]
        if ($value -is [string] -and $value.IndexOfAny([char[]]"`r`n`0") -ge 0) {
            throw "Smoke parameter '$key' contains CR, LF, or NUL."
        }
    }
    if ($parameters.ContainsKey('SetFile')) {
        $setPath = ConvertTo-QmFullPath -Path ([string]$parameters.SetFile)
        $repoRoot = ConvertTo-QmFullPath -Path (Join-Path $PSScriptRoot '..\..')
        if (-not (Test-QmPathWithin -Path $setPath -Root $repoRoot) -or -not (Test-Path -LiteralPath $setPath -PathType Leaf)) {
            throw 'SetFile is not a physical repository file.'
        }
        Assert-QmNoReparseComponents -Path $setPath
    }
}

function Write-QmAtomicResult {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Result,
        [Parameter(Mandatory = $true)][string]$ResultPath
    )
    $temporaryPath = "$ResultPath.$([guid]::NewGuid().ToString('N')).tmp"
    $json = $Result | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($temporaryPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temporaryPath -Destination $ResultPath -ErrorAction Stop
}

$runId = $null
$nonce = $null
$success = $false
$errorCode = 'CHILD_PRECHECK_FAILED'
$errorMessage = $null
$runSmokeExitCode = $null
$actualCommonPath = $null
$startedUtc = (Get-Date).ToUniversalTime()
$resultPath = $null
$logPath = $null

try {
    $RunDirectory = ConvertTo-QmFullPath -Path $RunDirectory
    if (-not (Test-QmPathWithin -Path $RunDirectory -Root $script:ReportsRoot)) {
        throw 'RunDirectory is outside D:\QM\reports\dev1.'
    }
    Assert-QmNoReparseComponents -Path $RunDirectory
    $requestPath = Join-Path $RunDirectory 'control\request.json'
    $outputDirectory = Join-Path $RunDirectory 'output'
    $resultPath = Join-Path $outputDirectory 'result.json'
    $logPath = Join-Path $outputDirectory 'run.log'
    foreach ($path in @($requestPath, $outputDirectory)) { Assert-QmNoReparseComponents -Path $path }

    $request = Get-Content -LiteralPath $requestPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    Assert-QmRequestSchema -Request $request -ExpectedRunDirectory $RunDirectory
    $runId = [string]$request.run_id
    $nonce = [string]$request.nonce

    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $currentSid = $currentIdentity.User.Value
    $currentName = $currentIdentity.Name
    if ($currentSid -ne [string]$request.expected_sid -or
        -not $currentName.Equals([string]$request.expected_account, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Scheduled Task did not run as the nonce-bound QMDev1 identity.'
    }
    if ((Resolve-QmAccountSid -AccountName ([string]$request.expected_account)) -ne [string]$request.expected_sid) {
        throw 'Requested QMDev1 name/SID mapping drifted.'
    }

    $actualProfile = ConvertTo-QmFullPath -Path $env:USERPROFILE
    $appData = ConvertTo-QmFullPath -Path $env:APPDATA
    $folderAppData = ConvertTo-QmFullPath -Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ApplicationData))
    $actualCommonPath = ConvertTo-QmFullPath -Path (Join-Path $appData 'MetaQuotes\Terminal\Common')
    if (-not $actualProfile.Equals((ConvertTo-QmFullPath -Path ([string]$request.expected_profile)), [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $appData.Equals($folderAppData, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $actualCommonPath.Equals((ConvertTo-QmFullPath -Path ([string]$request.expected_common_path)), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Scheduled Task profile/Common path does not match the controller contract.'
    }
    Assert-QmNoReparseComponents -Path $actualCommonPath
    Assert-QmNoDev1Processes

    $runSmokePath = ConvertTo-QmFullPath -Path ([string]$request.run_smoke_path)
    Assert-QmNoReparseComponents -Path $runSmokePath
    $actualHash = (Get-FileHash -LiteralPath $runSmokePath -Algorithm SHA256).Hash
    if ($actualHash -cne [string]$request.run_smoke_sha256) {
        throw 'run_smoke.ps1 changed between controller and child execution.'
    }
    if (-not (Test-Path -LiteralPath $script:PwshPath -PathType Leaf)) { throw 'Fixed PowerShell 7 executable is missing.' }
    Assert-QmNoReparseComponents -Path $script:PwshPath

    [System.IO.File]::WriteAllText($logPath, "DEV1 child preflight PASS at $((Get-Date).ToUniversalTime().ToString('o'))`r`n")
    Clear-QmInheritedEnvironment -ExpectedProfile ([string]$request.expected_profile)

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $script:PwshPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.WorkingDirectory = ConvertTo-QmFullPath -Path (Join-Path $PSScriptRoot '..\..')
    foreach ($argument in @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $runSmokePath)) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $parameters = [hashtable]$request.smoke_parameters
    foreach ($name in $script:AllowedParameterOrder) {
        if (-not $parameters.ContainsKey($name)) { continue }
        if ($name -in $script:SwitchParameters) {
            if ([bool]$parameters[$name]) { [void]$startInfo.ArgumentList.Add("-$name") }
            continue
        }
        [void]$startInfo.ArgumentList.Add("-$name")
        $value = if ($parameters[$name] -is [System.IFormattable]) {
            $parameters[$name].ToString($null, [System.Globalization.CultureInfo]::InvariantCulture)
        } else { [string]$parameters[$name] }
        [void]$startInfo.ArgumentList.Add($value)
    }
    [void]$startInfo.ArgumentList.Add('-Terminal')
    [void]$startInfo.ArgumentList.Add('DEV1')
    [void]$startInfo.ArgumentList.Add('-ReportRoot')
    [void]$startInfo.ArgumentList.Add((ConvertTo-QmFullPath -Path ([string]$request.smoke_report_root)))

    $runner = New-Object System.Diagnostics.Process
    $runner.StartInfo = $startInfo
    try {
        if (-not $runner.Start()) { throw 'Failed to start isolated run_smoke child process.' }
        $stdoutTask = $runner.StandardOutput.ReadToEndAsync()
        $stderrTask = $runner.StandardError.ReadToEndAsync()
        $runner.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        [System.IO.File]::AppendAllText($logPath, "--- run_smoke stdout ---`r`n$stdout`r`n--- run_smoke stderr ---`r`n$stderr`r`n")
        $runSmokeExitCode = $runner.ExitCode
    } finally {
        $runner.Dispose()
    }

    Assert-QmNoDev1Processes
    if ($runSmokeExitCode -ne 0) {
        $errorCode = 'RUN_SMOKE_FAILED'
        throw "run_smoke.ps1 exited with code $runSmokeExitCode."
    }
    $success = $true
    $errorCode = $null
} catch {
    $errorMessage = $_.Exception.Message
    if ($null -ne $logPath) {
        try { [System.IO.File]::AppendAllText($logPath, "DEV1 child failure: $errorMessage`r`n") } catch { }
    }
} finally {
    if ($null -ne $resultPath -and $null -ne $runId -and $null -ne $nonce) {
        $result = [ordered]@{
            schema_version = 1
            run_id = $runId
            nonce = $nonce
            success = $success
            error_code = $errorCode
            error_message = $errorMessage
            run_smoke_exit_code = $runSmokeExitCode
            identity_sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            common_path = $actualCommonPath
            started_utc = $startedUtc.ToString('o')
            finished_utc = (Get-Date).ToUniversalTime().ToString('o')
            log_path = $logPath
        }
        try { Write-QmAtomicResult -Result $result -ResultPath $resultPath } catch { }
    }
}

if (-not $success) { exit 1 }
exit 0
