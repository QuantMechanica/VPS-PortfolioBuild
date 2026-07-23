<#
.SYNOPSIS
  Build or verify the operational DXZ V2 profile without changing the sealed V2 profile.

.DESCRIPTION
  DarwinexZero_V2 is the OWNER-approved 24-strategy profile. It intentionally remains
  byte-for-byte sealed. The operational profile adds the proven read-only
  QM_AccountMonitor as chart25 so that deal/equity telemetry survives live recovery.

  Default mode creates DarwinexZero_V2_LiveOps atomically when it does not exist, then
  verifies every sealed file by SHA-256 and the monitor chart/binary by SHA-256.
  -VerifyOnly performs the recovery-time semantic contract check. It still verifies the
  sealed source and monitor binary hashes, but allows MT5 to have saved harmless chart
  window state in the operational profile.
#>
[CmdletBinding()]
param([switch]$VerifyOnly)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$profileRoot = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Profiles\Charts'
$sealedName = 'DarwinexZero_V2'
$operationalName = 'DarwinexZero_V2_LiveOps'
$monitorSourceName = 'DarwinexZero_V1'
$sealedDir = Join-Path $profileRoot $sealedName
$operationalDir = Join-Path $profileRoot $operationalName
$monitorChart = Join-Path (Join-Path $profileRoot $monitorSourceName) 'chart25.chr'
$monitorBinary = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\QM_AccountMonitor.ex5'

$sealedSha256 = [ordered]@{
    'chart01.chr' = 'DA552AF21DAE021F0E714EDA59C4D88108C23E5837AE06F401D601A566803037'
    'chart02.chr' = 'CA94099ABE49A179C01C3ECB3C935AB2BD12754D27ACDDF0A0D143F2A7A153A8'
    'chart03.chr' = '38ED279E42DFD94D811E405A3719F15B8C0274B7DBFBE475C36DC4B1914054A3'
    'chart04.chr' = 'E625E85704C20D801805D1FA2BA845276FD0110685910E60EEF1EBDA85B18F19'
    'chart05.chr' = '1C3A837916EC8B82F09A380BDE96CA02899664DF8CACBF0295BDED79BA563EC7'
    'chart06.chr' = '60DF5DCFBBFF605D3C389C81A4D1E2EFE3DEB121499E55B3577337BCBE03BD2B'
    'chart07.chr' = 'AA7FA3EB04D871E9C0CFA021C1C8D7CD24B40325A32D3E13BFE37A4A3E7DD6DF'
    'chart08.chr' = '0F2ADFFFD4D75B96A13D2AB2773908BADB82AEA3D4ACA7A8D360F08F1842FDB0'
    'chart09.chr' = '7928B8D9A534B626012092D5832BF3861FFB74522A42FD3EB70F79B329658F83'
    'chart10.chr' = 'ECEEC098C1F90F0FF34EE17C8E613178E4F5CDC09236E7C3206679F6784F8187'
    'chart11.chr' = '9F8C33C64EA7CF6C16FCE7A5C45CF47592EB693945D4B21B18AB0E244DA0A30C'
    'chart12.chr' = 'B7D6DFD5F0D07EB4868F99264B59955924A6227175AA340EFFA4376F84631767'
    'chart13.chr' = '60E9A127932FC0EB32F2FF23E2F491F20F7070840194BBBD953D8ACCEA5173D0'
    'chart14.chr' = '9093516CC879599AAED1AA248E2D88C8996B2890D2B10E61A661704E107CA8E6'
    'chart15.chr' = 'E18EB7978AEEE33CE41E080F045120046DFA37F3DD0E077BFF67C5DC7EB586C2'
    'chart16.chr' = 'BD73ECEBFEBFC93339500279F2EACE21D94F1F53FE13A2428413086E39B7B6CE'
    'chart17.chr' = 'BDF9A6C9592AF1D12E4969F5A17088EA0BD7CAED300AD87C72DAFE6416F6CD97'
    'chart18.chr' = '0CC3E3581C76D4C740718F1BA3F489F6C30296B8646CCAB643CCE724DD554D12'
    'chart19.chr' = '7537DD4F059AA2338446CD8400A0311D3E76C85B3EF1D439A012E2E556EB3075'
    'chart20.chr' = 'CC9A674C37E527053EB724E5584B386825EBCE00EF73EFB6A9F19969B0E3DF46'
    'chart21.chr' = '98A7D18FD26EAE966AE41A3B1100B62CE2993829C0F7F3D782AF0EC5D35CA8BE'
    'chart22.chr' = '6100946B76EED6FC27DA266F845D9D618A05BDA47162A4D5BE0EE206E4628E8C'
    'chart23.chr' = '04DE85B50B00D7C442CDB84E737A2004DC27998F7DDA67D9B3835F477071EEC9'
    'chart24.chr' = '97C9B918EDE74008EB5EFDCA31393F26E864507098DCC29471011FF0FD03FBC3'
    'order.wnd' = '515457F605D3B305FF58D051D64CE39AE6B009F5BA18A26532CCA9FA4D30665B'
}
$monitorChartSha256 = '57AA19FF44B8361446D314BEB201BB97D57CC21B6EAACD96852B40147802DDBB'
$monitorBinarySha256 = '8699ADC79BC0448563B6A53D59163EC149A30B6EF767E2F99FE148E5EFB4B9E5'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Sha256 {
    param([string]$Path)
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "missing file: $Path"
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToUpperInvariant()
}

