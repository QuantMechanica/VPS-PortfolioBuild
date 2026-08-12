[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{32}$')]
    [string]$Nonce,
    [Parameter(Mandatory = $true)]
    [string]$ReceiptPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedUser = 'QMDev2'
$expectedProfile = [System.IO.Path]::GetFullPath('C:\Users\QMDev2')
$reportRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev2\provisioning')
$calendarSource = [System.IO.Path]::GetFullPath('D:\QM\data\news_calendar')

function ConvertTo-QmFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path.IndexOfAny([char[]]"`r`n`0") -ge 0) {
        throw 'Path contains CR, LF, or NUL.'
    }
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-QmPathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )
    $fullPath = ConvertTo-QmFullPath -Path $Path
    $fullRoot = (ConvertTo-QmFullPath -Path $Root).TrimEnd('\')
    return $fullPath.StartsWith($fullRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

$ReceiptPath = ConvertTo-QmFullPath -Path $ReceiptPath
if (-not (Test-QmPathWithin -Path $ReceiptPath -Root $reportRoot)) {
    throw 'DEV2 profile receipt escaped its fixed provisioning root.'
}

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$expectedAccount = "$env:COMPUTERNAME\$expectedUser"
if (-not $identity.Name.Equals($expectedAccount, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "DEV2 profile initializer ran as '$($identity.Name)', expected '$expectedAccount'."
}

$actualProfile = ConvertTo-QmFullPath -Path $env:USERPROFILE
$actualAppData = ConvertTo-QmFullPath -Path ([System.Environment]::GetFolderPath(
        [System.Environment+SpecialFolder]::ApplicationData
    ))
if (-not $actualProfile.Equals($expectedProfile, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "DEV2 profile path drifted: $actualProfile"
}
if (-not (Test-QmPathWithin -Path $actualAppData -Root $expectedProfile)) {
    throw "DEV2 AppData escaped its profile: $actualAppData"
}

$commonFiles = Join-Path $actualAppData 'MetaQuotes\Terminal\Common\Files'
New-Item -ItemType Directory -Path $commonFiles -Force -ErrorAction Stop | Out-Null
$calendarRows = New-Object System.Collections.Generic.List[object]
foreach ($name in @('news_calendar_2015_2025.csv', 'forex_factory_calendar_clean.csv')) {
    $source = Join-Path $calendarSource $name
    $destination = Join-Path $commonFiles $name
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required offline calendar is missing: $source"
    }
    if (Test-Path -LiteralPath $destination) {
        throw "Refusing to overwrite unexpected DEV2 Common file: $destination"
    }
    Copy-Item -LiteralPath $source -Destination $destination -ErrorAction Stop
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
    $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sourceHash -cne $destinationHash) {
        throw "Offline calendar hash mismatch after DEV2 profile initialization: $name"
    }
    $calendarRows.Add([ordered]@{
            name = $name
            source_path = $source
            destination_path = $destination
            sha256 = $destinationHash
        })
}

$receipt = [ordered]@{
    schema_version = 1
    status = 'PASS'
    nonce = $Nonce
    account = $identity.Name
    sid = $identity.User.Value
    profile = $actualProfile
    common_path = ConvertTo-QmFullPath -Path (Join-Path $actualAppData 'MetaQuotes\Terminal\Common')
    calendars = $calendarRows.ToArray()
    sensitive_environment_values_persisted = $false
    completed_utc = (Get-Date).ToUniversalTime().ToString('o')
}
$temporary = "$ReceiptPath.$Nonce.tmp"
[System.IO.File]::WriteAllText(
    $temporary,
    ($receipt | ConvertTo-Json -Depth 5),
    (New-Object System.Text.UTF8Encoding($false))
)
Move-Item -LiteralPath $temporary -Destination $ReceiptPath -ErrorAction Stop

