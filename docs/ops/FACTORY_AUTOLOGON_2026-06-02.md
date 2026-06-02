# Factory decoupling from RDP — Autologon console session (2026-06-02)

## Problem

The MT5 backtest factory runs **inside OWNER's interactive RDP session** (visible mode,
directive 2026-05-23). OWNER connects from a **mobile RDP app**, whose flaky link causes
frequent disconnects. A plain disconnect is harmless — the disconnected session keeps
running and the factory with it (verified 2026-06-02: 10 `terminal64` + 10 worker daemons
alive while session 5 was `Getr.`). The danger is a **full session loss**: on 2026-06-02
RDP session 4 was lost entirely (storm of TS code `0x80072746` "forcibly closed by remote
host"; **no** logoff event 23 / Security 4647 — not an explicit sign-out) and Windows
created a fresh empty session 5 at 18:52 → MT5 + terminals gone, looked like a reboot.
The VPS had **not** rebooted (uptime 11d). Root cause = unstable phone↔Hetzner path.

## Solution (OWNER-approved 2026-06-02, option A)

Decouple the factory from any RDP connection by giving it a **persistent console session
created at boot** via **autologon**, with the factory auto-starting in it:

1. **Autologon** for `qm-admin` (the actual RDP user; note the QM Factory ON/OFF desktop
   shortcuts live under `Administrator`, but sessions run as `qm-admin`). Configured with
   **Sysinternals Autologon** (`C:\Tools\Autologon\Autologon64.exe`), which stores the
   password as an **encrypted LSA secret** — never plaintext, never in the repo. At boot
   the OS auto-logs-in qm-admin → a console session exists independent of any RDP client.
2. **Scheduled task `QM_StrategyFarm_FactoryON_AtLogon`** — trigger AtLogon of qm-admin
   (+30s delay), `LogonType=Interactive`, `RunLevel=Highest`. Runs
   `Factory_ON.ps1 -NoPause`. Because autologon's logon == boot, this fires ~once per boot
   and brings the factory up automatically. `RunLevel=Highest` means the script's
   self-elevate check passes → **no UAC prompt** (a Startup-folder shortcut would hang on
   the UAC dialog at unattended boot, which is why a task is used).
3. **`-NoPause`** switch on `Factory_ON.ps1` skips the trailing `Read-Host` so the
   unattended run completes. Manual desktop double-clicks omit it (window stays open).

### Why this is robust
- Phone disconnect → only detaches the view; the console session + factory keep running.
- `fSingleSessionPerUser=1` → when OWNER reconnects, RDP **reattaches** to the existing
  autologon session (no new empty session, no second logon, no double-fire).
- Reboot → autologon recreates the session → task auto-starts the factory. No manual click.
- MT5 windows stay **visible** (the whole point of the 2026-05-23 directive is preserved).

## The one manual step OWNER must do (password)

I cannot enter or store the password. In your **RDP session**, run:

```
C:\Tools\Autologon\Autologon64.exe
```

The dialog pre-fills Username (`qm-admin`) and Domain (`WIN-B95G5LPSJ1O`). Type the
qm-admin password, click **Enable**. (Do *not* pass the password on the command line — it
would land in shell history/transcripts. Use the GUI.)

Takes effect on the **next reboot**. No reboot is forced now (factory is running); it
proves out on the next natural reboot (e.g. Windows Update) or whenever you reboot.

## Verification
- After enabling: `AutoAdminLogon=1` and `DefaultUserName=qm-admin` under
  `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon` (the password is an LSA
  secret, not a registry value).
- Task: `Get-ScheduledTask QM_StrategyFarm_FactoryON_AtLogon` → State `Ready`.
- End-to-end: after a reboot, confirm qm-admin is auto-logged-in and (≈30s later) the
  factory daemons/terminals are up — `farmctl.py health` / cockpit.

## Rollback
- Disable autologon: run Autologon64.exe again → **Disable**.
- Remove task: `Unregister-ScheduledTask QM_StrategyFarm_FactoryON_AtLogon -Confirm:$false`.
- `-NoPause` switch on Factory_ON.ps1 is backward-compatible (manual double-click
  unaffected); leave or revert as desired.

## Notes / security
- Autologon means a reboot lands in an authenticated desktop without a manual login.
  Acceptable on a single-owner VPS behind RDP/NLA auth; flagged for awareness.
- The task is NOT in any `qm_tasks.manifest.ps1` category list, so **Factory OFF does not
  tear it down**. Because it re-runs full `Factory_ON`, a fresh logon after a deliberate
  Factory OFF would turn the factory back on — but with autologon, fresh logons only
  happen at boot, so this is the intended "factory up on boot" behaviour.
