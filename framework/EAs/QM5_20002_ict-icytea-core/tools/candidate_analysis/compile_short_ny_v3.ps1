[CmdletBinding()]
param(
    [switch]$Child,
    [string]$RunRoot,
    [string]$ExpectedSid,
    [string]$ExpectedSourceSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath('C:\QM\repo')
$eaRoot = Join-Path $repoRoot 'framework\EAs\QM5_20002_ict-icytea-core'
$source = Join-Path $eaRoot 'QM5_20002_ict-icytea-core.mq5'
$repoEx5 = [IO.Path]::ChangeExtension($source, '.ex5')
$repoInclude = Join-Path $repoRoot 'framework\include'
$compileOne = Join-Path $repoRoot 'framework\scripts\compile_one.ps1'
$devRoot = [IO.Path]::GetFullPath('D:\QM\mt5\DEV1')
$metaEditor = Join-Path $devRoot 'MetaEditor64.exe'
$pwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'
$credentialPath = 'C:\ProgramData\QM\DEV1\credential.clixml'
$reportsRoot = [IO.Path]::GetFullPath('D:\QM\reports\dev1\build\compile')
$controllerScript = [IO.Path]::GetFullPath($PSCommandPath)
$expectedContractCommit = 'd902b04932c340dd1212b9420077d7cec6b0d80d'
$expectedContractSha256 = '6ee74c60a823fe87b03b40a2737ba67d113b2e52e7c09a05f42ba2084e17fefa'
$expectedSourceCommit = '3f1039f0eeb56ee882b5c3451eed3ee71567d6bc'
$frozenSourceSha256 = '3fd49f2cea7575e659f1b1cf9c24c752a4a8e11db5e0c17cae69629a6f207f83'
$researchStatus = 'CARD_INTAKE_NOT_APPROVED'
$taskPrefix = 'QM_DEV1_COMPILE_QM20002_'

function Test-UnderRoot([string]$Path, [string]$Root) {
    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    return $fullPath.StartsWith($fullRoot + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Assert-PhysicalPath([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Required path missing: $Path" }
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    $cursor = $root
    foreach ($part in $full.Substring($root.Length).Split('\', [StringSplitOptions]::RemoveEmptyEntries)) {
        $cursor = Join-Path $cursor $part
        $item = Get-Item -LiteralPath $cursor -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point forbidden in compile chain: $cursor"
        }
    }
}

function Get-Dev1Processes {
    return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ExecutablePath -and (Test-UnderRoot -Path ([string]$_.ExecutablePath) -Root $devRoot)
    })
}

function Get-EphemeralCompileTasks {
    return @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $_.TaskPath -eq '\' -and $_.TaskName.StartsWith($taskPrefix, [StringComparison]::Ordinal)
    })
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-AtomicJson([string]$Path, [object]$Value) {
    $temp = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding utf8
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Resolve-Dev1ProfileInclude {
    $terminalProfiles = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
    $matches = @(Get-ChildItem -LiteralPath $terminalProfiles -Directory -ErrorAction Stop | Where-Object {
        $origin = Join-Path $_.FullName 'origin.txt'
        (Test-Path -LiteralPath $origin -PathType Leaf) -and
        ((Get-Content -LiteralPath $origin -Raw).Trim()).Equals($devRoot, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($matches.Count -ne 1) { throw "Expected exactly one QMDev1 DEV1 profile, found $($matches.Count)." }
    return Join-Path $matches[0].FullName 'MQL5\Include'
}

function Get-RepoIncludeSnapshot {
    $snapshot = [ordered]@{}
    foreach ($file in @(Get-ChildItem -LiteralPath $repoInclude -File -Recurse | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($repoInclude.Length).TrimStart('\')
        $snapshot[$relative] = [ordered]@{
            bytes = [long]$file.Length
            sha256 = Get-Sha256 -Path $file.FullName
        }
    }
    if ($snapshot.Count -le 0) { throw 'Repository include snapshot is empty.' }
    return $snapshot
}

function Export-IncludeManifest([string[]]$Targets, [System.Collections.IDictionary]$Snapshot, [string]$Path) {
    $current = Get-RepoIncludeSnapshot
    if ($current.Count -ne $Snapshot.Count) { throw 'Repository include file count changed during compile.' }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($relative in $Snapshot.Keys) {
        if (-not $current.Contains($relative) -or
            $current[$relative].bytes -ne $Snapshot[$relative].bytes -or
            $current[$relative].sha256 -cne $Snapshot[$relative].sha256) {
            throw "Repository include changed during compile: $relative"
        }
        foreach ($target in $Targets) {
            $destination = Join-Path $target $relative
            if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
                throw "Synced include missing: $destination"
            }
            $destinationItem = Get-Item -LiteralPath $destination
            $destinationHash = Get-Sha256 -Path $destination
            if ($destinationItem.Length -ne $Snapshot[$relative].bytes -or
                $destinationHash -cne $Snapshot[$relative].sha256) {
                throw "Synced include mismatch: $destination"
            }
            $rows.Add([pscustomobject]@{
                target_include_root = [IO.Path]::GetFullPath($target)
                relative_path = $relative
                bytes = $Snapshot[$relative].bytes
                source_sha256 = $Snapshot[$relative].sha256
                destination_sha256 = $destinationHash
            })
        }
    }
    $rows.ToArray() | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding utf8
    return $rows.Count
}

function Export-IncludePathAudit([string]$CompileLog, [string[]]$AllowedRoots, [string]$StageRoot, [string]$Path) {
    $text = Get-Content -LiteralPath $CompileLog -Raw
    $matches = [regex]::Matches($text, '(?im):\s*information:\s*including\s+(?<path>[^\r\n]+)')
    $seen = [ordered]@{}
    foreach ($match in $matches) {
        $included = [IO.Path]::GetFullPath($match.Groups['path'].Value.Trim())
        if (-not $seen.Contains($included)) {
            $allowed = Test-UnderRoot -Path $included -Root $StageRoot
            if (-not $allowed) {
                foreach ($root in $AllowedRoots) {
                    if (Test-UnderRoot -Path $included -Root $root) { $allowed = $true; break }
                }
            }
            $seen[$included] = $allowed
        }
    }
    if ($seen.Count -le 0) { throw 'Compile log did not disclose any included path.' }
    $rows = foreach ($included in $seen.Keys) {
        [pscustomobject]@{ included_path = $included; allowed = [bool]$seen[$included] }
    }
    $rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding utf8
    $outside = @($rows | Where-Object { -not $_.allowed }).Count
    if ($outside -ne 0) { throw "Compile used $outside include path(s) outside the isolated roots." }
    return [ordered]@{ count = @($rows).Count; outside = $outside }
}

function Invoke-CompileChild {
    if ([string]::IsNullOrWhiteSpace($RunRoot) -or [string]::IsNullOrWhiteSpace($ExpectedSid) -or
        [string]::IsNullOrWhiteSpace($ExpectedSourceSha256)) { throw 'Child invocation omitted a binding.' }
    $childRunRoot = [IO.Path]::GetFullPath($RunRoot)
    if (-not (Test-UnderRoot -Path $childRunRoot -Root $reportsRoot)) { throw 'Child RunRoot escaped reports root.' }
    $stageRoot = Join-Path $childRunRoot 'stage'
    $stageMq5 = Join-Path $stageRoot 'QM5_20002_ict-icytea-core.mq5'
    $stageEx5 = [IO.Path]::ChangeExtension($stageMq5, '.ex5')
    $resultPath = Join-Path $childRunRoot 'child_result.json'
    $childLog = Join-Path $childRunRoot 'compile_child.log'
    $includeManifest = Join-Path $childRunRoot 'include_sync_manifest.csv'
    $includeAudit = Join-Path $childRunRoot 'include_path_audit.csv'
    $started = (Get-Date).ToUniversalTime()
    $success = $false
    $failure = $null
    $errors = -1
    $warnings = -1
    $metaExit = -1
    $compileLog = $null
    $includeTargets = @()
    $includeRows = 0
    $includedPaths = 0
    $outsidePaths = -1
    try {
        foreach ($path in @($childRunRoot, $stageRoot, $stageMq5, $repoInclude, $compileOne, $metaEditor, $pwsh)) {
            Assert-PhysicalPath -Path $path
        }
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        if ($identity.User.Value -ne $ExpectedSid) { throw "Wrong child SID: $($identity.User.Value)" }
        $expectedAccount = "$env:COMPUTERNAME\QMDev1"
        if (-not $identity.Name.Equals($expectedAccount, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Wrong child account: $($identity.Name)"
        }
        if (-not ([IO.Path]::GetFullPath($env:USERPROFILE)).Equals('C:\Users\QMDev1', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Wrong QMDev1 profile.'
        }
        if ((Get-Sha256 -Path $stageMq5) -cne $ExpectedSourceSha256.ToLowerInvariant()) {
            throw 'Staged source SHA-256 drift.'
        }
        if (@(Get-Dev1Processes).Count -ne 0) { throw 'DEV1 was not idle in child preflight.' }

        foreach ($name in @([Environment]::GetEnvironmentVariables('Process').Keys)) {
            if ([string]$name -match '(?i)(TOKEN|SECRET|PASSWORD|API[_-]?KEY|CREDENTIAL)') {
                Remove-Item -LiteralPath ("Env:\{0}" -f [string]$name) -ErrorAction SilentlyContinue
            }
        }

        $profileInclude = Resolve-Dev1ProfileInclude
        $portableInclude = Join-Path $devRoot 'MQL5\Include'
        foreach ($target in @($profileInclude, $portableInclude)) { Assert-PhysicalPath -Path $target }
        $expectedTargets = @([IO.Path]::GetFullPath($profileInclude), [IO.Path]::GetFullPath($portableInclude)) | Sort-Object -Unique
        $includeSnapshot = Get-RepoIncludeSnapshot

        $buildRoot = Join-Path $childRunRoot 'compile_one_build'
        $reportRoot = Join-Path $childRunRoot 'compile_one_report'
        $output = @(& $pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $compileOne `
            -EAPath $stageMq5 -Strict -MetaEditorPath $metaEditor -BuildRoot $buildRoot -ReportRoot $reportRoot 2>&1)
        $compileExit = $LASTEXITCODE
        $output | ForEach-Object { [string]$_ } | Set-Content -LiteralPath $childLog -Encoding utf8
        $values = @{}
        foreach ($line in $output) {
            $textLine = [string]$line
            if ($textLine -match '^compile_one\.(?<key>[^=]+)=(?<value>.*)$') { $values[$Matches.key] = $Matches.value }
        }
        foreach ($requiredKey in @('result', 'reason_class', 'errors', 'warnings', 'metaeditor_exit_code',
                'include_sync_targets', 'log')) {
            if (-not $values.ContainsKey($requiredKey)) { throw "compile_one omitted output key: $requiredKey" }
        }
        if ($compileExit -ne 0 -or $values['result'] -ne 'PASS') {
            throw "compile_one failed: exit=$compileExit result=$($values['result']) reason=$($values['reason_class'])"
        }
        $errors = [int]$values['errors']
        $warnings = [int]$values['warnings']
        $metaExit = [int]$values['metaeditor_exit_code']
        if ($errors -ne 0 -or $warnings -ne 0) { throw "Strict compile failed: errors=$errors warnings=$warnings" }
        $compileLog = [IO.Path]::GetFullPath([string]$values['log'])
        if (-not (Test-Path -LiteralPath $compileLog -PathType Leaf)) { throw 'compile_one log missing.' }
        if (-not (Test-Path -LiteralPath $stageEx5 -PathType Leaf) -or (Get-Item $stageEx5).Length -le 0) {
            throw 'compile_one produced no non-empty staged EX5.'
        }
        if ((Get-Item $stageEx5).LastWriteTimeUtc -lt $started.AddSeconds(-2)) { throw 'Staged EX5 predates compile.' }

        $reportedTargets = @(([string]$values['include_sync_targets']).Split(';', [StringSplitOptions]::RemoveEmptyEntries) |
            ForEach-Object { [IO.Path]::GetFullPath($_) } | Sort-Object -Unique)
        if (($reportedTargets -join '|') -cne ($expectedTargets -join '|')) {
            throw "compile_one include targets escaped DEV1: $($reportedTargets -join ';')"
        }
        $includeTargets = $reportedTargets
        $includeRows = Export-IncludeManifest -Targets $includeTargets -Snapshot $includeSnapshot -Path $includeManifest
        $audit = Export-IncludePathAudit -CompileLog $compileLog -AllowedRoots $includeTargets -StageRoot $stageRoot -Path $includeAudit
        $includedPaths = [int]$audit.count
        $outsidePaths = [int]$audit.outside
        if (@(Get-Dev1Processes).Count -ne 0) { throw 'DEV1 process remained after compile.' }
        $success = $true
    } catch {
        $failure = $_.Exception.Message
        try { Add-Content -LiteralPath $childLog -Value "failure=$failure" -Encoding utf8 } catch { }
    } finally {
        foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $_.ExecutablePath -and ([IO.Path]::GetFullPath([string]$_.ExecutablePath)).Equals(
                ([IO.Path]::GetFullPath($metaEditor)), [StringComparison]::OrdinalIgnoreCase)
        })) {
            try { Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction Stop } catch { }
        }
        $result = [ordered]@{
            success = $success
            failure = $failure
            run_root = $childRunRoot
            identity_sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            metaeditor_path = $metaEditor
            metaeditor_sha256 = if (Test-Path $metaEditor) { Get-Sha256 $metaEditor } else { $null }
            metaeditor_exit_code = $metaExit
            errors = $errors
            warnings = $warnings
            source_mq5_sha256 = if (Test-Path $stageMq5) { Get-Sha256 $stageMq5 } else { $null }
            ex5_path = $stageEx5
            ex5_size_bytes = if (Test-Path $stageEx5) { (Get-Item $stageEx5).Length } else { 0 }
            ex5_sha256 = if (Test-Path $stageEx5) { Get-Sha256 $stageEx5 } else { $null }
            compile_log_path = $compileLog
            include_manifest_path = $includeManifest
            include_manifest_rows = $includeRows
            include_path_audit_path = $includeAudit
            included_paths_count = $includedPaths
            outside_include_paths_count = $outsidePaths
            include_sync_targets = $includeTargets
            started_utc = $started.ToString('o')
            finished_utc = (Get-Date).ToUniversalTime().ToString('o')
        }
        Write-AtomicJson -Path $resultPath -Value $result
    }
    if (-not $success) { exit 1 }
    exit 0
}

function Invoke-CompileController {
    $sourceHash = Get-Sha256 -Path $source
    if ($sourceHash -cne $frozenSourceSha256) { throw "Frozen source drift: $sourceHash" }
    $contractPath = Join-Path $eaRoot 'docs\candidate-analysis\short_ny_reverse_time_contract.json'
    if ((Get-Sha256 $contractPath) -cne $expectedContractSha256) { throw 'Contract-v3 SHA-256 drift.' }
    & git -C $repoRoot cat-file -e "$expectedSourceCommit`:framework/EAs/QM5_20002_ict-icytea-core/QM5_20002_ict-icytea-core.mq5" 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve frozen source blob.' }
    $head = (& git -C $repoRoot rev-parse HEAD).Trim()
    & git -C $repoRoot merge-base --is-ancestor $expectedContractCommit $head
    if ($LASTEXITCODE -ne 0) { throw 'Contract commit is not an ancestor of HEAD.' }
    & git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $head
    if ($LASTEXITCODE -ne 0) { throw 'Source commit is not an ancestor of HEAD.' }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Compile controller must be elevated.'
    }
    foreach ($path in @($source, $contractPath, $repoInclude, $compileOne, $metaEditor, $pwsh, $credentialPath, $reportsRoot)) {
        Assert-PhysicalPath -Path $path
    }
    Assert-PhysicalPath -Path $controllerScript
    $controllerScriptHash = Get-Sha256 $controllerScript
    $compileOneHash = Get-Sha256 $compileOne
    $metaEditorHash = Get-Sha256 $metaEditor
    if (@(Get-EphemeralCompileTasks).Count -ne 0) { throw 'A prior QM20002 compile task still exists.' }

    if ((Get-Service MpsSvc).Status -ne 'Running') { throw 'Firewall service is not running.' }
    if (@(Get-NetFirewallProfile -PolicyStore ActiveStore | Where-Object { -not $_.Enabled }).Count -ne 0) {
        throw 'A firewall profile is disabled.'
    }
    $firewall = [ordered]@{
        'QM_DEV1_BLOCK_TERMINAL_OUT' = Join-Path $devRoot 'terminal64.exe'
        'QM_DEV1_BLOCK_METATESTER_OUT' = Join-Path $devRoot 'metatester64.exe'
        'QM_DEV1_BLOCK_METAEDITOR_OUT' = $metaEditor
    }
    foreach ($entry in $firewall.GetEnumerator()) {
        $rules = @(Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName $entry.Key)
        if ($rules.Count -ne 1) { throw "Firewall rule count drift: $($entry.Key)" }
        $rule = $rules[0]
        $filter = @(Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule)
        if ($rule.Enabled.ToString() -ne 'True' -or $rule.Direction.ToString() -ne 'Outbound' -or
            $rule.Action.ToString() -ne 'Block' -or $rule.Profile.ToString() -ne 'Any' -or
            $filter.Count -ne 1 -or -not ([IO.Path]::GetFullPath($filter[0].Program)).Equals(
                ([IO.Path]::GetFullPath($entry.Value)), [StringComparison]::OrdinalIgnoreCase)) {
            throw "Firewall rule drift: $($entry.Key)"
        }
    }

    $mutex = [Threading.Mutex]::new($false, 'Global\QM_DEV1_SMOKE_CONTROLLER')
    $mutexAcquired = $false
    $taskRegistered = $false
    $taskName = $taskPrefix + [guid]::NewGuid().ToString('N')
    $preexistingBackup = $null
    $delivered = $false
    $complete = $false
    $plain = $null
    $credential = $null
    $runId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ_') + [guid]::NewGuid().ToString('N')
    $controllerRunRoot = Join-Path $reportsRoot $runId
    $stageRoot = Join-Path $controllerRunRoot 'stage'
    $stageMq5 = Join-Path $stageRoot 'QM5_20002_ict-icytea-core.mq5'
    $stageEx5 = [IO.Path]::ChangeExtension($stageMq5, '.ex5')
    $sourceManifest = Join-Path $controllerRunRoot 'source_manifest.csv'
    $resultPath = Join-Path $controllerRunRoot 'child_result.json'
    $evidencePath = Join-Path $controllerRunRoot 'evidence.json'
    try {
        $mutexDeadline = (Get-Date).ToUniversalTime().AddMinutes(30)
        $nextWaitNotice = [datetime]::MinValue
        while (-not $mutexAcquired -and (Get-Date).ToUniversalTime() -lt $mutexDeadline) {
            try { $mutexAcquired = $mutex.WaitOne(2000) } catch [Threading.AbandonedMutexException] { $mutexAcquired = $true }
            $now = (Get-Date).ToUniversalTime()
            if (-not $mutexAcquired -and $now -ge $nextWaitNotice) {
                Write-Output "compile_controller.waiting_for_dev1_mutex=$($now.ToString('o'))"
                $nextWaitNotice = $now.AddSeconds(30)
            }
        }
        if (-not $mutexAcquired) { throw 'Timed out waiting for the DEV1 smoke/compile mutex.' }

        $settleDeadline = (Get-Date).ToUniversalTime().AddSeconds(30)
        while (@(Get-Dev1Processes).Count -ne 0 -and (Get-Date).ToUniversalTime() -lt $settleDeadline) {
            Start-Sleep -Milliseconds 250
        }
        if (@(Get-Dev1Processes).Count -ne 0) { throw 'DEV1 remained busy after acquiring its controller mutex.' }

        New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
        Assert-PhysicalPath -Path $controllerRunRoot
        Copy-Item -LiteralPath $source -Destination $stageMq5 -Force
        if ((Get-Sha256 $stageMq5) -cne $sourceHash) { throw 'Staged source hash mismatch.' }
        @([pscustomobject]@{
            relative_path = 'QM5_20002_ict-icytea-core.mq5'
            bytes = (Get-Item $source).Length
            sha256 = $sourceHash
        }) | Export-Csv -LiteralPath $sourceManifest -NoTypeInformation -Encoding utf8

        $preexisting = Test-Path -LiteralPath $repoEx5 -PathType Leaf
        $preexistingHash = $null
        if ($preexisting) {
            $preexistingHash = Get-Sha256 $repoEx5
            $preexistingBackup = Join-Path $controllerRunRoot 'preexisting_repo_target.ex5'
            Copy-Item -LiteralPath $repoEx5 -Destination $preexistingBackup -Force
            Remove-Item -LiteralPath $repoEx5 -Force
        }

        $user = Get-LocalUser QMDev1
        if (-not $user.Enabled -or -not $user.PasswordRequired) { throw 'QMDev1 account gate failed.' }
        $sid = $user.SID.Value
        $account = "$env:COMPUTERNAME\QMDev1"
        $credential = Import-Clixml -LiteralPath $credentialPath
        if ($credential -isnot [Management.Automation.PSCredential]) { throw 'Invalid DEV1 credential type.' }
        $credentialName = $credential.UserName
        if ($credentialName.StartsWith('.\')) { $credentialName = "$env:COMPUTERNAME\$($credentialName.Substring(2))" }
        if (([Security.Principal.NTAccount]$credentialName).Translate([Security.Principal.SecurityIdentifier]).Value -ne $sid) {
            throw 'DEV1 credential SID mismatch.'
        }
        $plain = $credential.GetNetworkCredential().Password
        if ([string]::IsNullOrEmpty($plain)) { throw 'DEV1 task password is empty.' }

        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Child -RunRoot "{1}" -ExpectedSid "{2}" -ExpectedSourceSha256 "{3}"' -f
            $controllerScript, $controllerRunRoot, $sid, $sourceHash
        $action = New-ScheduledTaskAction -Execute $pwsh -Argument $arguments -WorkingDirectory $controllerRunRoot
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden `
            -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $taskName -TaskPath '\' -Action $action -Settings $settings `
            -User $account -Password $plain -RunLevel Limited -Description "Ephemeral isolated QM20002 Contract-v3 compile" | Out-Null
        $taskRegistered = $true
        $plain = $null
        $credential = $null
        $task = Get-ScheduledTask -TaskName $taskName -TaskPath '\'
        if ($task.Principal.LogonType.ToString() -ne 'Password' -or
            $task.Principal.RunLevel.ToString() -ne 'Limited' -or $null -ne $task.Triggers -or
            @($task.Actions).Count -ne 1 -or
            -not ([IO.Path]::GetFullPath([string]$task.Actions[0].Execute)).Equals(
                ([IO.Path]::GetFullPath($pwsh)), [StringComparison]::OrdinalIgnoreCase) -or
            [string]$task.Actions[0].Arguments -cne $arguments -or
            -not ([IO.Path]::GetFullPath([string]$task.Actions[0].WorkingDirectory)).Equals(
                ([IO.Path]::GetFullPath($controllerRunRoot)), [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Scheduled task isolation contract drift.'
        }
        if (@(Get-Dev1Processes).Count -ne 0) { throw 'DEV1 became busy before compile start.' }
        Start-ScheduledTask -TaskName $taskName -TaskPath '\'

        $deadline = (Get-Date).ToUniversalTime().AddMinutes(4)
        while ((Get-Date).ToUniversalTime() -lt $deadline -and -not (Test-Path -LiteralPath $resultPath)) {
            Start-Sleep -Seconds 1
        }
        if (-not (Test-Path -LiteralPath $resultPath)) { throw 'Isolated compile timed out.' }
        $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
        if (-not $result.success -or [int]$result.errors -ne 0 -or [int]$result.warnings -ne 0) {
            throw "Compile child failed: $($result.failure); errors=$($result.errors); warnings=$($result.warnings)"
        }
        if ([string]$result.source_mq5_sha256 -cne $sourceHash -or
            -not (Test-Path -LiteralPath $stageEx5 -PathType Leaf) -or (Get-Item $stageEx5).Length -le 0) {
            throw 'Compile child result does not bind the staged source/EX5.'
        }
        $stageHash = Get-Sha256 $stageEx5
        if ($stageHash -cne [string]$result.ex5_sha256) { throw 'Child EX5 SHA-256 mismatch.' }
        if ((Get-Sha256 $source) -cne $sourceHash) { throw 'Repository source changed during compile.' }
        if ((Get-Sha256 $controllerScript) -cne $controllerScriptHash) { throw 'Compile controller changed during compile.' }
        if ((Get-Sha256 $compileOne) -cne $compileOneHash) { throw 'compile_one changed during compile.' }
        if ((Get-Sha256 $metaEditor) -cne $metaEditorHash) { throw 'MetaEditor changed during compile.' }

        $waitExit = (Get-Date).ToUniversalTime().AddSeconds(30)
        while ((Get-Date).ToUniversalTime() -lt $waitExit -and
            (Get-ScheduledTask -TaskName $taskName -TaskPath '\').State -eq 'Running') { Start-Sleep -Milliseconds 250 }
        if ((Get-ScheduledTask -TaskName $taskName -TaskPath '\').State -eq 'Running') { throw 'Compile task did not exit cleanly.' }
        Unregister-ScheduledTask -TaskName $taskName -TaskPath '\' -Confirm:$false
        $taskRegistered = $false
        Start-Sleep -Milliseconds 500
        $activeAfter = @(Get-Dev1Processes).Count
        $tasksAfter = @(Get-EphemeralCompileTasks).Count
        if ($activeAfter -ne 0 -or $tasksAfter -ne 0) { throw "Compile cleanup incomplete: processes=$activeAfter tasks=$tasksAfter" }

        $tempTarget = "$repoEx5.$([guid]::NewGuid().ToString('N')).tmp"
        Copy-Item -LiteralPath $stageEx5 -Destination $tempTarget -Force
        if ((Get-Sha256 $tempTarget) -cne $stageHash) { Remove-Item $tempTarget -Force; throw 'EX5 delivery temp mismatch.' }
        Move-Item -LiteralPath $tempTarget -Destination $repoEx5 -Force
        if ((Get-Sha256 $repoEx5) -cne $stageHash) { throw 'Repository EX5 delivery mismatch.' }
        $delivered = $true

        $compileLog = [IO.Path]::GetFullPath([string]$result.compile_log_path)
        $includeManifest = [IO.Path]::GetFullPath([string]$result.include_manifest_path)
        $includeAudit = [IO.Path]::GetFullPath([string]$result.include_path_audit_path)
        $evidence = [ordered]@{
            result = 'PASS'
            research_status = $researchStatus
            run_id = $runId
            run_root = $controllerRunRoot
            task_user = $account
            task_logon_type = 'Password'
            task_run_level = 'Limited'
            contract_commit = $expectedContractCommit
            contract_sha256 = $expectedContractSha256
            source_git_commit = $expectedSourceCommit
            source_path = $source
            source_bytes = (Get-Item $source).Length
            source_sha256 = $sourceHash
            metaeditor_path = $metaEditor
            metaeditor_sha256 = $metaEditorHash
            compile_one_path = $compileOne
            compile_one_sha256 = $compileOneHash
            compile_controller_path = $controllerScript
            compile_controller_sha256 = $controllerScriptHash
            compile_log_path = $compileLog
            compile_log_sha256 = Get-Sha256 $compileLog
            errors = [int]$result.errors
            warnings = [int]$result.warnings
            include_manifest_path = $includeManifest
            include_manifest_rows = [int]$result.include_manifest_rows
            include_sync_manifest_sha256 = Get-Sha256 $includeManifest
            include_path_audit_path = $includeAudit
            include_path_audit_sha256 = Get-Sha256 $includeAudit
            included_paths_count = [int]$result.included_paths_count
            outside_include_paths_count = [int]$result.outside_include_paths_count
            source_manifest_sha256 = Get-Sha256 $sourceManifest
            stage_ex5_path = $stageEx5
            repo_ex5_path = $repoEx5
            ex5_size_bytes = (Get-Item $repoEx5).Length
            ex5_sha256 = $stageHash
            preexisting_repo_ex5 = $preexisting
            preexisting_repo_ex5_sha256 = $preexistingHash
            active_dev1_processes_after = $activeAfter
            ephemeral_tasks_after = $tasksAfter
            git_head_after = $head
            finished_utc = (Get-Date).ToUniversalTime().ToString('o')
        }
        Write-AtomicJson -Path $evidencePath -Value $evidence
        $complete = $true
        $evidence | ConvertTo-Json -Compress
    } catch {
        $_.Exception.Message | Set-Content -LiteralPath (Join-Path $controllerRunRoot 'controller_error.txt') -Encoding utf8 -ErrorAction SilentlyContinue
        throw
    } finally {
        $plain = $null
        $credential = $null
        if ($taskRegistered) {
            try { Stop-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue } catch { }
            try { Unregister-ScheduledTask -TaskName $taskName -TaskPath '\' -Confirm:$false -ErrorAction Stop } catch { }
        }
        if ($mutexAcquired) {
            foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
                $_.ExecutablePath -and ([IO.Path]::GetFullPath([string]$_.ExecutablePath)).Equals(
                    ([IO.Path]::GetFullPath($metaEditor)), [StringComparison]::OrdinalIgnoreCase)
            })) {
                try { Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction Stop } catch { }
            }
        }
        if (-not $complete) {
            if ($delivered -and (Test-Path -LiteralPath $repoEx5 -PathType Leaf)) {
                try { Remove-Item -LiteralPath $repoEx5 -Force } catch { }
            }
            if ($preexistingBackup -and (Test-Path -LiteralPath $preexistingBackup -PathType Leaf)) {
                try { Copy-Item -LiteralPath $preexistingBackup -Destination $repoEx5 -Force } catch { }
            }
        }
        if ($mutexAcquired) { try { $mutex.ReleaseMutex() } catch { } }
        $mutex.Dispose()
    }
}

if ($Child.IsPresent) {
    Invoke-CompileChild
} else {
    Invoke-CompileController
}
