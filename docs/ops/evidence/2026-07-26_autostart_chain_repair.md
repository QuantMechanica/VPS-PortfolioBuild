# Autostart Chain Repair — 2026-07-26 evening (Claude)

OWNER directive: Factory + T_Live must come back automatically after a VPS reboot,
without waiting for an interactive OWNER login.

## What actually happened (evidence-corrected timeline, local time)

- **00:27** VPS reboot. Windows autologon (qm-admin, LSA-stored secret) **worked**:
  Security log 4624 LogonType 2 for qm-admin at 00:27:14.
- **00:27→06:36 T_Live outage.** `QM_T_Live_AtLogon` fired and exited 2
  (T_Live_ON.ps1 guard/probe, boot-transient). The SYSTEM watchdog
  (`live_supervisor_watchdog.ps1`) kicked `QM_Live_MT5_SessionSupervisor` every
  ~15 min all night (log: alternating `kicked` / `wait process_absent_but_state_fresh`
  00:27–06:36); the supervisor started, wrote state, and died each cycle without
  relaunching T_Live. Root cause of the dead relaunch path: **task-definition drift** —
  `T_Live_Watchdog.ps1:311` says "demand start is deliberately enabled", but
  `QM_T_Live_AtLogon` and `QM_FTMO_AtLogon` had `AllowStartOnDemand=false`, so every
  interactive relaunch attempt was refused. No retry existed on the AtLogon tasks.
- **Daytime: factory was NOT down.** `factory_watchdog.jsonl` shows 9/9 workers with
  active progress continuously until 17:30 (pending 2221→2193).
- **17:33** session handover (old session 1 signed out, fresh RDP session 3 logon).
  AtLogon chain rebuilt everything by design: T_Live relaunched 17:33:48 (authorized
  on 4000090541 17:33:51, 21 EAs + AccountMonitor loaded), 9 workers respawned 17:35.
- **17:45** RAM/commit storm (metatester of QM5_13059 Q08 multisym at 29 GB private,
  pagefile 92 %, 250k pages/sec): workers T4/T9/T10 logged `ram_low_pause`
  (free 0.7 GB) and died. `worker_dedupe_heal` ran but did not respawn
  (workers_after=6). Manually restored 18:00 via
  `start_terminal_workers.py --dedupe` → 9/9 verified by process scan.

## Fixes applied (18:00–18:05)

1. `QM_T_Live_AtLogon`: `AllowStartOnDemand` false→true, added
   `RestartOnFailure` 6 × PT2M.
2. `QM_FTMO_AtLogon`: same two changes.
3. `QM_StrategyFarm_FactoryON_AtLogon`: added `RestartOnFailure` 6 × PT2M
   (demand start was already default-enabled).

Verified: `(Get-ScheduledTask <task>).Settings.AllowDemandStart` = True for both
AtLogon live tasks; re-exported XML shows RestartOnFailure on all three. A SYSTEM
demand-start test of `QM_T_Live_AtLogon` while qm-admin holds only an RDP session
queues the instance (0x800710E0 / event 325) — expected InteractiveToken behaviour;
at boot the autologon **console** session is qm-admin's, which is exactly the state
the kick path needs (proven by the supervisor itself being kick-started all night).
T_Live untouched throughout (process count stayed exactly 1).

## Also fixed today (same sweep)

- **News calendar stale**: `refresh_news_calendar.ps1` silently appended nothing under
  PS 5.1 — `@($feedJson | ConvertFrom-Json)` collapses the FF weekly array into one
  pseudo-event (pipeline does not enumerate). Fixed (commit e95efa9c1), re-run:
  +90/+90 events, coverage OK to 2026-07-31, stale flag cleared.
- **NO_HISTORY class**: 0 occurrences in the last 7 days (farm_state query);
  the 2026-06-20 worker-retry fix holds. Today's only fail class: 7 × INFRA_FAIL
  (RAM-storm victims) — ride along with tonight's staged requeue canary.

## Open (tickets enqueued to Codex lane)

- `61cfbaf3` T5 tester rebuild (indicator engine dead since 07-24, parked in
  disabled_terminals.txt).
- `29e1534a` Supervisor resident dies per kick cycle at boot; T_Live_ON exit-2
  branch diagnostics; WorkerDedupe respawn gap.

## Acceptance test (recommended)

Controlled reboot in tonight's Factory-OFF deployment window (before market open),
RDP disconnected: expect autologon console session → FactoryON + T_Live_ON +
supervisor all up within ~15 min with zero interaction. That is the pass/fail test
for the OWNER requirement.
