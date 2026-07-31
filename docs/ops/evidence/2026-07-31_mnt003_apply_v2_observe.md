# MNT-003 v2 apply and bounded observation

**Date:** 2026-07-31

**Router task:** `8b4f791a-3ef6-4461-8589-f1cae84dc66f`

**Predecessor diagnosis:** `c913effd-55db-4840-820d-3c51bae4ea8f`

**Disposition:** `APPLY_PASS_CYCLIC_OBSERVE_PASS_INSTALLERS_ALIGNED_DAILY_AND_TRIGGERLESS_FIRST_RUN_OPEN`

The approved v2 principal/action-only change was applied to all five MNT-003 tasks. AgyGovernor, CodexFleetPacer, and GeminiOrchestration each completed at least two regular post-apply cycles with Task Scheduler result 0. A later read-only process trace proved their `pythonw.exe` children ran in session 1 under the `qm-admin` token, with the exact v2 child command lines and no apostrophes. No rollback condition occurred.

MailboxSourceIntake's next daily trigger is 2026-08-01 06:07 CEST, outside this ticket's one-hour window. WorkerDedupe is intentionally triggerless/on-demand and has no next run. Neither was artificially started; their first post-apply execution evidence remains explicitly open.

No task was manually started, stopped, enabled, or disabled. No Factory state, T1–T10 test, T5, T_Live, FTMO, terminal, chart, or AutoTrading state was touched.

## Bound inputs and pre-apply gate

- plan: `docs/ops/evidence/2026-07-31_mnt003_minimal_plan_v2.json`
- plan SHA-256: `019f378e3966aa55e68fe0d35013ca273b8c6311283dbbda328bded1e378e7ee`
- apply tool: `tools/strategy_farm/Apply-Mnt003MinimalPlan.ps1`
- apply-tool SHA-256: `91d04c531b0014e5cb6f3422061a9517a217a3f41d26a860231713535caf3fb6`
- executor: `NT AUTHORITY\SYSTEM`, session 0, elevated
- target interactive session at preflight: `qm-admin`, session 1, active
- Task Scheduler Operational log: enabled

Windows PowerShell 5.1 WhatIf was run immediately before apply:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe `
  -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File C:\QM\repo\tools\strategy_farm\Apply-Mnt003MinimalPlan.ps1 `
  -Mode WhatIf `
  -PlanPath C:\QM\repo\docs\ops\evidence\2026-07-31_mnt003_minimal_plan_v2.json
```

Result: exit 0, five exact live-before normalized XML hash matches, and `WHATIF_ONLY`. The five matched before hashes were:

| Task | approved/live before normalized XML SHA-256 |
|---|---|
| AgyGovernor | `d6fda9988bd670b66cee6d2d9ce2e94c6591617367c533bb33ba8ba7464458c1` |
| CodexFleetPacer | `de6cfcd1d1ca18a56b42e9539ddc429ab370cd3d72ee4928aaeabbef5dcda4bc` |
| GeminiOrchestration | `4a5f5184b380c12cf3452ddc17bea93b8c6570c9ead64b743f10e04540eb909a` |
| MailboxSourceIntake | `1febc9055735b0be19ac812dedf9c492c4a957ce50152ccf6942f46cf7415200` |
| WorkerDedupe | `36e5d43de5ebda249c374990fa29b55b3e90753b24b4d3a50b2520b6f7066fc5` |

No hash drift was present, so the authorized apply proceeded.

## Apply

Command: the same Windows PowerShell 5.1 invocation with `-Mode Apply` and the v2 plan path.

Output:

```text
APPLIED principal/action only: QM_StrategyFarm_AgyGovernor
APPLIED principal/action only: QM_StrategyFarm_CodexFleetPacer
APPLIED principal/action only: QM_StrategyFarm_GeminiOrchestration_15min
APPLIED principal/action only: QM_StrategyFarm_MailboxSourceIntake_Daily
APPLIED principal/action only: QM_StrategyFarm_WorkerDedupe
APPLY_EXIT_CODE=0
```

Task Scheduler event 140 recorded the five updates from 19:42:42 through 19:42:45 CEST.

## Immediate and final contract verification

All five tasks are enabled and retain their approved registration metadata, triggers, and settings at exact XML-node hashes. Each principal is `SYSTEM/ServiceAccount/Highest`. Each action matches the v2 plan exactly, including one outer double-quoted `-Arguments` value; all five action strings have zero apostrophe characters.

| Task | post-apply normalized XML SHA-256 | registration / triggers / settings preserved | v2 action | apostrophe |
|---|---|---:|---:|---:|
| AgyGovernor | `94901e37eb51d67878f6a46d76fa9d1f7ca13a82dbda97d85091fb45598b95e3` | yes / yes / yes | exact | no |
| CodexFleetPacer | `e218083cb398496667f93fec6f691426feb6b9ca4e428f38a364a854745411dd` | yes / yes / yes | exact | no |
| GeminiOrchestration | `de76975abbabdacf4ccce157a71da23223f99bd9a017b43925ac3d2fba301e1d` | yes / yes / yes | exact | no |
| MailboxSourceIntake | `20622b68c4a3674fc194b16fe0766780c93bd98941cb3ca327e9d6fc16e4f05a` | yes / yes / yes | exact | no |
| WorkerDedupe | `fffb21ed38ea9843aac390121e5798075cd2e123383cbbe1c64bbb319130495b` | yes / yes / yes | exact | no |

## Cyclic-task observation

The apply window started at 19:42 CEST. The required two-cycle observation completed by 20:00:09 CEST, well below one hour.

