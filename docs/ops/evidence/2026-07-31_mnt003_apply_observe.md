# MNT-003 apply-and-observe — rolled back on first failed trigger

**Captured:** 2026-07-31 10:08–10:12 CEST
**Router task:** `4ac50dcd-48a5-42bc-8f7a-16d3c39f6686`
**Approved plan task:** `1326c521-c2bf-47a5-880b-99bfc8098d92`
**Disposition:** `ROLLED_BACK_POST_APPLY_FAILURE`

The approved, hash-gated principal/action change was applied to the five MNT-003
tasks. The first regular post-apply execution, `QM_StrategyFarm_AgyGovernor`,
returned `0x00000002`. The approved rule was to roll back all five tasks on any
misbehavior rather than debug the live contract in place. The exact captured
before XML was therefore restored immediately.

All five rollback hashes match their approved before hashes. No task was
enabled, disabled, started, or stopped manually. Factory state, T1–T10
backtests, T5, T_Live, FTMO, triggers, and task settings were not touched.

## Authorization and preconditions

- The plan task was closed `APPROVED` at `2026-07-31T09:47:19+02:00`.
- The apply-and-observe task was routed to Codex at
  `2026-07-31T09:47:20+02:00`.
- The apply process ran elevated as `NT AUTHORITY\SYSTEM` in session 0.
- Immediately before apply, `query session` showed `qm-admin` logged on in
  disconnected session 1.
- The Task Scheduler Operational log was enabled.
- All five live tasks still matched the approved before hashes; the apply tool
  would otherwise have failed closed before mutation.

## Apply

Command:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe `
  -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File C:\QM\repo\tools\strategy_farm\Apply-Mnt003MinimalPlan.ps1 `
  -Mode Apply `
  -PlanPath C:\QM\repo\docs\ops\evidence\2026-07-31_mnt003_minimal_plan.json
```

Output:

```text
APPLIED principal/action only: QM_StrategyFarm_AgyGovernor
APPLIED principal/action only: QM_StrategyFarm_CodexFleetPacer
APPLIED principal/action only: QM_StrategyFarm_GeminiOrchestration_15min
APPLIED principal/action only: QM_StrategyFarm_MailboxSourceIntake_Daily
APPLIED principal/action only: QM_StrategyFarm_WorkerDedupe
APPLY_EXIT_CODE=0
```

Task Scheduler recorded event 140 for the five updates at
10:08:38.824–10:08:40.669 CEST.

## Immediate post-apply contract verification

At 10:09:05–10:09:07 CEST, all five live definitions passed the same checks:

- principal `SYSTEM/ServiceAccount/Highest`;
- executable
  `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`;
- action arguments and working directory exactly matched the approved plan;
- registration information, triggers, and settings were byte-for-byte equal at
  the corresponding XML-node level to the captured before XML;
- enabled state remained `true`.

The observation window therefore began with a 5/5 structurally correct apply.

## First regular trigger and rollback decision

`QM_StrategyFarm_AgyGovernor` was the first target to reach a regular trigger.

| Evidence | Value |
|---|---|
| Task Scheduler event 107 | 10:10:01.823 CEST, time-trigger launch |
| Event 129 | root `powershell.exe`, PID 14576 |
| Event 100 | root task user `NT AUTHORITY\SYSTEM` |
| Event 201 | completed 10:10:03.832 CEST, return `2147942402` (`0x80070002`) |
| `Get-ScheduledTaskInfo` | `LastRunTime=2026-07-31T10:10:10+02:00`, `LastTaskResult=0x00000002` |

The task contract required `LastTaskResult=0`. Return `0x00000002` is therefore
misbehavior even though neither forbidden historical signature
`0x800710E0` nor `0xC0000142` appeared. The helper can itself return 2, and it
also propagates child exit codes, so this ticket makes no unsupported
root-cause attribution.

The process-start trace intended to capture the session-1 child hit an evidence
collector serialization error after the run. That does not weaken the rollback
decision: the nonzero authoritative Task Scheduler result independently
triggered the approved rollback rule.

No later target was allowed to run under the changed contract.

## Exact rollback

Command:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe `
  -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File C:\QM\repo\tools\strategy_farm\Apply-Mnt003MinimalPlan.ps1 `
  -Mode Rollback `
  -PlanPath C:\QM\repo\docs\ops\evidence\2026-07-31_mnt003_minimal_plan.json
```

Output:

```text
ROLLBACK registered exact before XML: QM_StrategyFarm_AgyGovernor
ROLLBACK registered exact before XML: QM_StrategyFarm_CodexFleetPacer
ROLLBACK registered exact before XML: QM_StrategyFarm_GeminiOrchestration_15min
ROLLBACK registered exact before XML: QM_StrategyFarm_MailboxSourceIntake_Daily
ROLLBACK registered exact before XML: QM_StrategyFarm_WorkerDedupe
ROLLBACK_EXIT_CODE=0
```

Task Scheduler recorded the five rollback updates at
10:11:11.658–10:11:11.878 CEST.

Post-rollback verification:

| Task | Expected/live normalized XML SHA-256 | Match | State | Enabled | Restored principal |
|---|---|---:|---|---:|---|
| AgyGovernor | `d6fda9988bd670b66cee6d2d9ce2e94c6591617367c533bb33ba8ba7464458c1` | yes | Ready | yes | `qm-admin/Interactive/Highest` |
| CodexFleetPacer | `de6cfcd1d1ca18a56b42e9539ddc429ab370cd3d72ee4928aaeabbef5dcda4bc` | yes | Ready | yes | `qm-admin/Interactive/Highest` |
| GeminiOrchestration | `4a5f5184b380c12cf3452ddc17bea93b8c6570c9ead64b743f10e04540eb909a` | yes | Ready | yes | `qm-admin/Interactive/Highest` |
| MailboxSourceIntake | `1febc9055735b0be19ac812dedf9c492c4a957ce50152ccf6942f46cf7415200` | yes | Ready | yes | `qm-admin/Interactive/Highest` |
| WorkerDedupe | `36e5d43de5ebda249c374990fa29b55b3e90753b24b4d3a50b2520b6f7066fc5` | yes | Ready | yes | `qm-admin/Interactive/Highest` |

The Operational-log slice from 10:08:00 through 10:11:40 CEST contained 16
target-task events, zero `0x800710E0`/`2147946720` rows, and zero
`0xC0000142`/`3221225794` rows.

## Installer alignment

No installer commit was created. Aligning the five installers to the proposed
SYSTEM-plus-helper contract after the live contract failed would make a future
reinstall reintroduce the rolled-back behavior. Installer alignment remains
pending until a follow-up plan explains and corrects the `0x00000002` result and
receives fresh approval.

## Focused verification

- Apply tool: exit 0, 5/5 applied.
- Immediate live contract: 5/5 principal/action matches; 5/5 preserved
  registration/triggers/settings/enabled state.
- First regular execution: failed, authoritative task result `0x00000002`.
- Rollback tool: exit 0, 5/5 exact-before XML registrations.
- Post-rollback normalized live XML hashes: 5/5 exact matches.
- Post-rollback state: 5/5 `Ready`, 5/5 enabled.

The safe handoff is REVIEW with the live system restored, not acceptance of the
proposed contract.
