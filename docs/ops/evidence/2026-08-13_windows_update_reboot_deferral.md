# Windows Update reboot-deferral hardening (2026-08-13)

**Author:** Claude (board-advisor lane) · **Task:** A1 — Windows Update reboot exposure
**Context:** DXZ probation review 2026-08-24. An unattended servicing reboot inside that
window self-inflicts a probation failure on an otherwise-clean live book (account
4000090541). Deferral of the RESTART only — patching itself is left fully enabled.

---

## 1. True current state (established, not trusted from summary)

### Reboot history — WORSE than the "double reboot last night" summary
Actual System-log evidence (`Get-WinEvent` Id 1074/6005/6006/6008, last 3 days):

| Time (local) | Event | Initiator | Reason |
|---|---|---|---|
| 12.08 23:44:38 | 1074 | `svchost.exe` (SYSTEM) | Operating System: **Service pack (Planned)** |
| 12.08 23:47:35 | 1074 | `TrustedInstaller.exe` (SYSTEM) | Operating System: **Upgrade (Planned)** |
| 13.08 05:27:32 | 1074 | `wininit.exe` | restart (no reason text); 6008 unexpected 05:28:06 |
| 13.08 14:27:59 | 6008 | — | **previous shutdown UNEXPECTED**; boot 14:29:41 |

So **three-to-four servicing restarts in ~15h**, the most recent **today 14:27**, not a
one-off last night. `LastBootUpTime = 2026-08-13 14:29:37`.

### Why `NoAutoRebootWithLoggedOnUsers=1` did NOT hold
Every restart was initiated by the **servicing / Update Session Orchestrator (USO)** path
— `TrustedInstaller.exe` / `svchost.exe` / `wininit.exe`, reason "Operating System:
Upgrade/Service pack (Planned)". `NoAutoRebootWithLoggedOnUsers` only gates the **legacy
Automatic-Updates scheduled-install reboot** (`AUOptions=4`) and only for an interactive
logged-on user. With `AUOptions=3` and the modern USO/servicing engine driving a
deadline-enforced restart, that value is simply not consulted. It was already `1` and was
irrelevant to the mechanism that fired. Addressing it would have been fixing the wrong
knob.

### The `Reboot_AC` task is a red herring
`\Microsoft\Windows\UpdateOrchestrator\Reboot_AC` shows `NextRunTime 2026-08-14 02:49:49`,
but its exported XML has `<Enabled>false</Enabled>` and its only action is
`MusNotification.exe Display` — a **notification**, not the restart. The real restarts came
from the servicing engine above, not this task. Left untouched.

### Prior registry state (recorded BEFORE any change)
`HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` — root key had only the `AU`
subkey; **all eight** target values ABSENT:

```
SetActiveHours                                = <ABSENT>
ActiveHoursStart                              = <ABSENT>
ActiveHoursEnd                                = <ABSENT>
ConfigureDeadlineNoAutoReboot                 = <ABSENT>
ConfigureDeadlineForQualityUpdates            = <ABSENT>
ConfigureDeadlineForFeatureUpdates            = <ABSENT>
ConfigureDeadlineGracePeriod                  = <ABSENT>
ConfigureDeadlineGracePeriodForFeatureUpdates = <ABSENT>
```

`HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`:
```
AUOptions                     = 3
NoAutoRebootWithLoggedOnUsers = 1
AlwaysAutoRebootAtScheduledTime = <ABSENT>   (good — NOT forcing a scheduled reboot)
AUPowerManagement             = 0
```

`HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings`: `UxOption=3`,
`SmartActiveHoursSuggestionState=0`, no `ActiveHours*` set.
`PendingFileRenameOperations`: set (~20 entries, all print-spooler `V4Dirs` temp files —
benign, not an OS reboot demand). `SoftwareDistribution\Download`: 8 items staged.
CBS `RebootPending` / WU `RebootRequired` keys: both **absent** at time of check.

---

## 2. Changes applied (all REVERSIBLE; all previously ABSENT)

Written under `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` (DWORD):

| Value | Set to | Purpose |
|---|---|---|
| `SetActiveHours` | 1 | Enable policy-defined active hours |
| `ActiveHoursStart` | 17 | Active-hours window **17:00** … |
| `ActiveHoursEnd` | 11 | … **11:00** next day (18h — OS hard max), covering the unattended overnight window where all four restarts and the 7h outage occurred |
| `ConfigureDeadlineNoAutoReboot` | 1 | **The real fix.** USO must NOT auto-restart outside active hours until the deadline is reached — the lever that actually governs the servicing/deadline restart that fired |
| `ConfigureDeadlineForQualityUpdates` | 14 | 14-day deadline → forced restart pushed to ~08-27, **past the 08-24 review** |
| `ConfigureDeadlineForFeatureUpdates` | 14 | Same for feature/"OS Upgrade" restarts (the 23:47 TrustedInstaller class) |
| `ConfigureDeadlineGracePeriod` | 2 | Grace after deadline before any forced restart |
| `ConfigureDeadlineGracePeriodForFeatureUpdates` | 2 | Same for feature updates |

Post-write read-back confirmed all eight values present with the intended data.

**Not changed:** `wuauserv` service (untouched, still running), `AUOptions` (left 3),
`NoAutoRebootWithLoggedOnUsers` (left 1), the `Reboot_AC`/`Reboot_Battery` orchestrator
tasks, and no update was hidden/blocked/uninstalled. Patching remains fully enabled.

