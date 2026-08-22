# Diversity funnel — hard CPU-ceiling stop

Date: 2026-08-22 UTC

Branch: `agents/board-advisor`

Status: stopped before farm claim, card selection, build, smoke, or Q02 enqueue

## Outcome

The mandatory capacity preflight bound before candidate selection. No EA or
task was claimed, and no build-backlog row was advanced. The standard build
process requires a Model-4 smoke, which cannot be admitted while the paced
fleet's explicit CPU ceiling is binding.

The canonical farm controller reported eight active work items: two Q02, four
Q07, one Q09_NEWS, and one permission-pattern fixture harness. The nearby
path-filtered process census found six governed tester processes on T1, T2,
T4, T6, T7, and T8, with no duplicate workers or orphaned processes. T3 and
T9 had fresh active claims but no visible terminal process at that scan. Codex
had no `IN_PROGRESS` or `TODO` agent task, and this wake took no new farm or
agent claim.

## Binding capacity stop

Five two-second whole-host CPU samples ending at
`2026-08-22T01:45:58.9005028Z` were `98.24%`, `96.10%`, `98.19%`, `95.86%`,
and `98.54%`. Their `97.39%` average and `98.54%` maximum both exceed the
explicit `97%` average-or-maximum hard ceiling.

This is a non-duplicate fleet observation 883.6 minutes after the prior
diversity stop. Active work moved from nine to eight, the visible governed
tester count moved from nine to six, and the phase mix changed from
Q03/Q05/Q06/Q07 to Q02/Q07/Q09_NEWS plus the harness. The capacity ceiling
nevertheless remains binding.

Per the mission stop condition, no farm claim, Strategy Card selection, EA or
registry mutation, resolver regeneration, build check, compile, smoke,
backtest, Q02 enqueue/requeue, dispatch, terminal reservation, priority
mutation, or process-control action was performed.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260822T014558Z_board_advisor.json`.

## Safety

No portfolio gate, portfolio KPI, deploy manifest, T_Live file/state, or
AutoTrading state was changed. T_Live appeared only in the read-only process
census and was excluded from the governed T1–T10 count. Concurrent unrelated
worktree changes were left unstaged and untouched.

## Continuation

After sustained whole-host CPU remains below 97% with maximum headroom, rerun
the farm ownership preflight and claim exactly one highest-diversity eligible
build or diverse Q02–Q03 infrastructure repair.
