# Diversity build backlog: stale-queue audit and CPU stop

**Date:** 2026-08-23 UTC (`2026-08-23T03:19:09Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Status:** no non-duplicate priority-1 build exists in the nominal backlog;
stopped during priority-2 discovery at the explicit backtest CPU ceiling

## Outcome

The farm reports 38 pending `build_ea` tasks, but a read-only identity and
filesystem reconciliation found that all 38 already resolve to an existing EA
source directory and `.mq5`. They cover 37 unique EA IDs because `QM5_11011`
has two pending rows. Thirty-six also already have an `.ex5` and prior build or
pipeline history. The remaining two are durable data-contract blocks:
`QM5_1459` needs unavailable lumber/IEF series and `QM5_1457` needs unavailable
rates/bond inputs.

A separate fast reconciliation of the approved-card reservoir against active
`ea_id_registry.csv` identities found zero active approved identities whose
exact EA directory is absent. Under `qm-build-ea-from-card`, there is therefore
no fresh, registry-ready priority-1 card to claim. Treating any of the 38 stale
rows as a new build would duplicate an existing identity or disregard its
recorded block/rework state.

This is a new operational finding relative to the preceding diversity CPU-stop
receipt, which explicitly stopped before backlog ranking. The nominal pending
count is historical/rework residue rather than unbuilt diversity capacity.

## Diverse infrastructure anchors

The two preferred FX market-neutral anchors are not current Q02-Q03
infrastructure recoveries. `QM5_12532` already has logical-basket Q02 PASS and
Q04 PASS. `QM5_12533` already has logical-basket Q02 PASS; its later Q04 result
is an economic FAIL rather than an ONINIT, NO_HISTORY, or stale-binary block.
No duplicate repair or enqueue was made.

The broader priority-2 infrastructure scan was stopped as soon as the binding
capacity sample arrived. No EA was claimed, modified, compiled, or enqueued.

## Binding capacity stop

Five whole-host CPU readings were `99.12%`, `98.47%`, `99.32%`, `96.60%`, and
`99.42%`. Their average was `98.586%` and their maximum `99.42%`, above the
explicit `97%` hard ceiling. Per the mission stop condition, no further
candidate discovery, queue mutation, tester work, or backtest followed.

Machine-readable evidence is
`artifacts/diversity_build_backlog_stale_audit_cpu_stop_20260823T031909Z_board_advisor.json`.

## Safety

- The farm database was queried read-only; no work item or build task changed.
- No portfolio gate, KPI, Q08-contribution, T_Live manifest, terminal, or
  AutoTrading surface was touched.
- Concurrent unrelated worktree changes were left unstaged and untouched.
