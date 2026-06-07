# Launches Google Drive for desktop (GoogleDriveFS) at qm-admin logon.
#
# Why this exists: Drive's own autostart is an HKCU Run-key, which on a headless
# auto-logon server is held back until an RDP client connects — so the G: vault
# mount is missing after a reboot until OWNER logs in (observed 2026-06-07: boot
# 02:31, Drive only came up 12:44 on RDP connect). A "At log on of qm-admin /
# run only when logged on" scheduled task fires at the boot auto-logon regardless
# of RDP connection. Version-robust: finds the newest installed version folder so
# it survives Drive auto-updates (the Run-key path would otherwise go stale).
$ErrorActionPreference = 'SilentlyContinue'
$base = 'C:\Program Files\Google\Drive File Stream'

if (Get-Process -Name GoogleDriveFS -ErrorAction SilentlyContinue) { return }  # already running

$exe = Get-ChildItem -Path $base -Recurse -Filter 'GoogleDriveFS.exe' -ErrorAction SilentlyContinue |
    Where-Object { $_.Directory.Name -match '^\d+\.\d+' } |
    Sort-Object { try { [version]$_.Directory.Name } catch { [version]'0.0' } } |
    Select-Object -Last 1
if (-not $exe) {
    $exe = Get-ChildItem -Path $base -Recurse -Filter 'GoogleDriveFS.exe' -ErrorAction SilentlyContinue |
        Select-Object -First 1
}
if ($exe) {
    Start-Process -FilePath $exe.FullName -ArgumentList '--startup_mode'
}
