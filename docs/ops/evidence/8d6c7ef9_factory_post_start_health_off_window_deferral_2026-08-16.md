# Factory post-start health gate — OFF-window deferral and patch contract

Date: 2026-08-16

Router task: `8d6c7ef9-dd06-4d16-9654-8a0cb2b3b154`

Verdict: `REVIEW — DEFERRED BY LIVE FACTORY GUARD`

## Guard result

The routed payload marks `tools/strategy_farm/factory_restart_health.ps1` as
ceremony-critical and permits changing it only during an OFF window.  The
canonical factory was ON when this task was handled:

- check time: `2026-08-16T09:00:00.6198176Z`;
- `D:\QM\strategy_farm\state\FACTORY_OFF.flag`: absent;
- governed worker processes visible: 7;
- `QM_StrategyFarm_AgentRouter_5min`: enabled;
- `QM_StrategyFarm_Pump_5min`: enabled.

Changing the live ceremony file would therefore violate the routed
constraint.  No source, scheduled task, worker, terminal, T_Live setting, or
AutoTrading setting was changed.  Active T1–T10 work was not interrupted.

## Reproduced defect

The current `Get-QmCriticalTaskFreshnessErrors` accepts only a task whose
instantaneous state is `Ready`, whose `LastTaskResult` is zero, and whose
`LastRunTime` is fresh and newer than the pre-start baseline.  The existing
wait-loop latch helps only after such a completion has first been observed.

A focused synthetic snapshot used the exact scheduler facts from the defect:

- task: `QM_StrategyFarm_AgentRouter_5min`;
- state: `Running`;
- start/`LastRunTime`: `2026-08-16T09:00:11Z`;
- restart floor: `2026-08-16T09:00:10Z`;
- pre-start baseline: `2026-08-16T09:00:00Z`;
- `LastTaskResult`: `2147946720` (`0x800710E0`, overlap refusal).

Current result:

```text
healthy=false
Critical task 'QM_StrategyFarm_AgentRouter_5min' is not freshly completed (state='Running').
Critical task 'QM_StrategyFarm_AgentRouter_5min' does not have a successful result.
```

This reproduces the starvation mode: a legitimate long router run cannot
latch until it finishes, while its five-minute overlap triggers continually
replace the scheduler result with the refusal code.

## Patch contract for the next authorized OFF decision

The OFF-window implementation should be narrow and fail closed:

1. Add an explicit allow-list for critical tasks whose legitimate runtime may
   exceed trigger cadence.  Initially it contains only
   `QM_StrategyFarm_AgentRouter_5min`; do not grant the exception to every
   critical task.
2. For an allow-listed task, accept either:
   - a fresh `Ready` completion with result `0`, or
   - a current `Running` instance whose `LastRunTime` is parseable, at or after
     the restart freshness floor, and strictly newer than its captured
     baseline.
3. A `Running` acceptance must not consult the prior `LastTaskResult`; this is
   where `0x800710E0` is non-authoritative.  Presence, enabled state, probe
   health, timestamp freshness, and baseline advancement remain mandatory.
4. A `Ready` row with `0x800710E0` is not success and is not a failed execution;
   keep waiting for a fresh success/running start.  All other nonzero completed
   results remain fail-closed.
5. Latch the accepted running-start evidence exactly as fresh completion is
   latched now, recording the acceptance mode and observed start timestamp.
6. At the existing bounded deadline, emit an explicit sorted list of critical
   task names that never latched, followed by the last detailed assessment.
   This turns the one-hour timeout into a deterministic `starved_tasks=...`
   diagnosis.
7. Preserve the immediate pre-release revalidation via the returned latch;
   no quiet-zone task is enabled before the health gate passes.

Required regression cases:

- allow-listed Router `Running` with fresh post-baseline start and
  `0x800710E0` -> PASS/latch;
- same Router with stale or unchanged start -> FAIL;
- non-allow-listed Pump `Running` -> FAIL;
- Router `Ready` with result `0` -> PASS/latch;
- Router `Ready` with `0x800710E0` -> pending, never execution-failure;
- ordinary nonzero completion -> FAIL;
- deadline error names exactly the unlatchable task(s);
- previously latched task remains accepted during a later overlap refusal.

## Focused verification

The unchanged baseline suite was run from `C:\QM\repo`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File tools/strategy_farm/tests/Test-FactoryRestartPostStartHealth.ps1
```

Result: `PASS Test-FactoryRestartPostStartHealth.ps1 (28 assertions)`.

That establishes a green pre-change baseline and confirms the defect is not a
general task/worker snapshot failure.  The current suite intentionally expects
an unlatchable running task to fail; the OFF-window patch must add the narrow
allow-listed exception and the regression cases above before the next
Factory_ON decision is minted.