function Assert-ExactFiles {
    param([string]$Directory, [string[]]$ExpectedNames)
    Assert-True (Test-Path -LiteralPath $Directory -PathType Container) "missing directory: $Directory"
    $actual = @((Get-ChildItem -LiteralPath $Directory -File | ForEach-Object Name | Sort-Object))
    $expected = @($ExpectedNames | Sort-Object)
    Assert-True ([string]::Join('|', $actual) -ceq [string]::Join('|', $expected)) (
        "unexpected file set in ${Directory}: " + [string]::Join(', ', $actual)
    )
}

function Get-ChartContract {
    param([string]$Path)
    $text = [IO.File]::ReadAllText($Path)
    $experts = [regex]::Matches($text, '(?ms)<expert>\s*.*?</expert>')
    Assert-True ($experts.Count -eq 1) "expected exactly one expert in $Path"
    $prefix = $text.Substring(0, $experts[0].Index)
    $symbol = [regex]::Match($prefix, '(?m)^symbol=(.+?)\r?$')
    $periodType = [regex]::Match($prefix, '(?m)^period_type=(.+?)\r?$')
    $periodSize = [regex]::Match($prefix, '(?m)^period_size=(.+?)\r?$')
    Assert-True ($symbol.Success -and $periodType.Success -and $periodSize.Success) "chart header incomplete: $Path"
    return [pscustomobject]@{
        symbol = $symbol.Groups[1].Value.Trim()
        period_type = $periodType.Groups[1].Value.Trim()
        period_size = $periodSize.Groups[1].Value.Trim()
        expert = $experts[0].Value.Trim()
    }
}

function Assert-SealedProfile {
    $names = @($sealedSha256.Keys)
    Assert-ExactFiles $sealedDir $names
    foreach ($name in $names) {
        $observed = Get-Sha256 (Join-Path $sealedDir $name)
        Assert-True ($observed -ceq $sealedSha256[$name]) "sealed V2 hash mismatch: $name"
    }
}

function Assert-MonitorContract {
    param([string]$Path, [switch]$RequireFullHash)
    $contract = Get-ChartContract $Path
    Assert-True ($contract.expert -match '(?m)^name=QM_AccountMonitor\r?$') 'monitor name mismatch'
    Assert-True ($contract.expert -match '(?m)^path=Experts\\QM_AccountMonitor\.ex5\r?$') 'monitor path mismatch'
    Assert-True ($contract.expert -match '(?m)^expertmode=1\r?$') 'monitor expertmode mismatch'
    Assert-True ($contract.expert -match '(?m)^InpTimerSeconds=60\r?$') 'monitor timer mismatch'
    Assert-True ($contract.expert -match '(?m)^InpJournalDir=QM\\journal\r?$') 'monitor journal path mismatch'
    Assert-True ($contract.expert -match '(?m)^InpShowPanel=true\r?$') 'monitor panel setting mismatch'
    if ($RequireFullHash) {
        Assert-True ((Get-Sha256 $Path) -ceq $monitorChartSha256) 'monitor chart hash mismatch'
    }
}

function Assert-OperationalProfile {
    param([string]$Directory, [switch]$RequireFullHash)
    $targetNames = @($sealedSha256.Keys) + 'chart25.chr'
    Assert-ExactFiles $Directory $targetNames
    foreach ($name in $sealedSha256.Keys) {
        $target = Join-Path $Directory $name
        if ($RequireFullHash) {
            Assert-True ((Get-Sha256 $target) -ceq $sealedSha256[$name]) "operational copy hash mismatch: $name"
        } elseif ($name -like 'chart*.chr') {
            $sealedContract = Get-ChartContract (Join-Path $sealedDir $name)
            $targetContract = Get-ChartContract $target
            foreach ($field in @('symbol', 'period_type', 'period_size', 'expert')) {
                Assert-True ($targetContract.$field -ceq $sealedContract.$field) "operational contract drift: $name/$field"
            }
        }
    }
    Assert-MonitorContract (Join-Path $Directory 'chart25.chr') -RequireFullHash:$RequireFullHash
}

try {
    Assert-SealedProfile
    Assert-True ((Get-Sha256 $monitorBinary) -ceq $monitorBinarySha256) 'monitor binary hash mismatch'

    if ($VerifyOnly) {
        Assert-OperationalProfile $operationalDir
        Write-Host "VERIFIED: $operationalName = sealed 24-strategy V2 contract + read-only account monitor"
        exit 0
    }

    Assert-MonitorContract $monitorChart -RequireFullHash

    if (Test-Path -LiteralPath $operationalDir) {
        Assert-OperationalProfile $operationalDir
        Write-Host "VERIFIED: existing $operationalName"
        exit 0
    }

    $stagingDir = Join-Path $profileRoot ('.' + $operationalName + '.building.' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stagingDir -ErrorAction Stop | Out-Null
    foreach ($name in $sealedSha256.Keys) {
        Copy-Item -LiteralPath (Join-Path $sealedDir $name) -Destination (Join-Path $stagingDir $name) -ErrorAction Stop
    }
    Copy-Item -LiteralPath $monitorChart -Destination (Join-Path $stagingDir 'chart25.chr') -ErrorAction Stop
    Assert-OperationalProfile $stagingDir -RequireFullHash
    Assert-True (-not (Test-Path -LiteralPath $operationalDir)) "target appeared during build: $operationalDir"
    Move-Item -LiteralPath $stagingDir -Destination $operationalDir -ErrorAction Stop
    Assert-OperationalProfile $operationalDir -RequireFullHash
    Write-Host "CREATED+VERIFIED: $operationalName"
    exit 0
} catch {
    Write-Error "DXZ LiveOps profile preparation failed: $($_.Exception.Message)"
    exit 2
}
