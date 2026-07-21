[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RunDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Dev2Root = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV2')
$script:ReportsRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev2')
$script:PwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
$script:LaneContractPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\registry\dev2_lane_contract.json'))
$script:CredentialPath = [System.IO.Path]::GetFullPath('C:\ProgramData\QM\DEV2\credential.machine-dpapi.json')
$script:CredentialHelperPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'dev2_machine_credential.ps1'))
$script:ControllerMutexName = 'Global\QM_DEV2_SMOKE_CONTROLLER'
$script:TaskNamePrefix = 'QM_DEV2_SMOKE_'
$script:PerAttemptOverheadSeconds = 600
$script:ControllerFinalizationMarginSeconds = 600
$script:AllowedSymbols = @('NDX.DWX', 'GDAXI.DWX', 'EURUSD.DWX', 'GBPUSD.DWX', 'USDJPY.DWX', 'XAUUSD.DWX')
$script:AllowedParameterOrder = @(
    'EAId', 'EALabel', 'Symbol', 'Year', 'FromDate', 'ToDate', 'Expert', 'Period', 'Runs',
    'MinTrades', 'Model', 'TimeoutSeconds', 'SetFile', 'AllowMissingRealTicksLogMarker',
    'CommissionPerLot', 'CommissionPerSideNative', 'TesterCurrencyOverride', 'TesterDepositOverride', 'SmokeMode'
)
$script:SwitchParameters = @('AllowMissingRealTicksLogMarker', 'SmokeMode')

function ConvertTo-QmFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path.IndexOfAny([char[]]"`r`n`0") -ge 0) { throw 'Path contains CR, LF, or NUL.' }
    return [System.IO.Path]::GetFullPath($Path)
}

function Get-QmMinimumDev2ControllerTimeoutSeconds {
    param(
        [Parameter(Mandatory = $true)][ValidateRange(1, 10)][int]$MaximumRunAttempts,
        [Parameter(Mandatory = $true)][ValidateRange(60, 28800)][int]$RunTimeoutSeconds
    )
    return ($MaximumRunAttempts * ($RunTimeoutSeconds + $script:PerAttemptOverheadSeconds)) +
        $script:ControllerFinalizationMarginSeconds
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

function Assert-QmNoDev2Processes {
    $running = @(
        Get-CimInstance -ClassName Win32_Process -Property ProcessId,ExecutablePath,CreationDate -ErrorAction Stop | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.ExecutablePath) -and
            (Test-QmPathWithin -Path ([string]$_.ExecutablePath) -Root $script:Dev2Root)
        }
    )
    if ($running.Count -gt 0) {
        throw "DEV2 is not idle inside the task preflight; exact-path process count=$($running.Count)."
    }
}

function Get-QmProcessOwnerSid {
    param([Parameter(Mandatory = $true)][object]$ProcessRecord)
    try {
        $owner = Invoke-CimMethod -InputObject $ProcessRecord -MethodName GetOwnerSid -ErrorAction Stop
    } catch [Microsoft.Management.Infrastructure.CimException] {
        if ($_.Exception.NativeErrorCode -eq [Microsoft.Management.Infrastructure.NativeErrorCode]::NotFound) {
            return $null
        }
        throw
    }
    if ([int]$owner.ReturnValue -ne 0 -or [string]::IsNullOrWhiteSpace([string]$owner.Sid)) {
        throw "Process owner SID lookup returned an unreadable result (pid=$($ProcessRecord.ProcessId))."
    }
    return [string]$owner.Sid
}

function Get-QmLiveProcessById {
    param([Parameter(Mandatory = $true)][int]$ProcessId)
    try {
        $matches = @(
            Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $ProcessId" `
                -Property ProcessId,ExecutablePath,CreationDate -ErrorAction Stop
        )
    } catch [Microsoft.Management.Infrastructure.CimException] {
        if ($_.Exception.NativeErrorCode -eq [Microsoft.Management.Infrastructure.NativeErrorCode]::NotFound) {
            return $null
        }
        throw
    }
    if ($matches.Count -eq 0) { return $null }
    if ($matches.Count -ne 1) {
        throw "Exact PID lookup returned a non-unique process record (pid=$ProcessId)."
    }
    return $matches[0]
}

