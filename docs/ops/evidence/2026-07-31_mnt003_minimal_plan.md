# MNT-003 minimal task-contract plan — PLAN + WHATIF only

**Captured:** 2026-07-31 06:21:29Z  
**Router task:** `1326c521-c2bf-47a5-880b-99bfc8098d92`  
**Verdict:** `PLAN_READY_NO_APPLY`

No scheduled task was registered, changed, enabled, disabled, started, or stopped.
The durable plan and all query rows are in
`docs/ops/evidence/2026-07-31_mnt003_minimal_plan.json`. The proposed apply tool
defaults to `WhatIf`; this ticket executed only that mode.

## Result

The five contracts do share a fragile scheduler dependency, but the live evidence
refutes the broader statement that a lock or RDP disconnect alone causes
`0x800710E0`.

At capture time, `query session` showed `qm-admin` logged on in session 1 with
state `Disc`. In that state:

- `QM_StrategyFarm_AgyGovernor`, `QM_StrategyFarm_CodexFleetPacer`, and
  `QM_StrategyFarm_GeminiOrchestration_15min` all completed with result `0`.
- `QM_StrategyFarm_MailboxSourceIntake_Daily` still retained
  `LastTaskResult=0x800710E0` from 2026-07-29.
- `QM_StrategyFarm_WorkerDedupe` still retained
  `LastTaskResult=0x800710E0` from 2026-07-26.

The precise common failure class is therefore: an `InteractiveToken` start is
refused when Task Scheduler cannot obtain a usable logged-on `qm-admin` token at
that instant. A disconnected-but-still-logged-on session can be usable. Session
transition, token absence, or logoff remains the unsafe state; it was not induced
in this read-only ticket.

The minimal contract change is:

1. LocalSystem owns each schedule (`SYSTEM` / `ServiceAccount` / `Highest`).
2. The existing `run_in_console_session.ps1` launches the user-bound child with
   the logged-on `qm-admin` token. That helper explicitly searches Active first
   and Disconnected second (`run_in_console_session.ps1:73-99`).
3. Triggers, settings, registration information, enabled state, and task names
   remain unchanged.
4. Rollback is exact re-registration of the captured before XML, hash-checked
   before any future apply.

This follows the working split already used by TesterCachePurge: its scheduler
principal is SYSTEM (`install_tester_cache_purge_scheduled_task.ps1:32-35`), while
user-session work is delegated explicitly. `QM_StrategyFarm_Pump_5min` is also
SYSTEM/ServiceAccount; it is not an unaffected *interactive* counterexample.

## Two-hour live measurement

The query window is exactly 2026-07-31 06:21:29+02:00 through
08:21:29+02:00. Factory ON occurred during this window, so target run events only
begin around 07:25-07:50. The raw event rows, TaskInfo snapshot, scheduler-log
metadata, session output, and comparison census are embedded in the plan JSON.

| Task | Principal at capture | Last run | Last result | Events in window | `0x800710E0` events |
|---|---|---:|---:|---:|---:|
| AgyGovernor | `qm-admin/Interactive/Highest` | 08:20:20 | `0x00000000` | 27 | 0 |
| CodexFleetPacer | `qm-admin/Interactive/Highest` | 08:13:13 | `0x00000000` | 21 | 0 |
| GeminiOrchestration | `qm-admin/Interactive/Highest` | 08:15:15 | `0x00000000` | 23 | 0 |
| MailboxSourceIntake | `qm-admin/Interactive/Highest` | 2026-07-29 06:07:07 | `0x800710E0` | 3 registration/update events | 0 |
| WorkerDedupe | `qm-admin/Interactive/Highest` | 2026-07-26 20:00:00 | `0x800710E0` | 3 registration/update events | 0 |
| TesterCachePurge reference | `SYSTEM/ServiceAccount/Highest` | 08:20:20 | `0x00000000` | 27 | 0 |
| Pump_5min reference | `SYSTEM/ServiceAccount/Highest` | 08:18:18 | `0x00000000` | 70 | 0 |

The Operational log no longer retains the 2026-07-26/29 failure events. It
contains no fresh `0x800710E0` row in this two-hour window. This is a stated
evidence limit, not a claim that the retained TaskInfo failures did not happen.
Pump had one separate action result `0x8007050B` at 07:36 and subsequently
recovered; it did not exhibit the target failure class.

## Per-task root cause and smallest proposed change

