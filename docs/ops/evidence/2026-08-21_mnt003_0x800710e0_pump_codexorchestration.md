# MNT-003 — 0x800710E0 on Pump_5min / CodexOrchestration_15min: benign, root-caused

**Date:** 2026-08-21
**Router task:** 9226799b-8dd0-4097-bcb4-3dee7eda862a (priority 74, ops_issue)
**Authority:** Claude (orchestrator) 2026-08-21, four-batch live-state
verification of the 2026-07-28 maintenance ledger.
**Recorder:** Claude (agents/board-advisor)

## Instructed work

Determine whether the `0x800710E0` exit codes on
`QM_StrategyFarm_CodexOrchestration_15min` and `QM_StrategyFarm_Pump_5min`
are real failures or an artefact, then either fix the cause or make the
wrapper report the true outcome.

## Finding: not a PowerShell-stderr artefact — a Task Scheduler overlap-refusal

Initial hypothesis (from the known 2026-07-13 PS 5.1 stderr-trap class,
commit `43f368e3d`) was ruled out by direct inspection: neither task runs
through a `powershell.exe` wrapper. Both invoke `pythonw.exe` directly
(`Get-ScheduledTaskInfo`/task-XML confirmed):

- `QM_StrategyFarm_Pump_5min` → `pythonw.exe tools/strategy_farm/run_pump_task.py`,
  `ExecutionTimeLimit=PT30M`, `MultipleInstancesPolicy=IgnoreNew`.
- `QM_StrategyFarm_CodexOrchestration_15min` → `pythonw.exe
  tools/strategy_farm/run_agent_orchestration_task.py --agent codex
  --max-sessions 1`, `ExecutionTimeLimit=PT4H`, `MultipleInstancesPolicy=IgnoreNew`.

Both wrappers propagate the child process's real return code with no
`2>&1`/EAP interaction; Python's harmless "Could not find platform
independent libraries \<prefix\>" stderr line is written into per-run logs
and does not affect the return code.

`0x800710E0` = decimal `2147946720`. Looked up directly
(`net helpmsg 4320`, confirmed via `FormatMessageW`):
**"The operator or administrator has refused the request."** This is Task
Scheduler's own code for a trigger `MultipleInstances=IgnoreNew` skipped
because the prior instance was still running — not a code either Python
wrapper can produce, and not a real failure. Pump's 5-minute cadence against
a 30-minute execution limit, and CodexOrchestration's 15-minute cadence
against a 4-hour execution limit, make an occasional overrun-and-skip
expected, not a fault.

**Ruled out the LSM/session-manager-degradation alternative explanation:**
this exact code (`2147946720`) is *also* the `$TASK_FAIL_CODE` in
`tools/strategy_farm/lsm_health_probe.ps1`, used to detect genuine LSM
degradation on three *other* tasks (`QuotaGovernor`, `FactoryWatchdog_15min`,
`FactoryRecycle_Daily`) whose MaxLagMinutes margins are tight relative to
cadence. Checked `D:\QM\reports\state\lsm_health.json` at the time of this
cycle: `verdict=ok`, `qwinsta_ok=true`, `logon_session_ok=true`,
`spawn_ok=true`, `tasks_failing_count=0/3` — LSM is healthy right now, so the
code's appearance on Pump/CodexOrchestration is the IgnoreNew-overlap
explanation, not LSM degradation. The two explanations are not in tension:
the probe's three monitored tasks have execution limits close to their
cadence (no legitimate overlap expected), while Pump and CodexOrchestration
both have execution limits many multiples of their cadence (legitimate
overlap expected under load) — `lsm_health_probe.ps1` is correct as-is for
its three tasks and was deliberately left untouched.

## Fix applied

`tools/strategy_farm/health.py::chk_pump_task_health()` — the only automated
health signal that reads `Pump_5min`'s live `LastTaskResult` — previously
treated any nonzero code except `267009` (0x41301, "currently running") as
`FAIL`. Added `2147946720` to the same benign-busy class, but — unlike the
blind early-return for `267009` — routed it through the *same* orphaned-lock
evidence check the `result == 0` path already uses (audit 2026-07-24 FB-06
precedent: a dead-PID lock must still fail even when the reported code looks
fine), so a genuinely stuck pump hiding behind this code is still caught.

No dedicated automated health check currently reads
`CodexOrchestration_15min`'s `LastTaskResult` (confirmed by search — only
`chk_codex_zero_activity`, which is activity-based, and the unrelated
Factory_ON ceremony-marker check, touch that task name). There was nothing
to fix in code for that task; this finding + the shared root cause is
recorded here so a future health-check author does not re-diagnose it as an
LSM or pump problem.

## Verification

New test: `tools/strategy_farm/tests/test_mnt003_pump_task_ignorenew_benign.py`
(4 cases: IgnoreNew-refused+no-lock → OK; IgnoreNew-refused+orphaned dead-PID
lock → still FAIL; genuine nonzero (e.g. 112/ERROR_DISK_FULL) → still FAIL;
267009 "currently running" → unchanged OK).

Failed-before / passes-after, checked directly against `git show HEAD:...`
(pre-fix) `health.py` content with the same mocks:

```text
PRE-FIX result for 2147946720: FAIL 2147946720
```

Post-fix: `4 passed`. Also ran `test_mnt003_installer_alignment.py` (a
pre-existing, differently-scoped MNT-003 ledger entry from an earlier date —
console-bridge template installers, unrelated to this ticket) to confirm no
collision/regression: `4 passed`.

## What was and wasn't done

- Live scheduled-task settings (`MultipleInstancesPolicy`, `ExecutionTimeLimit`)
  were inspected only, never modified — `IgnoreNew` is the correct overlap
  guard and must stay.
- No factory start/stop, no terminal64, no reboot.
- `lsm_health_probe.ps1` untouched — its use of the same code for its own
  three tasks is correct and orthogonal.
- Only `tools/strategy_farm/health.py` and the new test file were changed.
