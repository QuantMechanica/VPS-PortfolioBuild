[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Inspect', 'Apply', 'Restore')]
    [string]$Mode = 'Inspect',
    [string]$ReceiptRoot = 'D:\QM\reports\research\AD4EB945_LIVEUPDATE_GUARD_20260912'
)

$ErrorActionPreference = 'Stop'
$minimumRamBytes = 12GB
$profileRoot = 'C:\Windows\System32\config\systemprofile\AppData\Roaming\MetaQuotes\Terminal'
$seats = @(
    [pscustomobject]@{
        Seat = 'T11'
        TerminalRoot = 'D:\QM\mt5\T11'
        ProfileHash = 'F5D9412A6437C1548F3DA4241E8C78A6'
        FirewallName = 'QM Research T11 block background LiveUpdate'
    },
    [pscustomobject]@{
        Seat = 'T12'
        TerminalRoot = 'D:\QM\mt5\T12'
        ProfileHash = 'D033A12192D0AC53D574B7C2799994E6'
        FirewallName = 'QM Research T12 block background LiveUpdate'
    }
)

function Get-SeatState {
    param([pscustomobject]$Seat)

    $terminalRoot = [System.IO.Path]::GetFullPath($Seat.TerminalRoot).TrimEnd('\')
    if ($terminalRoot -notin @('D:\QM\mt5\T11', 'D:\QM\mt5\T12')) {
        throw "Refusing non-research terminal root: $terminalRoot"
    }
    $profilePath = Join-Path $profileRoot $Seat.ProfileHash
    $originPath = Join-Path $profilePath 'origin.txt'
    if (-not (Test-Path -LiteralPath $originPath -PathType Leaf)) {
        throw "Missing terminal identity file: $originPath"
    }
    $origin = (Get-Content -LiteralPath $originPath -Raw).Trim().TrimEnd('\')
    if ($origin -ine $terminalRoot) {
        throw "Terminal identity mismatch for $($Seat.Seat): '$origin' != '$terminalRoot'"
    }

    $liveUpdatePath = Join-Path $profilePath 'liveupdate'
    $payloads = @()
    $writeDeny = @()
    $profileDeleteChildDeny = @((Get-Acl -LiteralPath $profilePath).Access | Where-Object {
        -not $_.IsInherited -and
        $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny -and
        $_.IdentityReference.Value -eq 'NT AUTHORITY\SYSTEM' -and
        $_.FileSystemRights -eq [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -and
        $_.InheritanceFlags -eq [System.Security.AccessControl.InheritanceFlags]::None
    } | ForEach-Object {
        [ordered]@{
            identity = $_.IdentityReference.Value
            type = [string]$_.AccessControlType
            rights = [string]$_.FileSystemRights
            inheritance = [string]$_.InheritanceFlags
            propagation = [string]$_.PropagationFlags
        }
    })
    if (Test-Path -LiteralPath $liveUpdatePath -PathType Container) {
        $payloads = @(Get-ChildItem -LiteralPath $liveUpdatePath -File -Recurse | ForEach-Object {
            [ordered]@{
                name = $_.Name
                length = $_.Length
                sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        })
        $writeDeny = @((Get-Acl -LiteralPath $liveUpdatePath).Access | Where-Object {
            -not $_.IsInherited -and
            $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny -and
            $_.IdentityReference.Value -eq 'NT AUTHORITY\SYSTEM'
        } | ForEach-Object {
            [ordered]@{
                identity = $_.IdentityReference.Value
                type = [string]$_.AccessControlType
                rights = [string]$_.FileSystemRights
                inheritance = [string]$_.InheritanceFlags
                propagation = [string]$_.PropagationFlags
            }
        })
    }
    $rule = Get-NetFirewallRule -DisplayName $Seat.FirewallName -ErrorAction SilentlyContinue
    $application = if ($rule) { $rule | Get-NetFirewallApplicationFilter } else { $null }
    [ordered]@{
        seat = $Seat.Seat
        terminal_root = $terminalRoot
        terminal_executable = Join-Path $terminalRoot 'terminal64.exe'
        profile_hash = $Seat.ProfileHash
        profile_path = $profilePath
        origin_path = $originPath
        origin = $origin
        liveupdate_path = $liveUpdatePath
        liveupdate_present = Test-Path -LiteralPath $liveUpdatePath -PathType Container
        pending_payload_count = $payloads.Count
        pending_payloads = $payloads
        explicit_system_write_deny = $writeDeny
        explicit_profile_delete_child_deny = $profileDeleteChildDeny
        firewall_rule = if ($rule) { [ordered]@{
            display_name = $rule.DisplayName
            enabled = [string]$rule.Enabled
            direction = [string]$rule.Direction
            action = [string]$rule.Action
            program = [string]$application.Program
        }} else { $null }
    }
}

$activeResearch = @(Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and
    ([System.IO.Path]::GetFullPath($_.ExecutablePath).StartsWith('D:\QM\mt5\T11\', [System.StringComparison]::OrdinalIgnoreCase) -or
     [System.IO.Path]::GetFullPath($_.ExecutablePath).StartsWith('D:\QM\mt5\T12\', [System.StringComparison]::OrdinalIgnoreCase))
} | Select-Object ProcessId, Name, ExecutablePath)
$freeRamBytes = [long](Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1KB
if ($Mode -ne 'Inspect') {
    if ($activeResearch.Count -ne 0) { throw 'Refusing mutation while a T11/T12 process is active.' }
    if ($freeRamBytes -lt $minimumRamBytes) { throw "RAM guard: $freeRamBytes < $minimumRamBytes" }
}

$before = @($seats | ForEach-Object { Get-SeatState $_ })
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
$quarantineRoot = Join-Path ([System.IO.Path]::GetFullPath($ReceiptRoot)) 'quarantine'
$actions = @()

if ($Mode -eq 'Apply') {
    New-Item -ItemType Directory -Path $quarantineRoot -Force | Out-Null
    foreach ($seat in $seats) {
        $state = $before | Where-Object seat -eq $seat.Seat
        $quarantinePath = Join-Path $quarantineRoot ("{0}_{1}_liveupdate" -f $seat.Seat, $seat.ProfileHash)
        if ($state.liveupdate_present) {
            if (Test-Path -LiteralPath $quarantinePath) {
                throw "Quarantine target already exists: $quarantinePath"
            }
            if ($PSCmdlet.ShouldProcess($state.liveupdate_path, "Move staged LiveUpdate to $quarantinePath")) {
                Move-Item -LiteralPath $state.liveupdate_path -Destination $quarantinePath
                $actions += [ordered]@{ action = 'quarantine_liveupdate'; seat = $seat.Seat; source = $state.liveupdate_path; destination = $quarantinePath }
            }
        }
        if (-not (Test-Path -LiteralPath $state.liveupdate_path -PathType Container)) {
            if ($PSCmdlet.ShouldProcess($state.liveupdate_path, 'Create empty seat-specific LiveUpdate deny target')) {
                New-Item -ItemType Directory -Path $state.liveupdate_path | Out-Null
                $actions += [ordered]@{ action = 'create_empty_liveupdate_directory'; seat = $seat.Seat; path = $state.liveupdate_path }
            }
        }
        $existing = Get-NetFirewallRule -DisplayName $seat.FirewallName -ErrorAction SilentlyContinue
        if ($existing -and $PSCmdlet.ShouldProcess($seat.FirewallName, 'Remove superseded whole-program network block')) {
            $existing | Remove-NetFirewallRule
            $actions += [ordered]@{ action = 'remove_superseded_outbound_block'; seat = $seat.Seat; display_name = $seat.FirewallName }
        }
        $acl = Get-Acl -LiteralPath $state.liveupdate_path
        $rights = [System.Security.AccessControl.FileSystemRights]::WriteData -bor
            [System.Security.AccessControl.FileSystemRights]::AppendData -bor
            [System.Security.AccessControl.FileSystemRights]::WriteAttributes -bor
            [System.Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
            [System.Security.AccessControl.FileSystemRights]::Delete -bor
            [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles
        $denyRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            'NT AUTHORITY\SYSTEM', $rights,
            ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit),
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Deny)
        $existingDeny = @($acl.Access | Where-Object {
            -not $_.IsInherited -and $_.AccessControlType -eq 'Deny' -and
            $_.IdentityReference.Value -eq 'NT AUTHORITY\SYSTEM'
        })
        if ($existingDeny.Count -eq 0 -and $PSCmdlet.ShouldProcess($state.liveupdate_path, 'Deny SYSTEM payload writes while preserving terminal networking')) {
            [void]$acl.AddAccessRule($denyRule)
            Set-Acl -LiteralPath $state.liveupdate_path -AclObject $acl
            $actions += [ordered]@{ action = 'deny_system_liveupdate_writes'; seat = $seat.Seat; path = $state.liveupdate_path; rights = [string]$rights }
        }
        $profileAcl = Get-Acl -LiteralPath $state.profile_path
        $profileDeny = @($profileAcl.Access | Where-Object {
            -not $_.IsInherited -and $_.AccessControlType -eq 'Deny' -and
            $_.IdentityReference.Value -eq 'NT AUTHORITY\SYSTEM' -and
            $_.FileSystemRights -eq [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -and
            $_.InheritanceFlags -eq [System.Security.AccessControl.InheritanceFlags]::None
        })
        if ($profileDeny.Count -eq 0 -and $PSCmdlet.ShouldProcess($state.profile_path, 'Deny SYSTEM delete-child bypass of the protected LiveUpdate directory')) {
            $profileRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                'NT AUTHORITY\SYSTEM',
                [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles,
                [System.Security.AccessControl.InheritanceFlags]::None,
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Deny)
            [void]$profileAcl.AddAccessRule($profileRule)
            Set-Acl -LiteralPath $state.profile_path -AclObject $profileAcl
            $actions += [ordered]@{ action = 'deny_system_profile_delete_child'; seat = $seat.Seat; path = $state.profile_path; rights = 'DeleteSubdirectoriesAndFiles' }
        }
    }
}
elseif ($Mode -eq 'Restore') {
    foreach ($seat in $seats) {
        $rule = Get-NetFirewallRule -DisplayName $seat.FirewallName -ErrorAction SilentlyContinue
        if ($rule -and $PSCmdlet.ShouldProcess($seat.FirewallName, 'Remove exact research-seat firewall rule')) {
            $rule | Remove-NetFirewallRule
            $actions += [ordered]@{ action = 'remove_outbound_block'; seat = $seat.Seat; display_name = $seat.FirewallName }
        }
        $state = $before | Where-Object seat -eq $seat.Seat
        $profileAcl = Get-Acl -LiteralPath $state.profile_path
        $profileDenyRules = @($profileAcl.Access | Where-Object {
            -not $_.IsInherited -and $_.AccessControlType -eq 'Deny' -and
            $_.IdentityReference.Value -eq 'NT AUTHORITY\SYSTEM' -and
            $_.FileSystemRights -eq [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -and
            $_.InheritanceFlags -eq [System.Security.AccessControl.InheritanceFlags]::None
        })
        foreach ($profileDenyRule in $profileDenyRules) {
            [void]$profileAcl.RemoveAccessRuleSpecific($profileDenyRule)
        }
        if ($profileDenyRules.Count -gt 0 -and $PSCmdlet.ShouldProcess($state.profile_path, 'Remove exact SYSTEM profile delete-child deny')) {
            Set-Acl -LiteralPath $state.profile_path -AclObject $profileAcl
            $actions += [ordered]@{ action = 'remove_system_profile_delete_child_deny'; seat = $seat.Seat; path = $state.profile_path }
        }
        if (Test-Path -LiteralPath $state.liveupdate_path -PathType Container) {
            $acl = Get-Acl -LiteralPath $state.liveupdate_path
            $denyRules = @($acl.Access | Where-Object {
                -not $_.IsInherited -and $_.AccessControlType -eq 'Deny' -and
                $_.IdentityReference.Value -eq 'NT AUTHORITY\SYSTEM'
            })
            foreach ($denyRule in $denyRules) {
                [void]$acl.RemoveAccessRuleSpecific($denyRule)
            }
            if ($denyRules.Count -gt 0 -and $PSCmdlet.ShouldProcess($state.liveupdate_path, 'Remove exact SYSTEM LiveUpdate write-deny rules')) {
                Set-Acl -LiteralPath $state.liveupdate_path -AclObject $acl
                $actions += [ordered]@{ action = 'remove_system_liveupdate_write_deny'; seat = $seat.Seat; path = $state.liveupdate_path }
            }
        }
        $quarantinePath = Join-Path $quarantineRoot ("{0}_{1}_liveupdate" -f $seat.Seat, $seat.ProfileHash)
        if (Test-Path -LiteralPath $quarantinePath -PathType Container) {
            if (Test-Path -LiteralPath $state.liveupdate_path -PathType Container) {
                if (@(Get-ChildItem -LiteralPath $state.liveupdate_path -Force).Count -ne 0) {
                    throw "Restore target is not empty: $($state.liveupdate_path)"
                }
                Remove-Item -LiteralPath $state.liveupdate_path
            }
            if ($PSCmdlet.ShouldProcess($quarantinePath, "Restore LiveUpdate to $($state.liveupdate_path)")) {
                Move-Item -LiteralPath $quarantinePath -Destination $state.liveupdate_path
                $actions += [ordered]@{ action = 'restore_liveupdate'; seat = $seat.Seat; source = $quarantinePath; destination = $state.liveupdate_path }
            }
        }
    }
}

$after = @($seats | ForEach-Object { Get-SeatState $_ })
$guardReady = @($after | Where-Object {
    $_.pending_payload_count -ne 0 -or
    @($_.explicit_system_write_deny).Count -eq 0 -or
    @($_.explicit_profile_delete_child_deny).Count -eq 0 -or
    $_.firewall_rule
}).Count -eq 0
$result = if ($Mode -eq 'Apply' -and $guardReady) {
    'GUARD_APPLIED'
} elseif ($Mode -eq 'Inspect' -and $guardReady) {
    'GUARD_PRESENT'
} elseif ($Mode -eq 'Inspect') {
    'INSPECTED'
} elseif ($Mode -eq 'Restore') {
    'RESTORED'
} else {
    'CHECK_REQUIRED'
}

$receipt = [ordered]@{
    schema = 'qm.research-liveupdate-guard/v1'
    captured_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    mode = $Mode
    minimum_free_ram_bytes = $minimumRamBytes
    free_ram_bytes = $freeRamBytes
    active_research_processes = $activeResearch
    before = $before
    actions = $actions
    after = $after
    result = $result
    documentation = @(
        'https://www.mql5.com/en/forum/425911/page3'
    )
}

$receiptDirectory = [System.IO.Path]::GetFullPath($ReceiptRoot)
New-Item -ItemType Directory -Path $receiptDirectory -Force | Out-Null
$receiptPath = Join-Path $receiptDirectory ("{0}_{1}.json" -f $timestamp, $Mode.ToLowerInvariant())
$receipt | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding utf8
$receipt.receipt_path = $receiptPath
$receipt | ConvertTo-Json -Depth 12