function Test-QmSameProcessGeneration {
    param(
        [Parameter(Mandatory = $true)][object]$Left,
        [Parameter(Mandatory = $true)][object]$Right
    )
    if ([int]$Left.ProcessId -ne [int]$Right.ProcessId) { return $false }
    $leftPath = ConvertTo-QmFullPath -Path ([string]$Left.ExecutablePath)
    $rightPath = ConvertTo-QmFullPath -Path ([string]$Right.ExecutablePath)
    $leftCreationUtc = ([DateTimeOffset]$Left.CreationDate).ToUniversalTime()
    $rightCreationUtc = ([DateTimeOffset]$Right.CreationDate).ToUniversalTime()
    return (
        $leftPath.Equals($rightPath, [System.StringComparison]::OrdinalIgnoreCase) -and
        $leftCreationUtc.UtcTicks -eq $rightCreationUtc.UtcTicks
    )
}

function Assert-QmLaneContract {
    param([Parameter(Mandatory = $true)][System.Collections.IDictionary]$Contract)
    $expectedSymbols = @($script:AllowedSymbols | Sort-Object)
    $actualSymbols = @($Contract.allowed_symbols | ForEach-Object { [string]$_ } | Sort-Object)
    if ([int]$Contract.schema_version -ne 3 -or [string]$Contract.contract_id -cne 'QM_DEV2_ISOLATED_MT5_LANE_V3' -or
        [string]$Contract.lane -cne 'DEV2' -or [string]$Contract.source_lane -cne 'DEV1' -or
        [string]$Contract.identity.local_user -cne 'QMDev2' -or
        [string]$Contract.identity.credential_format -cne 'QM_DEV2_MACHINE_DPAPI_CREDENTIAL' -or
        [string]$Contract.identity.dpapi_scope -cne 'LocalMachine' -or
        -not [bool]$Contract.identity.credential_acl.inheritance_protected -or
        [string]$Contract.identity.credential_acl.owner_sid -cne 'S-1-5-32-544' -or
        [bool]$Contract.identity.credential_acl.additional_readers -or
        [string]::Join('|', @($Contract.identity.credential_acl.exact_full_control_sids | ForEach-Object { [string]$_ } | Sort-Object)) -cne 'S-1-5-18|S-1-5-32-544' -or
        -not (ConvertTo-QmFullPath -Path ([string]$Contract.identity.credential)).Equals($script:CredentialPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (ConvertTo-QmFullPath -Path ([string]$Contract.paths.terminal_root)).Equals($script:Dev2Root, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (ConvertTo-QmFullPath -Path ([string]$Contract.paths.report_root)).Equals($script:ReportsRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]$Contract.coordination.controller_mutex -cne $script:ControllerMutexName -or
        [string]$Contract.coordination.task_prefix -cne $script:TaskNamePrefix -or
        [string]::Join('|', $actualSymbols) -cne [string]::Join('|', $expectedSymbols)) {
        throw 'DEV2 lane contract drifted from the fixed child isolation contract.'
    }
    $port = $Contract.agent_port_contract
    if ([bool]$port.source_agents_dat_copied -or -not [bool]$port.require_runtime_listener_proof -or
        -not [bool]$port.require_exact_dev2_metatester_path -or
        -not [bool]$port.require_no_concurrent_overlapping_endpoint_owner -or
        -not [bool]$port.allow_released_baseline_endpoint_reuse -or
        [int]$port.minimum_port -lt 1 -or [int]$port.maximum_port -gt 65535 -or
        [int]$port.minimum_port -gt [int]$port.maximum_port) {
        throw 'DEV2 lane contract has an unsafe agent-port policy.'
    }
}

function Get-QmVerifiedProgramHashes {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$ExpectedHashes,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Contract
    )
    $expectedNames = @('MetaEditor64.exe', 'metatester64.exe', 'terminal64.exe')
    $requestNames = @($ExpectedHashes.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $contractHashes = [System.Collections.IDictionary]$Contract.program_sha256
    $contractNames = @($contractHashes.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $sortedExpectedNames = @($expectedNames | Sort-Object)
    if ([string]::Join('|', $requestNames) -cne [string]::Join('|', $sortedExpectedNames) -or
        [string]::Join('|', $contractNames) -cne [string]::Join('|', $sortedExpectedNames)) {
        throw 'DEV2 request/contract program hash set is not exact.'
    }
    $actualHashes = [ordered]@{}
    foreach ($name in $expectedNames) {
        $requested = ([string]$ExpectedHashes[$name]).ToLowerInvariant()
        $contracted = ([string]$contractHashes[$name]).ToLowerInvariant()
        if ($requested -notmatch '^[0-9a-f]{64}$' -or $requested -cne $contracted) {
            throw "DEV2 request/contract program hash mismatch for $name."
        }
        $programPath = ConvertTo-QmFullPath -Path (Join-Path $script:Dev2Root $name)
        Assert-QmNoReparseComponents -Path $programPath
        $actual = (Get-FileHash -LiteralPath $programPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        if ($actual -cne $requested) {
            throw "DEV2 program hash mismatch for $name; expected=$requested actual=$actual"
        }
        $actualHashes[$name] = $actual
    }
    return $actualHashes
}

function Get-QmListenerBaseline {
    $baseline = @{}
    foreach ($listener in @(Get-NetTCPConnection -State Listen -ErrorAction Stop)) {
        $portKey = ([int]$listener.LocalPort).ToString([System.Globalization.CultureInfo]::InvariantCulture)
        if (-not $baseline.ContainsKey($portKey)) {
            $baseline[$portKey] = New-Object System.Collections.Generic.List[object]
        }
        $baseline[$portKey].Add([pscustomobject]@{
            local_address = [string]$listener.LocalAddress
            owning_process = [int]$listener.OwningProcess
        })
    }
    return $baseline
}

function Test-QmListenerAddressesOverlap {
    param(
        [Parameter(Mandatory = $true)][string]$Left,
        [Parameter(Mandatory = $true)][string]$Right
    )
    try {
        $leftAddress = [System.Net.IPAddress]::Parse($Left)
        $rightAddress = [System.Net.IPAddress]::Parse($Right)
    } catch {
        throw 'Listener proof contains an invalid local IP address.'
    }
    if ($leftAddress.IsIPv4MappedToIPv6) { $leftAddress = $leftAddress.MapToIPv4() }
    if ($rightAddress.IsIPv4MappedToIPv6) { $rightAddress = $rightAddress.MapToIPv4() }
    if ($leftAddress.Equals($rightAddress)) { return $true }
    if ($leftAddress.Equals([System.Net.IPAddress]::Any) -or
        $leftAddress.Equals([System.Net.IPAddress]::IPv6Any) -or
        $rightAddress.Equals([System.Net.IPAddress]::Any) -or
        $rightAddress.Equals([System.Net.IPAddress]::IPv6Any)) { return $true }
    return $false
}

function Update-QmDev2AgentListenerProof {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Baseline,
        [Parameter(Mandatory = $true)][hashtable]$Seen,
        [Parameter(Mandatory = $true)][string]$ExpectedOwnerSid,
        [Parameter(Mandatory = $true)][DateTimeOffset]$EarliestCreationUtc,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$PortContract
    )
    $expectedPath = ConvertTo-QmFullPath -Path (Join-Path $script:Dev2Root 'metatester64.exe')
    foreach ($process in @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'metatester64.exe'" -Property ProcessId,ExecutablePath,CreationDate -ErrorAction Stop)) {
        if ([string]::IsNullOrWhiteSpace([string]$process.ExecutablePath)) { continue }
        $actualPath = ConvertTo-QmFullPath -Path ([string]$process.ExecutablePath)
        if (-not $actualPath.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $creationUtc = ([DateTimeOffset]$process.CreationDate).ToUniversalTime()
        if ($creationUtc -lt $EarliestCreationUtc.AddSeconds(-2)) {
            throw "Exact-path DEV2 metatester predates this child runner (pid=$($process.ProcessId))."
        }
        $liveProcess = Get-QmLiveProcessById -ProcessId ([int]$process.ProcessId)
        if ($null -eq $liveProcess -or -not (Test-QmSameProcessGeneration -Left $process -Right $liveProcess)) {
            continue
        }
        $ownerSid = Get-QmProcessOwnerSid -ProcessRecord $liveProcess
        if ($null -eq $ownerSid) {
            # Win32_Process disappeared between the generation recheck and GetOwnerSid.
            continue
        }
        if ($ownerSid -cne $ExpectedOwnerSid) {
            throw "Exact-path DEV2 metatester has wrong owner SID (pid=$($process.ProcessId))."
        }
        $confirmedProcess = Get-QmLiveProcessById -ProcessId ([int]$process.ProcessId)
        if ($null -eq $confirmedProcess -or
            -not (Test-QmSameProcessGeneration -Left $liveProcess -Right $confirmedProcess)) {
            continue
        }
        $process = $confirmedProcess
        # Take one coherent listener snapshot, then prove that the same process
        # generation still brackets it before evaluating or publishing any row.
        $listenerSnapshot = @(Get-NetTCPConnection -State Listen -ErrorAction Stop)
        $processListeners = @(
            $listenerSnapshot | Where-Object { [int]$_.OwningProcess -eq [int]$process.ProcessId }
        )
        $postListenerProcess = Get-QmLiveProcessById -ProcessId ([int]$process.ProcessId)
        if ($null -eq $postListenerProcess -or
            -not (Test-QmSameProcessGeneration -Left $confirmedProcess -Right $postListenerProcess)) {
            continue
        }
        $process = $postListenerProcess
        foreach ($listener in $processListeners) {
            $port = [int]$listener.LocalPort
            if ($port -lt [int]$PortContract.minimum_port -or $port -gt [int]$PortContract.maximum_port) {
                throw "DEV2 metatester listener port is outside contract: $port"
            }
            $portKey = $port.ToString([System.Globalization.CultureInfo]::InvariantCulture)
            $baselineOverlaps = @(
                if ($Baseline.ContainsKey($portKey)) {
                    $Baseline[$portKey] | Where-Object {
                        Test-QmListenerAddressesOverlap -Left ([string]$_.local_address) -Right ([string]$listener.LocalAddress)
                    }
                }
            )
            $currentOverlaps = @(
                $listenerSnapshot |
                    Where-Object {
                        [int]$_.LocalPort -eq $port -and
                        (Test-QmListenerAddressesOverlap -Left ([string]$_.LocalAddress) -Right ([string]$listener.LocalAddress))
                    }
            )
            $currentOwners = @(
                $currentOverlaps | ForEach-Object { [int]$_.OwningProcess } | Sort-Object -Unique
            )
            $otherOwners = @($currentOwners | Where-Object { $_ -ne [int]$process.ProcessId })
            if ($otherOwners.Count -gt 0) {
                throw "DEV2 metatester endpoint $($listener.LocalAddress):$port has another current listener owner."
            }
            if ($currentOwners.Count -ne 1 -or $currentOwners[0] -ne [int]$process.ProcessId) {
                throw "DEV2 metatester endpoint $($listener.LocalAddress):$port lacks exact single-owner proof."
            }
            $releasedBaselineOwners = @(
                $baselineOverlaps |
                    ForEach-Object { [int]$_.owning_process } |
                    Where-Object { $_ -notin $currentOwners } |
                    Sort-Object -Unique
            )
            $key = '{0}|{1}|{2}' -f [int]$process.ProcessId, $port, [string]$listener.LocalAddress
            $Seen[$key] = [ordered]@{
                local_address = [string]$listener.LocalAddress
                local_port = $port
                process_id = [int]$process.ProcessId
                owner_sid = $ownerSid
                executable_path = $actualPath
                creation_utc = $creationUtc.ToString('o')
                first_observed_utc = (Get-Date).ToUniversalTime().ToString('o')
                preexisting_port_owner = $false
                concurrent_port_owner = $false
                exclusive_current_owner = $true
                current_overlapping_owner_count = $currentOwners.Count
                baseline_endpoint_was_occupied = ($baselineOverlaps.Count -gt 0)
                released_baseline_owner_count = $releasedBaselineOwners.Count
            }
        }
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
        'expected_sid', 'expected_profile', 'expected_common_path', 'dev2_root', 'reports_root',
        'smoke_report_root', 'expected_task_name', 'controller_mutex', 'lane_contract_path',
        'lane_contract_sha256', 'machine_credential_path', 'machine_credential_sha256',
        'machine_credential_helper_path', 'machine_credential_helper_sha256',
        'child_path', 'child_sha256', 'run_smoke_path', 'run_smoke_sha256',
        'program_sha256', 'smoke_parameters', 'maximum_run_attempts',
        'per_attempt_overhead_seconds', 'controller_finalization_margin_seconds',
        'controller_timeout_seconds'
    )
    $extra = @($Request.Keys | Where-Object { $_ -notin $required })
    $missing = @($required | Where-Object { -not $Request.ContainsKey($_) })
    if ($extra.Count -gt 0 -or $missing.Count -gt 0 -or [int]$Request.schema_version -ne 2) {
        throw "Invalid DEV2 request schema. Missing=$([string]::Join(',', $missing)); extra=$([string]::Join(',', $extra))"
    }
    if ([string]$Request.run_id -notmatch '^[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}$' -or
        [string]$Request.nonce -notmatch '^[0-9a-f]{32}$') {
        throw 'Invalid run_id or nonce.'
    }
    $expires = [DateTimeOffset]::Parse([string]$Request.expires_utc).ToUniversalTime()
    if ($expires -le [DateTimeOffset]::UtcNow) { throw 'DEV2 request is expired.' }
    if (-not (ConvertTo-QmFullPath -Path ([string]$Request.dev2_root)).Equals($script:Dev2Root, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (ConvertTo-QmFullPath -Path ([string]$Request.reports_root)).Equals($script:ReportsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'DEV2 request changed a fixed isolation root.'
    }
    if ([string]$Request.expected_task_name -notmatch '^QM_DEV2_SMOKE_[0-9a-f]{32}$' -or
        -not ([string]$Request.expected_task_name).StartsWith($script:TaskNamePrefix, [System.StringComparison]::Ordinal) -or
        [string]$Request.controller_mutex -cne $script:ControllerMutexName -or
        -not (ConvertTo-QmFullPath -Path ([string]$Request.lane_contract_path)).Equals($script:LaneContractPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (ConvertTo-QmFullPath -Path ([string]$Request.machine_credential_path)).Equals($script:CredentialPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (ConvertTo-QmFullPath -Path ([string]$Request.machine_credential_helper_path)).Equals($script:CredentialHelperPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (ConvertTo-QmFullPath -Path ([string]$Request.child_path)).Equals((ConvertTo-QmFullPath -Path $PSCommandPath), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'DEV2 request changed its task, mutex, contract, or child-script identity.'
    }
    foreach ($hashName in @(
            'lane_contract_sha256', 'machine_credential_sha256',
            'machine_credential_helper_sha256', 'child_sha256', 'run_smoke_sha256'
        )) {
        if ([string]$Request[$hashName] -notmatch '^[0-9a-f]{64}$') {
            throw "DEV2 request contains invalid $hashName."
        }
    }
    if ($Request.program_sha256 -isnot [System.Collections.IDictionary]) {
        throw 'DEV2 request program_sha256 must be an object.'
    }
    if (-not (Test-QmPathWithin -Path ([string]$Request.smoke_report_root) -Root $ExpectedRunDirectory)) {
        throw 'Smoke ReportRoot escaped the nonce-bound run directory.'
    }
    if (-not (Test-QmPathWithin -Path $ExpectedRunDirectory -Root $script:ReportsRoot)) {
        throw 'RunDirectory escaped D:\QM\reports\dev2.'
    }

    $parameters = [hashtable]$Request.smoke_parameters
    $unknown = @($parameters.Keys | Where-Object { $_ -notin $script:AllowedParameterOrder })
    if ($unknown.Count -gt 0) { throw "Forbidden smoke parameter(s): $([string]::Join(',', $unknown))" }
    foreach ($forbidden in @('Terminal', 'ReportRoot', 'AllowRunningTerminal', 'DispatchPhase', 'DispatchVersion', 'DispatchSubGateHash')) {
        if ($parameters.ContainsKey($forbidden)) { throw "Forbidden DEV2 parameter: $forbidden" }
    }
    foreach ($mandatory in @('EAId', 'Symbol', 'Year', 'Expert', 'Period', 'Runs', 'MinTrades', 'Model', 'TimeoutSeconds')) {
        if (-not $parameters.ContainsKey($mandatory)) { throw "Missing smoke parameter: $mandatory" }
    }
    if ([string]$parameters.Symbol -notin $script:AllowedSymbols) { throw 'Symbol is outside the DEV2 allowlist.' }
    if ([string]$parameters.Expert -notmatch '^QM\\[A-Za-z0-9_.-]+$') { throw 'Expert path is invalid.' }
    if ([string]$parameters.Period -notmatch '^[A-Z][A-Z0-9]{0,4}$') { throw 'Period is invalid.' }
    if ([int]$parameters.Year -lt 2000 -or [int]$parameters.Year -gt 2100 -or
        [int]$parameters.Runs -lt 1 -or [int]$parameters.Runs -gt 10 -or
        [int]$parameters.Model -ne 4 -or [int]$parameters.TimeoutSeconds -lt 60 -or [int]$parameters.TimeoutSeconds -gt 28800) {
        throw 'Numeric smoke parameter is outside its fixed range.'
    }
    $expectedMaximumAttempts = [Math]::Min(10, ([int]$parameters.Runs + 2))
    $minimumControllerTimeout = Get-QmMinimumDev2ControllerTimeoutSeconds `
        -MaximumRunAttempts $expectedMaximumAttempts -RunTimeoutSeconds ([int]$parameters.TimeoutSeconds)
    if ($minimumControllerTimeout -gt 172800 -or
        [int]$Request.maximum_run_attempts -ne $expectedMaximumAttempts -or
        [int]$Request.per_attempt_overhead_seconds -ne $script:PerAttemptOverheadSeconds -or
        [int]$Request.controller_finalization_margin_seconds -ne $script:ControllerFinalizationMarginSeconds -or
        [int]$Request.controller_timeout_seconds -lt $minimumControllerTimeout -or
        [int]$Request.controller_timeout_seconds -gt 172800) {
        throw 'DEV2 request maximum-attempt/controller-timeout contract drifted.'
    }
    $created = [DateTimeOffset]::Parse([string]$Request.created_utc).ToUniversalTime()
    $lifetimeSeconds = ($expires - $created).TotalSeconds
    if ($lifetimeSeconds -lt ([int]$Request.controller_timeout_seconds + 590) -or
        $lifetimeSeconds -gt ([int]$Request.controller_timeout_seconds + 610)) {
        throw 'DEV2 request expiry does not cover the bounded controller timeout.'
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
$laneContractSha256 = $null
$childSha256 = $null
$runSmokeSha256 = $null
$machineCredentialSha256 = $null
$machineCredentialHelperSha256 = $null
$verifiedProgramSha256 = [ordered]@{}
$agentPortProof = [ordered]@{
    status = 'NOT_RUN'
    preexisting_port_owner = $false
    concurrent_port_owner = $false
    exclusivity_semantics = 'NO_CONCURRENT_OVERLAPPING_ENDPOINT_OWNER'
    released_baseline_endpoint_reuse_allowed = $true
    metatester_path = (ConvertTo-QmFullPath -Path (Join-Path $script:Dev2Root 'metatester64.exe'))
    metatester_sha256 = $null
    listeners = @()
}

try {
    $RunDirectory = ConvertTo-QmFullPath -Path $RunDirectory
    if (-not (Test-QmPathWithin -Path $RunDirectory -Root $script:ReportsRoot)) {
        throw 'RunDirectory is outside D:\QM\reports\dev2.'
    }
    Assert-QmNoReparseComponents -Path $RunDirectory
    $requestPath = Join-Path $RunDirectory 'control\request.json'
    $outputDirectory = Join-Path $RunDirectory 'output'
    $resultPath = Join-Path $outputDirectory 'result.json'
    $logPath = Join-Path $outputDirectory 'run.log'
    foreach ($path in @($requestPath, $outputDirectory)) { Assert-QmNoReparseComponents -Path $path }

    # PowerShell otherwise auto-converts ISO-8601 strings to DateTime. Casting that
    # value back to string drops the trailing Z and can reinterpret UTC as local
    # time, falsely expiring a fresh request. Keep wire dates as exact strings.
    $request = Get-Content -LiteralPath $requestPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -DateKind String -ErrorAction Stop
    Assert-QmRequestSchema -Request $request -ExpectedRunDirectory $RunDirectory
    $runId = [string]$request.run_id
    $nonce = [string]$request.nonce
    $machineCredentialSha256 = [string]$request.machine_credential_sha256
    $machineCredentialHelperSha256 = [string]$request.machine_credential_helper_sha256

    foreach ($boundPath in @([string]$request.lane_contract_path, [string]$request.child_path, [string]$request.run_smoke_path)) {
        Assert-QmNoReparseComponents -Path $boundPath
    }
    $laneContractSha256 = (Get-FileHash -LiteralPath ([string]$request.lane_contract_path) -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $childSha256 = (Get-FileHash -LiteralPath ([string]$request.child_path) -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $runSmokeSha256 = (Get-FileHash -LiteralPath ([string]$request.run_smoke_path) -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($laneContractSha256 -cne [string]$request.lane_contract_sha256 -or
        $childSha256 -cne [string]$request.child_sha256 -or
        $runSmokeSha256 -cne [string]$request.run_smoke_sha256) {
        throw 'DEV2 contract or runner script changed between controller and child execution.'
    }
    $laneContract = Get-Content -LiteralPath ([string]$request.lane_contract_path) -Raw -ErrorAction Stop |
        ConvertFrom-Json -AsHashtable -DateKind String -ErrorAction Stop
    Assert-QmLaneContract -Contract $laneContract
    $verifiedProgramSha256 = Get-QmVerifiedProgramHashes -ExpectedHashes ([System.Collections.IDictionary]$request.program_sha256) -Contract $laneContract

    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $currentSid = $currentIdentity.User.Value
    $currentName = $currentIdentity.Name
    if ($currentSid -ne [string]$request.expected_sid -or
        -not $currentName.Equals([string]$request.expected_account, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Scheduled Task did not run as the nonce-bound QMDev2 identity.'
    }
    if ((Resolve-QmAccountSid -AccountName ([string]$request.expected_account)) -ne [string]$request.expected_sid) {
        throw 'Requested QMDev2 name/SID mapping drifted.'
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
    Assert-QmNoDev2Processes

    $runSmokePath = ConvertTo-QmFullPath -Path ([string]$request.run_smoke_path)
    Assert-QmNoReparseComponents -Path $runSmokePath
    $actualHash = (Get-FileHash -LiteralPath $runSmokePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -cne [string]$request.run_smoke_sha256) {
        throw 'run_smoke.ps1 changed between controller and child execution.'
    }
    if (-not (Test-Path -LiteralPath $script:PwshPath -PathType Leaf)) { throw 'Fixed PowerShell 7 executable is missing.' }
    Assert-QmNoReparseComponents -Path $script:PwshPath

    [System.IO.File]::WriteAllText($logPath, "DEV2 child preflight PASS at $((Get-Date).ToUniversalTime().ToString('o'))`r`n")
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
    [void]$startInfo.ArgumentList.Add('DEV2')
    [void]$startInfo.ArgumentList.Add('-ReportRoot')
    [void]$startInfo.ArgumentList.Add((ConvertTo-QmFullPath -Path ([string]$request.smoke_report_root)))

    [hashtable]$listenerBaseline = Get-QmListenerBaseline
    $observedListeners = @{}
    $runnerStartedUtc = [DateTimeOffset]::UtcNow
    $runner = New-Object System.Diagnostics.Process
    $runner.StartInfo = $startInfo
    try {
        if (-not $runner.Start()) { throw 'Failed to start isolated run_smoke child process.' }
        $stdoutTask = $runner.StandardOutput.ReadToEndAsync()
        $stderrTask = $runner.StandardError.ReadToEndAsync()
        while (-not $runner.WaitForExit(250)) {
            Update-QmDev2AgentListenerProof -Baseline $listenerBaseline -Seen $observedListeners `
                -ExpectedOwnerSid $currentSid -EarliestCreationUtc $runnerStartedUtc `
                -PortContract ([System.Collections.IDictionary]$laneContract.agent_port_contract)
        }
        Update-QmDev2AgentListenerProof -Baseline $listenerBaseline -Seen $observedListeners `
            -ExpectedOwnerSid $currentSid -EarliestCreationUtc $runnerStartedUtc `
            -PortContract ([System.Collections.IDictionary]$laneContract.agent_port_contract)
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        [System.IO.File]::AppendAllText($logPath, "--- run_smoke stdout ---`r`n$stdout`r`n--- run_smoke stderr ---`r`n$stderr`r`n")
        $runSmokeExitCode = $runner.ExitCode
    } finally {
        try {
            if (-not $runner.HasExited) {
                $runner.Kill($true)
                [void]$runner.WaitForExit(10000)
            }
        } catch {
        }
        $runner.Dispose()
    }

    Assert-QmNoDev2Processes
    if ($observedListeners.Count -lt 1) {
        $agentPortProof.status = 'FAIL'
        $errorCode = 'DEV2_AGENT_PORT_PROOF_MISSING'
        throw 'No exact-path DEV2 metatester listener was observed during the smoke run.'
    }
    $postRunProgramHashes = Get-QmVerifiedProgramHashes -ExpectedHashes ([System.Collections.IDictionary]$request.program_sha256) -Contract $laneContract
    foreach ($name in @($verifiedProgramSha256.Keys)) {
        if ([string]$postRunProgramHashes[$name] -cne [string]$verifiedProgramSha256[$name]) {
            throw "DEV2 program changed during smoke execution: $name"
        }
    }
    $agentPortProof.status = 'PASS'
    $agentPortProof.metatester_sha256 = [string]$verifiedProgramSha256['metatester64.exe']
    $agentPortProof.listeners = @($observedListeners.Values | Sort-Object local_port, process_id, local_address)
    if ($runSmokeExitCode -ne 0) {
        $errorCode = 'RUN_SMOKE_FAILED'
        throw "run_smoke.ps1 exited with code $runSmokeExitCode."
    }
    $success = $true
    $errorCode = $null
} catch {
    $errorMessage = $_.Exception.Message
    if ($null -ne $logPath) {
        try { [System.IO.File]::AppendAllText($logPath, "DEV2 child failure: $errorMessage`r`n") } catch { }
    }
} finally {
    if ($null -ne $resultPath -and $null -ne $runId -and $null -ne $nonce) {
        $result = [ordered]@{
            schema_version = 2
            run_id = $runId
            nonce = $nonce
            success = $success
            error_code = $errorCode
            error_message = $errorMessage
            run_smoke_exit_code = $runSmokeExitCode
            identity_sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            common_path = $actualCommonPath
            expected_task_name = [string]$request.expected_task_name
            controller_mutex = [string]$request.controller_mutex
            lane_contract_sha256 = $laneContractSha256
            machine_credential_sha256 = $machineCredentialSha256
            machine_credential_helper_sha256 = $machineCredentialHelperSha256
            child_sha256 = $childSha256
            run_smoke_sha256 = $runSmokeSha256
            program_sha256 = $verifiedProgramSha256
            agent_port_proof = $agentPortProof
            started_utc = $startedUtc.ToString('o')
            finished_utc = (Get-Date).ToUniversalTime().ToString('o')
            log_path = $logPath
        }
        try { Write-QmAtomicResult -Result $result -ResultPath $resultPath } catch { }
    }
}

if (-not $success) { exit 1 }
exit 0
