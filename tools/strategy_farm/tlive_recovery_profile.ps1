<#
.SYNOPSIS
  Import-safe resolver for the T_Live recovery profile pointer (book cutover 2026-09-20).
.DESCRIPTION
  T_Live_ON.ps1 historically hard-coded the recovery profile (DarwinexZero_V2_LiveOps) and its
  PowerShell verifier (prepare_dxz_v2_liveops_profile.ps1 -VerifyOnly). A book cutover needs
  the launcher to resume a DIFFERENT profile and verify it with the builder's manifest. This
  module resolves that from an optional pointer file and falls back to the historical values
  when the pointer is absent, so the change is inert until the ceremony writes the pointer.

  Pointer (JSON, written by the cutover ceremony, removed = rollback to V2 behaviour):
    D:\QM\reports\state\tlive_recovery_profile.json
    {
      "schema": "qm.tlive-recovery-profile.v1",
      "profile": "DarwinexZero_Book2_LiveOps",
      "verifier": {
        "kind": "python",
        "exe": "C:\\Users\\Administrator\\AppData\\Local\\Programs\\Python\\Python311\\python.exe",
        "args": ["-X", "utf8", "C:\\QM\\repo\\tools\\strategy_farm\\build_tlive_book_profile.py", "verify",
                 "--profile-dir", "C:\\QM\\mt5\\T_Live\\MT5_Base\\MQL5\\Profiles\\Charts\\DarwinexZero_Book2_LiveOps",
                 "--manifest", "C:\\QM\\deploy\\DXZ_V2_20260913\\profile\\DarwinexZero_Book2_LiveOps\\profile_manifest.json"]
      },
      "set_by": "...", "set_at_utc": "...", "decision": "decisions/2026-09-15_owner_freifahrtsschein_scope_1_to_3.md"
    }
  DOT-SOURCING IS SAFE: this file only defines functions.
#>
function Get-TLiveRecoveryProfile {
    [CmdletBinding()]
    param(
        [string]$PointerPath = 'D:\QM\reports\state\tlive_recovery_profile.json',
        [string]$DefaultProfile = 'DarwinexZero_V2_LiveOps',
        [string]$DefaultVerifier = 'C:\QM\repo\tools\strategy_farm\prepare_dxz_v2_liveops_profile.ps1'
    )
    $result = [ordered]@{
        source        = 'default'
        profile       = $DefaultProfile
        verifier_kind = 'ps1'
        verifier_exe  = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        verifier_args = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $DefaultVerifier, '-VerifyOnly')
        pointer_path  = $PointerPath
        error         = $null
    }
    if (-not (Test-Path -LiteralPath $PointerPath -PathType Leaf)) { return [pscustomobject]$result }
    try {
        $raw = Get-Content -LiteralPath $PointerPath -Raw -Encoding UTF8
        $ptr = $raw | ConvertFrom-Json
        if ($ptr.schema -ne 'qm.tlive-recovery-profile.v1') { throw "unexpected schema '$($ptr.schema)'" }
        if (-not $ptr.profile -or ($ptr.profile -notmatch '^[A-Za-z0-9_.-]+$')) { throw 'profile name missing or off-contract' }
        if (-not $ptr.verifier -or -not $ptr.verifier.kind) { throw 'verifier block missing' }
        $kind = [string]$ptr.verifier.kind
        if ($kind -eq 'python') {
            if (-not $ptr.verifier.exe -or -not (Test-Path -LiteralPath $ptr.verifier.exe -PathType Leaf)) { throw 'python verifier exe missing' }
            $result.verifier_kind = 'python'
            $result.verifier_exe = [string]$ptr.verifier.exe
            $result.verifier_args = @($ptr.verifier.args | ForEach-Object { [string]$_ })
        } elseif ($kind -eq 'ps1') {
            if (-not $ptr.verifier.path -or -not (Test-Path -LiteralPath $ptr.verifier.path -PathType Leaf)) { throw 'ps1 verifier path missing' }
            $result.verifier_kind = 'ps1'
            $result.verifier_args = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', [string]$ptr.verifier.path) + @($ptr.verifier.args | ForEach-Object { [string]$_ })
        } else { throw "unsupported verifier kind '$kind'" }
        $result.profile = [string]$ptr.profile
        $result.source = 'pointer'
    } catch {
        # Fail CLOSED: a broken pointer must not silently fall back to the old book.
        $result.source = 'pointer_invalid'
        $result.error = $_.Exception.Message
    }
    return [pscustomobject]$result
}
