# Shared read-only identity checks and stale-lock reaping for the global
# Strategy Farm mutation lock.  This file only defines functions; dot-sourcing
# it never touches the factory, scheduler, database, terminals or lock file.

$script:QmFactoryMutationLockProtocolVersion = 2

function Read-QmFactoryMutationLockSnapshot {
    param([Parameter(Mandatory = $true)][string]$Path)

    $invalid = [ordered]@{
        valid = $false
        path = $Path
        pid = $null
        owner = $null
        nonce = $null
        created_at_utc = $null
        raw_bytes_base64 = $null
        reason = 'unreadable'
    }
    try {
        [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)
        if ($bytes.Length -eq 0 -or $bytes.Length -gt 65536) {
            $invalid.reason = 'invalid_size'
            return [pscustomobject]$invalid
        }
        $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
        $raw = $utf8.GetString($bytes)
        $record = $raw | ConvertFrom-Json -ErrorAction Stop
        $propertyNames = @($record.PSObject.Properties | ForEach-Object { [string]$_.Name })
        foreach ($required in @('pid','owner','nonce','created_at')) {
            if ($required -notin $propertyNames) {
                $invalid.reason = "missing_$required"
                return [pscustomobject]$invalid
            }
            if ([regex]::Matches($raw, ('"{0}"\s*:' -f [regex]::Escape($required))).Count -ne 1) {
                $invalid.reason = "ambiguous_$required"
                return [pscustomobject]$invalid
            }
        }

        [long]$ownerProcessId = 0
        if (-not [long]::TryParse(
            [string]$record.pid,
            [Globalization.NumberStyles]::None,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$ownerProcessId
        ) -or $ownerProcessId -le 0 -or $ownerProcessId -gt [int]::MaxValue) {
            $invalid.reason = 'invalid_pid'
            return [pscustomobject]$invalid
        }
        $owner = [string]$record.owner
        if ([string]::IsNullOrWhiteSpace($owner) -or $owner.Length -gt 512) {
            $invalid.reason = 'invalid_owner'
            return [pscustomobject]$invalid
        }
        $nonce = [string]$record.nonce
        if ($nonce -notmatch '^[0-9a-fA-F]{32}$') {
            $invalid.reason = 'invalid_nonce'
            return [pscustomobject]$invalid
        }

        # PowerShell 7 may eagerly deserialize an ISO JSON string as DateTime
        # and localize its string representation. Bind the UTC spelling from
        # the original bytes instead of trusting that conversion.
        $createdAtMatch = [regex]::Match(
            $raw,
            '"created_at"\s*:\s*"(?<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|\+00:00))"'
        )
        if (-not $createdAtMatch.Success) {
            $invalid.reason = 'invalid_created_at'
            return [pscustomobject]$invalid
        }
        [DateTimeOffset]$createdAt = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse(
            $createdAtMatch.Groups['timestamp'].Value,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind,
            [ref]$createdAt
        ) -or $createdAt.Offset -ne [TimeSpan]::Zero) {
            $invalid.reason = 'invalid_created_at'
            return [pscustomobject]$invalid
        }
        # A materially future-dated record cannot authenticate a process
        # lifetime. Retain it fail-closed for OWNER inspection.
        if ($createdAt.UtcDateTime -gt [DateTime]::UtcNow.AddMinutes(5)) {
            $invalid.reason = 'future_created_at'
            return [pscustomobject]$invalid
        }

        return [pscustomobject][ordered]@{
            valid = $true
            path = $Path
            pid = [int]$ownerProcessId
            owner = $owner
            nonce = $nonce.ToLowerInvariant()
            created_at_utc = $createdAt.UtcDateTime
            raw_bytes_base64 = [Convert]::ToBase64String($bytes)
            reason = 'valid'
        }
    } catch {
        return [pscustomobject]$invalid
    }
}

function Get-QmFactoryMutationLockOwnerState {
    param([Parameter(Mandatory = $true)]$Snapshot)

    if (-not $Snapshot.valid) {
        return [pscustomobject][ordered]@{
            safe_to_reap = $false
            owner_alive = $null
            reason = 'lock_identity_invalid'
        }
    }

    $ownerProcess = Get-Process -Id ([int]$Snapshot.pid) -ErrorAction SilentlyContinue
    if ($null -eq $ownerProcess) {
        return [pscustomobject][ordered]@{
            safe_to_reap = $true
            owner_alive = $false
            reason = 'owner_pid_not_live'
        }
    }

    try {
        $processStartedAtUtc = $ownerProcess.StartTime.ToUniversalTime()
    } catch {
        # Process lifetime could not be authenticated. Keep the lock.
        return [pscustomobject][ordered]@{
            safe_to_reap = $false
            owner_alive = $null
            reason = 'owner_start_time_unreadable'
        }
    }

    # A genuine owner process necessarily started before it wrote created_at.
    # A live process that started later is a reused PID, not the lock owner.
    if ($processStartedAtUtc -gt ([DateTime]$Snapshot.created_at_utc)) {
        return [pscustomobject][ordered]@{
            safe_to_reap = $true
            owner_alive = $false
            reason = 'owner_pid_reused'
        }
    }
    return [pscustomobject][ordered]@{
        safe_to_reap = $false
        owner_alive = $true
        reason = 'owner_identity_live'
    }
}

