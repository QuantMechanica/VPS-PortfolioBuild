# Shared, side-effect-free process classifiers for Factory OFF/ON/TestWindow.
#
# Safety contract:
#   * MT5 binaries are factory-owned only when ExecutablePath resolves to the
#     exact physical namespace D:\QM\mt5\T1..T10\<expected image>.
#   * Command-line processes are factory-owned only when their tokenized
#     invocation identifies the fixed repository script and a positive factory
#     selector. A basename/sub-string match is never sufficient.
#   * Missing, malformed, ambiguous, or duplicate evidence fails closed.

$script:QmFactoryProcessScopeVersion = 2
$script:QmFactoryRunSmokePath = 'C:\QM\repo\framework\scripts\run_smoke.ps1'
$script:QmFactoryWorkerPath = 'C:\QM\repo\tools\strategy_farm\terminal_worker.py'
$script:QmFactoryPumpPath = 'C:\QM\repo\tools\strategy_farm\run_pump_task.py'
$script:QmFactoryFarmRoot = 'D:\QM\strategy_farm'
$script:QmFactoryWorkItemReportRoot = 'D:\QM\reports\work_items'
$script:QmFactoryCanonicalRepoRoot = 'C:\QM\repo'
$script:QmFactoryWorktreeRoot = 'C:\QM\worktrees'
$script:QmFactoryPhaseRunnerAllowlistPath = Join-Path $PSScriptRoot 'phase_runner_allowlist.v1.json'
$script:QmFactoryPhaseRunnerAllowlistSchema = 'qm-phase-runner-allowlist/v1'
# Historical direct-parent runners that existed before the Q-phase rewrite.
# They are visibility-only: OFF must stop and report, never reap, because they
# cannot satisfy the current shared allowlist/lineage contract.
$script:QmFactoryLegacyPhaseRunnerReviewOnly = @(
    [pscustomobject]@{ Phase='P3.5'; RepoRelativePath='framework\scripts\p35_csr_runner.py' },
    [pscustomobject]@{ Phase='P4'; RepoRelativePath='framework\scripts\p4_walk_forward.py' },
    [pscustomobject]@{ Phase='Q09_LEGACY'; RepoRelativePath='framework\scripts\q09_news_mode.py' }
)

