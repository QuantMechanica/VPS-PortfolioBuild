# Factory self-healing fix — Codex implementation evidence

Date: 2026-07-26
Router ticket: `7abd518a`
Role: Codex builder; Claude remains approver

## Outcome

The SYSTEM watchdog's pure-worker-shortage path no longer calls
`QM_StrategyFarm_WorkerDedupe`, whose `Interactive` principal is stuck in Task
Scheduler's post-handover queue. It now launches the idempotent
`start_terminal_workers.py --dedupe` path in the logged-on `qm-admin` session
through `WTSQueryUserToken`, `DuplicateTokenEx`, and `CreateProcessAsUser`.

The existing silent-failure surface now treats `LastTaskResult=2147946720`
(`0x800710E0`) as an unconditional hard failure for every enabled `QM_*` task.
No new notification channel was added; findings continue through
`silent_failure_monitor.py` -> `silent_failure_alarms.json` ->
`gmail_alarm.py`/health merge.

## Implementation details

- `factory_watchdog.ps1`
  - Added `Invoke-InteractiveWorkerDedupe`.
  - Launches the pinned Python starter through an interactive-session
    PowerShell, clearing only stale `PYTHONHOME`/`PYTHONPATH` overrides.
  - Waits for the starter's real exit code.
  - Rejects session 0, rejects workers in another session, and rejects a
    shortage heal that makes no worker-count progress.
- `run_in_console_session.ps1`
  - Corrected `STARTUPINFO` to Unicode layout. The previous ANSI/default
    marshaling passed an invalid `lpDesktop` to `CreateProcessAsUserW` and
    reproduced `0xC0000142`.
  - Removed `CREATE_NO_WINDOW`; it contradicted the explicit
    `winsta0\default` interactive desktop attachment.
  - Added optional bounded child waiting and exit-code propagation.
- `silent_failure_monitor.py`
  - Corrected the hard-failure decimal constant. The old value was
    `2147943648` (`0x800704E0`), not `0x800710E0`.
  - The exact incident code can no longer be hidden by logon-task exclusions,
    age, missing cadence, or a missing `NextRun`.

## Acceptance evidence

Safe runtime test used a temporary, exact-name SYSTEM scheduled task and one
idle worker at a time. The temporary task was removed after testing.
`Factory_OFF.ps1`, TestWindow isolation, `tscon`, logoff, reboot, T_Live, and
AutoTrading were not invoked or modified.

Observed progression:

1. Pre-fix token launch reproduced the failure: child exit
   `3221225794` (`0xC0000142`).
2. After correcting `STARTUPINFO` and creation flags:
   - SYSTEM launcher: exit `0`
   - token-created starter PID: `4784`
   - target session: `3` (`qm-admin`)
   - starter exit: `0`
   - replacement worker: T7 PID `13656`, session `3`
   - worker remained alive and reached its normal resource admission checks.
3. A terminal launch from that exact replacement worker was **not observed**
   during the acceptance window. Its log reported the normal safety gates
   `free_ram_gb=3.7 < 4.0` followed by
   `free_gb=38.4/31.1 < 40.0`; therefore it correctly refused to start
   `terminal64.exe`. This is an environmental admission block, not an import
   or session-init failure, but it means terminal execution is not claimed as
   verified.
4. Post-test state:
   - worker fleet: 9/9 enabled terminals (T5 disabled by operator file)
   - interim keeper PID `1584`: still running in session 3
   - T_Live PID `16388`: still running in session 3
   - temporary acceptance task: removed

The interim `interactive_worker_keeper.py` is removable after this commit is
reviewed/deployed and a replacement worker is observed launching and
completing a `terminal64` run through the watchdog path. It was deliberately
left running because that last condition could not be verified.

## Health-probe evidence

Targeted dry run:

```text
python tools/strategy_farm/silent_failure_monitor.py --print
overall=FAIL
QM_Live_MT5_SessionSupervisor ... 0x800710E0 interactive-launch-queued
QM_StrategyFarm_WorkerDedupe ... 0x800710E0 interactive-launch-queued
QM_T_Live_AtLogon ... 0x800710E0 interactive-launch-queued
...
```

The current task set showed nine enabled tasks with this result, not the seven
in the original finding: Cockpit and `QM_T_Live_Watchdog` also carried
`0x800710E0` at probe time. This does not contradict the principal-class
diagnosis; it expands the currently affected set.

Tests:

```text
python -m pytest \
  tools/strategy_farm/tests/test_silent_failure_live_uptime.py \
  tools/strategy_farm/tests/test_factory_watchdog_interactive_heal_static.py -q
10 passed
```

PowerShell parser checks passed for both modified `.ps1` files.

## S4U judgment

No task was converted to S4U.

`WorkerDedupe`, the live session tasks, CodexFleetPacer, AgyGovernor, and
GeminiOrchestration either spawn descendants, depend on an interactive
desktop/profile, or both; moving them to S4U/session 0 would recreate the
failure class or introduce untested profile assumptions. WorkItemLogPruner is
the only plausible candidate because it is non-spawning, but its installer
was not found in the scoped repository and changing live task configuration
without a durable reinstall definition would create configuration drift.
Restoring the watchdog and alarming first is safer than an ad-hoc conversion.

## Remaining limitation

The pure worker-shortage path is fixed. Existing clean-slate/dispatch-stall
branches still invoke `QM_StrategyFarm_FactoryON_AtLogon`, which belongs to the
affected Interactive principal class. This change intentionally does not
token-launch the destructive full Factory_ON workflow; that broader recovery
path needs separate review and acceptance because it kills/rebuilds factory
processes. No claim is made that those branches are repaired by this commit.
