# Windows Server 2022 update/reboot policy proposal

Date: 2026-08-13

Status: PROPOSAL ONLY — OWNER + Claude change-window approval required

Host: Windows Server 2022 Standard, build 20348

## Decision

Use Windows Server's `Configure Automatic Updates` option **7 — Auto Download,
Notify to install, Notify to Restart**. Keep update installation and reboot as
two explicit OWNER-window actions. Do not create an automatic reboot task.

This is the smallest policy that matches the NOT-REBOOT doctrine on a headless
trading host. Microsoft specifically recommends option 7 for server devices.
Applicable updates continue to download, but Windows Update does not install or
restart them without operator action. OWNER should pin the manual install and,
when required, reboot to a weekend maintenance window after trading preflight.

No setting in this memo was applied.

## Evidence and incident boundary

Read-only inspection on 2026-08-13 found:

- `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\AUOptions = 3`;
- `NoAutoRebootWithLoggedOnUsers = 1`;
- no scheduled install day/time values and no active-hours policy values.

The existing `NoAutoRebootWithLoggedOnUsers` value is ineffective under this
configuration: Microsoft documents that it applies only with `AUOptions = 4`.
It also protects only a locally signed-in user or an **active** RDP session;
a disconnected RDP session does not qualify.

System events separate two failure classes:

| Local time | Evidence | Classification |
|---|---|---|
| 2026-08-12 23:44:38 | Event 1074, `svchost.exe`, planned service-pack restart | Windows servicing |
| 2026-08-12 23:47:35 | Event 1074, `TrustedInstaller.exe`, planned OS-upgrade restart | Windows servicing |
| 2026-08-13 05:27:32 | Event 1074, `wininit.exe`, reason `0x50006`, `lsass.exe` terminated unexpectedly | critical-process recovery, not an ordinary Windows Update restart |
| 2026-08-13 05:28:59 | Event 6008, prior shutdown unexpected | corroborates the second event as unclean |

The proposed update policy addresses the planned servicing restart. It cannot
prevent a restart caused by LSASS termination, host/power failure, bugcheck, or
an explicit administrator action. The overnight sequence may be related, but
the event records alone do not prove that Windows Update caused the LSASS
failure.

## Exact proposed configuration

Preferred control plane: Local Group Policy, not direct registry editing.

1. Open `gpedit.msc`.
2. Go to `Computer Configuration > Administrative Templates > Windows
   Components > Windows Update > Manage end user experience > Configure
   Automatic Updates`.
3. Set the policy to `Enabled` and choose `7 - Auto Download, Notify to install,
   Notify to Restart`.
4. Leave the following restart policies `Not Configured` so there is one
   restart path:
   - `Turn off auto-restart for updates during active hours`;
   - `No auto-restart with logged on users for scheduled automatic updates
     installations`;
   - `Always automatically restart at the scheduled time`;
   - update/restart deadline policies.
5. Do not configure `ScheduledInstallDay`, `ScheduledInstallTime`, or an
   automatic reboot task. Record the weekend OWNER window in the operating
   calendar/runbook instead.

The policy registry representation is:

```text
Key:   HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU
Value: AUOptions (REG_DWORD) = 7
```

Under option 7, the existing `NoAutoRebootWithLoggedOnUsers` value is not the
authority and should be removed by setting that policy to `Not Configured` in
the same sanctioned change. The proposed verification is `gpresult /scope
computer /v` plus a read-back of the policy key after `gpupdate /force`; neither
command was run as part of this proposal.

## Why the alternatives do not meet the doctrine

### Active hours

Active hours only suppress automatic restarts *inside* the configured range.
Later Windows releases support at most 18 active hours, leaving a daily reboot
window. They cannot express a 24-hour trading-host prohibition and therefore
are not the primary control.

The corresponding values are under
`HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate`:
`SetActiveHours`, `ActiveHoursStart`, and `ActiveHoursEnd`. They are intentionally
not proposed here.

### NoAutoRebootWithLoggedOnUsers

This policy maps to:

```text
Key:   HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU
Value: NoAutoRebootWithLoggedOnUsers (REG_DWORD) = 1
Precondition: AUOptions (REG_DWORD) = 4
```

It is conditional on a qualifying signed-in session, can be overridden by a
user-scheduled restart, and is not reliable for this host's disconnected/headless
operating pattern. The current `AUOptions = 3` means the value is presently not
providing its advertised protection.

### Automatic Saturday install

If OWNER explicitly prefers unattended installation over strict no-reboot
control, the bounded alternative is `AUOptions = 4` with:

```text
ScheduledInstallEveryWeek (REG_DWORD) = 1
ScheduledInstallDay       (REG_DWORD) = 7   # Saturday
ScheduledInstallTime      (REG_DWORD) = <OWNER-approved local hour, 0-23>
NoAutoRebootWithLoggedOnUsers (REG_DWORD) = 1
```

This is not the recommended setting. If no qualifying user is signed in,
Windows can restart after the scheduled installation. It is a weekend-window
policy, not an absolute reboot prohibition.

## Sanctioned application and rollback

Before application, OWNER + Claude should:

1. Confirm the exact weekend window and that T_Live/FTMO exposure is handled by
   the live-operations runbook. This memo grants no terminal or AutoTrading
   authority.
2. Export the current policy key for rollback:
   `reg export HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate
   <OWNER-approved-backup-path> /y`.
3. Apply option 7 through Local Group Policy, run `gpupdate /force`, and verify
   the effective computer policy and registry read-back.
4. Confirm Windows Update shows downloaded updates awaiting install and no
   automatic restart deadline.

Rollback is to restore the exported policy key or set `Configure Automatic
Updates` back to its captured prior state. The observed prior registry state was
`AUOptions = 3`, `NoAutoRebootWithLoggedOnUsers = 1`, with schedule values
absent. Returning to that state also returns to the reboot risk documented
above; rollback must therefore occur only in an OWNER window with a replacement
control ready.

## Residual risks

- Security fixes remain downloaded but uninstalled until the OWNER window;
  missed windows create patch-latency risk.
- Domain GPO, MDM, WSUS tooling, compliance deadlines, or a servicing tool can
  supersede local policy. Effective policy must be checked after every change.
- An administrator can still explicitly install/restart, and an OS upgrade
  launched outside Windows Update's ordinary automatic path may have its own
  reboot behavior.
- This policy does not prevent critical-process, bugcheck, power, hypervisor,
  or hardware restarts. The LSASS event needs separate root-cause handling if a
  routed task requests it.
- A sanctioned reboot still requires normal shutdown/recovery verification; no
  policy makes live trading reboot-safe by itself.

## Microsoft references

- [Manage device restarts after updates](https://learn.microsoft.com/en-us/windows/deployment/update/waas-restart)
- [Configure Group Policy settings for Automatic Updates (applies to Windows Server 2022)](https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/deploy/4-configure-group-policy-settings-for-automatic-updates)
- [Manage additional Windows Update settings](https://learn.microsoft.com/en-us/windows/deployment/update/waas-wu-settings)
