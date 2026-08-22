# Diversity funnel — hard CPU-ceiling stop

Date: 2026-08-22 UTC

Branch: `agents/board-advisor`

Status: stopped before farm claim, card selection, build, smoke, or Q02 enqueue

## Outcome

The mandatory capacity preflight bound before candidate selection. No EA or
task was claimed, and no build-backlog row was advanced. The standard build
process requires a Model-4 smoke, which cannot be admitted while the paced
fleet's explicit CPU ceiling is binding.

The farm database passed `PRAGMA quick_check=ok` in read-only/query-only mode.
It held seven active work items: one Q02, two Q04, three Q07, and one Q09_NEWS.
A nearby path-filtered process census found four governed tester processes on
T1, T2, T3, and T6. Codex had no `IN_PROGRESS` or `TODO` agent task, and this
wake took no new farm or agent claim.

## Binding capacity stop

Five two-second whole-host CPU samples ending at
`2026-08-22T03:32:15.4809051Z` were `99.47%`, `99.42%`, `98.58%`, `98.55%`,
and `100.00%`. Their `99.20%` average and `100.00%` maximum both exceed the
explicit `97%` average-or-maximum hard ceiling.

This is a non-duplicate fleet observation 106.3 minutes after the preceding
diversity stop. Active work moved from eight to seven, the visible governed
tester count moved from six to four, and the phase mix changed from
Q02/Q07/Q09_NEWS plus the fixture harness to Q02/Q04/Q07/Q09_NEWS. The
capacity ceiling nevertheless remains binding.

Per the mission stop condition, no farm claim, Strategy Card selection, EA or
registry mutation, resolver regeneration, build check, compile, smoke,
backtest, Q02 enqueue/requeue, dispatch, terminal reservation, priority
mutation, or process-control action was performed.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260822T033215Z_board_advisor.json`.

## Safety

No portfolio gate, portfolio KPI, deploy manifest, T_Live file/state, or
AutoTrading state was changed. T_Live was excluded from the numeric T1-T10
process census. Concurrent unrelated worktree changes were left unstaged and
untouched.

## Continuation

After sustained whole-host CPU remains below 97% with maximum headroom, rerun
the farm ownership preflight and claim exactly one highest-diversity eligible
build or diverse Q02-Q03 infrastructure repair.