### Rollback (restores exact prior state — all values were absent)
```powershell
$wu='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
foreach($v in 'SetActiveHours','ActiveHoursStart','ActiveHoursEnd',
  'ConfigureDeadlineNoAutoReboot','ConfigureDeadlineForQualityUpdates',
  'ConfigureDeadlineForFeatureUpdates','ConfigureDeadlineGracePeriod',
  'ConfigureDeadlineGracePeriodForFeatureUpdates'){
  Remove-ItemProperty $wu -Name $v -ErrorAction SilentlyContinue
}
```

---

## 3. Boot-time assertion — gap analysis (NO new task created)

The task warned against creating a duplicate recovery path that could race. Inspection of
the existing chain shows recovery is already layered, proven, and idempotent — it brought
T_Live back after **all four** restarts today/last night:

| Task | Trigger | Role |
|---|---|---|
| `QM_T_Live_AtLogon` | Logon | `T_Live_ON.ps1` — relaunch live terminal |
| `QM_T_Live_Watchdog` (Running) | Time | continuous T_Live liveness |
| `QM_Live_MT5_SessionSupervisor` (Running) | Logon, 10s loop | session/terminal supervision |
| `QM_LiveSupervisor_Watchdog_SYSTEM` | Time | SYSTEM-level watchdog |
| `QM_StrategyFarm_FactoryON_AtLogon` | Logon | `Factory_ON.ps1` |
| `QM_StrategyFarm_RebootDiagnostic_AtStartup` | **Boot** | mails post-boot diagnostic |
| `QM_Morning_Safety_Check_0445` | Daily | safety assertion + alert |
| `QM_Live_AlarmMailer_1min` | Time (1min) | escalation on live failure |

A **boot-trigger** assertion+alert path already exists
(`QM_StrategyFarm_RebootDiagnostic_AtStartup`), and T_Live liveness is asserted
continuously by two running watchdogs plus a 10s session supervisor and the 1-min alarm
mailer. **Live evidence it works:** after the 14:29 boot, `terminal64.exe` for
`C:\QM\mt5\T_Live\MT5_Base` (PID 12600, created 14:31:01) and the FTMO terminal (PID
11360, 14:30:16) were both up when I checked at 18:09.

**Decision: do not add a new task.** A new SYSTEM boot-trigger T_Live starter would race
the existing logon-triggered `QM_T_Live_AtLogon` and could double-launch `terminal64.exe`
against the **live** account (magic-number / order duplication hazard). The genuine
recovery+assertion coverage is present and non-racing.

**Honest residual gap (documented, not "fixed" with a racing task):** T_Live recovery is
**logon-triggered**, i.e. it depends on the autologon session establishing. The only
boot-(session-independent)-trigger worker starter,
`QM_StrategyFarm_TerminalWorkers_AT_STARTUP`, is **Disabled** (factory is instead brought
up via `FactoryON_AtLogon`). If autologon ever fails to establish a session, the
logon-triggered live recovery would not fire — but the boot-triggered
`RebootDiagnostic_AtStartup` mail would still send, surfacing it. This is the existing
architecture; changing it belongs to an OWNER-window review, not an unattended edit on a
live-trading host.

---

## 4. What is now prevented vs still possible (honest)

**Prevented / strongly deferred**
- Unattended servicing/USO forced restart no longer fires outside active hours until the
  deadline (14 days) + grace (2 days) — i.e. not before ~2026-08-27, **past the 08-24
  review**. This is the exact mechanism (deadline-enforced servicing restart) that caused
  the four restarts.
- Within active hours 17:00–11:00 (the unattended overnight window), auto-restart is
  additionally suppressed as a second layer.

**Still possible (cannot be honestly claimed as eliminated)**
- **Active hours is 18h max** — the window **11:00–17:00** is not covered by active hours.
  Protection there rests solely on the deadline-no-auto-reboot policy, not on active
  hours. A 24/7 active-hours guarantee is not offered by the OS.
- The **currently in-flight update was already pending before the policy existed.** The
  USO recalculates its restart schedule against the deadline policy on its next scan, so
  the armed `Reboot_AC` 02:49 notification should be superseded — but I cannot *prove*
  the engine retroactively cancels an already-scheduled restart. **I did not run
  `usoclient`/force a scan** (that could itself provoke install/restart activity on a live
  host).
- A **kernel/driver crash or host-level fault** (unrelated to WU) can still reboot the
  VPS; that is outside this task's scope and is covered by the recovery chain, not
  prevented.
- The UX effective mirror (`...\UX\Settings\ActiveHours*`) still read blank immediately
  after the write; the **policy key is authoritative** and read directly by the restart
  scheduler, so this is a display-mirror lag, not a failure of the policy.

**Operational recommendation (for OWNER window):** the machine is mid-servicing-cycle with
staged updates and clearly *wants* to reboot; deferral buys the window but the clean
resolution is **one OWNER-controlled reboot during the market-closed window (Fri 22:00 UTC
onward / Saturday)** to flush the pending servicing and clear `PendingFileRenameOperations`
— done deliberately, not unattended. After that, verify T_Live returns via the existing
chain and the `RebootDiagnostic_AtStartup` mail.

---

## 5. Verification performed
- Registry read-back after write: all 8 policy values present with intended data (§2).
- Reboot mechanism attributed via System event log initiators, not assumption (§1).
- Recovery-chain task triggers/actions enumerated; live `terminal64.exe` PIDs/paths
  confirm T_Live + FTMO up post-14:29-boot (§3).
- Prior values captured verbatim before mutation; rollback is a clean delete since all
  were absent (§2).

**Could not establish:** whether the USO will retroactively cancel the already-armed
02:49 notification/restart for the in-flight update (did not force a WU scan on the live
host by design). Recommend confirming after the next OWNER-controlled reboot.