function Initialize-QmFactoryMutationLockNativeDelete {
    if (($null -ne ([System.Management.Automation.PSTypeName]'QmFactoryMutationLockNative').Type)) {
        return $true
    }
    try {
        Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public static class QmFactoryMutationLockNative
{
    private const uint GenericRead = 0x80000000;
    private const uint DeleteAccess = 0x00010000;
    private const uint OpenExisting = 3;
    private const uint FileAttributeNormal = 0x00000080;

    [StructLayout(LayoutKind.Sequential)]
    private struct FileDispositionInfo
    {
        [MarshalAs(UnmanagedType.Bool)]
        public bool DeleteFile;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFileW(
        string fileName,
        uint desiredAccess,
        uint shareMode,
        IntPtr securityAttributes,
        uint creationDisposition,
        uint flagsAndAttributes,
        IntPtr templateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetFileInformationByHandle(
        SafeFileHandle file,
        int fileInformationClass,
        ref FileDispositionInfo fileInformation,
        uint bufferSize);

    public static bool DeleteIfContentMatches(string path, byte[] expected)
    {
        SafeFileHandle handle = CreateFileW(
            path,
            GenericRead | DeleteAccess,
            0,
            IntPtr.Zero,
            OpenExisting,
            FileAttributeNormal,
            IntPtr.Zero);
        if (handle == null || handle.IsInvalid)
        {
            if (handle != null) handle.Dispose();
            return false;
        }

        using (handle)
        using (FileStream stream = new FileStream(handle, FileAccess.Read))
        {
            if (stream.Length != expected.LongLength) return false;
            byte[] actual = new byte[expected.Length];
            int offset = 0;
            while (offset < actual.Length)
            {
                int read = stream.Read(actual, offset, actual.Length - offset);
                if (read == 0) return false;
                offset += read;
            }
            int difference = 0;
            for (int i = 0; i < actual.Length; i++)
            {
                difference |= actual[i] ^ expected[i];
            }
            if (difference != 0) return false;

            FileDispositionInfo disposition = new FileDispositionInfo { DeleteFile = true };
            return SetFileInformationByHandle(
                handle,
                4, // FILE_INFO_BY_HANDLE_CLASS.FileDispositionInfo
                ref disposition,
                (uint)Marshal.SizeOf(typeof(FileDispositionInfo)));
        }
    }
}
'@ -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Remove-QmFactoryMutationLockIfUnchanged {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedRawBytesBase64
    )

    try {
        [byte[]]$expected = [Convert]::FromBase64String($ExpectedRawBytesBase64)
    } catch {
        return $false
    }
    if (-not (Initialize-QmFactoryMutationLockNativeDelete)) {
        # No path-based fallback: inability to delete the exact opened file
        # object must retain the lock fail-closed.
        return $false
    }
    try {
        return [QmFactoryMutationLockNative]::DeleteIfContentMatches($Path, $expected)
    } catch {
        return $false
    }
}

function Wait-QmFactoryMutationLockDrain {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$TimeoutSeconds = 60,
        [int]$PollMilliseconds = 500
    )

    if ($TimeoutSeconds -lt 0 -or $PollMilliseconds -lt 0) {
        throw 'Mutation-lock drain timeouts must be non-negative.'
    }
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (Test-Path -LiteralPath $Path) {
        $snapshot = Read-QmFactoryMutationLockSnapshot -Path $Path
        $ownerState = Get-QmFactoryMutationLockOwnerState -Snapshot $snapshot
        if ($ownerState.safe_to_reap) {
            $removed = Remove-QmFactoryMutationLockIfUnchanged `
                -Path $Path `
                -ExpectedRawBytesBase64 $snapshot.raw_bytes_base64
            if ($removed -and -not (Test-Path -LiteralPath $Path)) {
                return $true
            }
        }
        if ([DateTime]::UtcNow -ge $deadline) {
            return $false
        }
        if ($PollMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $PollMilliseconds
        }
    }
    return $true
}
