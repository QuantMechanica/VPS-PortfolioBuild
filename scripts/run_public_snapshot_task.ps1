[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$LogPath = "C:\Windows\Temp\qm_public_snapshot.log",
    [string]$PythonExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe",
    [string]$FarmDbPath = "D:\QM\strategy_farm\state\farm_state.sqlite",
    [string]$FactoryOffFlagPath = "D:\QM\strategy_farm\state\FACTORY_OFF.flag",
    [string]$FactoryMutationLockPath = "D:\QM\strategy_farm\state\FACTORY_MUTATION.lock",
    [string]$DeployRepo = "C:\QM\deploy\quantmechanica-ops",
    [string]$PublishReceiptPath = "",
    [switch]$Publish,
    [ValidateRange(30, 3600)]
    [int]$TaskTimeoutSeconds = 600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-TaskLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f ([datetime]::UtcNow.ToString("o")), $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

function Get-RemainingTimeoutSeconds {
    $remaining = [int][math]::Floor(
        ($script:taskDeadlineUtc - [datetime]::UtcNow).TotalSeconds
    )
    if ($remaining -lt 1) {
        throw "public snapshot task exceeded ${TaskTimeoutSeconds}s deadline"
    }
    return $remaining
}

function Invoke-BoundedProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$Label
    )

    $remainingSeconds = Get-RemainingTimeoutSeconds
    $token = [guid]::NewGuid().ToString('N')
    $stdoutPath = Join-Path ([IO.Path]::GetTempPath()) `
        "qm_snapshot_${token}.stdout.log"
    $stderrPath = Join-Path ([IO.Path]::GetTempPath()) `
        "qm_snapshot_${token}.stderr.log"
    $process = $null
    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList `
            -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        if (-not $process.WaitForExit($remainingSeconds * 1000)) {
            Write-TaskLog (
                "public_snapshot_task watchdog_timeout label=$Label " +
                "pid=$($process.Id) deadline_s=$TaskTimeoutSeconds"
            )
            $oldPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                & taskkill.exe /PID $process.Id /T /F 2>&1 |
                    ForEach-Object { Write-TaskLog $_ }
            }
            finally {
                $ErrorActionPreference = $oldPreference
            }
            throw "$Label exceeded the public snapshot ${TaskTimeoutSeconds}s task deadline"
        }
        # WaitForExit(Int32) can report completion before redirected async
        # stdout/stderr handlers have drained, and on some PowerShell/.NET
        # combinations ExitCode remains unset until the parameterless wait and
        # refresh complete.  A null ExitCode compares unequal to zero and made
        # the incident guard fail closed even when its JSON said valid=true and
        # publication_allowed=true (the log showed ``rc=``).
        $process.WaitForExit()
        $process.Refresh()
        $exitCode = [int]$process.ExitCode
        $output = @()
        if (Test-Path -LiteralPath $stdoutPath) {
            $output += @(Get-Content -LiteralPath $stdoutPath -ErrorAction SilentlyContinue)
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $output += @(Get-Content -LiteralPath $stderrPath -ErrorAction SilentlyContinue)
        }
        return [pscustomobject]@{
            ExitCode = $exitCode
            Output = $output
        }
    }
    finally {
        if ($null -ne $process) { $process.Dispose() }
        Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

New-Item -ItemType Directory -Path (Split-Path -Parent $LogPath) -Force |
    Out-Null
Write-TaskLog "public_snapshot_task start"
$script:taskDeadlineUtc = [datetime]::UtcNow.AddSeconds($TaskTimeoutSeconds)
$publishRequested = [bool]$Publish -or ([string]$env:QM_PUBLIC_PUBLISH -ceq '1')
Write-TaskLog "public_snapshot_task publish_requested=$publishRequested"

$mutationLockStream = $null
$mutationLockBytesBase64 = $null
$locationPushed = $false
$snapshotStageDir = $null
try {
    if (Test-Path -LiteralPath $FactoryOffFlagPath) {
        Write-TaskLog "public_snapshot_task skipped=FACTORY_OFF.flag"
        return
    }
    if (-not (Test-Path -LiteralPath $PythonExe)) {
        throw "Python executable not found: $PythonExe"
    }

    Push-Location $RepoRoot
    $locationPushed = $true

    $incidentGuardScript = Join-Path $RepoRoot `
        "tools\strategy_farm\public_snapshot_incident_guard.py"
    if (-not (Test-Path -LiteralPath $incidentGuardScript -PathType Leaf)) {
        throw "public snapshot incident guard missing: $incidentGuardScript"
    }
    $guardRun = Invoke-BoundedProcess -FilePath $PythonExe `
        -ArgumentList @($incidentGuardScript, '--db', $FarmDbPath) `
        -Label 'public_snapshot_incident_guard.py'
    $guardOutput = @($guardRun.Output)
    $guardExitCode = $guardRun.ExitCode
    $guardJsonLine = @($guardOutput | ForEach-Object { [string]$_ } |
        Where-Object { $_.Trim().StartsWith('{') -and $_.Trim().EndsWith('}') } |
        Select-Object -Last 1)
    if ($guardJsonLine.Count -ne 1) {
        throw ("public snapshot incident guard returned no JSON record " +
            "(rc=$guardExitCode output=$($guardOutput -join ' | '))")
    }
    try {
        $incidentGuard = [string]$guardJsonLine[0] |
            ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "public snapshot incident guard returned invalid JSON: $($_.Exception.Message)"
    }
    if ([string]$incidentGuard.schema_version -cne `
            'qm-public-snapshot-incident-guard/v1' -or
        $incidentGuard.valid -isnot [bool] -or
        $incidentGuard.publication_allowed -isnot [bool]) {
        throw 'public snapshot incident guard returned an invalid contract'
    }
    if ($guardExitCode -ne 0 -or -not [bool]$incidentGuard.valid -or
        -not [bool]$incidentGuard.publication_allowed) {
        $holds = @($incidentGuard.active_incident_holds | ForEach-Object {
            "{0}:{1}" -f ([string]$_.hold_code),([string]$_.work_item_id)
        })
        throw ("public snapshot publication refused by incident guard " +
            "(rc=$guardExitCode valid=$($incidentGuard.valid) " +
            "holds=[$($holds -join ',')] error=$($incidentGuard.error))")
    }

    # Both DB-heavy children run before the tracked-file mutation lock exists.
    $pipelineRun = Invoke-BoundedProcess -FilePath $PythonExe `
        -ArgumentList @((Join-Path $RepoRoot 'scripts\build_pipeline_state.py')) `
        -Label 'build_pipeline_state.py'
    $pipelineRun.Output | ForEach-Object { Write-TaskLog $_ }
    if ($pipelineRun.ExitCode -ne 0) {
        throw "build_pipeline_state.py failed with exit code $($pipelineRun.ExitCode)"
    }

    $snapshotStageDir = Join-Path ([IO.Path]::GetTempPath()) `
        ("qm_public_snapshot_stage_{0}" -f [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $snapshotStageDir | Out-Null
    $exportArguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $RepoRoot 'scripts\export_public_snapshot.ps1'),
        '-RepoRoot', $RepoRoot,
        '-PublicDataDir', (Join-Path $RepoRoot 'public-data'),
        '-OutputDir', $snapshotStageDir,
        '-FarmDbPath', $FarmDbPath,
        '-PythonExe', $PythonExe
    )
    if (-not $publishRequested) { $exportArguments += '-NoGit' }
    $exportRun = Invoke-BoundedProcess -FilePath 'powershell.exe' `
        -ArgumentList $exportArguments -Label 'export_public_snapshot.ps1'
    $exportRun.Output | ForEach-Object { Write-TaskLog $_ }
    if ($exportRun.ExitCode -ne 0) {
        throw "export_public_snapshot.ps1 failed with exit code $($exportRun.ExitCode)"
    }

    # The global writer lock covers only the short staged-file publication.
    Get-RemainingTimeoutSeconds | Out-Null
    $mutationLockProtocolPath = Join-Path $RepoRoot `
        'tools\strategy_farm\factory_mutation_lock.ps1'
    if (-not (Test-Path -LiteralPath $mutationLockProtocolPath -PathType Leaf)) {
        throw "Mutation-lock protocol missing: $mutationLockProtocolPath"
    }
    . $mutationLockProtocolPath
    if ($script:QmFactoryMutationLockProtocolVersion -ne 2 -or
        -not (Get-Command -Name 'Remove-QmFactoryMutationLockIfUnchanged' `
            -CommandType Function -ErrorAction SilentlyContinue)) {
        throw 'Mutation-lock protocol version/function mismatch.'
    }

    $lockParent = Split-Path -Parent $FactoryMutationLockPath
    New-Item -ItemType Directory -Path $lockParent -Force | Out-Null
    try {
        $mutationLockStream = [System.IO.File]::Open(
            $FactoryMutationLockPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::Read
        )
        $lockRecord = [ordered]@{
            pid = $PID
            owner = 'public_snapshot'
            nonce = [guid]::NewGuid().ToString('N')
            created_at = [datetime]::UtcNow.ToString('o')
        } | ConvertTo-Json -Compress
        $lockBytes = [System.Text.Encoding]::UTF8.GetBytes($lockRecord)
        $mutationLockBytesBase64 = [Convert]::ToBase64String($lockBytes)
        $mutationLockStream.Write($lockBytes, 0, $lockBytes.Length)
        $mutationLockStream.Flush($true)
    }
    catch [System.IO.IOException] {
        Write-TaskLog "public_snapshot_task skipped=factory_mutation_lock_busy"
        return
    }

    if (Test-Path -LiteralPath $FactoryOffFlagPath) {
        Write-TaskLog "public_snapshot_task skipped=FACTORY_OFF.flag_after_lock"
        return
    }

    $publicDataDir = Join-Path $RepoRoot 'public-data'
    $published = New-Object System.Collections.Generic.List[string]
    foreach ($name in @(
        'public-snapshot.json', 'process-roadmap.json',
        'strategy-archive.json', 'company-operating-model.json', 'stats.json',
        'hero-equity.json'
    )) {
        $source = Join-Path $snapshotStageDir $name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "staged snapshot file missing: $source"
        }
        $destination = Join-Path $publicDataDir $name
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $destinationHash = if (Test-Path -LiteralPath $destination -PathType Leaf) {
            (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        } else {
            ''
        }
        if ($sourceHash -eq $destinationHash) { continue }
        $publishTemp = "${destination}.tmp.$PID"
        Copy-Item -LiteralPath $source -Destination $publishTemp -Force
        Move-Item -LiteralPath $publishTemp -Destination $destination -Force
        $published.Add($destination)
    }
    Write-TaskLog "public_snapshot_task publish_count=$($published.Count)"

    # Git and network operations never run while the factory mutation lock is
    # held. Release the exact nonce-bound lock before validation/publication.
    $mutationLockStream.Dispose()
    $mutationLockStream = $null
    $releasedExactLock = Remove-QmFactoryMutationLockIfUnchanged `
        -Path $FactoryMutationLockPath `
        -ExpectedRawBytesBase64 $mutationLockBytesBase64
    if (-not $releasedExactLock) {
        throw 'public snapshot mutation lock release failed closed'
    }

    $validationRun = Invoke-BoundedProcess -FilePath 'powershell.exe' `
        -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', (Join-Path $RepoRoot 'scripts\validate_public_snapshot.ps1'),
            '-RepoRoot', $RepoRoot,
            '-DataDir', $publicDataDir
        ) -Label 'validate_public_snapshot.ps1'
    $validationRun.Output | ForEach-Object { Write-TaskLog $_ }
    if ($validationRun.ExitCode -ne 0) {
        throw "validate_public_snapshot.ps1 failed with exit code $($validationRun.ExitCode)"
    }

    if ($publishRequested) {
        $publicPaths = @(
            'public-data/public-snapshot.json',
            'public-data/process-roadmap.json',
            'public-data/strategy-archive.json',
            'public-data/company-operating-model.json',
            'public-data/stats.json',
            'public-data/hero-equity.json'
        )
        $gitAddRun = Invoke-BoundedProcess -FilePath 'git.exe' `
            -ArgumentList (@('-C', $RepoRoot, 'add', '--') + $publicPaths) `
            -Label 'git add public snapshot'
        if ($gitAddRun.ExitCode -ne 0) { throw 'git add public snapshot failed' }

        $gitDiffRun = Invoke-BoundedProcess -FilePath 'git.exe' `
            -ArgumentList (@('-C', $RepoRoot, 'diff', '--cached', '--quiet', '--') + $publicPaths) `
            -Label 'git diff public snapshot'
        if ($gitDiffRun.ExitCode -eq 1) {
            $gitCommitRun = Invoke-BoundedProcess -FilePath 'git.exe' `
                -ArgumentList (@(
                    '-C', $RepoRoot, 'commit', '-m',
                    'infra: refresh validated public snapshot', '--'
                ) + $publicPaths) -Label 'git commit public snapshot'
            $gitCommitRun.Output | ForEach-Object { Write-TaskLog $_ }
            if ($gitCommitRun.ExitCode -ne 0) { throw 'git commit public snapshot failed' }
        } elseif ($gitDiffRun.ExitCode -ne 0) {
            throw "git diff public snapshot failed with exit code $($gitDiffRun.ExitCode)"
        }

        $gitPushRun = Invoke-BoundedProcess -FilePath 'git.exe' `
            -ArgumentList @('-C', $RepoRoot, 'push') -Label 'git push public snapshot'
        $gitPushRun.Output | ForEach-Object { Write-TaskLog $_ }
        if ($gitPushRun.ExitCode -ne 0) { throw 'git push public snapshot failed' }
    }

    $syncArguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $RepoRoot 'scripts\sync_public_data_to_website.ps1'),
        '-RepoRoot', $RepoRoot,
        '-DataDir', $publicDataDir,
        '-SchemaDir', $publicDataDir,
        '-DeployRepo', $DeployRepo,
        '-Apply', '-Commit'
    )
    if (-not [string]::IsNullOrWhiteSpace($PublishReceiptPath)) {
        $syncArguments += @('-ReceiptPath', $PublishReceiptPath)
    }
    if ($publishRequested) { $syncArguments += '-Push' }
    $syncRun = Invoke-BoundedProcess -FilePath 'powershell.exe' `
        -ArgumentList $syncArguments -Label 'sync_public_data_to_website.ps1'
    $syncRun.Output | ForEach-Object { Write-TaskLog $_ }
    if ($syncRun.ExitCode -ne 0) {
        throw "sync_public_data_to_website.ps1 failed with exit code $($syncRun.ExitCode)"
    }

    Write-TaskLog "public_snapshot_task exit=0"
}
catch {
    Write-TaskLog "public_snapshot_task exit=1 error=$($_.Exception.Message)"
    throw
}
finally {
    if ($locationPushed) {
        Pop-Location
    }
    if ($null -ne $mutationLockStream) {
        $mutationLockStream.Dispose()
        $releasedExactLock = Remove-QmFactoryMutationLockIfUnchanged `
            -Path $FactoryMutationLockPath `
            -ExpectedRawBytesBase64 $mutationLockBytesBase64
        if (-not $releasedExactLock) {
            Write-TaskLog `
                'public_snapshot_task mutation_lock_release=retained_fail_closed'
        }
    }
    if ($snapshotStageDir -and
        (Test-Path -LiteralPath $snapshotStageDir -PathType Container)) {
        $resolvedStage = [IO.Path]::GetFullPath($snapshotStageDir)
        $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolvedStage.StartsWith(
                $resolvedTemp, [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Split-Path -Leaf $resolvedStage).StartsWith(
                'qm_public_snapshot_stage_'
            )) {
            Remove-Item -LiteralPath $resolvedStage -Recurse -Force `
                -ErrorAction SilentlyContinue
        }
    }
}
