[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestPath,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ExpectedRequestSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-QmIdentityProbeFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.IndexOfAny([char[]]@([char]13, [char]10, [char]0)) -ge 0) {
        throw 'Identity-probe path is empty or contains CR, LF, or NUL.'
    }
    return [System.IO.Path]::GetFullPath($Path.Replace('/', '\'))
}

function Test-QmIdentityProbePathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )
    $full = ConvertTo-QmIdentityProbeFullPath -Path $Path
    $rootFull = (ConvertTo-QmIdentityProbeFullPath -Path $Root).TrimEnd('\')
    return $full.StartsWith($rootFull + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-QmIdentityProbeNoReparseComponents {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = ConvertTo-QmIdentityProbeFullPath -Path $Path
    if (-not (Test-Path -LiteralPath $full)) { throw "Required identity-probe path does not exist: $full" }
    $root = [System.IO.Path]::GetPathRoot($full)
    $cursor = $root
    foreach ($part in @($full.Substring($root.Length).Split('\', [System.StringSplitOptions]::RemoveEmptyEntries))) {
        $cursor = Join-Path $cursor $part
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point is forbidden in an identity-probe path: $cursor"
        }
    }
}

function Read-QmIdentityProbeRequest {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )
    if ($ExpectedSha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Identity-probe expected request SHA-256 is invalid.' }
    $full = ConvertTo-QmIdentityProbeFullPath -Path $Path
    Assert-QmIdentityProbeNoReparseComponents -Path $full
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw 'Identity-probe request is not a file.' }
    $stream = [System.IO.File]::Open(
        $full,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::None
    )
    try {
        if ($stream.Length -lt 32 -or $stream.Length -gt 32768) {
            throw 'Identity-probe request size is outside the strict bound.'
        }
        $bytes = [byte[]]::new([int]$stream.Length)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $read = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($read -le 0) { throw 'Identity-probe request ended before its declared length.' }
            $offset += $read
        }
    } finally {
        $stream.Dispose()
    }
    $digest = [System.Security.Cryptography.SHA256]::HashData($bytes)
    try {
        $actualSha256 = ([System.BitConverter]::ToString($digest)).Replace('-', '').ToLowerInvariant()
    } finally {
        [System.Array]::Clear($digest, 0, $digest.Length)
    }
    if ($actualSha256 -cne $ExpectedSha256) {
        [System.Array]::Clear($bytes, 0, $bytes.Length)
        throw 'Exact identity-probe request bytes differ from the expected SHA-256 binding.'
    }
    try {
        $json = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    } finally {
        [System.Array]::Clear($bytes, 0, $bytes.Length)
    }
    $expectedKinds = [ordered]@{
        artifact_type = 'String'
        created_utc = 'String'
        expected_account = 'String'
        expected_profile = 'String'
        expected_sid = 'String'
        expected_task_name = 'String'
        expires_utc = 'String'
        nonce = 'String'
        result_path = 'String'
        schema_version = 'Int32'
    }
    $document = [System.Text.Json.JsonDocument]::Parse($json)
    try {
        if ($document.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            throw 'Identity-probe request is not a JSON object.'
        }
        $names = New-Object System.Collections.Generic.List[string]
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
        foreach ($property in $document.RootElement.EnumerateObject()) {
            if (-not $seen.Add($property.Name)) { throw 'Identity-probe request contains a duplicate JSON property.' }
            if (-not $expectedKinds.Contains($property.Name)) { throw 'Identity-probe request contains an unexpected field.' }
            $names.Add($property.Name)
            $expectedKind = [string]$expectedKinds[$property.Name]
            $kindMatches = if ($expectedKind -ceq 'String') {
                $property.Value.ValueKind -eq [System.Text.Json.JsonValueKind]::String
            } else {
                $integerValue = 0
                $expectedKind -ceq 'Int32' -and
                    $property.Value.ValueKind -eq [System.Text.Json.JsonValueKind]::Number -and
                    $property.Value.TryGetInt32([ref]$integerValue)
            }
            if (-not $kindMatches) {
                throw "Identity-probe request property '$($property.Name)' has the wrong primitive ValueKind."
            }
        }
        if ([string]::Join('|', @($names.ToArray() | Sort-Object)) -cne
            [string]::Join('|', @($expectedKinds.Keys | ForEach-Object { [string]$_ } | Sort-Object))) {
            throw 'Identity-probe request fields differ from the exact schema.'
        }
    } finally {
        $document.Dispose()
    }
    return [pscustomobject]@{
        Path = $full
        Sha256 = $actualSha256
        Json = $json
        Payload = ($json | ConvertFrom-Json -DateKind String -ErrorAction Stop)
    }
}

$reportsRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev2')
$requestFull = ConvertTo-QmIdentityProbeFullPath -Path $RequestPath
if (-not (Test-QmIdentityProbePathWithin -Path $requestFull -Root $reportsRoot) -or
    -not (Test-Path -LiteralPath $requestFull -PathType Leaf)) {
    throw 'Identity-probe request escaped the DEV2 report root or is missing.'
}
Assert-QmIdentityProbeNoReparseComponents -Path $requestFull
$requestRecord = Read-QmIdentityProbeRequest -Path $requestFull -ExpectedSha256 $ExpectedRequestSha256
$request = $requestRecord.Payload
if ([int]$request.schema_version -ne 1 -or
    [string]$request.artifact_type -cne 'QM_DEV2_IDENTITY_PROBE_REQUEST' -or
    [string]$request.expected_account -cne "$env:COMPUTERNAME\QMDev2" -or
    [string]$request.expected_sid -cnotmatch '^S-1-5-21-[0-9]+-[0-9]+-[0-9]+-[0-9]+$' -or
    [string]$request.expected_task_name -cnotmatch '^QM_DEV2_SMOKE_[0-9a-f]{32}$' -or
    [string]$request.nonce -cnotmatch '^[0-9a-f]{32}$') {
    throw 'Identity-probe request schema or identity binding drifted.'
}
$created = [DateTimeOffset]::ParseExact(
    [string]$request.created_utc, 'o', [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::RoundtripKind
)
$expires = [DateTimeOffset]::ParseExact(
    [string]$request.expires_utc, 'o', [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::RoundtripKind
)
$now = [DateTimeOffset]::UtcNow
if ($created.Offset -ne [TimeSpan]::Zero -or $expires.Offset -ne [TimeSpan]::Zero -or
    $created -gt $now.AddMinutes(1) -or $expires -le $now -or $expires -gt $created.AddMinutes(15)) {
    throw 'Identity-probe request time window is invalid.'
}
$resultFull = ConvertTo-QmIdentityProbeFullPath -Path ([string]$request.result_path)
if (-not (Test-QmIdentityProbePathWithin -Path $resultFull -Root $reportsRoot) -or
    (Test-Path -LiteralPath $resultFull)) {
    throw 'Identity-probe result path escaped DEV2 reports or is not fresh.'
}
$resultParent = [System.IO.Path]::GetDirectoryName($resultFull)
Assert-QmIdentityProbeNoReparseComponents -Path $resultParent
$expectedProfile = ConvertTo-QmIdentityProbeFullPath -Path ([string]$request.expected_profile)

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
$profile = ConvertTo-QmIdentityProbeFullPath -Path $env:USERPROFILE
if ($null -eq $identity.User -or $identity.User.Value -cne [string]$request.expected_sid -or
    $identity.Name -cne [string]$request.expected_account -or
    $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator) -or
    -not $profile.Equals($expectedProfile, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Limited identity-probe child did not run as the exact isolated QMDev2 identity.'
}
$afterRecord = Read-QmIdentityProbeRequest -Path $requestFull -ExpectedSha256 $requestRecord.Sha256
if ([string]$afterRecord.Json -cne [string]$requestRecord.Json) {
    throw 'Identity-probe request changed during execution.'
}

$result = [ordered]@{
    schema_version = 1
    artifact_type = 'QM_DEV2_IDENTITY_PROBE_RESULT'
    status = 'PASS'
    completed_utc = [DateTimeOffset]::UtcNow.ToString('o')
    nonce = [string]$request.nonce
    account = $identity.Name
    sid = $identity.User.Value
    profile = $profile
    limited_non_admin = $true
    request_sha256 = $requestRecord.Sha256
}
$temporary = Join-Path $resultParent ('.identity-probe.' + [guid]::NewGuid().ToString('N') + '.tmp')
try {
    [System.IO.File]::WriteAllText(
        $temporary,
        ($result | ConvertTo-Json -Depth 4 -Compress),
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::Move($temporary, $resultFull, $false)
} finally {
    if (Test-Path -LiteralPath $temporary -PathType Leaf) { [System.IO.File]::Delete($temporary) }
}
