# 04:45 morning safety check — Codex build evidence

Date: 2026-08-06

Router task: `c112220b-f36b-497e-bb9e-7ce49975cf00`

Verdict: READY_FOR_CLAUDE_REVIEW; not installed and not approved

## Delivered artifacts

- `tools/strategy_farm/Morning_Safety_Check.ps1`: seven-check, start-only sweep
  with atomic latest state, append-only history, maintenance/factory suppression,
  fail-closed process inventory, governed task wakes, and WS-E2 failure paging.
- `tools/strategy_farm/live_alarm_mailer.py`: morning-safety FAILED mail mode,
  using the same Gmail transport/config and at-most-once run reservation.
- `tools/strategy_farm/install_live_uptime_tasks.ps1` and
  `qm_tasks.manifest.ps1`: synchronized `QM_Morning_Safety_Check_0445` contract.
- `tools/strategy_farm/morning_brief.py`: one compact 04:45-Safety summary line.
- Focused tests in `test_morning_safety_check.py`,
  `test_live_alarm_mailer.py`, and the existing morning-brief live-status suite.
- `docs/ops/MORNING_SAFETY_CHECK_0445_2026-08-06.md`: operator contract,
  approval gate, and DST caveat.

## Start-only invariants

- No direct `terminal64.exe` launch path exists.
- No `Start-Process`, `Stop-Process`, `Stop-ScheduledTask`, or `shutdown.exe`
  call exists.
- The only live recovery mutation is the existing `T_Live_Watchdog.ps1` invoked
  with `-NoReboot`; that watchdog owns the existing RunEx/supervisor chain.
- Unknown live or worker inventory fails closed.
- Duplicate workers are reported but never deduped by this sweep, avoiding an
  interruption to active T1-T10 work.
- News repair uses `QM_NewsCalendar_Refresh`; the age parameter is validated at
  `<=336` hours. No stale guard was weakened.
- `LIVE_UPTIME_MAINTENANCE.flag` and `FACTORY_OFF.flag` suppress their domains.
- No installation, task start, terminal action, reboot, AutoTrading change, or
  real SMTP send occurred during build verification.

## Focused verification

PowerShell parsing passed for the sweep, installer, and task manifest. Python
compilation passed for the shared mailer and morning briefing. Focused tests:

```
........................................................................ [ 82%]
...............                                                          [100%]
87 passed in 5.18s
```

The test set covers mail-on-FAILED, duplicate suppression, no mail on all-OK,
installer/manifest synchronization, 04:45 and 14-minute task contracts,
start-only forbidden actions, and morning-brief rendering.

## Production-state dry run

Command mode: `Morning_Safety_Check.ps1 -DryRun` with every output redirected to
`C:\Windows\Temp\qm_morning_safety_evidence_e80eb161e2e94c2d8243609f73389fcd`.
It performed read-only probes, wrote only fixture-local state/history/mail files,
and rendered a dry-run mail without SMTP.

Observed outcomes during the final dry run:

| Check | Result | Evidence summary |
|---|---|---|
| live watchdog cadence | OK | fresh state, task Ready; watchdog result 1 correctly treated as a degraded state verdict |
| live session supervisor | OK | scheduler-owned heartbeat, PID 11280 |
| live terminals | FAILED | DXZ RUNNING, FTMO still contractually PARKED |
| autologon/recovery contract | OK | watchdog contract ready, SYSTEM LSA secret present |
| factory lane pulse | OK | pump/tick/watchdog sane; 10/10 policy workers present exactly once |
| news calendar | OK | both source/FILE_COMMON hashes match; worst age 84.2h; coverage through 2026-08-09 |
| D: headroom | OK | 229.5 GB free |

The sole failure is the deterministic dependency on router task `7a75c2c6`:
FTMO must be reviewed and changed from PARKED to OWNER-ratified RUNNING before
this sweep can report dual-live OK. Because a concurrent OWNER-approved change
armed the regular watchdog's guarded reboot path, the dry-run correctly proposed
invoking the same watchdog script with an explicit no-reboot boundary
(`would_run_watchdog_no_reboot`) and did not execute it.
WS-E2 rendered `[QM LIVE] MORNING SAFETY FAILED - 1 check(s)` with
`send_result.dry_run=true`; exit code was 0 because the sweep and evidence/mail
simulation completed successfully.

## Review/activation boundary

Builder is not approver. Leave this task in router `REVIEW`; Claude must review
the implementation and its dependency on the FTMO RUNNING contract before any
scheduled-task registration.
