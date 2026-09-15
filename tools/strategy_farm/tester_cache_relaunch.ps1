# Pure relaunch verification helpers for tester_cache_purge.ps1.
#
# The purge supplies idempotent launch/probe/journal scriptblocks so this logic
# can be exercised without starting or stopping a real worker.  The recovery
# contract is exact: every factory worker present before maintenance must be
# present afterwards, and no unplanned terminal may appear.

function ConvertTo-NormalizedFactoryWorkerSet {
    param([string[]]$Terminals)
    return @($Terminals |
        ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } |
        Where-Object { $_ -match '^T(?:[1-9]|10)$' } |
        Sort-Object -Unique)
}

function Compare-FactoryWorkerSet {
    param(
        [string[]]$Expected,
        [string[]]$Running
    )
    $expectedSet = @(ConvertTo-NormalizedFactoryWorkerSet -Terminals $Expected)
    $runningSet = @(ConvertTo-NormalizedFactoryWorkerSet -Terminals $Running)
    $missing = @($expectedSet | Where-Object { $_ -notin $runningSet })
    $unexpected = @($runningSet | Where-Object { $_ -notin $expectedSet })
    return [pscustomobject]@{
        expected = $expectedSet
        running = $runningSet
        missing = $missing
        unexpected = $unexpected
        matched = ($missing.Count -eq 0 -and $unexpected.Count -eq 0)
    }
}

function Invoke-VerifiedFactoryWorkerRelaunch {
    param(
        [string[]]$Expected,
        [scriptblock]$Launch,
        [scriptblock]$Probe,
        [scriptblock]$Journal,
        [ValidateRange(0, 300)]
        [int]$SettleSeconds = 10
    )
    $lastOutcome = $null
    foreach ($attempt in 1..2) {
        $launchStatus = 'PASS'
        $launchEvidence = ''
        $launchError = ''
        try {
            $launchEvidence = [string](& $Launch)
        } catch {
            $launchStatus = 'FAIL'
            $launchError = $_.Exception.Message
        }
        if ($SettleSeconds -gt 0) { Start-Sleep -Seconds $SettleSeconds }

        $probeStatus = 'PASS'
        $probeError = ''
        $running = @()
        try {
            $running = @(& $Probe)
        } catch {
            $probeStatus = 'FAIL'
            $probeError = $_.Exception.Message
        }
        $comparison = Compare-FactoryWorkerSet -Expected $Expected -Running $running
        $matched = (
            $launchStatus -eq 'PASS' -and
            $probeStatus -eq 'PASS' -and
            $comparison.matched
        )
        $lastOutcome = [pscustomobject]@{
            attempt = $attempt
            expected = @($comparison.expected)
            running = @($comparison.running)
            missing = @($comparison.missing)
            unexpected = @($comparison.unexpected)
            matched = $matched
            launch_status = $launchStatus
            launch_error = $launchError
            launch_evidence = $launchEvidence
            probe_status = $probeStatus
            probe_error = $probeError
        }
        & $Journal $lastOutcome
        if ($matched) { return $lastOutcome }
    }
    return $lastOutcome
}
