# Shared, side-effect-free process classifiers for Factory OFF/ON/TestWindow.
#
# Safety contract:
#   * MT5 binaries are factory-owned only when ExecutablePath resolves to the
#     exact physical namespace D:\QM\mt5\T1..T10\<expected image>.
#   * Command-line processes are factory-owned only when their tokenized
#     invocation identifies the fixed repository script and a positive factory
#     selector. A basename/sub-string match is never sufficient.
#   * Missing, malformed, ambiguous, or duplicate evidence fails closed.

$script:QmFactoryProcessScopeVersion = 1
$script:QmFactoryRunSmokePath = 'C:\QM\repo\framework\scripts\run_smoke.ps1'
$script:QmFactoryWorkerPath = 'C:\QM\repo\tools\strategy_farm\terminal_worker.py'
$script:QmFactoryPumpPath = 'C:\QM\repo\tools\strategy_farm\run_pump_task.py'
$script:QmFactoryFarmRoot = 'D:\QM\strategy_farm'
$script:QmFactoryWorkItemReportRoot = 'D:\QM\reports\work_items'

function ConvertTo-QmCanonicalProcessPath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    try {
        if (-not [System.IO.Path]::IsPathRooted($Path)) { return $null }
        return [System.IO.Path]::GetFullPath($Path)
    } catch {
        return $null
    }
}

function Get-QmCommandLineArguments {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CommandLine
    )

    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return }
    try {
        $parseErrors = $null
        # A Win32 command line whose executable is quoted is not, by itself, a
        # valid PowerShell statement. Prefixing the invocation operator gives
        # PSParser the same argv boundary shape without evaluating anything.
        $tokens = @([System.Management.Automation.PSParser]::Tokenize(('& ' + $CommandLine), [ref]$parseErrors))
        if (@($parseErrors).Count -ne 0) { return }
        foreach ($token in @($tokens | Select-Object -Skip 1)) {
            if ($null -ne $token.Content) { [string]$token.Content }
        }
    } catch {
        return
    }
}

function Get-QmUniqueCommandLineOptionValue {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Option
    )

    if ($null -eq $Arguments -or $Arguments.Count -eq 0) { return $null }
    $matches = @()
    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        if ([string]::Equals($Arguments[$index], $Option, [System.StringComparison]::OrdinalIgnoreCase)) {
            $matches += $index
        }
    }
    if ($matches.Count -ne 1) { return $null }

    $valueIndex = [int]$matches[0] + 1
    if ($valueIndex -ge $Arguments.Count) { return $null }
    $value = [string]$Arguments[$valueIndex]
    if ([string]::IsNullOrWhiteSpace($value) -or $value.StartsWith('-')) { return $null }
    return $value
}

