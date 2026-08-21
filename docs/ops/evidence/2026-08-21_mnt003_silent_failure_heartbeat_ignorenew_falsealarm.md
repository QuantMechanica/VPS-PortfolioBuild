# MNT-003 (cont.) — 0x800710E0 false-FAIL on Pump/Orchestration in silent_failure_monitor + heartbeat

**Date:** 2026-08-21
**Router task:** 9226799b (QM-TODO-20260821-003), ops_issue
**Recorder:** Claude (agents/board-advisor)
**Relation:** extends the committed fix in
`docs/ops/evidence/2026-08-21_mnt003_0x800710e0_pump_codexorchestration.md`
(commit `19ae99a42`, which fixed `health.py::chk_pump_task_health`). That fix
was correct but **incomplete**: two other monitors still hard-alarmed on the
same benign code.

## Ground truth measured

Live scheduled-task inspection (`schtasks /query /v`, `/xml`,
`Get-ScheduledTask ... | .Principal`):

| Task | Principal (UserId) | LogonType | MultipleInstances | ExecLimit | Cadence |
|---|---|---|---|---|---|
| QM_StrategyFarm_Pump_5min | S-1-5-18 (SYSTEM) | ServiceAccount | IgnoreNew | PT30M | 5 min |
| QM_StrategyFarm_CodexOrchestration_15min | SYSTEM | ServiceAccount | IgnoreNew | PT4H | 15 min |
| QM_StrategyFarm_ClaudeOrchestration_15min | SYSTEM | ServiceAccount | IgnoreNew | PT4H | 15 min |
| QM_StrategyFarm_GeminiOrchestration_15min | SYSTEM | ServiceAccount | IgnoreNew | PT4H | 15 min |
| QM_StrategyFarm_Dashboard_Hourly | SYSTEM | ServiceAccount | IgnoreNew | PT30M | 60 min |
| QM_StrategyFarm_CodexFleetPacer | SYSTEM | ServiceAccount | IgnoreNew | PT1H | 15 min |
| QM_T_Live_AtLogon / _FTMO_AtLogon / _Live_MT5_SessionSupervisor | qm-admin | **Interactive** | — | — | at-logon |

XML backups exported (evidence, no task modified):
`docs/ops/evidence/task_backups/QM_StrategyFarm_Pump_5min_2026-08-21.xml`,
`..._CodexOrchestration_15min_2026-08-21.xml`.

**Root cause of the oscillation.** All the SYSTEM tasks above run
`MultipleInstancesPolicy=IgnoreNew` with an ExecutionTimeLimit many multiples of
their cadence. When a repetition trigger fires while the previous instance is
still running, the scheduler *refuses the new start* and stamps
`LastTaskResult = 0x800710E0` (decimal `2147946720`, Win32 `4320` =
"The operator or administrator has refused the request"). The next
non-overlapping fire stamps `0`. Hence the flip between `0` / `267009`
(0x41301 currently-running) / `2147946720`.

**The process actually does its work** (not a real failure):
- Pump wrapper logs `D:\QM\strategy_farm\logs\pump_task_*.log` show the
  kill-safety audit (`files_scanned: 8064, safe: true`) plus the farmctl pump
  cycle every run; e.g. `pump_task_20260821T113301Z.log` = 32,940 bytes of real
  dispatch output. The "Could not find platform independent libraries <prefix>"
  first line is Python's harmless embedded-launcher notice, not an error.
- `silent_failure_monitor`'s own independent `pump_blockade` check at
  `2026-08-21T12:45:01Z`: *"0/6 recent pump runs blocked; newest ok=True"* = OK.
- `health.json` fresh (7 min), `cockpit.html` fresh (2 min), dispatch demonstrably
  running — while the schtask-result check screamed FAIL. That contradiction is
  the proof of the false alarm.

## The two monitors that still false-alarmed

