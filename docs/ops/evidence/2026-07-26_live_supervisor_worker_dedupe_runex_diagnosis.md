# Q-only ops evidence: live supervisor and worker-dedupe session binding

Date: 2026-07-26  
Router task: `29e1534a-2b71-4e7f-8d2f-3bbbb35eecd8`  
Scope: diagnosis only; no terminal process was started or stopped, and no live
trading or AutoTrading state was changed.

## Verdict

The boot-window loop was not an unexplained resident-script crash. Both
`QM_Live_MT5_SessionSupervisor` and `QM_StrategyFarm_WorkerDedupe` are
Interactive tasks, while their watchdog callers run as SYSTEM and invoke
`Start-ScheduledTask`. In the current desktop/session state, Task Scheduler
queues those requests and refuses them with `0x800710E0` ("The operator or
administrator has refused the request"). The task action therefore never
starts in the existing `qm-admin` interactive session.

This explains both reported symptoms:

- `live_supervisor_watchdog.log` repeatedly says `kicked`, but the supervisor
  heartbeat remains stale and there is no resident supervisor process.
- `factory_watchdog.jsonl` reports `worker_dedupe_heal` with
  `workers_before=6 workers_after=6/9`; the task request was queued rather than
  executed. A later manual interactive `start_terminal_workers.py --dedupe`
  restored 9/9.

## Reproduced evidence

At approximately 18:20 local:

- `Get-ScheduledTaskInfo QM_Live_MT5_SessionSupervisor`:
  `LastTaskResult=2147946720` (`0x800710E0`), task state `Ready`.
- `Get-ScheduledTaskInfo QM_StrategyFarm_WorkerDedupe`:
  `LastTaskResult=2147946720` (`0x800710E0`), task state `Ready`.
- Task Scheduler Operational events for both tasks show event 325 ("queued
  instance") and event 110, without a corresponding action-start event 200.
- `qwinsta` shows one active `qm-admin` interactive session (session 3).
- No process command line contains `Live_MT5_SessionSupervisor.ps1`.
- `live_session_supervisor.json` remains at
  `last_checked_utc=2026-07-26T15:34:18Z`, supervisor PID 16588, session 3.

The scheduled-task contract itself is currently correct for the resident:
`AllowDemandStart=True`, `ExecutionTimeLimit=PT0S`, `RestartCount=255`,
`RestartInterval=PT1M`, `MultipleInstances=IgnoreNew`. This rules out the
earlier suspected execution-time-limit failure.

## Existing correct mechanism

`tools/strategy_farm/Start_Live_SessionSupervisor.ps1` already implements the
required binding:

1. resolve exactly one `qm-admin` desktop session;
2. validate the registered task contract;
3. call Task Scheduler COM `IRegisteredTask.RunEx` with
   `TASK_RUN_USE_SESSION_ID`;
4. verify scheduler ownership, engine PID/session, and the fresh heartbeat.

The defect is that `live_supervisor_watchdog.ps1` calls
`Start-ScheduledTask` directly instead of this bootstrap. WorkerDedupe has the
same incorrect SYSTEM-to-Interactive trampoline and lacks an equivalent
session-bound bootstrap.

## Required bounded repair

1. Change `live_supervisor_watchdog.ps1` to invoke
   `Start_Live_SessionSupervisor.ps1`, capture its exit/result, and log
   `kick_verified` only after its ownership/heartbeat verification succeeds.
   A queued request must be logged as failure, never `kicked`.
2. Add a generic or WorkerDedupe-specific `RunEx` bootstrap with the same
   exact-session and registered-action validation. Its success condition is
   task action completion plus a worker-count increase (or already 9/9), not a
   successful scheduling API return.
3. Have `factory_watchdog.ps1` call that bootstrap and record the bootstrap
   result, task result, target session, and before/after worker counts.
4. Add a structured append-only launcher record to `T_Live_ON.ps1` before
   every exit. Required fields: UTC timestamp, branch identifier, exit code,
   identity, session ID, probe status/error, and match count. This supplies the
   missing branch-level evidence for boot-transient exit 2 without weakening
   any fail-closed guard.

The repair must not launch `terminal64.exe` manually, enable AutoTrading, or
stop active T1-T10 work. A safe verification uses the supervisor's
`-ProbeOnly` mode and a WorkerDedupe run only when a worker slot is genuinely
missing; otherwise static/unit verification is sufficient.

