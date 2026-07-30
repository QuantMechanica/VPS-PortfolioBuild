# Scheduled-task contract correction package — 2026-07-28

Status: **CORRECTED PACKAGE UNEXECUTED**. The original content-bound Factory
plan `720d17a050c84023da17b8557efcbc277e6bd9239530dd6203c95ee80dab288f`
was attempted on 2026-07-30. Windows rejected the first
target XML before it could persist; the already-journaled attempt was restored
to its exact preimage and verified, and the orphaned exact-identity mutation
lock was recovered after its owner process exited. All five tasks replanned as
`BEFORE` and remained disabled. The failed plan must not be retried. See
`docs/ops/evidence/2026-07-30_mnt003_failed_apply_lock_recovery.json`.

The corrected package has not registered, started, stopped, enabled, or
disabled a scheduled task. It requires a new post-fix plan and fresh OWNER
authorization before any Apply.

The package contains exact semantic exports of the seven `0x800710E0` tasks
plus `QM_FTMO_AtLogon`, which is part of the same parked-terminal recovery
contract:

- `before/`: read-only exports taken on 2026-07-28.
- `after/`: proposed contracts.
- `rollback/`: the complete pre-change contracts.
- `Apply-TaskContractFix.ps1`: default read-only, content-addressed planner plus
  explicit, drift-refusing, enabled-state-preserving Factory apply/rollback.
  Live contracts are visible in PLAN but deliberately not mutable here.

Proposed disposition:

| Task | Proposed execution contract |
|---|---|
| `QM_StrategyFarm_AgyGovernor` | LocalSystem task; user/DPAPI-dependent Python is launched in the existing `qm-admin` session via `run_in_console_session.ps1`. |
| `QM_StrategyFarm_CodexFleetPacer` | LocalSystem, direct `pythonw.exe`; existing 15-minute trigger retained. |
| `QM_StrategyFarm_GeminiOrchestration_15min` | LocalSystem task; `run_in_console_session.ps1` launches `pythonw.exe` as logged-on `qm-admin`, preserving Credential Manager and `LOCALAPPDATA\agy`; the 15-minute trigger is retained. |
| `QM_StrategyFarm_MailboxSourceIntake_Daily` | LocalSystem task; the same wrapper launches `pythonw.exe` as logged-on `qm-admin`, preserving Administrator `CODEX_HOME` and per-user auth; daily 06:07 and retry settings are retained. |
| `QM_StrategyFarm_WorkerDedupe` | LocalSystem task; worker launcher is placed in the existing `qm-admin` session via `run_in_console_session.ps1`, avoiding GUI children in session 0. |
| `QM_T_Live_AtLogon` | Remains `qm-admin` / `InteractiveToken`; one logon trigger; demand start explicitly disabled. |
| `QM_FTMO_AtLogon` | Remains `qm-admin` / `InteractiveToken`; one logon trigger; demand start explicitly disabled. `FTMO_ON.ps1` provides the baked PARKED no-launch guard. |
| `QM_Live_MT5_SessionSupervisor` | Remains `qm-admin` / `InteractiveToken`; the 15-minute time trigger is removed, leaving one logon trigger; demand start remains enabled only for the session-bound RunEx starter. |

OWNER/Claude interactive-session usage:

Apply this package only after this branch has been merged and deployed to
`C:\QM\repo`; the proposed task actions reference code at that canonical path.

```powershell
# Read-only Factory plan; prints exact PLAN_ID and FACTORY_OFF_SHA256.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TaskContractFix.ps1

# JSON form for review and a separate read-only Live inventory.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TaskContractFix.ps1 -TaskScope Factory -PlanMode Apply -Json
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TaskContractFix.ps1 -TaskScope Live -PlanMode Apply

# A real mutation additionally requires all values below. Use only values from
# the just-reviewed plan and a fresh, durable OWNER decision; -WhatIf creates no
# lock, directory, receipt or task write.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TaskContractFix.ps1 `
  -Apply -TaskScope Factory `
  -ExpectedFactoryOffSha256 <64-hex-off-hash> `
  -ExpectedPlanId <64-hex-plan-id> `
  -OwnerDecisionRef <durable-owner-decision-ref> `
  -OwnerAuthorizedBy <owner-identity> `
  -OwnerAuthorizedAtUtc <fresh-UTC-timestamp> `
  -ReceiptPath D:\QM\strategy_farm\artifacts\task_contract_fix_2026-07-28\<receipt>.json `
  -WhatIf
```

The script accepts only the expected two-state transition (`BEFORE → AFTER` or
`AFTER → BEFORE`). Any third-state drift is refused. `<Settings><Enabled>` is
treated as runtime state rather than contract identity, so deliberate Factory
OFF does not become false contract drift. The configured bit is read from the
same exported XML snapshot (never inferred from operational `State`, which may
still be `Running`), then contract and bit are re-exported and CAS-checked
immediately before each registration. The script embeds that exact bit in the
target XML, then verifies both the target contract and unchanged Enabled state.
There is no transient default-enable window for deliberately disabled tasks.
It contains no `Start-ScheduledTask`, `Stop-ScheduledTask`, process control,
terminal launch, AutoTrading change, or task enable/disable command.

Before it creates the mutation lock, the script serializes every desired and
compensation payload as the UTF-16-declared Unicode string required by the
Task Scheduler API and parses it through `Schedule.Service.NewTask(0).XmlText`
without registration. This catches host-specific Task Scheduler XML/schema
errors read-only. LocalSystem contracts use SID `S-1-5-18`; their XML omits
`LogonType`, which Windows resolves to service-account logon.

For Factory mutation, the plan binds the exact repository commit, apply-script
hash, aggregate package hashes, raw OFF-flag hash, live contract preimages,
target fingerprints and Enabled bits. The script requires a fresh OWNER UTC
authorization (maximum age 24 hours), acquires the shared protocol-v2
`FACTORY_MUTATION.lock`, re-hashes OFF under that lock, validates the complete
five-task scope before task 1, and refuses if any selected task is enabled.

Before task 1 it publishes a create-only `IN_PROGRESS` receipt with full
base64-encoded preimages. It atomically journals each verified registration.
Any error compensates the attempted set in reverse order. Failed compensation
retains the mutation lock and records `FAILED_UNCOMPENSATED_LOCK_RETAINED`;
successful compensation records `FAILED_COMPENSATED`. A success is recorded as
`APPLIED_VERIFIED` or `ROLLED_BACK_VERIFIED`, followed by exact-identity lock
release. Existing receipts are never reused.

Live task contracts are never included in a Factory-scope apply and mutation
with `-TaskScope Live` is hard-refused. They require a separate future package
because T_Live/FTMO task state is outside the Factory restart boundary. Factory
apply remains deferred until the reviewed source is canonical and OWNER
authorizes that exact plan; this work did not run it.