| Task | Root-cause disposition | Proposed action under SYSTEM |
|---|---|---|
| AgyGovernor | Contract risk confirmed; disconnect alone refuted. Its quota pull reads the user Credential Manager through `CredReadW` (`agy_governor.py:14-17`, `agy_quota.py:57-61`). | Launch `pythonw.exe agy_governor.py` through the user-token helper; wait up to 240 s. |
| CodexFleetPacer | Contract risk confirmed; disconnect alone refuted. It resolves `codex` from the inherited user PATH (`codex_fleet_pacer.py:75-76`) and its installer documents user-session descendants (`install_codex_fleet_pacer_scheduled_task.ps1:1-4`). | Launch the absolute script through the user-token helper; wait up to 300 s. |
| GeminiOrchestration | Contract risk confirmed; disconnect alone refuted. agy authentication is in Windows Credential Manager (`run_agent_orchestration_task.py:77-92`); setting `USERPROFILE` under SYSTEM is not a replacement for the DPAPI user token. | Remove the `cmd.exe` redirection shell and launch the existing Python entry point through the user-token helper; wait up to 14,100 s. Existing application logs remain authoritative. |
| MailboxSourceIntake | Historical result confirms the class, but its daily trigger did not fire in-window. The installer explicitly treats Codex/agy credentials as user-bound (`install_mailbox_source_intake_task.ps1:3-6`), while the wrapper anchors `CODEX_HOME` (`mailbox_source_intake.py:102-103,359`). | Launch the existing Python entry point through the user-token helper; wait up to 2,640 s, below the unchanged 45-minute task limit. |
| WorkerDedupe | Historical result confirms the class; no demand test was allowed. Direct session-0 workers are forbidden because terminal descendants reproduce `0xC0000142` (`install_hygiene_and_lsm_tasks.ps1:231`). | Launch `start_terminal_workers.py --dedupe` through the user-token helper; wait up to 540 s. |

The proposed contract still fails visibly if `qm-admin` is fully logged off. It
does not invent a SYSTEM fallback for DPAPI or GUI work. Its purpose is to remove
Task Scheduler's `InteractiveToken` start dependency while preserving the
required user execution context.

## Plan and rollback artifacts

The single plan/evidence JSON is:

- `docs/ops/evidence/2026-07-31_mnt003_minimal_plan.json`

The exact before exports are:

- `docs/ops/evidence/2026-07-31_mnt003_before_QM_StrategyFarm_AgyGovernor.xml`
- `docs/ops/evidence/2026-07-31_mnt003_before_QM_StrategyFarm_CodexFleetPacer.xml`
- `docs/ops/evidence/2026-07-31_mnt003_before_QM_StrategyFarm_GeminiOrchestration_15min.xml`
- `docs/ops/evidence/2026-07-31_mnt003_before_QM_StrategyFarm_MailboxSourceIntake_Daily.xml`
- `docs/ops/evidence/2026-07-31_mnt003_before_QM_StrategyFarm_WorkerDedupe.xml`
- `docs/ops/evidence/2026-07-31_mnt003_before_QM_StrategyFarm_TesterCachePurge.xml`
- `docs/ops/evidence/2026-07-31_mnt003_before_QM_StrategyFarm_Pump_5min.xml`

The apply/WhatIf tool is:

- `tools/strategy_farm/Apply-Mnt003MinimalPlan.ps1`

It is 190 lines. `WhatIf` reads and hash-checks the live definitions and prints
the five principal/action diffs. `Apply` uses only `Set-ScheduledTask` for the
principal/action change. Explicit `Rollback`, and automatic rollback after a
partial apply error, use `Register-ScheduledTask` with the exact before XML.
There is no task enable/disable/start/stop command in the script.

## WhatIf executed

Both PowerShell implementations passed:

```text
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass \
  -File C:\QM\repo\tools\strategy_farm\Apply-Mnt003MinimalPlan.ps1 \
  -Mode WhatIf \
  -PlanPath C:\QM\repo\docs\ops\evidence\2026-07-31_mnt003_minimal_plan.json

5/5 live before hashes matched
5/5 proposed principals: qm-admin/Interactive/Highest
                         -> SYSTEM/ServiceAccount/Highest
WHATIF_ONLY: no Register-ScheduledTask or Set-ScheduledTask call executed.
exit 0
```

The same command under PowerShell 7 also exited `0`. Focused static verification:

```text
PowerShell AST parse errors: 0
script lines: 190
Enable/Disable/Start/Stop-ScheduledTask occurrences: 0
raw XML parse: 7/7 PASS (UTF-16 Task documents)
plan JSON parse: PASS; schema qm.mnt003.minimal-task-contract-plan/v1
```

## Open risks before any apply

- The live two-hour query did not reproduce `0x800710E0`; Mailbox and
  WorkerDedupe evidence is retained TaskInfo plus the unchanged vulnerable
  principal, not a fresh Operational event.
- A full user logoff still leaves no token for DPAPI/desktop work; the helper
  must fail rather than run those children as SYSTEM.
- Current installer scripts still describe/register Interactive principals.
  After OWNER approval and live apply, their source contracts must be aligned in
  a separately reviewed change or a reinstall can reintroduce MNT-003.
- No post-apply execution proof exists in this ticket. Approval should create a
  separate apply-and-observe task with rollback authority and an observation
  window spanning the affected triggers.
