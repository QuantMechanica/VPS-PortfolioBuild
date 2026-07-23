# Post-Reboot Install Checklist — 2026-07-05

After the hosting-provider panel reset on 2026-07-05 (forced by full LSM degradation:
qwinsta error 87, tasks failing 0x800710E0, shutdown.exe/WMI RPC 1722 unusable), install
the new preventive tooling **once the VPS boots cleanly** into an interactive session.

---

## Step 1 — Verify boot recovery

1. Confirm autologon worked: you have an interactive Administrator desktop.
2. Check **both** live terminals are alive on their exact paths:
   ```powershell
   Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" |
     Where-Object { $_.ExecutablePath -in @(
       'C:\QM\mt5\T_Live\MT5_Base\terminal64.exe',
       'C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe'
     ) } |
     Select-Object ProcessId, SessionId, ExecutablePath
   ```
   Expect exactly one DXZ and one FTMO process, both in the `qm-admin` session.
   Then verify the unattended recovery state:
   ```powershell
   Get-Content 'D:\QM\reports\state\live_uptime_watchdog.json' -Raw
   ```
   Expect `dxz_running=true`, `ftmo_running=true`, `process_probe_ok=true`,
   `session_placement_ok=true`, `session_supervisor_ready=true`, and
   `session_supervisor_scheduler_owned=true`, `recovery_task_contract_ready=true`,
   and `autologon_ready=true`.
3. Check factory workers:
   ```powershell
   python C:\QM\repo\tools\strategy_farm\farmctl.py health
   ```
   Expect T1-T10 workers recovering (some may be starting up; allow 2-3 minutes).
4. Confirm qwinsta now works (the degradation is gone post-reboot):
   ```powershell
   qwinsta /server:localhost
   ```
   Should list sessions without "Error [87]".

---

## Step 2 — Install live uptime + LSM tasks

Open an **elevated** (Run as Administrator) PowerShell prompt:

```powershell
& "C:\QM\repo\tools\strategy_farm\install_live_uptime_tasks.ps1" -RunNow
```

This idempotently repairs the two logon-only live terminal tasks, the resident
interactive session supervisor, and the minutely SYSTEM watchdog. It also verifies
the SYSTEM-only Autologon LSA secret. It must complete without changing the two live
PIDs. `QM_TSCon_Console_OnDisconnect` must remain `Disabled`.

The supervisor ownership can be checked without starting anything:

```powershell
& "C:\QM\repo\tools\strategy_farm\Start_Live_SessionSupervisor.ps1" -ProbeOnly
```

Expect `scheduler_owned=true`; the helper resolves the current `qm-admin` session.

Then install/repair the LSM probe and worker dedupe task. The historical hygiene
definition is preserved but deliberately left disabled:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
& "C:\QM\repo\tools\strategy_farm\install_hygiene_and_lsm_tasks.ps1" -RunLsmNow
```

The `-RunLsmNow` flag fires the LSM probe immediately so you get confirmation it works.

Expected output (last lines):
```
Registered DISABLED: QM_StrategyFarm_HygieneReboot (legacy definition; no automatic reboot)
Registered: QM_StrategyFarm_LsmHealthProbe (every 6h, SYSTEM)
Registered: QM_StrategyFarm_WorkerDedupe (on-demand, qm-admin Interactive)
Firing QM_StrategyFarm_LsmHealthProbe immediately (smoke run)...
lsm_health.json:
{"probed_at":"...","uptime_days":...,"qwinsta_ok":true,...,"verdict":"ok"}
```

The third task, `QM_StrategyFarm_WorkerDedupe`, is the interactive trampoline the
hardened watchdog now uses for the pure worker-shortage heal (`worker_dedupe_heal`
action). Without it the watchdog logs `heal_failed` for that class — the watchdog
file changes are already live (the SYSTEM task reads the repo file each run), so
registering this task is REQUIRED, not optional.

---

## Step 3 — Verify both tasks registered

```powershell
Get-ScheduledTask -TaskName 'QM_StrategyFarm_HygieneReboot'  | Select-Object TaskName, State
Get-ScheduledTask -TaskName 'QM_StrategyFarm_LsmHealthProbe' | Select-Object TaskName, State
Get-ScheduledTask -TaskName 'QM_StrategyFarm_WorkerDedupe'   | Select-Object TaskName, State
```

`QM_StrategyFarm_HygieneReboot` must show `State = Disabled`; the LSM and dedupe
tasks should show `State = Ready`.

Then verify the hardened watchdog cycles cleanly (new jsonl fields + heartbeat):

```powershell
Get-Content 'D:\QM\reports\state\factory_watchdog.jsonl' -Tail 4
```

Expect the newest lines to include a `"action":"heartbeat"` record with a fresh UTC
`ts`, and the main record to carry `lsm_degraded`, `qwinsta_error`, `secret_basis`
fields. No `session_lost_no_autologon` should appear post-reboot.

---

## Step 4 — Verify LsmHealthProbe first run wrote `verdict: ok`

```powershell
Get-Content 'D:\QM\reports\state\lsm_health.json'
```

Confirm `"verdict":"ok"` and `"qwinsta_ok":true`.  
If verdict is `degrading` or `critical` immediately after a clean reboot, investigate
the failing probes before proceeding.

---

## Step 5 — Record the decision

Note this reboot in the decisions log under `decisions/` as usual.

---

## Legacy hygiene kill switch (defence in depth)

To suppress future hygiene reboots without unregistering the task:

```powershell
New-Item -ItemType File -Force 'D:\QM\reports\state\HYGIENE_REBOOT_DISABLED.flag'
```

The task itself must remain disabled. Do not remove this flag or enable the task
until the reboot path has been separately hardened and approved.

---

## Task summary

| Task | Schedule | Principal | Script |
|---|---|---|---|
| QM_T_Live_AtLogon | qm-admin logon + 15s | qm-admin Interactive | `tools/strategy_farm/T_Live_ON.ps1` |
| QM_FTMO_AtLogon | qm-admin logon + 30s | qm-admin Interactive | `tools/strategy_farm/FTMO_ON.ps1` |
| QM_Live_MT5_SessionSupervisor | qm-admin logon + 45s, resident | qm-admin Interactive | `tools/strategy_farm/Live_MT5_SessionSupervisor.ps1` |
| QM_T_Live_Watchdog | Every minute | SYSTEM | `tools/strategy_farm/T_Live_Watchdog.ps1` |
| QM_StrategyFarm_HygieneReboot | **Disabled legacy definition** | SYSTEM | `tools/strategy_farm/weekly_hygiene_reboot.ps1` |
| QM_StrategyFarm_LsmHealthProbe | Every 6 hours | SYSTEM | `tools/strategy_farm/lsm_health_probe.ps1` |
| QM_StrategyFarm_WorkerDedupe | On-demand (watchdog-triggered) | qm-admin Interactive | `tools/strategy_farm/start_terminal_workers.py --dedupe` |

State files written:
- `D:\QM\reports\state\live_uptime_watchdog.json` — latest dual-live/session/recovery state
- `D:\QM\reports\state\live_uptime_watchdog.jsonl` — transitions/actions plus 15-minute heartbeat
- `D:\QM\reports\state\live_session_supervisor.json` — 10-second resident recovery heartbeat
- `D:\QM\reports\state\hygiene_reboot_state.json` — timestamp + uptime of last hygiene reboot
- `D:\QM\reports\state\hygiene_reboot.log` — guard evaluation log (append, UTC)
- `D:\QM\reports\state\lsm_health.json` — latest probe result
- `D:\QM\reports\state\lsm_health_history.jsonl` — probe history (one line per run)
