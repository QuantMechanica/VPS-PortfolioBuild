<#
.SYNOPSIS
    QuantMechanica V5 -- nightly off-drive backup to the Obsidian Vault (G:).

.DESCRIPTION
    Design deliverable (board-advisor, 2026-07-19). Installed later by the operating agent.
    Deliberately a SINGLE self-contained file (no companion .py/.psm1) so deploy = copy one
    file + register one scheduled task. The sqlite backup helper is a Python here-string
    materialized to a transient temp file at run time and deleted afterward.

    Runs as the same principal as the existing, empirically-working G:-writing task
    QM_MorningBriefing_Vault: local user qm-admin (SID ...-500), LogonType=Password (S4U
    "run whether user is logged on or not"). SYSTEM (S-1-5-18) does NOT see the G: mount --
    GoogleDriveFS.exe runs per-user in qm-admin's session (kept alive across reboots by
    QM_GoogleDrive_AtLogon, LogonType=InteractiveToken, logon trigger). See report for the
    empirical evidence trail.

    Order of operations, each step independently try/caught so one failure never aborts the
    rest of the run (task spec: non-fatal error handling):
      (a) farm_state.sqlite -> WAL-consistent ONLINE backup via python sqlite3, source opened
          on a read-only URI (mode=ro). The live farm DB is never opened for writing here.
      (b) T_Live: MT5_Base\Config, MQL5\Presets, MQL5\Profiles, MQL5\Files\QM -> robocopy.
          T_Live is the live-trading terminal; source is read-only, this script never writes
          back into it (robocopy direction is always source -> dest, no /MIR, no /MOV).
      (c) D:\QM\reports\state\{owner_decisions,quota_governor_state,pipeline_state}.json
      (d) framework registries: magic_numbers.csv, ea_id_registry.csv (from the repo checkout;
          read-only source, no repo edits)
    Then rotation: keep the newest -RetentionDays dated (yyyyMMdd) folders directly under
    -DestRoot, delete older ones. Guarded four ways before any Remove-Item:
      1. -DestRoot must literally contain the -RotationAnchor substring ("11 Backups" by
         default) -- a hard-coded sanity anchor independent of whatever -DestRoot resolves to.
      2. Candidate's resolved full path must start with -DestRoot's resolved full path.
      3. Candidate's parent directory must equal -DestRoot exactly (no recursing into
         unexpected nesting).
      4. Candidate directory name must match ^\d{8}$ (only date-stamped backup folders).

    Known-issue note (docs memory 2026-07-13, "PS5.1-stderr-trap kills tasks", fix 43f368e3d):
    on Windows PowerShell 5.1, $ErrorActionPreference='Stop' combined with native-command
    `2>&1` merges turns a benign stderr line (e.g. the embedded Python interpreter's
    "Could not find platform independent libraries <prefix>" notice) into a terminating error
    that kills the whole scheduled task. This script (1) keeps $ErrorActionPreference =
    'Continue' throughout and (2) never merges native stderr via 2>&1 on the python/robocopy
    calls -- exit codes are checked explicitly instead. That combination is what the
    already-working QM_* tasks on this box rely on; do not "fix forward" by adding 2>&1 here.

.PARAMETER DestRoot
    Root backups folder. Each run creates <DestRoot>\<yyyyMMdd>\...
    Defaults to the vault's "11 Backups" folder. Override for dry runs / tests.
.PARAMETER LogPath
    Transcript log file (append mode). Defaults to D:\QM\reports\state\backup_nightly.log.
    Override for dry runs so a test run never touches the real ops log.
.PARAMETER RetentionDays
    How many dated folders to keep under DestRoot. Default 14.
.PARAMETER RotationAnchor
    Literal substring -DestRoot must contain before rotation is allowed to run. Hard-coded
    sanity guard, independent of whatever value -DestRoot actually resolves to. Default
    "11 Backups". Override only for tests where DestRoot points somewhere else safe.
#>
[CmdletBinding()]
param(
    [string]$DestRoot       = "G:\My Drive\QuantMechanica - Company Reference\11 Backups",
    [string]$LogPath        = "D:\QM\reports\state\backup_nightly.log",
    [int]   $RetentionDays  = 14,
    [string]$RotationAnchor = "11 Backups",
    [string]$FarmStateDb    = "D:\QM\strategy_farm\state\farm_state.sqlite",
    [string]$TLiveBase      = "C:\QM\mt5\T_Live\MT5_Base",
    [string]$ReportsStateSrc= "D:\QM\reports\state",
    [string]$RegistrySrc    = "C:\QM\repo\framework\registry",
    [string]$PythonExe      = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe"
)

