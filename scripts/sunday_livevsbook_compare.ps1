<#
  Sunday live-vs-book reconciliation (OWNER request 2026-07-08).
  Compares T_Live live trading against the book (backtest) expectation via the
  read-only live-vs-book comparator (portfolio_live_forward_from_logs.py) and writes a
  dated report for the Sunday dual-book admission session. Does NOT touch trading state.

  Wired as scheduled task QM_NewBook_LiveVsBook_Sunday (one-time 2026-07-12).
  CADENCE STAYS SUNDAY. Promotion to a daily / money-gate cadence requires the E4' fixtures
  + read-only historical replay to pass Codex review AND an OWNER decision (ULTRACODE WS-E4).

  E4' repair (2026-07-26): the comparator is bound to ONE signed manifest (by SHA256) and an
  explicit deployment epoch, filters the live logs to exactly that book's EA/magic/symbol
  identities, matches the observation window on ts_utc, derives ATTACHMENT / TELEMETRY /
  ACTIVITY as three INDEPENDENT per-sleeve states, and takes the drawdown reference ONLY
  from a SUM-of-sleeves Monte-Carlo bound to this book (no placeholder). Incomplete inputs
  produce UNKNOWN sections, never a silent green.

  E4' round-2 (Codex WS-E4 CHANGES-REQUIRED): the default -Manifest now points at the
  SIGNED, OWNER-approved live manifest (status LIVE + approved_by), NOT a DRAFT. Binding a
  DRAFT manifest by SHA does not make it signed; -RequireSigned refuses an unsigned manifest.
  The default DXZ live book composition is identical across the signed live manifest and the
  07-19 draft (same 24 ea/symbol/magic tuples), so the epoch stays the 2026-07-19 go-live.

  SP-A2 (2026-08-22): -Manifest / -DeploymentEpoch default from the authenticated runtime
  deploy pointer (D:\QM\reports\state\live_deployment_pointer.json) instead of a hardcoded
  path+date here -- the prior hardcoded 07-19 epoch drifted from the actual deployed book
  (the 24-sleeve manifest was generated 07-24) and required manual re-pointing on every
  new-book deploy, which is exactly the "own 24-sleeve default that can silently drift"
  problem the pointer exists to close. -RequireSigned now defaults to $true (was an opt-in
  switch, unenforced on the scheduled-task path); pass -RequireSigned:$false to explicitly
  bypass for ad-hoc/manual runs. Explicit -Manifest/-DeploymentEpoch args still override the
  pointer (e.g. to inspect a candidate not-yet-signed manifest by hand).
#>
[CmdletBinding()]
param(
    [string]$Manifest        = $null,   # default: read from the runtime pointer below
    [string]$DeploymentEpoch = $null,   # default: read from the runtime pointer below
    [long]  $ExpectedAccount = 4000090541,   # DXZ live account (decisions/2026-07-19_t_live_dxz_sunday_final_book.md)
    [string]$McArtifact      = '',            # bound SUM-of-sleeves MC; empty -> DD check UNKNOWN (never placeholder)
    [bool]  $RequireSigned   = $true,         # refuse (exit 2) unless the manifest is SIGNED; explicit $false to bypass
    [string]$LogDir          = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM',
    [string]$OutDir          = 'D:\QM\reports\portfolio\live_burnin'
)

$ErrorActionPreference = 'Stop'
$py    = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$tool  = 'C:\QM\repo\tools\strategy_farm\portfolio\portfolio_live_forward_from_logs.py'
$stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$date  = (Get-Date).ToString('yyyyMMdd')
$out   = Join-Path $OutDir "livevsbook_sunday_$date.json"
$log   = 'D:\QM\reports\state\sunday_livevsbook_compare.log'

