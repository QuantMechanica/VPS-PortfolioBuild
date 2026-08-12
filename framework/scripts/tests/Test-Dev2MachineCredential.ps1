[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$helperPath = Join-Path $repoRoot 'framework\scripts\dev2_machine_credential.ps1'
$probePath = Join-Path $repoRoot 'framework\scripts\probe_dev2_machine_credential.ps1'
$rotationPath = Join-Path $repoRoot 'framework\scripts\rotate_dev2_machine_credential.ps1'
$identityProbePath = Join-Path $repoRoot 'framework\scripts\invoke_dev2_identity_probe.ps1'
foreach ($path in @($helperPath, $probePath, $rotationPath, $identityProbePath)) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -ne 0) { throw "PowerShell parse failure in $path" }
}
$identityTokens = $null
$identityErrors = $null
$identityAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $identityProbePath, [ref]$identityTokens, [ref]$identityErrors
)
if (@($identityErrors).Count -ne 0) { throw 'Identity-probe script has parse errors.' }
function Get-QmIdentityProbeFunctionText {
    param([Parameter(Mandatory = $true)][string]$Name)
    $functionAst = $identityAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $Name
    }, $true)
    if ($null -eq $functionAst) { throw "Identity-probe function is missing: $Name" }
    return $functionAst.Extent.Text
}
. $helperPath