# One failure must not abort the rest of the nightly run -- see stderr-trap note above.
$ErrorActionPreference = 'Continue'

$scriptStart = Get-Date
$stamp       = $scriptStart.ToString('yyyyMMdd')
$failures    = @()

# 2026-07-20 fix (first scheduled run failed 04:45): the GoogleDriveFS G: mount
# can be transiently absent in a fresh non-interactive qm-admin session (e.g.
# after a console disconnect). Join-Path validates the drive qualifier against
# live PSDrives, so a missing G: made $destDay null and cascaded null-binding
# failures through every step. Wait for the drive before doing anything; the
# 06:00 morning-brief task with the identical principal saw G: fine, so the
# mount returns on its own -- we just have to outwait the gap.
$driveQualifier = ($DestRoot -split ':')[0]
$driveWaitLimit = (Get-Date).AddMinutes(15)
while (-not (Test-Path "${driveQualifier}:\") -and (Get-Date) -lt $driveWaitLimit) {
    Start-Sleep -Seconds 30
}
if (-not (Test-Path "${driveQualifier}:\")) {
    # Distinct, greppable failure line; transcript may not be running yet.
    $msg = "FATAL drive ${driveQualifier}: not available after 15min wait -- GoogleDriveFS mount absent in this session"
    Write-Warning $msg
    Add-Content -Path $LogPath -Value "$((Get-Date).ToString('u')) $msg"
    exit 1
}
$destDay = Join-Path $DestRoot $stamp

function Assert-UnderRoot {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Root)
    $rp = [System.IO.Path]::GetFullPath($Path)
    $rr = [System.IO.Path]::GetFullPath($Root)
    if (-not $rp.StartsWith($rr, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing to touch '$rp' -- not under root '$rr'"
    }
}

New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null
New-Item -ItemType Directory -Force -Path $destDay  | Out-Null

$transcriptOn = $false
try {
    Start-Transcript -Path $LogPath -Append -ErrorAction Stop | Out-Null
    $transcriptOn = $true
} catch {
    Write-Warning "could not start transcript at $LogPath : $($_.Exception.Message)"
}

Write-Output "=== QM nightly backup start $($scriptStart.ToString('u')) ==="
Write-Output "DestRoot=$DestRoot"
Write-Output "DestDay=$destDay"
Write-Output "RetentionDays=$RetentionDays  RotationAnchor='$RotationAnchor'"

# ---- (a) farm_state.sqlite: WAL-consistent online backup, read-only source ----------------
try {
    $sqliteDest = Join-Path $destDay "farm_state_$stamp.sqlite"
    $py = @'
import sqlite3, sys, time
t0 = time.time()
src_path = sys.argv[1].replace("\\", "/")
uri = "file:" + src_path + "?mode=ro"
src = sqlite3.connect(uri, uri=True)
dst = sqlite3.connect(sys.argv[2])
with dst:
    src.backup(dst)
dst.close()
src.close()
print("sqlite backup OK %.1fs" % (time.time() - t0))
'@
    $pyFile = Join-Path $env:TEMP "qm_backup_sqlite_$PID.py"
    Set-Content -Path $pyFile -Value $py -Encoding UTF8
    if (-not (Test-Path $FarmStateDb)) { throw "source missing: $FarmStateDb" }
    & $PythonExe $pyFile $FarmStateDb $sqliteDest
    $rc = $LASTEXITCODE
    Remove-Item $pyFile -Force -ErrorAction SilentlyContinue
    if ($rc -ne 0) { throw "python sqlite backup exited $rc" }
    Write-Output "OK  farm_state.sqlite -> $sqliteDest"
} catch {
    $failures += "sqlite backup: $($_.Exception.Message)"
    Write-Warning "FAIL sqlite backup: $($_.Exception.Message)"
}

# ---- (b) T_Live: config / MQL5 Presets / MQL5 Profiles / MQL5 Files\QM --------------------
# Read-only source. robocopy only ever writes to $job.Dst -- never back into T_Live.
$robocopyJobs = @(
    @{ Src = Join-Path $TLiveBase "Config";       Dst = Join-Path $destDay "T_Live\config" }
    @{ Src = Join-Path $TLiveBase "MQL5\Presets";  Dst = Join-Path $destDay "T_Live\Presets" }
    @{ Src = Join-Path $TLiveBase "MQL5\Profiles"; Dst = Join-Path $destDay "T_Live\Profiles" }
    @{ Src = Join-Path $TLiveBase "MQL5\Files\QM"; Dst = Join-Path $destDay "T_Live\Files_QM" }
)
foreach ($job in $robocopyJobs) {
    try {
        if (-not (Test-Path $job.Src)) { throw "source missing: $($job.Src)" }
        robocopy $job.Src $job.Dst /E /R:1 /W:1 /NFL /NDL /NP /NJH | Out-Null
        $rc = $LASTEXITCODE
        if ($rc -ge 8) { throw "robocopy exit $rc (>=8 = failure)" }
        Write-Output "OK  robocopy '$($job.Src)' -> '$($job.Dst)' (exit $rc)"
    } catch {
        $failures += "robocopy $($job.Src): $($_.Exception.Message)"
        Write-Warning "FAIL robocopy $($job.Src): $($_.Exception.Message)"
    }
}

# ---- (c) D:\QM\reports\state json snapshots -------------------------------------------------
try {
    $reportsDst = Join-Path $destDay "reports_state"
    New-Item -ItemType Directory -Force -Path $reportsDst | Out-Null
    $jsonFiles = @("owner_decisions.json", "quota_governor_state.json", "pipeline_state.json")
    robocopy $ReportsStateSrc $reportsDst $jsonFiles /R:1 /W:1 /NFL /NDL /NP /NJH | Out-Null
    $rc = $LASTEXITCODE
    if ($rc -ge 8) { throw "robocopy exit $rc (>=8 = failure)" }
    Write-Output "OK  reports/state json -> $reportsDst (exit $rc)"
} catch {
    $failures += "reports/state json: $($_.Exception.Message)"
    Write-Warning "FAIL reports/state json: $($_.Exception.Message)"
}

# ---- (d) framework registries (read-only repo checkout, no repo edits) --------------------
try {
    $registryDst = Join-Path $destDay "framework_registry"
    New-Item -ItemType Directory -Force -Path $registryDst | Out-Null
    $regFiles = @("magic_numbers.csv", "ea_id_registry.csv")
    robocopy $RegistrySrc $registryDst $regFiles /R:1 /W:1 /NFL /NDL /NP /NJH | Out-Null
    $rc = $LASTEXITCODE
    if ($rc -ge 8) { throw "robocopy exit $rc (>=8 = failure)" }
    Write-Output "OK  framework registry -> $registryDst (exit $rc)"
} catch {
    $failures += "framework registry: $($_.Exception.Message)"
    Write-Warning "FAIL framework registry: $($_.Exception.Message)"
}

# ---- rotation: keep newest $RetentionDays dated folders directly under $DestRoot ----------
try {
    if ($DestRoot -notlike "*$RotationAnchor*") {
        throw "DestRoot '$DestRoot' does not contain required anchor '$RotationAnchor' -- refusing to rotate"
    }
    Assert-UnderRoot -Path $DestRoot -Root $DestRoot
    $destRootFull = ([System.IO.Path]::GetFullPath($DestRoot)).TrimEnd('\')
    $dated = Get-ChildItem -Path $DestRoot -Directory -ErrorAction Stop |
        Where-Object { $_.Name -match '^\d{8}$' } |
        Sort-Object Name -Descending
    $toDelete = $dated | Select-Object -Skip $RetentionDays
    $deletedCount = 0
    foreach ($d in $toDelete) {
        Assert-UnderRoot -Path $d.FullName -Root $DestRoot
        $parentFull = (Split-Path $d.FullName -Parent)
        if ($parentFull -ne $destRootFull) {
            throw "rotation candidate '$($d.FullName)' is not a direct child of DestRoot -- refusing"
        }
        if ($d.Name -notmatch '^\d{8}$') {
            throw "rotation candidate '$($d.FullName)' does not match yyyyMMdd -- refusing"
        }
        Remove-Item -LiteralPath $d.FullName -Recurse -Force
        Write-Output "ROTATE removed $($d.FullName)"
        $deletedCount++
    }
    Write-Output "OK  rotation: kept $([Math]::Min($RetentionDays,$dated.Count))/$($dated.Count) dated folders, removed $deletedCount"
} catch {
    $failures += "rotation: $($_.Exception.Message)"
    Write-Warning "FAIL rotation: $($_.Exception.Message)"
}

$elapsed = (Get-Date) - $scriptStart
Write-Output "=== QM nightly backup end $((Get-Date).ToString('u')) elapsed=$($elapsed.ToString()) failures=$($failures.Count) ==="
if ($failures.Count -gt 0) {
    Write-Output "Failure detail:"
    $failures | ForEach-Object { Write-Output "  - $_" }
}

if ($transcriptOn) { Stop-Transcript | Out-Null }

exit ([Math]::Min($failures.Count, 1))
