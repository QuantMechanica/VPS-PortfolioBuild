[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CredentialPath,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ExpectedCredentialSha256,
    [Parameter(Mandatory = $true)]
    [string]$HelperPath,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ExpectedHelperSha256,
    [Parameter(Mandatory = $true)]
    [string]$ReceiptPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$fixedCredentialPath = [System.IO.Path]::GetFullPath('C:\ProgramData\QM\DEV1\credential.machine-dpapi.json')
$fixedHelperPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'dev1_machine_credential.ps1'))
$contractId = 'QM_DEV1_ISOLATED_MT5_LANE_V3'
$lane = 'DEV1'
$targetUser = 'QMDev1'

function ConvertTo-QmProbeFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.IndexOfAny([char[]]@([char]13, [char]10, [char]0)) -ge 0) {
        throw 'Probe path is empty or contains CR, LF, or NUL.'
    }
    return [System.IO.Path]::GetFullPath($Path.Replace('/', '\'))
}

function Assert-QmProbeNoReparseComponents {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = ConvertTo-QmProbeFullPath -Path $Path
    if (-not (Test-Path -LiteralPath $full)) { throw "Required probe path does not exist: $full" }
    $root = [System.IO.Path]::GetPathRoot($full)
    $cursor = $root
    foreach ($part in @($full.Substring($root.Length).Split('\', [System.StringSplitOptions]::RemoveEmptyEntries))) {
        $cursor = Join-Path $cursor $part
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point is forbidden in a probe path: $cursor"
        }
    }
}

function Get-QmProbeDev1MetatesterCount {
    $expected = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV1\metatester64.exe')
    return @(
        Get-CimInstance -ClassName Win32_Process -Property ProcessId,ExecutablePath,CreationDate -ErrorAction Stop |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace([string]$_.ExecutablePath) -and
                [System.IO.Path]::GetFullPath([string]$_.ExecutablePath).Equals(
                    $expected, [System.StringComparison]::OrdinalIgnoreCase
                )
            }
    ).Count
}

$credentialFull = ConvertTo-QmProbeFullPath -Path $CredentialPath
$helperFull = ConvertTo-QmProbeFullPath -Path $HelperPath
$receiptFull = ConvertTo-QmProbeFullPath -Path $ReceiptPath
if (-not $credentialFull.Equals($fixedCredentialPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Preclaim probe CredentialPath differs from the fixed DEV1 machine credential path.'
}
if (-not $helperFull.Equals($fixedHelperPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Preclaim probe HelperPath differs from the fixed DEV1 credential helper path.'
}
foreach ($leaf in @($credentialFull, $helperFull)) {
    if (-not (Test-Path -LiteralPath $leaf -PathType Leaf)) { throw "Preclaim probe input is not a file: $leaf" }
    Assert-QmProbeNoReparseComponents -Path $leaf
}
$actualHelperSha256 = (Get-FileHash -LiteralPath $helperFull -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
if ($actualHelperSha256 -cne $ExpectedHelperSha256) {
    throw 'Preclaim probe helper SHA-256 differs from the expected binding.'
}
. $helperFull
Assert-QmDev1CredentialHelperBinding -HelperPath $helperFull -ExpectedSha256 $ExpectedHelperSha256 | Out-Null

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
if ($null -eq $identity.User -or -not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Preclaim credential probe requires the elevated persistent worker identity.'
}
$target = Get-LocalUser -Name $targetUser -ErrorAction Stop
if ($target.Name -cne $targetUser -or $target.Enabled -or -not $target.PasswordRequired) {
    throw 'Preclaim credential probe requires QMDev1 disabled-at-rest and password-required.'
}
if ((Get-QmProbeDev1MetatesterCount) -ne 0) {
    throw 'Preclaim credential probe found a running DEV1 metatester before decrypt.'
}

$expectedQualifiedAccount = "$env:COMPUTERNAME\$targetUser"
$credential = Get-QmDev1MachineCredential -CredentialPath $credentialFull `
    -ExpectedCredentialSha256 $ExpectedCredentialSha256 -ExpectedAccount $expectedQualifiedAccount `
    -ExpectedSid $target.SID.Value -ContractId $contractId -Lane $lane
try {
    if ($credential.UserName -cne $expectedQualifiedAccount -or $credential.Password.Length -le 0) {
        throw 'Preclaim credential probe decrypted an identity that differs from QMDev1.'
    }
} finally {
    if ($null -ne $credential) { $credential.Password.Dispose() }
    $credential = $null
}

if ((Get-QmProbeDev1MetatesterCount) -ne 0) {
    throw 'Preclaim credential probe observed a DEV1 metatester after decrypt.'
}
$actualCredentialSha256 = (Get-FileHash -LiteralPath $credentialFull -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
$actualHelperSha256 = (Get-FileHash -LiteralPath $helperFull -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
if ($actualCredentialSha256 -cne $ExpectedCredentialSha256 -or $actualHelperSha256 -cne $ExpectedHelperSha256) {
    throw 'Preclaim credential/helper binding changed after decrypt.'
}
Assert-QmDev1CredentialHelperBinding -HelperPath $helperFull -ExpectedSha256 $ExpectedHelperSha256 | Out-Null
$targetAfter = Get-LocalUser -Name $targetUser -ErrorAction Stop
if ($targetAfter.Enabled -or $targetAfter.SID.Value -cne $target.SID.Value) {
    throw 'Preclaim credential probe changed the disabled-at-rest DEV1 identity.'
}

$receiptParent = [System.IO.Path]::GetDirectoryName($receiptFull)
if (-not (Test-Path -LiteralPath $receiptParent -PathType Container)) {
    throw 'Preclaim probe ReceiptPath parent must already exist.'
}
Assert-QmProbeNoReparseComponents -Path $receiptParent
if (Test-Path -LiteralPath $receiptFull) {
    throw 'Preclaim probe ReceiptPath must be fresh.'
}
$receipt = [ordered]@{
    schema_version = 1
    artifact_type = 'QM_DEV1_MACHINE_CREDENTIAL_PRECLAIM_PROBE'
    status = 'PASS'
    created_utc = [DateTimeOffset]::UtcNow.ToString('o')
    worker_principal_sid = $identity.User.Value
    expected_account = 'QMDev1'
    credential_account_sid = $target.SID.Value
    credential_path = $credentialFull
    credential_sha256 = $actualCredentialSha256
    helper_path = $helperFull
    helper_sha256 = $actualHelperSha256
    native_counting_boundary_crossed = $false
    dev1_run_directory_created = $false
    metatester_started = $false
}
$temporaryPath = Join-Path $receiptParent ('.' + [System.IO.Path]::GetFileName($receiptFull) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
try {
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        ($receipt | ConvertTo-Json -Depth 4 -Compress),
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::Move($temporaryPath, $receiptFull, $false)
} finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
        [System.IO.File]::Delete($temporaryPath)
    }
}
Write-Output 'PASS QM_DEV1_MACHINE_CREDENTIAL_PRECLAIM_PROBE'