$target = Get-LocalUser -Name 'QMDev2' -ErrorAction Stop
$targetAccount = "$env:COMPUTERNAME\QMDev2"
$contractId = 'QM_DEV2_ISOLATED_MT5_LANE_V3'
$lane = 'DEV2'
$testRoot = [System.IO.Path]::GetFullPath((Join-Path 'C:\QM\tmp' ("dev2-machine-credential-test-$([guid]::NewGuid().ToString('N'))")))
$allowedTestPrefix = [System.IO.Path]::GetFullPath('C:\QM\tmp\dev2-machine-credential-test-')
if (-not $testRoot.StartsWith($allowedTestPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Temporary machine-credential test root escaped its fixed prefix.'
}
$artifactPath = Join-Path $testRoot 'credential.machine-dpapi.json'
$dummyPassword = 'QmTest!9-' + [guid]::NewGuid().ToString('N')
try {
    [void][System.IO.Directory]::CreateDirectory($testRoot)
    $created = New-QmDev2MachineCredentialArtifact -CredentialPath $artifactPath -Password $dummyPassword `
        -ExpectedAccount $targetAccount -ExpectedSid $target.SID.Value -ContractId $contractId -Lane $lane
    if ([string]$created.DpapiScope -cne 'LocalMachine' -or [string]$created.Sha256 -cnotmatch '^[0-9a-f]{64}$') {
        throw 'Machine-credential creation did not return its redacted LocalMachine binding.'
    }
    Assert-QmDev2CredentialExactAcl -Path $testRoot -Directory
    Assert-QmDev2CredentialExactAcl -Path $artifactPath
    $credential = Get-QmDev2MachineCredential -CredentialPath $artifactPath `
        -ExpectedCredentialSha256 $created.Sha256 -ExpectedAccount $targetAccount `
        -ExpectedSid $target.SID.Value -ContractId $contractId -Lane $lane
    try {
        if ($credential.UserName -cne $targetAccount -or $credential.Password.Length -le 0) {
            throw 'Machine-credential round trip returned the wrong redacted identity.'
        }
    } finally {
        $credential.Password.Dispose()
    }

    $rejected = $false
    try {
        Get-QmDev2MachineCredential -CredentialPath $artifactPath -ExpectedCredentialSha256 ('0' * 64) `
            -ExpectedAccount $targetAccount -ExpectedSid $target.SID.Value -ContractId $contractId -Lane $lane | Out-Null
    } catch { $rejected = $true }
    if (-not $rejected) { throw 'Wrong expected credential SHA-256 was accepted.' }

    $validArtifactJson = [System.IO.File]::ReadAllText($artifactPath, [System.Text.UTF8Encoding]::new($false, $true))
    $validPayload = $validArtifactJson | ConvertFrom-Json -DateKind String -ErrorAction Stop
    $artifactTypeText = [string]$validPayload.artifact_type
    foreach ($malformed in @(
            $validArtifactJson.Replace('"schema_version":1', '"schema_version":true'),
            $validArtifactJson.Replace('"schema_version":1', '"schema_version":"1"'),
            $validArtifactJson.Replace(
                ('"artifact_type":"' + $artifactTypeText + '"'),
                ('"artifact_type":["' + $artifactTypeText + '"]')
            ),
            $validArtifactJson.Replace('"schema_version":1', '"schema_version":1,"schema_version":1')
        )) {
        if ($malformed -ceq $validArtifactJson) { throw 'Malformed credential ValueKind fixture did not change the JSON.' }
        [System.IO.File]::WriteAllText($artifactPath, $malformed, [System.Text.UTF8Encoding]::new($false))
        Set-QmDev2CredentialExactAcl -Path $artifactPath
        $malformedSha = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $rejected = $false
        try {
            Read-QmDev2MachineCredentialEnvelope -CredentialPath $artifactPath `
                -ExpectedCredentialSha256 $malformedSha -ExpectedAccount $targetAccount `
                -ExpectedSid $target.SID.Value -ContractId $contractId -Lane $lane | Out-Null
        } catch { $rejected = $true }
        if (-not $rejected) { throw 'Credential envelope accepted a wrong primitive ValueKind or duplicate field.' }
    }
    $ciphertextText = [string]$validPayload.ciphertext_base64
    $nonCanonicalCiphertext = $ciphertextText.Substring(0, 4) + ' ' + $ciphertextText.Substring(4)
    $nonCanonicalJson = $validArtifactJson.Replace($ciphertextText, $nonCanonicalCiphertext)
    [System.IO.File]::WriteAllText($artifactPath, $nonCanonicalJson, [System.Text.UTF8Encoding]::new($false))
    Set-QmDev2CredentialExactAcl -Path $artifactPath
    $nonCanonicalSha = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $rejected = $false
    try {
        Get-QmDev2MachineCredential -CredentialPath $artifactPath -ExpectedCredentialSha256 $nonCanonicalSha `
            -ExpectedAccount $targetAccount -ExpectedSid $target.SID.Value -ContractId $contractId -Lane $lane | Out-Null
    } catch { $rejected = $true }
    if (-not $rejected) { throw 'Credential decrypt accepted whitespace-bearing noncanonical Base64.' }
    [System.IO.File]::WriteAllText($artifactPath, $validArtifactJson, [System.Text.UTF8Encoding]::new($false))
    Set-QmDev2CredentialExactAcl -Path $artifactPath

    Invoke-Expression (Get-QmIdentityProbeFunctionText -Name 'ConvertTo-QmIdentityProbeFullPath')
    Invoke-Expression (Get-QmIdentityProbeFunctionText -Name 'Assert-QmIdentityProbeNoReparseComponents')
    Invoke-Expression (Get-QmIdentityProbeFunctionText -Name 'Read-QmIdentityProbeRequest')
    $identityRequestPath = Join-Path $testRoot 'identity_probe_request.json'
    $identityRequest = [ordered]@{
        schema_version = 1
        artifact_type = 'QM_DEV2_IDENTITY_PROBE_REQUEST'
        nonce = '1' * 32
        created_utc = [DateTimeOffset]::UtcNow.ToString('o')
        expires_utc = [DateTimeOffset]::UtcNow.AddMinutes(10).ToString('o')
        expected_account = $targetAccount
        expected_sid = $target.SID.Value
        expected_profile = 'C:\Users\QMDev2'
        expected_task_name = 'QM_DEV2_SMOKE_' + ('2' * 32)
        result_path = Join-Path $testRoot 'identity_probe_result.json'
    }
    $validRequestJson = $identityRequest | ConvertTo-Json -Depth 4 -Compress
    foreach ($case in @(
            @{ Json = $validRequestJson; Valid = $true },
            @{ Json = $validRequestJson.Replace('"schema_version":1', '"schema_version":true'); Valid = $false },
            @{ Json = $validRequestJson.Replace('"schema_version":1', '"schema_version":"1"'); Valid = $false },
            @{ Json = $validRequestJson.Replace(
                    ('"expected_account":"' + $targetAccount.Replace('\', '\\') + '"'),
                    ('"expected_account":["' + $targetAccount.Replace('\', '\\') + '"]')
                ); Valid = $false },
            @{ Json = $validRequestJson.Replace('"nonce":"' + ('1' * 32) + '"',
                    '"nonce":"' + ('1' * 32) + '","nonce":"' + ('1' * 32) + '"'); Valid = $false }
        )) {
        [System.IO.File]::WriteAllText($identityRequestPath, [string]$case.Json, [System.Text.UTF8Encoding]::new($false))
        $requestSha = (Get-FileHash -LiteralPath $identityRequestPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $accepted = $true
        try { $null = Read-QmIdentityProbeRequest -Path $identityRequestPath -ExpectedSha256 $requestSha } catch { $accepted = $false }
        if ($accepted -ne [bool]$case.Valid) { throw 'Identity request strict ValueKind/duplicate regression failed.' }
    }
    [System.IO.File]::WriteAllBytes($identityRequestPath, [byte[]]@(0x7b, 0xff, 0x7d))
    $invalidUtf8Sha = (Get-FileHash -LiteralPath $identityRequestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $rejected = $false
    try { $null = Read-QmIdentityProbeRequest -Path $identityRequestPath -ExpectedSha256 $invalidUtf8Sha } catch { $rejected = $true }
    if (-not $rejected) { throw 'Identity request reader accepted malformed UTF-8.' }

    $payload = Get-Content -LiteralPath $artifactPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $ciphertext = [string]$payload.ciphertext_base64
    $payload.ciphertext_base64 = $(if ($ciphertext[0] -ceq 'A') { 'B' } else { 'A' }) + $ciphertext.Substring(1)
    [System.IO.File]::WriteAllText(
        $artifactPath, ($payload | ConvertTo-Json -Depth 4 -Compress), [System.Text.UTF8Encoding]::new($false)
    )
    Set-QmDev2CredentialExactAcl -Path $artifactPath
    $tamperedSha = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $rejected = $false
    try {
        Get-QmDev2MachineCredential -CredentialPath $artifactPath -ExpectedCredentialSha256 $tamperedSha `
            -ExpectedAccount $targetAccount -ExpectedSid $target.SID.Value -ContractId $contractId -Lane $lane | Out-Null
    } catch { $rejected = $true }
    if (-not $rejected) { throw 'Tampered DPAPI ciphertext was accepted.' }

    $usersSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545')
    $acl = Get-Acl -LiteralPath $artifactPath
    $readRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $usersSid, [System.Security.AccessControl.FileSystemRights]::Read,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    [void]$acl.AddAccessRule($readRule)
    Set-Acl -LiteralPath $artifactPath -AclObject $acl
    $rejected = $false
    try { Assert-QmDev2CredentialExactAcl -Path $artifactPath } catch { $rejected = $true }
    if (-not $rejected) { throw 'Credential ACL accepted an additional BUILTIN\Users reader.' }
    Set-QmDev2CredentialExactAcl -Path $artifactPath

    $helperSha = (Get-FileHash -LiteralPath $helperPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-QmDev2CredentialHelperBinding -HelperPath $helperPath -ExpectedSha256 $helperSha | Out-Null

    $probeText = Get-Content -LiteralPath $probePath -Raw
    $expectedReceiptFields = @(
        'schema_version', 'artifact_type', 'status', 'created_utc', 'worker_principal_sid',
        'expected_account', 'credential_account_sid', 'credential_path', 'credential_sha256',
        'helper_path', 'helper_sha256', 'native_counting_boundary_crossed',
        'dev2_run_directory_created', 'metatester_started'
    )
    foreach ($field in $expectedReceiptFields) {
        if (-not $probeText.Contains("$field =", [System.StringComparison]::Ordinal)) {
            throw "Preclaim probe receipt field is missing: $field"
        }
    }
    foreach ($forbidden in @('Enable-LocalUser', 'Register-ScheduledTask', 'Start-ScheduledTask', 'run_dev2_smoke.ps1')) {
        if ($probeText.Contains($forbidden, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Preclaim decrypt-only probe crossed a forbidden boundary: $forbidden"
        }
    }
} finally {
    $dummyPassword = $null
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = [System.IO.Path]::GetFullPath($testRoot)
        if (-not $resolved.StartsWith($allowedTestPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to remove an escaped temporary credential-test root.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
    }
}

Write-Host 'PASS Test-Dev2MachineCredential'