if ([string]::IsNullOrWhiteSpace($Manifest) -or [string]::IsNullOrWhiteSpace($DeploymentEpoch)) {
    # Regex extraction (not ConvertFrom-Json property access): PowerShell auto-coerces
    # ISO-8601-looking JSON string values into [datetime] and re-renders them in the
    # current culture's date format on interpolation, which the Python comparator's
    # datetime.fromisoformat() cannot parse. Regex keeps the literal bytes.
    $Pointer = 'D:\QM\reports\state\live_deployment_pointer.json'
    if (-not (Test-Path $Pointer)) {
        throw "sunday_livevsbook_compare: no -Manifest/-DeploymentEpoch given and runtime deploy pointer missing ($Pointer) -- refusing to guess."
    }
    $pointerRaw = Get-Content -Raw -Path $Pointer
    if ([string]::IsNullOrWhiteSpace($Manifest) -and $pointerRaw -match '"manifest_path"\s*:\s*"([^"]*)"') {
        $Manifest = $Matches[1] -replace '\\\\', '\'
    }
    if ([string]::IsNullOrWhiteSpace($DeploymentEpoch) -and $pointerRaw -match '"deployment_epoch_utc"\s*:\s*"([^"]*)"') {
        $DeploymentEpoch = $Matches[1]
    }
    if ([string]::IsNullOrWhiteSpace($Manifest) -or [string]::IsNullOrWhiteSpace($DeploymentEpoch)) {
        throw "sunday_livevsbook_compare: pointer at $Pointer is missing manifest_path or deployment_epoch_utc -- refusing to guess."
    }
}

if (-not (Test-Path $Manifest)) { throw "manifest not found: $Manifest" }
$manifestSha = (Get-FileHash -Algorithm SHA256 -Path $Manifest).Hash.ToLower()

# Signed-manifest deploy-stamp: SIGNED iff status in {LIVE,APPROVED,SIGNED,DEPLOYED} AND
# (signed=true OR approved_by present). Logged for the audit trail; a DRAFT is UNSIGNED.
try {
    $mf = Get-Content -Raw -Path $Manifest | ConvertFrom-Json
    $mfStatus = "$($mf.status)".ToUpper()
    $mfApprover = if ($mf.approved_by) { $mf.approved_by } else { $mf.declared_approved_by }
    $mfSignedOk = ($mfStatus -in @('LIVE','APPROVED','SIGNED','DEPLOYED')) -and `
                  ((($null -ne $mf.signed) -and [bool]$mf.signed) -or ($mfApprover))
    $mfLabel = if ($mfSignedOk) { 'SIGNED' } elseif ($mfStatus -eq 'DRAFT') { 'DRAFT' } else { 'UNSIGNED' }
} catch {
    $mfStatus = 'UNPARSEABLE'; $mfSignedOk = $false; $mfLabel = 'UNSIGNED'
}

"$stamp  START sunday live-vs-book compare -> $out" | Out-File -Append -Encoding utf8 $log
"$stamp  manifest=$Manifest sha256=$manifestSha epoch=$DeploymentEpoch account=$ExpectedAccount" |
    Out-File -Append -Encoding utf8 $log
"$stamp  manifest_signature=$mfLabel status=$mfStatus signed=$mfSignedOk require_signed=$RequireSigned" |
    Out-File -Append -Encoding utf8 $log

if ($RequireSigned -and (-not $mfSignedOk)) {
    "$stamp  REFUSED: --RequireSigned set but manifest is $mfLabel (status=$mfStatus)." |
        Out-File -Append -Encoding utf8 $log
    throw "manifest is $mfLabel (status=$mfStatus); refusing under -RequireSigned. Binding a manifest by SHA does not make it signed."
}

# Bind the exact identity set + deployment epoch. No placeholder MC: the drawdown check is
# UNKNOWN unless a manifest-bound SUM-of-sleeves reference is supplied via -McArtifact.
$argsList = @(
    $tool,
    '--manifest', $Manifest,
    '--deployment-epoch', $DeploymentEpoch,
    '--expected-account', $ExpectedAccount,
    '--log-dir', $LogDir,
    '--generated-at-utc', $stamp,
    '--out', $out
)
if ($McArtifact -and (Test-Path $McArtifact)) {
    $argsList += @('--mc-artifact', $McArtifact)
}
if ($RequireSigned) {
    $argsList += '--require-signed'
}

# PS 5.1: with ErrorActionPreference=Stop, python's harmless stderr warning
# ("Could not find platform independent libraries") became a terminating
# NativeCommandError via 2>&1 and killed the run right after START.
$ErrorActionPreference = 'Continue'
& $py @argsList 2>&1 |
    Tee-Object -Variable result | Out-File -Append -Encoding utf8 $log
"$stamp  DONE exit=$LASTEXITCODE" | Out-File -Append -Encoding utf8 $log
