#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ArtifactRoot,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PortableTemplateRoot,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$ExpectedFactoryOffSha256,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9A-Fa-f]{40}$')]
    [string]$ExpectedSourceCommit,

    [string]$FactoryOffFlagPath = 'D:\QM\strategy_farm\state\FACTORY_OFF.flag',
    [string]$MutationLockPath = 'D:\QM\strategy_farm\state\FACTORY_MUTATION.lock',

    [ValidateRange(30, 900)]
    [int]$TimeoutSecondsPerEa = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $providerPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    return [System.IO.Path]::GetFullPath($providerPath).TrimEnd('\')
}

function Assert-NoReparsePointInExistingPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $normalized = Get-NormalizedPath -Path $Path
    $cursor = $normalized
    while (-not (Test-Path -LiteralPath $cursor)) {
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or
            $parent.Equals($cursor, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "$Label has no inspectable existing ancestor: $normalized"
        }
        $cursor = $parent
    }

    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Label contains a reparse-point/junction component: $($item.FullName)"
        }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or
            $parent.Equals($cursor, [System.StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $cursor = $parent
    }
    return $normalized
}

function Assert-NoReparsePointsInTree {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $resolvedRoot = Assert-NoReparsePointInExistingPath -Path $Root -Label $Label
    if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
        throw "$Label is not an existing directory: $resolvedRoot"
    }
    $reparseMembers = @(
        Get-ChildItem -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction Stop |
            Where-Object {
                ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
            }
    )
    if ($reparseMembers.Count -ne 0) {
        $members = ($reparseMembers | ForEach-Object { $_.FullName }) -join ' | '
        throw "$Label contains reparse-point/junction members: $members"
    }
    return $resolvedRoot
}

