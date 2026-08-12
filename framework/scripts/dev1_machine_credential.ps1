Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:QmDev1CredentialArtifactType = 'QM_DEV1_MACHINE_DPAPI_CREDENTIAL'
$script:QmDev1CredentialArtifactSchema = 1
$script:QmDev1CredentialDpapiScope = 'LocalMachine'
$script:QmDev1CredentialAdminSid = 'S-1-5-32-544'
$script:QmDev1CredentialSystemSid = 'S-1-5-18'

function ConvertTo-QmDev1CredentialFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.IndexOfAny([char[]]@([char]13, [char]10, [char]0)) -ge 0) {
        throw 'DEV1 credential path is empty or contains CR, LF, or NUL.'
    }
    return [System.IO.Path]::GetFullPath($Path.Replace('/', '\'))
}

function Resolve-QmDev1CredentialSid {
    param([Parameter(Mandatory = $true)][string]$AccountName)
    $normalized = if ($AccountName.StartsWith('.\', [System.StringComparison]::Ordinal)) {
        "$env:COMPUTERNAME\$($AccountName.Substring(2))"
    } else {
        $AccountName
    }
    return (New-Object System.Security.Principal.NTAccount($normalized)).Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value
}

function Get-QmDev1HostAccountDomainSid {
    param([Parameter(Mandatory = $true)][string]$TargetSid)
    if ($TargetSid -notmatch '^(?<domain>S-1-5-21-[0-9]+-[0-9]+-[0-9]+)-[0-9]+$') {
        throw 'QMDev1 must be a local account with a machine account-domain SID.'
    }
    return [string]$Matches.domain
}

function Assert-QmDev1CredentialNoReparseComponents {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = ConvertTo-QmDev1CredentialFullPath -Path $Path
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Required DEV1 credential path does not exist: $full"
    }
    $root = [System.IO.Path]::GetPathRoot($full)
    $cursor = $root
    foreach ($part in @($full.Substring($root.Length).Split('\', [System.StringSplitOptions]::RemoveEmptyEntries))) {
        $cursor = Join-Path $cursor $part
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse points are forbidden in the DEV1 credential path: $cursor"
        }
    }
}

function Set-QmDev1CredentialExactAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$Directory
    )
    $full = ConvertTo-QmDev1CredentialFullPath -Path $Path
    Assert-QmDev1CredentialNoReparseComponents -Path $full
    $acl = Get-Acl -LiteralPath $full -ErrorAction Stop
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) {
        [void]$acl.RemoveAccessRuleAll($rule)
    }
    $admin = New-Object System.Security.Principal.SecurityIdentifier($script:QmDev1CredentialAdminSid)
    $system = New-Object System.Security.Principal.SecurityIdentifier($script:QmDev1CredentialSystemSid)
    $acl.SetOwner($admin)
    $inheritance = if ($Directory.IsPresent) {
        [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
            [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    } else {
        [System.Security.AccessControl.InheritanceFlags]::None
    }
    foreach ($sid in @($admin, $system)) {
        $access = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $sid,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            $inheritance,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        [void]$acl.AddAccessRule($access)
    }
    Set-Acl -LiteralPath $full -AclObject $acl -ErrorAction Stop
    Assert-QmDev1CredentialExactAcl -Path $full -Directory:$Directory.IsPresent
}

function Assert-QmDev1CredentialExactAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$Directory
    )
    $full = ConvertTo-QmDev1CredentialFullPath -Path $Path
    Assert-QmDev1CredentialNoReparseComponents -Path $full
    $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
    if ($Directory.IsPresent -and -not $item.PSIsContainer) {
        throw "Expected a DEV1 credential directory: $full"
    }
    if (-not $Directory.IsPresent -and $item.PSIsContainer) {
        throw "Expected a DEV1 credential file: $full"
    }
    $acl = Get-Acl -LiteralPath $full -ErrorAction Stop
    if (-not $acl.AreAccessRulesProtected) {
        throw "DEV1 credential ACL inheritance is not disabled: $full"
    }
    $ownerSid = Resolve-QmDev1CredentialSid -AccountName $acl.Owner
    if ($ownerSid -cne $script:QmDev1CredentialAdminSid) {
        throw "DEV1 credential ACL owner is not BUILTIN\Administrators: $full"
    }
    $rules = @($acl.Access)
    if ($rules.Count -ne 2) {
        throw "DEV1 credential ACL must contain exactly two access rules: $full"
    }
    $expectedSids = @($script:QmDev1CredentialAdminSid, $script:QmDev1CredentialSystemSid) | Sort-Object
    $actualSids = New-Object System.Collections.Generic.List[string]
    $expectedInheritance = if ($Directory.IsPresent) {
        [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
            [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    } else {
        [System.Security.AccessControl.InheritanceFlags]::None
    }
    foreach ($rule in $rules) {
        $sid = Resolve-QmDev1CredentialSid -AccountName $rule.IdentityReference.Value
        $actualSids.Add($sid)
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow -or
            $rule.IsInherited -or
            [int64]$rule.FileSystemRights -ne [int64][System.Security.AccessControl.FileSystemRights]::FullControl -or
            $rule.InheritanceFlags -ne $expectedInheritance -or
            $rule.PropagationFlags -ne [System.Security.AccessControl.PropagationFlags]::None) {
            throw "DEV1 credential ACL contains a non-exact access rule: $full"
        }
    }
    if ([string]::Join('|', @($actualSids.ToArray() | Sort-Object)) -cne [string]::Join('|', $expectedSids)) {
        throw "DEV1 credential ACL identities differ from Administrators and SYSTEM: $full"
    }
    Assert-QmDev1CredentialNoReparseComponents -Path $full
}

