# Factory restart preflight — prepared, not authorized

**Observed:** 2026-07-30 05:25:25Z

**Audited source:** `f8593cd4beba7194f2a30fe29dfd43bffda6556d`

**Disposition:** `BLOCKED_OWNER_ACTION_REQUIRED`

**Factory ON executed:** no

## Outcome

The restart mechanics are source-tested and the Factory is quiescent, but the current
runtime state is not yet eligible for `Factory_ON.ps1`. The blocker is not the completed
MT5 diagnostic. It is the deliberate fail-closed restart contract: the 66-byte legacy
OFF flag has no exact 21-task restore map, the T5/minimum-worker policy remains
unratified, five external bindings remain red and the source-ready MNT-003 Factory
contract has not received its post-publication OWNER apply.

The machine-readable preflight is
`docs/ops/evidence/2026-07-30_factory_restart_preflight.json`.

## Verified safe baseline

- `FACTORY_OFF.flag` remains byte-identical at SHA-256
  `09cc4f83e8d5f384f03bc51306beff2cdd165108559a00dbf665097c60b47f1c`.
- The global mutation lock is absent after the governed T10 run.
- All 30 managed tasks and all six permanently disabled hazard/policy tasks are present and
  Disabled.
- T5 is the sole entry in `disabled_terminals.txt`; a normal restart would expect nine
  visible worker daemons.
- T_Live remains PID 5220, started at 2026-07-29 09:25:43+02:00. Neither T_Live nor
  AutoTrading was touched.
- PowerShell process-scope tests pass 278 assertions; restore-intent tests pass.
- The final source green lane is 3,399 passed, one skipped, five exact external-residual
  deselections and 49 passed subtests. The external lane produces exactly those five
  known failures and no others.

## OWNER decisions still required

1. Approve or amend the 21 explicit restore-state Booleans in the JSON preflight. The
   proposal is based on the last versioned pre-OFF inventory: 19 Enabled and two
   Disabled (`FactoryRecycle_Daily`, `SourcingIntakeSweep`). It is evidence for review,
   not permission and not a claim about the exact final instant before OFF.
2. Ratify T5 quarantine and the resulting nine-worker/minimum-worker health policy.
3. Ratify exactly seven `release_on_restart` rows and the commit-bound MNT-003 Factory
   apply plan.
4. Select the exact durably published canonical commit before starting a moving source
   checkout.

The earlier source hazards are now closed in the candidate source:

- `Factory_ON.ps1` now waits, before hold release, for exact task-enabled states, fresh
  successful QuotaPull/AgentRouter/Pump results and exactly the expected nine workers in
  the interactive session. Its bounded 300-second timeout follows the existing
  `OFF_RECOVERY_REQUIRED` rollback path.
- `QM_StrategyFarm_UnreadableLinks_Friday` moved from `ALWAYS_ON` to
  `ENFORCE_DISABLED`; the observed Disabled state is now the coded safe default.
- MNT-003 now treats Enabled as state, not contract identity, and provides an exact
  OFF-hash/plan-bound, protocol-v2 locked Factory apply with full-scope preflight,
  create-only crash journal, per-task CAS, reverse compensation and retained-lock
  fail-closed recovery. Its five Factory tasks plan as `BEFORE/disabled`; Live tasks are
  plan-only. No runtime apply occurred.

Two governance/runtime conditions remain hard blockers:

- The authoritative residual plan keeps the Factory OFF until the five fail-closed
  external-state tests pass. Those bindings must be repaired, or OWNER must explicitly
  revise that exit contract; the existing requirement will not be silently waived.
- After canonical publication the MNT-003 plan must be regenerated because it binds the
  exact source commit and script/package hashes, then pass OWNER-controlled
  `PLAN → WhatIf → Apply` while Factory OFF remains asserted.

Only after those decisions may a fresh `qm.factory-restore-intent/v1` manifest be
created. It must bind the exact OFF-flag SHA, contain all 21 Boolean keys, name OWNER
authority and a durable decision reference, and be used within its 24-hour lifetime.
No executable OWNER manifest was fabricated during this preflight.

## Queue and health handover

- 23 holds are active: seven are explicitly `release_on_restart`; 16 are non-releasing
  FTMO/quarantine holds and must remain active.
- The candidate restart code releases the seven-row cohort only after the new bounded
  post-start task/result/worker health gate passes. Runtime proof remains deferred to
  the eventual explicit OWNER restart window.
- A read-only health pass reports 21 OK, eight WARN and six FAIL. Three FAILs are
  expected consequences of intentional OFF (`pump_task_lastresult`, idle dispatcher,
  zero workers). Persistent findings remain visible: 445 unbuilt approved cards, 265
  retry-exhausted Q02/P2 pairs and live KS-baseline dormancy.
- MNT-007 census is internally complete (`unresolved=0`, invalid Q08 retryable=0). The
  dry run found 1,619 eligible rows overall; its Q02 view contains 596 groups (204
  eligible, 392 refused). A create-only five-row Wave-1 plan exists at
  `D:\QM\strategy_farm\artifacts\factory_restart_preflight_f8593cd4b_20260730\mnt007_wave1_plan.json`,
  SHA-256 `aec0b2be416230f63f96a676aa89b63de826bb891021385da6d87ad02ca9aa00`.
  It was not applied and is not implicit restart authority. Applying it would move the
  pending count from 2,188 to 2,193, so a restart would not be an isolated five-row
  canary.

## FTMO boundary

The completed FTMO research receipt is technically valid but reports strict
qualification `UNVERIFIED`, money gate `SETUP_DATA_MISSING` and paid challenge
`NO_GO`. Its authorization section sets `factory_restart_authorized=false`. This does
not make the infrastructure unsafe; it simply cannot be used as authorization for the
independent Factory restart or for deployment, purchase or AutoTrading.

## Controlled continuation

After publication, the five residuals (or their explicit governance revision), the
commit-bound MNT-003 Factory apply and the remaining OWNER decisions are closed, use `Factory_OFF.ps1
-RestoreIntentManifest <OWNER-manifest>` to upgrade the legacy record while remaining
OFF. Re-run the full read-only preflight against the new schema-v2 flag. Only then, in
the visible elevated `qm-admin` session and after a final explicit OWNER go, run
`Factory_ON.ps1 -NoPause` and require nine workers plus successful task-result and
heartbeat health before releasing exactly the seven restart holds; then verify exact
task restoration, T_Live continuity and post-start health. Any mismatch must leave or
restore Factory OFF.