function Test-PathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$Parent
    )

    $candidatePath = (Get-NormalizedPath -Path $Candidate)
    $parentPath = (Get-NormalizedPath -Path $Parent)
    if ($candidatePath.Equals($parentPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    return $candidatePath.StartsWith(
        $parentPath + '\',
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Assert-PathsDisjoint {
    param(
        [Parameter(Mandatory = $true)][string]$Left,
        [Parameter(Mandatory = $true)][string]$Right,
        [Parameter(Mandatory = $true)][string]$Label
    )

    Assert-NoReparsePointInExistingPath -Path $Left -Label "$Label left" | Out-Null
    Assert-NoReparsePointInExistingPath -Path $Right -Label "$Label right" | Out-Null
    if ((Test-PathWithin -Candidate $Left -Parent $Right) -or
        (Test-PathWithin -Candidate $Right -Parent $Left)) {
        throw "$Label paths must be disjoint: left=$Left right=$Right"
    }
}

function Assert-NotProtectedTerminalPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $normalized = (
        Assert-NoReparsePointInExistingPath -Path $Path -Label $Label
    ).Replace('/', '\')
    $protected = '(?i)^[A-Z]:\\QM\\mt5\\(?:T_Live|T(?:10|[1-9])(?:_[^\\]+)?)(?:\\|$)'
    if ($normalized -match $protected) {
        throw "$Label may not use T_Live or T1-T10: $normalized"
    }
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Hash input is not a file: $Path"
    }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Assert-CompileSourceBinding {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$ExpectedCommit,
        [Parameter(Mandatory = $true)][string[]]$PathSpecs,
        [Parameter(Mandatory = $true)][string]$Checkpoint
    )

    if ($PathSpecs.Count -eq 0) {
        throw "[$Checkpoint] Compile-relevant source pathspec set is empty."
    }

    $headOutput = @(& git -C $RepoRoot rev-parse --verify HEAD 2>&1)
    $headExitCode = $LASTEXITCODE
    if ($headExitCode -ne 0 -or $headOutput.Count -ne 1) {
        $detail = ($headOutput | ForEach-Object { [string]$_ }) -join ' | '
        throw "[$Checkpoint] Unable to resolve repository HEAD: exit=$headExitCode detail=$detail"
    }
    $actualCommit = ([string]$headOutput[0]).Trim().ToLowerInvariant()
    if ($actualCommit -notmatch '^[0-9a-f]{40}$') {
        throw "[$Checkpoint] Repository HEAD is not an exact 40-hex commit: $actualCommit"
    }
    if ($actualCommit -ne $ExpectedCommit.ToLowerInvariant()) {
        throw "[$Checkpoint] Source commit mismatch: expected=$ExpectedCommit actual=$actualCommit"
    }

    $statusOutput = @(
        & git -C $RepoRoot status --porcelain=v1 --untracked-files=all -- @PathSpecs 2>&1
    )
    $statusExitCode = $LASTEXITCODE
    if ($statusExitCode -ne 0) {
        $detail = ($statusOutput | ForEach-Object { [string]$_ }) -join ' | '
        throw "[$Checkpoint] Unable to inspect compile-relevant source status: exit=$statusExitCode detail=$detail"
    }
    $dirtyEntries = @(
        $statusOutput |
            ForEach-Object { ([string]$_).TrimEnd() } |
            Where-Object { $_ -ne '' }
    )
    if ($dirtyEntries.Count -ne 0) {
        throw "[$Checkpoint] Compile-relevant source is dirty relative to HEAD: $($dirtyEntries -join ' | ')"
    }
    return $actualCommit
}

function Get-TreeDigest {
    param([Parameter(Mandatory = $true)][string]$Root)

    $resolvedRoot = Assert-NoReparsePointsInTree `
        -Root $Root -Label 'Tree hash input'
    $prefix = $resolvedRoot + '\'
    $files = @(
        Get-ChildItem -LiteralPath $resolvedRoot -File -Recurse -Force |
            Sort-Object -Property FullName
    )
    if ($files.Count -eq 0) {
        throw "Tree hash input is empty: $resolvedRoot"
    }

    $builder = New-Object System.Text.StringBuilder
    [long]$totalBytes = 0
    foreach ($file in $files) {
        if (-not $file.FullName.StartsWith(
            $prefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Tree member escaped root: $($file.FullName)"
        }
        $relative = $file.FullName.Substring($prefix.Length).Replace('\', '/')
        $sha = Get-Sha256 -Path $file.FullName
        [void]$builder.Append($relative)
        [void]$builder.Append("`0")
        [void]$builder.Append($sha)
        [void]$builder.Append("`0")
        [void]$builder.Append([string]$file.Length)
        [void]$builder.Append("`n")
        $totalBytes += $file.Length
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($builder.ToString())
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $digestBytes = $algorithm.ComputeHash($bytes)
    }
    finally {
        $algorithm.Dispose()
    }
    $digest = ([System.BitConverter]::ToString($digestBytes)).Replace('-', '').ToLowerInvariant()
    return [pscustomobject][ordered]@{
        root = $resolvedRoot
        sha256 = $digest
        file_count = $files.Count
        total_bytes = $totalBytes
    }
}

function Copy-DirectoryContents {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [switch]$Overlay
    )

    Assert-NoReparsePointsInTree -Root $Source -Label 'Copy source directory' | Out-Null
    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
        throw "Copy destination directory missing: $Destination"
    }
    Assert-NoReparsePointInExistingPath `
        -Path $Destination -Label 'Copy destination directory' | Out-Null
    foreach ($child in Get-ChildItem -LiteralPath $Source -Force | Sort-Object -Property Name) {
        $copyArgs = @{
            LiteralPath = $child.FullName
            Destination = $Destination
            Recurse = $true
            ErrorAction = 'Stop'
        }
        if ($Overlay.IsPresent) {
            $copyArgs['Force'] = $true
        }
        Copy-Item @copyArgs
    }
}

function Write-JsonCreateOnly {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value
    )

    $json = ($Value | ConvertTo-Json -Depth 12) + "`n"
    $encoding = [System.Text.UTF8Encoding]::new($false)
    $stream = [System.IO.FileStream]::new(
        $Path,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    try {
        $writer = New-Object System.IO.StreamWriter($stream, $encoding)
        try {
            $writer.Write($json)
            $writer.Flush()
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        if ($stream) {
            $stream.Dispose()
        }
    }
}

function Get-MetaEditorProcesses {
    return @(
        Get-Process -Name 'metaeditor64', 'metaeditor' -ErrorAction SilentlyContinue
    )
}

function Assert-SafetyInterlocks {
    param(
        [Parameter(Mandatory = $true)][string]$FlagPath,
        [Parameter(Mandatory = $true)][string]$ExpectedFlagSha256,
        [Parameter(Mandatory = $true)][string]$LockPath,
        [Parameter(Mandatory = $true)][string]$Checkpoint
    )

    Assert-NoReparsePointInExistingPath `
        -Path $FlagPath -Label "[$Checkpoint] FACTORY_OFF path" | Out-Null
    Assert-NoReparsePointInExistingPath `
        -Path $LockPath -Label "[$Checkpoint] mutation-lock path" | Out-Null
    if (-not (Test-Path -LiteralPath $FlagPath -PathType Leaf)) {
        throw "[$Checkpoint] FACTORY_OFF.flag missing: $FlagPath"
    }
    $actualFlagSha = Get-Sha256 -Path $FlagPath
    if ($actualFlagSha -ne $ExpectedFlagSha256.ToLowerInvariant()) {
        throw "[$Checkpoint] FACTORY_OFF SHA-256 mismatch: expected=$ExpectedFlagSha256 actual=$actualFlagSha"
    }
    if (Test-Path -LiteralPath $LockPath) {
        throw "[$Checkpoint] factory mutation lock exists: $LockPath"
    }
    $activeMetaEditors = @(Get-MetaEditorProcesses)
    if ($activeMetaEditors.Count -ne 0) {
        $identities = ($activeMetaEditors | ForEach-Object { "$($_.ProcessName):$($_.Id)" }) -join ','
        throw "[$Checkpoint] MetaEditor process already active: $identities"
    }
    return $actualFlagSha
}

function Parse-CompileSummary {
    param([Parameter(Mandatory = $true)][string]$LogText)

    $matches = [regex]::Matches(
        $LogText,
        '(?im)(?<errors>\d+)\s+errors?\s*,\s*(?<warnings>\d+)\s+warnings?'
    )
    if ($matches.Count -eq 0) {
        throw 'Compile log has no exact errors/warnings summary.'
    }
    $summary = $matches[$matches.Count - 1]
    return [pscustomobject][ordered]@{
        errors = [int]$summary.Groups['errors'].Value
        warnings = [int]$summary.Groups['warnings'].Value
    }
}

function Assert-CompileLogProvenance {
    param(
        [Parameter(Mandatory = $true)][string]$LogText,
        [Parameter(Mandatory = $true)][string]$IsolatedMql5Root
    )

    if ($LogText -match '(?i)(?:%APPDATA%|\\Users\\[^\\\r\n]+\\AppData\\)') {
        throw 'Compile log contains APPDATA provenance.'
    }
    if ($LogText -match '(?i)[A-Z]:\\QM\\mt5\\(?:T_Live|T(?:10|[1-9])(?:_[^\\\r\n]+)?)(?:\\|$)') {
        throw 'Compile log contains T_Live/T1-T10 provenance.'
    }

    $paths = New-Object System.Collections.Generic.List[string]
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($environmentName in @('APPDATA', 'LOCALAPPDATA')) {
        $hostPath = [Environment]::GetEnvironmentVariable($environmentName, 'Process')
        if ($hostPath -and $LogText.IndexOf(
            $hostPath,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -ge 0) {
            throw "Compile log contains host $environmentName provenance."
        }
    }
    $headerMatches = [regex]::Matches(
        $LogText,
        '(?im)(?<path>[A-Z]:\\[^\r\n"''<>|]*?\.mqh)'
    )
    foreach ($match in $headerMatches) {
        $path = [System.IO.Path]::GetFullPath($match.Groups['path'].Value)
        if (-not (Test-PathWithin -Candidate $path -Parent $IsolatedMql5Root)) {
            throw "Compile log header escaped isolated MQL5 root: $path"
        }
        if ($seen.Add($path)) {
            [void]$paths.Add($path)
        }
    }
    return @($paths | Sort-Object)
}

function Invoke-PortableMetaEditorCompile {
    param(
        [Parameter(Mandatory = $true)][string]$WorkspaceMetaEditor,
        [Parameter(Mandatory = $true)][string]$StagedMq5,
        [Parameter(Mandatory = $true)][string]$CompileLog,
        [Parameter(Mandatory = $true)][string]$IsolatedRoamingAppData,
        [Parameter(Mandatory = $true)][string]$IsolatedLocalAppData,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds
    )

    $previousAppData = [Environment]::GetEnvironmentVariable('APPDATA', 'Process')
    $previousLocalAppData = [Environment]::GetEnvironmentVariable('LOCALAPPDATA', 'Process')
    $process = $null
    $startedUtc = (Get-Date).ToUniversalTime()
    try {
        [Environment]::SetEnvironmentVariable('APPDATA', $IsolatedRoamingAppData, 'Process')
        [Environment]::SetEnvironmentVariable('LOCALAPPDATA', $IsolatedLocalAppData, 'Process')
        $arguments = @(
            '/portable',
            ('/compile:"{0}"' -f $StagedMq5),
            ('/log:"{0}"' -f $CompileLog)
        )
        $process = Start-Process -FilePath $WorkspaceMetaEditor `
            -ArgumentList $arguments -PassThru -WindowStyle Hidden
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $identity = Get-CimInstance Win32_Process `
                -Filter "ProcessId=$($process.Id)" -ErrorAction SilentlyContinue
            if ($identity -and $identity.ExecutablePath -and
                (Get-NormalizedPath -Path $identity.ExecutablePath).Equals(
                    (Get-NormalizedPath -Path $WorkspaceMetaEditor),
                    [System.StringComparison]::OrdinalIgnoreCase
                )) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                $process.WaitForExit(10000) | Out-Null
            }
            throw "Portable MetaEditor timed out after $TimeoutSeconds seconds."
        }
        $exitCode = $process.ExitCode
    }
    finally {
        [Environment]::SetEnvironmentVariable('APPDATA', $previousAppData, 'Process')
        [Environment]::SetEnvironmentVariable('LOCALAPPDATA', $previousLocalAppData, 'Process')
    }

    return [pscustomobject][ordered]@{
        started_at_utc = $startedUtc.ToString('o')
        completed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        exit_code = $exitCode
    }
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$repoIncludeRoot = (Resolve-Path -LiteralPath (Join-Path $repoRoot 'framework\include')).Path
$repoEaRoot = (Resolve-Path -LiteralPath (Join-Path $repoRoot 'framework\EAs')).Path
$toolPath = (Resolve-Path -LiteralPath $PSCommandPath).Path
$artifactRootPath = Get-NormalizedPath -Path $ArtifactRoot
$templateRootPath = Get-NormalizedPath -Path $PortableTemplateRoot
$factoryOffPath = Get-NormalizedPath -Path $FactoryOffFlagPath
$mutationLock = Get-NormalizedPath -Path $MutationLockPath
$expectedFactoryOff = $ExpectedFactoryOffSha256.ToLowerInvariant()
$expectedSourceCommitNormalized = $ExpectedSourceCommit.ToLowerInvariant()
$v1ArtifactRoot = Get-NormalizedPath -Path 'D:\QM\strategy_farm\artifacts\ftmo_book3'

Assert-PathsDisjoint -Left $artifactRootPath -Right $v1ArtifactRoot `
    -Label 'V2 artifact root versus immutable V1 artifact root'
Assert-PathsDisjoint -Left $artifactRootPath -Right $repoRoot `
    -Label 'Artifact root versus repository'
Assert-NotProtectedTerminalPath -Path $artifactRootPath -Label 'Artifact root'
Assert-NotProtectedTerminalPath -Path $templateRootPath -Label 'Portable template root'

if (Test-Path -LiteralPath $artifactRootPath) {
    throw "ArtifactRoot is create-only and already exists: $artifactRootPath"
}
$artifactParent = Split-Path -Parent $artifactRootPath
if (-not (Test-Path -LiteralPath $artifactParent -PathType Container)) {
    throw "ArtifactRoot parent must already exist: $artifactParent"
}
if (-not (Test-Path -LiteralPath $templateRootPath -PathType Container)) {
    throw "Portable template root missing: $templateRootPath"
}

$sourceMetaEditor = Join-Path $templateRootPath 'MetaEditor64.exe'
$standardIncludeRoot = Join-Path $templateRootPath 'MQL5\Include'
if (-not (Test-Path -LiteralPath $sourceMetaEditor -PathType Leaf)) {
    throw "Portable template MetaEditor64.exe missing: $sourceMetaEditor"
}
if (-not (Test-Path -LiteralPath $standardIncludeRoot -PathType Container)) {
    throw "Portable template standard include tree missing: $standardIncludeRoot"
}
Assert-NoReparsePointInExistingPath `
    -Path $sourceMetaEditor -Label 'Portable template MetaEditor' | Out-Null
Assert-NoReparsePointsInTree `
    -Root $standardIncludeRoot -Label 'Portable template standard include tree' | Out-Null
Assert-NoReparsePointsInTree `
    -Root $repoIncludeRoot -Label 'Repository include tree' | Out-Null
Assert-NoReparsePointInExistingPath `
    -Path $toolPath -Label 'Compile controller' | Out-Null
$toolSha256 = Get-Sha256 -Path $toolPath
$sourceMetaEditorSha256 = Get-Sha256 -Path $sourceMetaEditor

$eaSpecs = @(
    [ordered]@{ ea_id = 9936; name = 'QM5_9936_ff-range-breakout-gmt3-h1' },
    [ordered]@{ ea_id = 10145; name = 'QM5_10145_tsm-meanret' },
    [ordered]@{ ea_id = 13108; name = 'QM5_13108_xti-mtsm-s2' },
    [ordered]@{ ea_id = 20181; name = 'QM5_20181_ftmo-joint-multisym-timer' }
)
foreach ($spec in $eaSpecs) {
    $sourceDirectory = Join-Path $repoEaRoot $spec.name
    $sourceMq5 = Join-Path $sourceDirectory ($spec.name + '.mq5')
    if (-not (Test-Path -LiteralPath $sourceMq5 -PathType Leaf)) {
        throw "Canonical FTMO MQ5 missing: $sourceMq5"
    }
    Assert-NoReparsePointsInTree `
        -Root $sourceDirectory -Label "Canonical FTMO EA tree $($spec.name)" | Out-Null
}

$compileSourcePathspecs = @('framework/include')
$compileSourcePathspecs += @(
    $eaSpecs | ForEach-Object { "framework/EAs/$($_.name)" }
)
$compileSourcePathspecs += 'tools/strategy_farm/compile_ftmo_book3_v2.ps1'
$actualSourceCommit = Assert-CompileSourceBinding -RepoRoot $repoRoot `
    -ExpectedCommit $expectedSourceCommitNormalized `
    -PathSpecs $compileSourcePathspecs -Checkpoint 'before-artifact-create'

Assert-SafetyInterlocks -FlagPath $factoryOffPath `
    -ExpectedFlagSha256 $expectedFactoryOff -LockPath $mutationLock `
    -Checkpoint 'before-artifact-create' | Out-Null

New-Item -ItemType Directory -Path $artifactRootPath -ErrorAction Stop | Out-Null
Assert-NoReparsePointInExistingPath `
    -Path $artifactRootPath -Label 'Created artifact root' | Out-Null
$workspaceRoot = Join-Path $artifactRootPath 'workspace'
$compilerRoot = Join-Path $workspaceRoot 'portable_metaeditor'
$isolatedMql5Root = Join-Path $compilerRoot 'MQL5'
$isolatedIncludeRoot = Join-Path $isolatedMql5Root 'Include'
$isolatedExpertsRoot = Join-Path $isolatedMql5Root 'Experts\FTMO_Book3_V2'
$workLogRoot = Join-Path $workspaceRoot 'compile_logs'
$isolatedRoaming = Join-Path $workspaceRoot 'profile\Roaming'
$isolatedLocal = Join-Path $workspaceRoot 'profile\Local'
foreach ($directory in @(
    $workspaceRoot,
    $compilerRoot,
    $isolatedMql5Root,
    $isolatedIncludeRoot,
    $isolatedExpertsRoot,
    $workLogRoot,
    $isolatedRoaming,
    $isolatedLocal
)) {
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -ErrorAction Stop | Out-Null
    }
}

# Copy only the compiler executable plus narrowly allowlisted top-level runtime
# dependencies. Terminal/tester binaries and unrelated template artifacts are
# deliberately excluded.
$runtimeExtensions = @('.dll', '.dat', '.ico')
foreach ($file in Get-ChildItem -LiteralPath $templateRootPath -File -Force |
    Sort-Object -Property Name) {
    $isMetaEditor = $file.Name.Equals(
        'MetaEditor64.exe',
        [System.StringComparison]::OrdinalIgnoreCase
    )
    if (-not $isMetaEditor -and
        $runtimeExtensions -notcontains $file.Extension.ToLowerInvariant()) {
        continue
    }
    if ($file.Name.Equals('portable.txt', [System.StringComparison]::OrdinalIgnoreCase)) {
        continue
    }
    Assert-NoReparsePointInExistingPath `
        -Path $file.FullName -Label "Portable runtime dependency $($file.Name)" | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $compilerRoot -ErrorAction Stop
}
$workspaceMetaEditor = Join-Path $compilerRoot 'MetaEditor64.exe'
if (-not (Test-Path -LiteralPath $workspaceMetaEditor -PathType Leaf)) {
    throw 'Isolated MetaEditor copy is missing.'
}
if ((Get-Sha256 -Path $workspaceMetaEditor) -ne $sourceMetaEditorSha256) {
    throw 'Isolated MetaEditor copy hash mismatch.'
}
$portableMarker = Join-Path $compilerRoot 'portable.txt'
$portableMarkerStream = [System.IO.FileStream]::new(
    $portableMarker,
    [System.IO.FileMode]::CreateNew,
    [System.IO.FileAccess]::Write,
    [System.IO.FileShare]::None
)
$portableMarkerStream.Dispose()

$standardIncludeDigest = Get-TreeDigest -Root $standardIncludeRoot
$repoIncludeDigest = Get-TreeDigest -Root $repoIncludeRoot
Copy-DirectoryContents -Source $standardIncludeRoot -Destination $isolatedIncludeRoot
Copy-DirectoryContents -Source $repoIncludeRoot -Destination $isolatedIncludeRoot -Overlay
$mergedIncludeDigestBefore = Get-TreeDigest -Root $isolatedIncludeRoot

$results = New-Object System.Collections.Generic.List[object]
foreach ($spec in $eaSpecs) {
    Assert-CompileSourceBinding -RepoRoot $repoRoot `
        -ExpectedCommit $expectedSourceCommitNormalized `
        -PathSpecs $compileSourcePathspecs `
        -Checkpoint ("before-compile-{0}" -f $spec.ea_id) | Out-Null
    Assert-SafetyInterlocks -FlagPath $factoryOffPath `
        -ExpectedFlagSha256 $expectedFactoryOff -LockPath $mutationLock `
        -Checkpoint ("before-compile-{0}" -f $spec.ea_id) | Out-Null

    $sourceDirectory = Join-Path $repoEaRoot $spec.name
    $sourceMq5 = Join-Path $sourceDirectory ($spec.name + '.mq5')
    Assert-NoReparsePointsInTree `
        -Root $sourceDirectory -Label "Canonical FTMO EA tree $($spec.name)" | Out-Null
    $stagedDirectory = Join-Path $isolatedExpertsRoot $spec.name
    if (Test-Path -LiteralPath $stagedDirectory) {
        throw "Create-only staged EA directory already exists: $stagedDirectory"
    }
    Copy-Item -LiteralPath $sourceDirectory -Destination $stagedDirectory `
        -Recurse -ErrorAction Stop
    $stagedMq5 = Join-Path $stagedDirectory ($spec.name + '.mq5')
    $stagedEx5 = [System.IO.Path]::ChangeExtension($stagedMq5, '.ex5')
    $workLog = Join-Path $workLogRoot ($spec.name + '.compile.log')
    if (-not (Test-PathWithin -Candidate $stagedEx5 -Parent $workspaceRoot)) {
        throw "Computed EX5 escaped new workspace: $stagedEx5"
    }
    if (Test-Path -LiteralPath $workLog) {
        throw "Create-only work compile log already exists: $workLog"
    }

    # MetaEditor can silently skip an include-only rebuild if a target EX5 is
    # present. Delete only this copied workspace target; canonical repo and V1
    # artifacts are structurally outside the permitted removal scope.
    if (Test-Path -LiteralPath $stagedEx5 -PathType Leaf) {
        Remove-Item -LiteralPath $stagedEx5 -Force
    }
    $sourceMq5Sha = Get-Sha256 -Path $sourceMq5
    $stagedMq5ShaBefore = Get-Sha256 -Path $stagedMq5
    if ($sourceMq5Sha -ne $stagedMq5ShaBefore) {
        throw "Staged MQ5 hash mismatch before compile: $($spec.name)"
    }

    $compileStarted = (Get-Date).ToUniversalTime()
    $processResult = Invoke-PortableMetaEditorCompile `
        -WorkspaceMetaEditor $workspaceMetaEditor `
        -StagedMq5 $stagedMq5 `
        -CompileLog $workLog `
        -IsolatedRoamingAppData $isolatedRoaming `
        -IsolatedLocalAppData $isolatedLocal `
        -TimeoutSeconds $TimeoutSecondsPerEa

    if (-not (Test-Path -LiteralPath $workLog -PathType Leaf)) {
        throw "MetaEditor produced no compile log: $($spec.name)"
    }
    if (-not (Test-Path -LiteralPath $stagedEx5 -PathType Leaf)) {
        throw "MetaEditor produced no EX5: $($spec.name)"
    }
    $logFile = Get-Item -LiteralPath $workLog
    $ex5File = Get-Item -LiteralPath $stagedEx5
    if ($logFile.Length -le 0 -or $ex5File.Length -le 0) {
        throw "MetaEditor produced an empty log or EX5: $($spec.name)"
    }
    if ($logFile.LastWriteTimeUtc -lt $compileStarted.AddSeconds(-2) -or
        $ex5File.LastWriteTimeUtc -lt $compileStarted.AddSeconds(-2)) {
        throw "Compile output predates this invocation: $($spec.name)"
    }

    $logText = Get-Content -Raw -LiteralPath $workLog
    $summary = Parse-CompileSummary -LogText $logText
    if ($summary.errors -ne 0 -or $summary.warnings -ne 0) {
        throw "Strict compile failed for $($spec.name): errors=$($summary.errors) warnings=$($summary.warnings)"
    }
    $includeProvenance = @(Assert-CompileLogProvenance `
        -LogText $logText -IsolatedMql5Root $isolatedMql5Root)
    $stagedMq5ShaAfter = Get-Sha256 -Path $stagedMq5
    if ($stagedMq5ShaAfter -ne $stagedMq5ShaBefore) {
        throw "MetaEditor changed staged MQ5 bytes: $($spec.name)"
    }

    [void]$results.Add([pscustomobject][ordered]@{
        ea_id = $spec.ea_id
        name = $spec.name
        result = 'PASS'
        errors = $summary.errors
        warnings = $summary.warnings
        metaeditor_exit_code = $processResult.exit_code
        started_at_utc = $processResult.started_at_utc
        completed_at_utc = $processResult.completed_at_utc
        source_mq5_path = $sourceMq5
        source_mq5_sha256 = $sourceMq5Sha
        staged_mq5_path = $stagedMq5
        staged_mq5_sha256 = $stagedMq5ShaAfter
        work_ex5_path = $stagedEx5
        ex5_sha256 = Get-Sha256 -Path $stagedEx5
        work_log_path = $workLog
        log_sha256 = Get-Sha256 -Path $workLog
        include_provenance = $includeProvenance
    })

    Assert-SafetyInterlocks -FlagPath $factoryOffPath `
        -ExpectedFlagSha256 $expectedFactoryOff -LockPath $mutationLock `
        -Checkpoint ("after-compile-{0}" -f $spec.ea_id) | Out-Null
    Assert-CompileSourceBinding -RepoRoot $repoRoot `
        -ExpectedCommit $expectedSourceCommitNormalized `
        -PathSpecs $compileSourcePathspecs `
        -Checkpoint ("after-compile-{0}" -f $spec.ea_id) | Out-Null
}

if ($results.Count -ne $eaSpecs.Count -or
    @($results | Where-Object { $_.result -ne 'PASS' }).Count -ne 0) {
    throw 'Canonical publication requires exactly four serial PASS results.'
}
$standardIncludeDigestAfter = Get-TreeDigest -Root $standardIncludeRoot
$repoIncludeDigestAfter = Get-TreeDigest -Root $repoIncludeRoot
if ($standardIncludeDigestAfter.sha256 -ne $standardIncludeDigest.sha256 -or
    $repoIncludeDigestAfter.sha256 -ne $repoIncludeDigest.sha256) {
    throw 'Canonical source include tree changed during compile.'
}
if ((Get-Sha256 -Path $toolPath) -ne $toolSha256 -or
    (Get-Sha256 -Path $sourceMetaEditor) -ne $sourceMetaEditorSha256) {
    throw 'Compile tool or source MetaEditor changed during compile.'
}
foreach ($result in $results) {
    if ((Get-Sha256 -Path $result.source_mq5_path) -ne $result.source_mq5_sha256) {
        throw "Canonical MQ5 changed during compile: $($result.name)"
    }
}
$mergedIncludeDigestAfter = Get-TreeDigest -Root $isolatedIncludeRoot
if ($mergedIncludeDigestAfter.sha256 -ne $mergedIncludeDigestBefore.sha256) {
    throw 'Isolated include tree changed during compile.'
}

# Publication is assembled only after all four strict compiles pass. Canonical
# directories are moved into place without overwrite, and the manifest is the
# final create-only commit marker.
$publicationStage = Join-Path $workspaceRoot 'publication_stage'
$publicationEx5 = Join-Path $publicationStage 'canonical_staged_ex5'
$publicationLogs = Join-Path $publicationStage 'canonical_compile_logs'
foreach ($directory in @($publicationStage, $publicationEx5, $publicationLogs)) {
    New-Item -ItemType Directory -Path $directory -ErrorAction Stop | Out-Null
}
foreach ($result in $results) {
    $publishedEx5 = Join-Path $publicationEx5 ($result.name + '.ex5')
    $publishedLog = Join-Path $publicationLogs ($result.name + '.compile.log')
    Copy-Item -LiteralPath $result.work_ex5_path -Destination $publishedEx5 -ErrorAction Stop
    Copy-Item -LiteralPath $result.work_log_path -Destination $publishedLog -ErrorAction Stop
    if ((Get-Sha256 -Path $publishedEx5) -ne $result.ex5_sha256 -or
        (Get-Sha256 -Path $publishedLog) -ne $result.log_sha256) {
        throw "Publication staging hash mismatch: $($result.name)"
    }
}

Assert-SafetyInterlocks -FlagPath $factoryOffPath `
    -ExpectedFlagSha256 $expectedFactoryOff -LockPath $mutationLock `
    -Checkpoint 'before-canonical-publication' | Out-Null
Assert-CompileSourceBinding -RepoRoot $repoRoot `
    -ExpectedCommit $expectedSourceCommitNormalized `
    -PathSpecs $compileSourcePathspecs `
    -Checkpoint 'before-canonical-publication' | Out-Null
Assert-NoReparsePointsInTree `
    -Root $artifactRootPath -Label 'Artifact root before publication' | Out-Null
Assert-NoReparsePointInExistingPath `
    -Path $templateRootPath -Label 'Portable template root before publication' | Out-Null

$canonicalEx5 = Join-Path $artifactRootPath 'canonical_staged_ex5'
$canonicalLogs = Join-Path $artifactRootPath 'canonical_compile_logs'
$manifestPath = Join-Path $artifactRootPath 'compile_manifest.json'
foreach ($destination in @($canonicalEx5, $canonicalLogs, $manifestPath)) {
    if (Test-Path -LiteralPath $destination) {
        throw "Create-only canonical destination already exists: $destination"
    }
}
Move-Item -LiteralPath $publicationEx5 -Destination $canonicalEx5 -ErrorAction Stop
Move-Item -LiteralPath $publicationLogs -Destination $canonicalLogs -ErrorAction Stop

$manifestResults = New-Object System.Collections.Generic.List[object]
foreach ($result in $results) {
    $finalEx5 = Join-Path $canonicalEx5 ($result.name + '.ex5')
    $finalLog = Join-Path $canonicalLogs ($result.name + '.compile.log')
    if ((Get-Sha256 -Path $finalEx5) -ne $result.ex5_sha256 -or
        (Get-Sha256 -Path $finalLog) -ne $result.log_sha256) {
        throw "Canonical publication hash mismatch: $($result.name)"
    }
    [void]$manifestResults.Add([ordered]@{
        ea_id = $result.ea_id
        name = $result.name
        result = $result.result
        errors = $result.errors
        warnings = $result.warnings
        metaeditor_exit_code = $result.metaeditor_exit_code
        started_at_utc = $result.started_at_utc
        completed_at_utc = $result.completed_at_utc
        source_mq5_path = $result.source_mq5_path
        source_mq5_sha256 = $result.source_mq5_sha256
        staged_mq5_path = $result.staged_mq5_path
        staged_mq5_sha256 = $result.staged_mq5_sha256
        ex5_path = $finalEx5
        ex5_sha256 = $result.ex5_sha256
        compile_log_path = $finalLog
        compile_log_sha256 = $result.log_sha256
        include_provenance = $result.include_provenance
    })
}

Assert-SafetyInterlocks -FlagPath $factoryOffPath `
    -ExpectedFlagSha256 $expectedFactoryOff -LockPath $mutationLock `
    -Checkpoint 'before-manifest-commit' | Out-Null
Assert-CompileSourceBinding -RepoRoot $repoRoot `
    -ExpectedCommit $expectedSourceCommitNormalized `
    -PathSpecs $compileSourcePathspecs `
    -Checkpoint 'before-manifest-commit' | Out-Null
Assert-NoReparsePointsInTree `
    -Root $artifactRootPath -Label 'Artifact root before manifest commit' | Out-Null

$sourceCompilerInfo = Get-Item -LiteralPath $sourceMetaEditor
$manifest = [ordered]@{
    schema_version = 2
    contract = 'FTMO_BOOK3_PORTABLE_COMPILE_V2'
    result = 'PASS'
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    source_commit = $actualSourceCommit
    artifact_root = $artifactRootPath
    create_only = $true
    serial_compile = $true
    canonical_publication_after_four_pass = $true
    terminals_started = @()
    terminals_modified = @()
    factory_off = [ordered]@{
        path = $factoryOffPath
        sha256 = $expectedFactoryOff
    }
    mutation_lock = [ordered]@{
        path = $mutationLock
        required_absent = $true
    }
    tool = [ordered]@{
        path = $toolPath
        sha256 = $toolSha256
    }
    compiler = [ordered]@{
        portable = $true
        invocation_switch = '/portable'
        source_template_root = $templateRootPath
        source_path = $sourceMetaEditor
        source_sha256 = $sourceMetaEditorSha256
        workspace_path = $workspaceMetaEditor
        workspace_sha256 = Get-Sha256 -Path $workspaceMetaEditor
        file_version = $sourceCompilerInfo.VersionInfo.FileVersion
        product_version = $sourceCompilerInfo.VersionInfo.ProductVersion
        isolated_appdata = $isolatedRoaming
        isolated_localappdata = $isolatedLocal
    }
    include_trees = [ordered]@{
        standard_source = $standardIncludeDigest
        standard_source_after = $standardIncludeDigestAfter
        repo_overlay = $repoIncludeDigest
        repo_overlay_after = $repoIncludeDigestAfter
        isolated_merged_before = $mergedIncludeDigestBefore
        isolated_merged_after = $mergedIncludeDigestAfter
    }
    compile_order = @($eaSpecs | ForEach-Object { $_.name })
    # PowerShell 7.5 can throw "Argument types do not match" when the array
    # subexpression binder receives a generic List[object] directly.  Force
    # enumeration through the pipeline so the create-only manifest is a plain
    # object array on every supported PowerShell version.
    results = @($manifestResults | ForEach-Object { $_ })
    publication = [ordered]@{
        staged_ex5_tree = Get-TreeDigest -Root $canonicalEx5
        compile_logs_tree = Get-TreeDigest -Root $canonicalLogs
    }
}
Write-JsonCreateOnly -Path $manifestPath -Value $manifest

Write-Output 'PASS: FTMO Book-3 V2 portable compile (4/4, 0 errors, 0 warnings)'
Write-Output "artifact_root=$artifactRootPath"
Write-Output "manifest=$manifestPath"