function Initialize-QmDev1CredentialDirectory {
    param([Parameter(Mandatory = $true)][string]$DirectoryPath)
    $full = ConvertTo-QmDev1CredentialFullPath -Path $DirectoryPath
    if (-not (Test-Path -LiteralPath $full)) {
        [void][System.IO.Directory]::CreateDirectory($full)
    }
    Assert-QmDev1CredentialNoReparseComponents -Path $full
    Set-QmDev1CredentialExactAcl -Path $full -Directory
    return $full
}

function Get-QmDev1MachineCredentialEntropy {
    param(
        [Parameter(Mandatory = $true)][string]$ContractId,
        [Parameter(Mandatory = $true)][string]$Lane,
        [Parameter(Mandatory = $true)][string]$HostAccountDomainSid,
        [Parameter(Mandatory = $true)][string]$TargetSid
    )
    if ($ContractId -cne 'QM_DEV1_ISOLATED_MT5_LANE_V3' -or $Lane -cne 'DEV1') {
        throw 'DEV1 credential entropy requires the exact V3 lane contract.'
    }
    if ((Get-QmDev1HostAccountDomainSid -TargetSid $TargetSid) -cne $HostAccountDomainSid) {
        throw 'DEV1 credential entropy host account-domain SID does not bind the target SID.'
    }
    $context = @(
        'QM_DEV1_MACHINE_DPAPI_ENTROPY_V1',
        "contract_id=$ContractId",
        "lane=$Lane",
        "host_account_domain_sid=$HostAccountDomainSid",
        "target_sid=$TargetSid"
    ) -join "`n"
    $contextBytes = [System.Text.UTF8Encoding]::new($false, $true).GetBytes($context)
    try {
        return [System.Security.Cryptography.SHA256]::HashData($contextBytes)
    } finally {
        [System.Array]::Clear($contextBytes, 0, $contextBytes.Length)
    }
}

function Assert-QmDev1Sha256 {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($Value -cnotmatch '^[0-9a-f]{64}$') {
        throw "$Label must be a lowercase SHA-256 value."
    }
}

function Read-QmDev1CredentialBoundFileBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256,
        [ValidateRange(1, 1048576)][int]$MinimumBytes = 1,
        [ValidateRange(1, 1048576)][int]$MaximumBytes = 1048576
    )
    Assert-QmDev1Sha256 -Value $ExpectedSha256 -Label 'ExpectedCredentialSha256'
    if ($MinimumBytes -gt $MaximumBytes) { throw 'Credential input minimum size exceeds its maximum size.' }
    $full = ConvertTo-QmDev1CredentialFullPath -Path $Path
    Assert-QmDev1CredentialNoReparseComponents -Path $full
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "DEV1 credential input is not a file: $full"
    }
    $stream = [System.IO.File]::Open(
        $full,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::None
    )
    try {
        if ($stream.Length -lt $MinimumBytes -or $stream.Length -gt $MaximumBytes) {
            throw "DEV1 credential input size is outside its strict bound: $full"
        }
        $bytes = [byte[]]::new([int]$stream.Length)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $read = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($read -le 0) { throw "DEV1 credential input ended before its declared length: $full" }
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
        throw 'Exact DEV1 credential input bytes differ from their expected SHA-256 binding.'
    }
    Assert-QmDev1CredentialNoReparseComponents -Path $full
    return [pscustomobject]@{
        Path = $full
        Sha256 = $actualSha256
        Bytes = $bytes
    }
}