function Import-QmFactoryPhaseRunnerAllowlist {
    [CmdletBinding()]
    param()

    if (-not (Test-Path -LiteralPath $script:QmFactoryPhaseRunnerAllowlistPath -PathType Leaf)) {
        throw "Phase-runner allowlist missing: $script:QmFactoryPhaseRunnerAllowlistPath"
    }
    try {
        $document = Get-Content -LiteralPath $script:QmFactoryPhaseRunnerAllowlistPath -Raw -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Phase-runner allowlist unreadable: $($_.Exception.Message)"
    }
    if ([string]$document.schema_version -ne $script:QmFactoryPhaseRunnerAllowlistSchema) {
        throw "Phase-runner allowlist schema mismatch: $($document.schema_version)"
    }
    $entries = @($document.entries)
    if ($entries.Count -eq 0) { throw 'Phase-runner allowlist is empty.' }

    $seenPhases = @{}
    $seenPaths = @{}
    $validated = @()
    foreach ($entry in $entries) {
        $phase = [string]$entry.phase
        $relativePath = ([string]$entry.repo_relative_path).Replace('/', '\')
        $terminalSelector = [string]$entry.terminal_selector
        if ([string]::IsNullOrWhiteSpace($phase) -or $seenPhases.ContainsKey($phase)) {
            throw "Duplicate/empty phase in phase-runner allowlist: '$phase'"
        }
        if (
            [string]::IsNullOrWhiteSpace($relativePath) -or
            [System.IO.Path]::IsPathRooted($relativePath) -or
            $relativePath -match '(?i)(?:\A|\\)\.\.(?:\\|\z)' -or
            $relativePath -notmatch '(?i)\.py\z' -or
            $relativePath -notmatch '(?i)\A(?:framework\\scripts|tools\\strategy_farm)\\'
        ) {
            throw "Invalid repository-relative phase-runner path: '$relativePath'"
        }
        if ($seenPaths.ContainsKey($relativePath.ToLowerInvariant())) {
            throw "Duplicate phase-runner path in allowlist: '$relativePath'"
        }
        if ($terminalSelector -notin @('required', 'optional')) {
            throw "Invalid terminal-selector contract for phase '$phase': '$terminalSelector'"
        }
        $seenPhases[$phase] = $true
        $seenPaths[$relativePath.ToLowerInvariant()] = $true
        $validated += [pscustomobject]@{
            Phase = $phase
            RepoRelativePath = $relativePath
            TerminalSelector = $terminalSelector
        }
    }
    return @($validated)
}

$script:QmFactoryPhaseRunnerAllowlist = @(Import-QmFactoryPhaseRunnerAllowlist)

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

function Get-QmPythonLaunchTarget {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [string[]]$Arguments
    )

    # Keep this deliberately smaller than Python's complete command-line
    # surface.  These are the only interpreter flags used by a supported
    # Factory launcher.  A new flag therefore requires an explicit code and
    # test change instead of silently moving the script-token boundary.
    $index = 1
    $seenUnbuffered = $false
    $seenUtf8 = $false
    $acceptedFlags = New-Object System.Collections.Generic.List[string]

    while ($null -ne $Arguments -and $index -lt $Arguments.Count) {
        $token = [string]$Arguments[$index]
        if ($token -ceq '-u') {
            if ($seenUnbuffered) {
                return [pscustomobject][ordered]@{
                    Valid = $false; TargetIndex = -1; Reason = 'python_flag_duplicate_u'; Flags = @($acceptedFlags)
                }
            }
            $seenUnbuffered = $true
            [void]$acceptedFlags.Add('-u')
            $index++
            continue
        }
        if ($token -ceq '-X') {
            if ($seenUtf8) {
                return [pscustomobject][ordered]@{
                    Valid = $false; TargetIndex = -1; Reason = 'python_flag_duplicate_x_utf8'; Flags = @($acceptedFlags)
                }
            }
            $valueIndex = $index + 1
            if ($valueIndex -ge $Arguments.Count -or ([string]$Arguments[$valueIndex] -cne 'utf8')) {
                return [pscustomobject][ordered]@{
                    Valid = $false; TargetIndex = -1; Reason = 'python_x_option_not_allowlisted'; Flags = @($acceptedFlags)
                }
            }
            $seenUtf8 = $true
            [void]$acceptedFlags.Add('-X utf8')
            $index += 2
            continue
        }
        if ($token -ceq '-Xutf8') {
            if ($seenUtf8) {
                return [pscustomobject][ordered]@{
                    Valid = $false; TargetIndex = -1; Reason = 'python_flag_duplicate_x_utf8'; Flags = @($acceptedFlags)
                }
            }
            $seenUtf8 = $true
            [void]$acceptedFlags.Add('-Xutf8')
            $index++
            continue
        }

        # -m is a launch target rather than a prefix flag.  It remains visible
        # here so the existing, tightly-scoped legacy-module review path can
        # classify it.  Every other leading-dash token is fail-closed.
        if ($token -ceq '-m') { break }
        if ([string]::IsNullOrWhiteSpace($token)) {
            return [pscustomobject][ordered]@{
                Valid = $false; TargetIndex = -1; Reason = 'python_launch_target_empty'; Flags = @($acceptedFlags)
            }
        }
        if ($token.StartsWith('-', [System.StringComparison]::Ordinal)) {
            return [pscustomobject][ordered]@{
                Valid = $false; TargetIndex = -1; Reason = 'python_interpreter_flag_not_allowlisted'; Flags = @($acceptedFlags)
            }
        }
        break
    }

    if ($null -eq $Arguments -or $index -ge $Arguments.Count) {
        return [pscustomobject][ordered]@{
            Valid = $false; TargetIndex = -1; Reason = 'python_launch_target_missing'; Flags = @($acceptedFlags)
        }
    }
    return [pscustomobject][ordered]@{
        Valid = $true; TargetIndex = $index; Reason = 'python_interpreter_prefix_allowlisted'; Flags = @($acceptedFlags)
    }
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

    $launchTarget = Get-QmPythonLaunchTarget -Arguments $arguments
    if (-not $launchTarget.Valid) { return $false }
    $scriptIndex = [int]$launchTarget.TargetIndex

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

    $launchTarget = Get-QmPythonLaunchTarget -Arguments $arguments
    if (-not $launchTarget.Valid) { return $false }
    $scriptIndex = [int]$launchTarget.TargetIndex
    if ($arguments.Count -ne ($scriptIndex + 1)) { return $false }

    $scriptToken = ([string]$arguments[$scriptIndex]).Replace('/', '\')
    if ([string]::Equals($scriptToken, 'tools\strategy_farm\run_pump_task.py', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    $pumpPath = ConvertTo-QmCanonicalProcessPath -Path $scriptToken
    return [string]::Equals($pumpPath, $script:QmFactoryPumpPath, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-QmCommandLineOptionIndexes {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Option
    )

    if ($null -eq $Arguments) { return }
    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        if ([string]::Equals($Arguments[$index], $Option, [System.StringComparison]::OrdinalIgnoreCase)) {
            $index
        }
    }
}

function Test-QmFactoryRunnerRepositoryPath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$RepoRelativePath
    )

    $canonicalPath = ConvertTo-QmCanonicalProcessPath -Path $Path
    if ($null -eq $canonicalPath) { return $false }
    $relative = $RepoRelativePath.Replace('/', '\')
    try {
        $canonicalExpected = [System.IO.Path]::GetFullPath((Join-Path $script:QmFactoryCanonicalRepoRoot $relative))
    } catch {
        return $false
    }
    if ([string]::Equals($canonicalPath, $canonicalExpected, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    # Work-item artifact pinning can intentionally launch the same exact runner
    # from one direct C:\QM\worktrees\<name> checkout.  No deeper or foreign root
    # is accepted, and the allowlisted repository-relative suffix must be exact.
    $worktreePrefix = $script:QmFactoryWorktreeRoot.TrimEnd('\') + '\'
    if (-not $canonicalPath.StartsWith($worktreePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    $tail = $canonicalPath.Substring($worktreePrefix.Length)
    $parts = @($tail.Split(@('\'), [System.StringSplitOptions]::RemoveEmptyEntries))
    $relativeParts = @($relative.Split(@('\'), [System.StringSplitOptions]::RemoveEmptyEntries))
    if ($parts.Count -ne ($relativeParts.Count + 1)) { return $false }
    if ($parts[0] -notmatch '\A[A-Za-z0-9._-]+\z') { return $false }
    $actualRelative = [string]::Join('\', @($parts | Select-Object -Skip 1))
    return [string]::Equals($actualRelative, $relative, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-QmFactoryPhaseRunnerEntry {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ScriptPath
    )

    foreach ($entry in $script:QmFactoryPhaseRunnerAllowlist) {
        if (Test-QmFactoryRunnerRepositoryPath -Path $ScriptPath -RepoRelativePath $entry.RepoRelativePath) {
            return $entry
        }
    }
    return $null
}

function Get-QmFactoryLegacyPhaseRunnerReviewEntry {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ScriptPath
    )

    foreach ($entry in $script:QmFactoryLegacyPhaseRunnerReviewOnly) {
        if (Test-QmFactoryRunnerRepositoryPath -Path $ScriptPath -RepoRelativePath $entry.RepoRelativePath) {
            return $entry
        }
    }
    return $null
}

function Test-QmCommandLineReferencesFactoryWorkItemRoot {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CommandLine,

        [AllowEmptyCollection()]
        [string[]]$Arguments
    )

    $root = $script:QmFactoryWorkItemReportRoot.TrimEnd('\')
    foreach ($argument in @($Arguments)) {
        $canonical = ConvertTo-QmCanonicalProcessPath -Path ([string]$argument)
        if ($null -eq $canonical) { continue }
        if (
            [string]::Equals($canonical, $root, [System.StringComparison]::OrdinalIgnoreCase) -or
            $canonical.StartsWith(($root + '\'), [System.StringComparison]::OrdinalIgnoreCase)
        ) {
            return $true
        }
    }
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $false }
    # Visibility-only fallback for --option=value and embedded quoted forms.
    # The boundary deliberately excludes work_items_evil.
    return [bool]($CommandLine -match '(?i)D:[\\/]QM[\\/]reports[\\/]work_items(?=$|[\\/\s"''=])')
}

function New-QmFactoryPhaseRunnerClassification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('FACTORY_OWNED', 'REVIEW_REQUIRED', 'NOT_FACTORY')]
        [string]$Disposition,

        [Parameter(Mandatory = $true)]
        [string]$MatcherReason,

        [AllowNull()][string]$Phase,
        [AllowNull()][string]$ScriptPath,
        [AllowNull()][string]$WorkItemRoot,
        [AllowNull()][string]$WorkItemId,
        [AllowNull()][string]$Terminal
    )

    return [pscustomobject][ordered]@{
        Disposition = $Disposition
        MatcherReason = $MatcherReason
        Phase = $Phase
        ScriptPath = $ScriptPath
        WorkItemRoot = $WorkItemRoot
        WorkItemId = $WorkItemId
        Terminal = $Terminal
    }
}

function Get-QmFactoryPhaseRunnerClassification {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CommandLine
    )

    $arguments = @(Get-QmCommandLineArguments -CommandLine $CommandLine)
    if (-not (Test-QmCommandLineExecutableName -Arguments $arguments -AllowedNames @('python.exe', 'pythonw.exe'))) {
        return New-QmFactoryPhaseRunnerClassification -Disposition NOT_FACTORY `
            -MatcherReason 'interpreter_not_python' -Phase $null -ScriptPath $null `
            -WorkItemRoot $null -WorkItemId $null -Terminal $null
    }
    $referencesWorkItems = Test-QmCommandLineReferencesFactoryWorkItemRoot `
        -CommandLine $CommandLine -Arguments $arguments
    $reviewDisposition = $(if ($referencesWorkItems) { 'REVIEW_REQUIRED' } else { 'NOT_FACTORY' })

    $launchTarget = Get-QmPythonLaunchTarget -Arguments $arguments
    if (-not $launchTarget.Valid) {
        return New-QmFactoryPhaseRunnerClassification -Disposition $reviewDisposition `
            -MatcherReason $launchTarget.Reason -Phase $null -ScriptPath $null `
            -WorkItemRoot $null -WorkItemId $null -Terminal $null
    }
    $scriptIndex = [int]$launchTarget.TargetIndex
    if ([string]::Equals($arguments[$scriptIndex], '-m', [System.StringComparison]::OrdinalIgnoreCase)) {
        $moduleIndex = $scriptIndex + 1
        $moduleName = $(if ($moduleIndex -lt $arguments.Count) { [string]$arguments[$moduleIndex] } else { '' })
        if ([string]::Equals($moduleName, 'framework.scripts.p3_param_sweep', [System.StringComparison]::OrdinalIgnoreCase)) {
            $legacyEntry = @($script:QmFactoryPhaseRunnerAllowlist | Where-Object { $_.Phase -eq 'Q03' })[0]
            $legacyScriptPath = $(if ($null -ne $legacyEntry) {
                Join-Path $script:QmFactoryCanonicalRepoRoot $legacyEntry.RepoRelativePath
            } else { $null })
            return New-QmFactoryPhaseRunnerClassification -Disposition REVIEW_REQUIRED `
                -MatcherReason 'legacy_module_runner_without_exact_uuid_lineage' -Phase 'Q03' `
                -ScriptPath $legacyScriptPath -WorkItemRoot $null -WorkItemId $null -Terminal $null
        }
        return New-QmFactoryPhaseRunnerClassification -Disposition $reviewDisposition `
            -MatcherReason 'runner_module_not_allowlisted' -Phase $null -ScriptPath $null `
            -WorkItemRoot $null -WorkItemId $null -Terminal $null
    }
    $scriptPath = ConvertTo-QmCanonicalProcessPath -Path $arguments[$scriptIndex]
    $entry = Get-QmFactoryPhaseRunnerEntry -ScriptPath $scriptPath
    if ($null -eq $entry) {
        $legacyReviewEntry = Get-QmFactoryLegacyPhaseRunnerReviewEntry -ScriptPath $scriptPath
        if ($null -ne $legacyReviewEntry) {
            return New-QmFactoryPhaseRunnerClassification -Disposition REVIEW_REQUIRED `
                -MatcherReason 'deprecated_legacy_runner_not_reap_allowlisted' `
                -Phase $legacyReviewEntry.Phase -ScriptPath $scriptPath `
                -WorkItemRoot $null -WorkItemId $null -Terminal $null
        }
        return New-QmFactoryPhaseRunnerClassification -Disposition $reviewDisposition `
            -MatcherReason 'runner_script_not_allowlisted' -Phase $null -ScriptPath $scriptPath `
            -WorkItemRoot $null -WorkItemId $null -Terminal $null
    }

    $outPrefixIndexes = @(Get-QmCommandLineOptionIndexes -Arguments $arguments -Option '--out-prefix')
    if ($outPrefixIndexes.Count -ne 1) {
        # An exact allowlisted script is an autonomous phase-runner near-match
        # even when its historical argv predates UUID lineage.  Surface it and
        # block OFF, but never promote it to reap ownership.
        return New-QmFactoryPhaseRunnerClassification -Disposition REVIEW_REQUIRED `
            -MatcherReason $(if ($outPrefixIndexes.Count -eq 0) {'out_prefix_missing'} else {'out_prefix_duplicate'}) `
            -Phase $entry.Phase -ScriptPath $scriptPath -WorkItemRoot $null -WorkItemId $null -Terminal $null
    }
    $outValueIndex = [int]$outPrefixIndexes[0] + 1
    $outPrefix = $null
    if ($outValueIndex -lt $arguments.Count) { $outPrefix = [string]$arguments[$outValueIndex] }
    if (-not (Test-QmDirectFactoryWorkItemReportRoot -Path $outPrefix)) {
        return New-QmFactoryPhaseRunnerClassification -Disposition REVIEW_REQUIRED `
            -MatcherReason 'out_prefix_not_direct_work_item_uuid' -Phase $entry.Phase -ScriptPath $scriptPath `
            -WorkItemRoot (ConvertTo-QmCanonicalProcessPath -Path $outPrefix) -WorkItemId $null -Terminal $null
    }
    $canonicalOutPrefix = ConvertTo-QmCanonicalProcessPath -Path $outPrefix
    $workItemId = [System.IO.Path]::GetFileName($canonicalOutPrefix)

    $terminalIndexes = @(Get-QmCommandLineOptionIndexes -Arguments $arguments -Option '--terminal')
    if ($terminalIndexes.Count -gt 1) {
        return New-QmFactoryPhaseRunnerClassification -Disposition REVIEW_REQUIRED `
            -MatcherReason 'terminal_selector_duplicate' -Phase $entry.Phase -ScriptPath $scriptPath `
            -WorkItemRoot $canonicalOutPrefix -WorkItemId $workItemId -Terminal $null
    }
    if ($entry.TerminalSelector -eq 'required' -and $terminalIndexes.Count -ne 1) {
        return New-QmFactoryPhaseRunnerClassification -Disposition REVIEW_REQUIRED `
            -MatcherReason 'terminal_selector_missing' -Phase $entry.Phase -ScriptPath $scriptPath `
            -WorkItemRoot $canonicalOutPrefix -WorkItemId $workItemId -Terminal $null
    }
    $terminal = $null
    if ($terminalIndexes.Count -eq 1) {
        $terminalValueIndex = [int]$terminalIndexes[0] + 1
        if ($terminalValueIndex -lt $arguments.Count) { $terminal = [string]$arguments[$terminalValueIndex] }
        # T5 is intentionally disabled/isolated and T_Live is never in Factory
        # scope.  Both therefore fail closed to REVIEW_REQUIRED, never reap.
        if ($terminal -notmatch '(?i)\AT(?:[1-4]|[6-9]|10)\z') {
            return New-QmFactoryPhaseRunnerClassification -Disposition REVIEW_REQUIRED `
                -MatcherReason 'terminal_selector_outside_factory_scope' -Phase $entry.Phase -ScriptPath $scriptPath `
                -WorkItemRoot $canonicalOutPrefix -WorkItemId $workItemId -Terminal $terminal
        }
    }

    return New-QmFactoryPhaseRunnerClassification -Disposition FACTORY_OWNED `
        -MatcherReason ("allowlist_v1_lineage_bound:{0}" -f $entry.Phase) `
        -Phase $entry.Phase -ScriptPath $scriptPath -WorkItemRoot $canonicalOutPrefix `
        -WorkItemId $workItemId -Terminal $terminal
}

function Test-QmFactoryPhaseRunnerCommandLine {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CommandLine
    )

    $classification = Get-QmFactoryPhaseRunnerClassification -CommandLine $CommandLine
    return [string]$classification.Disposition -eq 'FACTORY_OWNED'
}

function Get-QmCommandLineSha256 {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CommandLine
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$CommandLine)
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Test-QmFactoryNullProcessScan {
    [CmdletBinding()]
    param([AllowNull()]$Scan)

    if ($null -eq $Scan) { return $false }
    foreach ($property in @('worker_daemons', 'phase_runners', 'smoke_wrappers', 'terminal64', 'metatester64')) {
        if ($null -eq $Scan.PSObject.Properties[$property]) { return $false }
        if (@($Scan.$property).Count -ne 0) { return $false }
    }
    return $true
}

function Test-QmStableFactoryNullScans {
    [CmdletBinding()]
    param([AllowEmptyCollection()][object[]]$Scans)

    $items = @($Scans)
    if ($items.Count -lt 2) { return $false }
    $first = $items[$items.Count - 2]
    $second = $items[$items.Count - 1]
    if (-not (Test-QmFactoryNullProcessScan -Scan $first)) { return $false }
    if (-not (Test-QmFactoryNullProcessScan -Scan $second)) { return $false }
    $firstAt = [string]$first.scanned_at
    $secondAt = [string]$second.scanned_at
    return (
        -not [string]::IsNullOrWhiteSpace($firstAt) -and
        -not [string]::IsNullOrWhiteSpace($secondAt) -and
        -not [string]::Equals($firstAt, $secondAt, [System.StringComparison]::Ordinal)
    )
}