function Test-QmCommandLineExecutableName {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedNames
    )

    if ($null -eq $Arguments -or $Arguments.Count -eq 0) { return $false }
    try {
        $actualName = [System.IO.Path]::GetFileName([string]$Arguments[0])
    } catch {
        return $false
    }
    foreach ($allowedName in $AllowedNames) {
        if ([string]::Equals($actualName, $allowedName, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Test-QmFactoryMt5ImagePath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Path,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$ImageName
    )

    if ($ImageName -notin @('terminal64.exe', 'metatester64.exe')) { return $false }
    $canonicalPath = ConvertTo-QmCanonicalProcessPath -Path $Path
    if ($null -eq $canonicalPath) { return $false }
    $imagePattern = [regex]::Escape($ImageName)
    return [bool]($canonicalPath -match ("(?i)\AD:\\QM\\mt5\\T(?:[1-9]|10)\\{0}\z" -f $imagePattern))
}

function Test-QmFactoryWorkerCommandLine {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CommandLine
    )

    $arguments = @(Get-QmCommandLineArguments -CommandLine $CommandLine)
    if (-not (Test-QmCommandLineExecutableName -Arguments $arguments -AllowedNames @('python.exe', 'pythonw.exe'))) {
        return $false
    }

    $scriptIndex = 1
    if ($arguments.Count -gt 1 -and [string]::Equals($arguments[1], '-u', [System.StringComparison]::OrdinalIgnoreCase)) {
        $scriptIndex = 2
    }
    if ($arguments.Count -le $scriptIndex) { return $false }

    $workerPath = ConvertTo-QmCanonicalProcessPath -Path $arguments[$scriptIndex]
    if (-not [string]::Equals($workerPath, $script:QmFactoryWorkerPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }

    $terminal = Get-QmUniqueCommandLineOptionValue -Arguments $arguments -Option '--terminal'
    if ($terminal -notmatch '(?i)\AT(?:[1-9]|10)\z') { return $false }

    $farmRoot = ConvertTo-QmCanonicalProcessPath -Path (Get-QmUniqueCommandLineOptionValue -Arguments $arguments -Option '--root')
    return [string]::Equals($farmRoot, $script:QmFactoryFarmRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-QmDirectFactoryWorkItemReportRoot {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Path
    )

    $canonicalPath = ConvertTo-QmCanonicalProcessPath -Path $Path
    if ($null -eq $canonicalPath) { return $false }
    try {
        $parent = [System.IO.Directory]::GetParent($canonicalPath)
        if ($null -eq $parent) { return $false }
        if (-not [string]::Equals($parent.FullName, $script:QmFactoryWorkItemReportRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
        $parsedGuid = [guid]::Empty
        return [guid]::TryParseExact([System.IO.Path]::GetFileName($canonicalPath), 'D', [ref]$parsedGuid)
    } catch {
        return $false
    }
}

function Test-QmFactoryRunSmokeCommandLine {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CommandLine
    )

    $arguments = @(Get-QmCommandLineArguments -CommandLine $CommandLine)
    if (-not (Test-QmCommandLineExecutableName -Arguments $arguments -AllowedNames @('pwsh.exe', 'powershell.exe'))) {
        return $false
    }
    if (@($arguments | Where-Object { [string]::Equals($_, '-Command', [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) {
        return $false
    }

    $runSmokePath = ConvertTo-QmCanonicalProcessPath -Path (Get-QmUniqueCommandLineOptionValue -Arguments $arguments -Option '-File')
    if (-not [string]::Equals($runSmokePath, $script:QmFactoryRunSmokePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }

    $terminal = Get-QmUniqueCommandLineOptionValue -Arguments $arguments -Option '-Terminal'
    if ($terminal -match '(?i)\AT(?:[1-9]|10)\z') { return $true }
    if (-not [string]::Equals($terminal, 'any', [System.StringComparison]::OrdinalIgnoreCase)) { return $false }

    $reportRoot = Get-QmUniqueCommandLineOptionValue -Arguments $arguments -Option '-ReportRoot'
    return Test-QmDirectFactoryWorkItemReportRoot -Path $reportRoot
}

function Test-QmFactoryPumpCommandLine {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CommandLine
    )

    $arguments = @(Get-QmCommandLineArguments -CommandLine $CommandLine)
    if (-not (Test-QmCommandLineExecutableName -Arguments $arguments -AllowedNames @('python.exe', 'pythonw.exe'))) {
        return $false
    }

    $scriptIndex = 1
    if ($arguments.Count -gt 1 -and [string]::Equals($arguments[1], '-u', [System.StringComparison]::OrdinalIgnoreCase)) {
        $scriptIndex = 2
    }
    if ($arguments.Count -ne ($scriptIndex + 1)) { return $false }

    $scriptToken = ([string]$arguments[$scriptIndex]).Replace('/', '\')
    if ([string]::Equals($scriptToken, 'tools\strategy_farm\run_pump_task.py', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    $pumpPath = ConvertTo-QmCanonicalProcessPath -Path $scriptToken
    return [string]::Equals($pumpPath, $script:QmFactoryPumpPath, [System.StringComparison]::OrdinalIgnoreCase)
}