function Assert-QmDev1CredentialHelperBinding {
    param(
        [Parameter(Mandatory = $true)][string]$HelperPath,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )
    Assert-QmDev1Sha256 -Value $ExpectedSha256 -Label 'ExpectedHelperSha256'
    $full = ConvertTo-QmDev1CredentialFullPath -Path $HelperPath
    Assert-QmDev1CredentialNoReparseComponents -Path $full
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "DEV1 credential helper is not a file: $full"
    }
    $actual = (Get-FileHash -LiteralPath $full -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($actual -cne $ExpectedSha256) {
        throw 'DEV1 credential helper SHA-256 differs from the expected binding.'
    }
    return $actual
}

function Read-QmDev1MachineCredentialEnvelope {
    param(
        [Parameter(Mandatory = $true)][string]$CredentialPath,
        [Parameter(Mandatory = $true)][string]$ExpectedCredentialSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedAccount,
        [Parameter(Mandatory = $true)][string]$ExpectedSid,
        [Parameter(Mandatory = $true)][string]$ContractId,
        [Parameter(Mandatory = $true)][string]$Lane
    )
    Assert-QmDev1Sha256 -Value $ExpectedCredentialSha256 -Label 'ExpectedCredentialSha256'
    $full = ConvertTo-QmDev1CredentialFullPath -Path $CredentialPath
    $parent = [System.IO.Path]::GetDirectoryName($full)
    Assert-QmDev1CredentialExactAcl -Path $parent -Directory
    Assert-QmDev1CredentialExactAcl -Path $full
    $byteRecord = Read-QmDev1CredentialBoundFileBytes -Path $full `
        -ExpectedSha256 $ExpectedCredentialSha256 -MinimumBytes 32 -MaximumBytes 65536
    try {
        $json = [System.Text.UTF8Encoding]::new($false, $true).GetString($byteRecord.Bytes)
    } finally {
        [System.Array]::Clear($byteRecord.Bytes, 0, $byteRecord.Bytes.Length)
    }
    $document = [System.Text.Json.JsonDocument]::Parse($json)
    try {
        if ($document.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            throw 'DEV1 machine credential artifact is not a JSON object.'
        }
        $names = New-Object System.Collections.Generic.List[string]
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
        $expectedKinds = [ordered]@{
            account = 'String'
            artifact_type = 'String'
            ciphertext_base64 = 'String'
            contract_id = 'String'
            created_utc = 'String'
            dpapi_scope = 'String'
            generation_id = 'String'
            host_account_domain_sid = 'String'
            lane = 'String'
            schema_version = 'Int32'
            target_sid = 'String'
            text_encoding = 'String'
        }
        foreach ($property in $document.RootElement.EnumerateObject()) {
            if (-not $seen.Add($property.Name)) {
                throw 'DEV1 machine credential artifact contains a duplicate JSON property.'
            }
            $names.Add($property.Name)
            if (-not $expectedKinds.Contains($property.Name)) {
                throw 'DEV1 machine credential artifact contains an unexpected JSON property.'
            }
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
                throw "DEV1 machine credential property '$($property.Name)' has the wrong primitive ValueKind."
            }
        }
        $expectedNames = @($expectedKinds.Keys | ForEach-Object { [string]$_ } | Sort-Object)
        if ([string]::Join('|', @($names.ToArray() | Sort-Object)) -cne [string]::Join('|', $expectedNames)) {
            throw 'DEV1 machine credential artifact fields differ from the exact schema.'
        }
    } finally {
        $document.Dispose()
    }
    $payload = $json | ConvertFrom-Json -DateKind String -ErrorAction Stop
    $hostAccountDomainSid = Get-QmDev1HostAccountDomainSid -TargetSid $ExpectedSid
    if ([int]$payload.schema_version -ne $script:QmDev1CredentialArtifactSchema -or
        [string]$payload.artifact_type -cne $script:QmDev1CredentialArtifactType -or
        [string]$payload.contract_id -cne $ContractId -or
        [string]$payload.lane -cne $Lane -or
        [string]$payload.account -cne $ExpectedAccount -or
        [string]$payload.target_sid -cne $ExpectedSid -or
        [string]$payload.host_account_domain_sid -cne $hostAccountDomainSid -or
        [string]$payload.dpapi_scope -cne $script:QmDev1CredentialDpapiScope -or
        [string]$payload.text_encoding -cne 'UTF-8' -or
        [string]$payload.generation_id -cnotmatch '^[0-9a-f]{32}$') {
        throw 'DEV1 machine credential artifact identity or cryptographic scope drifted.'
    }
    $created = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParseExact(
            [string]$payload.created_utc,
            'o',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind,
            [ref]$created
        ) -or $created.Offset -ne [TimeSpan]::Zero -or $created -gt [DateTimeOffset]::UtcNow.AddMinutes(5)) {
        throw 'DEV1 machine credential artifact has an invalid UTC creation time.'
    }
    if ((Resolve-QmDev1CredentialSid -AccountName $ExpectedAccount) -cne $ExpectedSid) {
        throw 'DEV1 machine credential expected account no longer resolves to its bound SID.'
    }
    Assert-QmDev1CredentialExactAcl -Path $parent -Directory
    Assert-QmDev1CredentialExactAcl -Path $full
    return [pscustomobject]@{
        Path = $full
        Sha256 = $byteRecord.Sha256
        Account = [string]$payload.account
        TargetSid = [string]$payload.target_sid
        HostAccountDomainSid = [string]$payload.host_account_domain_sid
        ContractId = [string]$payload.contract_id
        Lane = [string]$payload.lane
        GenerationId = [string]$payload.generation_id
        CreatedUtc = $created
        CiphertextBase64 = [string]$payload.ciphertext_base64
    }
}

function Get-QmDev1MachineCredential {
    param(
        [Parameter(Mandatory = $true)][string]$CredentialPath,
        [Parameter(Mandatory = $true)][string]$ExpectedCredentialSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedAccount,
        [Parameter(Mandatory = $true)][string]$ExpectedSid,
        [Parameter(Mandatory = $true)][string]$ContractId,
        [Parameter(Mandatory = $true)][string]$Lane
    )
    $envelope = Read-QmDev1MachineCredentialEnvelope @PSBoundParameters
    $ciphertext = $null
    $entropy = $null
    $plaintextBytes = $null
    $password = $null
    $securePassword = $null
    try {
        if ($envelope.CiphertextBase64.Length -lt 44 -or $envelope.CiphertextBase64.Length -gt 43692) {
            throw 'DEV1 machine credential ciphertext text length is outside the strict Base64 bound.'
        }
        try {
            $ciphertext = [System.Convert]::FromBase64String($envelope.CiphertextBase64)
        } catch [System.FormatException] {
            throw 'DEV1 machine credential ciphertext is not strict Base64.'
        }
        if ([System.Convert]::ToBase64String($ciphertext) -cne $envelope.CiphertextBase64) {
            throw 'DEV1 machine credential ciphertext is not canonical Base64.'
        }
        if ($ciphertext.Length -lt 32 -or $ciphertext.Length -gt 32768) {
            throw 'DEV1 machine credential ciphertext size is outside the strict bound.'
        }
        $entropy = Get-QmDev1MachineCredentialEntropy -ContractId $ContractId -Lane $Lane `
            -HostAccountDomainSid $envelope.HostAccountDomainSid -TargetSid $ExpectedSid
        try {
            $plaintextBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
                $ciphertext,
                $entropy,
                [System.Security.Cryptography.DataProtectionScope]::LocalMachine
            )
        } catch [System.Security.Cryptography.CryptographicException] {
            throw 'DEV1 machine credential LocalMachine-DPAPI unprotect failed.'
        }
        $password = [System.Text.UTF8Encoding]::new($false, $true).GetString($plaintextBytes)
        if ([string]::IsNullOrEmpty($password) -or $password.Length -gt 1024) {
            throw 'DEV1 machine credential decrypted password length is invalid.'
        }
        $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
        return New-Object System.Management.Automation.PSCredential($ExpectedAccount, $securePassword)
    } finally {
        $password = $null
        if ($null -ne $plaintextBytes) { [System.Array]::Clear($plaintextBytes, 0, $plaintextBytes.Length) }
        if ($null -ne $entropy) { [System.Array]::Clear($entropy, 0, $entropy.Length) }
        if ($null -ne $ciphertext) { [System.Array]::Clear($ciphertext, 0, $ciphertext.Length) }
    }
}

