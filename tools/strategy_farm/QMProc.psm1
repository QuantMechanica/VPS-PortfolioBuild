# QMProc.psm1 — Shared process-query helpers for QuantMechanica factory scripts.
#
# WHY THIS EXISTS
# ---------------
# Factory_OFF, Factory_ON, factory_watchdog, and purge scripts each contained
# hand-rolled Get-CimInstance queries to find terminal64.exe / pythonw.exe
# processes, all with subtly different path-anchor patterns and T_Live guards.
# A single wrong filter could accidentally kill the live T_Live terminal.
# This module provides one tested, T_Live-safe implementation used everywhere.
#
# USAGE
#   Import-Module (Join-Path $PSScriptRoot 'QMProc.psm1') -Force
#   $procs = Get-QMFactoryProcesses -Terminal T3 -ProcessName terminal64.exe
#
# HARD RULES (enforced in every query):
#   - Always anchors to D:\QM\mt5\<Terminal>\ in CommandLine (path-anchored).
#   - Always excludes T_Live via -notmatch 'T_Live' (T_Live isolation hard rule).
#   - Returns CIM process objects; callers use Stop-Process / .ProcessId as needed.

function Get-QMFactoryProcesses {
    <#
    .SYNOPSIS
        Return CIM Win32_Process objects for a specific factory terminal slot.
    .PARAMETER Terminal
        Terminal slot name, e.g. T1, T3, T10.  Must match the directory under
        D:\QM\mt5\.  Validated against ^T([1-9]|10)$ to prevent accidental
        T_Live matches.
    .PARAMETER ProcessName
        Process executable to query (default: terminal64.exe).
        Use 'python.exe OR pythonw.exe' for worker daemons, via separate calls or
        a caller-side filter.
    .EXAMPLE
        $dead = Get-QMFactoryProcesses -Terminal T5 | Where-Object { ... }
        $dead | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^T([1-9]|10)$')]
        [string]$Terminal,

        [string]$ProcessName = 'terminal64.exe'
    )

    # Guard: refuse T_Live at the parameter level.  ValidatePattern above already
    # enforces the T1-T10 pattern, but belt-and-suspenders.
    if ($Terminal -eq 'T_Live') {
        throw "Get-QMFactoryProcesses: T_Live is explicitly excluded (T_Live isolation hard rule)."
    }

    # Escape the terminal name for use in a WQL filter and regex.
    $escapedTerminal = [regex]::Escape($Terminal)
    # Path-anchor: only processes whose CommandLine contains D:\QM\mt5\Tn\ (or T1\ etc).
    # The -notmatch 'T_Live' guard is redundant given ValidatePattern but kept for safety.
    return @(
        Get-CimInstance Win32_Process -Filter "Name='$ProcessName'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -match "\\mt5\\$escapedTerminal\\" -and
            $_.CommandLine -notmatch 'T_Live'
        }
    )
}

Export-ModuleMember -Function Get-QMFactoryProcesses