| Task | regular cycle | root PID (event 129) | completed (event 201) | result |
|---|---|---:|---|---:|
| CodexFleetPacer | 1 | 12488 | 19:43:51 | 0 |
| CodexFleetPacer | 2 | 19072 | 19:58:52 | 0 |
| GeminiOrchestration | 1 | 10940 | 19:45:07 | 0 |
| GeminiOrchestration | 2 | 6140 | 20:00:08 | 0 |
| AgyGovernor | 1 | 5328 | 19:50:05 | 0 |
| AgyGovernor | 2 | 18552 | 20:00:09 | 0 |

For each run, event 100 records `NT AUTHORITY\SYSTEM` as the root task user. `Get-ScheduledTaskInfo` remained result `0x00000000` after completion.

Across all five target task names from the apply events through the observation close, the Task Scheduler Operational slice contained zero post-apply events with decimal/hex signatures for:

- `0x800710E0` / `2147946720`
- `0xC0000142` / `3221225794`
- `0x80070002` / `2147942402`

### Child token, session, and command-line proof

The durable read-only collector and result are:

- `docs/ops/evidence/2026-07-31_mnt003_process_trace.ps1`
- `docs/ops/evidence/2026-07-31_mnt003_process_trace_result.json`

The result uses Task Scheduler events 100/129/201 for root authority and PID/result, and a live `Win32_Process.GetOwner` plus CIM snapshot for the child token/session/command line.

| Task | SYSTEM root PID | child PID | child owner | session | child command | apostrophe |
|---|---:|---:|---|---:|---|---:|
| AgyGovernor | 11984 | 8920 | `WIN-B95G5LPSJ1O\qm-admin` | 1 | `pythonw.exe C:\QM\repo\tools\strategy_farm\agy_governor.py` | no |
| CodexFleetPacer | 16128 | 17860 | `WIN-B95G5LPSJ1O\qm-admin` | 1 | `pythonw.exe C:\QM\repo\tools\strategy_farm\codex_fleet_pacer.py` | no |
| GeminiOrchestration | 12488 | 14368 | `WIN-B95G5LPSJ1O\qm-admin` | 1 | `pythonw.exe C:\QM\repo\tools\strategy_farm\run_agent_orchestration_task.py --agent gemini --max-sessions 1` | no |

Those naturally scheduled traced runs also completed with event-201 result 0. The last traced result was 20:30:05 CEST, 48 minutes after apply.

## Agy HTTP 401 finding

AgyGovernor's domain log recorded HTTP 401 at the post-apply 19:50 and 20:00 runs (`2026-07-31T17:50:04Z` and `2026-07-31T18:00:09Z`). The task root and child contract completed with result 0 in both cycles. Per the brief, this is a separate Agy credential/token finding and does not fail the scheduled-task contract. No owned gate existed, so the governor took no gate action.

## Mailbox and WorkerDedupe first-run status

| Task | post-apply run observed | reason | next action |
|---|---:|---|---|
| MailboxSourceIntake | no | daily 06:07 trigger; next natural run `2026-08-01T06:07:07+02:00`, outside ticket window | leave open for the next normal run; do not fire manually |
| WorkerDedupe | no | intentionally has no trigger and no `NextRunTime`; last stored `0x800710E0` is from 2026-07-26, before this apply | leave open until the watchdog's next genuine on-demand need; do not fire manually |

The old stored nonzero results on these two never appeared as post-apply events and did not trigger rollback.

## Installer alignment

After the three cyclic tasks passed the required observation, the five installation sources were aligned to the v2 bridge pattern in a separate commit:

`1ddf11d075108535fa4d7e030f0f001bef4ed27f` — `ops: align MNT-003 installers with v2 bridge`

Changed installers:

- `install_agy_governor_scheduled_task.ps1`
- `install_codex_fleet_pacer_scheduled_task.ps1`
- `install_agent_orchestration_scheduled_tasks.ps1` (Gemini target only; out-of-scope Codex/Claude contracts preserved)
- `install_mailbox_source_intake_task.ps1`
- `install_hygiene_and_lsm_tasks.ps1` (WorkerDedupe target only)

Each target template now uses `SYSTEM/ServiceAccount/Highest`, `run_in_console_session.ps1`, `pythonw.exe`, target user `qm-admin`, the approved timeout, and one outer double-quoted child argument. Each fails closed if the emitted action contains an apostrophe. The installers were not executed.

Focused verification:

```text
python -m pytest \
  tools/strategy_farm/tests/test_mnt003_installer_alignment.py \
  tools/strategy_farm/tests/test_task_contract_fix_package.py \
  tools/strategy_farm/tests/test_factory_watchdog_interactive_heal_static.py \
  tools/strategy_farm/tests/test_tester_cache_purge_owner_state.py -q

16 passed in 11.27s
```

The new alignment test also parses all five installers with Windows PowerShell 5.1.

## Final disposition

- Apply: **PASS 5/5**.
- Preserved task definition nodes: **PASS 5/5**.
- Two regular result-0 cycles: **PASS 3/3 cyclic tasks**.
- SYSTEM root to `qm-admin` session-1 child proof: **PASS 3/3**.
- Forbidden scheduler signatures after apply: **0**.
- Installer alignment: **PASS**, separate commit `1ddf11d07`.
- Mailbox first normal run: **OPEN**, next day by design.
- WorkerDedupe first genuine on-demand run: **OPEN**, no trigger by design.
- Rollback: **not invoked; no rollback condition occurred**.

The v2 production definitions remain active and verified. This evidence creates no Factory, pipeline, or live-trading verdict.
