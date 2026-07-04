# Post-Reboot Install Checklist — 2026-07-05

After the hosting-provider panel reset on 2026-07-05 (forced by full LSM degradation:
qwinsta error 87, tasks failing 0x800710E0, shutdown.exe/WMI RPC 1722 unusable), install
the new preventive tooling **once the VPS boots cleanly** into an interactive session.

---

## Step 1 — Verify boot recovery

1. Confirm autologon worked: you have an interactive Administrator desktop.
2. Check T_Live is alive:
   ```powershell
   Get-Process -Name terminal64 -ErrorAction SilentlyContinue
   ```
   At least one `terminal64` process from `C:\QM\mt5\T_Live` should be present.
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

## Step 2 — Install the hygiene + LSM tasks

Open an **elevated** (Run as Administrator) PowerShell prompt:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
& "C:\QM\repo\tools\strategy_farm\install_hygiene_and_lsm_tasks.ps1" -RunLsmNow
```

The `-RunLsmNow` flag fires the LSM probe immediately so you get confirmation it works.

Expected output (last lines):
```
Registered: QM_StrategyFarm_HygieneReboot (weekly Saturday 07:00:00 local, SYSTEM)
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

All three should show `State = Ready`.

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

## Kill switch (if needed)

To suppress future hygiene reboots without unregistering the task:

```powershell
New-Item -ItemType File -Force 'D:\QM\reports\state\HYGIENE_REBOOT_DISABLED.flag'
```

To re-enable:

```powershell
Remove-Item 'D:\QM\reports\state\HYGIENE_REBOOT_DISABLED.flag' -Force
```

The `weekly_hygiene_reboot.ps1` script checks for this flag at Guard 3 on every run.
The task remains registered and fires weekly, but exits 0 without rebooting while the
flag is present.

---

## Task summary

| Task | Schedule | Principal | Script |
|---|---|---|---|
| QM_StrategyFarm_HygieneReboot | Weekly, Saturday 07:00 local | SYSTEM | `tools/strategy_farm/weekly_hygiene_reboot.ps1` |
| QM_StrategyFarm_LsmHealthProbe | Every 6 hours | SYSTEM | `tools/strategy_farm/lsm_health_probe.ps1` |
| QM_StrategyFarm_WorkerDedupe | On-demand (watchdog-triggered) | qm-admin Interactive | `tools/strategy_farm/start_terminal_workers.py --dedupe` |

State files written:
- `D:\QM\reports\state\hygiene_reboot_state.json` — timestamp + uptime of last hygiene reboot
- `D:\QM\reports\state\hygiene_reboot.log` — guard evaluation log (append, UTC)
- `D:\QM\reports\state\lsm_health.json` — latest probe result
- `D:\QM\reports\state\lsm_health_history.jsonl` — probe history (one line per run)