**`silent_failure_monitor.py`** — `check_scheduled_tasks()` treated
`2147946720` as an unconditional hard FAIL for *any* task
(`schtask_hardfail_results`, line ~406), interpreting it as an
"interactive-launch-queued" failure. That interpretation is only valid for
**interactive-logon** tasks (a `qm-admin` GUI `AtLogon` task whose token is gone
after a session handover — the scheduler then queues the launch forever). On a
SYSTEM/service task it can only be the IgnoreNew overlap-refusal. Evidence it was
firing all day (`D:\QM\reports\state\silent_failure_monitor.log`):

```
2026-08-21T05:00:01Z ALARM-OPEN [FAIL] schtask:QM_StrategyFarm_Pump_5min :: ... 0x800710E0 interactive-launch-queued
2026-08-21T07:45:01Z ALARM-OPEN [FAIL] schtask:QM_StrategyFarm_CodexOrchestration_15min :: ... 0x800710E0 interactive-launch-queued
2026-08-21T08:45:01Z ALARM-OPEN [FAIL] schtask:QM_StrategyFarm_ClaudeOrchestration_15min :: ... 0x800710E0 interactive-launch-queued
(Dashboard_Hourly likewise; recurring all day)
```
The same log also shows a **genuine** Pump failure at `2026-08-21T10:00:02Z`:
`267014 killed@time-limit` — this class must keep alarming.

**`heartbeat_snapshot.py`** — `probe_scheduled_tasks()` reported any rc not in
`{0, 267009, None}` as `SCHEDULED_TASK_FAILING`. It carried
`CodexOrchestration_15min` in a **name-scoped** `EXPECTED` dict, which had the
side effect of suppressing *every* non-zero code on that task — including a real
`267014` killed@time-limit. Pump and the sibling SYSTEM tasks were not excepted
at all.

## Fix applied (monitor heuristics only — no task definition changed)

Decision: **do not modify the task XML.** `IgnoreNew` is the correct overlap
guard; `Parallel` would allow dangerous concurrent pumps, `Queue` would pile up
runs. The reported result mismatch lives in the monitors, so the monitors were
corrected to match reality.

1. `silent_failure_monitor.py`
   - Probe (`_PS_PROBE`) now also emits `LogonType` and `UserId` per task
     (zero extra cost — already iterating `Get-ScheduledTask` objects).
   - `check_scheduled_tasks()` computes `interactive_logon` from `LogonType`
     (`interactive`/`interactivetoken`/`interactivetokenorpassword`/`group`),
     with a name-set fallback to `schtask_live_logon_owned_elsewhere` so the
     three known interactive tasks still alarm even if the probe cannot read
     LogonType. `0x800710E0` now FAILs **only** on interactive-logon tasks; on a
     SYSTEM/service task it is treated as the benign overlap-refusal (no finding).
   - `267014` and all other genuine codes are unchanged and still FAIL.

2. `heartbeat_snapshot.py`
   - Replaced the name-scoped CodexOrchestration `EXPECTED` entry with a
     **code-scoped** `BENIGN_IGNORENEW_OVERLAP` set (Pump + the three
     Orchestration tasks + Dashboard_Hourly): only `0x800710E0` on those tasks is
     routed to `tasks_failing_expected`; every other non-zero code (e.g.
     `267014`) still lands in `tasks_failing` and raises the flag. This is
     strictly more correct than before (it no longer masks real Codex failures).

## Detection rule — REAL outage vs today's benign code

A genuine Pump/Orchestration outage remains fully distinguishable and is caught
by signals independent of `LastTaskResult`:

- **Pump:** `chk_pump_task_health` orphaned-lock check (dead PID holding
  `pump_task.lock`) → FAIL; `silent_failure_monitor` `pump_blockade` streak
  (`PUMP_BLOCKED` markers in `pump_task_*.log`) → FAIL; any non-benign exit code
  (`267014`, `112`, `86` PUMP_BLOCKED, …) → FAIL.