function New-QmDev1MachineCredentialArtifact {
    param(
        [Parameter(Mandatory = $true)][string]$CredentialPath,
        [Parameter(Mandatory = $true)][string]$Password,
        [Parameter(Mandatory = $true)][string]$ExpectedAccount,
        [Parameter(Mandatory = $true)][string]$ExpectedSid,
        [Parameter(Mandatory = $true)][string]$ContractId,
        [Parameter(Mandatory = $true)][string]$Lane
    )
    if ([string]::IsNullOrEmpty($Password) -or $Password.Length -gt 1024) {
        throw 'DEV1 machine credential password length is invalid.'
    }
    if ((Resolve-QmDev1CredentialSid -AccountName $ExpectedAccount) -cne $ExpectedSid) {
        throw 'DEV1 machine credential creation account does not resolve to the expected SID.'
    }
    $full = ConvertTo-QmDev1CredentialFullPath -Path $CredentialPath
    $parent = Initialize-QmDev1CredentialDirectory -DirectoryPath ([System.IO.Path]::GetDirectoryName($full))
    if (Test-Path -LiteralPath $full) {
        throw "DEV1 machine credential artifact already exists: $full"
    }
    $hostAccountDomainSid = Get-QmDev1HostAccountDomainSid -TargetSid $ExpectedSid
    $plainBytes = $null
    $entropy = $null
    $ciphertext = $null
    $temporaryPath = Join-Path $parent ('.credential.machine-dpapi.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $plainBytes = [System.Text.UTF8Encoding]::new($false, $true).GetBytes($Password)
        $entropy = Get-QmDev1MachineCredentialEntropy -ContractId $ContractId -Lane $Lane `
            -HostAccountDomainSid $hostAccountDomainSid -TargetSid $ExpectedSid
        $ciphertext = [System.Security.Cryptography.ProtectedData]::Protect(
            $plainBytes,
            $entropy,
            [System.Security.Cryptography.DataProtectionScope]::LocalMachine
        )
        $generationId = [guid]::NewGuid().ToString('N')
        $payload = [ordered]@{
            schema_version = $script:QmDev1CredentialArtifactSchema
            artifact_type = $script:QmDev1CredentialArtifactType
            contract_id = $ContractId
            lane = $Lane
            account = $ExpectedAccount
            target_sid = $ExpectedSid
            host_account_domain_sid = $hostAccountDomainSid
            dpapi_scope = $script:QmDev1CredentialDpapiScope
            text_encoding = 'UTF-8'
            generation_id = $generationId
            created_utc = [DateTimeOffset]::UtcNow.ToString('o')
            ciphertext_base64 = [System.Convert]::ToBase64String($ciphertext)
        }
        $json = $payload | ConvertTo-Json -Depth 4 -Compress
        [System.IO.File]::WriteAllText($temporaryPath, $json, [System.Text.UTF8Encoding]::new($false))
        Set-QmDev1CredentialExactAcl -Path $temporaryPath
        [System.IO.File]::Move($temporaryPath, $full, $false)
        Set-QmDev1CredentialExactAcl -Path $full
        $sha = (Get-FileHash -LiteralPath $full -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        $probe = Get-QmDev1MachineCredential -CredentialPath $full -ExpectedCredentialSha256 $sha `
            -ExpectedAccount $ExpectedAccount -ExpectedSid $ExpectedSid -ContractId $ContractId -Lane $Lane
        try {
            if ($probe.Password.Length -le 0) {
                throw 'DEV1 machine credential creation round-trip returned an empty secure password.'
            }
        } finally {
            $probe.Password.Dispose()
            $probe = $null
        }
        return [pscustomobject]@{
            Path = $full
            Sha256 = $sha
            GenerationId = $generationId
            TargetSid = $ExpectedSid
            HostAccountDomainSid = $hostAccountDomainSid
            DpapiScope = $script:QmDev1CredentialDpapiScope
        }
    } finally {
        if ($null -ne $plainBytes) { [System.Array]::Clear($plainBytes, 0, $plainBytes.Length) }
        if ($null -ne $entropy) { [System.Array]::Clear($entropy, 0, $entropy.Length) }
        if ($null -ne $ciphertext) { [System.Array]::Clear($ciphertext, 0, $ciphertext.Length) }
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            [System.IO.File]::Delete($temporaryPath)
        }
    }
}
