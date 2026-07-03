# QMProc.psm1 — shared terminal-process helpers for QM strategy farm
# Usage: Import-Module C:/QM/repo/tools/strategy_farm/QMProc.psm1
#
# NOTE: Factory_OFF.ps1 uses ad-hoc Get-CimInstance + -notmatch 'T_Live' filters
# directly in its body (lines 75-93). It SHOULD be refactored to use
# Get-QMFactoryProcesses here, but that change is deferred to avoid breaking
# the existing script in this PR. Integration is documented for future refactoring.

function Get-QMFactoryProcesses {
    <#
    .SYNOPSIS
        Get MT5 terminal64 processes for one or all factory terminals (T1-T10).
        Never matches T_Live regardless of filter.

    .PARAMETER Terminal
        Optional. Name like 'T1', 'T2', ... 'T10'. If omitted, returns all T1-T10 processes.

    .EXAMPLE
        Get-QMFactoryProcesses -Terminal T3
        Get-QMFactoryProcesses   # all factory terminals
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Terminal
    )

    # The factory MT5 root is D:\QM\mt5; terminals are T1..T10
    # T_Live is at C:\QM\mt5\T_Live -- always excluded
    $FactoryRoot = 'D:\QM\mt5'

    # Build path pattern(s) to match
    if ($Terminal) {
        # Validate that this is a factory terminal, never T_Live
        if ($Terminal -match '^T_?Live$') {
            Write-Error "Get-QMFactoryProcesses: T_Live is excluded. Use direct path access for live terminal management."
            return
        }
        $paths = @("$FactoryRoot\$Terminal\")
    } else {
        # All T1-T10
        $paths = (1..10) | ForEach-Object { "$FactoryRoot\T$_\" }
    }

    # Get all terminal64 processes and filter by path-anchored command line
    Get-CimInstance -ClassName Win32_Process -Filter "Name='terminal64.exe'" |
        Where-Object {
            $procPath = $_.ExecutablePath
            if (-not $procPath) { return $false }
            # Must be under factory root AND -notmatch T_Live (defense-in-depth)
            ($procPath -like "$FactoryRoot\*") -and
            ($procPath -notmatch [regex]::Escape('T_Live')) -and
            ($paths | Where-Object { $procPath -like "$_*" } | Select-Object -First 1)
        } |
        Select-Object ProcessId, Name, ExecutablePath,
                      @{Name='Terminal'; Expression={
                          if ($_.ExecutablePath -match '\\(T\d+)\\') { $Matches[1] } else { '?' }
                      }}
}

Export-ModuleMember -Function Get-QMFactoryProcesses