- **Orchestration lanes:** `health.py::chk_agent_lane_heartbeat_stale`
  (activity-based on `state/lane_<agent>_heartbeat.json` freshness) → WARN; any
  non-benign exit code → FAIL.

`0x800710E0` on a SYSTEM/IgnoreNew task means *the prior instance is still
running and doing the work* — the exact opposite of an outage. A real outage
shows as stale activity or a genuine bad code, never as this code.

## Verification (tests)

```
python -m pytest tools/strategy_farm/tests/test_mnt003_pump_task_ignorenew_benign.py \
    tools/strategy_farm/tests/test_mnt003_heartbeat_ignorenew_benign.py \
    tools/strategy_farm/tests/test_silent_failure_live_uptime.py -q
=> 24 passed
python -m pytest tools/strategy_farm/tests/test_run_agent_orchestration_heartbeat.py \
    tools/strategy_farm/tests/test_health_agent_lane_heartbeat.py -q
=> 6 passed
```

New/changed tests:
- `test_silent_failure_live_uptime.py`: repurposed the old
  `test_recurring_task_interactive_launch_queued_is_hard_failure` (its fixture,
  CodexFleetPacer, is actually a ServiceAccount task, so its premise was the
  pre-MNT-003 misinterpretation) into
  `test_interactive_recurring_task_launch_queued_is_hard_failure` (Interactive →
  FAIL), `test_service_task_ignorenew_overlap_0x800710E0_is_benign` (SYSTEM →
  no FAIL), and `test_service_task_killed_at_time_limit_still_fails` (267014 →
  FAIL).
- `test_mnt003_heartbeat_ignorenew_benign.py` (new): Pump/orchestration
  `0x800710E0` → expected-not-failing; Pump `267014` → still failing;
  non-class task `0x800710E0` → still failing.

Live end-to-end probe after the fix (`_windows_probe()` + `check_scheduled_tasks`)
returned LogonType correctly (`ServiceAccount` for SYSTEM tasks, `Interactive`
for `QM_T_Live_AtLogon`) and produced **0 FAIL findings** (the two remaining
findings are pre-existing WARNs for `Public_Snapshot_Hourly`/`MailboxSourceIntake`
rc=1, unrelated).

## Not done / follow-up (Entscheidungsschlange)

1. `lsm_health_probe.ps1` left **untouched**. It uses the same code as its own
   LSM-degradation signal on QuotaGovernor / FactoryWatchdog_15min /
   FactoryRecycle_Daily. QuotaGovernor (ExecLimit PT5M < 15-min cadence) and the
   disabled FactoryRecycle cannot benign-overlap. **FactoryWatchdog_15min CAN**
   (ExecLimit PT10M > 5-min interval), so a benign overlap could produce a
   spurious `degrading` verdict — but never `critical`, which is corroboration-
   gated (requires a second independent probe: qwinsta error 87 / logon / spawn
   failure). The prior evidence's blanket "correct as-is" claim is therefore only
   accurate for the *critical* verdict. Candidate refinement (not in this task's
   scope; the probe is a deliberate session-degradation detector and changing it
   risks the real signal): count `0x800710E0` as failing only when
   ExecLimit <= cadence, or require it to persist across N runs.

## Rollback

Pure code/test changes; revert the four files:
```
git checkout HEAD -- tools/strategy_farm/silent_failure_monitor.py \
  tools/strategy_farm/heartbeat_snapshot.py \
  tools/strategy_farm/tests/test_silent_failure_live_uptime.py
git rm tools/strategy_farm/tests/test_mnt003_heartbeat_ignorenew_benign.py
```
No scheduled task, factory, terminal, or DB state was modified. The two
`task_backups/*.xml` are read-only evidence exports.
```
schtasks /create /tn <name> /xml <backup.xml> /f   # only if a task ever needs restoring (none changed)
```
