param()

$ErrorActionPreference = 'Stop'
$protocolPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'factory_mutation_lock.ps1'
. $protocolPath

$script:assertions = 0
function Assert-True([bool]$Condition, [string]$Message) {
    $script:assertions += 1
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

function Write-TestLockRecord {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$OwnerProcessId,
        [Parameter(Mandatory = $true)][string]$Owner,
        [Parameter(Mandatory = $true)][string]$Nonce,
        [Parameter(Mandatory = $true)][DateTime]$CreatedAtUtc
    )
    $json = [ordered]@{
        pid = $OwnerProcessId
        owner = $Owner
        nonce = $Nonce
        created_at = $CreatedAtUtc.ToUniversalTime().ToString('o')
    } | ConvertTo-Json -Compress
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("qm_factory_mutation_lock_{0}" -f [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$lockPath = Join-Path $testRoot 'FACTORY_MUTATION.lock'

try {
    $currentProcess = Get-Process -Id $PID -ErrorAction Stop
    Write-TestLockRecord `
        -Path $lockPath `
        -OwnerProcessId $PID `
        -Owner 'powershell-test-live-owner' `
        -Nonce '11111111111111111111111111111111' `
        -CreatedAtUtc ([DateTime]::UtcNow)
    $liveSnapshot = Read-QmFactoryMutationLockSnapshot -Path $lockPath
    Assert-True $liveSnapshot.valid 'current-format lock must parse'
    Assert-True `
        (-not (Wait-QmFactoryMutationLockDrain -Path $lockPath -TimeoutSeconds 0 -PollMilliseconds 0)) `
        'matching live PID/start-time identity must retain the lock'
    Assert-True (Test-Path -LiteralPath $lockPath) 'live lock must remain present'

    # Simulate PID reuse: the current PID is live, but its StartTime is later
    # than the timestamp at which the abandoned lock claims to have been made.
    Write-TestLockRecord `
        -Path $lockPath `
        -OwnerProcessId $PID `
        -Owner 'powershell-test-abandoned-owner' `
        -Nonce '22222222222222222222222222222222' `
        -CreatedAtUtc ($currentProcess.StartTime.ToUniversalTime().AddMinutes(-1))
    Assert-True `
        (Wait-QmFactoryMutationLockDrain -Path $lockPath -TimeoutSeconds 0 -PollMilliseconds 0) `
        'reused live PID must not authenticate an abandoned lock'
    Assert-True (-not (Test-Path -LiteralPath $lockPath)) 'PID-reuse lock must be reaped'

    # Legacy/incomplete records have no authenticated content identity and are
    # therefore never reaped automatically.
    [IO.File]::WriteAllText(
        $lockPath,
        ('{{"pid":{0},"owner":"legacy","created_at":"{1}"}}' -f `
            $PID,[DateTime]::UtcNow.ToString('o')),
        [Text.UTF8Encoding]::new($false)
    )
    $legacySnapshot = Read-QmFactoryMutationLockSnapshot -Path $lockPath
    Assert-True (-not $legacySnapshot.valid) 'nonce-less legacy record must be invalid'
    Assert-True `
        (-not (Wait-QmFactoryMutationLockDrain -Path $lockPath -TimeoutSeconds 0 -PollMilliseconds 0)) `
        'legacy record must remain fail-closed'
    Assert-True (Test-Path -LiteralPath $lockPath) 'legacy record must not be deleted'

    # Exact-byte revalidation protects a replacement lock from a stale reaper.
    Write-TestLockRecord `
        -Path $lockPath `
        -OwnerProcessId ([int]::MaxValue) `
        -Owner 'old-dead-owner' `
        -Nonce '33333333333333333333333333333333' `
        -CreatedAtUtc ([DateTime]::UtcNow)
    $oldSnapshot = Read-QmFactoryMutationLockSnapshot -Path $lockPath
    Write-TestLockRecord `
        -Path $lockPath `
        -OwnerProcessId $PID `
        -Owner 'replacement-live-owner' `
        -Nonce '44444444444444444444444444444444' `
        -CreatedAtUtc ([DateTime]::UtcNow)
    Assert-True `
        (-not (Remove-QmFactoryMutationLockIfUnchanged `
            -Path $lockPath `
            -ExpectedRawBytesBase64 $oldSnapshot.raw_bytes_base64)) `
        'stale snapshot must not delete replacement content'
    $replacement = Read-QmFactoryMutationLockSnapshot -Path $lockPath
    Assert-True ($replacement.nonce -eq '44444444444444444444444444444444') `
        'replacement identity must remain intact'

    Write-TestLockRecord `
        -Path $lockPath `
        -OwnerProcessId ([int]::MaxValue) `
        -Owner 'dead-owner' `
        -Nonce '55555555555555555555555555555555' `
        -CreatedAtUtc ([DateTime]::UtcNow)
    Assert-True `
        (Wait-QmFactoryMutationLockDrain -Path $lockPath -TimeoutSeconds 0 -PollMilliseconds 0) `
        'valid nonce-bound dead-owner lock must be reaped'
    Assert-True (-not (Test-Path -LiteralPath $lockPath)) 'dead-owner lock must be absent'

    Write-TestLockRecord `
        -Path $lockPath `
        -OwnerProcessId ([int]::MaxValue) `
        -Owner 'future-owner' `
        -Nonce '66666666666666666666666666666666' `
        -CreatedAtUtc ([DateTime]::UtcNow.AddMinutes(10))
    $futureSnapshot = Read-QmFactoryMutationLockSnapshot -Path $lockPath
    Assert-True (-not $futureSnapshot.valid) 'future-dated identity must be invalid'
    Assert-True `
        (-not (Wait-QmFactoryMutationLockDrain -Path $lockPath -TimeoutSeconds 0 -PollMilliseconds 0)) `
        'future-dated identity must remain fail-closed'
    Assert-True (Test-Path -LiteralPath $lockPath) 'future-dated lock must remain present'

    Write-Host "Factory mutation-lock tests passed ($script:assertions assertions)"
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
